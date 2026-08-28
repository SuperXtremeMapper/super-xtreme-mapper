//
//  TSIWriter.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation
import os

enum TSIWriterError: Error, Equatable, Sendable, LocalizedError {
    case invalidCommandID(Int)
    case invalidDeviceName
    case incompatibleImportedInteraction(
        controllerType: ControllerType,
        interactionMode: InteractionMode
    )
    case unreconcilableImportedCMAD(field: String)
    case conflictingEncoderModes(controlName: String, direction: IODirection)
    case conflictingMIDIControlDefinitions(controlName: String, direction: IODirection)

    var errorDescription: String? {
        switch self {
        case .invalidCommandID(let id):
            "Command ID \(id) cannot be represented as a TSI UInt32."
        case .invalidDeviceName:
            "A new TSI device must have a non-empty registry name."
        case .incompatibleImportedInteraction(let controllerType, let interactionMode):
            "Imported \(controllerType.displayName) mappings cannot use \(interactionMode.displayName) interaction."
        case .unreconcilableImportedCMAD(let field):
            "The imported CMAD does not contain the \(field) bytes required by this edit."
        case .conflictingEncoderModes(let name, let direction):
            "\(direction.rawValue) control \(name) has conflicting encoder modes."
        case .conflictingMIDIControlDefinitions(let name, let direction):
            "\(direction.rawValue) control \(name) has conflicting MIDI definitions."
        }
    }
}

/// Writer for TSI (Traktor Settings Interface) files.
///
/// Converts in-memory TSI data structures back to the TSI file format.
public struct TSIWriter: Sendable {

    private enum OutputMode: Equatable {
        case preservingImported
        case converted
    }

    private static let logger = Logger(subsystem: "com.sxm.app", category: "TSIWriter")

    public init() {}

    // MARK: - Public API

    /// Writes a MappingFile to TSI format.
    ///
    /// - Parameter mappingFile: The mapping file to serialize
    /// - Returns: The complete TSI file data
    func write(_ mappingFile: MappingFile) throws -> Data {
        if let envelope = mappingFile.sourceEnvelope,
           envelope.baseline.matches(mappingFile) {
            return envelope.originalXML
        }

        let risks = try validatedPreservationRisks(for: mappingFile)
        if !risks.isEmpty {
            throw TSIPreservationError.unsafeOverwrite(risks: risks)
        }
        return try writeRegenerated(mappingFile, mode: .preservingImported)
    }

    /// Deliberately canonicalizes the modeled projection. This bypasses exact
    /// source passthrough and preservation refusal, but never writer validation.
    func writeConverted(_ mappingFile: MappingFile) throws -> Data {
        try writeRegenerated(mappingFile, mode: .converted)
    }

    /// Computes the complete document-boundary write once. Callers retain the
    /// result until the corresponding save completion is known.
    func makeWritePlan(for mappingFile: MappingFile) throws -> TSIWritePlan {
        let report = preservationReport(for: mappingFile)
        let baseline = TSISemanticBaseline(
            devices: mappingFile.devices,
            version: mappingFile.version
        )

        if let envelope = mappingFile.sourceEnvelope,
           envelope.baseline.matches(mappingFile) {
            return TSIWritePlan(
                output: envelope.originalXML,
                baseline: baseline,
                report: report,
                disposition: .originalPassthrough
            )
        }

        return TSIWritePlan(
            output: try write(mappingFile),
            baseline: baseline,
            report: report,
            disposition: .regenerated
        )
    }

    private func writeRegenerated(
        _ mappingFile: MappingFile,
        mode: OutputMode
    ) throws -> Data {
        // Build frame hierarchy: DIOM -> DEVS -> DEVI -> CMAS -> CMAI -> CMAD
        let diomData = try buildDIOM(from: mappingFile, mode: mode)

        // Create the root DIOM frame
        let diomFrame = TSIFrame(identifier: "DIOM", size: UInt32(diomData.count), data: diomData)

        // Encode to binary
        let binaryData = encodeFrame(diomFrame)

        // Encode to Base64
        let base64String = encodeBase64(binaryData)

        // Create XML wrapper
        return createXML(withControllerData: base64String)
    }

    /// Side-effect-free safety decision. Converted-writer validation is the
    /// first lattice gate, before source risks are considered.
    func preservationReport(for mappingFile: MappingFile) -> TSIPreservationReport {
        do {
            let risks = try validatedPreservationRisks(for: mappingFile)
            return TSIPreservationReport(
                risks: risks,
                disposition: risks.isEmpty ? .ordinarySaveSafe : .lossyConvertible,
                validationError: nil
            )
        } catch {
            return TSIPreservationReport(
                risks: mappingFile.sourceEnvelope?.risks ?? [],
                disposition: .unwritable,
                validationError: TSIWriterValidationFailure(error)
            )
        }
    }

    /// Converted validation is the first lattice gate. Only a projection that
    /// can be written canonically is classified as ordinary-save-safe or
    /// lossy-convertible; preserving regeneration happens later and only for
    /// the ordinary-safe case.
    private func validatedPreservationRisks(
        for mappingFile: MappingFile
    ) throws -> [TSIPreservationRisk] {
        _ = try writeRegenerated(mappingFile, mode: .converted)
        return preservationRisks(for: mappingFile)
    }

