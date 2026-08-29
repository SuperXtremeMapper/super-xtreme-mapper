//
//  VoiceMappingCoordinatorTests.swift
//  XtremeMappingTests
//
//  State-machine tests for the voice mapping coordinator: pending-input
//  consumption, re-trigger behavior, session reset, and command validation.
//

import XCTest
import AppKit
@testable import XtremeMapping

// MARK: - Mocks

/// Mock interpreter with a controllable async result.
///
/// Set `result` or `error` for immediate responses. Set `holdResponse = true`
/// to suspend the call until `resume(with:)` / `resume(throwing:)` is invoked,
/// which lets tests observe the coordinator mid-processing deterministically.
private final class MockInterpreter: CommandInterpreting, @unchecked Sendable {
    var result: VoiceCommandResult?
    var error: Error?
    var holdResponse = false

    private(set) var callCount = 0
    private(set) var transcripts: [String] = []
    private var heldContinuation: CheckedContinuation<VoiceCommandResult, Error>?

    struct MockError: Error {}

    func interpretCommand(
        transcript: String,
        availableCommands: [String]
    ) async throws -> VoiceCommandResult {
        callCount += 1
        transcripts.append(transcript)

        if holdResponse {
            return try await withCheckedThrowingContinuation { continuation in
                heldContinuation = continuation
            }
        }
        if let error {
            throw error
        }
        guard let result else {
            throw MockError()
        }
        return result
    }

    func resume(with result: VoiceCommandResult) {
        heldContinuation?.resume(returning: result)
        heldContinuation = nil
    }

    func resume(throwing error: Error) {
        heldContinuation?.resume(throwing: error)
        heldContinuation = nil
    }
}

/// No-op speech provider so tests never touch real speech recognition.
private final class MockSpeechProvider: SpeechRecognitionProvider {
    var isListening = false
    var transcript = ""
    var onTranscriptReady: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onModelLoadProgress: ((Double, String) -> Void)?

    func startListening() async throws { isListening = true }
    func stopListening() { isListening = false }
}

/// Speech provider whose starts complete only when the test resumes them.
/// Resuming sets listening after any earlier stop, reproducing providers that
/// do not cooperatively notice Task cancellation while starting.
private final class SuspendedSpeechProvider: SpeechRecognitionProvider {
    var isListening = false
    var transcript = ""
    var onTranscriptReady: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onModelLoadProgress: ((Double, String) -> Void)?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var starts: [CheckedContinuation<Void, Never>] = []

    func startListening() async throws {
        startCount += 1
        await withCheckedContinuation { continuation in
            starts.append(continuation)
        }
        isListening = true
    }

    func stopListening() {
        stopCount += 1
        isListening = false
    }

    func resumeNextStart() {
        starts.removeFirst().resume()
    }
}

// MARK: - Tests

@MainActor
final class VoiceMappingCoordinatorTests: XCTestCase {

    private var mock: MockInterpreter!
    private var coordinator: VoiceMappingCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockInterpreter()
        coordinator = VoiceMappingCoordinator(
            midiManager: MIDIInputManager.shared,
            voiceManager: VoiceInputManager(provider: MockSpeechProvider()),
            claudeService: mock
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        mock = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeMIDI(cc: Int, value: Int = 64) -> MIDIMessage {
        MIDIMessage(channel: 1, note: nil, cc: cc, value: value)
    }

    private func makeResult(
        command: String,
        confidence: Double = 0.95,
        alternatives: [CommandAlternative]? = nil
    ) -> VoiceCommandResult {
        VoiceCommandResult(
            command: command,
            assignment: nil,
            controllerType: nil,
            confidence: confidence,
            alternatives: alternatives
        )
    }

    private func makeAlternative(command: String, confidence: Double = 0.7) -> CommandAlternative {
        CommandAlternative(
            command: command,
            assignment: nil,
            description: "test alternative",
            confidence: confidence
        )
    }

    /// Spins the main actor until the condition holds or the timeout expires.
    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line,
        condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(condition(), "Timed out waiting for: \(description)", file: file, line: line)
    }

    /// Drives one full MIDI+voice pair through processing and waits for completion.
    private func processPair(
        midi: MIDIMessage,
        voice: String,
        expectedCallCount: Int
    ) async {
        coordinator.handleTranscriptReady(voice)
        coordinator.handleMIDIReceived(midi)
        await waitUntil("processing of \"\(voice)\" to complete") {
            mock.callCount == expectedCallCount && !coordinator.isProcessing
        }
    }

