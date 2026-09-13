import Foundation

nonisolated struct MappingExplanationSnapshot: Codable, Sendable, Equatable {
    let title: String
    let revision: String
    let devices: [ExplanationDevice]
    let rows: [ExplanationRow]
    let limitations: [String]

    static func build(file: MappingFile, title: String, revision: String) throws -> Self {
        try Task.checkCancellation()
        let metadata = file.interchangeMetadata
        var configurations: [UUID: ControllerConfiguration] = [:]
        for annotation in metadata?.deviceProfiles ?? [] where configurations[annotation.deviceID] == nil {
            configurations[annotation.deviceID] = annotation.configuration
        }
        let controlsByRow = Dictionary(grouping: metadata?.physicalControls ?? [], by: \.mappingID)
        let library = try? ControllerProfileLibrary()
        let resolver = library.map(ControllerControlResolver.init(library:))
        var snapshotLimitations: [String] = (file.sourceEnvelope?.risks ?? []).map { risk in
            let detail = risk.detail.isEmpty ? "" : " (\(risk.detail))"
            return "Preserved native source uncertainty [\(risk.code.rawValue)] at \(risk.path)\(detail). The original source bytes are retained outside explanation context."
        }
        if file.sourceEnvelope == nil {
            for (deviceIndex, device) in file.devices.enumerated() {
                for (rowIndex, row) in device.mappings.enumerated() {
                    guard let imported = row.importedCMAD else { continue }
                    let location = "device \(deviceIndex + 1), row \(rowIndex + 1)"
                    if imported.payload.count < imported.expectedCompleteLength {
                        snapshotLimitations.append("Preserved native source uncertainty [partialCMAD] at \(location); the imported settings tail is incomplete.")
                    } else if !imported.trailingBytes.isEmpty {
                        snapshotLimitations.append("Preserved native source uncertainty [extendedCMAD] at \(location); trailing native data is opaque.")
                    }
                    if imported.commentWasLossy {
                        snapshotLimitations.append("Preserved native source uncertainty [lossyString] at \(location); the imported comment required lossy decoding.")
                    }
                }
            }
        }
        if library == nil, !(metadata?.deviceProfiles ?? []).isEmpty {
            snapshotLimitations.append("The bundled controller profile catalogue could not be loaded; saved profile pins remain listed without catalogue evidence.")
        }

        var devices: [ExplanationDevice] = []
        var rows: [ExplanationRow] = []
        for device in file.devices {
            try Task.checkCancellation()
            let configuration = configurations[device.id]
            var deviceLimitations: [String] = []
            let profile: String
            if let configuration {
                profile = "\(configuration.profileID)@\(configuration.version)"
                if let library, (try? library.profile(id: configuration.profileID, version: configuration.version)) == nil {
                    deviceLimitations.append("The exact pinned profile \(profile) is unavailable; no substitute profile was used.")
                }
                if let library, let pinned = try? library.profile(id: configuration.profileID, version: configuration.version) {
                    if pinned.coverageState == .documentationOnly {
                        deviceLimitations.append("This controller has documentation only: no physical-control addresses are established. MIDI Learn or a verified template is needed; do not infer manufacturer addresses.")
                    } else if pinned.coverageState == .partial {
                        deviceLimitations.append("This controller has partial MIDI coverage. Only listed bindings are established; missing controls and source conflicts remain unresolved.")
                    }
                    if !pinned.modes.contains(where: { $0.id == configuration.layerMode }) {
                        deviceLimitations.append("Configured layer mode \(configuration.layerMode) is absent from the exact pinned profile.")
                    }
                    if !pinned.unitMaps.contains(where: { $0.id == configuration.unitMap }) {
                        deviceLimitations.append("Configured unit map \(configuration.unitMap) is absent from the exact pinned profile.")
                    }
                }
                if !(1...16).contains(configuration.globalChannel) {
                    deviceLimitations.append("Configured MIDI channel \(configuration.globalChannel) is outside the valid 1...16 range.")
                }
                if configuration.unitMap != "factory" {
                    deviceLimitations.append("Custom unit map \(configuration.unitMap) addresses are unknown unless a matching explicit override supplies evidence.")
                }
                if configuration.feedbackMode == "unknown" {
                    deviceLimitations.append("Hardware feedback mode is unknown; output/LED behavior may depend on the device's configured mode.")
                }
            } else {
                profile = "No profile selected"
                deviceLimitations.append("No exact controller profile is pinned, so physical-control identity cannot be inferred from MIDI alone.")
            }
            let settings = [
                "Input port: \(device.inPort.isEmpty ? "Unspecified" : device.inPort)",
                "Output port: \(device.outPort.isEmpty ? "Unspecified" : device.outPort)",
                "TSI version: \(device.tsiVersion)",
                "Mapping revision: \(device.mappingFileRevision)"
            ] + (configuration.map {
                ["MIDI channel: \($0.globalChannel)", "Layer mode: \($0.layerMode)",
                 "Unit map: \($0.unitMap)", "Feedback mode: \($0.feedbackMode)"]
            } ?? [])
            devices.append(ExplanationDevice(id: device.id, name: device.name, comment: device.comment,
                                             profile: profile, settings: settings, limitations: deviceLimitations))

            let inferredControls = try profileMatches(device: device, configuration: configuration,
                                                      library: library, resolver: resolver)

            for (index, entry) in device.mappings.enumerated() {
                try Task.checkCancellation()
                var limitations: [String] = deviceLimitations
                var sources: [String] = []
                var controls: [String] = []
                let command = entry.commandDescriptor.name
                if !TraktorCommands.isKnownCommand(command) {
                    limitations.append("Unknown command ID \(entry.commandID); its behavior is not present in the command catalogue.")
                }
                if entry.rawMidiControlName != nil || entry.rawMidiBindingID != nil {
                    limitations.append("Opaque or unresolved imported MIDI is preserved, but its complete behavior is unknown.")
                }
                if entry.rawDCDTControlType != nil || entry.rawDCDTMinValueBits != nil ||
                    entry.rawDCDTMaxValueBits != nil || entry.rawDCDTEncoderMode != nil || entry.rawDCDTControlID != nil {
                    limitations.append("Opaque imported controller details are preserved as raw values and cannot be fully interpreted.")
                }
                if let imported = entry.importedCMAD {
                    if imported.payload.count < imported.expectedCompleteLength {
                        limitations.append("Preserved native row uncertainty [partialCMAD]: the imported settings tail is incomplete, so displayed defaults may not describe the source.")
                    } else if imported.payload.count > imported.expectedCompleteLength {
                        limitations.append("Preserved native row uncertainty [extendedCMAD]: trailing native settings are opaque.")
                    }
                    if imported.commentWasLossy {
                        limitations.append("Preserved native row uncertainty [lossyString]: the imported comment required lossy decoding.")
                    }
                    if imported.deviceType != 4 {
                        limitations.append("Preserved native row uncertainty [proprietaryDeviceType]: device type \(imported.deviceType) is unknown; the displayed model value is a fallback.")
                    }
                    if ![0, 1, 2, 65_535].contains(imported.controllerType) {
                        limitations.append("Preserved native row uncertainty [coercedControllerType]: controller type \(imported.controllerType) is unknown; \(entry.controllerType.displayName) is a fallback.")
                    }
                    if !(0...8).contains(imported.interactionMode) {
                        limitations.append("Preserved native row uncertainty [coercedInteractionMode]: interaction mode \(imported.interactionMode) is unknown; \(entry.interactionMode.displayName) is a fallback.")
                    }
                    let importedTarget = Int32(bitPattern: imported.assignment)
                    if !(-1...15).contains(importedTarget) {
                        limitations.append("Preserved native row uncertainty [coercedTargetAssignment]: assignment \(importedTarget) is unknown; \(entry.assignment.displayName) is a fallback.")
                    }
                }

                for match in inferredControls[entry.id] ?? [] {
                    controls.append("Physical control: \(match.description)")
                    sources.append(contentsOf: match.sources)
                }
                for annotation in controlsByRow[entry.id] ?? [] {
                    controls.append("Physical control: \(annotation.controlID) (profile \(annotation.profileID))")
                    guard annotation.profileID == configuration?.profileID else {
                        limitations.append("The physical-control annotation does not match this device's exact pinned profile.")
                        continue
                    }
                    guard let resolver else { continue }
                    let direction: ControllerProfile.Direction = entry.ioType == .output ? .receive : .send
                    switch resolver.resolve(controlID: annotation.controlID, configuration: configuration,
                                            layer: .base, direction: direction) {
                    case let .resolved(bindings):
                        let matching = bindings.filter { $0.midi == entry.midiAssignment }
                        if matching.isEmpty {
                            limitations.append("The annotated control does not match the row's MIDI address in the pinned base-layer context.")
                        } else {
                            for binding in matching {
                                sources.append(binding.provenance)
                                sources.append(contentsOf: binding.evidence.map { "Evidence \($0)" })
                            }
                        }
                    case let .unresolved(reason):
                        limitations.append(reason)
                    }
                }

                let conditionValues = [entry.modifier1Condition, entry.modifier2Condition].compactMap { $0 }
                let conditions = conditionValues.map {
                    "\($0.displayString) · target \(TraktorConditionMetadata.targetLabel($0.target))"
                }
                var modifierReads = conditionValues
                    .compactMap { condition -> Int? in
                        guard (1...8).contains(condition.modifier) else { return nil }
                        return condition.modifier
                    }
                var rowDetails = details(for: entry)
                if let configuration {
                    rowDetails.append("Profile pin: \(configuration.profileID)@\(configuration.version)")
                    rowDetails.append("Profile configuration: channel \(configuration.globalChannel), layer mode \(configuration.layerMode), unit map \(configuration.unitMap), feedback \(configuration.feedbackMode)")
                }
                let modifierNumber = (2548...2555).contains(entry.commandID) ? entry.commandID - 2547 : nil
                let writes = modifierNumber != nil && entry.ioType != .output ? [modifierNumber!] : []
                if let modifierNumber, entry.ioType == .output {
                    modifierReads.append(modifierNumber)
                    rowDetails.append("Observes Modifier \(modifierNumber) state for controller feedback; it does not write the modifier.")
                }
                rows.append(ExplanationRow(
                    id: entry.id, deviceID: device.id, deviceName: device.name, position: index + 1,
                    commandID: entry.commandID, command: command, direction: entry.ioType.rawValue,
                    assignment: entry.assignment.displayName, midi: entry.mappedToDisplay,
                    controllerType: entry.controllerType.displayName, interaction: entry.interactionMode.displayName,
                    conditions: conditions, modifierReads: Array(Set(modifierReads)).sorted(), modifierWrites: writes,
                    details: rowDetails, controls: Self.orderedUnique(controls), sources: Self.orderedUnique(sources),
                    limitations: Self.orderedUnique(limitations), comment: entry.comment
                ))
            }
        }
        return Self(title: title, revision: revision, devices: devices, rows: rows,
                    limitations: Self.orderedUnique(snapshotLimitations))
    }

    private struct ProfileMatch {
        let controlID: String
        let description: String
        let sources: [String]
    }

    private struct BindingKey: Hashable {
        let midi: MIDIAssignment
        let direction: ControllerProfile.Direction
    }

    /// Resolve the small fixed profile catalogue once per device, then join through an indexed MIDI key.
    private static func profileMatches(device: Device, configuration: ControllerConfiguration?,
                                       library: ControllerProfileLibrary?, resolver: ControllerControlResolver?) throws -> [UUID: [ProfileMatch]] {
        guard let configuration, let library, let resolver,
              let profile = try? library.profile(id: configuration.profileID, version: configuration.version) else { return [:] }
        var rowIDsByBinding: [BindingKey: [UUID]] = [:]
        for row in device.mappings where row.rawMidiControlName == nil && row.rawMidiBindingID == nil {
            if row.ioType != .output { rowIDsByBinding[BindingKey(midi: row.midiAssignment, direction: .send), default: []].append(row.id) }
            if row.ioType != .input { rowIDsByBinding[BindingKey(midi: row.midiAssignment, direction: .receive), default: []].append(row.id) }
        }
        let evidenceByID = Dictionary(uniqueKeysWithValues: profile.evidence.map { ($0.id, $0) })
        let sourceByID = Dictionary(uniqueKeysWithValues: profile.sources.map { ($0.id, $0) })
        func sourceDescriptions(_ ids: [String], provenance: String) -> [String] {
            var result = [provenance]
            for id in ids {
                guard let evidence = evidenceByID[id], let source = sourceByID[evidence.sourceID] else {
                    result.append("Evidence \(id)")
                    continue
                }
                result.append("\(evidence.verification.rawValue): \(source.url), \(evidence.locator)")
            }
            return result
        }
        var result: [UUID: [ProfileMatch]] = [:]
        guard let mode = profile.modes.first(where: { $0.id == configuration.layerMode }) else { return [:] }
        for control in profile.controls {
            try Task.checkCancellation()
            let lookupLayers: [ControllerProfile.Layer] = mode.layeredGroups.contains(control.group)
                ? [.base, .amber, .green] : [.base]
            for direction in [ControllerProfile.Direction.send, .receive] {
                for layer in lookupLayers {
                    guard case let .resolved(bindings) = resolver.resolve(controlID: control.id,
                        configuration: configuration, layer: layer, direction: direction) else { continue }
                    for binding in bindings {
                        for rowID in rowIDsByBinding[BindingKey(midi: binding.midi, direction: direction)] ?? [] {
                            let aliases = control.aliases.isEmpty ? "" : "; aliases: \(control.aliases.joined(separator: ", "))"
                            let color = binding.color.map { "; LED color: \($0.rawValue)" } ?? ""
                            result[rowID, default: []].append(ProfileMatch(
                                controlID: control.id,
                                description: "\(control.name) [\(control.id)]\(aliases); \(direction.rawValue); \(layer.rawValue) layer\(color)",
                                sources: sourceDescriptions(binding.evidence, provenance: binding.provenance)
                            ))
                        }
                    }
                }
            }
        }
        for rowID in result.keys {
            var seen = Set<String>()
            result[rowID] = result[rowID]?.filter { seen.insert("\($0.description)|\($0.sources.joined())").inserted }
        }
        return result
    }

    private static func details(for entry: MappingEntry) -> [String] {
        var result: [String] = []
        if entry.invert { result.append("Invert: enabled") }
        if entry.softTakeover { result.append("Soft Takeover: enabled") }
        if entry.autoRepeat { result.append("Auto Repeat: enabled") }
        if entry.interactionMode == .direct { result.append("Set value: \(entry.setToValue)") }
        if entry.controllerType == .encoder {
            result += ["Encoder mode: \(entry.encoderMode.displayName)",
                       "Rotary sensitivity: \(entry.rotarySensitivity)",
                       "Rotary acceleration: \(entry.rotaryAcceleration)"]
        }
        if entry.ioType == .output || entry.controllerType == .led {
            result += ["LED controller range: \(entry.ledMinRangeType):\(entry.ledMinRangeData) to \(entry.ledMaxRangeType):\(entry.ledMaxRangeData)",
                       "LED MIDI range: \(entry.ledMinMidi) to \(entry.ledMaxMidi)",
                       "LED invert: \(entry.ledInvert)", "LED blend: \(entry.ledBlend)"]
        }
        result.append("Resolution: \(entry.resolution)")
        return result
    }

    private static func orderedUnique(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.filter { seen.insert($0).inserted }
    }
}

nonisolated struct ExplanationDevice: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let comment: String
    let profile: String
    let settings: [String]
    let limitations: [String]
}

nonisolated struct ExplanationRow: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let deviceID: UUID
    let deviceName: String
    let position: Int
    let commandID: Int
    let command: String
    let direction: String
    let assignment: String
    let midi: String
    let controllerType: String
    let interaction: String
    let conditions: [String]
    let modifierReads: [Int]
    let modifierWrites: [Int]
    let details: [String]
    let controls: [String]
    let sources: [String]
    let limitations: [String]
    let comment: String
}
