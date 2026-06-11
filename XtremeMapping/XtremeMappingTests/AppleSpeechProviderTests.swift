//
//  AppleSpeechProviderTests.swift
//  XtremeMappingTests
//
//  Tests for the stale-task guards: delegate callbacks from a restarted
//  recognizer's old task must be ignored, and the delayed task start must
//  no-op when the recognition request has been swapped underneath it.
//
//  SFSpeechRecognitionTask is not directly constructible, so the identity
//  checks are tested through the AnyObject-typed static seams plus the
//  instance-level delayed-start method (driven with real, constructible
//  SFSpeechAudioBufferRecognitionRequest instances).
//

import XCTest
import Speech
@testable import XtremeMapping

@MainActor
final class AppleSpeechProviderTests: XCTestCase {

    // MARK: - isCurrentToken (delegate stale-task identity check)

    func testIsCurrentTokenTrueForSameObject() {
        let token = NSObject()
        XCTAssertTrue(AppleSpeechProvider.isCurrentToken(token, current: token))
    }

    func testIsCurrentTokenFalseForDistinctObjects() {
        XCTAssertFalse(AppleSpeechProvider.isCurrentToken(NSObject(), current: NSObject()),
                       "A stale task token must never be treated as current")
    }

    func testIsCurrentTokenFalseWhenNoCurrentTask() {
        XCTAssertFalse(AppleSpeechProvider.isCurrentToken(NSObject(), current: nil),
                       "Callbacks arriving after the task is cleared must be ignored")
    }

    func testIsCurrentTokenFalseWhenCandidateNil() {
        XCTAssertFalse(AppleSpeechProvider.isCurrentToken(nil, current: NSObject()))
    }

    // MARK: - shouldStartDelayedTask (delayed-start guard)

    func testShouldStartWhenListeningAndRequestUnchanged() {
        let request = NSObject()
        XCTAssertTrue(AppleSpeechProvider.shouldStartDelayedTask(
            isListening: true, currentRequest: request, capturedRequest: request
        ))
    }

    func testShouldNotStartWhenRequestSwapped() {
        XCTAssertFalse(AppleSpeechProvider.shouldStartDelayedTask(
            isListening: true, currentRequest: NSObject(), capturedRequest: NSObject()
        ), "A quick stop→start swaps the request; the stale delayed start must no-op")
    }

    func testShouldNotStartWhenRequestCleared() {
        XCTAssertFalse(AppleSpeechProvider.shouldStartDelayedTask(
            isListening: true, currentRequest: nil, capturedRequest: NSObject()
        ))
    }

    func testShouldNotStartWhenNotListening() {
        let request = NSObject()
        XCTAssertFalse(AppleSpeechProvider.shouldStartDelayedTask(
            isListening: false, currentRequest: request, capturedRequest: request
        ))
    }

    // MARK: - startDelayedRecognitionTask (instance-level guard)

    func testDelayedStartNoOpsWhenProviderNeverStarted() {
        let provider = AppleSpeechProvider()

        // The provider has no live request (never started): a delayed start
        // captured against a now-dead request must not start any task.
        provider.startDelayedRecognitionTask(for: SFSpeechAudioBufferRecognitionRequest())

        XCTAssertNil(provider.recognitionTask,
                     "Delayed start must not attach a task to a dead request")
        XCTAssertFalse(provider.isListening)
    }
}
