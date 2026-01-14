//
//  TSIInterpreter.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Interprets parsed TSI frames into the app's data model.
///
/// TSI binary format structure:
/// ```
/// DIOM (Device IO Mappings)
/// ├── DIOI (Header/version)
/// └── DEVS (Devices container, 4-byte count prefix)
///     └── DEVI (Device) × N
///         ├── Device name (UTF-16BE string)
///         ├── DDAT (Device Data)
///         │   ├── DDCI (Control Index - DCDT lookup table)
///         │   │   └── DCDT × N (MIDI control definitions)
///         │   └── DDCB (Command Bindings)
///         │       └── CMAS (Mappings list)
///         │           └── CMAI × N (Individual mappings)
///         │               └── CMAD (Mapping data)
/// ```
struct TSIInterpreter {

    // MARK: - Frame Identifiers

    private enum FrameID {
        static let deviceIOMappings = "DIOM"
        static let devicesContainer = "DEVS"
        static let device = "DEVI"
        static let mappingsList = "CMAS"
        static let mappingItem = "CMAI"
        static let mappingData = "CMAD"
        static let controlTable = "DCDT"
    }

    // MARK: - Public API

    /// Interprets TSI frames into a MappingFile
    static func interpret(frames: [TSIFrame]) throws -> MappingFile {
        var devices: [Device] = []

        for frame in frames {
            if frame.identifier == FrameID.deviceIOMappings {
                let diomFrames = try parseNestedFrames(from: frame.data)

                for nested in diomFrames {
                    if nested.identifier == FrameID.devicesContainer {
                        // DEVS has 4-byte count prefix
                        guard nested.data.count > 4 else { continue }
                        let dataAfterCount = nested.data.subdata(in: 4..<nested.data.count)
                        let devsFrames = try parseNestedFrames(from: dataAfterCount)

                        for devsNested in devsFrames {
                            if devsNested.identifier == FrameID.device {
                                let device = try parseDevice(from: devsNested.data)
                                devices.append(device)
                            }
                        }
                    }
                }
            }
        }

        return MappingFile(devices: devices)
    }

    // MARK: - Device Parsing

    private static func parseDevice(from data: Data) throws -> Device {
        var offset = 0

        // Parse device name (UTF-16BE string with 4-byte length prefix)
        let deviceName: String
        if let (name, newOffset) = readUTF16BEString(from: data, at: offset) {
            deviceName = name
            offset = newOffset
        } else {
            deviceName = "Unknown Device"
        }

        // Build DCDT lookup table (control index -> MIDI name)
        let controlLookup = buildControlLookup(from: data)

        // Find and parse CMAS (mappings list)
        let mappings = parseMappings(from: data, controlLookup: controlLookup)

        print("TSI: Device '\(deviceName)' with \(mappings.count) mappings")

        return Device(
            name: deviceName,
            mappings: mappings
        )
    }

    // MARK: - MIDI Note Binding Lookup (DCBM)

