import XCTest
@testable import XtremeMapping

final class AssistantConversationServiceTests: XCTestCase {
    func testMissingKeyAndByteBounds() async throws {
        let service = AssistantConversationService(apiKeyProvider: { nil })
        let context = ExplanationContext(revision: "r", rows: [], totalRows: 0, omittedRows: 0, limitations: [])
        let request = AssistantConversationRequest(question: "Help", context: context)
        do { _ = try await service.respond(to: request, model: .sonnet); XCTFail() }
        catch { XCTAssertTrue(error.localizedDescription.contains("key")) }
        var huge = request
        huge.question = String(repeating: "🙂", count: 4001)
        XCTAssertThrowsError(try service.makeRequest(apiKey: "test", conversation: huge, model: .sonnet))
        huge = request
        huge.context = ExplanationContext(revision: "r", rows: [], totalRows: 0, omittedRows: 0, limitations: [String(repeating: "🙂", count: 30000)])
        XCTAssertThrowsError(try service.makeRequest(apiKey: "test", conversation: huge, model: .sonnet))
    }

    func testStrictResponseAndCitationValidation() throws {
        let request = AssistantConversationRequest(question: "help", context: .init(revision: "r", rows: [], totalRows: 0, omittedRows: 0, limitations: []))
        let service = AssistantConversationService(apiKeyProvider: { nil })
        func envelope(_ input: String, stop: String = "tool_use") -> Data {
            Data("{\"stop_reason\":\"\(stop)\",\"content\":[{\"type\":\"tool_use\",\"name\":\"return_conversation\",\"input\":\(input)}]}".utf8)
        }
        let valid = "{\"answer\":{\"facts\":[],\"interpretations\":[],\"unknowns\":[\"Which deck?\"]},\"operations\":[]}"
        XCTAssertEqual(try service.decodeResponse(envelope(valid), request: request).answer.unknowns, ["Which deck?"])
        XCTAssertThrowsError(try service.decodeResponse(envelope(valid, stop: "max_tokens"), request: request))
        XCTAssertThrowsError(try service.decodeResponse(envelope(valid, stop: "refusal"), request: request))
        let invalid = "{\"answer\":{\"facts\":[{\"text\":\"x\",\"rowIDs\":[\"\(UUID())\"]}],\"interpretations\":[],\"unknowns\":[]},\"operations\":[]}"
        XCTAssertThrowsError(try service.decodeResponse(envelope(invalid), request: request))
        // The API now injects extra keys (e.g. "caller") into tool inputs. The
        // decoder tolerates unknown keys — they are inert, the app only ever
        // reads answer/operations — so an extra key must NOT reject the reply.
        let withInjectedKey = valid.replacingOccurrences(of: "\"operations\":[]", with: "\"operations\":[],\"caller\":\"assistant\"")
        XCTAssertEqual(try service.decodeResponse(envelope(withInjectedKey), request: request).answer.unknowns, ["Which deck?"])
    }

    func testRequestHasAuthoritativeCatalogueAndBoundedHistory() throws {
        let service = AssistantConversationService(apiKeyProvider: { nil })
        var request = AssistantConversationRequest(question: "play pause", context: .init(revision: "r", rows: [], totalRows: 0, omittedRows: 0, limitations: []))
        request.history = (0..<50).map { _ in .init(role: "user", text: String(repeating: "🙂", count: 1000)) }
        let transport = try service.makeRequest(apiKey: "secret", conversation: request, model: .sonnet)
        XCTAssertEqual(transport.timeoutInterval, 45)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(transport.httpBody)) as? [String: Any])
        XCTAssertEqual(body["max_tokens"] as? Int, 8192)
        let system = try XCTUnwrap(body["system"] as? String)
        XCTAssertFalse(system.contains("🙂")); XCTAssertFalse(system.contains("secret"))
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(XCTUnwrap(messages.first?["content"]).utf8)) as? [String: Any])
        XCTAssertLessThanOrEqual(try JSONSerialization.data(withJSONObject: XCTUnwrap(payload["history"])).count, 24 * 1024)
        let catalogue = try XCTUnwrap(payload["command_catalogue"] as? [[String: Any]])
        XCTAssertFalse(catalogue.isEmpty)
        for record in catalogue {
            let id = try XCTUnwrap(record["id"] as? Int)
            XCTAssertEqual(record["name"] as? String, TraktorCommands.name(for: id))
        }
    }
}

extension AssistantConversationServiceTests {
    func testProposalRejectsMissingTargetsAndCapturedAddressMismatch() throws {
        let device = Device(name: "Controller", inPort: "In", outPort: "Out", mappings: [])
        let file = MappingFile(devices: [device])
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Test", revision: "r")
        var request = AssistantConversationRequest(question: "sync", context: .init(revision: "r", rows: [], totalRows: 0, omittedRows: 0, limitations: []))
        request.availableDevices = snapshot.devices
        request.destinationDeviceID = device.id
        request.capturedMIDI = SXMJSONMIDI(try .note(channel: 1, number: 60))
        let answer = MappingAssistantAnswer(facts: [], interpretations: [.init(text: "Proposed Sync On", rowIDs: [])], unknowns: [])
        let valid = AssistantEditOperation(kind: .add, deviceID: device.id, newRowID: UUID(), patch: .init(commandID: 125, ioType: .input, assignment: .deckA, interactionMode: .toggle, midi: request.capturedMIDI, controllerType: .button))
        XCTAssertNoThrow(try AssistantConversationService.validate(.init(answer: answer, operations: [valid]), request: request))
        var wrong = valid
        wrong.patch?.midi = SXMJSONMIDI(try .note(channel: 1, number: 61))
        XCTAssertThrowsError(try AssistantConversationService.validate(.init(answer: answer, operations: [wrong]), request: request))
        request.capturedMIDI = nil
        XCTAssertThrowsError(try AssistantConversationService.validate(.init(answer: answer, operations: [valid]), request: request))
        request.question = "sync Note 60 channel 1"
        XCTAssertNoThrow(try AssistantConversationService.validate(.init(answer: answer, operations: [valid]), request: request))
        let missing = AssistantEditOperation(kind: .delete, deviceID: device.id, rowID: UUID())
        XCTAssertThrowsError(try AssistantConversationService.validate(.init(answer: answer, operations: [missing]), request: request))
    }
}

extension AssistantConversationServiceTests {
    func testCombiningMarkQuestionIsRejectedByUTF8ByteBudget() throws {
        let question = "a" + String(repeating: "\u{0301}", count: 9000)
        XCTAssertLessThan(question.count, 4000)
        XCTAssertGreaterThan(question.utf8.count, 16 * 1024)
        let request = AssistantConversationRequest(question: question, context: .init(revision: "r", rows: [], totalRows: 0, omittedRows: 0, limitations: []))
        let service = AssistantConversationService(apiKeyProvider: { nil })
        XCTAssertThrowsError(try service.makeRequest(apiKey: "test", conversation: request, model: .sonnet))
    }
}
