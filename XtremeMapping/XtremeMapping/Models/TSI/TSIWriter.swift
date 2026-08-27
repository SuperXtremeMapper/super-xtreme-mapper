//
//  TSIWriter.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation
import os

enum TSIWriterError: Error, Equatable {
    case invalidCommandID(Int)
    case conflictingEncoderModes(controlName: String, direction: IODirection)
}

/// Writer for TSI (Traktor Settings Interface) files.
///
/// Converts in-memory TSI data structures back to the TSI file format.
public struct TSIWriter: Sendable {

    private static let logger = Logger(subsystem: "com.sxm.app", category: "TSIWriter")

    public init() {}

    // MARK: - Public API

    /// Writes a MappingFile to TSI format.
    ///
    /// - Parameter mappingFile: The mapping file to serialize
    /// - Returns: The complete TSI file data
    func write(_ mappingFile: MappingFile) throws -> Data {
        // Build frame hierarchy: DIOM -> DEVS -> DEVI -> CMAS -> CMAI -> CMAD
        let diomData = try buildDIOM(from: mappingFile)

        // Create the root DIOM frame
        let diomFrame = TSIFrame(identifier: "DIOM", size: UInt32(diomData.count), data: diomData)

        // Encode to binary
        let binaryData = encodeFrame(diomFrame)

        // Encode to Base64
        let base64String = encodeBase64(binaryData)

        // Create XML wrapper
        return createXML(withControllerData: base64String)
    }

    // MARK: - Frame Building

    /// Builds the DIOM (Device IO Mappings) frame content
    private func buildDIOM(from mappingFile: MappingFile) throws -> Data {
        var data = Data()

        // DIOI header frame (version info - 4 bytes, must be 1 for Traktor compatibility)
        let dioiData = Data([0x00, 0x00, 0x00, 0x01])
        data.append(encodeFrame(TSIFrame(identifier: "DIOI", size: UInt32(dioiData.count), data: dioiData)))

        // DEVS (devices container) with count prefix
        let devsContent = try buildDEVS(from: mappingFile.devices)
        data.append(encodeFrame(TSIFrame(identifier: "DEVS", size: UInt32(devsContent.count), data: devsContent)))

        return data
    }

    /// Builds the DEVS (Devices) frame content with count prefix
    private func buildDEVS(from devices: [Device]) throws -> Data {
        var data = Data()

        // 4-byte device count (big-endian)
        var count = UInt32(devices.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Each device as a DEVI frame
        for device in devices {
            let deviContent = try buildDEVI(from: device)
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

    private func tsiDeviceName(for device: Device) -> String {
        Self.recognizedDeviceNames.contains(device.name) ? device.name : "Generic MIDI"
    }

    /// Builds the DEVI (Device) frame content
    private func buildDEVI(from device: Device) throws -> Data {
        var data = Data()

        // Device name (UTF-16BE with 4-byte length prefix)
        data.append(encodeUTF16BEString(tsiDeviceName(for: device)))

        // DDAT (Device Data) containing DDCB (Command Bindings)
        let ddatContent = try buildDDAT(from: device)
        data.append(encodeFrame(TSIFrame(identifier: "DDAT", size: UInt32(ddatContent.count), data: ddatContent)))

        return data
    }

    /// Builds the DDAT (Device Data) frame content
    private func buildDDAT(from device: Device) throws -> Data {
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
        let inPort = device.inPort.isEmpty ? "All Ports" : device.inPort
        let outPort = device.outPort.isEmpty ? "All Ports" : device.outPort
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
        let ddcbContent = try buildDDCB(from: writableMappings)
        data.append(encodeFrame(TSIFrame(identifier: "DDCB", size: UInt32(ddcbContent.count), data: ddcbContent)))

        return data
    }

    private struct MIDIControlDefinitionKey: Hashable {
        let controlName: String
        let direction: IODirection
    }

    private struct MIDIControlDefinition {
        let key: MIDIControlDefinitionKey
        let encoderMode: UInt32
    }

    /// Builds the direction-specific MIDI definition lists. DCBM remains the
    /// authority for binding IDs; these rows carry metadata only.
    private func buildDDDC(from mappings: [MappingEntry]) throws -> Data {
        var modesByKey: [MIDIControlDefinitionKey: UInt32] = [:]
        var definitions: [MIDIControlDefinition] = []

        for mapping in mappings {
            guard let controlName = midiControlName(for: mapping) else { continue }
            let direction: IODirection = mapping.ioType == .output ? .output : .input
            let key = MIDIControlDefinitionKey(
                controlName: controlName,
                direction: direction
            )
            let encoderMode = mapping.effectiveDCDTEncoderMode

            if let existing = modesByKey[key] {
                guard existing == encoderMode else {
                    throw TSIWriterError.conflictingEncoderModes(
                        controlName: controlName,
                        direction: direction
                    )
                }
                continue
            }

            modesByKey[key] = encoderMode
            definitions.append(MIDIControlDefinition(key: key, encoderMode: encoderMode))
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

            let isOutput = definition.key.direction == .output
            var controlType = UInt32(isOutput ? 8 : 7).bigEndian
            payload.append(Data(bytes: &controlType, count: 4))

            var minValue = Float32(0).bitPattern.bigEndian
            payload.append(Data(bytes: &minValue, count: 4))

            var maxValue = Float32(127).bitPattern.bigEndian
            payload.append(Data(bytes: &maxValue, count: 4))

            var encoderMode = definition.encoderMode.bigEndian
            payload.append(Data(bytes: &encoderMode, count: 4))

            var controlID = UInt32.max.bigEndian
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
    private func buildDDCB(from mappings: [MappingEntry]) throws -> Data {
        var data = Data()

        // Build CMAS (Mappings List)
        let cmasContent = try buildCMAS(from: mappings)
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
    private func buildCMAS(from mappings: [MappingEntry]) throws -> Data {
        var data = Data()

        // 4-byte mapping count prefix
        var count = UInt32(mappings.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Build control name to binding ID lookup (must mirror buildDCBM)
        let controlNameToId = bindingIds(for: mappings)

        // Each mapping as a CMAI frame
        for mapping in mappings {
            let cmaiContent = try buildCMAI(from: mapping, controlNameToId: controlNameToId)
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
        var bindingId = 0
        for mapping in mappings {
            guard let controlName = midiControlName(for: mapping) else { continue }
            if controlNameToId[controlName] == nil {
                controlNameToId[controlName] = bindingId
                bindingId += 1
            }
        }
        return controlNameToId
    }

    /// Builds the CMAI (Mapping Item) frame content
    private func buildCMAI(from mapping: MappingEntry, controlNameToId: [String: Int]) throws -> Data {
        var data = Data()

        // MidiNoteBindingId (4 bytes) — the unassigned sentinel when the
        // mapping has no MIDI control (no fabricated CC 0 binding).
        let bindingIdValue: UInt32
        if let controlName = midiControlName(for: mapping) {
            bindingIdValue = UInt32(controlNameToId[controlName] ?? 0)
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
        let cmadContent = buildCMAD(from: mapping)
        data.append(encodeFrame(TSIFrame(identifier: "CMAD", size: UInt32(cmadContent.count), data: cmadContent)))

        return data
    }

    /// Builds the CMAD (Mapping Data) frame content
    private func buildCMAD(from mapping: MappingEntry) -> Data {
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
