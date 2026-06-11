//
//  TSIInterpreterTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import XCTest
@testable import XtremeMapping

final class TSIInterpreterTests: XCTestCase {

    // MARK: - MIDI Control Name Parsing Tests

    func testParseCCControlName() {
        // Test parsing "Ch01.CC.100"
        let result = parseMidiControlName("Ch01.CC.100")
        XCTAssertEqual(result.channel, 1)
        XCTAssertEqual(result.number, 100)
        XCTAssertTrue(result.isCC)
    }

    func testParseCCControlNameChannel9() {
        let result = parseMidiControlName("Ch09.CC.016")
        XCTAssertEqual(result.channel, 9)
        XCTAssertEqual(result.number, 16)
        XCTAssertTrue(result.isCC)
    }

    func testParseCCControlNameChannel16() {
        let result = parseMidiControlName("Ch16.CC.127")
        XCTAssertEqual(result.channel, 16)
        XCTAssertEqual(result.number, 127)
        XCTAssertTrue(result.isCC)
    }

    func testParseNoteControlName() {
        let result = parseMidiControlName("Ch09.Note.C2")
        XCTAssertEqual(result.channel, 9)
        XCTAssertFalse(result.isCC)
        // C2 = MIDI note 36 (C-1=0, C0=12, C1=24, C2=36)
        XCTAssertEqual(result.number, 36)
    }

    func testParseNoteControlNameSharp() {
        let result = parseMidiControlName("Ch01.Note.A#2")
        XCTAssertEqual(result.channel, 1)
        XCTAssertFalse(result.isCC)
        // A#2 = MIDI note 46
        XCTAssertEqual(result.number, 46)
    }

    func testParseNoteControlNameHighOctave() {
        let result = parseMidiControlName("Ch05.Note.G8")
        XCTAssertEqual(result.channel, 5)
        XCTAssertFalse(result.isCC)
        // G8 = MIDI note 115
        XCTAssertEqual(result.number, 115)
    }

    func testParseInvalidControlName() {
        let result = parseMidiControlName("InvalidName")
        XCTAssertEqual(result.channel, 1) // Default
        XCTAssertNil(result.number)
    }

    // MARK: - MIDI Note Number Conversion Tests

    func testMidiNoteNumberC0() {
        XCTAssertEqual(midiNoteNumber(from: "C0"), 12)
    }

    func testMidiNoteNumberC4() {
        // Middle C
        XCTAssertEqual(midiNoteNumber(from: "C4"), 60)
    }

    func testMidiNoteNumberA4() {
        // A440
        XCTAssertEqual(midiNoteNumber(from: "A4"), 69)
    }

    func testMidiNoteNumberCSharp2() {
        XCTAssertEqual(midiNoteNumber(from: "C#2"), 37)
    }

    func testMidiNoteNumberFSharp5() {
        XCTAssertEqual(midiNoteNumber(from: "F#5"), 78)
    }

    func testMidiNoteNumberB7() {
        XCTAssertEqual(midiNoteNumber(from: "B7"), 107)
    }

    func testMidiNoteNumberInvalidNote() {
        XCTAssertNil(midiNoteNumber(from: "X5"))
    }

    // MARK: - Interaction Mode Mapping Tests

    func testInteractionModeToggle() {
        XCTAssertEqual(interactionMode(from: 1), .toggle)
    }

    func testInteractionModeHold() {
        XCTAssertEqual(interactionMode(from: 2), .hold)
    }

    func testInteractionModeDirect() {
        XCTAssertEqual(interactionMode(from: 3), .direct)
    }

    func testInteractionModeRelative() {
        XCTAssertEqual(interactionMode(from: 4), .relative)
    }

    func testInteractionModeOutput() {
        XCTAssertEqual(interactionMode(from: 8), .output)
    }

    func testInteractionModeTrigger() {
        XCTAssertEqual(interactionMode(from: 0), .trigger)
    }

    func testInteractionModeIncrement() {
        XCTAssertEqual(interactionMode(from: 5), .increment)
    }

    func testInteractionModeDecrement() {
        XCTAssertEqual(interactionMode(from: 6), .decrement)
    }

    func testInteractionModeReset() {
        XCTAssertEqual(interactionMode(from: 7), .reset)
    }

    func testInteractionModeUnknownDefaultsToHold() {
        XCTAssertEqual(interactionMode(from: 99, isOutput: false), .hold)
    }

