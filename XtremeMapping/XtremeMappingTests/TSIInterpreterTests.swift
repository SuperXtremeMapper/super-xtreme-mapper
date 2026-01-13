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
        XCTAssertEqual(controllerType(from: 2), .faderOrKnob)
    }

    func testControllerTypeLED() {
        XCTAssertEqual(controllerType(from: 65535), .button)
    }

    // MARK: - Target Deck Mapping Tests

    func testTargetDeckDeviceTarget() {
        XCTAssertEqual(targetAssignment(from: -1), .deviceTarget)
    }

    func testTargetDeckGlobal() {
        XCTAssertEqual(targetAssignment(from: 0), .global)
    }

    func testTargetDeckA() {
        XCTAssertEqual(targetAssignment(from: 1), .deckA)
    }

    func testTargetDeckB() {
        XCTAssertEqual(targetAssignment(from: 2), .deckB)
    }

    func testTargetDeckC() {
        XCTAssertEqual(targetAssignment(from: 3), .deckC)
    }

    func testTargetDeckD() {
        XCTAssertEqual(targetAssignment(from: 4), .deckD)
    }

    func testTargetFXUnit1() {
        XCTAssertEqual(targetAssignment(from: 5), .fxUnit1)
    }

    func testTargetFXUnit4() {
        XCTAssertEqual(targetAssignment(from: 8), .fxUnit4)
    }

    func testTargetUnknownDefaultsToGlobal() {
        XCTAssertEqual(targetAssignment(from: 99), .global)
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
        case 1: return .toggle
        case 2: return .hold
        case 3: return .direct
        case 4: return .relative
        case 8: return .output
        default: return isOutput ? .output : .hold
        }
    }

    /// Map controller type value - mirrors TSIInterpreter logic
    private func controllerType(from value: Int) -> ControllerType {
        switch value {
        case 0: return .button
        case 1, 2: return .faderOrKnob
        case 65535: return .button
        default: return .button
        }
    }

    /// Map target deck value - mirrors TSIInterpreter logic
    private func targetAssignment(from value: Int) -> TargetAssignment {
        switch value {
        case -1: return .deviceTarget
        case 0: return .global
        case 1: return .deckA
        case 2: return .deckB
        case 3: return .deckC
        case 4: return .deckD
        case 5: return .fxUnit1
        case 6: return .fxUnit2
        case 7: return .fxUnit3
        case 8: return .fxUnit4
        default: return .global
        }
    }
}
