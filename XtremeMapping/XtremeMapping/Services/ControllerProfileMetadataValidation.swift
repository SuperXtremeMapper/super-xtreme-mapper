import Foundation

/// Annotations never change generic MIDI assignments. Unavailable references survive with warnings.
nonisolated enum ControllerProfileMetadataValidation {
    private struct Pin: Hashable {
        let id: String
        let version: String?
    }
    static func validate(_ document: SXMJSONDocument) -> [MappingDiagnostic] {
        guard let metadata = document.metadata else { return [] }
        let library = try? ControllerProfileLibrary()
        let deviceIDs = Set(document.devices.map(\.id))
        let rowIDs = Set(document.devices.flatMap(\.mappings).map(\.id))
        var issues: [MappingDiagnostic] = []
        func emit(_ code: String, _ path: String, _ message: String, _ severity: MappingDiagnosticSeverity = .warning) {
            issues.append(MappingDiagnostic(code: code, severity: severity, path: path, message: message,
                suggestion: severity == .warning ? "Check the annotation against the intended controller and exact profile version. Generic MIDI assignments remain available." : "Correct this annotation before importing."))
        }
        var checkedPins = Set<Pin>()
        var availableProfiles: [Pin: ControllerProfile] = [:]
        func profile(_ id: String, _ version: String?, _ path: String) -> ControllerProfile? {
            let pin = Pin(id: id, version: version)
            if checkedPins.insert(pin).inserted,
               let version, let result = try? library?.profile(id: id, version: version) {
                availableProfiles[pin] = result
            }
            guard let result = availableProfiles[pin] else {
                emit("profile.unresolved", path, "Profile '\(id)' at exact version '\(version ?? "unspecified")' is unavailable; the original reference is retained.")
                return nil
            }
            return result
        }
        // Build this index once per distinct exact pin, while retaining a diagnostic
        // for every unavailable reference at its original document path.
        var indexedPins = Set<Pin>()
        var controlIDsByProfile: [String: Set<String>] = [:]
        for (i, reference) in metadata.profileReferences.enumerated() {
            let known = profile(reference.profileID, reference.version, "$.metadata.profileReferences[\(i)]")
            let pin = Pin(id: reference.profileID, version: reference.version)
            if indexedPins.insert(pin).inserted, let known {
                controlIDsByProfile[reference.profileID, default: []].formUnion(known.controls.map(\.id))
            }
        }
        for (i, control) in metadata.physicalControls.enumerated() {
            let path = "$.metadata.physicalControls[\(i)]"
            if !rowIDs.contains(control.mappingID) { emit("metadata.reference", path + ".mappingID", "Physical control references a missing mapping.") }
            if controlIDsByProfile[control.profileID]?.contains(control.controlID) != true {
                emit("profile.controlUnresolved", path + ".controlID", "The annotated control cannot be resolved from its exact profile references; the annotation is retained.")
            }
        }
        for (i, override) in metadata.localOverrides.enumerated() {
            let path = "$.metadata.localOverrides[\(i)]"
            if !rowIDs.contains(override.mappingID) { emit("metadata.reference", path + ".mappingID", "Local override references a missing mapping.") }
            if (try? override.midi.model()) == nil { emit("metadata.midi", path + ".midi", "Local override requires a valid MIDI assignment.", .error) }
        }
        var seenDevices = Set<UUID>()
        for (i, annotation) in (metadata.deviceProfiles ?? []).enumerated() {
            let path = "$.metadata.deviceProfiles[\(i)]"
            let configuration = annotation.configuration
            if !seenDevices.insert(annotation.deviceID).inserted { emit("metadata.duplicateDevice", path + ".deviceID", "Only one controller configuration is allowed per device.", .error) }
            if !deviceIDs.contains(annotation.deviceID) { emit("metadata.reference", path + ".deviceID", "Controller configuration references a missing device; it is retained for repair.") }
            if !(1...16).contains(configuration.globalChannel) { emit("metadata.channel", path + ".configuration.globalChannel", "Controller MIDI channel must be 1–16.", .error) }
            let known = profile(configuration.profileID, configuration.version, path + ".configuration")
            if let known {
                if !known.modes.contains(where: { $0.id == configuration.layerMode }) { emit("profile.configurationUnresolved", path + ".configuration.layerMode", "Layer mode '\(configuration.layerMode)' is unsupported by this exact profile; the setting is retained.") }
                if !known.unitMaps.contains(where: { $0.id == configuration.unitMap }) { emit("profile.configurationUnresolved", path + ".configuration.unitMap", "Unit map '\(configuration.unitMap)' is unsupported by this exact profile; the setting is retained.") }
            }
            if !["unknown", "remote", "linked"].contains(configuration.feedbackMode) { emit("profile.configurationUnresolved", path + ".configuration.feedbackMode", "Unknown feedback mode is retained without interpreting feedback addresses.") }
            var identities = Set<[String]>()
            for (j, override) in configuration.overrides.enumerated() {
                let op = path + ".configuration.overrides[\(j)]"
                let identity = [override.controlID, override.layerMode, override.unitMap, override.layer.rawValue, override.direction.rawValue]
                if !identities.insert(identity).inserted { emit("metadata.duplicateOverride", op, "Duplicate override for this control, mode, map, layer and direction.", .error) }
                if (try? override.midi.model()) == nil || override.midi.kind == .unassigned { emit("metadata.midi", op + ".midi", "Control override requires an assigned MIDI note or CC on channel 1–16 with number 0–127.", .error) }
                if let known {
                    if !known.controls.contains(where: { $0.id == override.controlID }) { emit("profile.controlUnresolved", op + ".controlID", "Unknown control override is retained for its exact profile pin.") }
                    if !known.modes.contains(where: { $0.id == override.layerMode }) || !known.unitMaps.contains(where: { $0.id == override.unitMap }) { emit("profile.configurationUnresolved", op, "Override context is unsupported by this profile and remains retained without applying it to another context.") }
                }
            }
        }
        return issues
    }
}
