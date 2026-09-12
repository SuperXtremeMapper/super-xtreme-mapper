import XCTest
@testable import XtremeMapping

@MainActor
final class AssistantInputCoordinatorTests: XCTestCase {
    func testStartsOffAndLateTranscriptIsIgnoredAfterStop() async throws {
        let speech = AssistantTestSpeech()
        let midi = AssistantTestMIDI()
        let input = AssistantInputCoordinator(speech: speech, midi: midi)
        var received: [String] = []
        input.onTranscript = { received.append($0) }
        XCTAssertFalse(input.voiceEnabled)
        XCTAssertEqual(speech.starts, 0)
        await input.setVoiceEnabled(true)?.value
        let callback = speech.onTranscriptReady
        callback?("Deck A volume")
        XCTAssertEqual(received, ["Deck A volume"])
        input.stopAll()
        callback?("late")
        XCTAssertEqual(received.count, 1)
        XCTAssertFalse(input.voiceEnabled)
        XCTAssertFalse(speech.isListening)
    }

    func testCancelledStartCannotLeaveMicrophoneRunning() async throws {
        let speech = AssistantTestSpeech()
        speech.delay = true
        let input = AssistantInputCoordinator(speech: speech, midi: AssistantTestMIDI())
        let task = input.setVoiceEnabled(true)
        while speech.resume == nil { await Task.yield() }
        input.stopAll()
        speech.resume?.resume()
        await task?.value
        XCTAssertFalse(speech.isListening)
        XCTAssertFalse(input.voiceEnabled)
    }

    func testCaptureFreezesSupportedMessageAndReleasesOwnedListener() {
        let midi = AssistantTestMIDI()
        let input = AssistantInputCoordinator(speech: AssistantTestSpeech(), midi: midi)
        input.learnControl()
        let callback = midi.callback
        callback?(MIDIMessage(channel: 1, note: 50, cc: nil, value: 0))
        XCTAssertNil(input.capturedMIDI)
        callback?(MIDIMessage(channel: 3, note: nil, cc: 16, value: 64))
        XCTAssertEqual(input.capturedMIDI?.channel, 3)
        XCTAssertEqual(input.capturedMIDI?.number, 16)
        XCTAssertFalse(input.isLearning)
        XCTAssertEqual(midi.stops, 1)
        callback?(MIDIMessage(channel: 7, note: nil, cc: 22, value: 70))
        XCTAssertEqual(input.capturedMIDI?.number, 16)
        input.clearCapture()
        XCTAssertNil(input.capturedMIDI)
    }

    func testBusyMIDIAndSpeechFailureAreActionable() async {
        let midi = AssistantTestMIDI(); midi.accept = false
        let speech = AssistantTestSpeech(); speech.fail = true
        let input = AssistantInputCoordinator(speech: speech, midi: midi)
        input.learnControl()
        XCTAssertNotNil(input.errorMessage)
        XCTAssertFalse(input.isLearning)
        await input.setVoiceEnabled(true)?.value
        XCTAssertFalse(input.voiceEnabled)
        XCTAssertNotNil(input.errorMessage)
    }
}

@MainActor private final class AssistantTestSpeech: SpeechRecognitionProvider {
    var isListening = false
    var transcript = ""
    var onTranscriptReady: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onModelLoadProgress: ((Double, String) -> Void)?
    var starts = 0
    var delay = false
    var fail = false
    var resume: CheckedContinuation<Void, Never>?
    func startListening() async throws {
        starts += 1
        if delay { await withCheckedContinuation { resume = $0 } }
        if fail { throw CocoaError(.userCancelled) }
        isListening = true
    }
    func stopListening() { isListening = false }
}

@MainActor private final class AssistantTestMIDI: AssistantMIDIListening {
    var callback: ((MIDIMessage) -> Void)?
    var accept = true
    var stops = 0
    func start(_ callback: @escaping (MIDIMessage) -> Void) -> Bool {
        guard accept else { return false }; self.callback = callback; return true
    }
    func stop() { if callback != nil { stops += 1 }; callback = nil }
}
