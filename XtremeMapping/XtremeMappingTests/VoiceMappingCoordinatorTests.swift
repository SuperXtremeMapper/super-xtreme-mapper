//
//  VoiceMappingCoordinatorTests.swift
//  XtremeMappingTests
//
//  State-machine tests for the voice mapping coordinator: pending-input
//  consumption, re-trigger behavior, session reset, and command validation.
//

import XCTest
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
        mock.result = makeResult(command: "Play/Pause")

        await processPair(midi: makeMIDI(cc: 10), voice: "play deck a", expectedCallCount: 1)

        XCTAssertNil(coordinator.pendingMIDI, "pendingMIDI must be consumed by processMapping")
        XCTAssertNil(coordinator.pendingVoice, "pendingVoice must be consumed by processMapping")
        XCTAssertEqual(coordinator.currentResult?.command, "Play/Pause")
        XCTAssertEqual(coordinator.currentMIDI, makeMIDI(cc: 10))
    }

    func testNewMIDIAfterResultDoesNotRePairWithStaleTranscript() async {
        mock.result = makeResult(command: "Play/Pause")
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
        mock.result = makeResult(command: "Volume")
        mock.resume(with: makeResult(command: "Play/Pause"))

        await waitUntil("second processing to complete") {
            mock.callCount == 2 && !coordinator.isProcessing
        }
        XCTAssertEqual(mock.transcripts, ["voice one", "voice two"])
        XCTAssertEqual(coordinator.currentMIDI, makeMIDI(cc: 20))
        XCTAssertEqual(coordinator.currentResult?.command, "Volume")
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
        mock.result = makeResult(command: "Play/Pause")
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
        XCTAssertTrue(coordinator.sessionMappings.isEmpty, "saveAndContinue must refuse while processing")

        // The new result lands normally afterwards.
        mock.resume(with: makeResult(command: "Volume"))
        await waitUntil("second processing to complete") { !coordinator.isProcessing }
        XCTAssertEqual(coordinator.currentResult?.command, "Volume")
    }

    // MARK: - Task 2.2: deactivate clears session state

    func testDeactivateClearsSessionState() async {
        coordinator.activate()

        // Build up a session: one saved mapping plus a registered entry ID.
        mock.result = makeResult(command: "Play/Pause")
        await processPair(midi: makeMIDI(cc: 10), voice: "play deck a", expectedCallCount: 1)
        coordinator.saveAndContinue()
        coordinator.registerSessionMappingId(UUID())
        XCTAssertEqual(coordinator.sessionMappings.count, 1)
        XCTAssertEqual(coordinator.sessionMappingIds.count, 1)

        coordinator.deactivate()

        XCTAssertTrue(coordinator.sessionMappings.isEmpty, "deactivate must clear sessionMappings")
        XCTAssertTrue(coordinator.sessionMappingIds.isEmpty, "deactivate must clear sessionMappingIds")
    }

    // MARK: - Task 2.3: Unknown command names never reach the document

    func testStaleDisambiguationStateClearedWhenNewPairProcesses() async {
        // First pair yields a low-confidence result → disambiguation shown.
        mock.result = makeResult(
            command: "Play/Pause",
            confidence: 0.4,
            alternatives: [makeAlternative(command: "Play")]
        )
        await processPair(midi: makeMIDI(cc: 10), voice: "play something", expectedCallCount: 1)
        XCTAssertNotNil(coordinator.disambiguationOptions, "Low-confidence result should show options")

        // User ignores the options and captures a new pair instead.
        mock.result = makeResult(command: "Play", confidence: 0.95)
        await processPair(midi: makeMIDI(cc: 20), voice: "play it", expectedCallCount: 2)

        XCTAssertNil(coordinator.disambiguationOptions,
                     "Stale disambiguation options must be cleared when a new pair processes")
        XCTAssertEqual(coordinator.currentResult?.command, "Play")
        XCTAssertEqual(coordinator.currentMIDI?.cc, 20)

        // Saving now must save the NEW pair, not the stale disambiguation MIDI.
        coordinator.saveAndContinue()
        XCTAssertEqual(coordinator.sessionMappings.count, 1)
        XCTAssertEqual(coordinator.sessionMappings.first?.midi.cc, 20)
        XCTAssertEqual(coordinator.sessionMappings.first?.result.command, "Play")
    }

    func testUnknownPrimaryWithKnownAlternativeRoutesToDisambiguation() async {
        mock.result = makeResult(
            command: "Totally Made Up Knob",
            confidence: 0.95,
            alternatives: [
                makeAlternative(command: "Play/Pause"),
                makeAlternative(command: "Another Fake Command")
            ]
        )

        await processPair(midi: makeMIDI(cc: 10), voice: "do the thing", expectedCallCount: 1)

        XCTAssertNotEqual(coordinator.statusMessage, "Press Next to save",
                          "Unknown command must never be presented as save-ready")
        XCTAssertNil(coordinator.currentResult, "Unknown primary must not become a savable result")

        let options = coordinator.disambiguationOptions ?? []
        XCTAssertEqual(options.map(\.command), ["Play/Pause"],
                       "Disambiguation must show only known commands")

        // Selecting the known option makes it savable.
        coordinator.selectOption(0)
        XCTAssertEqual(coordinator.currentResult?.command, "Play/Pause")
        coordinator.saveAndContinue()
        XCTAssertEqual(coordinator.sessionMappings.count, 1)
        XCTAssertEqual(coordinator.sessionMappings.first?.result.command, "Play/Pause")
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
        XCTAssertTrue(coordinator.sessionMappings.isEmpty)
    }

    func testDisambiguationFiltersUnknownAlternatives() async {
        // Known primary, low confidence, mixed alternatives.
        mock.result = makeResult(
            command: "Play/Pause",
            confidence: 0.5,
            alternatives: [
                makeAlternative(command: "Bogus Control"),
                makeAlternative(command: "Volume")
            ]
        )

        await processPair(midi: makeMIDI(cc: 10), voice: "play something", expectedCallCount: 1)

        let options = coordinator.disambiguationOptions ?? []
        XCTAssertEqual(options.map(\.command), ["Play/Pause", "Volume"],
                       "Unknown alternatives must be filtered out of disambiguation")
    }

    func testSaveAndContinueRefusesUnknownCommand() {
        // Hand-seed an unknown result as if validation had been bypassed.
        coordinator.currentResult = makeResult(command: "Totally Made Up Knob")
        coordinator.currentMIDI = makeMIDI(cc: 10)

        coordinator.saveAndContinue()

        XCTAssertTrue(coordinator.sessionMappings.isEmpty,
                      "saveAndContinue must refuse unknown command names")
        XCTAssertEqual(coordinator.savedMappingCount, 0)
    }
}
