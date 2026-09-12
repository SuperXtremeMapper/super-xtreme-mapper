import XCTest
@testable import XtremeMapping

final class SXMJSONEditingTests: XCTestCase {
    private let opaqueEntry = #"<Entry Name="Vendor.OpaqueSetting" Type="1" Value="keep-exactly"/>"#

    private func source(deviceCount: Int = 1, includeOpaqueXML: Bool = true) throws -> MappingFile {
        let devices = (0..<deviceCount).map { index in
            Device(name: "Device \(index)", mappings: [
                MappingEntry(commandID: 100, assignment: .deckA, interactionMode: .toggle, midiCC: 12, comment: "First", controllerType: .button),
                MappingEntry(commandID: 206, assignment: .deckA, interactionMode: .hold, midiCC: 13, comment: "Second", controllerType: .button)
            ])
        }
        let canonical = try TSIWriter().write(MappingFile(devices: devices))
        let xml = String(decoding: canonical, as: UTF8.self)
            .replacingOccurrences(of: "</TraktorSettings>", with: (includeOpaqueXML ? opaqueEntry : "") + "</TraktorSettings>")
        XCTAssertEqual(xml.contains(opaqueEntry), includeOpaqueXML)
        return try TSIParser().parseDocument(Data(xml.utf8))
    }