    // MARK: - Task 2.1: Pending state consumed by processMapping

    func testProcessingConsumesPendingInputs() async {
        mock.result = makeResult(command: "Cue")

        await processPair(midi: makeMIDI(cc: 10), voice: "play deck a", expectedCallCount: 1)

        XCTAssertNil(coordinator.pendingMIDI, "pendingMIDI must be consumed by processMapping")
        XCTAssertNil(coordinator.pendingVoice, "pendingVoice must be consumed by processMapping")
        XCTAssertEqual(coordinator.currentResult?.command, "Cue")
        XCTAssertEqual(coordinator.currentMIDI, makeMIDI(cc: 10))
    }

    func testNewMIDIAfterResultDoesNotRePairWithStaleTranscript() async {
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "play deck a", expectedCallCount: 1)

        // A second MIDI press arrives while the previous result is on screen.
        coordinator.handleMIDIReceived(makeMIDI(cc: 20))

        // Give any (incorrect) re-processing a chance to fire.
        try? await Task.sleep(nanoseconds: 200_000_000)
        await Task.yield()

        XCTAssertEqual(mock.callCount, 1, "Stale transcript must not re-pair with a new MIDI press")
        XCTAssertFalse(coordinator.isProcessing)
        XCTAssertEqual(coordinator.pendingMIDI, makeMIDI(cc: 20), "New MIDI waits for a new voice command")
    }

    // MARK: - Task 2.1: Re-trigger for new inputs arriving mid-processing

    func testNewInputsDuringProcessingAreProcessedAfterwards() async {
        mock.holdResponse = true
        coordinator.handleTranscriptReady("voice one")
        coordinator.handleMIDIReceived(makeMIDI(cc: 10))
        await waitUntil("first processing to start") { coordinator.isProcessing }

        // New pair arrives while the API call is in flight.
        coordinator.handleTranscriptReady("voice two")
        coordinator.handleMIDIReceived(makeMIDI(cc: 20))
        XCTAssertEqual(mock.callCount, 1, "No concurrent processing while isProcessing")

        // Complete the first call; the coordinator must re-trigger for the new pair.
        mock.holdResponse = false
        mock.result = makeResult(command: "Jog Turn")
        mock.resume(with: makeResult(command: "Cue"))

        await waitUntil("second processing to complete") {
            mock.callCount == 2 && !coordinator.isProcessing
        }
        XCTAssertEqual(mock.transcripts, ["voice one", "voice two"])
        XCTAssertEqual(coordinator.currentMIDI, makeMIDI(cc: 20))
        XCTAssertEqual(coordinator.currentResult?.command, "Jog Turn")
    }

    func testAPIErrorDoesNotRetryAndShowsFailedState() async {
        mock.error = MockInterpreter.MockError()

        coordinator.handleTranscriptReady("play deck a")
        coordinator.handleMIDIReceived(makeMIDI(cc: 10))
        await waitUntil("error processing to complete") {
            mock.callCount == 1 && !coordinator.isProcessing
        }

        // Give any (incorrect) retry loop a chance to fire.
        try? await Task.sleep(nanoseconds: 200_000_000)
        await Task.yield()

        XCTAssertEqual(mock.callCount, 1, "Consumed inputs must not retry on API error")
        XCTAssertNil(coordinator.pendingMIDI)
        XCTAssertNil(coordinator.pendingVoice)
        XCTAssertNil(coordinator.currentResult)
        XCTAssertNil(coordinator.currentMIDI, "Failed processing must not leave a half-paired MIDI")
        XCTAssertTrue(
            coordinator.statusMessage.localizedCaseInsensitiveContains("error"),
            "Status must reflect failure, got: \(coordinator.statusMessage)"
        )
    }

    // MARK: - Task 2.1: Stale result not savable mid-processing

    func testSaveRefusedWhileProcessingAndStaleResultCleared() async {
        // First pair completes and its result is on screen.
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "play deck a", expectedCallCount: 1)
        XCTAssertNotNil(coordinator.currentResult)

        // Second pair starts processing and is held in flight.
        mock.holdResponse = true
        coordinator.handleTranscriptReady("volume deck b")
        coordinator.handleMIDIReceived(makeMIDI(cc: 20))
        await waitUntil("second processing to start") { coordinator.isProcessing }

        XCTAssertNil(
            coordinator.currentResult,
            "Previous result must be cleared once new processing starts"
        )

        // Saving mid-processing is refused.
        coordinator.saveAndContinue()
        XCTAssertTrue(coordinator.stagedMappings.isEmpty, "saveAndContinue must refuse while processing")

        // The new result lands normally afterwards.
        mock.resume(with: makeResult(command: "Jog Turn"))
        await waitUntil("second processing to complete") { !coordinator.isProcessing }
        XCTAssertEqual(coordinator.currentResult?.command, "Jog Turn")
    }

    // MARK: - Task 2.2: deactivate clears session state

    func testDeactivateClearsSessionState() async {
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        XCTAssertTrue(coordinator.setDocument(document, destinationDeviceID: device.id))
        coordinator.activate()

        // Build up a session: one saved mapping (saveAndContinue registers
        // the document-inserted entry ID itself).
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "play deck a", expectedCallCount: 1)
        coordinator.saveAndContinue()
        XCTAssertEqual(coordinator.stagedMappings.count, 1)

        coordinator.deactivate()

        XCTAssertTrue(coordinator.stagedMappings.isEmpty, "deactivate must clear stagedMappings")
    }

    // MARK: - Task 2.3: Unknown command names never reach the document

    func testStaleDisambiguationStateClearedWhenNewPairProcesses() async {
        // First pair yields a low-confidence result → disambiguation shown.
        mock.result = makeResult(
            command: "Cue",
            confidence: 0.4,
            alternatives: [makeAlternative(command: "Loop Active On")]
        )
        await processPair(midi: makeMIDI(cc: 10), voice: "play something", expectedCallCount: 1)
        XCTAssertNotNil(coordinator.disambiguationOptions, "Low-confidence result should show options")

        // User ignores the options and captures a new pair instead.
        mock.result = makeResult(command: "Loop Active On", confidence: 0.95)
        await processPair(midi: makeMIDI(cc: 20), voice: "play it", expectedCallCount: 2)

        XCTAssertNil(coordinator.disambiguationOptions,
                     "Stale disambiguation options must be cleared when a new pair processes")
        XCTAssertEqual(coordinator.currentResult?.command, "Loop Active On")
        XCTAssertEqual(coordinator.currentMIDI?.cc, 20)

        // Saving now must save the NEW pair, not the stale disambiguation MIDI.
        coordinator.saveAndContinue()
        XCTAssertEqual(coordinator.stagedMappings.count, 1)
        XCTAssertEqual(coordinator.stagedMappings.first?.midiCC, 20)
        XCTAssertEqual(coordinator.stagedMappings.first?.commandName, "Loop Active On")
    }

    func testUnknownPrimaryWithKnownAlternativeRoutesToDisambiguation() async {
        mock.result = makeResult(
            command: "Totally Made Up Knob",
            confidence: 0.95,
            alternatives: [
                makeAlternative(command: "Cue"),
                makeAlternative(command: "Another Fake Command")
            ]
        )

        await processPair(midi: makeMIDI(cc: 10), voice: "do the thing", expectedCallCount: 1)

        XCTAssertNotEqual(coordinator.statusMessage, "Press Next to save",
                          "Unknown command must never be presented as save-ready")
        XCTAssertNil(coordinator.currentResult, "Unknown primary must not become a savable result")

        let options = coordinator.disambiguationOptions ?? []
        XCTAssertEqual(options.map(\.command), ["Cue"],
                       "Disambiguation must show only known commands")

        // Selecting the known option makes it savable.
        coordinator.selectOption(0)
        XCTAssertEqual(coordinator.currentResult?.command, "Cue")
        coordinator.saveAndContinue()
        XCTAssertEqual(coordinator.stagedMappings.count, 1)
        XCTAssertEqual(coordinator.stagedMappings.first?.commandName, "Cue")
    }

    func testUnknownPrimaryWithNoKnownAlternativesIsError() async {
        mock.result = makeResult(
            command: "Totally Made Up Knob",
            confidence: 0.95,
            alternatives: [makeAlternative(command: "Another Fake Command")]
        )

        await processPair(midi: makeMIDI(cc: 10), voice: "do the thing", expectedCallCount: 1)

        XCTAssertNil(coordinator.currentResult)
        XCTAssertNil(coordinator.currentMIDI)
        XCTAssertNil(coordinator.disambiguationOptions)
        XCTAssertNotEqual(coordinator.statusMessage, "Press Next to save")
        coordinator.saveAndContinue()
        XCTAssertTrue(coordinator.stagedMappings.isEmpty)
    }

    func testDisambiguationFiltersUnknownAlternatives() async {
        // Known primary, low confidence, mixed alternatives.
        mock.result = makeResult(
            command: "Cue",
            confidence: 0.5,
            alternatives: [
                makeAlternative(command: "Bogus Control"),
                makeAlternative(command: "Jog Turn")
            ]
        )

        await processPair(midi: makeMIDI(cc: 10), voice: "play something", expectedCallCount: 1)

        let options = coordinator.disambiguationOptions ?? []
        XCTAssertEqual(options.map(\.command), ["Cue", "Jog Turn"],
                       "Unknown alternatives must be filtered out of disambiguation")
    }

    func testSaveAndContinueRefusesUnknownCommand() {
        // Hand-seed an unknown result as if validation had been bypassed.
        coordinator.currentResult = makeResult(command: "Totally Made Up Knob")
        coordinator.currentMIDI = makeMIDI(cc: 10)

        coordinator.saveAndContinue()

        XCTAssertTrue(coordinator.stagedMappings.isEmpty,
                      "saveAndContinue must refuse unknown command names")
    }

    func testHighConfidenceLegacyCommandIsRejected() async {
        mock.result = makeResult(command: "Cruise Mode On")

        await processPair(midi: makeMIDI(cc: 10), voice: "enable cruise", expectedCallCount: 1)

        XCTAssertNil(coordinator.currentResult)
        XCTAssertNil(coordinator.currentMIDI)
        XCTAssertNil(coordinator.disambiguationOptions)
        XCTAssertTrue(coordinator.statusMessage.contains("isn't a known Traktor command"))
    }

    func testHighConfidenceOutputOnlyCommandIsRejectedForVoiceInput() async {
        mock.result = makeResult(command: "Slot State")

        await processPair(midi: makeMIDI(cc: 10), voice: "show slot state", expectedCallCount: 1)

        XCTAssertNil(coordinator.currentResult)
        XCTAssertNil(coordinator.currentMIDI)
        XCTAssertNil(coordinator.disambiguationOptions)
        XCTAssertTrue(coordinator.statusMessage.contains("isn't a known Traktor command"))
    }

    func testDisambiguationOffersOnlyVerifiedInputCommands() async {
        mock.result = makeResult(
            command: "Cue",
            confidence: 0.5,
            alternatives: [
                makeAlternative(command: "Slot State"),
                makeAlternative(command: "Cruise Mode On"),
                makeAlternative(command: "Jog Turn"),
                makeAlternative(command: "Totally Made Up Knob")
            ]
        )

        await processPair(midi: makeMIDI(cc: 10), voice: "choose a control", expectedCallCount: 1)

        XCTAssertEqual(coordinator.disambiguationOptions?.map(\.command), ["Cue", "Jog Turn"])
    }

    func testSaveAndContinueRefusesUnverifiedCommand() {
        coordinator.currentResult = makeResult(command: "Cruise Mode On")
        coordinator.currentMIDI = makeMIDI(cc: 10)

        coordinator.saveAndContinue()

        XCTAssertTrue(coordinator.stagedMappings.isEmpty)
        XCTAssertTrue(coordinator.statusMessage.contains("not saved"))
    }

    // MARK: - Atomic staged session

    func testVoiceMappingBuilderCreatesEntryWithoutDocumentMutation() throws {
        let document = TraktorMappingDocument()
        let before = document.mappingFile

        let entry = try VoiceMappingBuilder.makeEntry(
            midi: makeMIDI(cc: 10),
            result: makeResult(command: "Cue")
        )

        XCTAssertEqual(document.mappingFile, before)
        XCTAssertEqual(entry.commandName, "Cue")
        XCTAssertEqual(entry.midiCC, 10)
    }

    func testActivateRejectsInvalidMultiDeviceDestination() {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [
            Device(name: "First"),
            Device(name: "Second"),
        ]))

        XCTAssertFalse(coordinator.setDocument(document, destinationDeviceID: nil))
        coordinator.activate()

        XCTAssertFalse(coordinator.isActive)
        XCTAssertTrue(coordinator.statusMessage.localizedCaseInsensitiveContains("destination"))
    }

    func testCancelDuringSuspendedActivationCannotReactivateMicrophoneOrOverwriteStatus() async {
        let provider = SuspendedSpeechProvider()
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        coordinator = VoiceMappingCoordinator(
            midiManager: MIDIInputManager.shared,
            voiceManager: VoiceInputManager(provider: provider),
            claudeService: mock
        )
        XCTAssertTrue(coordinator.setDocument(document, destinationDeviceID: device.id))

        coordinator.activate()
        await waitUntil("activation start to suspend") { provider.startCount == 1 }
        coordinator.cancelSession()
        provider.resumeNextStart()
        await waitUntil("stale activation to finish and stop") { provider.stopCount >= 2 }

        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(provider.isListening)
        XCTAssertEqual(coordinator.statusMessage, "")
    }

    func testFinishDuringSuspendedRestartCannotReactivateMicrophoneOrOverwriteSavedStatus() async {
        let provider = SuspendedSpeechProvider()
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        coordinator = VoiceMappingCoordinator(
            midiManager: MIDIInputManager.shared,
            voiceManager: VoiceInputManager(provider: provider),
            claudeService: mock
        )
        XCTAssertTrue(coordinator.setDocument(document, destinationDeviceID: device.id))
        coordinator.activate()
        await waitUntil("initial activation to suspend") { provider.startCount == 1 }
        provider.resumeNextStart()
        await waitUntil("initial activation to finish") { provider.isListening }

        coordinator.currentResult = makeResult(command: "Cue")
        coordinator.currentMIDI = makeMIDI(cc: 10)
        coordinator.saveAndContinue()
        await waitUntil("session restart to suspend") { provider.startCount == 2 }

        coordinator.finishAndSave()
        XCTAssertEqual(coordinator.statusMessage, "Saved 1 mappings!")
        provider.resumeNextStart()
        await waitUntil("stale restart to finish and stop") { provider.stopCount >= 2 }

        XCTAssertFalse(coordinator.isActive)
        XCTAssertFalse(provider.isListening)
        XCTAssertEqual(coordinator.statusMessage, "Saved 1 mappings!")
    }

    func testFinishRefusesToDropVisibleUnstagedMapping() {
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        XCTAssertTrue(coordinator.setDocument(document, destinationDeviceID: device.id))
        coordinator.currentResult = makeResult(command: "Cue")
        coordinator.currentMIDI = makeMIDI(cc: 10)
        coordinator.saveAndContinue()
        coordinator.currentResult = makeResult(command: "Jog Turn")
        coordinator.currentMIDI = makeMIDI(cc: 11)
        let beforeFinish = document.mappingFile

        XCTAssertFalse(coordinator.canFinishSession)
        coordinator.finishAndSave()

        XCTAssertEqual(document.mappingFile, beforeFinish)
        XCTAssertEqual(coordinator.stagedMappings.count, 1)
        XCTAssertEqual(coordinator.currentResult?.command, "Jog Turn")
        XCTAssertEqual(coordinator.currentMIDI?.cc, 11)
        XCTAssertTrue(coordinator.statusMessage.localizedCaseInsensitiveContains("add"))

        coordinator.performVoiceSave(overwrite: false)
        XCTAssertEqual(document.mappingFile, beforeFinish)
        XCTAssertEqual(coordinator.stagedMappings.count, 1)
        XCTAssertEqual(coordinator.currentResult?.command, "Jog Turn")
    }

    func testSaveAndContinueStagesWithoutDocumentOrUndoMutation() async throws {
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let backing = NSDocument()
        document.backingDocument = backing
        let before = document.mappingFile
        coordinator.setDocument(document, destinationDeviceID: device.id)
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "cue deck a", expectedCallCount: 1)

        coordinator.saveAndContinue()

        XCTAssertEqual(coordinator.stagedMappings.count, 1)
        XCTAssertEqual(document.mappingFile, before)
        XCTAssertFalse(try XCTUnwrap(backing.undoManager).canUndo)
        XCTAssertTrue(coordinator.statusMessage.contains("Added to Session"))
        XCTAssertNil(coordinator.currentResult)
        XCTAssertNil(coordinator.currentMIDI)
    }

    func testFinishCommitsEntireVoiceSessionAsOneUndoTransaction() async throws {
        let existing = MappingEntry(commandID: 100, assignment: .deckA)
        let device = Device(name: "Generic MIDI", mappings: [existing])
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let backing = NSDocument()
        document.backingDocument = backing
        let undoManager = try XCTUnwrap(backing.undoManager)
        coordinator.setDocument(document, destinationDeviceID: device.id)

        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "cue", expectedCallCount: 1)
        coordinator.saveAndContinue()
        mock.result = makeResult(command: "Jog Turn")
        await processPair(midi: makeMIDI(cc: 11), voice: "jog", expectedCallCount: 2)
        coordinator.saveAndContinue()

        coordinator.finishAndSave()

        XCTAssertEqual(document.mappingFile.devices[0].mappings.count, 3)
        XCTAssertTrue(coordinator.stagedMappings.isEmpty)
        XCTAssertEqual(undoManager.undoActionName, "Save Voice Mappings")
        undoManager.undo()
        XCTAssertEqual(document.mappingFile.devices[0].mappings, [existing])
        XCTAssertFalse(undoManager.canUndo, "the complete voice session must be one Undo action")
    }

    func testVoiceOverwriteRemovesOnlyExactSemanticMatchInDestinationDevice() async throws {
        let target = Device(name: "Target")
        let other = Device(name: "Other")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [target, other]))
        coordinator.setDocument(document, destinationDeviceID: target.id)
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "cue", expectedCallCount: 1)
        coordinator.saveAndContinue()

        let staged = try XCTUnwrap(coordinator.stagedMappings.first)
        let exact = staged.copyWithNewID()
        var differentDirection = staged.copyWithNewID()
        differentDirection.ioType = .output
        var differentTarget = staged.copyWithNewID()
        differentTarget.assignment = .deckB
        var differentSetTo = staged.copyWithNewID()
        differentSetTo.setToValue = 0.25
        var differentModifierNumber = staged.copyWithNewID()
        differentModifierNumber.modifier1Condition = ModifierCondition(modifier: 2, value: 3)
        var differentModifierValue = staged.copyWithNewID()
        differentModifierValue.modifier2Condition = ModifierCondition(modifier: 4, value: 5)
        var unsupportedConditionTarget = staged.copyWithNewID()
        unsupportedConditionTarget.modifier1Condition = ModifierCondition(modifier: 6, value: 7)
        var payload = Data(repeating: 0, count: 120)
        func store(_ value: UInt32, at offset: Int) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { bytes in
                payload.replaceSubrange(offset..<(offset + 4), with: bytes)
            }
        }
        store(6, at: 52)
        store(99, at: 56)
        store(7, at: 60)
        unsupportedConditionTarget.importedCMAD = try XCTUnwrap(
            ImportedCMAD(payload: payload, semanticAtImport: unsupportedConditionTarget)
        )

        let nearMatches = [
            differentDirection,
            differentTarget,
            differentSetTo,
            differentModifierNumber,
            differentModifierValue,
            unsupportedConditionTarget,
        ]
        document.mappingFile.devices[0].mappings = [exact] + nearMatches
        document.mappingFile.devices[1].mappings = [staged.copyWithNewID()]
        let otherDeviceBefore = document.mappingFile.devices[1]

        coordinator.performVoiceSave(overwrite: true)

        let savedTarget = document.mappingFile.devices[0].mappings
        XCTAssertFalse(savedTarget.contains(where: { $0.id == exact.id }))
        for nearMatch in nearMatches {
            XCTAssertTrue(
                savedTarget.contains(where: { $0.id == nearMatch.id }),
                "A different semantic binding component must make the row nonreplaceable"
            )
        }
        XCTAssertTrue(savedTarget.contains(where: { $0.id == staged.id }))
        XCTAssertEqual(document.mappingFile.devices[1], otherDeviceBefore)
    }

    func testCancelClearsStagingAndLeavesDocumentUnchanged() async {
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let before = document.mappingFile
        coordinator.setDocument(document, destinationDeviceID: device.id)
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "cue", expectedCallCount: 1)
        coordinator.saveAndContinue()

        coordinator.cancelSession()

        XCTAssertTrue(coordinator.stagedMappings.isEmpty)
        XCTAssertEqual(document.mappingFile, before)
    }

    func testFailedFinishKeepsStagingAndLeavesDocumentAndUndoUnchanged() async throws {
        let device = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let backing = NSDocument()
        document.backingDocument = backing
        let undoManager = try XCTUnwrap(backing.undoManager)
        coordinator.setDocument(document, destinationDeviceID: device.id)
        mock.result = makeResult(command: "Cue")
        await processPair(midi: makeMIDI(cc: 10), voice: "cue", expectedCallCount: 1)
        coordinator.saveAndContinue()
        document.mappingFile.devices.removeAll()
        let beforeFinish = document.mappingFile

        coordinator.finishAndSave()

        XCTAssertEqual(document.mappingFile, beforeFinish)
        XCTAssertEqual(coordinator.stagedMappings.count, 1)
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertTrue(coordinator.statusMessage.localizedCaseInsensitiveContains("destination"))
    }
}
