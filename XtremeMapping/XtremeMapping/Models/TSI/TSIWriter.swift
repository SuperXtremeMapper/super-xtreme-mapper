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

        // DIOI header frame (version info - 4 bytes, always 0 for now)
        let dioiData = Data([0x00, 0x00, 0x00, 0x00])
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

        // DDCI (Control Index) - simplified, just build DCBM entries for MIDI controls used
        let ddciContent = buildDDCI(from: device.mappings)
        data.append(encodeFrame(TSIFrame(identifier: "DDCI", size: UInt32(ddciContent.count), data: ddciContent)))

        // DDCB (Command Bindings) containing CMAS
        let ddcbContent = buildDDCB(from: device.mappings)
        data.append(encodeFrame(TSIFrame(identifier: "DDCB", size: UInt32(ddcbContent.count), data: ddcbContent)))

        return data
    }

    /// Builds the DDCI (Control Index) with DCBM entries
    private func buildDDCI(from mappings: [MappingEntry]) -> Data {
        var data = Data()

        // Collect unique MIDI control identifiers
        var seenControls = Set<String>()
        var bindingId = 0

        for mapping in mappings {
            let controlName = midiControlName(for: mapping)
            if !seenControls.contains(controlName) {
                seenControls.insert(controlName)

                // Build DCBM frame: Id (4 bytes) + MidiNoteLength (4 bytes) + MidiNote (wchar_t[])
                var dcbmData = Data()

                // Binding ID
                var idValue = UInt32(bindingId).bigEndian
                dcbmData.append(Data(bytes: &idValue, count: 4))

                // String length in characters
                var strLen = UInt32(controlName.count).bigEndian
                dcbmData.append(Data(bytes: &strLen, count: 4))

                // String content (UTF-16BE)
                for char in controlName.unicodeScalars {
                    var codeUnit = UInt16(char.value).bigEndian
                    dcbmData.append(Data(bytes: &codeUnit, count: 2))
                }

                data.append(encodeFrame(TSIFrame(identifier: "DCBM", size: UInt32(dcbmData.count), data: dcbmData)))
                bindingId += 1
            }
        }

        return data
    }

    /// Builds the DDCB (Command Bindings) frame content
    private func buildDDCB(from mappings: [MappingEntry]) -> Data {
        // Build CMAS (Mappings List)
        let cmasContent = buildCMAS(from: mappings)
        return encodeFrame(TSIFrame(identifier: "CMAS", size: UInt32(cmasContent.count), data: cmasContent))
    }

    /// Builds the CMAS (Mappings List) frame content
    private func buildCMAS(from mappings: [MappingEntry]) -> Data {
        var data = Data()

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

        // Unknown1 (4 bytes) - constant 4
        var unknown1 = UInt32(4).bigEndian
        data.append(Data(bytes: &unknown1, count: 4))

        // ControllerType: Button=0, FaderOrKnob=1, Encoder=2, LED=65535
        let ctrlType: UInt32 = {
            switch mapping.controllerType {
            case .none: return 0  // Default to button if unassigned
            case .button: return 0
            case .faderOrKnob: return 1
            case .encoder: return 2
            case .led: return 65535
            }
        }()
        var controllerType = ctrlType.bigEndian
        data.append(Data(bytes: &controllerType, count: 4))

        // InteractionMode: Toggle=1, Hold=2, Direct=3, Relative=4, Output=8
        let intMode: UInt32 = {
            switch mapping.interactionMode {
            case .none: return 2  // Default to hold if unassigned
            case .toggle: return 1
            case .hold: return 2
            case .direct: return 3
            case .relative: return 4
            case .output: return 8
            case .increment: return 5
            case .decrement: return 6
            case .reset: return 7
            case .trigger: return 9
            }
        }()
        var interactionMode = intMode.bigEndian
        data.append(Data(bytes: &interactionMode, count: 4))

        // Deck/Target assignment (4 bytes, signed)
        let deckValue: Int32 = {
            switch mapping.assignment {
            case .none: return 0  // Default to global if unassigned
            case .deviceTarget: return -1
            case .global: return 0
            case .deckA: return 1
            case .deckB: return 2
            case .deckC: return 3
            case .deckD: return 4
            case .fxUnit1: return 5
            case .fxUnit2: return 6
            case .fxUnit3: return 7
            case .fxUnit4: return 8
            }
        }()
        var deck = UInt32(bitPattern: deckValue).bigEndian
        data.append(Data(bytes: &deck, count: 4))

        // AutoRepeat (4 bytes) - 0
        var autoRepeat = UInt32(0).bigEndian
        data.append(Data(bytes: &autoRepeat, count: 4))

        // Invert (4 bytes)
        var invert = UInt32(mapping.invert ? 1 : 0).bigEndian
        data.append(Data(bytes: &invert, count: 4))

        // SoftTakeover (4 bytes)
        var softTakeover = UInt32(mapping.softTakeover ? 1 : 0).bigEndian
        data.append(Data(bytes: &softTakeover, count: 4))

        // RotarySensitivity (4 bytes float)
        let rotarySens: Float32 = mapping.rotarySensitivity
        var sensBytes = rotarySens.bitPattern.bigEndian
        data.append(Data(bytes: &sensBytes, count: 4))

        // RotaryAcceleration (4 bytes float)
        let rotaryAccel: Float32 = mapping.rotaryAcceleration
        var accelBytes = rotaryAccel.bitPattern.bigEndian
        data.append(Data(bytes: &accelBytes, count: 4))

        // Unknown (8 bytes) - zeros
        data.append(Data(count: 8))

        // SetValueTo (4 bytes float)
        let setValue: Float32 = mapping.setToValue
        var setValueBytes = setValue.bitPattern.bigEndian
        data.append(Data(bytes: &setValueBytes, count: 4))

        // CommentLength + Comment
        var commentLen = UInt32(mapping.comment.count).bigEndian
        data.append(Data(bytes: &commentLen, count: 4))

        if !mapping.comment.isEmpty {
            for char in mapping.comment.unicodeScalars {
                var codeUnit = UInt16(char.value).bigEndian
                data.append(Data(bytes: &codeUnit, count: 2))
            }
        }

        // Modifier conditions (simplified - 4 values of 4 bytes each)
        // ModifierOneId, ModifierOneValue, ModifierTwoId, ModifierTwoValue
        let mod1Id = UInt32(mapping.modifier1Condition?.modifier ?? 0).bigEndian
        let mod1Val = UInt32(mapping.modifier1Condition?.value ?? 0).bigEndian
        let mod2Id = UInt32(mapping.modifier2Condition?.modifier ?? 0).bigEndian
        let mod2Val = UInt32(mapping.modifier2Condition?.value ?? 0).bigEndian

        var m1Id = mod1Id; data.append(Data(bytes: &m1Id, count: 4))
        var m1Val = mod1Val; data.append(Data(bytes: &m1Val, count: 4))
        var m2Id = mod2Id; data.append(Data(bytes: &m2Id, count: 4))
        var m2Val = mod2Val; data.append(Data(bytes: &m2Val, count: 4))

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

    /// Generates MIDI control name for a mapping (e.g., "Ch01.CC.100" or "Ch09.Note.C4")
    private func midiControlName(for mapping: MappingEntry) -> String {
        let channel = String(format: "Ch%02d", mapping.midiChannel)

        if let cc = mapping.midiCC {
            return "\(channel).CC.\(cc)"
        } else if let note = mapping.midiNote {
            let noteName = midiNoteName(for: note)
            return "\(channel).Note.\(noteName)"
        } else {
            return "\(channel).CC.0"
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
