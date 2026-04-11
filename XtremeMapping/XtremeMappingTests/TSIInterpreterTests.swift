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

    /// Write a MappingEntry through TSIWriter, parse it back through TSIInterpreter,
    /// and return the first mapping from the result.
    private func roundTrip(_ entry: MappingEntry) throws -> MappingEntry? {
        let writer = TSIWriter()
        let device = Device(name: "Test", mappings: [entry])
        let tsiData = writer.write(MappingFile(devices: [device]))

        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)
        return result.devices.first?.mappings.first
    }

    func testRoundTripPreservesInteractionModes() throws {
        let modes: [InteractionMode] = [.trigger, .toggle, .hold, .direct, .relative, .increment, .decrement, .reset, .output]
        for mode in modes {
            let entry = MappingEntry(
                commandName: "Deck Common.Play/Pause",
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
                commandName: "Deck Common.Play/Pause",
                ioType: ctrlType == .led ? .output : .input,
                assignment: .deckA,
                interactionMode: ctrlType.defaultInteractionMode,
                controllerType: ctrlType,
                midiChannel: 1, midiCC: 10
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
                commandName: "Deck Common.Play/Pause",
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
                commandName: "Deck Common.Play/Pause",
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

    func testRoundTripSetToValueZero() throws {
        let entry = MappingEntry(
            commandName: "Deck Common.Play/Pause",
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