    private func editedJSON(_ file: MappingFile, change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: SXMJSONCodec.encode(file)) as? [String: Any])
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func editFirstRow(_ file: MappingFile, change: (inout [String: Any]) -> Void) throws -> Data {
        try editedJSON(file) { object in
            var devices = object["devices"] as! [[String: Any]]
            var rows = devices[0]["mappings"] as! [[String: Any]]
            change(&rows[0])
            devices[0]["mappings"] = rows
            object["devices"] = devices
        }
    }

    func testExternalCommentAndReorderMatchDirectTSIEditWithoutLosingOpaqueXML() throws {
        let original = try source()
        let json = try editedJSON(original) { object in
            var devices = object["devices"] as! [[String: Any]]
            var rows = devices[0]["mappings"] as! [[String: Any]]
            rows[0]["comment"] = "External café 🎚 edit"
            rows.reverse()
            devices[0]["mappings"] = rows
            object["devices"] = devices
        }
        var expected = original
        expected.devices[0].mappings[0].comment = "External café 🎚 edit"
        expected.devices[0].mappings.reverse()
        let candidate = JSONImportService.review(json)
        XCTAssertTrue(candidate.canOpen, "\(candidate.diagnostics)")
        XCTAssertTrue(candidate.canWriteTSI, "\(candidate.diagnostics)")
        let restored = try XCTUnwrap(candidate.mappingFile)
        let output = try TSIWriter().write(restored)
        XCTAssertEqual(output, try TSIWriter().write(expected))
        XCTAssertTrue(String(decoding: output, as: UTF8.self).contains(opaqueEntry))
        XCTAssertEqual(restored.sourceEnvelope?.originalXML, original.sourceEnvelope?.originalXML)
        XCTAssertEqual(try TSIParser().parseDocument(output).allMappings.map(\.comment), ["Second", "External café 🎚 edit"])
    }

    func testUnsavedAddedAndRemovedRowsRetainOriginalBaselineAndWritableProjection() throws {
        let original = try source(includeOpaqueXML: false)
        var edited = original
        let removedID = edited.devices[0].mappings.removeFirst().id
        let newRow = MappingEntry(commandID: 100, assignment: .deckB, interactionMode: .toggle, midiCC: 40, comment: "New unsaved", controllerType: .button)
        edited.devices[0].mappings.append(newRow)
        let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(edited))
        XCTAssertEqual(restored.allMappings.map(\.id), edited.allMappings.map(\.id))
        XCTAssertEqual(restored.allMappings.last?.comment, "New unsaved")
        let envelope = try XCTUnwrap(restored.sourceEnvelope)
        XCTAssertEqual(envelope.originalXML, original.sourceEnvelope?.originalXML)
        XCTAssertTrue(envelope.baseline.devices[0].mappings.contains { $0.id == removedID })
        XCTAssertFalse(envelope.baseline.devices[0].mappings.contains { $0.id == newRow.id })
        XCTAssertFalse(envelope.baseline.matches(restored))
        let output = try TSIWriter().write(restored)
        XCTAssertEqual(output, try TSIWriter().write(edited))
        XCTAssertEqual(try TSIParser().parseDocument(output).allMappings.map(\.comment), ["Second", "New unsaved"])
    }

    func testAddedRowCannotSilentlyRegenerateOpaqueSource() throws {
        var edited = try source()
        edited.devices[0].mappings.append(MappingEntry(commandID: 100, assignment: .deckB,
            interactionMode: .toggle, midiCC: 40, comment: "Added", controllerType: .button))
        let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(edited))
        XCTAssertEqual(restored.sourceEnvelope?.originalXML, edited.sourceEnvelope?.originalXML)
        XCTAssertThrowsError(try TSIWriter().write(edited))
        XCTAssertThrowsError(try TSIWriter().write(restored))
        let review = JSONImportService.review(try SXMJSONCodec.encode(edited))
        XCTAssertTrue(review.canOpen)
        XCTAssertFalse(review.canWriteTSI)
        XCTAssertTrue(review.diagnostics.contains { $0.code == "preservation.writeBlocked" })
    }

    func testDamagedBase64MissingCorrespondenceAndDuplicateSourceIdentityAreRefused() throws {
        let original = try source()
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["originalXML"] = "invalid base64!" },
            { $0["devices"] = [] },
            { preservation in
                var devices = preservation["devices"] as! [[String: Any]]
                devices[0]["mappingIDs"] = []
                preservation["devices"] = devices
            },
            { preservation in
                var devices = preservation["devices"] as! [[String: Any]]
                let ids = devices[0]["mappingIDs"] as! [String]
                devices[0]["mappingIDs"] = [ids[0], ids[0]]
                preservation["devices"] = devices
            }
        ]
        for mutation in mutations {
            let data = try editedJSON(original) { object in
                var preservation = object["preservation"] as! [String: Any]
                mutation(&preservation)
                object["preservation"] = preservation
            }
            XCTAssertThrowsError(try SXMJSONCodec.decode(data)) { error in
                XCTAssertEqual((error as? SXMJSONIssue)?.code, "preservation.invalid")
            }
            XCTAssertFalse(JSONImportService.review(data).canOpen)
        }
    }

    func testMovingOriginalRowIdentityAcrossDevicesIsRefused() throws {
        let data = try editedJSON(source(deviceCount: 2)) { object in
            var devices = object["devices"] as! [[String: Any]]
            var firstRows = devices[0]["mappings"] as! [[String: Any]]
            var secondRows = devices[1]["mappings"] as! [[String: Any]]
            secondRows.append(firstRows.removeFirst())
            devices[0]["mappings"] = firstRows
            devices[1]["mappings"] = secondRows
            object["devices"] = devices
        }
        XCTAssertThrowsError(try SXMJSONCodec.decode(data)) { error in
            XCTAssertEqual((error as? SXMJSONIssue)?.code, "preservation.identity")
        }
        XCTAssertFalse(JSONImportService.review(data).canOpen)
    }

    func testExceptionalSourceFloatPayloadAndNegativeZeroSurviveJSONAndExactTSI() throws {
        let original = try sourceWithBinaryChanges { binary in
            let start = try XCTUnwrap(binary.range(of: Data("CMAD".utf8))).lowerBound + 8
            Self.replaceWord(&binary, at: start + 28, with: 0x7FC01234)
            Self.replaceWord(&binary, at: start + 44, with: 0x80000000)
        }
        XCTAssertEqual(original.allMappings[0].rotarySensitivity.bitPattern, 0x7FC01234)
        XCTAssertEqual(original.allMappings[0].setToValue.bitPattern, 0x80000000)
        let data = try SXMJSONCodec.encode(original)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let row = ((object["devices"] as! [[String: Any]])[0]["mappings"] as! [[String: Any]])[0]
        XCTAssertEqual((row["rotarySensitivity"] as? [String: UInt32])?["sourceBits"], 0x7FC01234)
        XCTAssertEqual((row["setToValue"] as? [String: UInt32])?["sourceBits"], 0x80000000)
        let restored = try SXMJSONCodec.decode(data)
        XCTAssertEqual(restored.allMappings[0].rotarySensitivity.bitPattern, 0x7FC01234)
        XCTAssertEqual(restored.allMappings[0].setToValue.bitPattern, 0x80000000)
        XCTAssertEqual(try TSIWriter().write(restored), original.sourceEnvelope?.originalXML)
    }

    func testNewNonfiniteValuesWithoutSourceAreRefused() throws {
        let file = MappingFile(devices: [Device(name: "New", mappings: [MappingEntry(commandID: 100)])])
        for bits: UInt32 in [0x7FC01234, 0x7F800000, 0xFF800000] {
            let data = try editFirstRow(file) { $0["rotarySensitivity"] = ["sourceBits": bits] }
            XCTAssertThrowsError(try SXMJSONCodec.decode(data)) { error in
                XCTAssertEqual((error as? SXMJSONIssue)?.code, "preservation.float")
            }
            XCTAssertFalse(JSONImportService.review(data).canOpen)
        }
    }

    func testUnknownSourceCommandIsRetainedButChangedUnknownCommandIsRejected() throws {
        let original = try sourceWithBinaryChanges { binary in
            let start = try XCTUnwrap(binary.range(of: Data("CMAI".utf8))).lowerBound + 8
            Self.replaceWord(&binary, at: start + 8, with: 999999)
        }
        XCTAssertEqual(original.allMappings[0].commandID, 999999)
        let unchanged = JSONImportService.review(try SXMJSONCodec.encode(original))
        XCTAssertTrue(unchanged.canOpen, "\(unchanged.diagnostics)")
        XCTAssertTrue(unchanged.canWriteTSI, "\(unchanged.diagnostics)")
        XCTAssertTrue(unchanged.diagnostics.contains { $0.code == "command.unknown" && $0.severity == .warning })
        let data = try editFirstRow(original) { row in
            row["commandID"] = 999998
            row.removeValue(forKey: "commandName")
        }
        let changed = JSONImportService.review(data)
        XCTAssertFalse(changed.canOpen)
        XCTAssertTrue(changed.diagnostics.contains { $0.code == "command.unknown" && $0.severity == .error })
    }

    func testProfileMetadataSurvivesRepeatedEncoding() throws {
        var original = try source()
        let mappingID = original.allMappings[0].id
        original.interchangeMetadata = SXMJSONMetadata(
            profileReferences: [.init(profileID: "vendor/controller", version: "1.2.3")],
            physicalControls: [.init(mappingID: mappingID, profileID: "vendor/controller", controlID: "play.button")],
            localOverrides: [.init(mappingID: mappingID, midi: SXMJSONMIDI(try .note(channel: 16, number: 127)))])
        let first = try SXMJSONCodec.encode(original)
        let restored = try SXMJSONCodec.decode(first)
        XCTAssertEqual(restored.interchangeMetadata, original.interchangeMetadata)
        XCTAssertEqual(try SXMJSONCodec.encode(restored), first)
    }

    func testExternalSourceFreeCommandEditProducesIntendedTSI() throws {
        let file = MappingFile(devices: [Device(name: "New", mappings: [
            MappingEntry(commandID: 100, assignment: .deckA, interactionMode: .hold, midiCC: 12, controllerType: .button)
        ])])
        for includeName in [true, false] {
            let data = try editFirstRow(file) { row in
                row["commandID"] = 206
                if includeName { row["commandName"] = TraktorCommands.descriptor(for: 206).name }
                else { row.removeValue(forKey: "commandName") }
            }
            let result = JSONImportService.review(data)
            XCTAssertTrue(result.canOpen, "\(result.diagnostics)")
            XCTAssertTrue(result.canWriteTSI, "\(result.diagnostics)")
            let restored = try XCTUnwrap(result.mappingFile)
            let tsi = try TSIWriter().write(restored)
            let reparsed = try TSIParser().parseDocument(tsi)
            if !includeName {
                let directory = URL(fileURLWithPath: "/tmp/sxm-json-demonstration", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try SXMJSONCodec.encode(file).write(to: directory.appendingPathComponent("original.sxm.json"), options: .atomic)
                try data.write(to: directory.appendingPathComponent("edited.sxm.json"), options: .atomic)
                try tsi.write(to: directory.appendingPathComponent("edited.tsi"), options: .atomic)
                print("JSON editing demonstration: \(directory.path)")
            }
            XCTAssertEqual(reparsed.allMappings.first?.commandID, 206)
            XCTAssertEqual(reparsed.allMappings.first?.midiAssignment, file.allMappings.first?.midiAssignment)
        }
    }

    private func sourceWithBinaryChanges(_ change: (inout Data) throws -> Void) throws -> MappingFile {
        let source = try source()
        let xml = try XCTUnwrap(source.sourceEnvelope?.originalXML)
        let encoded = try TSIParser.extractControllerData(from: xml)
        var binary = try TSIParser().decodeBase64(encoded)
        try change(&binary)
        let altered = "<NIXML><TraktorSettings><Entry Name=\"DeviceIO.Config.Controller\" Type=\"3\" Value=\"\(binary.base64EncodedString())\"/>\(opaqueEntry)</TraktorSettings></NIXML>"
        return try TSIParser().parseDocument(Data(altered.utf8))
    }

    private static func replaceWord(_ data: inout Data, at offset: Int, with word: UInt32) {
        var bigEndian = word.bigEndian
        let bytes = Data(bytes: &bigEndian, count: 4)
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }
}
