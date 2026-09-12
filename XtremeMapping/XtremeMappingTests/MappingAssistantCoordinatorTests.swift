import XCTest
@testable import XtremeMapping

@MainActor
final class MappingAssistantCoordinatorTests: XCTestCase {
    func testSuccessfulAnswerUpdatesPublishedState() async {
        let service = ControlledAnswering()
        let coordinator = MappingAssistantCoordinator(service: service)
        let task = coordinator.ask(question: "q", contextJSON: Data("{}".utf8),
                                   allowedRowIDs: [], revision: "1", model: .sonnet)
        await waitUntil { service.pendingCount == 1 }
        XCTAssertTrue(coordinator.isWorking)

        let expected = MappingAssistantAnswer(facts: [], interpretations: [], unknowns: ["Unknown"])
        service.resumeFirst(with: .success(expected))
        await task.value

        XCTAssertEqual(coordinator.answer, expected)
        XCTAssertFalse(coordinator.isWorking)
        XCTAssertNil(coordinator.errorMessage)
    }

    func testReplacementRejectsLateResultEvenWhenServiceIgnoresCancellation() async {
        let service = ControlledAnswering()
        let coordinator = MappingAssistantCoordinator(service: service)
        let first = coordinator.ask(question: "first", contextJSON: Data("{}".utf8),
                                    allowedRowIDs: [], revision: "1", model: .sonnet)
        await waitUntil { service.pendingCount == 1 }
        let second = coordinator.ask(question: "second", contextJSON: Data("{}".utf8),
                                     allowedRowIDs: [], revision: "1", model: .haiku)
        await waitUntil { service.pendingCount == 2 }

        let current = MappingAssistantAnswer(facts: [], interpretations: [], unknowns: ["second"])
        let stale = MappingAssistantAnswer(facts: [], interpretations: [], unknowns: ["first"])
        service.resume(at: 1, with: .success(current))
        await second.value
        service.resume(at: 0, with: .success(stale))
        await first.value

        XCTAssertEqual(coordinator.answer, current)
        XCTAssertFalse(coordinator.isWorking)
    }

    func testCancelRejectsLateResultAndClearsWorkingState() async {
        let service = ControlledAnswering()
        let coordinator = MappingAssistantCoordinator(service: service)
        let task = coordinator.ask(question: "q", contextJSON: Data("{}".utf8),
                                   allowedRowIDs: [], revision: "1", model: .sonnet)
        await waitUntil { service.pendingCount == 1 }
        coordinator.cancel()
        XCTAssertFalse(coordinator.isWorking)

        service.resumeFirst(with: .success(MappingAssistantAnswer(
            facts: [], interpretations: [], unknowns: ["late"]
        )))
        await task.value
        XCTAssertNil(coordinator.answer)
        XCTAssertNil(coordinator.errorMessage)
    }

    func testRevisionInvalidationClearsAnswerAndRejectsLateResult() async {
        let service = ControlledAnswering()
        let coordinator = MappingAssistantCoordinator(service: service)
        let first = coordinator.ask(question: "q", contextJSON: Data("{}".utf8),
                                    allowedRowIDs: [], revision: "1", model: .sonnet)
        await waitUntil { service.pendingCount == 1 }
        service.resumeFirst(with: .success(MappingAssistantAnswer(
            facts: [], interpretations: [], unknowns: ["revision one"]
        )))
        await first.value
        XCTAssertNotNil(coordinator.answer)

        coordinator.invalidate(revision: "2")
        XCTAssertNil(coordinator.answer)
        XCTAssertNil(coordinator.errorMessage)

        let second = coordinator.ask(question: "q2", contextJSON: Data("{}".utf8),
                                     allowedRowIDs: [], revision: "2", model: .sonnet)
        await waitUntil { service.pendingCount == 2 }
        coordinator.invalidate(revision: "3")
        service.resume(at: 1, with: .success(MappingAssistantAnswer(
            facts: [], interpretations: [], unknowns: ["stale revision two"]
        )))
        await second.value
        XCTAssertNil(coordinator.answer)
        XCTAssertFalse(coordinator.isWorking)
    }

    func testCurrentFailurePublishesSanitizedMessage() async {
        let service = ControlledAnswering()
        let coordinator = MappingAssistantCoordinator(service: service)
        let task = coordinator.ask(question: "q", contextJSON: Data("{}".utf8),
                                   allowedRowIDs: [], revision: "1", model: .sonnet)
        await waitUntil { service.pendingCount == 1 }
        service.resumeFirst(with: .failure(TestFailure()))
        await task.value

        XCTAssertNil(coordinator.answer)
        XCTAssertEqual(coordinator.errorMessage, TestFailure().localizedDescription)
        XCTAssertFalse(coordinator.isWorking)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            await Task.yield()
        }
        XCTAssertTrue(condition())
    }
}

private struct TestFailure: LocalizedError {
    var errorDescription: String? { "Test failure" }
}

private final class ControlledAnswering: MappingAnswering, @unchecked Sendable {
    private struct Pending {
        let continuation: CheckedContinuation<MappingAssistantAnswer, Error>
    }
    private let lock = NSLock()
    private var pending: [Pending] = []

    var pendingCount: Int { lock.withLock { pending.count } }

    func answer(question: String, contextJSON: Data, allowedRowIDs: Set<UUID>,
                model: MappingAssistantModel) async throws -> MappingAssistantAnswer {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { pending.append(Pending(continuation: continuation)) }
            }
        } onCancel: {
            // Intentionally ignore cancellation. The coordinator must still reject this result.
        }
    }

    func resumeFirst(with result: Result<MappingAssistantAnswer, Error>) {
        resume(at: 0, with: result)
    }

    func resume(at index: Int, with result: Result<MappingAssistantAnswer, Error>) {
        let continuation = lock.withLock { pending[index].continuation }
        continuation.resume(with: result)
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
