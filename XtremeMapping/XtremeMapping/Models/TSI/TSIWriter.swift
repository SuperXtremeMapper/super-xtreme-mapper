//
//  TSIWriter.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Writer for TSI (Traktor Settings Interface) files.
///
/// Converts in-memory TSI data structures back to the TSI file format.
public struct TSIWriter: Sendable {

    public init() {}

    // MARK: - Public API

    /// Writes a MappingFile to TSI format.
    ///
    /// - Parameter mappingFile: The mapping file to serialize
    /// - Returns: The complete TSI file data
    func write(_ mappingFile: MappingFile) -> Data {
        // Build frame hierarchy: DIOM -> DEVS -> DEVI -> CMAS -> CMAI -> CMAD
        let diomData = buildDIOM(from: mappingFile)

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
    private func buildDIOM(from mappingFile: MappingFile) -> Data {
        var data = Data()

        // DIOI header frame (version info - 4 bytes, must be 1 for Traktor compatibility)
        let dioiData = Data([0x00, 0x00, 0x00, 0x01])
        data.append(encodeFrame(TSIFrame(identifier: "DIOI", size: UInt32(dioiData.count), data: dioiData)))

        // DEVS (devices container) with count prefix
        let devsContent = buildDEVS(from: mappingFile.devices)
        data.append(encodeFrame(TSIFrame(identifier: "DEVS", size: UInt32(devsContent.count), data: devsContent)))

        return data
    }

    /// Builds the DEVS (Devices) frame content with count prefix
    private func buildDEVS(from devices: [Device]) -> Data {
        var data = Data()

        // 4-byte device count (big-endian)
        var count = UInt32(devices.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Each device as a DEVI frame
        for device in devices {
            let deviContent = buildDEVI(from: device)
            data.append(encodeFrame(TSIFrame(identifier: "DEVI", size: UInt32(deviContent.count), data: deviContent)))
        }

        return data
    }

    /// Builds the DEVI (Device) frame content
    private func buildDEVI(from device: Device) -> Data {
        var data = Data()

        // Device name (UTF-16BE with 4-byte length prefix)
        data.append(encodeUTF16BEString(device.name))

        // DDAT (Device Data) containing DDCB (Command Bindings)
        let ddatContent = buildDDAT(from: device)
        data.append(encodeFrame(TSIFrame(identifier: "DDAT", size: UInt32(ddatContent.count), data: ddatContent)))

        return data
    }

    /// Builds the DDAT (Device Data) frame content
    private func buildDDAT(from device: Device) -> Data {
        var data = Data()

        // DDIF (Device Info Flags) - 4 bytes, value 0
        var ddifValue = UInt32(0).bigEndian
        let ddifData = Data(bytes: &ddifValue, count: 4)
        data.append(encodeFrame(TSIFrame(identifier: "DDIF", size: UInt32(ddifData.count), data: ddifData)))

        // DDIV (Device Version) - version string + MappingFileRevision (int32)
        var ddivData = Data()
        ddivData.append(encodeUTF16BEString("3.11.0"))
        var mappingRevision = UInt32(2).bigEndian  // MappingFileRevision, typically 2
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

        // DDDC (MIDI Definitions Container) containing DDCI
        let ddciContent = buildDDCI(from: device.mappings)
        let ddciFrame = encodeFrame(TSIFrame(identifier: "DDCI", size: UInt32(ddciContent.count), data: ddciContent))
        data.append(encodeFrame(TSIFrame(identifier: "DDDC", size: UInt32(ddciFrame.count), data: ddciFrame)))

        // DDCB (Command Bindings) containing CMAS
        let ddcbContent = buildDDCB(from: device.mappings)
        data.append(encodeFrame(TSIFrame(identifier: "DDCB", size: UInt32(ddcbContent.count), data: ddcbContent)))

        return data
    }

    /// Builds the DDCI (Control Index) with DCDT entries
    private func buildDDCI(from mappings: [MappingEntry]) -> Data {
        var data = Data()

        // Collect unique MIDI control identifiers
        var seenControls = Set<String>()

        // First, add 4-byte count prefix (number of DCDT entries)
        var uniqueCount: UInt32 = 0
        for mapping in mappings {
            let controlName = midiControlName(for: mapping)
            if !seenControls.contains(controlName) {
                seenControls.insert(controlName)
                uniqueCount += 1
            }
        }
        var countBE = uniqueCount.bigEndian
        data.append(Data(bytes: &countBE, count: 4))

        // Reset and build DCDT frames
        seenControls.removeAll()

        for mapping in mappings {
            let controlName = midiControlName(for: mapping)
            if !seenControls.contains(controlName) {
                seenControls.insert(controlName)

                // Build DCDT frame with full structure
                var dcdtData = Data()

                // String length in characters
                var strLen = UInt32(controlName.count).bigEndian
                dcdtData.append(Data(bytes: &strLen, count: 4))

                // String content (UTF-16BE)
                for char in controlName.unicodeScalars {
                    var codeUnit = UInt16(char.value).bigEndian
                    dcdtData.append(Data(bytes: &codeUnit, count: 2))
                }

                // MidiControlType (4 bytes) - 7 for CC
                var controlType = UInt32(7).bigEndian
                dcdtData.append(Data(bytes: &controlType, count: 4))

                // MinValue (4 bytes float) - 0.0
                let minValue: Float32 = 0.0
                var minValueBytes = minValue.bitPattern.bigEndian
                dcdtData.append(Data(bytes: &minValueBytes, count: 4))

                // MaxValue (4 bytes float) - 127.0
                let maxValue: Float32 = 127.0
                var maxValueBytes = maxValue.bitPattern.bigEndian
                dcdtData.append(Data(bytes: &maxValueBytes, count: 4))

                // EncoderMode (4 bytes) - 1
                var encoderMode = UInt32(1).bigEndian
                dcdtData.append(Data(bytes: &encoderMode, count: 4))

                // ControlId (4 bytes) - -1 (0xFFFFFFFF)
                var controlId = UInt32(0xFFFFFFFF).bigEndian
                dcdtData.append(Data(bytes: &controlId, count: 4))

                data.append(encodeFrame(TSIFrame(identifier: "DCDT", size: UInt32(dcdtData.count), data: dcdtData)))
            }
        }

        return data
    }

    /// Builds the DDCB (Command Bindings) frame content
    private func buildDDCB(from mappings: [MappingEntry]) -> Data {
        var data = Data()

        // Build CMAS (Mappings List)
        let cmasContent = buildCMAS(from: mappings)
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
        var controlNameToId: [String: Int] = [:]
        var bindingId = 0
        for mapping in mappings {
            let controlName = midiControlName(for: mapping)
            if controlNameToId[controlName] == nil {
                controlNameToId[controlName] = bindingId
                bindingId += 1
            }
        }

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
    private func buildCMAS(from mappings: [MappingEntry]) -> Data {
        var data = Data()

        // 4-byte mapping count prefix
        var count = UInt32(mappings.count).bigEndian
        data.append(Data(bytes: &count, count: 4))

        // Build control name to binding ID lookup
        var controlNameToId: [String: Int] = [:]
        var bindingId = 0
        for mapping in mappings {
            let controlName = midiControlName(for: mapping)
            if controlNameToId[controlName] == nil {
                controlNameToId[controlName] = bindingId
                bindingId += 1
            }
        }

        // Each mapping as a CMAI frame
        for mapping in mappings {
            let cmaiContent = buildCMAI(from: mapping, controlNameToId: controlNameToId)
            data.append(encodeFrame(TSIFrame(identifier: "CMAI", size: UInt32(cmaiContent.count), data: cmaiContent)))
        }

        return data
    }

    /// Builds the CMAI (Mapping Item) frame content
    private func buildCMAI(from mapping: MappingEntry, controlNameToId: [String: Int]) -> Data {
        var data = Data()

        // MidiNoteBindingId (4 bytes)
        let controlName = midiControlName(for: mapping)
        var bindingId = UInt32(controlNameToId[controlName] ?? 0).bigEndian
        data.append(Data(bytes: &bindingId, count: 4))

        // Type: 0=Input, 1=Output (4 bytes)
        var ioType = UInt32(mapping.ioType == .output ? 1 : 0).bigEndian
        data.append(Data(bytes: &ioType, count: 4))

        // TraktorControlId (4 bytes) - need reverse lookup from command name
        let controlId = TraktorCommands.id(for: mapping.commandName)
        var traktorId = UInt32(controlId).bigEndian
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

        // 4. Target/Assignment (4 bytes, signed)
        // Per spec: -1=DeviceTarget, 0=A/FX1/Global, 1=B/FX2, 2=C/FX3, 3=D/FX4
        let targetValue: Int32 = {
            switch mapping.assignment {
            case .none: return 0
            case .deviceTarget: return -1
            case .global: return 0
            case .deckA: return 0
            case .deckB: return 1
            case .deckC: return 2
            case .deckD: return 3
            case .fxUnit1: return 0
            case .fxUnit2: return 1
            case .fxUnit3: return 2
            case .fxUnit4: return 3
            }
        }()
        var target = UInt32(bitPattern: targetValue).bigEndian
        data.append(Data(bytes: &target, count: 4))

        // 5. AutoRepeat (4 bytes bool)
        var autoRepeat = UInt32(0).bigEndian
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

        // 10. HasValueUI (4 bytes bool) - 0 for most mappings
        var hasValueUI = UInt32(0).bigEndian
        data.append(Data(bytes: &hasValueUI, count: 4))

        // 11. ValueUIType (4 bytes enum) - 1=ComboBox, 2=Slider
        // Use Slider (2) for faders/knobs/encoders, ComboBox (1) for buttons
        let valueUITypeValue: UInt32 = {
            switch mapping.controllerType {
            case .faderOrKnob, .encoder: return 2  // Slider
            case .button: return 1  // ComboBox
            default: return 0
            }
        }()
        var valueUIType = valueUITypeValue.bigEndian
        data.append(Data(bytes: &valueUIType, count: 4))

        // 12. SetValueTo (4 bytes float) - default 1.0 for sliders
        let setValue: Float32 = mapping.setToValue != 0 ? mapping.setToValue : 1.0
        var setValueBytes = setValue.bitPattern.bigEndian
        data.append(Data(bytes: &setValueBytes, count: 4))

        // 13. Comment (wide string with length prefix)
        var commentLen = UInt32(mapping.comment.count).bigEndian
        data.append(Data(bytes: &commentLen, count: 4))
        if !mapping.comment.isEmpty {
            for char in mapping.comment.unicodeScalars {
                var codeUnit = UInt16(char.value).bigEndian
                data.append(Data(bytes: &codeUnit, count: 2))
            }
        }

        // 14-16. ConditionOne: Id (4), Target (4), Value (4)
        var cond1Id = UInt32(mapping.modifier1Condition?.modifier ?? 0).bigEndian
        data.append(Data(bytes: &cond1Id, count: 4))
        var cond1Target = UInt32(0).bigEndian  // Target enum
        data.append(Data(bytes: &cond1Target, count: 4))
        var cond1Value = UInt32(mapping.modifier1Condition?.value ?? 0).bigEndian
        data.append(Data(bytes: &cond1Value, count: 4))

        // 17-19. ConditionTwo: Id (4), Target (4), Value (4)
        var cond2Id = UInt32(mapping.modifier2Condition?.modifier ?? 0).bigEndian
        data.append(Data(bytes: &cond2Id, count: 4))
        var cond2Target = UInt32(0).bigEndian
        data.append(Data(bytes: &cond2Target, count: 4))
        var cond2Value = UInt32(mapping.modifier2Condition?.value ?? 0).bigEndian
        data.append(Data(bytes: &cond2Value, count: 4))

        // 20-21. LedMinControllerRange: ValueUIType (4), data (4)
        var ledMinType = UInt32(0).bigEndian
        data.append(Data(bytes: &ledMinType, count: 4))
        var ledMinData = UInt32(0).bigEndian
        data.append(Data(bytes: &ledMinData, count: 4))

        // 22-23. LedMaxControllerRange: ValueUIType (4), data (4)
        // Per Traktor export: type=0, value=1 (integer, not float)
        var ledMaxType = UInt32(0).bigEndian
        data.append(Data(bytes: &ledMaxType, count: 4))
        var ledMaxData = UInt32(1).bigEndian
        data.append(Data(bytes: &ledMaxData, count: 4))

        // 24. LedMinMidiRange (4 bytes)
        var ledMinMidi = UInt32(0).bigEndian
        data.append(Data(bytes: &ledMinMidi, count: 4))

        // 25. LedMaxMidiRange (4 bytes)
        var ledMaxMidi = UInt32(127).bigEndian
        data.append(Data(bytes: &ledMaxMidi, count: 4))

        // 26-30. Optional fields for Generic MIDI device
        // 26. LedInvert (4 bytes bool)
        var ledInvert = UInt32(0).bigEndian
        data.append(Data(bytes: &ledInvert, count: 4))

        // 27. LedBlend (4 bytes bool)
        var ledBlend = UInt32(0).bigEndian
        data.append(Data(bytes: &ledBlend, count: 4))

        // 28. unknownValueUIType (4 bytes)
        var unknownVUI = UInt32(0).bigEndian
        data.append(Data(bytes: &unknownVUI, count: 4))

        // 29. Resolution (4 bytes enum)
        var resolution = UInt32(0).bigEndian
        data.append(Data(bytes: &resolution, count: 4))

        // 30. UseFactoryMap (4 bytes bool)
        var useFactoryMap = UInt32(0).bigEndian
        data.append(Data(bytes: &useFactoryMap, count: 4))

        return data
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
    private func encodeUTF16BEString(_ string: String) -> Data {
        var data = Data()

        // Length in characters
        var length = UInt32(string.count).bigEndian
        data.append(Data(bytes: &length, count: 4))

        // UTF-16BE characters
        for char in string.unicodeScalars {
            var codeUnit = UInt16(char.value).bigEndian
            data.append(Data(bytes: &codeUnit, count: 2))
        }

        return data
    }

    /// Generates MIDI control name for a mapping (e.g., "Ch01.CC.000" or "Ch09.Note.C4")
    private func midiControlName(for mapping: MappingEntry) -> String {
        let channel = String(format: "Ch%02d", mapping.midiChannel)

        if let cc = mapping.midiCC {
            return String(format: "%@.CC.%03d", channel, cc)
        } else if let note = mapping.midiNote {
            let noteName = midiNoteName(for: note)
            return "\(channel).Note.\(noteName)"
        } else {
            return "\(channel).CC.000"
        }
    }

    /// Converts MIDI note number to name
    private func midiNoteName(for note: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[note % 12]
        let octave = (note / 12) - 1
        return "\(noteName)\(octave)"
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
