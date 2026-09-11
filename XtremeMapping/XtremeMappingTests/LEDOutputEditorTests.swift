import XCTest
@testable import XtremeMapping

@MainActor
final class LEDOutputEditorTests: XCTestCase {
    func testMIDILearnKeepsOutputTypeAndInputInference() {
        var output = MappingEntry.output(commandID: 1)
        var input = MappingEntry(commandID: 1, ioType: .input)
        SettingsPanelV2.applyLearnedControllerType(.encoder, to: &output)
        SettingsPanelV2.applyLearnedControllerType(.encoder, to: &input)
        XCTAssertEqual(output.controllerType, .led)
        XCTAssertEqual(output.interactionMode, .output)
        XCTAssertEqual(input.controllerType, .encoder)
        XCTAssertEqual(input.interactionMode, ControllerType.encoder.defaultInteractionMode)
    }

    func testLearnPreservesEveryValidInputInteraction() {
        for type in [ControllerType.button, .faderOrKnob, .encoder] {
            for mode in type.validInteractionModes {
                var entry = MappingEntry(commandID: 2196, ioType: .input)
                entry.controllerType = .button
                entry.interactionMode = mode
                SettingsPanelV2.applyLearnedControllerType(type, to: &entry)
                XCTAssertEqual(entry.controllerType, type)
                XCTAssertEqual(entry.interactionMode, mode)
            }
        }
    }

    func testLearnResetsIncompatibleInputInteraction() {
        var entry = MappingEntry(commandID: 2196, ioType: .input)
        entry.interactionMode = .relative
        SettingsPanelV2.applyLearnedControllerType(.button, to: &entry)
        XCTAssertEqual(entry.interactionMode, .hold)
    }

    func testMixedDraftOnlyAppliesExplicitFields() throws {
        var first = MappingEntry.output(commandID: 1)
        var second = MappingEntry.output(commandID: 1)
        first.ledMinMidi = 3
        second.ledMinMidi = 9
        second.ledBlend = !first.ledBlend
        var draft = LEDOutputDraft(entries: [first, second])
        XCTAssertNil(draft.commonText(.midiMinimum))
        XCTAssertNil(draft.commonFlag(blend: true))
        XCTAssertTrue(draft.patch.isEmpty)
        draft.setText("70", for: .midiMaximum)
        let changed = try draft.patch.applying(to: second)
        XCTAssertEqual(changed.ledMinMidi, 9)
        XCTAssertEqual(changed.ledMaxMidi, 70)
        XCTAssertEqual(changed.ledBlend, second.ledBlend)
        XCTAssertNil(draft.patch.controllerMinimum)
    }

    func testUnknownControllerRangeStillAllowsIndependentOutputFlagEdits() throws {
        var output = MappingEntry.output(commandID: 1)
        output.ledMinRangeType = 99
        output.ledMinRangeData = 123456
        output.invert = true
        var draft = LEDOutputDraft(entries: [output])
        XCTAssertFalse(LEDOutputSettings.canEditControllerRange(in: [output]))
        draft.setFlag(true, blend: false)
        draft.setFlag(true, blend: true)
        let result = try draft.patch.applying(to: output)
        XCTAssertTrue(result.ledInvert)
        XCTAssertTrue(result.ledBlend)
        XCTAssertEqual(result.invert, output.invert)
        XCTAssertEqual(result.ledMinRangeType, 99)
        XCTAssertEqual(result.ledMinRangeData, 123456)
    }

    func testApplyIsLockedScopedUndoableAndInvalidDraftIsAtomic() throws {
        let output = MappingEntry.output(commandID: 1)
        let input = MappingEntry(commandID: 1, ioType: .input)
        let document = TraktorMappingDocument()
        document.mappingFile = MappingFile(devices: [Device(mappings: [output, input])])
        let original = document.mappingFile
        let undo = UndoManager()
        undo.groupsByEvent = false
        var draft = LEDOutputDraft(entries: [output])
        draft.setText("42", for: .midiMaximum)
        XCTAssertFalse(try LEDOutputDraft.apply(draft.patch, selectedIDs: [output.id], document: document, isLocked: true, undoManager: undo))
        XCTAssertEqual(document.mappingFile, original)
        undo.beginUndoGrouping()
        XCTAssertTrue(try LEDOutputDraft.apply(draft.patch, selectedIDs: [output.id], document: document, isLocked: false, undoManager: undo))
        undo.endUndoGrouping()
        XCTAssertEqual(document.mappingFile.allMappings[0].ledMaxMidi, 42)
        XCTAssertEqual(document.mappingFile.allMappings[1], input)
        undo.undo()
        XCTAssertEqual(document.mappingFile, original)
        undo.redo()
        let applied = document.mappingFile
        draft.setText("128", for: .midiMinimum)
        XCTAssertThrowsError(try LEDOutputDraft.apply(draft.patch, selectedIDs: [output.id], document: document, isLocked: false, undoManager: undo))
        XCTAssertEqual(document.mappingFile, applied)
        XCTAssertThrowsError(try LEDOutputDraft.apply(draft.patch, selectedIDs: [output.id, input.id], document: document, isLocked: false, undoManager: undo))
        XCTAssertEqual(document.mappingFile, applied)
    }
}
