//
//  MappingBatchEditorTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

@MainActor
final class MappingBatchEditorTests: XCTestCase {

    func testCommentDraftPreservesUnsavedTextForSamePersistedSelection() {
        var state = CommentDraftState<Int>()
        state.reconcile(selectionID: 7, persistedComment: "stored comment")
        state.text = "unsaved local edit"

        state.reconcile(selectionID: 7, persistedComment: "stored comment")

        XCTAssertEqual(state.text, "unsaved local edit")
    }

    func testCommentDraftReloadsWhenPersistedCommentChangesForSameSelection() {
        var state = CommentDraftState<Int>()
        state.reconcile(selectionID: 7, persistedComment: "before save")
        state.text = "saved comment"
        state.reconcile(selectionID: 7, persistedComment: "saved comment")

        state.reconcile(selectionID: 7, persistedComment: "before save")

        XCTAssertEqual(state.text, "before save")
    }

    func testCommentDraftReloadsWhenSelectionIDChanges() {
        var state = CommentDraftState<Int>()
        state.reconcile(selectionID: 7, persistedComment: "shared persisted text")
        state.text = "unsaved local edit"

        state.reconcile(selectionID: 8, persistedComment: "shared persisted text")

        XCTAssertEqual(state.text, "shared persisted text")
    }

    func testStaleSettingsLeaseCannotStopOrClearReplacementListener() throws {
        var deliveries: [String] = []
        var ownership = MIDIInputManager.ListenerOwnership()
        let settingsLease = try XCTUnwrap(
            ownership.acquire { _ in deliveries.append("settings") }
        )
        XCTAssertTrue(ownership.startLeasedListening(using: settingsLease))

        ownership.replaceCallback { _ in deliveries.append("replacement") }
        ownership.startLegacyListening()

        XCTAssertFalse(ownership.release(settingsLease))
        ownership.deliver(MIDIMessage(channel: 1, note: 60, cc: nil, value: 100))
        XCTAssertTrue(ownership.isListening)
        XCTAssertNil(ownership.activeLease)
        XCTAssertEqual(deliveries, ["replacement"])
    }

    func testStaleLegacyCleanupCannotStopNewerLeasedListener() throws {
        var deliveries: [String] = []
        var ownership = MIDIInputManager.ListenerOwnership()

        ownership.replaceCallback { _ in deliveries.append("legacy") }
        ownership.startLegacyListening()
        ownership.stopLegacyListening()
        ownership.replaceCallback(nil)

        let settingsLease = try XCTUnwrap(
            ownership.acquire { _ in deliveries.append("settings") }
        )
        XCTAssertTrue(ownership.startLeasedListening(using: settingsLease))

        ownership.stopLegacyListening()
        ownership.replaceCallback(nil)
        ownership.deliver(MIDIMessage(channel: 1, note: nil, cc: 0, value: 0))

        XCTAssertTrue(ownership.owns(settingsLease))
        XCTAssertEqual(ownership.activeLease, settingsLease)
        XCTAssertTrue(ownership.isListening)
        XCTAssertEqual(deliveries, ["settings"])

        XCTAssertTrue(ownership.release(settingsLease))
        XCTAssertFalse(ownership.isListening)
        XCTAssertNil(ownership.activeLease)
        XCTAssertFalse(ownership.hasCallback)
    }

    func testSharedMIDIAssignmentChangesOnlySelectedRows() throws {
        let first = MappingEntry.fullFieldSentinel
        let second = MappingEntry(
            commandID: 201,
            assignment: .deckB,
            interactionMode: .relative,
            midiAssignment: try .note(channel: 2, number: 64),
            modifier1Condition: ModifierCondition(modifier: 2, value: 3),
            comment: "second",
            controllerType: .encoder,
            invert: true,
            rotarySensitivity: 1.75,
            rotaryAcceleration: 0.25
        )
        let untouched = MappingEntry(
            commandID: 202,
            assignment: .deckC,
            interactionMode: .direct,
            midiAssignment: try .unassigned(channel: 4),
            comment: "untouched",
            controllerType: .faderOrKnob,
            softTakeover: true
        )
        var file = MappingFile(devices: [
            Device(name: "First", mappings: [first]),
            Device(name: "Second", mappings: [second, untouched]),
        ])
        let assignment = try MIDIAssignment.controlChange(channel: 9, number: 22)

        MappingBatchEditor.apply(
            assignment,
            to: Set([first.id, second.id]),
            in: &file
        )

        var expectedFirst = first
        expectedFirst.midiAssignment = assignment
        var expectedSecond = second
        expectedSecond.midiAssignment = assignment
        XCTAssertEqual(file.devices[0].mappings[0], expectedFirst)
        XCTAssertEqual(file.devices[1].mappings[0], expectedSecond)
        XCTAssertEqual(file.devices[1].mappings[1], untouched)
    }

    func testBatchLearnIgnoresNoteOffAndAcceptsFirstNoteOn() throws {
        let noteOff = MIDIMessage(channel: 2, note: 64, cc: nil, value: 0)
        let noteOn = MIDIMessage(channel: 2, note: 64, cc: nil, value: 100)

        XCTAssertNil(MIDIAssignment(learnMessage: noteOff))
        XCTAssertEqual(
            MIDIAssignment(learnMessage: noteOn),
            try MIDIAssignment.note(channel: 2, number: 64)
        )
    }

