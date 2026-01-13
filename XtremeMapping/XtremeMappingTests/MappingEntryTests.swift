//
//  MappingEntryTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Testing
@testable import XtremeMapping

struct MappingEntryTests {

    // MARK: - MappedToDisplay Tests

    @Test func testMappedToDisplayCC() {
        let entry = MappingEntry(midiChannel: 1, midiCC: 8)
        #expect(entry.mappedToDisplay == "Ch01 CC 008")
    }

    @Test func testMappedToDisplayNote() {
        let entry = MappingEntry(midiChannel: 2, midiNote: 60)
        #expect(entry.mappedToDisplay == "Ch02 Note C4")
    }

    @Test func testMappedToDisplayNoteSharp() {
        // D#5 is MIDI note 75
        let entry = MappingEntry(midiChannel: 10, midiNote: 75)
        #expect(entry.mappedToDisplay == "Ch10 Note D#5")
    }

    @Test func testMappedToDisplayHighChannel() {
        let entry = MappingEntry(midiChannel: 16, midiCC: 127)
        #expect(entry.mappedToDisplay == "Ch16 CC 127")
    }

    @Test func testMappedToDisplayLowestNote() {
        // MIDI note 0 is C-1 (or C0 depending on convention, we'll use C-1)
        let entry = MappingEntry(midiChannel: 1, midiNote: 0)
        #expect(entry.mappedToDisplay == "Ch01 Note C-1")
    }

    // MARK: - ModifierCondition Tests

    @Test func testModifierConditionDisplay() {
        let condition = ModifierCondition(modifier: 4, value: 2)
        #expect(condition.displayString == "M4 = 2")
    }

    @Test func testModifierConditionDisplayM1() {
        let condition = ModifierCondition(modifier: 1, value: 0)
        #expect(condition.displayString == "M1 = 0")
    }

    @Test func testModifierConditionDisplayM8() {
        let condition = ModifierCondition(modifier: 8, value: 7)
        #expect(condition.displayString == "M8 = 7")
    }

    // MARK: - ControllerType Tests

    @Test func testControllerTypeDisplayNames() {
        #expect(ControllerType.button.displayName == "Button")
        #expect(ControllerType.faderOrKnob.displayName == "Fader/Knob")
        #expect(ControllerType.encoder.displayName == "Encoder")
        #expect(ControllerType.led.displayName == "LED")
    }

    @Test func testControllerTypeRawValues() {
        #expect(ControllerType.button.rawValue == 0)
        #expect(ControllerType.faderOrKnob.rawValue == 1)
        #expect(ControllerType.encoder.rawValue == 2)
        #expect(ControllerType.led.rawValue == 65535)
    }

    // MARK: - InteractionMode Tests

    @Test func testInteractionModeDisplayNames() {
        #expect(InteractionMode.toggle.displayName == "Toggle")
        #expect(InteractionMode.hold.displayName == "Hold")
        #expect(InteractionMode.direct.displayName == "Direct")
        #expect(InteractionMode.relative.displayName == "Relative")
        #expect(InteractionMode.increment.displayName == "Inc")
        #expect(InteractionMode.decrement.displayName == "Dec")
        #expect(InteractionMode.reset.displayName == "Reset")
        #expect(InteractionMode.output.displayName == "Output")
        #expect(InteractionMode.trigger.displayName == "Trigger")
    }

    @Test func testInteractionModeRawValues() {
        #expect(InteractionMode.toggle.rawValue == 0)
        #expect(InteractionMode.hold.rawValue == 1)
        #expect(InteractionMode.direct.rawValue == 2)
        #expect(InteractionMode.relative.rawValue == 3)
        #expect(InteractionMode.increment.rawValue == 4)
        #expect(InteractionMode.decrement.rawValue == 5)
        #expect(InteractionMode.reset.rawValue == 6)
        #expect(InteractionMode.output.rawValue == 7)
        #expect(InteractionMode.trigger.rawValue == 8)
    }

    // MARK: - TargetAssignment Tests

    @Test func testTargetAssignmentDisplayNames() {
        #expect(TargetAssignment.deviceTarget.displayName == "Device Target")
        #expect(TargetAssignment.global.displayName == "Global")
        #expect(TargetAssignment.deckA.displayName == "Deck A")
        #expect(TargetAssignment.deckB.displayName == "Deck B")
        #expect(TargetAssignment.deckC.displayName == "Deck C")
        #expect(TargetAssignment.deckD.displayName == "Deck D")
        #expect(TargetAssignment.fxUnit1.displayName == "FX Unit 1")
        #expect(TargetAssignment.fxUnit2.displayName == "FX Unit 2")
        #expect(TargetAssignment.fxUnit3.displayName == "FX Unit 3")
        #expect(TargetAssignment.fxUnit4.displayName == "FX Unit 4")
    }