    /// Builds a lookup table from DCBM frames: binding ID -> MIDI control name
    /// DCBM structure per spec:
    /// - Id: int (unique identifier for this binding)
    /// - MidiNoteLength: int
    /// - MidiNote: wchar_t[] (e.g. "Ch01.CC.100" or "Ch09.Note.A#2")
    private static func buildControlLookup(from data: Data) -> [Int: String] {
        var lookup: [Int: String] = [:]
        var offset = 0

        // Find DCBM frames
        while offset < data.count - 8 {
            guard offset + 4 <= data.count else { break }
            let marker = data.subdata(in: offset..<(offset + 4))
            guard String(data: marker, encoding: .ascii) == "DCBM" else {
                offset += 1
                continue
            }

            // Read DCBM size
            let sizeBytes = data.subdata(in: (offset + 4)..<(offset + 8))
            let size = Int(sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            guard size > 8 && size < 500 && offset + 8 + size <= data.count else {
                offset += 1
                continue
            }

            let dcbmData = data.subdata(in: (offset + 8)..<(offset + 8 + size))

            // Parse DCBM: Id (4 bytes) + MidiNoteLength (4 bytes) + MidiNote (wchar_t[])
            if dcbmData.count >= 8 {
                let bindingId = Int(dcbmData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                let stringLength = Int(dcbmData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

                if stringLength > 0 && stringLength < 200 && 8 + stringLength * 2 <= dcbmData.count {
                    var midiNote = ""
                    for i in stride(from: 8, to: 8 + stringLength * 2, by: 2) {
                        let hi = UInt16(dcbmData[i])
                        let lo = UInt16(dcbmData[i + 1])
                        let codeUnit = (hi << 8) | lo
                        if let scalar = UnicodeScalar(codeUnit) {
                            midiNote.append(Character(scalar))
                        }
                    }
                    lookup[bindingId] = midiNote
                }
            }

            offset += 8 + size
        }

        // Also build DCDT lookup as fallback (for control indices)
        var dcdtIndex = 0
        offset = 0
        while offset < data.count - 8 {
            guard offset + 4 <= data.count else { break }
            let marker = data.subdata(in: offset..<(offset + 4))
            guard String(data: marker, encoding: .ascii) == FrameID.controlTable else {
                offset += 1
                continue
            }

            let sizeBytes = data.subdata(in: (offset + 4)..<(offset + 8))
            let size = Int(sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            guard size > 0 && size < 500 && offset + 8 + size <= data.count else {
                offset += 1
                continue
            }

            let dcdtData = data.subdata(in: (offset + 8)..<(offset + 8 + size))
            if let (name, _) = readUTF16BEString(from: dcdtData, at: 0), !name.isEmpty {
                // Use negative indices for DCDT to avoid collision with DCBM IDs
                if lookup[dcdtIndex] == nil {
                    lookup[dcdtIndex] = name
                }
            }

            dcdtIndex += 1
            offset += 8 + size
        }

        return lookup
    }

    // MARK: - Mapping Parsing

    private static func parseMappings(from data: Data, controlLookup: [Int: String]) -> [MappingEntry] {
        var mappings: [MappingEntry] = []

        // Find CMAS frame
        guard let cmasOffset = findFrame(FrameID.mappingsList, in: data) else {
            return mappings
        }

        let sizeBytes = data.subdata(in: (cmasOffset + 4)..<(cmasOffset + 8))
        let cmasSize = Int(sizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

        guard cmasSize > 0 && cmasOffset + 8 + cmasSize <= data.count else {
            return mappings
        }

        let cmasData = data.subdata(in: (cmasOffset + 8)..<(cmasOffset + 8 + cmasSize))

        // Parse each CMAI frame within CMAS
        var offset = 0
        while offset < cmasData.count - 8 {
            let marker = cmasData.subdata(in: offset..<(offset + 4))
            guard String(data: marker, encoding: .ascii) == FrameID.mappingItem else {
                offset += 1
                continue
            }

            let cmaiSizeBytes = cmasData.subdata(in: (offset + 4)..<(offset + 8))
            let cmaiSize = Int(cmaiSizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            guard cmaiSize > 0 && offset + 8 + cmaiSize <= cmasData.count else {
                offset += 1
                continue
            }

            let cmaiData = cmasData.subdata(in: (offset + 8)..<(offset + 8 + cmaiSize))

            if let mapping = parseCMAI(from: cmaiData, controlLookup: controlLookup) {
                mappings.append(mapping)
            }

            offset += 8 + cmaiSize
        }

        return mappings
    }

    /// Parse CMAI (Controller Mapping Assignment Item)
    /// Per TSI spec (github.com/ivanz/TraktorMappingFileFormat):
    /// - MidiNoteBindingId: int (references DCBM binding)
    /// - Type: int (0=Input, 1=Output)
    /// - TraktorControlId: int (Traktor command identifier)
    /// - Settings: CMAD frame
    private static func parseCMAI(from data: Data, controlLookup: [Int: String]) -> MappingEntry? {
        guard data.count >= 20 else { return nil }

        // Parse CMAI header (3 x 4-byte integers before CMAD)
        let midiBindingId = Int(readUInt32BE(from: data, at: 0))
        let ioTypeValue = readUInt32BE(from: data, at: 4)
        let traktorControlId = Int(readUInt32BE(from: data, at: 8))

        // Skip unassigned/empty mappings (command ID 0 means no command assigned)
        guard traktorControlId > 0 else { return nil }

        let ioType: IODirection = ioTypeValue == 1 ? .output : .input

        // Get MIDI control name from lookup table using binding ID
        let midiControlName = controlLookup[midiBindingId] ?? "Ctrl_\(midiBindingId)"

        // Find and parse CMAD frame
        var cmadSettings = CMADParsed()

        if let cmadOffset = findFrame(FrameID.mappingData, in: data) {
            let cmadSizeBytes = data.subdata(in: (cmadOffset + 4)..<(cmadOffset + 8))
            let cmadSize = Int(cmadSizeBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            if cmadSize > 0 && cmadOffset + 8 + cmadSize <= data.count {
                let cmadData = data.subdata(in: (cmadOffset + 8)..<(cmadOffset + 8 + cmadSize))
                cmadSettings = parseCMAD(from: cmadData)
            }
        }

        // Map interaction mode per spec: Toggle=1, Hold=2, Direct=3, Relative=4,
        // Increment=5, Decrement=6, Reset=7, Output=8
        let interactionMode: InteractionMode
        switch cmadSettings.interactionMode {
        case 1: interactionMode = .toggle
        case 2: interactionMode = .hold
        case 3: interactionMode = .direct
        case 4: interactionMode = .relative
        case 8: interactionMode = .output
        default: interactionMode = ioType == .output ? .output : .hold
        }

        // Map controller type per spec: Button=0, Fader=1, Encoder=2, LED=65535
        let controllerType: ControllerType
        switch cmadSettings.controllerType {
        case 0: controllerType = .button
        case 1, 2: controllerType = .faderOrKnob
        case 65535: controllerType = .button  // LED
        default: controllerType = .button
        }

        // Look up command name from Traktor's command database
        let commandName = TraktorCommands.name(for: traktorControlId)

        // Parse MIDI info from control name
        let (channel, noteOrCC, isCc) = parseMidiControlName(midiControlName)

        // Map target deck per TSI spec:
        // -1 = Device Target (use device's default)
        // 0 = Global/DeckA/FX1 (context dependent, treat as Global)
        // 1-4 = Decks A-D (but TSI uses 1=B, 2=C, 3=D, 4=unused)
        // 5-8 = FX Units 1-4
        // Actually per spec: 0=A, 1=B, 2=C, 3=D for decks when contextual
        let assignment: TargetAssignment
        switch cmadSettings.targetDeck {
        case -1: assignment = .deviceTarget
        case 0: assignment = .global  // Or DeckA depending on command type
        case 1: assignment = .deckA
        case 2: assignment = .deckB
        case 3: assignment = .deckC
        case 4: assignment = .deckD
        case 5: assignment = .fxUnit1
        case 6: assignment = .fxUnit2
        case 7: assignment = .fxUnit3
        case 8: assignment = .fxUnit4
        default: assignment = .global
        }

        // Build modifier conditions from parsed values
        let modifier1: ModifierCondition? = cmadSettings.modifierOneId > 0
            ? ModifierCondition(modifier: cmadSettings.modifierOneId, value: cmadSettings.modifierOneValue)
            : nil
        let modifier2: ModifierCondition? = cmadSettings.modifierTwoId > 0
            ? ModifierCondition(modifier: cmadSettings.modifierTwoId, value: cmadSettings.modifierTwoValue)
            : nil

        return MappingEntry(
            commandName: commandName,
            ioType: ioType,
            assignment: assignment,
            interactionMode: interactionMode,
            midiChannel: channel,
            midiNote: isCc ? nil : noteOrCC,
            midiCC: isCc ? noteOrCC : nil,
            modifier1Condition: modifier1,
            modifier2Condition: modifier2,
            comment: cmadSettings.comment,
            controllerType: controllerType,
            invert: cmadSettings.invert,
            softTakeover: cmadSettings.softTakeover,
            setToValue: cmadSettings.setToValue,
            rotarySensitivity: cmadSettings.rotarySensitivity,
            rotaryAcceleration: cmadSettings.rotaryAcceleration
        )
    }

    /// Parse CMAD (Controller Mapping Assignment Data)
    /// Per TSI spec (github.com/ivanz/TraktorMappingFileFormat):
    /// - Bytes 0-3: Unknown1 (constant 4)
    /// - Bytes 4-7: ControllerType (Button=0, FaderOrKnob=1, Encoder=2, LED=65535)
    /// - Bytes 8-11: InteractionMode (Toggle=1, Hold=2, Direct=3, Relative=4, Output=8)
    /// - Bytes 12-15: Deck (-1=Device, 0-3=Decks A-D, 4-15=FX/Remix slots)
    /// - Bytes 16-19: AutoRepeat
    /// - Bytes 20-23: Invert
    /// - Bytes 24-27: SoftTakeover
    /// - Bytes 28-31: RotarySensitivity (float)
    /// - Bytes 32-35: RotaryAcceleration (float)
    /// - Bytes 36-43: Unknown
    /// - Bytes 44-47: SetValueTo (float)
    /// - Bytes 48-51: CommentLength
    /// - Bytes 52+: Comment (variable length wchar_t[])
    /// - After comment: ModifierOneId, ModifierOneValue, ModifierTwoId, ModifierTwoValue, LED settings
    private struct CMADParsed {
        var controllerType: Int = 0
        var interactionMode: Int = 0
        var targetDeck: Int = -1
        var invert: Bool = false
        var softTakeover: Bool = false
        var rotarySensitivity: Float = 1.0
        var rotaryAcceleration: Float = 0.0
        var setToValue: Float = 0.0
        var comment: String = ""
        var modifierOneId: Int = 0
        var modifierOneValue: Int = 0
        var modifierTwoId: Int = 0
        var modifierTwoValue: Int = 0
    }

    private static func parseCMAD(from data: Data) -> CMADParsed {
        var result = CMADParsed()

        guard data.count >= 52 else { return result }

        // Controller type at bytes 4-7
        result.controllerType = Int(readUInt32BE(from: data, at: 4))

        // Interaction mode at bytes 8-11
        result.interactionMode = Int(readUInt32BE(from: data, at: 8))

        // Target deck at bytes 12-15 (signed, -1 = device target)
        let deckValue = Int32(bitPattern: readUInt32BE(from: data, at: 12))
        result.targetDeck = Int(deckValue)

        // Invert at bytes 20-23
        result.invert = readUInt32BE(from: data, at: 20) != 0

        // SoftTakeover at bytes 24-27
        result.softTakeover = readUInt32BE(from: data, at: 24) != 0

        // RotarySensitivity at bytes 28-31 (float)
        result.rotarySensitivity = readFloatBE(from: data, at: 28)

        // RotaryAcceleration at bytes 32-35 (float)
        result.rotaryAcceleration = readFloatBE(from: data, at: 32)

        // SetValueTo at bytes 44-47 (float)
        result.setToValue = readFloatBE(from: data, at: 44)

        // Comment: length at bytes 48-51, then wchar_t[] string
        guard data.count >= 52 else { return result }
        let commentLength = Int(readUInt32BE(from: data, at: 48))

        if commentLength > 0 && commentLength < 1000 {
            let commentStart = 52
            let commentEnd = commentStart + commentLength * 2

            if commentEnd <= data.count {
                var commentStr = ""
                for i in stride(from: commentStart, to: commentEnd, by: 2) {
                    let hi = UInt16(data[i])
                    let lo = UInt16(data[i + 1])
                    let codeUnit = (hi << 8) | lo
                    if let scalar = UnicodeScalar(codeUnit) {
                        commentStr.append(Character(scalar))
                    }
                }
                result.comment = commentStr

                // After comment: modifier IDs and values (4 x 4 bytes)
                let modifierOffset = commentEnd
                if modifierOffset + 16 <= data.count {
                    result.modifierOneId = Int(readUInt32BE(from: data, at: modifierOffset))
                    result.modifierOneValue = Int(readUInt32BE(from: data, at: modifierOffset + 4))
                    result.modifierTwoId = Int(readUInt32BE(from: data, at: modifierOffset + 8))
                    result.modifierTwoValue = Int(readUInt32BE(from: data, at: modifierOffset + 12))
                }
            }
        } else {
            // No comment, modifiers start at byte 52
            if data.count >= 68 {
                result.modifierOneId = Int(readUInt32BE(from: data, at: 52))
                result.modifierOneValue = Int(readUInt32BE(from: data, at: 56))
                result.modifierTwoId = Int(readUInt32BE(from: data, at: 60))
                result.modifierTwoValue = Int(readUInt32BE(from: data, at: 64))
            }
        }

        return result
    }

    /// Reads a big-endian float from data at the given offset
    private static func readFloatBE(from data: Data, at offset: Int) -> Float {
        guard offset + 4 <= data.count else { return 0.0 }
        let bits = readUInt32BE(from: data, at: offset)
        return Float(bitPattern: bits)
    }

    // MARK: - MIDI Control Name Parsing

    /// Parses a MIDI control name like "Ch01.CC.100" or "Ch09.Note.A#2"
    /// Returns (channel, noteOrCCNumber, isCC)
    private static func parseMidiControlName(_ name: String) -> (Int, Int?, Bool) {
        // Parse channel
        var channel = 1
        if let chRange = name.range(of: "Ch"),
           let dotRange = name.range(of: ".", range: chRange.upperBound..<name.endIndex) {
            let chStr = String(name[chRange.upperBound..<dotRange.lowerBound])
            if let ch = Int(chStr) {
                channel = ch
            }
        }

        // Check if CC or Note
        let isCC = name.contains(".CC.")
        var number: Int? = nil

        if isCC {
            // Parse CC number
            if let ccRange = name.range(of: ".CC.") {
                let ccStr = String(name[ccRange.upperBound...])
                number = Int(ccStr)
            }
        } else if name.contains(".Note.") {
            // Parse MIDI note name
            if let noteRange = name.range(of: ".Note.") {
                let noteName = String(name[noteRange.upperBound...])
                number = midiNoteNumber(from: noteName)
            }
        }

        return (channel, number, isCC)
    }

    /// Converts a note name like "A#2" to MIDI note number
    private static func midiNoteNumber(from noteName: String) -> Int? {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        var note = noteName
        var octave = 0

        // Extract octave from end
        while let lastChar = note.last, lastChar.isNumber {
            octave = Int(String(lastChar))! + octave * 10
            note.removeLast()
        }

        // Handle negative octaves (like -1)
        if note.last == "-" {
            octave = -octave
            note.removeLast()
        }

        // Find note index
        guard let noteIndex = noteNames.firstIndex(of: note) else { return nil }

        // MIDI note: (octave + 1) * 12 + noteIndex
        // C-1 = 0, C0 = 12, C4 = 60
        return (octave + 1) * 12 + noteIndex
    }

    // MARK: - Utility Functions

    private static func readUTF16BEString(from data: Data, at offset: Int) -> (String, Int)? {
        guard offset + 4 <= data.count else { return nil }

        let lengthBytes = data.subdata(in: offset..<(offset + 4))
        let charCount = Int(lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

        guard charCount >= 0 && charCount < 10000 else { return nil }

        let byteCount = charCount * 2
        let stringEnd = offset + 4 + byteCount

        guard stringEnd <= data.count else { return nil }

        var decoded = ""
        for i in stride(from: offset + 4, to: stringEnd, by: 2) {
            let hi = UInt16(data[i])
            let lo = UInt16(data[i + 1])
            let codeUnit = (hi << 8) | lo
            if let scalar = UnicodeScalar(codeUnit) {
                decoded.append(Character(scalar))
            }
        }

        return (decoded, stringEnd)
    }

    private static func readUInt32BE(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let bytes = data.subdata(in: offset..<(offset + 4))
        return bytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    private static func findFrame(_ identifier: String, in data: Data) -> Int? {
        guard let idData = identifier.data(using: .ascii), idData.count == 4 else { return nil }

        for i in 0..<(data.count - 4) {
            if data[i] == idData[0] &&
               data[i+1] == idData[1] &&
               data[i+2] == idData[2] &&
               data[i+3] == idData[3] {
                return i
            }
        }
        return nil
    }

    private static func parseNestedFrames(from data: Data) throws -> [TSIFrame] {
        var frames: [TSIFrame] = []
        var offset = 0

        while offset < data.count - 8 {
            let remainingData = data.subdata(in: offset..<data.count)

            do {
                let frame = try TSIFrame.parse(from: remainingData)
                frames.append(frame)
                offset += frame.totalSize
            } catch {
                break
            }
        }

        return frames
    }
}
