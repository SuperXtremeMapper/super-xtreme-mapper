//
//  MappingEntryTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Testing
import Foundation
@testable import XtremeMapping

struct MappingEntryTests {

    @Test func copyWithNewIDChangesOnlyIdentity() {
        let source = MappingEntry.fullFieldSentinel
        let copy = source.copyWithNewID()

        #expect(copy.id != source.id)
        #expect(copy.commandID == source.commandID)
        #expect(copy.ioType == source.ioType)
        #expect(copy.assignment == source.assignment)
        #expect(copy.interactionMode == source.interactionMode)
        #expect(copy.midiAssignment == source.midiAssignment)
        #expect(copy.modifier1Condition == source.modifier1Condition)
        #expect(copy.modifier2Condition == source.modifier2Condition)
        #expect(copy.comment == source.comment)
        #expect(copy.controllerType == source.controllerType)
        #expect(copy.invert == source.invert)
        #expect(copy.softTakeover == source.softTakeover)
        #expect(copy.setToValue == source.setToValue)
        #expect(copy.rotarySensitivity == source.rotarySensitivity)
        #expect(copy.rotaryAcceleration == source.rotaryAcceleration)
        #expect(copy.encoderMode == source.encoderMode)
        #expect(copy.rawDCDTEncoderMode == source.rawDCDTEncoderMode)
        #expect(copy.autoRepeat == source.autoRepeat)
        #expect(copy.ledMinRangeType == source.ledMinRangeType)
        #expect(copy.ledMinRangeData == source.ledMinRangeData)
        #expect(copy.ledMaxRangeType == source.ledMaxRangeType)
        #expect(copy.ledMaxRangeData == source.ledMaxRangeData)
        #expect(copy.ledMinMidi == source.ledMinMidi)
        #expect(copy.ledMaxMidi == source.ledMaxMidi)
        #expect(copy.ledInvert == source.ledInvert)
        #expect(copy.ledBlend == source.ledBlend)
        #expect(copy.resolution == source.resolution)
        #expect(copy.importedCMAD == source.importedCMAD)
    }

    @Test func opaqueMidiCompatibilityStateCopiesCodablesAndClearsOnAssignment() throws {
        var source = MappingEntry(
            commandID: 100,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 5,
            rawDCDTMinValueBits: Float32(-1).bitPattern,
            rawDCDTMaxValueBits: Float32(1).bitPattern,
            rawDCDTControlID: 42
        )

        let copy = source.copyWithNewID()
        #expect(copy.rawMidiControlName == "Ch02.PitchBend")
        #expect(copy.rawDCDTControlType == 5)
        #expect(copy.rawDCDTMinValueBits == Float32(-1).bitPattern)
        #expect(copy.rawDCDTMaxValueBits == Float32(1).bitPattern)
        #expect(copy.rawDCDTControlID == 42)

        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONEncoder().encode(source)
        )
        #expect(decoded.rawMidiControlName == source.rawMidiControlName)
        #expect(decoded.rawDCDTControlType == source.rawDCDTControlType)
        #expect(decoded.rawDCDTMinValueBits == source.rawDCDTMinValueBits)
        #expect(decoded.rawDCDTMaxValueBits == source.rawDCDTMaxValueBits)
        #expect(decoded.rawDCDTControlID == source.rawDCDTControlID)