    @Test func testTargetAssignmentRawValues() {
        #expect(TargetAssignment.deviceTarget.rawValue == -1)
        #expect(TargetAssignment.global.rawValue == 0)
        #expect(TargetAssignment.deckA.rawValue == 1)
        #expect(TargetAssignment.deckB.rawValue == 2)
        #expect(TargetAssignment.deckC.rawValue == 3)
        #expect(TargetAssignment.deckD.rawValue == 4)
        #expect(TargetAssignment.fxUnit1.rawValue == 5)
        #expect(TargetAssignment.fxUnit2.rawValue == 6)
        #expect(TargetAssignment.fxUnit3.rawValue == 7)
        #expect(TargetAssignment.fxUnit4.rawValue == 8)
    }

    // MARK: - CommandCategory Tests

    @Test func testCommandCategoryRawValues() {
        #expect(CommandCategory.all.rawValue == "All")
        #expect(CommandCategory.decks.rawValue == "Decks")
        #expect(CommandCategory.sampleDecks.rawValue == "Sample Decks")
        #expect(CommandCategory.effectsUnits.rawValue == "Effects Units")
        #expect(CommandCategory.mixer.rawValue == "Mixer")
        #expect(CommandCategory.cueLoops.rawValue == "Cue/Loops")
        #expect(CommandCategory.loopRecorder.rawValue == "Loop Recorder")
        #expect(CommandCategory.browser.rawValue == "Browser")
        #expect(CommandCategory.globals.rawValue == "Globals")
    }

    // MARK: - IODirection Tests

    @Test func testIODirectionRawValues() {
        #expect(IODirection.all.rawValue == "All")
        #expect(IODirection.input.rawValue == "In")
        #expect(IODirection.output.rawValue == "Out")
    }

    // MARK: - Device Tests

    @Test func testDeviceDefaultInit() {
        let device = Device()
        #expect(device.name == "")
        #expect(device.comment == "")
        #expect(device.inPort == "")
        #expect(device.outPort == "")
        #expect(device.mappings.isEmpty)
    }

    @Test func testDeviceWithMappings() {
        let mapping = MappingEntry(commandName: "Play", midiChannel: 1, midiNote: 60)
        let device = Device(name: "Kontrol S4", mappings: [mapping])
        #expect(device.name == "Kontrol S4")
        #expect(device.mappings.count == 1)
        #expect(device.mappings[0].commandName == "Play")
    }

    // MARK: - MappingFile Tests

    @Test func testMappingFileDefaultInit() {
        let file = MappingFile()
        #expect(file.devices.isEmpty)
        #expect(file.version == 0)
    }

    @Test func testMappingFileAllMappings() {
        let mapping1 = MappingEntry(commandName: "Play", midiChannel: 1, midiNote: 60)
        let mapping2 = MappingEntry(commandName: "Cue", midiChannel: 1, midiNote: 61)
        let mapping3 = MappingEntry(commandName: "Sync", midiChannel: 2, midiNote: 62)

        let device1 = Device(name: "Device 1", mappings: [mapping1, mapping2])
        let device2 = Device(name: "Device 2", mappings: [mapping3])

        let file = MappingFile(devices: [device1, device2])
        #expect(file.allMappings.count == 3)
    }

    // MARK: - MappingEntry Default Init Tests

    @Test func testMappingEntryDefaultInit() {
        let entry = MappingEntry()
        #expect(entry.commandName == "")
        #expect(entry.ioType == .input)
        #expect(entry.assignment == .global)
        #expect(entry.interactionMode == .hold)
        #expect(entry.midiChannel == 1)
        #expect(entry.midiNote == nil)
        #expect(entry.midiCC == nil)
        #expect(entry.modifier1Condition == nil)
        #expect(entry.modifier2Condition == nil)
        #expect(entry.comment == "")
        #expect(entry.controllerType == .button)
        #expect(entry.invert == false)
    }

    // MARK: - MappingEntry Identifiable Tests

    @Test func testMappingEntryHasUniqueID() {
        let entry1 = MappingEntry()
        let entry2 = MappingEntry()
        #expect(entry1.id != entry2.id)
    }

    // MARK: - MIDI Note to Name Conversion Tests

    @Test func testMidiNoteC4() {
        let entry = MappingEntry(midiChannel: 1, midiNote: 60)
        #expect(entry.mappedToDisplay.contains("C4"))
    }

    @Test func testMidiNoteA4() {
        // A4 is MIDI note 69
        let entry = MappingEntry(midiChannel: 1, midiNote: 69)
        #expect(entry.mappedToDisplay.contains("A4"))
    }

    @Test func testMidiNoteHighestNote() {
        // G9 is MIDI note 127
        let entry = MappingEntry(midiChannel: 1, midiNote: 127)
        #expect(entry.mappedToDisplay.contains("G9"))
    }
}
