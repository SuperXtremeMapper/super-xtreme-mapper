import Foundation

nonisolated enum SXMJSONCodec {
    static let maximumBytes = 128 * 1024 * 1024
    static let maximumTextBytes = 1024 * 1024

    static func encode(_ file: MappingFile) throws -> Data {
        let preservation = file.sourceEnvelope.map(SXMJSONPreservation.init)
        let source = try preservation?.reconstruct()
        let savedDevices = Dictionary(uniqueKeysWithValues: (file.sourceEnvelope?.baseline.devices ?? []).map { ($0.id, $0) })
        let sourceDevices = Dictionary(uniqueKeysWithValues: (source?.devices ?? []).map { ($0.id, $0) })
        let savedRows = Dictionary(uniqueKeysWithValues: (file.sourceEnvelope?.baseline.devices.flatMap(\.mappings) ?? []).map { ($0.id, $0) })
        let sourceRows = Dictionary(uniqueKeysWithValues: (source?.allMappings ?? []).map { ($0.id, $0) })
        let devices = file.devices.map { d -> SXMJSONDevice in
            let saved = savedDevices[d.id]
            let parsed = sourceDevices[d.id]
            return SXMJSONDevice(id: d.id,
                name: d.name == saved?.name ? (parsed?.name ?? d.name) : d.name,
                comment: d.comment == saved?.comment ? (parsed?.comment ?? d.comment) : d.comment,
                inPort: d.inPort == saved?.inPort ? (parsed?.inPort ?? d.inPort) : d.inPort,
                outPort: d.outPort == saved?.outPort ? (parsed?.outPort ?? d.outPort) : d.outPort,
                tsiVersion: d.tsiVersion == saved?.tsiVersion ? (parsed?.tsiVersion ?? d.tsiVersion) : d.tsiVersion,
                mappingFileRevision: d.mappingFileRevision == saved?.mappingFileRevision ? (parsed?.mappingFileRevision ?? d.mappingFileRevision) : d.mappingFileRevision,
                mappings: d.mappings.map { SXMJSONMapping($0, saved: savedRows[$0.id], source: sourceRows[$0.id]) })
        }
        let version = file.version == file.sourceEnvelope?.baseline.version ? (source?.version ?? file.version) : file.version
        let document = SXMJSONDocument(format: "sxm-mapping", schemaVersion: file.interchangeMetadata?.deviceProfiles == nil ? 1 : 2, tsiVersion: version,
            devices: devices, preservation: preservation, metadata: file.interchangeMetadata)
        // Verify projection can reconstruct all import-only state; never silently omit it.
        let restored = try mappingFile(from: document, reconstructedSource: source)
        let reconstructsExactly: Bool
        if restored == file {
            reconstructsExactly = true
        } else if let originalOutput = try? TSIWriter().write(file),
                  let restoredOutput = try? TSIWriter().write(restored) {
            // After a committed save, the live model can retain older CMAD
            // fingerprints. Reparsed state is equivalent only if actual TSI
            // output agrees byte-for-byte; never trust edited baseline claims.
            reconstructsExactly = originalOutput == restoredOutput
        } else {
            reconstructsExactly = false
        }
        guard reconstructsExactly else {
            throw SXMJSONIssue(code: "preservation.unrepresentable", path: "$",
                message: "This document contains import-only state that cannot be reconstructed from its retained source. Save and reopen its TSI before exporting JSON.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(document)
        guard bytes.count <= maximumBytes else { throw SXMJSONIssue(code: "json.resourceLimit", path: "$", message: "JSON exceeds 128 MiB.") }
        try validateStructure(bytes)
        return bytes
    }

    static func decode(_ data: Data) throws -> MappingFile {
        try mappingFile(from: document(from: data))
    }

    static func document(from data: Data) throws -> SXMJSONDocument {
        try validateStructure(data)
        do { return try JSONDecoder().decode(SXMJSONDocument.self, from: data) }
        catch let error as DecodingError { throw decodingIssue(error) }
    }

    static func mappingFile(from document: SXMJSONDocument, reconstructedSource: MappingFile? = nil) throws -> MappingFile {
        guard document.format == "sxm-mapping", [1, 2].contains(document.schemaVersion) else {
            throw SXMJSONIssue(code: "schema.version", path: "$.schemaVersion", message: "Expected sxm-mapping schema version 1 or 2.")
        }
        if document.schemaVersion == 1, document.metadata?.deviceProfiles != nil {
            throw SXMJSONIssue(code: "schema.unknownKey", path: "$.metadata.deviceProfiles", message: "Device configuration requires schema version 2.")
        }
        if let issue = ControllerProfileMetadataValidation.validate(document).first(where: { $0.severity == .error }) {
            throw SXMJSONIssue(code: issue.code, path: issue.path, message: issue.message)
        }
        let source = try reconstructedSource ?? document.preservation?.reconstruct()
        let sourceDevices = Dictionary(uniqueKeysWithValues: (source?.devices ?? []).map { ($0.id, $0) })
        let sourceRows = Dictionary(uniqueKeysWithValues: (source?.allMappings ?? []).map { ($0.id, $0) })
        let sourceOwners = Dictionary(uniqueKeysWithValues: (source?.devices ?? []).flatMap { d in d.mappings.map { ($0.id, d.id) } })
        var ids = Set<UUID>()
        var devices: [Device] = []
        for (di, d) in document.devices.enumerated() {
            let dp = "$.devices[\(di)]"
            guard ids.insert(d.id).inserted, sourceRows[d.id] == nil else { throw duplicate(dp + ".id") }
            var rows: [MappingEntry] = []
            for (mi, m) in d.mappings.enumerated() {
                let mp = dp + ".mappings[\(mi)]"
                guard ids.insert(m.id).inserted, sourceDevices[m.id] == nil else { throw duplicate(mp + ".id") }
                if let owner = sourceOwners[m.id], owner != d.id {
                    throw SXMJSONIssue(code: "preservation.identity", path: mp + ".id", message: "An original mapping identity belongs to a different source device. Use a new UUID for a new row.")
                }
                do {
                    let row = try m.model(source: sourceRows[m.id])
                    for (name, value, original) in [("setToValue", row.setToValue, sourceRows[m.id]?.setToValue),
                        ("rotarySensitivity", row.rotarySensitivity, sourceRows[m.id]?.rotarySensitivity),
                        ("rotaryAcceleration", row.rotaryAcceleration, sourceRows[m.id]?.rotaryAcceleration)] {
                        if !value.isFinite && value.bitPattern != original?.bitPattern {
                            throw SXMJSONIssue(code: "preservation.float", path: mp + "." + name,
                                message: "Nonfinite values are allowed only unchanged from verified source bits.")
                        }
                    }
                    rows.append(row)
                } catch let issue as SXMJSONIssue {
                    if issue.path != "$" { throw issue }
                    throw SXMJSONIssue(code: issue.code, path: mp, message: issue.message)
                } catch {
                    throw SXMJSONIssue(code: "schema.midi", path: mp + ".midi", message: error.localizedDescription)
                }
            }
            devices.append(Device(id: d.id, name: d.name, comment: d.comment, inPort: d.inPort, outPort: d.outPort,
                importedIdentity: sourceDevices[d.id]?.importedIdentity, tsiVersion: d.tsiVersion,
                mappingFileRevision: d.mappingFileRevision, mappings: rows))
        }
        var file = MappingFile(devices: devices, version: document.tsiVersion, sourceEnvelope: source?.sourceEnvelope)
        file.interchangeMetadata = document.metadata
        return file
    }

    private static func duplicate(_ path: String) -> SXMJSONIssue {
        SXMJSONIssue(code: "schema.duplicateID", path: path, message: "Every device and mapping must have a unique UUID.")
    }

    static func decodingIssue(_ error: DecodingError) -> SXMJSONIssue {
        let context: DecodingError.Context
        var suffix = ""
        switch error {
        case .keyNotFound(let key, let c): context = c; suffix = "." + key.stringValue
        case .dataCorrupted(let c), .typeMismatch(_, let c), .valueNotFound(_, let c): context = c
        @unknown default: return SXMJSONIssue(code: "schema.invalid", path: "$", message: "Invalid JSON document.")
        }
        let path = context.codingPath.reduce("$") { result, key in
            result + (key.intValue.map { "[\($0)]" } ?? ".\(key.stringValue)")
        }
        return SXMJSONIssue(code: "schema.invalid", path: path + suffix, message: context.debugDescription)
    }

    /// The scanner validates grammar before Foundation materializes the bounded tree.
    static func validateStructure(_ data: Data) throws {
        try SXMJSONScanner.validate(data, maximumBytes: maximumBytes)
        let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        try check(object, shape: "document", path: "$", version: (object as? [String: Any])?["schemaVersion"] as? Int ?? 1)
    }

    /// A disclosure gate, stricter about container shapes than import diagnostics.
    /// Uses the interchange key allowlists so unknown nested objects cannot carry
    /// opaque source text into an AI request. Wrong scalar types/values stay
    /// eligible for correction; unexpected objects/arrays must be fixed locally.
    /// The root preservation value is excluded: the repair input protects and
    /// redacts its complete original byte range without interpreting its contents.
    static func validateRepairVisibility(_ root: [String: Any]) throws {
        try checkRepairVisibility(root, shape: "document", depth: 0)
    }

    private static func checkRepairVisibility(_ value: Any, shape: String, depth: Int) throws {
        guard depth <= 64, let object = value as? [String: Any],
              let allowed = keys[shape], Set(object.keys).isSubset(of: allowed) else {
            throw JSONRepairError.unsafeInput
        }
        for (key, child) in object {
            if shape == "document", key == "preservation" { continue }
            if child is NSNull { continue }
            let objectShape: String?
            let arrayShape: String?
            switch (shape, key) {
            case ("document", "metadata"): objectShape = "metadataV2"; arrayShape = nil
            case ("document", "devices"): objectShape = nil; arrayShape = "device"
            case ("device", "mappings"): objectShape = nil; arrayShape = "mapping"
            case ("mapping", "midi"), ("controlOverride", "midi"), ("override", "midi"):
                objectShape = "midi"; arrayShape = nil
            case ("mapping", "modifier1Condition"), ("mapping", "modifier2Condition"):
                objectShape = "condition"; arrayShape = nil
            case ("mapping", "setToValue"), ("mapping", "rotarySensitivity"), ("mapping", "rotaryAcceleration"):
                objectShape = child is [String: Any] ? "float" : nil; arrayShape = nil
            case ("metadataV2", "profileReferences"): objectShape = nil; arrayShape = "profile"
            case ("metadataV2", "physicalControls"): objectShape = nil; arrayShape = "control"
            case ("metadataV2", "localOverrides"): objectShape = nil; arrayShape = "override"
            case ("metadataV2", "deviceProfiles"): objectShape = nil; arrayShape = "deviceProfile"
            case ("deviceProfile", "configuration"): objectShape = "configuration"; arrayShape = nil
            case ("configuration", "overrides"): objectShape = nil; arrayShape = "controlOverride"
            default: objectShape = nil; arrayShape = nil
            }
            if let objectShape {
                try checkRepairVisibility(child, shape: objectShape, depth: depth + 1)
            } else if let arrayShape {
                guard let array = child as? [Any] else { throw JSONRepairError.unsafeInput }
                for item in array { try checkRepairVisibility(item, shape: arrayShape, depth: depth + 1) }
            } else {
                guard !(child is [String: Any]), !(child is [Any]) else { throw JSONRepairError.unsafeInput }
            }
        }
    }

    private static let keys: [String: Set<String>] = [
        "document": ["format", "schemaVersion", "tsiVersion", "devices", "preservation", "metadata"],
        "device": ["id", "name", "comment", "inPort", "outPort", "tsiVersion", "mappingFileRevision", "mappings"],
        "mapping": ["id", "commandID", "commandName", "ioType", "assignment", "interactionMode", "midi", "modifier1Condition", "modifier2Condition", "comment", "controllerType", "invert", "softTakeover", "setToValue", "rotarySensitivity", "rotaryAcceleration", "encoderMode", "autoRepeat", "ledMinRangeType", "ledMinRangeData", "ledMaxRangeType", "ledMaxRangeData", "ledMinMidi", "ledMaxMidi", "ledInvert", "ledBlend", "resolution"],
        "midi": ["kind", "channel", "number"], "condition": ["modifier", "value", "target", "rawTarget"],
        "float": ["sourceBits"], "preservation": ["originalXML", "devices"], "sourceDevice": ["id", "mappingIDs"],
        "metadata": ["profileReferences", "physicalControls", "localOverrides"],
        "metadataV2": ["profileReferences", "physicalControls", "localOverrides", "deviceProfiles"],
        "deviceProfile": ["deviceID", "configuration"],
        "configuration": ["profileID", "version", "globalChannel", "layerMode", "unitMap", "feedbackMode", "overrides"],
        "controlOverride": ["controlID", "layerMode", "unitMap", "layer", "direction", "midi", "provenance"],
        "profile": ["profileID", "version"], "control": ["mappingID", "profileID", "controlID"], "override": ["mappingID", "midi"]
    ]

    private static func check(_ value: Any, shape: String, path: String, version: Int) throws {
        guard let object = value as? [String: Any] else {
            throw SXMJSONIssue(code: "schema.type", path: path, message: "Expected an object.")
        }
        for key in object.keys.sorted() where keys[shape]?.contains(key) != true {
            throw SXMJSONIssue(code: "schema.unknownKey", path: path + "." + key,
                message: "Unknown field '\(key)'. Check its spelling against the selected schema.")
        }
        for key in object.keys.sorted() {
            let child = object[key]!
            let cp = path + "." + key
            if let string = child as? String, key != "originalXML", string.utf8.count > maximumTextBytes {
                throw SXMJSONIssue(code: "json.resourceLimit", path: cp, message: "Text exceeds 1 MiB of UTF-8.")
            }
            let childShape: String?
            switch key {
            case "midi": childShape = "midi"
            case "modifier1Condition", "modifier2Condition": childShape = "condition"
            case "preservation", "configuration": childShape = key
            case "metadata": childShape = version == 2 ? "metadataV2" : "metadata"
            case "setToValue", "rotarySensitivity", "rotaryAcceleration": childShape = child is [String: Any] ? "float" : nil
            default: childShape = nil
            }
            if let childShape, !(child is NSNull) { try check(child, shape: childShape, path: cp, version: version) }
            if let array = child as? [Any] {
                let element: String?
                switch key {
                case "devices": element = shape == "preservation" ? "sourceDevice" : "device"
                case "mappings": element = "mapping"
                case "profileReferences": element = "profile"
                case "physicalControls": element = "control"
                case "localOverrides": element = "override"
                case "deviceProfiles": element = "deviceProfile"
                case "overrides": element = "controlOverride"
                default: element = nil
                }
                if key == "devices", array.count > 256 { throw SXMJSONIssue(code: "json.resourceLimit", path: cp, message: "At most 256 devices are allowed.") }
                if key == "deviceProfiles", array.count > 256 { throw SXMJSONIssue(code: "json.resourceLimit", path: cp, message: "At most 256 device profiles are allowed.") }
                if ["profileReferences", "physicalControls", "localOverrides", "overrides"].contains(key), array.count > 100_000 { throw SXMJSONIssue(code: "json.resourceLimit", path: cp, message: "At most 100,000 metadata records are allowed per array.") }
                if let element {
                    for (i, item) in array.enumerated() { try check(item, shape: element, path: cp + "[\(i)]", version: version) }
                }
            }
        }
        if shape == "document" {
            let devices = object["devices"] as? [[String: Any]] ?? []
            let count = devices.reduce(0) { $0 + (($1["mappings"] as? [Any])?.count ?? 0) }
            guard count <= 100_000 else { throw SXMJSONIssue(code: "json.resourceLimit", path: "$.devices", message: "At most 100,000 mappings are allowed.") }
        }
    }
}
