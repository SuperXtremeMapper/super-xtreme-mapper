import Foundation

nonisolated struct ControllerProfileResource: Sendable {
    let name: String
    let data: Data
}

nonisolated enum ControllerProfileLibraryError: Error, Equatable, LocalizedError {
    case invalidResource(resource: String, path: String, reason: String)
    case unavailable(id: String, version: String)

    var errorDescription: String? {
        switch self {
        case let .invalidResource(resource, path, reason):
            return "Controller profile \(resource), \(path): \(reason)"
        case let .unavailable(id, version):
            return "Controller profile \(id) version \(version) is unavailable."
        }
    }
}

/// Loads a fixed catalogue atomically. User references are resolved by exact version only.
nonisolated struct ControllerProfileLibrary: Sendable {
    private struct Pin: Hashable, Sendable { let id: String; let version: String }
    private let profilesByPin: [Pin: ControllerProfile]
    let profiles: [ControllerProfile]
    private let controlsByPin: [Pin: [String: ControllerProfile.Control]]

    private static let bundled = Result { try ControllerProfileLibrary(loading: .main) }

    init(bundle: Bundle = .main) throws {
        if bundle == .main { self = try Self.bundled.get() }
        else { self = try Self(loading: bundle) }
    }

    private init(loading bundle: Bundle) throws {
        func resourceURL(_ name: String) -> URL? {
            bundle.url(forResource: name, withExtension: "json", subdirectory: "ControllerProfiles")
                ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources/ControllerProfiles")
                ?? bundle.url(forResource: name, withExtension: "json")
        }
        let manifestName = "controller-profile-catalogue"
        guard let manifestURL = resourceURL(manifestName) else {
            throw ControllerProfileLibraryError.invalidResource(resource: manifestName + ".json", path: "$", reason: "Bundled catalogue is missing.")
        }
        struct Catalogue: Decodable { let resources: [String] }
        let catalogue: Catalogue
        do {
            guard (try manifestURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 16_384 else {
                throw ControllerProfileLibraryError.invalidResource(resource: manifestName, path: "$", reason: "Catalogue exceeds size limit.")
            }
            let data = try Data(contentsOf: manifestURL)
            guard data.count <= 16_384 else { throw ControllerProfileLibraryError.invalidResource(resource: manifestName, path: "$", reason: "Catalogue exceeds size limit.") }
            try Self.checkBounds(.init(name: manifestName, data: data))
            catalogue = try JSONDecoder().decode(Catalogue.self, from: data)
            guard !catalogue.resources.isEmpty, catalogue.resources.count <= 64,
                  Set(catalogue.resources).count == catalogue.resources.count,
                  catalogue.resources.allSatisfy({ !$0.isEmpty && $0.count <= 200 && $0.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 46 } }) else {
                throw ControllerProfileLibraryError.invalidResource(resource: manifestName, path: "$.resources", reason: "Expected unique bounded resource names.")
            }
        } catch let error as ControllerProfileLibraryError { throw error }
        catch { throw ControllerProfileLibraryError.invalidResource(resource: manifestName, path: "$", reason: error.localizedDescription) }
        var resources: [ControllerProfileResource] = []
        for filename in catalogue.resources {
            let url = bundle.url(forResource: filename, withExtension: "json", subdirectory: "ControllerProfiles")
                ?? bundle.url(forResource: filename, withExtension: "json", subdirectory: "Resources/ControllerProfiles")
                ?? bundle.url(forResource: filename, withExtension: "json")
            guard let url else {
                throw ControllerProfileLibraryError.invalidResource(resource: filename + ".json", path: "$", reason: "Bundled resource is missing.")
            }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= Self.maximumBytes else {
                    throw ControllerProfileLibraryError.invalidResource(resource: url.lastPathComponent, path: "$", reason: "Resource exceeds size limit.")
                }
                resources.append(ControllerProfileResource(name: url.lastPathComponent, data: try Data(contentsOf: url)))
            } catch let error as ControllerProfileLibraryError { throw error }
            catch {
                throw ControllerProfileLibraryError.invalidResource(resource: url.lastPathComponent, path: "$", reason: error.localizedDescription)
            }
        }
        try self.init(resources: resources)
    }

    init(resources: [ControllerProfileResource]) throws {
        var entries: [Pin: ControllerProfile] = [:]
        var ordered: [ControllerProfile] = []
        guard resources.count <= 64, resources.reduce(0, { $0 + $1.data.count }) <= 64_000_000 else {
            throw ControllerProfileLibraryError.invalidResource(resource: "catalogue", path: "$", reason: "Catalogue exceeds resource count or total size limit.")
        }
        for resource in resources {
            try Self.checkBounds(resource)
            let profile: ControllerProfile
            do { profile = try JSONDecoder().decode(ControllerProfile.self, from: resource.data) }
            catch {
                throw ControllerProfileLibraryError.invalidResource(resource: resource.name, path: Self.decodingPath(error), reason: "Malformed profile: \(error.localizedDescription)")
            }
            try Self.validate(profile, resource: resource.name)
            let pin = Pin(id: profile.id, version: profile.version)
            guard entries[pin] == nil else {
                throw ControllerProfileLibraryError.invalidResource(resource: resource.name, path: "$.id", reason: "Duplicate profile ID and exact version.")
            }
            entries[pin] = profile
            ordered.append(profile)
        }
        profilesByPin = entries
        profiles = ordered
        controlsByPin = entries.mapValues { Dictionary(uniqueKeysWithValues: $0.controls.map { ($0.id, $0) }) }
    }

    func profile(id: String, version: String) throws -> ControllerProfile {
        guard let profile = profilesByPin[Pin(id: id, version: version)] else {
            throw ControllerProfileLibraryError.unavailable(id: id, version: version)
        }
        return profile
    }

    func control(id: String, profileID: String, version: String) -> ControllerProfile.Control? {
        controlsByPin[Pin(id: profileID, version: version)]?[id]
    }

    private static let maximumBytes = 12_000_000

    /// Scan before decoding so hostile nesting cannot consume decoder stack space.
    private static func checkBounds(_ resource: ControllerProfileResource) throws {
        func invalid(_ reason: String) -> ControllerProfileLibraryError {
            .invalidResource(resource: resource.name, path: "$", reason: reason)
        }
        guard resource.data.count <= maximumBytes else { throw invalid("Resource exceeds size limit.") }
        var depth = 0
        var quoted = false
        var escaped = false
        for byte in resource.data {
            if quoted {
                if escaped { escaped = false }
                else if byte == 92 { escaped = true }
                else if byte == 34 { quoted = false }
            } else if byte == 34 { quoted = true }
            else if byte == 91 || byte == 123 {
                depth += 1
                guard depth <= 32 else { throw invalid("Resource exceeds nesting limit.") }
            } else if byte == 93 || byte == 125 { depth -= 1 }
        }
    }

    private static func decodingPath(_ error: Error) -> String {
        let keys: [CodingKey]
        switch error {
        case let DecodingError.keyNotFound(key, context): keys = context.codingPath + [key]
        case let DecodingError.typeMismatch(_, context): keys = context.codingPath
        case let DecodingError.valueNotFound(_, context): keys = context.codingPath
        case let DecodingError.dataCorrupted(context): keys = context.codingPath
        default: keys = []
        }
        return keys.reduce("$") { path, key in
            path + (key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)")
        }
    }

    private static func validate(_ profile: ControllerProfile, resource: String) throws {
        func require(_ valid: Bool, _ path: String, _ reason: String) throws {
            guard valid else { throw ControllerProfileLibraryError.invalidResource(resource: resource, path: path, reason: reason) }
        }
        func text(_ value: String, _ path: String) throws {
            try require(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 16_384, path, "Expected nonempty bounded text.")
        }
        func ids(_ values: [String], _ path: String) throws -> Set<String> {
            try require(!values.isEmpty, path, "Expected at least one record.")
            var seen = Set<String>()
            for (index, value) in values.enumerated() {
                try text(value, "\(path)[\(index)].id")
                try require(seen.insert(value).inserted, "\(path)[\(index)].id", "Duplicate ID.")
            }
            return seen
        }
        func refs(_ values: [String], _ known: Set<String>, _ path: String, required: Bool = true) throws {
            try require(!required || !values.isEmpty, path, "Evidence references are required.")
            for (index, value) in values.enumerated() {
                try require(known.contains(value), "\(path)[\(index)]", "Unknown reference: \(value).")
            }
        }
        try require([1, 2].contains(profile.schemaVersion), "$.schemaVersion", "Unsupported profile schema version.")
        try text(profile.id, "$.id")
        try text(profile.version, "$.version")
        try text(profile.manufacturer, "$.manufacturer")
        try text(profile.model, "$.model")
        try require((1...16).contains(profile.defaultChannel), "$.defaultChannel", "Channel must be 1...16.")
        let sources = try ids(profile.sources.map(\.id), "$.sources")
        let evidence = try ids(profile.evidence.map(\.id), "$.evidence")
        let modes = try ids(profile.modes.map(\.id), "$.modes")
        _ = try ids(profile.unitMaps.map(\.id), "$.unitMaps")
        if profile.coverageState == .documentationOnly {
            try require(profile.schemaVersion == 2 && profile.controls.isEmpty, "$.controls", "Documentation-only profiles must have no invented controls.")
            try require(!(profile.coverageNotes ?? []).isEmpty && !profile.limitations.isEmpty, "$.coverageNotes", "Documentation-only profiles require coverage notes and limitations.")
        } else {
            _ = try ids(profile.controls.map(\.id), "$.controls")
        }
        let groups = Set(profile.controls.map(\.group))
        let ports: Set<String>
        if let records = profile.ports, !records.isEmpty {
            ports = try ids(records.map(\.id), "$.ports")
            for (index, port) in records.enumerated() { try text(port.name, "$.ports[\(index)].name") }
        } else { ports = [] }
        if profile.schemaVersion == 1 {
            try require(profile.ports == nil && profile.coverageNotes == nil && profile.coverageState == nil, "$", "Schema 2 fields require schemaVersion 2.")
        }
        for (index, note) in (profile.coverageNotes ?? []).enumerated() { try text(note, "$.coverageNotes[\(index)]") }

        for (index, source) in profile.sources.enumerated() {
            let path = "$.sources[\(index)]"
            let url = URL(string: source.url)
            try require(url?.scheme == "https" && url?.host != nil, path + ".url", "Expected an HTTPS source URL.")
            try text(source.revision, path + ".revision")
            try require(source.sha256.count == 64 && source.sha256.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }, path + ".sha256", "Expected a lowercase SHA-256 digest.")
        }
        for (index, record) in profile.evidence.enumerated() {
            let path = "$.evidence[\(index)]"
            try require(sources.contains(record.sourceID), path + ".sourceID", "Unknown source reference.")
            try text(record.locator, path + ".locator")
        }
        for (index, mode) in profile.modes.enumerated() {
            let path = "$.modes[\(index)]"
            try text(mode.name, path + ".name")
            try refs(mode.layeredGroups, groups, path + ".layeredGroups", required: false)
            try refs(mode.evidence, evidence, path + ".evidence")
        }
        for (index, map) in profile.unitMaps.enumerated() {
            try refs(map.evidence, evidence, "$.unitMaps[\(index)].evidence")
        }
        for (index, control) in profile.controls.enumerated() {
            let path = "$.controls[\(index)]"
            try text(control.physicalID, path + ".physicalID")
            try text(control.name, path + ".name")
            try text(control.group, path + ".group")
            try refs(control.reservedInModes, modes, path + ".reservedInModes", required: false)
            try refs(control.evidence, evidence, path + ".evidence")
            try require(!control.bindings.isEmpty, path + ".bindings", "Expected at least one documented binding.")
            for (bindingIndex, binding) in control.bindings.enumerated() {
                let bp = path + ".bindings[\(bindingIndex)]"
                let scalar = binding.kind == .note || binding.kind == .controlChange
                if profile.schemaVersion == 1 {
                    try require(binding.channel == nil && binding.modeID == nil && binding.portID == nil && binding.context == nil && binding.support == nil && binding.components == nil && binding.semantics == nil, bp, "Schema 2 binding fields require schemaVersion 2.")
                } else {
                    try require(binding.layer == .base, bp + ".layer", "Schema 2 contexts use explicit modes and ports, with base layer.")
                }
                if scalar {
                    try require(binding.number.map { (0...127).contains($0) } == true, bp + ".number", "Scalar MIDI number must be 0...127.")
                    try require(binding.components == nil, bp + ".components", "Scalar bindings cannot contain compound components.")
                } else {
                    try require(profile.schemaVersion == 2 && binding.number == nil, bp + ".number", "Compound and other messages require schema 2 and no scalar number.")
                    try require(binding.support == .documentedOnly, bp + ".support", "Non-scalar messages must be documentedOnly.")
                    if binding.kind == .compound { try require((binding.components?.count ?? 0) >= 2, bp + ".components", "Compound messages require at least two documented components.") }
                }
                let validEncoding: Bool
                switch binding.encoding {
                case .noteGate: validEncoding = binding.kind == .note
                case .absolute7Bit, .relativeTwosComplement: validEncoding = binding.kind == .controlChange
                case .relativeBinaryOffset: validEncoding = profile.schemaVersion == 2 && binding.kind == .controlChange
                case .paired14Bit: validEncoding = profile.schemaVersion == 2 && binding.kind == .compound
                case .palette: validEncoding = profile.schemaVersion == 2 && scalar
                case .documented, .unsupported: validEncoding = profile.schemaVersion == 2
                }
                try require(validEncoding, bp + ".encoding", "Encoding is incompatible with the MIDI message kind.")
                if let channel = binding.channel { try require((1...16).contains(channel), bp + ".channel", "Channel must be 1...16.") }
                if let modeID = binding.modeID { try require(modes.contains(modeID), bp + ".modeID", "Unknown mode reference.") }
                if let portID = binding.portID { try require(ports.contains(portID), bp + ".portID", "Unknown port reference.") }
                if let context = binding.context { try text(context, bp + ".context") }
                if let semantics = binding.semantics { try text(semantics, bp + ".semantics") }
                for (index, component) in (binding.components ?? []).enumerated() {
                    let cp = bp + ".components[\(index)]"
                    try require(component.kind == .note || component.kind == .controlChange, cp + ".kind", "Components must describe scalar Note or CC messages.")
                    try require((0...127).contains(component.number), cp + ".number", "MIDI number must be 0...127.")
                    try text(component.role, cp + ".role")
                }
                if let minimum = binding.valueMin {
                    try require((0...127).contains(minimum), bp + ".valueMin", "MIDI value must be 0...127.")
                    try require(binding.valueMax != nil, bp + ".valueMax", "Both value bounds must be specified together.")
                }
                if let maximum = binding.valueMax {
                    try require((0...127).contains(maximum), bp + ".valueMax", "MIDI value must be 0...127.")
                    try require(binding.valueMin != nil, bp + ".valueMin", "Both value bounds must be specified together.")
                }
                if let minimum = binding.valueMin, let maximum = binding.valueMax {
                    try require(minimum <= maximum, bp + ".valueMin", "Minimum exceeds maximum.")
                }
                try require(binding.color == nil || binding.direction == .receive, bp + ".color", "LED color belongs to receive bindings.")
                try refs(binding.evidence, evidence, bp + ".evidence")
            }
        }
        for (index, limitation) in profile.limitations.enumerated() {
            try text(limitation.message, "$.limitations[\(index)].message")
            try refs(limitation.evidence, evidence, "$.limitations[\(index)].evidence")
        }
        try refs(profile.configurationEvidence, evidence, "$.configurationEvidence")
    }
}
