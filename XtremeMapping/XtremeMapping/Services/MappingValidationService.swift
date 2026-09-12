import Foundation

nonisolated enum MappingValidationService {
    static func validate(_ document: SXMJSONDocument, source: MappingFile?) -> [MappingDiagnostic] {
        var issues: [MappingDiagnostic] = []
        let originals = Dictionary(uniqueKeysWithValues: (source?.allMappings ?? []).map { ($0.id, $0) })
        var ids = Set<UUID>()
        func emit(_ code: String, _ path: String, _ message: String,
                  _ severity: MappingDiagnosticSeverity = .error, device: UUID? = nil, row: UUID? = nil,
                  suggestion: String? = nil) {
            issues.append(MappingDiagnostic(code: code, severity: severity, path: path,
                deviceID: device, mappingID: row, message: message, suggestion: suggestion))
        }
        if document.tsiVersion < 0 || document.tsiVersion > Int(UInt32.max) {
            emit("value.range", "$.tsiVersion", "TSI version must fit an unsigned 32-bit integer.")
        }
        for (di, device) in document.devices.enumerated() {
            let dp = "$.devices[\(di)]"
            if !ids.insert(device.id).inserted { emit("schema.duplicateID", dp + ".id", "Duplicate UUID.", device: device.id) }
            if !(0...Int(UInt32.max)).contains(device.mappingFileRevision) {
                emit("value.range", dp + ".mappingFileRevision", "Revision must fit an unsigned 32-bit integer.", device: device.id)
            }
            var bindings: [String: UUID] = [:]
            for (mi, row) in device.mappings.enumerated() {
                let p = dp + ".mappings[\(mi)]"
                let original = originals[row.id]
                func issue(_ code: String, _ field: String, _ message: String,
                           _ severity: MappingDiagnosticSeverity = .error, suggestion: String? = nil) {
                    emit(code, p + "." + field, message, severity, device: device.id, row: row.id, suggestion: suggestion)
                }
                if !ids.insert(row.id).inserted { issue("schema.duplicateID", "id", "Every device and row needs a unique UUID.") }
                if !(1...16).contains(row.midi.channel) { issue("midi.channel", "midi.channel", "MIDI channel must be 1–16.") }
                if row.midi.kind == .unassigned {
                    if row.midi.number != nil { issue("midi.number", "midi.number", "Unassigned MIDI must omit number.") }
                } else if !(0...127).contains(row.midi.number ?? -1) {
                    issue("midi.number", "midi.number", "MIDI note or CC number must be 0–127.")
                }
                let descriptor = TraktorCommands.descriptor(for: row.commandID)
                let inheritedCommand = original?.commandID == row.commandID
                let expectedName = row.commandID == 0 ? "" : descriptor.name
                if let name = row.commandName, name != expectedName {
                    issue("command.nameConflict", "commandName", "Command \(row.commandID) is '\(expectedName)', not '\(name)'.",
                        suggestion: "Update commandName to '\(expectedName)' or omit it; commandID is authoritative.")
                }
                if row.commandID <= 0 || row.commandID > Int(UInt32.max) || descriptor.verification == .unknown {
                    issue("command.unknown", "commandID", inheritedCommand
                        ? "Unrecognized source command is retained; TSI output depends on preservation checks."
                        : "This command ID is not in the local catalogue. Choose a known command ID.", inheritedCommand ? .warning : .error)
                }
                let knownInvalidDirection = row.ioType == .all || (!descriptor.supportedDirections.isEmpty && !descriptor.supports(row.ioType.model))
                if knownInvalidDirection {
                    let unchanged = inheritedCommand && original?.ioType == row.ioType.model
                    issue("command.direction", "ioType", unchanged
                        ? "Source direction is outside current catalogue evidence and remains preserved."
                        : "This direction is not supported for the selected command.", unchanged ? .warning : .error)
                }
                if !(inheritedCommand && original?.assignment == row.assignment.model) {
                    if TraktorCommands.usesFXUnitTargetEncoding(row.commandID), row.assignment.model.fxUnitCommandTargetValue == nil {
                        issue("command.target", "assignment", "This command requires an FX unit target.")
                    }
                    if [239, 249, 250, 251, 259].contains(row.commandID), row.assignment.model.remixSlotCommandTargetValue == nil {
                        issue("command.target", "assignment", "This command requires a Remix Deck slot target.")
                    }
                }
                let value = row.setToValue.value
                let unchangedValue = inheritedCommand && original?.setToValue.bitPattern == value.bitPattern
                    && original?.controllerType == row.controllerType.model && original?.ioType == row.ioType.model
                if !unchangedValue, row.ioType != .output {
                    var allowed = true
                    if row.commandID == 2328 || row.commandID == 2331 {
                        allowed = value.isFinite && value.rounded() == value && (-1...7).contains(value)
                    } else if (2548...2555).contains(row.commandID) {
                        allowed = value.isFinite && value.rounded() == value && (0...7).contains(value)
                    } else if row.commandID == TraktorLoopValueMetadata.commandID {
                        allowed = TraktorLoopValueMetadata.choices.contains { $0.value == value }
                    } else if TraktorCommands.usesBooleanValueEncoding(row.commandID) {
                        allowed = value == 0 || value == 1
                    } else if row.controllerType == .none || row.controllerType == .led {
                        // The writer uses UInt32 for its unmodeled-controller fallback.
                        allowed = value.isFinite && value.rounded() == value && Double(value) >= 0 && Double(value) <= Double(UInt32.max)
                    }
                    if !allowed { issue("value.setToValue", "setToValue", "This value is outside the command's supported selector or wire range. Choose a valid integer selector.") }
                }
                if row.controllerType == .led && row.ioType != .output,
                   !(original?.controllerType == .led && original?.ioType == row.ioType.model) {
                    issue("mapping.controllerDirection", "controllerType", "LED controllers require output direction.")
                }
                if !row.controllerType.model.validInteractionModes.contains(row.interactionMode.model),
                   !(original?.controllerType == row.controllerType.model && original?.interactionMode == row.interactionMode.model) {
                    issue("mapping.interaction", "interactionMode", "Choose an interaction mode supported by this controller type.")
                }
                for (name, value, prior) in [("ledMinMidi", row.ledMinMidi, original?.ledMinMidi), ("ledMaxMidi", row.ledMaxMidi, original?.ledMaxMidi)] {
                    if !(0...127).contains(value), value != prior { issue("value.range", name, "MIDI output value must be 0–127.") }
                }
                for (name, value) in [("ledMinRangeType", row.ledMinRangeType), ("ledMaxRangeType", row.ledMaxRangeType),
                    ("ledMinRangeData", row.ledMinRangeData), ("ledMaxRangeData", row.ledMaxRangeData), ("resolution", row.resolution)] {
                    if !(0...Int(UInt32.max)).contains(value) { issue("value.range", name, "Value must fit an unsigned 32-bit wire field.") }
                }
                for (name, condition, previous) in [("modifier1Condition", row.modifier1Condition, original?.modifier1Condition),
                                                    ("modifier2Condition", row.modifier2Condition, original?.modifier2Condition)] {
                    guard let condition else { continue }
                    if let model = try? condition.model(), model == previous { continue }
                    if !(1...Int(UInt32.max)).contains(condition.modifier) {
                        issue("condition.identifier", name + ".modifier", "Condition identifier must be positive and fit an unsigned 32-bit value.")
                    }
                    let values = TraktorConditionMetadata.values(for: condition.modifier)
                    if values.isEmpty {
                        issue("condition.unknown", name + ".modifier", "Unknown condition can only be retained unchanged from source.")
                    } else if !values.contains(where: { $0.rawValue == condition.value }) {
                        issue("condition.value", name + ".value", "Choose a supported value for this condition.")
                    }
                    if let model = try? condition.model() {
                        let targets = TraktorConditionMetadata.targets(for: condition.modifier)
                        if !targets.isEmpty && !targets.contains(model.target) {
                            issue("condition.target", name + ".target", "Choose a supported target for this condition.")
                        } else if targets.isEmpty && !TraktorConditionMetadata.targets.contains(model.target) {
                            issue("condition.target", name + ".target", "Opaque targets can only be retained unchanged from source.")
                        }
                    }
                }
                if row.midi.kind != .unassigned {
                    let binding = "\(row.ioType.rawValue)/\(row.midi.kind.rawValue)/\(row.midi.channel)/\(row.midi.number ?? -1)"
                    if let prior = bindings[binding] {
                        issue("mapping.overlap", "midi", "MIDI address is also used by mapping \(prior). Layers may make this intentional.", .warning)
                    } else { bindings[binding] = row.id }
                }
            }
        }
        if let metadata = document.metadata {
            for (i, profile) in metadata.profileReferences.enumerated() {
                emit("profile.unresolved", "$.metadata.profileReferences[\(i)]", "Profile '\(profile.profileID)' is retained as metadata; local profile resolution is not available.", .information)
            }
            let rowIDs = Set(document.devices.flatMap(\.mappings).map(\.id))
            for (i, control) in metadata.physicalControls.enumerated() where !rowIDs.contains(control.mappingID) {
                emit("metadata.reference", "$.metadata.physicalControls[\(i)].mappingID", "Physical control references a missing mapping.")
            }
            for (i, override) in metadata.localOverrides.enumerated() {
                if !rowIDs.contains(override.mappingID) { emit("metadata.reference", "$.metadata.localOverrides[\(i)].mappingID", "Local override references a missing mapping.") }
                if (try? override.midi.model()) == nil { emit("metadata.midi", "$.metadata.localOverrides[\(i)].midi", "Local override requires a valid MIDI assignment.") }
            }
        }
        return issues
    }
}