    func testInteractionModeUnknownDefaultsToOutputForOutput() {
        XCTAssertEqual(interactionMode(from: 99, isOutput: true), .output)
    }

    // MARK: - Controller Type Mapping Tests

    func testControllerTypeButton() {
        XCTAssertEqual(controllerType(from: 0), .button)
    }

    func testControllerTypeFader() {
        XCTAssertEqual(controllerType(from: 1), .faderOrKnob)
    }

    func testControllerTypeEncoder() {
        XCTAssertEqual(controllerType(from: 2), .encoder)
    }

    func testControllerTypeLED() {
        XCTAssertEqual(controllerType(from: 65535), .led)
    }

    // MARK: - Target Deck Mapping Tests

    func testTargetDeckDeviceTarget() {
        XCTAssertEqual(targetAssignment(from: -1), .deviceTarget)
    }

    func testTargetDeckGlobal() {
        // Spec value 0 decodes as deckA (writer encodes both global and deckA as 0)
        XCTAssertEqual(targetAssignment(from: 0), .deckA)
    }

    func testTargetDeckB() {
        XCTAssertEqual(targetAssignment(from: 1), .deckB)
    }

    func testTargetDeckC() {
        XCTAssertEqual(targetAssignment(from: 2), .deckC)
    }

    func testTargetDeckD() {
        XCTAssertEqual(targetAssignment(from: 3), .deckD)
    }

    func testTargetFXUnit1() {
        XCTAssertEqual(targetAssignment(from: 4), .fxUnit1)
    }

    func testTargetFXUnit2() {
        XCTAssertEqual(targetAssignment(from: 5), .fxUnit2)
    }

    func testTargetFXUnit3() {
        XCTAssertEqual(targetAssignment(from: 6), .fxUnit3)
    }

    func testTargetFXUnit4() {
        XCTAssertEqual(targetAssignment(from: 7), .fxUnit4)
    }

    func testTargetUnknownDefaultsToGlobal() {
        XCTAssertEqual(targetAssignment(from: 99), .global)
    }

    // MARK: - Round-Trip Tests

