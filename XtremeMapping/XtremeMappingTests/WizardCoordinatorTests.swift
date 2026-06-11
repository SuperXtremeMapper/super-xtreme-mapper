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
