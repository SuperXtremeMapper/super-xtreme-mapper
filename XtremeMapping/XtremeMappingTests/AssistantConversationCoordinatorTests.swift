import XCTest
@testable import XtremeMapping

private actor ConversationStub: AssistantConversing {
    var requests: [AssistantConversationRequest] = []
    func respond(to request: AssistantConversationRequest, model: MappingAssistantModel) async throws -> AssistantConversationResponse {
        requests.append(request)
        let row = request.context.rows[0]
        return .init(answer: .init(facts: [.init(text: "This row", rowIDs: [row.id])], interpretations: [], unknowns: []), operations: [.init(kind: .update, deviceID: row.deviceID, rowID: row.id, patch: .init(comment: request.question))])
    }
}
@MainActor final class AssistantConversationCoordinatorTests: XCTestCase {
    func testFollowUpReplacesProposalAndApplyClearsIt() async throws {
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "Assistant Test Controller", inPort: "Test In", outPort: "Test Out", mappings: [MappingEntry(commandID: 100)])]))
        let snapshot = try MappingExplanationSnapshot.build(file: doc.mappingFile, title: "Test", revision: doc.explanationRevision)
        let stub = ConversationStub(), coordinator = AssistantConversationCoordinator(service: stub)
        await coordinator.send(question: "first", document: doc, snapshot: snapshot, selectedIDs: [snapshot.rows[0].id], capturedMIDI: nil, destinationDeviceID: nil, model: .sonnet).value
        XCTAssertNotNil(coordinator.pendingPlan)
        await coordinator.send(question: "second", document: doc, snapshot: snapshot, selectedIDs: [], capturedMIDI: nil, destinationDeviceID: nil, model: .sonnet).value
        let requests = await stub.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[1].pendingOperations.count, 1)
        XCTAssertEqual(requests[1].history.count, 2)
        XCTAssertEqual(requests[1].context.rows.first?.id, snapshot.rows[0].id)
        XCTAssertTrue(try coordinator.apply(document: doc, isLocked: false, undoManager: nil))
        XCTAssertEqual(doc.mappingFile.allMappings[0].comment, "second")
        XCTAssertNil(coordinator.pendingPlan)
    }
    func testLocalLookupAndRevisionInvalidate() throws {
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "Assistant Test Controller", inPort: "Test In", outPort: "Test Out", mappings: [MappingEntry(commandID: 100)])]))
        let snapshot = try MappingExplanationSnapshot.build(file: doc.mappingFile, title: "Test", revision: doc.explanationRevision)
        let coordinator = AssistantConversationCoordinator(service: ConversationStub())
        coordinator.findLocally(question: "play", snapshot: snapshot, selectedIDs: [snapshot.rows[0].id])
        XCTAssertEqual(coordinator.localContext?.rows.count, 1)
        XCTAssertEqual(coordinator.messages.count, 2)
        coordinator.invalidate(revision: "new")
        XCTAssertNil(coordinator.localContext)
        XCTAssertNil(coordinator.pendingPlan)
        coordinator.clear(); XCTAssertTrue(coordinator.messages.isEmpty)
    }
}

private actor DelayedConversationStub: AssistantConversing {
    var continuations: [CheckedContinuation<AssistantConversationResponse, Never>] = []
    func respond(to request: AssistantConversationRequest, model: MappingAssistantModel) async throws -> AssistantConversationResponse {
        await withCheckedContinuation { continuations.append($0) }
    }
    var count: Int { continuations.count }
    func finish() {
        let pending = continuations; continuations = []
        for continuation in pending {
            continuation.resume(returning: .init(answer: .init(facts: [], interpretations: [], unknowns: ["Late answer"]), operations: []))
        }
    }
}
extension AssistantConversationCoordinatorTests {
    func testLateCancellationAndRevisionResponsesAreDropped() async throws {
        for changeRevision in [false, true] {
            let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "Assistant Test Controller", inPort: "Test In", outPort: "Test Out", mappings: [MappingEntry(commandID: 100)])]))
            let snapshot = try MappingExplanationSnapshot.build(file: doc.mappingFile, title: "Test", revision: doc.explanationRevision)
            let stub = DelayedConversationStub(), coordinator = AssistantConversationCoordinator(service: stub)
            let task = coordinator.send(question: "Help", document: doc, snapshot: snapshot, selectedIDs: [], capturedMIDI: nil, destinationDeviceID: nil, model: .sonnet)
            while await stub.count == 0 { await Task.yield() }
            if changeRevision { coordinator.invalidate(revision: "new") } else { coordinator.cancel() }
            await stub.finish(); await task.value
            XCTAssertFalse(coordinator.isWorking)
            XCTAssertNil(coordinator.pendingPlan)
            XCTAssertFalse(coordinator.messages.contains { $0.text == "Late answer" })
        }
    }
}

