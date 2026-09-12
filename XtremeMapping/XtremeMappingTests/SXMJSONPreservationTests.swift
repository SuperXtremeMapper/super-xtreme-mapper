import XCTest
@testable import XtremeMapping

final class SXMJSONPreservationTests: XCTestCase {
    private var fixtures: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TSI")
    }

    @MainActor
    func testExportAfterCommittedSaveUsesReparsedSourceWithoutStaleCMAD() throws {
        let initial = MappingFile(devices: [Device(name: "Saved", mappings: [MappingEntry(commandID: 100,
            assignment: .deckA, interactionMode: .toggle, midiCC: 10, controllerType: .button)])])
        let document = try TraktorMappingDocument(fileContents: TSIWriter().write(initial))
        document.mappingFile.devices[0].mappings[0].comment = "saved comment"
        let saved = try document.prepareWriteSnapshot()
        try document.commitPendingWrite()
        let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(document.mappingFile))
        XCTAssertEqual(try TSIWriter().write(restored), saved.plan.output)
        XCTAssertEqual(restored.allMappings.first?.comment, "saved comment")
        document.mappingFile.devices[0].mappings[0].comment = "second unsaved comment"
        let edited = try SXMJSONCodec.decode(SXMJSONCodec.encode(document.mappingFile))
        XCTAssertEqual(edited.allMappings.first?.comment, "second unsaved comment")
        XCTAssertEqual(edited.sourceEnvelope?.originalXML, saved.plan.output)
        XCTAssertEqual(try TSIWriter().write(edited), try TSIWriter().write(document.mappingFile))
    }
    @MainActor
    func testJSONCreatedDocumentCanExportAfterSavingCanonicalDefaults() throws {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "New", mappings: [
            MappingEntry(commandID: 206, assignment: .deckA, interactionMode: .hold, midiCC: 12, controllerType: .button)])]))
        let saved = try document.prepareWriteSnapshot()
        try document.commitPendingWrite()
        let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(document.mappingFile))
        XCTAssertEqual(try TSIWriter().write(restored), saved.plan.output)
        XCTAssertEqual(restored.devices[0].name, "Generic MIDI")
        XCTAssertEqual(restored.devices[0].inPort, "All Ports")
        document.mappingFile.devices[0].comment = "unsaved device comment"
        document.mappingFile.devices[0].mappings[0].comment = "unsaved row comment"
        let edited = try SXMJSONCodec.decode(SXMJSONCodec.encode(document.mappingFile))
        XCTAssertEqual(edited.devices[0].comment, "unsaved device comment")
        XCTAssertEqual(edited.devices[0].mappings[0].comment, "unsaved row comment")
        XCTAssertEqual(edited.sourceEnvelope?.originalXML, saved.plan.output)
        XCTAssertEqual(try TSIWriter().write(edited), try TSIWriter().write(document.mappingFile))
    }
    func testNativeComplexExternalCommentEditProducesIntendedTSI() throws {
        let bytes = try Data(contentsOf: fixtures.appendingPathComponent("traktor-4.5.1-xone-k3-benchmark-06-outputs-comments-modifiers.tsi"))
        var file = try TSIParser().parseDocument(bytes)
        let exported = try SXMJSONCodec.encode(file)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: exported) as? [String: Any])
        var devices = object["devices"] as! [[String: Any]]
        var rows = devices[0]["mappings"] as! [[String: Any]]
        rows[0]["comment"] = "External native-fixture edit 🎛"
        devices[0]["mappings"] = rows; object["devices"] = devices
        let edited = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        let candidate = JSONImportService.review(edited)
        XCTAssertTrue(candidate.canOpen)
        XCTAssertTrue(candidate.canWriteTSI, "\(candidate.diagnostics.filter { $0.code == "preservation.writeBlocked" })")
        let output = try TSIWriter().write(XCTUnwrap(candidate.mappingFile))
        file.devices[0].mappings[0].comment = "External native-fixture edit 🎛"
        XCTAssertEqual(output, try TSIWriter().write(file))
        XCTAssertEqual(try TSIParser().parseDocument(output).allMappings[0].comment, "External native-fixture edit 🎛")
        XCTAssertEqual(candidate.mappingFile?.sourceEnvelope?.originalXML, bytes)
        let directory = URL(fileURLWithPath: "/tmp/sxm-json-demonstration")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unchangedOutput = try TSIWriter().write(SXMJSONCodec.decode(exported))
        XCTAssertEqual(unchangedOutput, bytes)
        try unchangedOutput.write(to: directory.appendingPathComponent("native-unchanged-roundtrip.tsi"))
        try exported.write(to: directory.appendingPathComponent("native-original.sxm.json"))
        try edited.write(to: directory.appendingPathComponent("native-edited.sxm.json"))
        try output.write(to: directory.appendingPathComponent("native-edited.tsi"))
    }
    func testUneditedComplexFixtureReturnsExactBytes() throws {
        let data = try Data(contentsOf: fixtures.appendingPathComponent("traktor-4.4.x-sanitized-complete.tsi"))
        let original = try TSIParser().parseDocument(data)
        XCTAssertFalse(try XCTUnwrap(original.sourceEnvelope).risks.isEmpty)
        let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(original))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(try TSIWriter().write(restored), data)
    }

    func testEveryAcceptedFixtureReturnsExactBytes() throws {
        let urls = try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "tsi" }
        var accepted = 0
        for url in urls {
            let bytes = try Data(contentsOf: url)
            guard let original = try? TSIParser().parseDocument(bytes) else { continue }
            accepted += 1
            let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(original))
            XCTAssertEqual(restored, original, url.lastPathComponent)
            XCTAssertEqual(try TSIWriter().write(restored), bytes, url.lastPathComponent)
        }
        XCTAssertGreaterThan(accepted, 3)
    }

    func testCurrentUnsavedCommentAndReorderKeepOriginalBaseline() throws {
        let bytes = try Data(contentsOf: fixtures.appendingPathComponent("traktor-4.4.x-sanitized-complete.tsi"))
        var original = try TSIParser().parseDocument(bytes)
        original.devices[0].mappings[0].comment = "External edit 🎚 日本語"
        original.devices[0].mappings.reverse()
        let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(original))
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.sourceEnvelope?.originalXML, bytes)
        XCTAssertFalse(try XCTUnwrap(restored.sourceEnvelope).baseline.matches(restored))
        XCTAssertThrowsError(try TSIWriter().write(original))
        XCTAssertThrowsError(try TSIWriter().write(restored))
    }
}
