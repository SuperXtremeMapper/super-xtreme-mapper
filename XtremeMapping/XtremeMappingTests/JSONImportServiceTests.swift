import XCTest
@testable import XtremeMapping

final class JSONImportServiceTests: XCTestCase {
    private func json(_ change: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let row = MappingEntry(commandID: 100, assignment: .deckA, interactionMode: .toggle,
            midiCC: 12, controllerType: .button)
        let file = MappingFile(devices: [Device(name: "Test", mappings: [row])])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: SXMJSONCodec.encode(file)) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }
    private func editRow(_ edit: (inout [String: Any]) -> Void) throws -> Data {
        try json { object in
            var devices = object["devices"] as! [[String: Any]]
            var rows = devices[0]["mappings"] as! [[String: Any]]
            edit(&rows[0]); devices[0]["mappings"] = rows; object["devices"] = devices
        }
    }
    func testUnsafeValuesAreRejectedBeforeWriterPreflight() throws {
        for (command, controller, interaction, value) in [(100, "none", "none", 1e30), (2548, "button", "direct", 99.0), (2548, "button", "direct", 1.5)] {
            let data = try editRow { $0["commandID"] = command; $0.removeValue(forKey: "commandName")
                $0["controllerType"] = controller; $0["interactionMode"] = interaction; $0["setToValue"] = value }
            let document = try SXMJSONCodec.document(from: data)
            XCTAssertTrue(MappingValidationService.validate(document, source: nil).contains { $0.code == "value.setToValue" && $0.severity == .error })
        }
    }
    func testKnownFXTargetMismatchIsRejected() throws {
        let result = JSONImportService.review(try editRow {
            $0["commandID"] = 335; $0.removeValue(forKey: "commandName")
            $0["controllerType"] = "button"; $0["interactionMode"] = "direct"; $0["assignment"] = "deckD"
        })
        XCTAssertFalse(result.canOpen)
        XCTAssertTrue(result.diagnostics.contains { $0.code == "command.target" })
    }
    func testCanonicalNormalizationIsExplicitInReview() throws {
        let result = JSONImportService.review(try editRow { $0["ledBlend"] = true; $0["resolution"] = 42 })
        XCTAssertTrue(result.canWriteTSI)
        XCTAssertTrue(result.diagnostics.contains { $0.code == "writer.normalization" && $0.severity == .warning && $0.message.contains("resolution") })
    }
    func testRootVersionNormalizationShowsBeforeAndAfter() throws {
        let result = JSONImportService.review(try json { $0["tsiVersion"] = 123 })
        XCTAssertTrue(result.canWriteTSI)
        XCTAssertTrue(result.diagnostics.contains { $0.code == "writer.normalization" && $0.path == "$.tsiVersion" && $0.message.contains("123 → 0") })
    }
    func testMalformedJSONHasActionableSyntaxDiagnostic() {
        let result = JSONImportService.review(Data("{\"a\": 1,}".utf8))
        XCTAssertFalse(result.canOpen)
        XCTAssertNil(result.mappingFile)
        XCTAssertEqual(result.diagnostics.first?.code, "json.syntax")
        XCTAssertTrue(result.diagnostics.first?.message.contains("byte") == true)
    }
    func testMIDIIndependentRangeErrorsIdentifyExactPaths() throws {
        let data = try editRow { $0["midi"] = ["kind": "controlChange", "channel": 17, "number": 128] }
        let result = JSONImportService.review(data)
        XCTAssertFalse(result.canOpen)
        XCTAssertNil(result.mappingFile)
        XCTAssertEqual(Set(result.diagnostics.filter { $0.severity == .error }.map(\.path)),
            ["$.devices[0].mappings[0].midi.channel", "$.devices[0].mappings[0].midi.number"])
    }
    func testValidSourceFreeMappingIsWritable() throws {
        let result = JSONImportService.review(try json())
        XCTAssertTrue(result.canOpen, "\(result.diagnostics)")
        XCTAssertTrue(result.canWriteTSI)
        XCTAssertEqual(try TSIParser().parseDocument(TSIWriter().write(XCTUnwrap(result.mappingFile))).allMappings.first?.commandID, 100)
    }
    func testCommandNameConflictIsRejectedButOmittedNameRegenerates() throws {
        let conflict = JSONImportService.review(try editRow { $0["commandName"] = "Cue" })
        XCTAssertFalse(conflict.canOpen)
        XCTAssertTrue(conflict.diagnostics.contains { $0.code == "command.nameConflict" && $0.path.hasSuffix(".commandName") })
        let omitted = JSONImportService.review(try editRow { $0.removeValue(forKey: "commandName") })
        XCTAssertTrue(omitted.canOpen)
        XCTAssertEqual(omitted.mappingFile?.allMappings.first?.commandName, "Play/Pause")
    }
    func testUnknownNewCommandAndInvalidDirectionAreRejected() throws {
        let unknown = JSONImportService.review(try editRow { $0["commandID"] = 999999; $0.removeValue(forKey: "commandName") })
        XCTAssertFalse(unknown.canOpen)
        XCTAssertTrue(unknown.diagnostics.contains { $0.code == "command.unknown" })
        let direction = JSONImportService.review(try editRow { $0["ioType"] = "all" })
        XCTAssertFalse(direction.canOpen)
        XCTAssertTrue(direction.diagnostics.contains { $0.code == "command.direction" })
    }
    func testDuplicateIDsAreRejected() throws {
        let data = try json { object in
            var devices = object["devices"] as! [[String: Any]]
            var rows = devices[0]["mappings"] as! [[String: Any]]
            rows.append(rows[0]); devices[0]["mappings"] = rows; object["devices"] = devices
        }
        let result = JSONImportService.review(data)
        XCTAssertFalse(result.canOpen)
        XCTAssertTrue(result.diagnostics.contains { $0.code == "schema.duplicateID" })
    }
    func testOverlapIsAdvisory() throws {
        let data = try json { object in
            var devices = object["devices"] as! [[String: Any]]
            var rows = devices[0]["mappings"] as! [[String: Any]]
            var second = rows[0]; second["id"] = UUID().uuidString; rows.append(second)
            devices[0]["mappings"] = rows; object["devices"] = devices
        }
        let result = JSONImportService.review(data)
        XCTAssertTrue(result.canOpen)
        XCTAssertTrue(result.diagnostics.contains { $0.code == "mapping.overlap" && $0.severity == .warning })
    }
    func testComplexSourcePassesButUnsupportedEditIsInspectionOnly() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TSI/traktor-4.4.x-sanitized-complete.tsi")
        var file = try TSIParser().parseDocument(Data(contentsOf: url))
        let unchanged = JSONImportService.review(try SXMJSONCodec.encode(file))
        XCTAssertTrue(unchanged.canOpen, "\(unchanged.diagnostics.filter { $0.severity == .error })")
        XCTAssertTrue(unchanged.canWriteTSI)
        file.devices[0].mappings[0].comment = "edited"
        let edited = JSONImportService.review(try SXMJSONCodec.encode(file))
        XCTAssertTrue(edited.canOpen)
        XCTAssertFalse(edited.canWriteTSI)
        XCTAssertTrue(edited.diagnostics.contains { $0.code == "preservation.writeBlocked" })
    }
}
