import XCTest
@testable import XtremeMapping

@MainActor
final class JSONImportExportTests: XCTestCase {
    func testAcceptedReviewOpensExactCandidateAsDirtyUntitledDocument() throws {
        var file = MappingFile(devices: [Device(name: "Imported", mappings: [MappingEntry(commandID: 999999, ioType: .input)])])
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [])
        var opened: TraktorMappingDocument?
        let coordinator = JSONImportCoordinator(openDocument: { opened = $0 })
        coordinator.present(JSONImportCandidate(mappingFile: file, diagnostics: [], canOpen: true, canWriteTSI: false))
        coordinator.accept()
        let document = try XCTUnwrap(opened)
        XCTAssertEqual(document.mappingFile.devices.first?.id, file.devices.first?.id)
        XCTAssertEqual(document.mappingFile.allMappings.first?.id, file.allMappings.first?.id)
        XCTAssertEqual(document.mappingFile.interchangeMetadata, file.interchangeMetadata)
        XCTAssertNil(document.fileURL)
        XCTAssertTrue(document.isDirty)
    }

    func testCancelledOrInvalidReviewNeverOpensDocument() {
        var opened = 0
        let coordinator = JSONImportCoordinator(openDocument: { _ in opened += 1 })
        coordinator.present(JSONImportCandidate(mappingFile: MappingFile(), diagnostics: [], canOpen: true, canWriteTSI: true))
        coordinator.cancel()
        coordinator.accept()
        coordinator.present(JSONImportCandidate(mappingFile: nil, diagnostics: [], canOpen: false, canWriteTSI: false))
        coordinator.accept()
        XCTAssertEqual(opened, 0)
    }

    func testExportPreservesSourceDocumentAndDirtyState() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source.tsi")
        let sourceData = Data("Existing TSI".utf8)
        try sourceData.write(to: source)
        let document = TraktorMappingDocument(mappingFile: MappingFile())
        document.updateFileURL(source)
        document.noteChange()
        let destination = directory.appendingPathComponent("copy.sxm.json")
        try document.exportJSON(to: destination)
        XCTAssertTrue(document.isDirty)
        XCTAssertEqual(document.fileURL, source)
        XCTAssertEqual(try Data(contentsOf: source), sourceData)
        XCTAssertEqual(try SXMJSONCodec.decode(Data(contentsOf: destination)), document.mappingFile)
        XCTAssertThrowsError(try document.exportJSON(to: source))
        XCTAssertThrowsError(try document.exportJSON(to: destination))
    }

    func testCancelledBackgroundReviewCannotReplaceNewerCandidate() async {
        let oldCandidate = JSONImportCandidate(mappingFile: MappingFile(devices: [Device(name: "Old")]), diagnostics: [], canOpen: true, canWriteTSI: true)
        let newerCandidate = JSONImportCandidate(mappingFile: MappingFile(devices: [Device(name: "New")]), diagnostics: [], canOpen: true, canWriteTSI: true)
        let started = expectation(description: "Background review started")
        let gate = JSONReviewTestGate()
        var opened = 0
        let coordinator = JSONImportCoordinator(openDocument: { _ in opened += 1 }, reviewFile: { _ in
            started.fulfill()
            await gate.wait()
            return oldCandidate
        })
        let pending = coordinator.begin(url: URL(fileURLWithPath: "/unused.json"))
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(coordinator.isWorking)
        coordinator.cancel()
        coordinator.present(newerCandidate)
        await gate.release()
        await pending.value
        XCTAssertFalse(coordinator.isWorking)
        XCTAssertEqual(coordinator.candidate?.mappingFile?.devices.first?.name, "New")
        XCTAssertEqual(opened, 0)
    }

    func testBoundedReaderRejectsOversizedInput() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 32, count: 20).write(to: url)
        XCTAssertThrowsError(try JSONImportFileReader.read(url, maximumBytes: 10))
        XCTAssertEqual(try JSONImportFileReader.read(url, maximumBytes: 20).count, 20)
    }
}

private actor JSONReviewTestGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false
    func wait() async {
        if released { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