    func testBatchLearnAcceptsControlChangeNumberZero() throws {
        let message = MIDIMessage(channel: 16, note: nil, cc: 0, value: 0)

        XCTAssertEqual(
            MIDIAssignment(learnMessage: message),
            try MIDIAssignment.controlChange(channel: 16, number: 0)
        )
    }

    func testChannelOnlyEditPreservesEachRowsAssignmentKindAndNumber() throws {
        let note = MappingEntry(
            commandID: 100,
            midiAssignment: try .note(channel: 1, number: 64)
        )
        let cc = MappingEntry(
            commandID: 201,
            midiAssignment: try .controlChange(channel: 2, number: 22)
        )
        let none = MappingEntry(
            commandID: 202,
            midiAssignment: try .unassigned(channel: 3)
        )
        var file = MappingFile(devices: [Device(mappings: [note, cc, none])])

        try MappingBatchEditor.applyChannel(
            12,
            to: Set([note.id, cc.id, none.id]),
            in: &file
        )

        XCTAssertEqual(
            file.devices[0].mappings[0].midiAssignment,
            try .note(channel: 12, number: 64)
        )
        XCTAssertEqual(
            file.devices[0].mappings[1].midiAssignment,
            try .controlChange(channel: 12, number: 22)
        )
        XCTAssertEqual(
            file.devices[0].mappings[2].midiAssignment,
            try .unassigned(channel: 12)
        )
    }

    func testInvalidChannelEditThrowsWithoutPartialChanges() throws {
        let first = MappingEntry(
            commandID: 100,
            midiAssignment: try .note(channel: 1, number: 64)
        )
        let second = MappingEntry(
            commandID: 201,
            midiAssignment: try .controlChange(channel: 2, number: 22)
        )
        var file = MappingFile(devices: [Device(mappings: [first, second])])
        let before = file

        XCTAssertThrowsError(
            try MappingBatchEditor.applyChannel(
                17,
                to: Set([first.id, second.id]),
                in: &file
            )
        ) { error in
            XCTAssertEqual(
                error as? MIDIAssignment.ValidationError,
                .channelOutOfRange(17)
            )
        }
        XCTAssertEqual(file, before)
    }

    func testEmptySelectionIsANoOp() throws {
        var file = MappingFile(devices: [
            Device(mappings: [MappingEntry.fullFieldSentinel]),
        ])
        let before = file

        MappingBatchEditor.apply(
            try .controlChange(channel: 5, number: 0),
            to: [],
            in: &file
        )
        try MappingBatchEditor.applyChannel(6, to: [], in: &file)
        MappingBatchEditor.applyComment("replacement", to: [], in: &file)

        XCTAssertEqual(file, before)
    }

    func testCommentEditChangesOnlySelectedMappingComments() {
        let selected = MappingEntry.fullFieldSentinel
        let untouched = MappingEntry(commandID: 201, comment: "keep")
        let alsoSelected = MappingEntry(commandID: 202, comment: "second")
        var file = MappingFile(devices: [
            Device(name: "First", mappings: [selected, untouched]),
            Device(name: "Second", mappings: [alsoSelected]),
        ])

        MappingBatchEditor.applyComment(
            "shared macro comment",
            to: [selected.id, alsoSelected.id],
            in: &file
        )

        var expectedSelected = selected
        expectedSelected.comment = "shared macro comment"
        var expectedAlsoSelected = alsoSelected
        expectedAlsoSelected.comment = "shared macro comment"
        XCTAssertEqual(file.devices[0].mappings[0], expectedSelected)
        XCTAssertEqual(file.devices[0].mappings[1], untouched)
        XCTAssertEqual(file.devices[1].mappings[0], expectedAlsoSelected)
    }

    func testDeviceCommentEditUsesStableIDAndChangesOnlyChosenComment() {
        let firstID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let secondID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let first = Device(
            id: firstID,
            name: "Duplicate",
            comment: "first comment",
            inPort: "First In",
            outPort: "First Out",
            tsiVersion: "4.4.1",
            mappingFileRevision: 7,
            mappings: [MappingEntry(commandID: 100, comment: "first mapping")]
        )
        let second = Device(
            id: secondID,
            name: "Duplicate",
            comment: "second comment",
            inPort: "Second In",
            outPort: "Second Out",
            tsiVersion: "3.11.0",
            mappingFileRevision: 2,
            mappings: [MappingEntry(commandID: 201, comment: "second mapping")]
        )
        var file = MappingFile(devices: [first, second], version: 42)

        MappingBatchEditor.applyDeviceComment(
            "updated device comment",
            to: secondID,
            in: &file
        )

        var expectedSecond = second
        expectedSecond.comment = "updated device comment"
        XCTAssertEqual(file.devices[0], first)
        XCTAssertEqual(file.devices[1], expectedSecond)
        XCTAssertEqual(file.version, 42)
    }

    func testSharedAssignmentIsOneUndoableDocumentMutation() throws {
        let first = MappingEntry(commandID: 100, midiChannel: 1, midiNote: 60)
        let second = MappingEntry(commandID: 201, midiChannel: 2, midiCC: 7)
        let original = MappingFile(devices: [Device(mappings: [first, second])])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()
        let assignment = try MIDIAssignment.controlChange(channel: 16, number: 0)

        document.performUndoableMutation(
            actionName: "Assign MIDI",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.apply(
                assignment,
                to: Set([first.id, second.id]),
                in: &file
            )
        }

        XCTAssertEqual(
            document.mappingFile.allMappings.map(\.midiAssignment),
            [assignment, assignment]
        )
        undoManager.undo()
        XCTAssertEqual(document.mappingFile, original)
    }
}