extension AssistantConversationCoordinatorTests {
    func testOverviewSamplesAcrossDevices() throws {
        let devices = (0..<3).map { index in Device(name: "Controller \(index)", inPort: "In", outPort: "Out", mappings: (0..<40).map { _ in MappingEntry(commandID: 100) }) }
        let file = MappingFile(devices: devices)
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Test", revision: "r")
        let coordinator = AssistantConversationCoordinator(service: ConversationStub())
        coordinator.findLocally(question: "Give me an overview of this configuration", snapshot: snapshot, selectedIDs: [])
        XCTAssertEqual(Set(coordinator.localContext?.rows.map(\.deviceID) ?? []).count, 3)
        XCTAssertGreaterThan(coordinator.localContext?.omittedRows ?? 0, 0)
        XCTAssertLessThanOrEqual(try JSONEncoder().encode(XCTUnwrap(coordinator.localContext)).count, 96 * 1024)
    }
}

private actor ExplanationConversationStub: AssistantConversing {
    var requests: [AssistantConversationRequest] = []
    func respond(to request: AssistantConversationRequest, model: MappingAssistantModel) async throws -> AssistantConversationResponse {
        requests.append(request)
        let rows = request.context.rows
        let answer = MappingAssistantAnswer(facts: rows.map { .init(text: "This mapping controls \($0.command).", rowIDs: [$0.id]) }, interpretations: [], unknowns: rows.isEmpty ? ["No rows supplied"] : [])
        return .init(answer: answer, operations: [])
    }
}
extension AssistantConversationCoordinatorTests {
    func testExplanationOnlyFollowUpsRetainReferencedRows() async throws {
        let file = MappingFile(devices: [Device(name: "Controller", inPort: "In", outPort: "Out", mappings: [MappingEntry(commandID: 125)])])
        let doc = TraktorMappingDocument(mappingFile: file)
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Test", revision: doc.explanationRevision)
        let stub = ExplanationConversationStub(), coordinator = AssistantConversationCoordinator(service: stub)
        await coordinator.send(question: "Explain selected row", document: doc, snapshot: snapshot, selectedIDs: [snapshot.rows[0].id], capturedMIDI: nil, destinationDeviceID: nil, model: .sonnet).value
        XCTAssertNil(coordinator.pendingPlan)
        for question in ["Why?", "What does this mean?"] {
            await coordinator.send(question: question, document: doc, snapshot: snapshot, selectedIDs: [], capturedMIDI: nil, destinationDeviceID: nil, model: .sonnet).value
            XCTAssertNil(coordinator.pendingPlan)
        }
        let requests = await stub.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests[1].context.rows.map(\.id), [snapshot.rows[0].id])
        XCTAssertEqual(requests[2].context.rows.map(\.id), [snapshot.rows[0].id])
    }

    func testLocalLookupRejectsQuestionOverUTF8Budget() throws {
        let question = "a" + String(repeating: "\u{0301}", count: 9000)
        let snapshot = try MappingExplanationSnapshot.build(file: MappingFile(devices: []), title: "Test", revision: "r")
        let coordinator = AssistantConversationCoordinator(service: ExplanationConversationStub())
        coordinator.findLocally(question: question, snapshot: snapshot, selectedIDs: [])
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertNil(coordinator.localContext)
        XCTAssertTrue(coordinator.messages.isEmpty)
    }
}
