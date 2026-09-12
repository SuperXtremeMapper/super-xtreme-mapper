import XCTest
@testable import XtremeMapping

final class JSONRepairTests: XCTestCase {
    private func fixture(preserved: Bool = false) throws -> Data {
        var file = MappingFile(devices: [Device(name: "Test", mappings: [MappingEntry(commandID: 100,
            assignment: .deckA, interactionMode: .toggle, midiCC: 12, controllerType: .button)])])
        if preserved { file = try TSIParser().parseDocument(TSIWriter().write(file)) }
        return try SXMJSONCodec.encode(file)
    }
    func testSourceFreeSyntaxRepairKeepsExactOriginalAndRevalidates() throws {
        let good = try fixture()
        let original = Data((String(decoding: good, as: UTF8.self) + ",").utf8)
        let input = try JSONRepairInput(original: original)
        let tail = String(decoding: original.suffix(20), as: UTF8.self)
        let plan = try JSONRepairPlan(input: input, patches: [.init(before: tail, after: String(tail.dropLast()))])
        XCTAssertEqual(input.original, original)
        XCTAssertEqual(plan.repaired, good)
        XCTAssertTrue(plan.candidate.canOpen)
        XCTAssertTrue(plan.candidate.canWriteTSI)
        XCTAssertEqual(plan.patches.first?.before, tail)
    }
    func testSourceFreeMissingCommaBeforeKeyCanBeSafelyReviewed() throws {
        let good = try fixture()
        let text = String(decoding: good, as: UTF8.self)
        let before = "\"schemaVersion\" : 1,"
        XCTAssertTrue(text.contains(before))
        let original = Data(text.replacingOccurrences(of: before, with: "\"schemaVersion\" : 1").utf8)
        let plan = try JSONRepairPlan(input: JSONRepairInput(original: original),
            patches: [.init(before: "\"schemaVersion\" : 1", after: before)])
        XCTAssertEqual(plan.repaired, good)
        XCTAssertTrue(plan.candidate.canWriteTSI)
    }
    func testKnownScalarTypeErrorRemainsRepairable() throws {
        let good = try fixture()
        let correct = "\"schemaVersion\" : 1"
        let wrongType = "\"schemaVersion\" : \"1\""
        let original = Data(String(decoding: good, as: UTF8.self).replacingOccurrences(of: correct, with: wrongType).utf8)
        let plan = try JSONRepairPlan(input: JSONRepairInput(original: original),
            patches: [.init(before: wrongType, after: correct)])
        XCTAssertEqual(plan.repaired, good)
        XCTAssertTrue(plan.candidate.canWriteTSI)
    }
    func testPreservationIsRedactedAndUntouchedBySchemaRepair() throws {
        let good = try fixture(preserved: true)
        let original = Data(String(decoding: good, as: UTF8.self).replacingOccurrences(of: "\"schemaVersion\" : 1", with: "\"schemaVersion\" : 99").utf8)
        XCTAssertFalse(JSONImportService.review(original).canOpen)
        let input = try JSONRepairInput(original: original)
        let object = try JSONSerialization.jsonObject(with: good) as! [String: Any]
        let preservation = object["preservation"] as! [String: Any]
        for value in preservation.values.compactMap({ $0 as? String }) where value.count > 100 {
            XCTAssertFalse(input.redactedText.contains(value))
        }
        let plan = try JSONRepairPlan(input: input, patches: [.init(before: "\"schemaVersion\" : 99", after: "\"schemaVersion\" : 1")])
        XCTAssertEqual(plan.repaired, good)
        XCTAssertTrue(plan.candidate.canWriteTSI)
        XCTAssertEqual(plan.candidate.mappingFile?.sourceEnvelope?.originalXML, JSONImportService.review(good).mappingFile?.sourceEnvelope?.originalXML)
    }
    func testMalformedPreservationAndAmbiguousSyntaxRefuseBeforeTransport() throws {
        for text in ["{\"preservation\": {\"secret\":\"abc\"},", "{\"pre\\u0073ervation\": null,}", "{preservation: secret}", "{\"name\":\"unterminated"] {
            XCTAssertThrowsError(try JSONRepairInput(original: Data(text.utf8)))
        }
    }
    func testAmbiguousMalformedAndRenamedPreservationRefuseLocally() throws {
        for text in [#"{"preserv" "ation":{"originalXML":"private"}}"#,
                     #"{"preservatio":{"originalXML":"private"}}"#,
                     #"{"metadata":{"originalXML":"private"}}"#,
                     #"{"devices":[], "mystery":"private"}"#] {
            XCTAssertThrowsError(try JSONRepairInput(original: Data(text.utf8)))
        }
    }
    func testEntireVisibleTreeRequiresKnownFieldsAndContainerShapes() throws {
        let examples = [
            #"{"devices":[],"metadata":{"preservatio":{"originalXM":"PRIVATE_RETAINED_SOURCE"}}}"#,
            #"{"devices":[],"metadata":{"originalXM":"PRIVATE_RETAINED_SOURCE"}}"#,
            #"{"devices":[{"preservatio":{"originalXM":"PRIVATE_RETAINED_SOURCE"}}]}"#,
            #"{"devices":[{"mappings":[{"originalXM":"PRIVATE_RETAINED_SOURCE"}]}]}"#,
            #"{"devices":[{"mappings":[{"midi":{"mystery":"PRIVATE_RETAINED_SOURCE"}}]}]}"#,
            #"{"devices":[{"comment":{"name":"PRIVATE_RETAINED_SOURCE"}}]}"#,
            #"{"devices":[{"mappings":{"name":"PRIVATE_RETAINED_SOURCE"}}]}"#,
            #"{"devices":[],"metadata":{"profileReferences":[{"profileID":{"version":"PRIVATE_RETAINED_SOURCE"}}]}}"#
        ]
        for text in examples {
            XCTAssertThrowsError(try JSONRepairInput(original: Data(text.utf8)), text)
            let trailingComma = String(text.dropLast()) + ",}"
            XCTAssertThrowsError(try JSONRepairInput(original: Data(trailingComma.utf8)), trailingComma)
        }
    }
    @MainActor
    func testUnknownNestedSourceRefusesBeforeCredentialsOrTransport() async {
        var reads = 0
        let original = Data(#"{"devices":[],"metadata":{"preservatio":{"originalXM":"PRIVATE_RETAINED_SOURCE"}},}"#.utf8)
        let coordinator = JSONImportCoordinator(openDocument: { _ in }, readData: { _ in original },
            repairService: StubRepair(patches: []),
            repairCredentials: MappingAssistantCredentials(provider: { reads += 1; return "key" }))
        await coordinator.begin(url: URL(fileURLWithPath: "/unused")).value
        XCTAssertFalse(coordinator.canRequestRepair)
        XCTAssertNotNil(coordinator.repairUnavailableReason)
        await coordinator.requestRepair(consent: true)?.value
        XCTAssertEqual(reads, 0)
    }
    func testProtectedEditsAmbiguityOverlapNoopAndInvalidCandidateAreRejected() throws {
        let input = try JSONRepairInput(original: fixture(preserved: true))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: [.init(before: "\"preservation\"", after: "\"gone\"")]))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: [.init(before: "schemaVersion", after: "schemaVersion")]))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: [.init(before: "\"schemaVersion\" : 1", after: "\"schemaVersion\" : 99")]))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: [.init(before: " : ", after: ":")]))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: [.init(before: "schemaVersion", after: "schema"), .init(before: "\"schemaVersion\"", after: "\"version\"")]))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: []))
    }
    func testStrictResponseRejectsUnknownFieldsAndTools() throws {
        let service = JSONRepairService(apiKeyProvider: { nil })
        let valid = Data(#"{"stop_reason":"end_turn","content":[{"type":"text","text":"{\"patches\":[{\"before\":\"bad\",\"after\":\"good\"}]}"}]}"#.utf8)
        XCTAssertEqual(try service.decodeResponse(valid).count, 1)
        for body in [#"{"stop_reason":"tool_use","content":[{"type":"tool_use","name":"run","input":{}}]}"#,
                     #"{"stop_reason":"end_turn","content":[{"type":"text","text":"{\"patches\":[],\"extra\":1}"}]}"#] {
            XCTAssertThrowsError(try service.decodeResponse(Data(body.utf8)))
        }
        XCTAssertThrowsError(try service.decodeResponse(Data(repeating: 32, count: 128 * 1024 + 1)))
    }
    func testRequestContainsOnlyRedactedTextAndFixedSonnetWithoutTools() throws {
        let original = try fixture(preserved: true)
        let input = try JSONRepairInput(original: original)
        let request = try JSONRepairService(apiKeyProvider: { nil }).makeRequest(apiKey: "test-key", input: input)
        let body = try XCTUnwrap(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(object["model"] as? String, MappingAssistantModel.sonnet.rawValue)
        XCTAssertNil(object["tools"])
        XCTAssertEqual(request.timeoutInterval, 45)
        let message = (object["messages"] as! [[String: Any]])[0]["content"] as! String
        XCTAssertEqual(message, input.redactedText)
        let source = (try JSONSerialization.jsonObject(with: original) as! [String: Any])["preservation"] as! [String: Any]
        XCTAssertFalse(message.contains(source["originalXML"] as! String))
        XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("test-key"))
    }
    func testEscapedProtectedKeysAndIntroducedPreservationAreRejected() throws {
        let source = String(decoding: try fixture(preserved: true), as: UTF8.self)
            .replacingOccurrences(of: "\"preservation\"", with: "\"pre\\u0073ervation\"")
        let input = try JSONRepairInput(original: Data(source.utf8))
        XCTAssertFalse(input.redactedText.contains("originalXML"))
        XCTAssertThrowsError(try JSONRepairPlan(input: input, patches: [.init(before: "pre\\u0073ervation", after: "removed")]))
        let plain = try JSONRepairInput(original: fixture())
        XCTAssertThrowsError(try JSONRepairPlan(input: plain, patches: [.init(before: "\"schemaVersion\" : 1", after: "\"preservation\": null, \"schemaVersion\": 1")]))
        XCTAssertThrowsError(try JSONRepairInput(original: Data(repeating: 32, count: 8 * 1024 * 1024 + 1)))
        XCTAssertThrowsError(try JSONRepairInput(original: Data(("{\"text\":\"" + String(repeating: "a", count: 96 * 1024) + "\"}").utf8)))
    }
    func testTransportSanitizesStatusBodyAndNetworkErrors() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [RepairURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel(); RepairURLProtocol.handler = nil }
        let input = try JSONRepairInput(original: fixture())
        let service = JSONRepairService(apiKeyProvider: { "secret-key" }, session: session)
        RepairURLProtocol.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data("private server body secret-key".utf8))
        }
        do { _ = try await service.propose(for: input); XCTFail("Expected HTTP error") }
        catch { XCTAssertTrue(error.localizedDescription.contains("401")); XCTAssertFalse(error.localizedDescription.contains("secret-key")) }
        RepairURLProtocol.handler = { _ in throw NSError(domain: "secret-key", code: 1, userInfo: [NSLocalizedDescriptionKey: "private server body"]) }
        do { _ = try await service.propose(for: input); XCTFail("Expected network error") }
        catch { XCTAssertFalse(error.localizedDescription.contains("private server body")); XCTAssertFalse(error.localizedDescription.contains("secret-key")) }
    }

    @MainActor
    func testOriginalFileNeverChangesThroughRepairAndImport() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data((String(decoding: try fixture(), as: UTF8.self) + ",").utf8)
        try original.write(to: url)
        let tail = String(decoding: original.suffix(20), as: UTF8.self)
        var opened: TraktorMappingDocument?
        let coordinator = JSONImportCoordinator(openDocument: { opened = $0 },
            repairService: StubRepair(patches: [.init(before: tail, after: String(tail.dropLast()))]),
            repairCredentials: MappingAssistantCredentials(provider: { "key" }))
        await coordinator.begin(url: url).value
        await coordinator.requestRepair(consent: true)?.value
        coordinator.acceptRepair()
        coordinator.accept()
        XCTAssertNotNil(opened)
        XCTAssertNil(opened?.fileURL)
        XCTAssertTrue(opened?.isDirty == true)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    @MainActor
    func testCancelledRepairCannotReplaceNewImport() async throws {
        let good = try fixture()
        let original = Data((String(decoding: good, as: UTF8.self) + ",").utf8)
        let tail = String(decoding: original.suffix(20), as: UTF8.self)
        let gate = RepairGate()
        let started = expectation(description: "Repair started")
        let coordinator = JSONImportCoordinator(openDocument: { _ in }, readData: { _ in original },
            repairService: DelayedRepair(gate: gate, started: { started.fulfill() }, patches: [.init(before: tail, after: String(tail.dropLast()))]),
            repairCredentials: MappingAssistantCredentials(provider: { "key" }))
        await coordinator.begin(url: URL(fileURLWithPath: "/old")).value
        let pending = coordinator.requestRepair(consent: true)
        await fulfillment(of: [started], timeout: 5)
        await coordinator.begin(url: URL(fileURLWithPath: "/new")).value
        await gate.release()
        await pending?.value
        XCTAssertNil(coordinator.repairPlan)
        XCTAssertFalse(coordinator.isRepairing)
        XCTAssertFalse(coordinator.candidate!.canOpen)
        XCTAssertEqual(coordinator.originalData, original)
    }

    @MainActor
    func testConsentLazyKeyAndAcceptDiscardAreSeparateFromImport() async throws {
        let good = try fixture()
        let original = Data((String(decoding: good, as: UTF8.self) + ",").utf8)
        let tail = String(decoding: original.suffix(20), as: UTF8.self)
        var keyReads = 0
        var opened = 0
        let coordinator = JSONImportCoordinator(openDocument: { _ in opened += 1 },
            readData: { _ in original }, repairService: StubRepair(patches: [.init(before: tail, after: String(tail.dropLast()))]),
            repairCredentials: MappingAssistantCredentials(provider: { keyReads += 1; return "test-key" }))
        await coordinator.begin(url: URL(fileURLWithPath: "/unused")).value
        XCTAssertEqual(keyReads, 0)
        await coordinator.requestRepair(consent: false)?.value
        XCTAssertEqual(keyReads, 0)
        await coordinator.requestRepair(consent: true)?.value
        XCTAssertEqual(keyReads, 1)
        XCTAssertNotNil(coordinator.repairPlan)
        XCTAssertFalse(coordinator.candidate!.canOpen)
        coordinator.accept()
        XCTAssertEqual(opened, 0)
        coordinator.acceptRepair()
        XCTAssertTrue(coordinator.candidate!.canOpen)
        XCTAssertEqual(opened, 0)
        coordinator.discardRepair()
        XCTAssertFalse(coordinator.candidate!.canOpen)
        XCTAssertEqual(coordinator.originalData, original)
        await coordinator.requestRepair(consent: true)?.value
        coordinator.acceptRepair()
        coordinator.accept()
        XCTAssertEqual(opened, 1)
    }
}

private struct StubRepair: JSONRepairing {
    let patches: [JSONRepairPatch]
    func propose(for input: JSONRepairInput) async throws -> [JSONRepairPatch] { patches }
}

private actor RepairGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() { released = true; continuation?.resume(); continuation = nil }
}
private struct DelayedRepair: JSONRepairing {
    let gate: RepairGate
    let started: @Sendable () -> Void
    let patches: [JSONRepairPatch]
    func propose(for input: JSONRepairInput) async throws -> [JSONRepairPatch] {
        started(); await gate.wait(); return patches
    }
}

private final class RepairURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