    /// Write a Device through TSIWriter, parse it back through TSIInterpreter,
    /// and return the first device from the result.
    private func roundTripDevice(_ device: Device) throws -> Device? {
        let writer = TSIWriter()
        let tsiData = writer.write(MappingFile(devices: [device]))

        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)
        return result.devices.first
    }

    /// Write a MappingEntry through TSIWriter, parse it back through TSIInterpreter,
    /// and return the first mapping from the result.
    private func roundTrip(_ entry: MappingEntry) throws -> MappingEntry? {
        try roundTripDevice(Device(name: "Test", mappings: [entry]))?.mappings.first
    }

    func testRoundTripPreservesInteractionModes() throws {
        let modes: [InteractionMode] = [.trigger, .toggle, .hold, .direct, .relative, .increment, .decrement, .reset, .output]
        for mode in modes {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: mode == .output ? .output : .input,
                assignment: .deckA,
                interactionMode: mode,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.interactionMode, mode, "InteractionMode \(mode) did not survive round-trip")
        }
    }

    func testRoundTripPreservesControllerTypes() throws {
        let types: [ControllerType] = [.button, .faderOrKnob, .encoder, .led]
        for ctrlType in types {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: ctrlType == .led ? .output : .input,
                assignment: .deckA,
                interactionMode: ctrlType.defaultInteractionMode,
                midiChannel: 1,
                midiCC: 10,
                controllerType: ctrlType
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.controllerType, ctrlType, "ControllerType \(ctrlType) did not survive round-trip")
        }
    }

    func testRoundTripPreservesAssignments() throws {
        // .global and .deckA both encode as 0 — that's a TSI spec limitation, not a bug.
        // FX units encode as 4-7.
        let assignments: [TargetAssignment] = [.deviceTarget, .deckA, .deckB, .deckC, .deckD, .fxUnit1, .fxUnit2, .fxUnit3, .fxUnit4]
        for assign in assignments {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input, assignment: assign,
                interactionMode: .hold,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, assign, "TargetAssignment \(assign) did not survive round-trip")
        }
    }

    func testRoundTripFXUnitAssignments() throws {
        let fxAssignments: [TargetAssignment] = [.fxUnit1, .fxUnit2, .fxUnit3, .fxUnit4]

        for assignment in fxAssignments {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input,
                assignment: assignment,
                interactionMode: .toggle,
                midiChannel: 1,
                midiCC: 1,
                controllerType: .button
            )

            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, assignment,
                           "\(assignment.displayName) did not round-trip correctly")
        }
    }

    // MARK: - Modifier Condition Round-Trip Tests (Task 1.1)

    func testRoundTripPreservesModifier1Only() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3)
        )
        let result = try roundTrip(entry)
        XCTAssertEqual(result?.modifier1Condition, ModifierCondition(modifier: 2, value: 3))
        XCTAssertNil(result?.modifier2Condition)
    }

    func testRoundTripPreservesModifier2Only() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            modifier2Condition: ModifierCondition(modifier: 4, value: 5)
        )
        let result = try roundTrip(entry)
        XCTAssertNil(result?.modifier1Condition)
        XCTAssertEqual(result?.modifier2Condition, ModifierCondition(modifier: 4, value: 5))
    }

    func testRoundTripPreservesBothModifiersWithComment() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            modifier1Condition: ModifierCondition(modifier: 1, value: 7),
            modifier2Condition: ModifierCondition(modifier: 8, value: 2),
            comment: "shifted action"
        )
        let result = try roundTrip(entry)
        XCTAssertEqual(result?.modifier1Condition, ModifierCondition(modifier: 1, value: 7))
        XCTAssertEqual(result?.modifier2Condition, ModifierCondition(modifier: 8, value: 2))
        XCTAssertEqual(result?.comment, "shifted action")
    }

    func testRoundTripPreservesNoModifiers() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10
        )
        let result = try roundTrip(entry)
        XCTAssertNil(result?.modifier1Condition)
        XCTAssertNil(result?.modifier2Condition)
    }

    // MARK: - Unresolvable Command Filtering Tests (Task 1.2)

    func testRoundTripDropsUnresolvableMappingsAndKeepsBindingAlignment() throws {
        let invalid = MappingEntry(
            commandName: "Totally Unknown",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 5
        )
        let negative = MappingEntry(
            commandName: "Command #-1",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 6
        )
        let zero = MappingEntry(
            commandName: "Command #0",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 7
        )
        let valid = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10
        )

        let writer = TSIWriter()
        let device = Device(name: "Test", mappings: [invalid, negative, zero, valid])
        let tsiData = writer.write(MappingFile(devices: [device]))

        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)

        let mappings = result.devices.first?.mappings ?? []
        XCTAssertEqual(mappings.count, 1, "Only the resolvable mapping should survive")
        XCTAssertEqual(mappings.first?.commandName, "Play/Pause")
        XCTAssertEqual(mappings.first?.midiCC, 10, "Binding IDs must stay aligned after filtering")
        XCTAssertEqual(mappings.first?.midiChannel, 1)
    }

    // MARK: - Full TSI Target Value Round-Trip Tests (Task 1.3)

    func testRoundTripPreservesAllTSITargetValues() throws {
        // For each TSI deck value -1...15, use the case that ENCODES to that value
        // and assert it decodes back to the same case. .none/.global excluded —
        // both encode to 0 and decode as .deckA (documented collapse, below).
        let casesByTSIValue: [(tsiValue: Int, assignment: TargetAssignment)] = [
            (-1, .deviceTarget),
            (0, .deckA), (1, .deckB), (2, .deckC), (3, .deckD),
            (4, .fxUnit1), (5, .fxUnit2), (6, .fxUnit3), (7, .fxUnit4),
            (8, .remixSlot1), (9, .remixSlot2), (10, .remixSlot3), (11, .remixSlot4),
            (12, .remixSlot5), (13, .remixSlot6), (14, .remixSlot7), (15, .remixSlot8)
        ]
        for (tsiValue, assignment) in casesByTSIValue {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input, assignment: assignment, interactionMode: .hold,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, assignment,
                           "TSI deck value \(tsiValue) (\(assignment.displayName)) did not survive round-trip")
        }
    }

    func testGlobalAndNoneTargetsCollapseToDeckA() throws {
        // Documented TSI ambiguity: .global and .none both encode as deck value 0,
        // which decodes as .deckA.
        for assignment in [TargetAssignment.global, TargetAssignment.none] {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input, assignment: assignment, interactionMode: .hold,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, .deckA,
                           "\(assignment.displayName) should collapse to Deck A by design")
        }
    }

    // MARK: - Non-BMP Text Tests (Task 1.4)

    func testRoundTripPreservesNonBMPCommentAndDeviceName() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10,
            comment: "Fire 🔥 emoji"
        )
        let device = Device(name: "Mixer 🎛 Pro", mappings: [entry])

        var parsed: Device?
        XCTAssertNoThrow(parsed = try roundTripDevice(device))
        XCTAssertEqual(parsed?.name, "Mixer 🎛 Pro")
        XCTAssertEqual(parsed?.mappings.first?.comment, "Fire 🔥 emoji")
    }

    func testDecodeUTF16BESurrogatePair() {
        // 🔥 = U+1F525 = surrogate pair D83D DD25
        let bytes = Data([0xD8, 0x3D, 0xDD, 0x25])
        XCTAssertEqual(TSIInterpreter.decodeUTF16BE(from: bytes, at: 0, codeUnitCount: 2), "🔥")
    }

    func testDecodeUTF16BEMixedBMPAndSurrogates() {
        // "A🔥B" = 0041 D83D DD25 0042
        let bytes = Data([0x00, 0x41, 0xD8, 0x3D, 0xDD, 0x25, 0x00, 0x42])
        XCTAssertEqual(TSIInterpreter.decodeUTF16BE(from: bytes, at: 0, codeUnitCount: 4), "A🔥B")
    }

    func testDecodeUTF16BEOutOfBoundsReturnsEmpty() {
        let bytes = Data([0x00, 0x41])
        XCTAssertEqual(TSIInterpreter.decodeUTF16BE(from: bytes, at: 0, codeUnitCount: 5), "")
    }

    // MARK: - Device Metadata & CMAD Field Round-Trip Tests (Task 1.5)

    func testRoundTripPreservesDeviceMetadataAndCMADFields() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10,
            autoRepeat: true,
            ledMaxRangeData: 5,
            ledMinMidi: 10,
            ledMaxMidi: 100,
            ledInvert: true,
            resolution: 2
        )
        let device = Device(
            name: "Test",
            comment: "My controller",
            inPort: "Port A",
            outPort: "Port B",
            tsiVersion: "3.10.0",
            mappingFileRevision: 3,
            mappings: [entry]
        )

        let parsed = try roundTripDevice(device)
        XCTAssertEqual(parsed?.comment, "My controller")
        XCTAssertEqual(parsed?.inPort, "Port A")
        XCTAssertEqual(parsed?.outPort, "Port B")
        XCTAssertEqual(parsed?.tsiVersion, "3.10.0")
        XCTAssertEqual(parsed?.mappingFileRevision, 3)

        let mapping = parsed?.mappings.first
        XCTAssertEqual(mapping?.autoRepeat, true)
        XCTAssertEqual(mapping?.ledMaxRangeData, 5)
        XCTAssertEqual(mapping?.ledMinMidi, 10)
        XCTAssertEqual(mapping?.ledMaxMidi, 100)
        XCTAssertEqual(mapping?.ledInvert, true)
        XCTAssertEqual(mapping?.resolution, 2)
        // Untouched fields keep their defaults
        XCTAssertEqual(mapping?.ledMinRangeType, 0)
        XCTAssertEqual(mapping?.ledMinRangeData, 0)
        XCTAssertEqual(mapping?.ledMaxRangeType, 0)
        XCTAssertEqual(mapping?.ledBlend, false)
    }

    // MARK: - Direction-Aware DCDT Tests (Task 1.6)

    /// Scans raw TSI binary for DCDT frames, returning (controlName, midiControlType) pairs.
    private func scanDCDTEntries(in data: Data) -> [(name: String, controlType: Int)] {
        var entries: [(String, Int)] = []
        var offset = 0
        while offset < data.count - 8 {
            let marker = data.subdata(in: offset..<(offset + 4))
            guard String(data: marker, encoding: .ascii) == "DCDT" else {
                offset += 1
                continue
            }
            let size = Int(data.subdata(in: (offset + 4)..<(offset + 8)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            guard size > 8, offset + 8 + size <= data.count else {
                offset += 1
                continue
            }
            let frameData = data.subdata(in: (offset + 8)..<(offset + 8 + size))
            let strLen = Int(frameData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            if strLen > 0, 4 + strLen * 2 + 4 <= frameData.count {
                let name = TSIInterpreter.decodeUTF16BE(from: frameData, at: 4, codeUnitCount: strLen)
                let typeOffset = 4 + strLen * 2
                let controlType = Int(frameData.subdata(in: typeOffset..<(typeOffset + 4)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                entries.append((name, controlType))
            }
            offset += 8 + size
        }
        return entries
    }

    func testDCDTEmitsDirectionAwareEntriesForSharedControl() throws {
        let inMapping = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 20, controllerType: .button
        )
        let outMapping = MappingEntry(
            commandName: "Is Playing",
            ioType: .output, assignment: .deckA, interactionMode: .output,
            midiChannel: 1, midiCC: 20, controllerType: .led
        )
        let device = Device(name: "Test", mappings: [inMapping, outMapping])

        let writer = TSIWriter()
        let tsiData = writer.write(MappingFile(devices: [device]))
        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)

        let dcdtEntries = scanDCDTEntries(in: binaryData)
        XCTAssertEqual(dcdtEntries.count, 2, "Expected one DCDT per (control, direction) pair")
        XCTAssertTrue(dcdtEntries.contains { $0.name == "Ch01.CC.020" && $0.controlType == 7 },
                      "Missing IN entry (MidiControlType 7) for Ch01.CC.020")
        XCTAssertTrue(dcdtEntries.contains { $0.name == "Ch01.CC.020" && $0.controlType == 8 },
                      "Missing OUT entry (MidiControlType 8) for Ch01.CC.020")

        // Both mappings must still resolve through the interpreter
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)
        let mappings = result.devices.first?.mappings ?? []
        XCTAssertEqual(mappings.count, 2)
        XCTAssertTrue(mappings.allSatisfy { $0.midiCC == 20 && $0.midiChannel == 1 },
                      "IN/OUT pair must not shift binding indices")
    }

    func testRoundTripSetToValueZero() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 7,
            controllerType: .faderOrKnob,
            setToValue: 0.0
        )

        let result = try roundTrip(entry)
        XCTAssertEqual(result?.setToValue, 0.0,
                       "setToValue of 0.0 should survive round-trip")
    }

    // MARK: - Helper Functions (Expose internal logic for testing)

    /// Parse MIDI control name - mirrors TSIInterpreter logic
    private func parseMidiControlName(_ name: String) -> (channel: Int, number: Int?, isCC: Bool) {
        var channel = 1
        if let chRange = name.range(of: "Ch"),
           let dotRange = name.range(of: ".", range: chRange.upperBound..<name.endIndex) {
            let chStr = String(name[chRange.upperBound..<dotRange.lowerBound])
            if let ch = Int(chStr) {
                channel = ch
            }
        }

        let isCC = name.contains(".CC.")
        var number: Int? = nil

        if isCC {
            if let ccRange = name.range(of: ".CC.") {
                let ccStr = String(name[ccRange.upperBound...])
                number = Int(ccStr)
            }
        } else if name.contains(".Note.") {
            if let noteRange = name.range(of: ".Note.") {
                let noteName = String(name[noteRange.upperBound...])
                number = midiNoteNumber(from: noteName)
            }
        }

        return (channel, number, isCC)
    }

    /// Convert note name to MIDI number - mirrors TSIInterpreter logic
    private func midiNoteNumber(from noteName: String) -> Int? {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        var note = noteName
        var octave = 0

        while let lastChar = note.last, lastChar.isNumber {
            octave = Int(String(lastChar))! + octave * 10
            note.removeLast()
        }

        if note.last == "-" {
            octave = -octave
            note.removeLast()
        }

        guard let noteIndex = noteNames.firstIndex(of: note) else { return nil }

        return (octave + 1) * 12 + noteIndex
    }

    /// Map interaction mode value - mirrors TSIInterpreter logic
    private func interactionMode(from value: Int, isOutput: Bool = false) -> InteractionMode {
        switch value {
        case 0: return .trigger
        case 1: return .toggle
        case 2: return .hold
        case 3: return .direct
        case 4: return .relative
        case 5: return .increment
        case 6: return .decrement
        case 7: return .reset
        case 8: return .output
        default: return isOutput ? .output : .hold
        }
    }

    /// Map controller type value - mirrors TSIInterpreter logic
    private func controllerType(from value: Int) -> ControllerType {
        switch value {
        case 0: return .button
        case 1: return .faderOrKnob
        case 2: return .encoder
        case 65535: return .led
        default: return .button
        }
    }

    /// Map target deck value - mirrors TSIInterpreter logic
    private func targetAssignment(from value: Int) -> TargetAssignment {
        switch value {
        case -1: return .deviceTarget
        case 0: return .deckA
        case 1: return .deckB
        case 2: return .deckC
        case 3: return .deckD
        case 4: return .fxUnit1
        case 5: return .fxUnit2
        case 6: return .fxUnit3
        case 7: return .fxUnit4
        default: return .global
        }
    }
}
