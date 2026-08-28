//
//  WizardCoordinatorTests.swift
//  XtremeMappingTests
//
//  State-machine tests for the mapping wizard coordinator: note-off
//  discard, shift-button assignment and hold tracking, modifier dedup,
//  and shift state reset across sessions and MIDI setup changes.
//

import XCTest
import AppKit
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
    /// then moves to a tab with verified deck commands.
    private func assignShift(note: Int) {
        coordinator.switchToTab(.setup)
        coordinator.handleMIDIReceived(noteOn(note))
        XCTAssertNotNil(coordinator.shiftMIDI, "Shift button should be assigned")
        coordinator.switchToTab(.decks)
    }

    private func captures(for commandID: Int) -> [WizardCapturedMapping] {
        coordinator.capturedMappings.filter { $0.function.commandID == commandID }
    }

    /// Attaches a document and restarts learning so save paths have a target.
    @discardableResult
    private func attachDocument(
        _ document: TraktorMappingDocument = TraktorMappingDocument(),
        destinationDeviceID: Device.ID? = nil
    ) -> TraktorMappingDocument {
        coordinator.start(document: document, destinationDeviceID: destinationDeviceID)
        coordinator.setupConfig.controllerName = "Test Controller"
        coordinator.setupConfig.inputPort = "Test In"
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

    // MARK: - Reliable command and MIDI propagation

    func testWizardCapturedMappingUsesVerifiedCommandAndMIDIIDs() throws {
        let function = WizardFunction(
            displayName: "Play/Pause",
            commandID: 100,
            controllerType: .button,
            interactionMode: .toggle
        )
        let captured = WizardCapturedMapping(
            function: function,
            assignment: .deckC,
            midiMessage: MIDIMessage(channel: 9, note: 64, cc: nil, value: 127),
            modifierCondition: ModifierCondition(modifier: 1, value: 1)
        )

        let entry = captured.toMappingEntry()

        XCTAssertEqual(entry.commandID, 100)
        XCTAssertEqual(entry.midiAssignment, try .note(channel: 9, number: 64))
        XCTAssertEqual(entry.assignment, .deckC)
        XCTAssertEqual(entry.modifier1Condition, ModifierCondition(modifier: 1, value: 1))
    }

    func testEveryWizardFunctionUsesVerifiedInputCommand() {
        for tab in WizardTab.allCases {
            for function in tab.functions {
                let descriptor = TraktorCommands.descriptor(for: function.commandID)
                XCTAssertEqual(
                    descriptor.verification,
                    .verifiedTraktor441,
                    "\(tab): \(function.displayName)"
                )
                XCTAssertTrue(
                    descriptor.supportedDirections.contains(.input),
                    "\(tab): \(function.displayName)"
                )
            }
        }
    }

    func testHotcueEightUsesCanonicalCommandAndZeroBasedSetValue() throws {
        let function = try XCTUnwrap(
            WizardTab.cueLoop.functions.first { $0.displayName == "Hotcue 8" }
        )

        XCTAssertEqual(function.commandID, 2328)
        XCTAssertEqual(function.setToValue, 7)
    }

    func testCapturedRemixSlotRetainsExactTarget() throws {
        let function = WizardFunction(
            displayName: "Slot Trigger",
            commandID: 601,
            controllerType: .button,
            interactionMode: .trigger,
            perDeck: false
        )
        let captured = WizardCapturedMapping(
            function: function,
            assignment: .remixDeckDSlot4,
            midiMessage: noteOn(72, channel: 16),
            modifierCondition: nil
        )

        let entry = captured.toMappingEntry()

        XCTAssertEqual(entry.commandID, 601)
        XCTAssertEqual(entry.assignment, .remixDeckDSlot4)
        XCTAssertEqual(entry.midiAssignment, try .note(channel: 16, number: 72))
    }

    func testConflictIdentityUsesRawCommandIDWhenNamesMatch() throws {
        let observedBeatPhase = MappingEntry(
            commandID: 513,
            assignment: .deckB,
            setToValue: 3
        )
        let historicBeatPhase = MappingEntry(
            commandID: 2251,
            assignment: .deckB,
            setToValue: 3
        )
        XCTAssertEqual(observedBeatPhase.commandName, historicBeatPhase.commandName)

        XCTAssertNotEqual(
            try XCTUnwrap(SemanticBindingKey(entry: observedBeatPhase)),
            try XCTUnwrap(SemanticBindingKey(entry: historicBeatPhase))
        )
    }

    func testConflictIdentityUsesCanonicalTargetAndCommandAwareSetToWireValue() throws {
        let source = MappingEntry(commandID: 2328, assignment: .deckA, setToValue: 2.49)
        let sameQuantizedValue = MappingEntry(commandID: 2328, assignment: .deckA, setToValue: 2.40)
        let differentTarget = MappingEntry(commandID: 2328, assignment: .deckB, setToValue: 2.49)
        let differentValue = MappingEntry(commandID: 2328, assignment: .deckA, setToValue: 2.51)
        let positiveZero = MappingEntry(commandID: 100, assignment: .deckA, setToValue: 0.0)
        let negativeZero = MappingEntry(commandID: 100, assignment: .global, setToValue: -0.0)

        XCTAssertEqual(
            try XCTUnwrap(SemanticBindingKey(entry: source)),
            try XCTUnwrap(SemanticBindingKey(entry: sameQuantizedValue)),
            "Hotcue set-to is an integer selector on the wire"
        )
        XCTAssertNotEqual(
            try XCTUnwrap(SemanticBindingKey(entry: source)),
            try XCTUnwrap(SemanticBindingKey(entry: differentTarget))
        )
        XCTAssertNotEqual(
            try XCTUnwrap(SemanticBindingKey(entry: source)),
            try XCTUnwrap(SemanticBindingKey(entry: differentValue))
        )
        XCTAssertNotEqual(
            try XCTUnwrap(SemanticBindingKey(entry: positiveZero)),
            try XCTUnwrap(SemanticBindingKey(entry: negativeZero)),
            "Non-indexed commands retain exact Float32 wire bits even when their canonical targets match"
        )
    }

    func testConflictIdentityIncludesDirectionAndBothCompleteModifierTuples() throws {
        let base = MappingEntry(
            commandID: 100,
            ioType: .input,
            assignment: .deckA,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3),
            modifier2Condition: ModifierCondition(modifier: 4, value: 5)
        )
        var direction = base
        direction.ioType = .output
        var modifierNumber = base
        modifierNumber.modifier1Condition = ModifierCondition(modifier: 3, value: 3)
        var modifierValue = base
        modifierValue.modifier2Condition = ModifierCondition(modifier: 4, value: 6)
        var canonicalInactive = base
        canonicalInactive.modifier1Condition = nil
        var explicitInactive = canonicalInactive
        explicitInactive.modifier1Condition = ModifierCondition(modifier: 0, value: 0)

        let baseKey = try XCTUnwrap(SemanticBindingKey(entry: base))
        XCTAssertNotEqual(baseKey, try XCTUnwrap(SemanticBindingKey(entry: direction)))
        XCTAssertNotEqual(baseKey, try XCTUnwrap(SemanticBindingKey(entry: modifierNumber)))
        XCTAssertNotEqual(baseKey, try XCTUnwrap(SemanticBindingKey(entry: modifierValue)))
        XCTAssertEqual(
            try XCTUnwrap(SemanticBindingKey(entry: canonicalInactive)),
            try XCTUnwrap(SemanticBindingKey(entry: explicitInactive)),
            "Only the fully canonical inactive condition normalizes to nil"
        )
    }

    func testConflictIdentityRejectsUnsupportedImportedConditionTarget() throws {
        var entry = MappingEntry(
            commandID: 100,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3)
        )
        var payload = Data(repeating: 0, count: 120)
        func store(_ value: UInt32, at offset: Int) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { bytes in
                payload.replaceSubrange(offset..<(offset + 4), with: bytes)
            }
        }
        store(2, at: 52)
        store(99, at: 56)
        store(3, at: 60)
        entry.importedCMAD = try XCTUnwrap(ImportedCMAD(payload: payload, semanticAtImport: entry))

        XCTAssertNil(
            SemanticBindingKey(entry: entry),
            "A condition target the semantic model cannot represent must never be replaceable"
        )
    }

    func testConditionOneNativeTargetRemainsNonreplaceableWhenConditionTwoChanges() throws {
        var entry = MappingEntry(
            commandID: 100,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3),
            modifier2Condition: ModifierCondition(modifier: 4, value: 5)
        )
        var payload = Data(repeating: 0, count: 120)
        func store(_ value: UInt32, at offset: Int) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { bytes in
                payload.replaceSubrange(offset..<(offset + 4), with: bytes)
            }
        }
        store(2, at: 52)
        store(99, at: 56)
        store(3, at: 60)
        entry.importedCMAD = try XCTUnwrap(ImportedCMAD(payload: payload, semanticAtImport: entry))
        entry.modifier2Condition = ModifierCondition(modifier: 4, value: 6)

        XCTAssertNil(SemanticBindingKey(entry: entry))
    }

    func testConditionTwoNativeTargetRemainsNonreplaceableWhenConditionOneChanges() throws {
        var entry = MappingEntry(
            commandID: 100,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3),
            modifier2Condition: ModifierCondition(modifier: 4, value: 5)
        )
        var payload = Data(repeating: 0, count: 120)
        func store(_ value: UInt32, at offset: Int) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { bytes in
                payload.replaceSubrange(offset..<(offset + 4), with: bytes)
            }
        }
        store(4, at: 64)
        store(88, at: 68)
        store(5, at: 72)
        entry.importedCMAD = try XCTUnwrap(ImportedCMAD(payload: payload, semanticAtImport: entry))
        entry.modifier1Condition = ModifierCondition(modifier: 2, value: 4)

        XCTAssertNil(SemanticBindingKey(entry: entry))
    }

    func testStartRejectsInvalidMultiDeviceDestination() {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [
            Device(name: "First"),
            Device(name: "Second"),
        ]))

        XCTAssertFalse(coordinator.start(document: document, destinationDeviceID: nil))
        XCTAssertFalse(coordinator.isListening)
        XCTAssertTrue(coordinator.capturedMappings.isEmpty)
        XCTAssertTrue(coordinator.statusMessage.localizedCaseInsensitiveContains("destination"))
    }

    func testStartRebindsCleanSessionAndOldCapturesCannotReachNewDocument() throws {
        let firstDevice = Device(name: "First")
        let firstDocument = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [firstDevice])
        )
        XCTAssertTrue(coordinator.start(document: firstDocument, destinationDeviceID: firstDevice.id))
        coordinator.setupConfig.controllerName = "First Controller"
        coordinator.setupConfig.inputPort = "First In"
        coordinator.beginLearning()
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(60))
        coordinator.showOverwriteAlert = true
        coordinator.conflictingCommands = ["Old Conflict"]
        XCTAssertFalse(coordinator.capturedMappings.isEmpty)
        XCTAssertTrue(coordinator.isListening)

        let secondDevice = Device(name: "Second")
        let secondDocument = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [secondDevice])
        )
        XCTAssertTrue(coordinator.start(document: secondDocument, destinationDeviceID: secondDevice.id))

        XCTAssertEqual(coordinator.phase, .setup)
        XCTAssertFalse(coordinator.isListening)
        XCTAssertTrue(coordinator.capturedMappings.isEmpty)
        XCTAssertNil(coordinator.pendingMIDI)
        XCTAssertNil(coordinator.shiftMIDI)
        XCTAssertFalse(coordinator.isShiftHeld)
        XCTAssertFalse(coordinator.showOverwriteAlert)
        XCTAssertTrue(coordinator.conflictingCommands.isEmpty)
        XCTAssertFalse(coordinator.shouldDismiss)

        coordinator.setupConfig.controllerName = "Second Controller"
        coordinator.setupConfig.inputPort = "Second In"
        coordinator.beginLearning()
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(61))
        coordinator.performSave(overwrite: false)

        XCTAssertTrue(firstDocument.mappingFile.devices[0].mappings.isEmpty)
        XCTAssertEqual(secondDocument.mappingFile.devices[0].mappings.count, 1)
        XCTAssertEqual(secondDocument.mappingFile.devices[0].mappings[0].midiNote, 61)
    }

    func testNextSkipsTabsWhoseUnverifiedFunctionsWereRemoved() {
        coordinator.switchToTab(.setup)

        coordinator.next()

        XCTAssertEqual(coordinator.currentTab, .decks)
        XCTAssertNotNil(coordinator.currentFunction)
    }

    func testPreviousSkipsTabsWhoseUnverifiedFunctionsWereRemoved() {
        coordinator.switchToTab(.cueLoop)

        coordinator.previous()

        XCTAssertEqual(coordinator.currentTab, .decks)
        XCTAssertNotNil(coordinator.currentFunction)
    }

    func testLastVerifiedWizardFunctionIsReportedAsLastStep() {
        coordinator.setupConfig.numberOfChannels = 1
        coordinator.switchToTab(.cueLoop)
        for _ in 1..<WizardTab.cueLoop.functions.count {
            coordinator.next()
        }

        XCTAssertEqual(coordinator.currentFunction?.displayName, "Hotcue 8")
        XCTAssertTrue(coordinator.isAtLastStep)
    }

    // MARK: - Task 3.2: note-off never creates a capture

    func testNoteOffDoesNotAddOrReplaceCapture() {
        coordinator.switchToTab(.decks)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(captures(for: function.commandID).count, 1)
        XCTAssertEqual(captures(for: function.commandID).first?.midiMessage.value, 127)

        coordinator.handleMIDIReceived(noteOff(60))
        let after = captures(for: function.commandID)
        XCTAssertEqual(after.count, 1, "Note-off must not add a capture")
        XCTAssertEqual(after.first?.midiMessage.value, 127, "Note-off must not replace the note-on capture")
    }

    func testNoteOffDoesNotRestartAutoAdvance() {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.decks)

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
        coordinator.switchToTab(.decks)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        coordinator.handleMIDIReceived(cc(7, value: 0))
        let result = captures(for: function.commandID)
        XCTAssertEqual(result.count, 1, "CC with value 0 is a valid position and must capture")
        XCTAssertEqual(result.first?.midiMessage.cc, 7)
        XCTAssertEqual(result.first?.midiMessage.value, 0)
    }

    // MARK: - Task 3.3: nil/M1=0 dedup equivalence

    func testNilModifierAndM1ZeroDeduplicate() {
        coordinator.switchToTab(.decks)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }

        // Capture with no shift assigned → modifierCondition == nil
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(captures(for: function.commandID).count, 1)
        XCTAssertNil(captures(for: function.commandID).first?.modifierCondition)

        // Assign shift, then recapture the same function unshifted → M1 = 0
        assignShift(note: 99)
        coordinator.handleMIDIReceived(noteOn(61))

        let result = captures(for: function.commandID)
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
        coordinator.switchToTab(.decks)
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
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.previous()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "previous() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testClearCurrentMappingCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.clearCurrentMapping()
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "clearCurrentMapping() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testSwitchToTabCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.switchToTab(.decks)
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "switchToTab() must cancel a pending auto-advance")
        try await assertPositionStable()
    }

    func testCancelCancelsPendingAutoAdvance() async throws {
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.decks)
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
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(60))
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 1.0, accuracy: 0.001)

        coordinator.performSave(overwrite: false)
        XCTAssertEqual(coordinator.autoAdvanceCountdown, 0, accuracy: 0.001,
                       "performSave() must cancel a pending auto-advance")
        XCTAssertEqual(coordinator.phase, .complete)
        try await assertPositionStable()
    }

    func testSaveToDocumentWithConflictCancelsPendingAutoAdvance() async throws {
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        attachDocument(document, destinationDeviceID: device.id)
        coordinator.autoAdvanceEnabled = true
        coordinator.switchToTab(.decks)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }
        document.mappingFile.devices[0].mappings = [
            MappingEntry(
                commandID: function.commandID,
                assignment: try XCTUnwrap(coordinator.currentAssignment),
                setToValue: function.setToValue ?? 0
            )
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
        coordinator.switchToTab(.decks)
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
        coordinator.switchToTab(.decks)
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
        coordinator.switchToTab(.decks)
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

    func testConflictInOtherDeviceDoesNotTriggerOverwriteAlert() throws {
        let firstDevice = Device(name: "First")
        let secondDevice = Device(name: "Second")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [firstDevice, secondDevice]))
        attachDocument(document, destinationDeviceID: firstDevice.id)
        coordinator.switchToTab(.decks)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }
        // Conflict lives in devices[1]; the wizard only writes to devices[0],
        // so it must not count.
        document.mappingFile.devices[1].mappings = [
            MappingEntry(
                commandID: function.commandID,
                assignment: try XCTUnwrap(coordinator.currentAssignment),
                setToValue: function.setToValue ?? 0
            )
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

    func testConflictInFirstDeviceStillTriggersOverwriteAlert() throws {
        let firstDevice = Device(name: "First")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [firstDevice]))
        attachDocument(document, destinationDeviceID: firstDevice.id)
        coordinator.switchToTab(.decks)
        guard let function = coordinator.currentFunction else {
            return XCTFail("Expected a current function on the mixer tab")
        }
        document.mappingFile.devices[0].mappings = [
            MappingEntry(
                commandID: function.commandID,
                assignment: try XCTUnwrap(coordinator.currentAssignment),
                setToValue: function.setToValue ?? 0
            )
        ]

        coordinator.handleMIDIReceived(noteOn(60))
        coordinator.saveToDocument()

        XCTAssertTrue(coordinator.showOverwriteAlert)
        XCTAssertEqual(coordinator.conflictingCommands, [function.commandName])
    }

    func testSavedMappingEntryUsesCapturedMIDIChannel() {
        let document = attachDocument()
        coordinator.switchToTab(.decks)
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

    func testWizardSaveIsOneBackingDocumentUndoTransaction() throws {
        let existing = MappingEntry(commandID: 100, assignment: .deckA)
        let device = Device(name: "Generic MIDI", mappings: [existing])
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let backing = NSDocument()
        document.backingDocument = backing
        let undoManager = try XCTUnwrap(backing.undoManager)
        attachDocument(document, destinationDeviceID: device.id)
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(61))

        coordinator.performSave(overwrite: false)

        XCTAssertEqual(document.mappingFile.devices[0].mappings.count, 2)
        XCTAssertTrue(undoManager.canUndo)
        XCTAssertEqual(undoManager.undoActionName, "Save Wizard Mappings")
        undoManager.undo()
        XCTAssertEqual(document.mappingFile.devices[0].mappings, [existing])
        XCTAssertFalse(undoManager.canUndo, "the entire wizard save must be one Undo action")
    }

    func testWizardFailedPreflightLeavesDocumentAndUndoUnchanged() throws {
        let invalidDevice = Device(name: "")
        let original = MappingFile(devices: [invalidDevice])
        let document = TraktorMappingDocument(mappingFile: original)
        let backing = NSDocument()
        document.backingDocument = backing
        let undoManager = try XCTUnwrap(backing.undoManager)
        attachDocument(document, destinationDeviceID: invalidDevice.id)
        coordinator.switchToTab(.decks)
        coordinator.handleMIDIReceived(noteOn(61))

        coordinator.performSave(overwrite: false)

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertEqual(coordinator.phase, .learning)
        XCTAssertTrue(coordinator.statusMessage.localizedCaseInsensitiveContains("cannot"))
    }

    func testWizardOverwriteIsScopedToExplicitDestinationDevice() throws {
        let first = Device(name: "First")
        let target = Device(name: "Target")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [first, target]))
        attachDocument(document, destinationDeviceID: target.id)
        coordinator.switchToTab(.decks)
        let function = try XCTUnwrap(coordinator.currentFunction)
        let assignment = try XCTUnwrap(coordinator.currentAssignment)
        let conflict = MappingEntry(
            commandID: function.commandID,
            assignment: assignment,
            setToValue: function.setToValue ?? 0
        )
        document.mappingFile.devices[0].mappings = [conflict]
        document.mappingFile.devices[1].mappings = [conflict.copyWithNewID()]
        coordinator.handleMIDIReceived(noteOn(61))

        coordinator.performSave(overwrite: true)

        XCTAssertEqual(document.mappingFile.devices[0].mappings, [conflict])
        XCTAssertEqual(document.mappingFile.devices[1].mappings.count, 1)
        XCTAssertEqual(document.mappingFile.devices[1].mappings[0].midiNote, 61)
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
