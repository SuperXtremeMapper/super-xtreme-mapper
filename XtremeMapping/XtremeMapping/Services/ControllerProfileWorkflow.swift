import Foundation

/// Stages controller annotations independently of the document's generic MIDI rows.
nonisolated enum ControllerProfileWorkflow {
    enum Failure: Error, LocalizedError {
        case locked
        case stale
        case missingDevice
        case unassignedOverride
        case invalidConfiguration(String)

        var errorDescription: String? {
            switch self {
            case .locked: return "Unlock the mapping before changing its controller profile."
            case .stale: return "Controller annotations changed while these settings were open. Reopen the settings to apply your changes."
            case .missingDevice: return "This device is no longer in the mapping."
            case .unassignedOverride: return "Choose or learn a MIDI note or CC before recording an override."
            case .invalidConfiguration(let message): return message
            }
        }
    }

    static func apply(configuration: ControllerConfiguration?, deviceID: UUID,
                      expectedMetadata: SXMJSONMetadata?, isLocked: Bool,
                      to file: inout MappingFile) throws {
        guard !isLocked else { throw Failure.locked }
        guard file.interchangeMetadata == expectedMetadata else { throw Failure.stale }
        guard file.devices.contains(where: { $0.id == deviceID }) else { throw Failure.missingDevice }

        let existing = file.interchangeMetadata?.deviceProfiles ?? []
        if let configuration {
            // Validate only the staged configuration. Unrelated annotations are retained as-is.
            let candidate = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [],
                deviceProfiles: [.init(deviceID: deviceID, configuration: configuration)])
            let document = SXMJSONDocument(format: "sxm-mapping", schemaVersion: 2, tsiVersion: 1,
                devices: [], preservation: nil, metadata: candidate)
            if let issue = ControllerProfileMetadataValidation.validate(document).first(where: { $0.severity == .error }) {
                throw Failure.invalidConfiguration(issue.message)
            }
            if existing.filter({ $0.deviceID == deviceID }).map(\.configuration) == [configuration] { return }
        } else if !existing.contains(where: { $0.deviceID == deviceID }) {
            return
        }

        var metadata = file.interchangeMetadata ?? SXMJSONMetadata(
            profileReferences: [], physicalControls: [], localOverrides: [])
        var profiles = existing
        if let configuration {
            let annotation = SXMJSONMetadata.DeviceProfile(deviceID: deviceID, configuration: configuration)
            if let index = profiles.firstIndex(where: { $0.deviceID == deviceID }) {
                profiles[index] = annotation
                profiles = profiles.enumerated().filter { $0.offset == index || $0.element.deviceID != deviceID }.map(\.element)
            } else {
                profiles.append(annotation)
            }
            let pin = SXMJSONMetadata.Profile(profileID: configuration.profileID, version: configuration.version)
            if !metadata.profileReferences.contains(pin) { metadata.profileReferences.append(pin) }
        } else {
            profiles.removeAll { $0.deviceID == deviceID }
        }
        metadata.deviceProfiles = profiles
        file.interchangeMetadata = metadata
    }

    static func setOverride(controlID: String, layer: ControllerProfile.Layer,
                            direction: ControllerProfile.Direction, midi: MIDIAssignment,
                            provenance: ControllerControlOverride.Provenance,
                            in configuration: inout ControllerConfiguration) throws {
        guard midi.kind != .unassigned else { throw Failure.unassignedOverride }
        let override = ControllerControlOverride(controlID: controlID,
            layerMode: configuration.layerMode, unitMap: configuration.unitMap,
            layer: layer, direction: direction, midi: SXMJSONMIDI(midi), provenance: provenance)
        func matches(_ item: ControllerControlOverride) -> Bool {
            item.controlID == controlID && item.layerMode == override.layerMode &&
            item.unitMap == override.unitMap && item.layer == layer && item.direction == direction
        }
        if let index = configuration.overrides.firstIndex(where: matches) {
            configuration.overrides[index] = override
            configuration.overrides = configuration.overrides.enumerated()
                .filter { $0.offset == index || !matches($0.element) }.map(\.element)
        } else {
            configuration.overrides.append(override)
        }
    }
}