        source.midiAssignment = try .controlChange(channel: 3, number: 12)
        #expect(source.rawMidiControlName == nil)
        #expect(source.rawMidiBindingID == nil)
        #expect(source.rawDCDTControlType == nil)
        #expect(source.rawDCDTMinValueBits == nil)
        #expect(source.rawDCDTMaxValueBits == nil)
        #expect(source.rawDCDTControlID == nil)
    }

    @Test func mappingFileAggregatesCompatibilityWarnings() {
        let opaque = MappingEntry(
            commandID: 100,
            rawMidiControlName: "Ch02.PitchBend"
        )
        let unresolved = MappingEntry(
            commandID: 201,
            rawMidiBindingID: 95
        )
        let file = MappingFile(devices: [
            Device(name: "Generic MIDI", mappings: [opaque, unresolved])
        ])

        #expect(file.tsiCompatibilityWarnings == [
            .opaqueMIDIControl(name: "Ch02.PitchBend"),
            .unresolvedMIDIBinding(id: 95),
        ])
    }

    // MARK: - Validated MIDI Assignment Tests

    @Test func noteAssignmentClearsControlChange() throws {
        var entry = MappingEntry(midiChannel: 1, midiCC: 7)
        entry.midiNote = 60

        expectAssignment(entry.midiAssignment, kind: .note, channel: 1, number: 60)
        #expect(entry.midiNote == 60)
        #expect(entry.midiCC == nil)
    }

    @Test func controlChangeAssignmentClearsNote() throws {
        var entry = MappingEntry(midiChannel: 2, midiNote: 61)
        entry.midiCC = 8

        expectAssignment(entry.midiAssignment, kind: .controlChange, channel: 2, number: 8)
        #expect(entry.midiNote == nil)
        #expect(entry.midiCC == 8)
    }

    @Test func settingNilNoteClearsOnlyCurrentNote() throws {
        var note = MappingEntry(midiChannel: 3, midiNote: 62)
        note.midiNote = nil
        expectAssignment(note.midiAssignment, kind: .unassigned, channel: 3, number: nil)

        var cc = MappingEntry(midiChannel: 4, midiCC: 9)
        cc.midiNote = nil
        expectAssignment(cc.midiAssignment, kind: .controlChange, channel: 4, number: 9)
    }

    @Test func settingNilControlChangeClearsOnlyCurrentControlChange() throws {
        var cc = MappingEntry(midiChannel: 5, midiCC: 10)
        cc.midiCC = nil
        expectAssignment(cc.midiAssignment, kind: .unassigned, channel: 5, number: nil)

        var note = MappingEntry(midiChannel: 6, midiNote: 63)
        note.midiCC = nil
        expectAssignment(note.midiAssignment, kind: .note, channel: 6, number: 63)
    }

    @Test func changingCompatibilityChannelPreservesAssignmentKindAndNumber() throws {
        var note = MappingEntry(midiChannel: 1, midiNote: 64)
        note.midiChannel = 16
        expectAssignment(note.midiAssignment, kind: .note, channel: 16, number: 64)

        var cc = MappingEntry(midiChannel: 2, midiCC: 11)
        cc.midiChannel = 15
        expectAssignment(cc.midiAssignment, kind: .controlChange, channel: 15, number: 11)
    }

    @Test func validatedAssignmentInitializerWinsOverLegacyDefaults() throws {
        let assignment = try MIDIAssignment.note(channel: 9, number: 69)
        let entry = MappingEntry(midiAssignment: assignment)

        expectAssignment(entry.midiAssignment, kind: .note, channel: 9, number: 69)
        #expect(entry.midiChannel == 9)
        #expect(entry.midiNote == 69)
        #expect(entry.midiCC == nil)
    }

    @Test func jsonRetainsLegacyMIDIKeys() throws {
        let entry = MappingEntry(midiAssignment: try .controlChange(channel: 16, number: 127))
        let json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )

        #expect(json["midiChannel"] as? Int == 16)
        #expect(json["midiNote"] == nil)
        #expect(json["midiCC"] as? Int == 127)
        #expect(json["midiAssignment"] == nil)
    }

    @Test(arguments: [
        ("midiChannel", 0),
        ("midiChannel", 17),
        ("midiNote", -1),
        ("midiNote", 128),
        ("midiCC", -1),
        ("midiCC", 128),
    ])
    func jsonRejectsInvalidExternalMIDIValues(key: String, value: Int) throws {
        let entry = MappingEntry(midiChannel: 1, midiCC: 7)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json[key] = value

        try expectDataCorrupted(json)
    }

    @Test func jsonRejectsAmbiguousNoteAndControlChange() throws {
        let entry = MappingEntry(midiChannel: 1, midiCC: 7)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json["midiNote"] = 60
        json["midiCC"] = 7

        try expectDataCorrupted(json)
    }

    private func expectDataCorrupted(_ json: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: json)
        do {
            _ = try JSONDecoder().decode(MappingEntry.self, from: data)
            Issue.record("Expected invalid MIDI JSON to throw DecodingError.dataCorrupted")
        } catch DecodingError.dataCorrupted {
            // Expected: MappingEntry revalidates legacy MIDI keys on decode.
        }
    }

    private func expectAssignment(
        _ assignment: MIDIAssignment,
        kind: MIDIAssignment.Kind,
        channel: Int,
        number: Int?
    ) {
        #expect(assignment.kind == kind)
        #expect(assignment.channel == channel)
        #expect(assignment.number == number)
    }

    // MARK: - Legacy Codable Compatibility Tests

    @Test func testExplicitCommandIDWinsOverStaleEncodedName() throws {
        let entry = MappingEntry(commandID: 201)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json["commandName"] = "Loop Out"
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(MappingEntry.self, from: data)
        #expect(decoded.commandID == 201)
        #expect(decoded.commandName == "Reverse Playback On")
    }

    @Test func testExplicitCommandIDDoesNotRequireRedundantName() throws {
        let entry = MappingEntry(commandID: 201)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json.removeValue(forKey: "commandName")
        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.commandID == 201)
    }

    @Test func testLegacyNameOnlyJSONDerivesCommandID() throws {
        let entry = MappingEntry(commandID: 100)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json.removeValue(forKey: "commandID")
        json["commandName"] = "Play/Pause (Deck Common)"
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(MappingEntry.self, from: data)
        #expect(decoded.commandID == 100)
    }

    @Test func testUnknownPositiveCommandIDSurvivesCodable() throws {
        let entry = MappingEntry(commandID: 4242, comment: "Legacy macro")
        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONEncoder().encode(entry)
        )
        #expect(decoded.commandID == 4242)
        #expect(decoded.commandName == "Unknown command #4242")
        #expect(decoded.comment == "Legacy macro")
    }

    @Test func testLegacySlotNameMigratesToCanonicalIDAndTarget() throws {
        let entry = MappingEntry(commandID: 251, assignment: .deckA)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json.removeValue(forKey: "commandID")
        json["commandName"] = "Slot 3 Volume"
        let data = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(MappingEntry.self, from: data)
        #expect(decoded.commandID == 251)
        #expect(decoded.assignment == .remixDeckASlot3)
    }

    @Test func testHistoricRenamedLabelPreservesItsOldRawID() throws {
        let entry = MappingEntry(commandID: 100)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json.removeValue(forKey: "commandID")
        json["commandName"] = "Loop Out"
        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.commandID == 201)
    }

    @Test func testUnknownNameOnlyJSONBecomesVisibleInvalidID() throws {
        let entry = MappingEntry(commandID: 100)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        json.removeValue(forKey: "commandID")
        json["commandName"] = "Not a Traktor command"
        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
        #expect(decoded.commandID == 0)
        #expect(decoded.commandName == "")
    }

    @Test func testDeviceDecodesLegacyJSONWithoutVersionKeys() throws {
        // Encode a current Device, strip the new DDIV keys to simulate
        // previously-persisted data, and confirm decode falls back to defaults.
        let device = Device(name: "Legacy", comment: "c", inPort: "in", outPort: "out")
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(device)) as? [String: Any]
        )
        json.removeValue(forKey: "tsiVersion")
        json.removeValue(forKey: "mappingFileRevision")
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(Device.self, from: legacyData)
        #expect(decoded.name == "Legacy")
        #expect(decoded.comment == "c")
        #expect(decoded.importedIdentity == nil)
        #expect(decoded.tsiVersion == "3.11.0")
        #expect(decoded.mappingFileRevision == 2)
    }

    @Test func testMappingEntryDecodesLegacyJSONWithoutCMADFields() throws {
        let entry = MappingEntry(commandName: "Play/Pause", midiChannel: 1, midiCC: 10)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        for key in ["autoRepeat", "ledMinRangeType", "ledMinRangeData", "ledMaxRangeType",
                    "ledMaxRangeData", "ledMinMidi", "ledMaxMidi", "ledInvert", "ledBlend",
                    "resolution"] {
            json.removeValue(forKey: key)
        }
        let legacyData = try JSONSerialization.data(withJSONObject: json)

        let decoded = try JSONDecoder().decode(MappingEntry.self, from: legacyData)
        #expect(decoded.commandName == "Play/Pause")
        #expect(decoded.autoRepeat == false)
        #expect(decoded.ledMinRangeType == 1)
        #expect(decoded.ledMinRangeData == 0)
        #expect(decoded.ledMaxRangeType == 1)
        #expect(decoded.ledMaxRangeData == 1)
        #expect(decoded.ledMinMidi == 0)
        #expect(decoded.ledMaxMidi == 127)
        #expect(decoded.ledInvert == false)
        #expect(decoded.ledBlend == false)
        #expect(decoded.resolution == 1)
        #expect(decoded.importedCMAD == nil)
    }

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
        #expect(TargetAssignment.remixDeckASlot1.displayName == "Deck A Slot 1")
        #expect(TargetAssignment.remixDeckDSlot4.displayName == "Deck D Slot 4")
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
        #expect(TargetAssignment.remixDeckASlot1.rawValue == 17)
        #expect(TargetAssignment.remixDeckDSlot4.rawValue == 32)
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

    @Test func mappingFileEnvelopeIsNotCodableAndDoesNotAffectSemanticEquality() throws {
        let semantic = MappingFile(devices: [Device(name: "Generic MIDI")], version: 4)
        let envelope = TSIRawEnvelope(
            originalXML: Data("private source".utf8),
            controllerValues: ["cHJpdmF0ZSBzb3VyY2U="],
            primaryFrames: [],
            baseline: TSISemanticBaseline(devices: semantic.devices, version: semantic.version),
            risks: []
        )
        var imported = semantic
        imported.sourceEnvelope = envelope

        #expect(imported == semantic)

        let encoded = try JSONEncoder().encode(imported)
        let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        #expect(Set(object.keys) == ["devices", "version"])

        let decoded = try JSONDecoder().decode(MappingFile.self, from: encoded)
        #expect(decoded == semantic)
        #expect(decoded.sourceEnvelope == nil)
    }

    // MARK: - MappingEntry Default Init Tests

    @Test func testMappingEntryDefaultInit() {
        let entry = MappingEntry()
        #expect(entry.commandName == "")
        #expect(entry.ioType == .input)
        #expect(entry.assignment == TargetAssignment.none)
        #expect(entry.interactionMode == InteractionMode.none)
        #expect(entry.midiChannel == 1)
        #expect(entry.midiNote == nil)
        #expect(entry.midiCC == nil)
        #expect(entry.modifier1Condition == nil)
        #expect(entry.modifier2Condition == nil)
        #expect(entry.comment == "")
        #expect(entry.controllerType == ControllerType.none)
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
