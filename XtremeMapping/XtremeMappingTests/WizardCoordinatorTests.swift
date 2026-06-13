//
//  WizardCoordinatorTests.swift
//  XtremeMappingTests
//
//  State-machine tests for the mapping wizard coordinator: note-off
//  discard, shift-button assignment and hold tracking, modifier dedup,
//  and shift state reset across sessions and MIDI setup changes.
//

import XCTest
@testable import XtremeMapping

@MainActor
final class WizardCoordinatorTests: XCTestCase {

    private var coordinator: WizardCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        coordinator = WizardCoordinator()
        coordinator.setupConfig.controllerName = "Test Controller"
        coordinator.setupConfig.inputPort = "Test In"
        coordinator.autoAdvanceEnabled = false
        coordinator.beginLearning()
    }

    override func tearDown() async throws {
        // Stops MIDI listening and clears the shared manager's callbacks so
        // stray hardware input can't reach a dead coordinator mid-suite.
        coordinator.cancel()
        coordinator = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func noteOn(_ note: Int, channel: Int = 1, velocity: Int = 127) -> MIDIMessage {
        MIDIMessage(channel: channel, note: note, cc: nil, value: velocity)
    }

    private func noteOff(_ note: Int, channel: Int = 1) -> MIDIMessage {
        MIDIMessage(channel: channel, note: note, cc: nil, value: 0)
    }

    private func cc(_ controller: Int, channel: Int = 1, value: Int) -> MIDIMessage {
        MIDIMessage(channel: channel, note: nil, cc: controller, value: value)
    }

    /// Assigns the given note as the shift button via the Setup tab,
    /// then moves to the Mixer tab.
    private func assignShift(note: Int) {
        coordinator.switchToTab(.setup)
        coordinator.handleMIDIReceived(noteOn(note))
        XCTAssertNotNil(coordinator.shiftMIDI, "Shift button should be assigned")
        coordinator.switchToTab(.mixer)
    }

    private func captures(for commandName: String) -> [WizardCapturedMapping] {
        coordinator.capturedMappings.filter { $0.function.commandName == commandName }
    }

    /// Attaches a document and restarts learning so save paths have a target.
    @discardableResult
    private func attachDocument(_ document: TraktorMappingDocument = TraktorMappingDocument()) -> TraktorMappingDocument {
        coordinator.start(document: document)
        coordinator.beginLearning()
        return document
    }

    /// Records the wizard's position, waits past the auto-advance window,
    /// and asserts no stray advance mutated it.
    private func assertPositionStable(file: StaticString = #filePath, line: UInt = #line) async throws {
        let tab = coordinator.currentTab
        let functionIndex = coordinator.currentFunctionIndex
        let assignmentIndex = coordinator.currentAssignmentIndex
        let phase = coordinator.phase
        let message = coordinator.statusMessage
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertEqual(coordinator.currentTab, tab, "Stray auto-advance changed the tab", file: file, line: line)
        XCTAssertEqual(coordinator.currentFunctionIndex, functionIndex, "Stray auto-advance changed the function index", file: file, line: line)
        XCTAssertEqual(coordinator.currentAssignmentIndex, assignmentIndex, "Stray auto-advance changed the assignment index", file: file, line: line)
        XCTAssertEqual(coordinator.phase, phase, "Stray auto-advance changed the phase", file: file, line: line)
        XCTAssertEqual(coordinator.statusMessage, message, "Stray auto-advance changed the status message", file: file, line: line)
    }

    // MARK: - Task 3.2: note-off never creates a capture

    func testNoteOffDoesNotAddOrReplaceCapture() {
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(captures(for: function.commandName).count, 1)
        XCTAssertEqual(captures(for: function.commandName).first?.midiMessage.value, 127)

        coordinator.handleMIDIReceived(noteOff(60))
        let after = captures(for: function.commandName)
        XCTAssertEqual(after.count, 1, "Note-off must not add a capture")
        XCTAssertEqual(after.first?.midiMessage.value, 127, "Note-off must not replace the note-on capture")
    }

    func testNoteOffDoesNotRestartAutoAdvance() {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)

        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)
        coordinator.cancelAutoAdvance()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001)

        coordinator.handleMIDIReceived(noteOff(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "Note-off must not restart auto-advance")
    }

    func testNoteOffOnSetupTabDoesNotBecomeShiftAssignment() {
        coordinator.switchToTab(.setup)

        coordinator.handleMIDIReceived(noteOff(42))
        XCTAssertNil(coordinator.shiftMIDI, "A note-off must not be assigned as the shift button")
        XCTAssertTrue(coordinator.capturedMappings.isEmpty)
    }

    func testCCValueZeroStillCaptures() {
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        coordinator.handleMIDIReceived(cc(7, value: 0))
        let result = captures(for: function.commandName)
        XCTAssertEqual(result.count, 1, "CC with value 0 is a valid position and must capture")
        XCTAssertEqual(result.first?.midiMessage.cc, 7)
        XCTAssertEqual(result.first?.midiMessage.value, 0)
    }

    // MARK: - Task 3.3: nil/M1=0 dedup equivalence

    func testNilModifierAndM1ZeroDeduplicate() {
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        // Capture with no shift assigned → modifierCondition == nil
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(captures(for: function.commandName).count, 1)
        XCTAssertNil(captures(for: function.commandName).first?.modifierCondition)

        // Assign shift, then recapture the same function unshifted → M1 = 0
        assignShift(note: 99)
        coordinator.handleMIDIReceived(noteOn(61))

        let result = captures(for: function.commandName)
        XCTAssertEqual(result.count, 1,
                       "nil modifier and M1=0 are equivalent — recapture must replace, not duplicate")
        XCTAssertEqual(result.first?.midiMessage.note, 61)
    }

    // MARK: - Shift hold tracking

    func testShiftPressAndReleaseTrackHeldState() {
        assignShift(note: 99)

        coordinator.handleMIDIReceived(noteOn(99))
        XCTAssertTrue(coordinator.isShiftHeld)
        XCTAssertTrue(coordinator.capturedMappings.allSatisfy { $0.midiMessage.note != 99 || $0.function.commandName == "Modifier #1" },
                      "Shift presses must not create captures on non-setup tabs")

        coordinator.handleMIDIReceived(noteOff(99))
        XCTAssertFalse(coordinator.isShiftHeld, "Shift note-off must release the held state")
    }

    func testShiftReleaseOnSetupTabClearsHeldState() {
        // Hold shift on a learning tab, navigate back to Setup, release there.
        // The release must still clear isShiftHeld or every later capture
        // would wrongly get M1=1.
        assignShift(note: 99)
        coordinator.handleMIDIReceived(noteOn(99))
        XCTAssertTrue(coordinator.isShiftHeld)

        coordinator.switchToTab(.setup)
        coordinator.handleMIDIReceived(noteOff(99))
        XCTAssertFalse(coordinator.isShiftHeld,
                       "Shift release on the Setup tab must clear the held state")
    }

    // MARK: - Task 3.4: shift state reset

    func testBeginLearningResetsShiftState() {
        assignShift(note: 99)
        coordinator.handleMIDIReceived(noteOn(99))
        XCTAssertNotNil(coordinator.shiftMIDI)
        XCTAssertTrue(coordinator.isShiftHeld)

        coordinator.beginLearning()
        XCTAssertNil(coordinator.shiftMIDI, "beginLearning must clear a stale shift assignment")
        XCTAssertFalse(coordinator.isShiftHeld, "beginLearning must clear a stale held state")
    }

    func testSetupChangeForcesShiftReleased() {
        assignShift(note: 99)
        coordinator.handleMIDIReceived(noteOn(99))
        XCTAssertTrue(coordinator.isShiftHeld)

        coordinator.handleMIDISetupChanged()
        XCTAssertFalse(coordinator.isShiftHeld,
                       "A MIDI setup change must force-release the shift state")
    }

    // MARK: - Task 3.1: auto-advance cancellation on navigation (M6)

    func testSkipCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.skip()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "skip() must cancel the pending auto-advance — it already advanced once itself")
        // skip() advanced exactly once; the stale task must not advance again.
        try await assertPositionStable()
    }

    func testPreviousCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.previous()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "previous() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testClearCurrentMappingCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.clearCurrentMapping()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "clearCurrentMapping() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testSwitchToTabCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.switchToTab(.decks)
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "switchToTab() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testCancelCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.cancel()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "cancel() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testPerformSaveCancelsPendingAutoAdvance() async throws {
        attachDocument()
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.performSave(overwrite: false)
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "performSave() must cancel a pending auto-advance")
        XCTAssertEqual(coordinator.phase, .complete)
        try await assertPositionStable()
    }

    func testSaveToDocumentWithConflictCancelsPendingAutoAdvance() async throws {
        let document = attachDocument()
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }
        document.mappingFile.devices = [
            Device(mappings: [MappingEntry(commandName: function.commandName)])
        ]

        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.saveToDocument()
        XCTAssertTrue(coordinator.showOverwriteAlert, "Conflict in devices[0] must raise the overwrite alert")
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "saveToDocument() must cancel a pending auto-advance before showing the alert")
        try await assertPositionStable()
        XCTAssertTrue(coordinator.showOverwriteAlert)
    }

    func testStrayAutoAdvanceFireIsNoOpOutsideLearning() {
        attachDocument()
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        coordinator.performSave(overwrite: false)
        XCTAssertEqual(coordinator.phase, .complete)

        let message = coordinator.statusMessage
        let tab = coordinator.currentTab
        let functionIndex = coordinator.currentFunctionIndex
        let assignmentIndex = coordinator.currentAssignmentIndex

        coordinator.fireAutoAdvance()

        XCTAssertEqual(coordinator.phase, .complete, "A stray fire must not mutate a completed wizard")
        XCTAssertEqual(coordinator.statusMessage, message)
        XCTAssertEqual(coordinator.currentTab, tab)
        XCTAssertEqual(coordinator.currentFunctionIndex, functionIndex)
        XCTAssertEqual(coordinator.currentAssignmentIndex, assignmentIndex)
    }

    // MARK: - Task 3.2: stop MIDI listening on save/close (M7)

    func testPerformSaveStopsMIDIListening() {
        attachDocument()
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertTrue(coordinator.isListening)

        coordinator.performSave(overwrite: false)

        XCTAssertEqual(coordinator.phase, .complete)
        XCTAssertFalse(coordinator.isListening, "performSave must stop MIDI listening")
        XCTAssertNil(MIDIInputManager.shared.onMIDIReceived,
                     "performSave must clear the manager's MIDI callback")
    }

    func testCancelAfterCompletedSavePreservesSavedState() {
        attachDocument()
        coordinator.switchToTab(.mixer)
        coordinator.handleMIDIReceived(noteOn(60))
        coordinator.performSave(overwrite: false)
        XCTAssertEqual(coordinator.phase, .complete)
        let savedCount = coordinator.capturedMappings.count
        XCTAssertGreaterThan(savedCount, 0)

        // Window-close fires cancel() via onDisappear; it must not clobber
        // the completed save's state.
        coordinator.cancel()
        XCTAssertEqual(coordinator.phase, .complete,
                       "cancel() after a completed save must not reset the phase")
        XCTAssertEqual(coordinator.capturedMappings.count, savedCount,
                       "cancel() after a completed save must keep the captured mappings")
        XCTAssertFalse(coordinator.isListening)

        // Idempotent: a second cancel changes nothing.
        coordinator.cancel()
        XCTAssertEqual(coordinator.phase, .complete)
        XCTAssertEqual(coordinator.capturedMappings.count, savedCount)
    }

    // MARK: - Task 3.3: conflict scope alignment (L10) + entry channel (L9)

    func testConflictInOtherDeviceDoesNotTriggerOverwriteAlert() {
        let document = attachDocument()
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }
        // Conflict lives in devices[1]; the wizard only writes to devices[0],
        // so it must not count.
        document.mappingFile.devices = [
            Device(),
            Device(mappings: [MappingEntry(commandName: function.commandName)])
        ]

        coordinator.handleMIDIReceived(noteOn(60))
        coordinator.saveToDocument()

        XCTAssertFalse(coordinator.showOverwriteAlert,
                       "A mapping in devices[1] must not count as a conflict for devices[0]")
        XCTAssertEqual(coordinator.phase, .complete, "Save must proceed directly")
        XCTAssertTrue(document.mappingFile.devices[0].mappings.contains { $0.commandName == function.commandName },
                      "The new mapping lands in devices[0]")
        XCTAssertEqual(document.mappingFile.devices[1].mappings.count, 1,
                       "devices[1] is untouched")
    }

    func testConflictInFirstDeviceStillTriggersOverwriteAlert() {
        let document = attachDocument()
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }
        document.mappingFile.devices = [
            Device(mappings: [MappingEntry(commandName: function.commandName)])
        ]

        coordinator.handleMIDIReceived(noteOn(60))
        coordinator.saveToDocument()

        XCTAssertTrue(coordinator.showOverwriteAlert)
        XCTAssertEqual(coordinator.conflictingCommands, [function.commandName])
    }

    func testSavedMappingEntryUsesCapturedMIDIChannel() {
        let document = attachDocument()
        coordinator.switchToTab(.mixer)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        coordinator.handleMIDIReceived(noteOn(60, channel: 5))
        coordinator.performSave(overwrite: false)

        let saved = document.mappingFile.devices[0].mappings.first { $0.commandName == function.commandName }
        XCTAssertEqual(saved?.midiChannel, 5,
                       "The entry's channel comes from the captured MIDI message")
        XCTAssertEqual(saved?.midiNote, 60)
    }

    func testSampleDeckAssignmentsExpandBySelectedChannelCount() {
        coordinator.switchToTab(.sampleDecks)

        coordinator.setupConfig.numberOfChannels = 1
        XCTAssertEqual(coordinator.currentAssignments,
                       [.remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4])

        coordinator.setupConfig.numberOfChannels = 2
        XCTAssertEqual(coordinator.currentAssignments,
                       [.remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4,
                        .remixDeckBSlot1, .remixDeckBSlot2, .remixDeckBSlot3, .remixDeckBSlot4])

        coordinator.setupConfig.numberOfChannels = 4
        XCTAssertEqual(coordinator.currentAssignments,
                       [.remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4,
                        .remixDeckBSlot1, .remixDeckBSlot2, .remixDeckBSlot3, .remixDeckBSlot4,
                        .remixDeckCSlot1, .remixDeckCSlot2, .remixDeckCSlot3, .remixDeckCSlot4,
                        .remixDeckDSlot1, .remixDeckDSlot2, .remixDeckDSlot3, .remixDeckDSlot4])
    }

    func testSetupChangeCallbackIsWiredToManager() {
        // beginLearning (in setUp) wires onSetupChanged on the shared manager.
        assignShift(note: 99)
        coordinator.handleMIDIReceived(noteOn(99))
        XCTAssertTrue(coordinator.isShiftHeld)

        XCTAssertNotNil(MIDIInputManager.shared.onSetupChanged,
                        "startMIDIListening must subscribe to setup changes")
        MIDIInputManager.shared.onSetupChanged?()
        XCTAssertFalse(coordinator.isShiftHeld,
                       "The manager's setup-change callback must reach the coordinator")
    }
}