    private func preservationRisks(for mappingFile: MappingFile) -> [TSIPreservationRisk] {
        if let sourceRisks = mappingFile.sourceEnvelope?.risks {
            return sourceRisks
        }

        var risks: [TSIPreservationRisk] = []
        for (deviceIndex, device) in mappingFile.devices.enumerated() {
            for (mappingIndex, mapping) in device.mappings.enumerated() {
                guard let imported = mapping.importedCMAD else { continue }
                let path = "/Device[\(deviceIndex)]/Mapping[\(mappingIndex)]/CMAD[0]"
                if imported.payload.count < imported.expectedCompleteLength {
                    risks.append(.init(
                        code: .partialCMAD,
                        path: path,
                        detail: "\(imported.payload.count)/\(imported.expectedCompleteLength)"
                    ))
                    continue
                }
                if imported.payload.count > imported.expectedCompleteLength {
                    risks.append(.init(
                        code: .extendedCMAD,
                        path: path,
                        detail: "\(imported.payload.count)/\(imported.expectedCompleteLength)"
                    ))
                    continue
                }
                if imported.commentWasLossy {
                    risks.append(.init(code: .lossyString, path: "\(path)/Comment"))
                }
                if imported.deviceType != 4 {
                    risks.append(.init(code: .proprietaryDeviceType, path: path))
                }
                if ![0, 1, 2, 65_535].contains(imported.controllerType) {
                    risks.append(.init(code: .coercedControllerType, path: path))
                }
                if !(0...8).contains(imported.interactionMode) {
                    risks.append(.init(code: .coercedInteractionMode, path: path))
                }
                let target = Int32(bitPattern: imported.assignment)
                if !(-1...15).contains(target) {
                    risks.append(.init(code: .coercedTargetAssignment, path: path))
                }
            }
        }
        return risks.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.code.rawValue != $1.code.rawValue {
                return $0.code.rawValue < $1.code.rawValue
            }
            return $0.detail < $1.detail
        }
    }

    // MARK: - Frame Building

    /// Builds the DIOM (Device IO Mappings) frame content
    private func buildDIOM(from mappingFile: MappingFile, mode: OutputMode) throws -> Data {
        var data = Data()

        // DIOI header frame (version info - 4 bytes, must be 1 for Traktor compatibility)
        let dioiData = Data([0x00, 0x00, 0x00, 0x01])
        data.append(encodeFrame(TSIFrame(identifier: "DIOI", size: UInt32(dioiData.count), data: dioiData)))

        // DEVS (devices container) with count prefix
        let devsContent = try buildDEVS(from: mappingFile.devices, mode: mode)
        data.append(encodeFrame(TSIFrame(identifier: "DEVS", size: UInt32(devsContent.count), data: devsContent)))

        return data
    }

    /// Builds the DEVS (Devices) frame content with count prefix
    private func buildDEVS(from devices: [Device], mode: OutputMode) throws -> Data {
        var data = Data()

        // 4-byte device count (big-endian)
        var count = UInt32(devices.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Each device as a DEVI frame
        for device in devices {
            let deviContent = try buildDEVI(from: device, mode: mode)
            data.append(encodeFrame(TSIFrame(identifier: "DEVI", size: UInt32(deviContent.count), data: deviContent)))
        }

        return data
    }

    /// DEVI names Traktor's device registry recognizes. Anything else makes
    /// Traktor list the file but load zero mappings (the device can't be
    /// resolved to known hardware). User-supplied controller labels belong in
    /// `comment` (DDIC), not in `name`.
    private static let recognizedDeviceNames: Set<String> = [
        "Generic MIDI",
        "Kontrol X1",
        "Kontrol S2",
        "Kontrol S4",
    ]

    func canonicalDeviceName(for device: Device) -> String {
        if device.importedIdentity != nil {
            return device.name
        }
        return Self.recognizedDeviceNames.contains(device.name) ? device.name : "Generic MIDI"
    }

    static func canonicalPort(_ port: String) -> String {
        port.isEmpty ? "All Ports" : port
    }

    /// Builds the DEVI (Device) frame content
    private func buildDEVI(from device: Device, mode: OutputMode) throws -> Data {
        var data = Data()

        let ddatContent = try buildDDAT(from: device, mode: mode)
        let deviceName: String
        switch mode {
        case .preservingImported where device.importedIdentity != nil:
            deviceName = device.name
        case .preservingImported:
            guard !device.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw TSIWriterError.invalidDeviceName
            }
            deviceName = canonicalDeviceName(for: device)
        case .converted:
            if device.importedIdentity == nil,
               device.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw TSIWriterError.invalidDeviceName
            }
            deviceName = Self.recognizedDeviceNames.contains(device.name)
                ? device.name
                : "Generic MIDI"
        }

        // Device name (UTF-16BE with 4-byte length prefix)
        data.append(encodeUTF16BEString(deviceName))

        // DDAT (Device Data) containing DDCB (Command Bindings)
        data.append(encodeFrame(TSIFrame(identifier: "DDAT", size: UInt32(ddatContent.count), data: ddatContent)))

        return data
    }

    /// Builds the DDAT (Device Data) frame content
    private func buildDDAT(from device: Device, mode: OutputMode) throws -> Data {
        var data = Data()

        // Filter placeholders while preserving every positive stored command ID.
        // Computed ONCE and shared by ALL frame builders (DDCI, DCBM, CMAS) so
        // binding IDs stay aligned across frames — filtering in only one builder
        // would make a CMAI point at the wrong MIDI control after reload.
        var writableMappings: [MappingEntry] = []
        writableMappings.reserveCapacity(device.mappings.count)
        for mapping in device.mappings {
            guard mapping.commandID > 0 else {
                Self.logger.warning(
                    "Skipping unwritable mapping '\(mapping.commandName, privacy: .public)' (stored ID \(mapping.commandID))"
                )
                continue
            }
            guard mapping.commandID <= Int(UInt32.max) else {
                throw TSIWriterError.invalidCommandID(mapping.commandID)
            }
            writableMappings.append(mapping)
        }

        // DDIF (Device Info Flags) - 4 bytes, value 0
        var ddifValue = UInt32(0).bigEndian
        let ddifData = Data(bytes: &ddifValue, count: 4)
        data.append(encodeFrame(TSIFrame(identifier: "DDIF", size: UInt32(ddifData.count), data: ddifData)))

        // DDIV (Device Version) - version string + MappingFileRevision (int32)
        var ddivData = Data()
        ddivData.append(encodeUTF16BEString(device.tsiVersion))
        var mappingRevision = UInt32(clamping: device.mappingFileRevision).bigEndian
        ddivData.append(Data(bytes: &mappingRevision, count: 4))
        data.append(encodeFrame(TSIFrame(identifier: "DDIV", size: UInt32(ddivData.count), data: ddivData)))

        // DDIC (Device Comment) - comment string
        let ddicData = encodeUTF16BEString(device.comment)
        data.append(encodeFrame(TSIFrame(identifier: "DDIC", size: UInt32(ddicData.count), data: ddicData)))

        // DDPT (Device Ports) - in port + out port strings
        var ddptData = Data()
        let preserveIdentity = mode == .preservingImported && device.importedIdentity != nil
        let inPort = preserveIdentity ? device.inPort : Self.canonicalPort(device.inPort)
        let outPort = preserveIdentity ? device.outPort : Self.canonicalPort(device.outPort)
        ddptData.append(encodeUTF16BEString(inPort))
        ddptData.append(encodeUTF16BEString(outPort))
        data.append(encodeFrame(TSIFrame(identifier: "DDPT", size: UInt32(ddptData.count), data: ddptData)))

        // DDDC (MIDI Definitions Container) contains direction-specific DDCI
        // input and DDCO output definition lists as sibling frames.
        let dddcContent = try buildDDDC(from: writableMappings)
        data.append(encodeFrame(TSIFrame(
            identifier: "DDDC",
            size: UInt32(dddcContent.count),
            data: dddcContent
        )))

        // DDCB (Command Bindings) containing CMAS
        let ddcbContent = try buildDDCB(from: writableMappings, mode: mode)
        data.append(encodeFrame(TSIFrame(identifier: "DDCB", size: UInt32(ddcbContent.count), data: ddcbContent)))

        return data
    }

    private struct MIDIControlDefinitionKey: Hashable {
        let controlName: String
        let direction: IODirection
    }

    private struct MIDIControlDefinition: Equatable {
        let key: MIDIControlDefinitionKey
        let controlType: UInt32
        let minValueBits: UInt32
        let maxValueBits: UInt32
        let encoderMode: UInt32
        let controlID: UInt32
    }

    /// Builds the direction-specific MIDI definition lists. DCBM remains the
    /// authority for binding IDs; these rows carry metadata only.
    private func buildDDDC(from mappings: [MappingEntry]) throws -> Data {
        var definitionsByKey: [MIDIControlDefinitionKey: MIDIControlDefinition] = [:]
        var definitions: [MIDIControlDefinition] = []

        for mapping in mappings {
            guard let controlName = midiControlName(for: mapping) else { continue }
            let direction: IODirection = mapping.ioType == .output ? .output : .input
            let key = MIDIControlDefinitionKey(
                controlName: controlName,
                direction: direction
            )
            let encoderMode = mapping.effectiveDCDTEncoderMode
            let definition = MIDIControlDefinition(
                key: key,
                controlType: mapping.rawDCDTControlType
                    ?? (direction == .output ? 8 : 7),
                minValueBits: mapping.rawDCDTMinValueBits
                    ?? Float32(0).bitPattern,
                maxValueBits: mapping.rawDCDTMaxValueBits
                    ?? Float32(127).bitPattern,
                encoderMode: encoderMode,
                controlID: mapping.rawDCDTControlID ?? UInt32.max
            )

            if let existing = definitionsByKey[key] {
                guard existing.encoderMode == encoderMode else {
                    throw TSIWriterError.conflictingEncoderModes(
                        controlName: controlName,
                        direction: direction
                    )
                }
                guard existing == definition else {
                    throw TSIWriterError.conflictingMIDIControlDefinitions(
                        controlName: controlName,
                        direction: direction
                    )
                }
                continue
            }

            definitionsByKey[key] = definition
            definitions.append(definition)
        }

        var data = Data()
        let inputDefinitions = definitions.filter { $0.key.direction == .input }
        if !inputDefinitions.isEmpty {
            let payload = buildDefinitionList(from: inputDefinitions)
            data.append(encodeFrame(TSIFrame(
                identifier: "DDCI",
                size: UInt32(payload.count),
                data: payload
            )))
        }

        let outputDefinitions = definitions.filter { $0.key.direction == .output }
        if !outputDefinitions.isEmpty {
            let payload = buildDefinitionList(from: outputDefinitions)
            data.append(encodeFrame(TSIFrame(
                identifier: "DDCO",
                size: UInt32(payload.count),
                data: payload
            )))
        }

        return data
    }

    private func buildDefinitionList(from definitions: [MIDIControlDefinition]) -> Data {
        var data = Data()
        var count = UInt32(definitions.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        for definition in definitions {
            var payload = Data()
            payload.append(encodeUTF16BEString(definition.key.controlName))

            var controlType = definition.controlType.bigEndian
            payload.append(Data(bytes: &controlType, count: 4))

            var minValue = definition.minValueBits.bigEndian
            payload.append(Data(bytes: &minValue, count: 4))

            var maxValue = definition.maxValueBits.bigEndian
            payload.append(Data(bytes: &maxValue, count: 4))

            var encoderMode = definition.encoderMode.bigEndian
            payload.append(Data(bytes: &encoderMode, count: 4))

            var controlID = definition.controlID.bigEndian
            payload.append(Data(bytes: &controlID, count: 4))

            data.append(encodeFrame(TSIFrame(
                identifier: "DCDT",
                size: UInt32(payload.count),
                data: payload
            )))
        }

        return data
    }

    /// Builds the DDCB (Command Bindings) frame content
    private func buildDDCB(from mappings: [MappingEntry], mode: OutputMode) throws -> Data {
        var data = Data()

        // Build CMAS (Mappings List)
        let cmasContent = try buildCMAS(from: mappings, mode: mode)
        data.append(encodeFrame(TSIFrame(identifier: "CMAS", size: UInt32(cmasContent.count), data: cmasContent)))

        // Build DCBM (MIDI Note Binding List) - links BindingId to MidiNote strings
        let dcbmContent = buildDCBM(from: mappings)
        data.append(encodeFrame(TSIFrame(identifier: "DCBM", size: UInt32(dcbmContent.count), data: dcbmContent)))

        return data
    }

    /// Builds the DCBM (MIDI Note Binding List) frame content
    private func buildDCBM(from mappings: [MappingEntry]) -> Data {
        var data = Data()

        // Build list of unique control names with their binding IDs
        // (unassigned mappings have no control name and get no DCBM entry)
        let controlNameToId = bindingIds(for: mappings)

        // Count prefix
        var count = UInt32(controlNameToId.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Each binding as a nested DCBM frame
        for (controlName, id) in controlNameToId.sorted(by: { $0.value < $1.value }) {
            var bindingData = Data()

            // BindingId (4 bytes)
            var bindingIdValue = UInt32(id).bigEndian
            bindingData.append(Data(bytes: &bindingIdValue, count: 4))

            // MidiNote (wide string)
            bindingData.append(encodeUTF16BEString(controlName))

            // Wrap in DCBM frame
            data.append(encodeFrame(TSIFrame(identifier: "DCBM", size: UInt32(bindingData.count), data: bindingData)))
        }

        return data
    }

    /// Builds the CMAS (Mappings List) frame content
    private func buildCMAS(from mappings: [MappingEntry], mode: OutputMode) throws -> Data {
        var data = Data()

        // 4-byte mapping count prefix
        var count = UInt32(mappings.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Build control name to binding ID lookup (must mirror buildDCBM)
        let controlNameToId = bindingIds(for: mappings)

        // Each mapping as a CMAI frame
        for mapping in mappings {
            let cmaiContent = try buildCMAI(
                from: mapping,
                controlNameToId: controlNameToId,
                mode: mode
            )
            data.append(encodeFrame(TSIFrame(identifier: "CMAI", size: UInt32(cmaiContent.count), data: cmaiContent)))
        }

        return data
    }

    /// Assigns sequential binding IDs to the unique MIDI control names in
    /// mapping order. Shared by buildDCBM and buildCMAS so CMAI binding IDs
    /// always agree with the DCBM list. Unassigned mappings are excluded —
    /// they carry the `TSIBindingID.unassigned` sentinel instead.
    private func bindingIds(for mappings: [MappingEntry]) -> [String: Int] {
        var controlNameToId: [String: Int] = [:]
        let reservedIds = Set(mappings.compactMap { mapping -> UInt32? in
            guard mapping.rawMidiControlName == nil else { return nil }
            return mapping.rawMidiBindingID
        })
        var bindingId = 0
        for mapping in mappings {
            guard let controlName = midiControlName(for: mapping) else { continue }
            if controlNameToId[controlName] == nil {
                while reservedIds.contains(UInt32(bindingId)) {
                    bindingId += 1
                }
                controlNameToId[controlName] = bindingId
                bindingId += 1
            }
        }
        return controlNameToId
    }

    /// Builds the CMAI (Mapping Item) frame content
    private func buildCMAI(
        from mapping: MappingEntry,
        controlNameToId: [String: Int],
        mode: OutputMode
    ) throws -> Data {
        var data = Data()

        // MidiNoteBindingId (4 bytes) — the unassigned sentinel when the
        // mapping has no MIDI control (no fabricated CC 0 binding).
        let bindingIdValue: UInt32
        if let controlName = midiControlName(for: mapping) {
            bindingIdValue = UInt32(controlNameToId[controlName] ?? 0)
        } else if let rawBindingID = mapping.rawMidiBindingID {
            bindingIdValue = rawBindingID
        } else {
            bindingIdValue = TSIBindingID.unassigned
        }
        var bindingId = bindingIdValue.bigEndian
        data.append(Data(bytes: &bindingId, count: 4))

        // Type: 0=Input, 1=Output (4 bytes)
        var ioType = UInt32(mapping.ioType == .output ? 1 : 0).bigEndian
        data.append(Data(bytes: &ioType, count: 4))

        // TraktorControlId (4 bytes) — the stored raw integer is authoritative.
        guard mapping.commandID > 0, mapping.commandID <= Int(UInt32.max) else {
            throw TSIWriterError.invalidCommandID(mapping.commandID)
        }
        var traktorId = UInt32(mapping.commandID).bigEndian
        data.append(Data(bytes: &traktorId, count: 4))

        // CMAD frame
        let cmadContent = try buildCMAD(from: mapping, mode: mode)
        data.append(encodeFrame(TSIFrame(identifier: "CMAD", size: UInt32(cmadContent.count), data: cmadContent)))

        return data
    }

    /// Builds the CMAD (Mapping Data) frame content
    private func buildCMAD(from mapping: MappingEntry, mode: OutputMode) throws -> Data {
        if let imported = mapping.importedCMAD {
            let baseline = imported.semanticAtImport
            if mapping.interactionMode != baseline.interactionMode
                || mapping.controllerType != baseline.controllerType {
                guard mapping.controllerType.validInteractionModes.contains(mapping.interactionMode) else {
                    throw TSIWriterError.incompatibleImportedInteraction(
                        controllerType: mapping.controllerType,
                        interactionMode: mapping.interactionMode
                    )
                }
            }
        }
        guard mode == .preservingImported, let imported = mapping.importedCMAD else {
            return buildCanonicalCMAD(from: mapping)
        }
        return try buildImportedCMAD(from: mapping, imported: imported)
    }

    private func buildImportedCMAD(
        from mapping: MappingEntry,
        imported: ImportedCMAD
    ) throws -> Data {
        let baseline = imported.semanticAtImport
        let controllerChanged = mapping.controllerType != baseline.controllerType
        let commandChanged = mapping.commandID != baseline.commandID
        let profileChanged = controllerChanged || commandChanged

        if mapping.interactionMode != baseline.interactionMode || controllerChanged {
            guard mapping.controllerType.validInteractionModes.contains(mapping.interactionMode) else {
                throw TSIWriterError.incompatibleImportedInteraction(
                    controllerType: mapping.controllerType,
                    interactionMode: mapping.interactionMode
                )
            }
        }

        var data: Data
        if mapping.comment != baseline.comment {
            data = Data(imported.payload.prefix(48))
            data.append(encodeUTF16BEString(mapping.comment))
            data.append(imported.optionalBytes)
        } else {
            data = imported.payload
        }

        if controllerChanged {
            try replaceUInt32(
                Self.controllerTypeRaw(mapping.controllerType),
                in: &data,
                at: 4,
                field: "ControllerType"
            )
        }
        if mapping.interactionMode != baseline.interactionMode {
            try replaceUInt32(
                Self.interactionModeRaw(mapping.interactionMode),
                in: &data,
                at: 8,
                field: "InteractionMode"
            )
        }
        if mapping.assignment != baseline.assignment || commandChanged {
            try replaceUInt32(
                Self.targetRaw(for: mapping),
                in: &data,
                at: 12,
                field: "Assignment"
            )
        }
        if mapping.autoRepeat != baseline.autoRepeat {
            try replaceUInt32(mapping.autoRepeat ? 1 : 0, in: &data, at: 16, field: "AutoRepeat")
        }
        if mapping.invert != baseline.invert {
            try replaceUInt32(mapping.invert ? 1 : 0, in: &data, at: 20, field: "Invert")
        }
        if mapping.softTakeover != baseline.softTakeover {
            try replaceUInt32(mapping.softTakeover ? 1 : 0, in: &data, at: 24, field: "SoftTakeover")
        }
        if mapping.rotarySensitivity.bitPattern != baseline.rotarySensitivityBits {
            try replaceUInt32(
                mapping.rotarySensitivity.bitPattern,
                in: &data,
                at: 28,
                field: "RotarySensitivity"
            )
        }
        if mapping.rotaryAcceleration.bitPattern != baseline.rotaryAccelerationBits {
            try replaceUInt32(
                mapping.rotaryAcceleration.bitPattern,
                in: &data,
                at: 32,
                field: "RotaryAcceleration"
            )
        }

        let profile = Self.cmadProfile(for: mapping)
        if profileChanged {
            for (offset, value, field) in [
                (36, profile.hasValueUI, "HasValueUI"),
                (40, profile.valueUIType, "ValueUIType"),
                (44, profile.setValueRaw, "SetValueTo"),
            ] {
                try replaceUInt32(value, in: &data, at: offset, field: field)
            }
        } else if mapping.setToValue.bitPattern != baseline.setToValueBits {
            try replaceUInt32(
                Self.setValueRaw(for: mapping, commandId: mapping.commandID),
                in: &data,
                at: 44,
                field: "SetValueTo"
            )
        }

        let conditionOffset = 52 + mapping.comment.utf16.count * 2
        if mapping.modifier1Condition != baseline.modifier1Condition
            || mapping.modifier2Condition != baseline.modifier2Condition {
            let conditions: [UInt32] = [
                UInt32(clamping: mapping.modifier1Condition?.modifier ?? 0),
                0,
                UInt32(clamping: mapping.modifier1Condition?.value ?? 0),
                UInt32(clamping: mapping.modifier2Condition?.modifier ?? 0),
                0,
                UInt32(clamping: mapping.modifier2Condition?.value ?? 0),
            ]
            for (index, value) in conditions.enumerated() {
                try replaceUInt32(
                    value,
                    in: &data,
                    at: conditionOffset + index * 4,
                    field: "Conditions"
                )
            }
        }

        let ledOffset = conditionOffset + 24
        if profileChanged {
            for (relativeOffset, value, field) in [
                (0, profile.ledMinType, "LedMinType"),
                (4, profile.ledMinData, "LedMinData"),
                (8, profile.ledMaxType, "LedMaxType"),
                (12, profile.ledMaxData, "LedMaxData"),
                (28, profile.ledBlend, "LedBlend"),
                (32, profile.unknownVUI, "UnknownVUI"),
                (36, profile.resolutionRaw, "Resolution"),
            ] {
                try replaceUInt32(
                    value,
                    in: &data,
                    at: ledOffset + relativeOffset,
                    field: field
                )
            }
        } else {
            let ownedLEDValues: [(Bool, Int, UInt32, String)] = [
                (mapping.ledMinRangeType != baseline.ledMinRangeType, 0,
                 UInt32(clamping: mapping.ledMinRangeType), "LedMinType"),
                (mapping.ledMinRangeData != baseline.ledMinRangeData, 4,
                 UInt32(clamping: mapping.ledMinRangeData), "LedMinData"),
                (mapping.ledMaxRangeType != baseline.ledMaxRangeType, 8,
                 UInt32(clamping: mapping.ledMaxRangeType), "LedMaxType"),
                (mapping.ledMaxRangeData != baseline.ledMaxRangeData, 12,
                 UInt32(clamping: mapping.ledMaxRangeData), "LedMaxData"),
                (mapping.ledMinMidi != baseline.ledMinMidi, 16,
                 UInt32(clamping: mapping.ledMinMidi), "LedMinMidi"),
                (mapping.ledMaxMidi != baseline.ledMaxMidi, 20,
                 UInt32(clamping: mapping.ledMaxMidi), "LedMaxMidi"),
                (mapping.ledInvert != baseline.ledInvert, 24,
                 mapping.ledInvert ? 1 : 0, "LedInvert"),
                (mapping.ledBlend != baseline.ledBlend, 28,
                 mapping.ledBlend ? 1 : 0, "LedBlend"),
                (mapping.resolution != baseline.resolution, 36,
                 UInt32(clamping: mapping.resolution), "Resolution"),
            ]
            for (changed, relativeOffset, value, field) in ownedLEDValues where changed {
                try replaceUInt32(
                    value,
                    in: &data,
                    at: ledOffset + relativeOffset,
                    field: field
                )
            }
        }

        return data
    }

    private func buildCanonicalCMAD(from mapping: MappingEntry) -> Data {
        var data = Data()

        // 1. DeviceType (4 bytes) - 4=GenericMidi per CMDR enum
        var deviceType = UInt32(4).bigEndian
        data.append(Data(bytes: &deviceType, count: 4))

        // 2. ControlType: Button=0, FaderOrKnob=1, Encoder=2, LED=65535 (per official spec)
        let ctrlType: UInt32 = {
            switch mapping.controllerType {
            case .none: return 0
            case .button: return 0
            case .faderOrKnob: return 1
            case .encoder: return 2
            case .led: return 65535
            }
        }()
        var controllerType = ctrlType.bigEndian
        data.append(Data(bytes: &controllerType, count: 4))

        // 3. InteractionMode: Trigger=0, Toggle=1, Hold=2, Direct=3, Relative=4, Inc=5, Dec=6, Reset=7, Output=8
        let intMode: UInt32 = {
            switch mapping.interactionMode {
            case .none: return 0      // Default to Trigger when not set
            case .trigger: return 0
            case .toggle: return 1
            case .hold: return 2
            case .direct: return 3
            case .relative: return 4
            case .increment: return 5
            case .decrement: return 6
            case .reset: return 7
            case .output: return 8
            }
        }()
        var interactionMode = intMode.bigEndian
        data.append(Data(bytes: &interactionMode, count: 4))

        // 4. Target/Assignment (4 bytes, signed).
        // Most commands use -1 Device, 0..3 Deck A..D, and 4..7 FX1..4.
        // Remix-slot commands (239/249/250/251/259) overload the same field
        // as deckIndex * 4 + slotIndex. This is verified against local
        // Traktor 4.4 exports where Slot Volume spans targets 0...15.
        let cmdIdForTarget = mapping.commandID
        let isSlotCommand = Self.isRemixSlotCommand(cmdIdForTarget)
        let targetValue: Int32 = {
            if isSlotCommand {
                return mapping.assignment.remixSlotCommandTargetValue ?? 0
            }
            switch mapping.assignment {
            case .none: return 0
            case .deviceTarget: return -1
            case .global: return 0
            case .deckA: return 0
            case .deckB: return 1
            case .deckC: return 2
            case .deckD: return 3
            case .fxUnit1: return 4
            case .fxUnit2: return 5
            case .fxUnit3: return 6
            case .fxUnit4: return 7
            case .remixSlot1: return 8
            case .remixSlot2: return 9
            case .remixSlot3: return 10
            case .remixSlot4: return 11
            case .remixSlot5: return 12
            case .remixSlot6: return 13
            case .remixSlot7: return 14
            case .remixSlot8: return 15
            case .remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4,
                 .remixDeckBSlot1, .remixDeckBSlot2, .remixDeckBSlot3, .remixDeckBSlot4,
                 .remixDeckCSlot1, .remixDeckCSlot2, .remixDeckCSlot3, .remixDeckCSlot4,
                 .remixDeckDSlot1, .remixDeckDSlot2, .remixDeckDSlot3, .remixDeckDSlot4:
                return mapping.assignment.deckTargetValueForNonSlotCommand ?? 0
            }
        }()
        var target = UInt32(bitPattern: targetValue).bigEndian
        data.append(Data(bytes: &target, count: 4))

        // 5. AutoRepeat (4 bytes bool)
        var autoRepeat = UInt32(mapping.autoRepeat ? 1 : 0).bigEndian
        data.append(Data(bytes: &autoRepeat, count: 4))

        // 6. Invert (4 bytes bool)
        var invert = UInt32(mapping.invert ? 1 : 0).bigEndian
        data.append(Data(bytes: &invert, count: 4))

        // 7. SoftTakeover (4 bytes bool)
        var softTakeover = UInt32(mapping.softTakeover ? 1 : 0).bigEndian
        data.append(Data(bytes: &softTakeover, count: 4))

        // 8. RotarySensitivity (4 bytes float)
        let rotarySens: Float32 = mapping.rotarySensitivity
        var sensBytes = rotarySens.bitPattern.bigEndian
        data.append(Data(bytes: &sensBytes, count: 4))

        // 9. RotaryAcceleration (4 bytes float)
        let rotaryAccel: Float32 = mapping.rotaryAcceleration
        var accelBytes = rotaryAccel.bitPattern.bigEndian
        data.append(Data(bytes: &accelBytes, count: 4))

        // CMAD scalars 10-12 and 20-30 are command-type-specific in Traktor 4.4.
        // Empirically derived from decoding the user's Traktor Settings.tsi
        // across Hotcue(2328) / Slot Volume(251 fader) / Play-Pause(100 button) /
        // Sync(125 button). The "universal default" approach from earlier
        // attempts at this fix is wrong — buttons, faders, and indexed-buttons
        // each carry a distinct LED/Range/Blend/Resolution profile.
        let cmad = Self.cmadProfile(for: mapping)

        // 10. HasValueUI
        var hasValueUI = cmad.hasValueUI.bigEndian
        data.append(Data(bytes: &hasValueUI, count: 4))

        // 11. ValueUIType (1=ComboBox button, 2=Slider fader)
        var valueUIType = cmad.valueUIType.bigEndian
        data.append(Data(bytes: &valueUIType, count: 4))

        // 12. SetValueTo (semantics overloaded — see cmadProfile())
        var setValueBytes = cmad.setValueRaw.bigEndian
        data.append(Data(bytes: &setValueBytes, count: 4))

        // 13. Comment (wide string with length prefix)
        data.append(encodeUTF16BEString(mapping.comment))

        // 14-16. ConditionOne: Id (4), Target (4), Value (4)
        // (clamping — modifier values also originate from persisted JSON)
        var cond1Id = UInt32(clamping: mapping.modifier1Condition?.modifier ?? 0).bigEndian
        data.append(Data(bytes: &cond1Id, count: 4))
        var cond1Target = UInt32(0).bigEndian  // Target enum
        data.append(Data(bytes: &cond1Target, count: 4))
        var cond1Value = UInt32(clamping: mapping.modifier1Condition?.value ?? 0).bigEndian
        data.append(Data(bytes: &cond1Value, count: 4))

        // 17-19. ConditionTwo: Id (4), Target (4), Value (4)
        var cond2Id = UInt32(clamping: mapping.modifier2Condition?.modifier ?? 0).bigEndian
        data.append(Data(bytes: &cond2Id, count: 4))
        var cond2Target = UInt32(0).bigEndian
        data.append(Data(bytes: &cond2Target, count: 4))
        var cond2Value = UInt32(clamping: mapping.modifier2Condition?.value ?? 0).bigEndian
        data.append(Data(bytes: &cond2Value, count: 4))

        // 20-25. LED/Range block — all command-type-specific (see cmadProfile()).
        var ledMinType = cmad.ledMinType.bigEndian
        data.append(Data(bytes: &ledMinType, count: 4))
        var ledMinData = cmad.ledMinData.bigEndian
        data.append(Data(bytes: &ledMinData, count: 4))
        var ledMaxType = cmad.ledMaxType.bigEndian
        data.append(Data(bytes: &ledMaxType, count: 4))
        var ledMaxData = cmad.ledMaxData.bigEndian
        data.append(Data(bytes: &ledMaxData, count: 4))
        var ledMinMidi = UInt32(clamping: mapping.ledMinMidi).bigEndian
        data.append(Data(bytes: &ledMinMidi, count: 4))
        var ledMaxMidi = UInt32(clamping: mapping.ledMaxMidi).bigEndian
        data.append(Data(bytes: &ledMaxMidi, count: 4))

        // 26-30. Tail fields (LedInvert, LedBlend, UnknownVUI, Resolution, UseFactoryMap)
        var ledInvert = UInt32(mapping.ledInvert ? 1 : 0).bigEndian
        data.append(Data(bytes: &ledInvert, count: 4))
        var ledBlend = cmad.ledBlend.bigEndian
        data.append(Data(bytes: &ledBlend, count: 4))
        var unknownVUI = cmad.unknownVUI.bigEndian
        data.append(Data(bytes: &unknownVUI, count: 4))
        var resolution = cmad.resolutionRaw.bigEndian
        data.append(Data(bytes: &resolution, count: 4))
        var useFactoryMap = UInt32(0).bigEndian
        data.append(Data(bytes: &useFactoryMap, count: 4))

        return data
    }

    func preservingCMADPayload(for mapping: MappingEntry) throws -> Data {
        try buildCMAD(from: mapping, mode: .preservingImported)
    }

    // MARK: - CMAD profile per command type
    //
    // Traktor 4.4's CMAD scalar fields (HasValueUI, ValueUIType, SetValueTo,
    // LedMin/MaxType, LedMin/MaxData, LedBlend, UnknownVUI, Resolution) are
    // OVERLOADED by command type. The same 4-byte slot at the same offset
    // carries different semantics for a button vs a fader vs an indexed
    // hotcue — even the type of the value (uint32 vs float-bit-pattern)
    // changes. Empirically derived by decoding 3+ real bindings per command
    // type from the user's Traktor Settings.tsi.
    //
    // Pre-fix attempts to set "universal defaults" on these fields produced
    // bindings Traktor listed in its editor but refused to fire correctly
    // (or fired wrong actions). Round-trip-within-this-app tests passed
    // because the writer and parser agreed with each other — but neither
    // agreed with Traktor.

    private struct CMADProfile {
        let hasValueUI: UInt32      // 0 / 1
        let valueUIType: UInt32     // 1 ComboBox / 2 Slider
        let setValueRaw: UInt32     // command-specific raw bits or selector
        let ledMinType: UInt32      // 1 (int) for buttons, 2 (float) for faders
        let ledMinData: UInt32      // 0 / 0xFFFFFFFF / 0 (raw bits)
        let ledMaxType: UInt32      // 1 / 2
        let ledMaxData: UInt32      // index-max (hotcue: 7), int 1 (generic btn), float-1.0 bits (fader)
        let ledBlend: UInt32        // 0 / 1
        let unknownVUI: UInt32      // 1 button / 2 fader
        let resolutionRaw: UInt32   // int 1 button / float-0.0625 fader (0x3D800000)
    }

    private static func isRemixSlotCommand(_ commandId: Int) -> Bool {
        [239, 249, 250, 251, 259].contains(commandId)
    }

    private static func controllerTypeRaw(_ controllerType: ControllerType) -> UInt32 {
        switch controllerType {
        case .none, .button: 0
        case .faderOrKnob: 1
        case .encoder: 2
        case .led: 65_535
        }
    }

    private static func interactionModeRaw(_ interactionMode: InteractionMode) -> UInt32 {
        switch interactionMode {
        case .none, .trigger: 0
        case .toggle: 1
        case .hold: 2
        case .direct: 3
        case .relative: 4
        case .increment: 5
        case .decrement: 6
        case .reset: 7
        case .output: 8
        }
    }

    private static func targetRaw(for mapping: MappingEntry) -> UInt32 {
        let value: Int32
        if isRemixSlotCommand(mapping.commandID) {
            value = mapping.assignment.remixSlotCommandTargetValue ?? 0
        } else {
            switch mapping.assignment {
            case .none, .global, .deckA: value = 0
            case .deviceTarget: value = -1
            case .deckB: value = 1
            case .deckC: value = 2
            case .deckD: value = 3
            case .fxUnit1: value = 4
            case .fxUnit2: value = 5
            case .fxUnit3: value = 6
            case .fxUnit4: value = 7
            case .remixSlot1: value = 8
            case .remixSlot2: value = 9
            case .remixSlot3: value = 10
            case .remixSlot4: value = 11
            case .remixSlot5: value = 12
            case .remixSlot6: value = 13
            case .remixSlot7: value = 14
            case .remixSlot8: value = 15
            case .remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4,
                 .remixDeckBSlot1, .remixDeckBSlot2, .remixDeckBSlot3, .remixDeckBSlot4,
                 .remixDeckCSlot1, .remixDeckCSlot2, .remixDeckCSlot3, .remixDeckCSlot4,
                 .remixDeckDSlot1, .remixDeckDSlot2, .remixDeckDSlot3, .remixDeckDSlot4:
                value = mapping.assignment.deckTargetValueForNonSlotCommand ?? 0
            }
        }
        return UInt32(bitPattern: value)
    }

    private static func floatBits(_ value: Float32) -> UInt32 {
        value.bitPattern
    }

    private static func setValueRaw(for mapping: MappingEntry, commandId: Int) -> UInt32 {
        // Hotcue index is stored as a raw UInt32 selector, not a float.
        if commandId == 2328 {
            let index = max(0, min(7, Int(mapping.setToValue.rounded())))
            return UInt32(index)
        }

        // Values verified from local Traktor 4.x exports. For commands not in
        // this list, preserve the MappingEntry value instead of inventing a
        // universal default.
        switch commandId {
        case 239:
            return 1
        case 102, 251, 6:
            return floatBits(1.0)
        case 117, 249, 320:
            return floatBits(0.5)
        case 123, 365, 366, 367, 368:
            return floatBits(0.0)
        default:
            return floatBits(Float32(mapping.setToValue))
        }
    }

    private static func cmadProfile(for mapping: MappingEntry) -> CMADProfile {
        let cmdId = mapping.commandID

        // Indexed-hotcue path (id 2328 = "Select/Set+Store Hotcue").
        // SetValueTo carries the hotcue index 0..7 as raw uint32.
        if cmdId == 2328 {
            return CMADProfile(
                hasValueUI: 1,
                valueUIType: 1,
                setValueRaw: setValueRaw(for: mapping, commandId: cmdId),
                ledMinType: 1,
                ledMinData: 0xFFFFFFFF,
                ledMaxType: 1,
                ledMaxData: 7,
                ledBlend: 1,
                unknownVUI: 1,
                resolutionRaw: 1
            )
        }

        switch mapping.controllerType {
        case .faderOrKnob, .encoder:
            // Fader/knob profile (e.g. Slot Volume id 251, EQ, gain).
            // SetValueTo, LedMaxData, Resolution are FLOAT bit-patterns.
            return CMADProfile(
                hasValueUI: 0,
                valueUIType: 2,
                setValueRaw: setValueRaw(for: mapping, commandId: cmdId),
                ledMinType: 2,
                ledMinData: 0,
                ledMaxType: 2,
                ledMaxData: floatBits(1.0),
                ledBlend: 1,
                unknownVUI: 2,
                resolutionRaw: floatBits(0.0625)
            )
        case .button:
            // Generic-button profile (Play/Pause, Sync, mute toggle, etc.)
            return CMADProfile(
                hasValueUI: 0,
                valueUIType: 1,
                setValueRaw: setValueRaw(for: mapping, commandId: cmdId),
                ledMinType: 1,
                ledMinData: 0,
                ledMaxType: 1,
                ledMaxData: 1,
                ledBlend: 0,
                unknownVUI: 1,
                resolutionRaw: 1
            )
        default:
            // LED outputs and any other type — fall back to the persisted
            // MappingEntry values. Conservative: round-trips existing files
            // without overriding fields we don't yet have decoded references
            // for.
            return CMADProfile(
                hasValueUI: 0,
                valueUIType: 1,
                setValueRaw: UInt32(max(0, mapping.setToValue.rounded())),
                ledMinType: UInt32(clamping: mapping.ledMinRangeType),
                ledMinData: UInt32(clamping: mapping.ledMinRangeData),
                ledMaxType: UInt32(clamping: mapping.ledMaxRangeType),
                ledMaxData: UInt32(clamping: mapping.ledMaxRangeData),
                ledBlend: UInt32(mapping.ledBlend ? 1 : 0),
                unknownVUI: 1,
                resolutionRaw: UInt32(clamping: mapping.resolution)
            )
        }
    }

    // MARK: - Encoding Helpers

    private func replaceUInt32(
        _ value: UInt32,
        in data: inout Data,
        at offset: Int,
        field: String
    ) throws {
        guard offset >= 0, offset <= data.count, data.count - offset >= 4 else {
            throw TSIWriterError.unreconcilableImportedCMAD(field: field)
        }
        var bigEndian = value.bigEndian
        data.replaceSubrange(
            offset..<(offset + 4),
            with: Data(bytes: &bigEndian, count: 4)
        )
    }

    /// Encodes a single frame to binary data
    private func encodeFrame(_ frame: TSIFrame) -> Data {
        var data = Data()

        // 4-byte identifier (ASCII)
        if let idData = frame.identifier.data(using: .ascii) {
            data.append(idData)
        } else {
            data.append(Data(count: 4))
        }

        // 4-byte size (big-endian)
        var size = frame.size.bigEndian
        data.append(Data(bytes: &size, count: 4))

        // Frame data
        data.append(frame.data)

        return data
    }

    /// Encodes frames to binary data.
    public func encodeFrames(_ frames: [TSIFrame]) -> Data {
        var data = Data()
        for frame in frames {
            data.append(encodeFrame(frame))
        }
        return data
    }

    /// Encodes a UTF-16BE string with 4-byte length prefix
    ///
    /// Iterates UTF-16 code units (not unicode scalars) so non-BMP characters
    /// like emoji encode as surrogate pairs instead of trapping on
    /// `UInt16(scalar.value)`. The length prefix counts UTF-16 code units.
    private func encodeUTF16BEString(_ string: String) -> Data {
        var data = Data()

        // Length in UTF-16 code units
        var length = UInt32(string.utf16.count).bigEndian
        data.append(Data(bytes: &length, count: 4))

        // UTF-16BE code units (surrogate pairs preserved)
        for unit in string.utf16 {
            var codeUnit = unit.bigEndian
            data.append(Data(bytes: &codeUnit, count: 2))
        }

        return data
    }

    /// Generates the MIDI control name for a mapping (e.g., "Ch01.CC.020" or
    /// "Ch09.Note.C4"), or nil when the mapping has no MIDI assignment.
    ///
    /// Returning nil (instead of fabricating "ChXX.CC.000") lets callers skip
    /// DCDT/DCBM entries and write the unassigned sentinel binding ID, so an
    /// unassigned mapping round-trips unassigned.
    private func midiControlName(for mapping: MappingEntry) -> String? {
        if let rawMidiControlName = mapping.rawMidiControlName {
            return rawMidiControlName
        }

        let assignment = mapping.midiAssignment
        let channel = String(format: "Ch%02d", assignment.channel)

        switch assignment.kind {
        case .unassigned:
            return nil
        case .note:
            return "\(channel).Note.\(midiNoteToName(assignment.number!))"
        case .controlChange:
            return String(format: "%@.CC.%03d", channel, assignment.number!)
        }
    }


    /// Encodes binary data to Base64.
    public func encodeBase64(_ data: Data) -> String {
        return data.base64EncodedString()
    }

    /// Creates a complete TSI XML document with the given controller data.
    public func createXML(withControllerData controllerData: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="no" ?>
        <NIXML><TraktorSettings><Entry Name="DeviceIO.Config.Controller" Type="3" Value="\(controllerData)"/></TraktorSettings></NIXML>
        """
        return xml.data(using: .utf8) ?? Data()
    }
}
