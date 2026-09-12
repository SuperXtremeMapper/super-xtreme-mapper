import XCTest
@testable import XtremeMapping

@MainActor
final class AssistantEditPlanTests: XCTestCase {
    private func fixture() -> MappingFile {
        MappingFile(devices: [Device(name: "Assistant Test Controller", inPort: "Test MIDI In", outPort: "Test MIDI Out", mappings: [MappingEntry(commandID: 100, comment: "one"), MappingEntry(commandID: 100, comment: "two"), MappingEntry(commandID: 100, comment: "three")])])
    }
    func testAtomicUpdateDuplicateDeleteAddAndUndoRedo() throws {
        let file = fixture(), d = file.devices[0], newID = UUID(), addedID = UUID()
        let doc = TraktorMappingDocument(mappingFile: file)
        let ops: [AssistantEditOperation] = [
            .init(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: .init(comment: "edited")),
            .init(kind: .duplicate, deviceID: d.id, rowID: d.mappings[1].id, newRowID: newID),
            .init(kind: .delete, deviceID: d.id, rowID: d.mappings[2].id),
            .init(kind: .add, deviceID: d.id, newRowID: addedID, patch: .init(commandID: 100, comment: "added"))]
        let plan = try AssistantEditPlan.prepare(operations: ops, file: file, revision: doc.explanationRevision)
        XCTAssertEqual(plan.changes.count, 4)
        XCTAssertEqual(plan.changes.first?.before, d.mappings[0])
        let undo = UndoManager(); undo.groupsByEvent = false
        undo.beginUndoGrouping()
        XCTAssertTrue(try plan.apply(document: doc, isLocked: false, undoManager: undo))
        undo.endUndoGrouping()
        let after = doc.mappingFile
        XCTAssertEqual(after.allMappings.map(\.id), [d.mappings[0].id, d.mappings[1].id, newID, addedID])
        undo.undo(); XCTAssertEqual(doc.mappingFile, file); XCTAssertFalse(undo.canUndo)
        undo.redo(); XCTAssertEqual(doc.mappingFile, after)
    }
    func testExactReorderAndInvalidAtomicTargets() throws {
        let file = fixture(), d = file.devices[0]
        let order = d.mappings.reversed().map(\.id)
        let doc = TraktorMappingDocument(mappingFile: file)
        let plan = try AssistantEditPlan.prepare(operations: [.init(kind: .reorder, deviceID: d.id, rowOrder: order)], file: file, revision: doc.explanationRevision)
        XCTAssertFalse(plan.isEmpty)
        XCTAssertTrue(try plan.apply(document: doc, isLocked: false, undoManager: nil))
        XCTAssertEqual(doc.mappingFile.allMappings.map(\.id), order)
        for ops: [AssistantEditOperation] in [
            [.init(kind: .reorder, deviceID: d.id, rowOrder: Array(order.dropLast()))],
            [.init(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: .init(comment: "x")), .init(kind: .delete, deviceID: d.id, rowID: d.mappings[0].id)],
            [.init(kind: .delete, deviceID: UUID(), rowID: d.mappings[0].id)],
            [.init(kind: .add, deviceID: d.id, newRowID: d.mappings[0].id, patch: .init(commandID: 100))]
        ] { XCTAssertThrowsError(try AssistantEditPlan.prepare(operations: ops, file: file, revision: "r")) }
        XCTAssertEqual(file.allMappings[0].comment, "one")
    }
    func testStaleMetadataRevisionSourceAndLock() throws {
        let file = fixture(), d = file.devices[0]
        let op = AssistantEditOperation(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: .init(comment: "x"))
        let doc = TraktorMappingDocument(mappingFile: file)
        let plan = try AssistantEditPlan.prepare(operations: [op], file: file, revision: doc.explanationRevision)
        XCTAssertThrowsError(try plan.apply(document: doc, isLocked: true, undoManager: nil))
        let wrongRevision = try AssistantEditPlan.prepare(operations: [op], file: file, revision: "old")
        XCTAssertThrowsError(try wrongRevision.apply(document: doc, isLocked: false, undoManager: nil))
        doc.mappingFile.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [])
        XCTAssertThrowsError(try plan.apply(document: doc, isLocked: false, undoManager: nil))
        XCTAssertEqual(doc.mappingFile.allMappings, file.allMappings)
        let parsed = try TSIParser().parseDocument(TSIWriter().write(file))
        let sourcedDoc = TraktorMappingDocument(mappingFile: parsed)
        let sourcedPlan = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: parsed.devices[0].id, rowID: parsed.allMappings[0].id, patch: .init(comment: "new"))], file: parsed, revision: sourcedDoc.explanationRevision)
        sourcedDoc.mappingFile.sourceEnvelope = nil
        XCTAssertThrowsError(try sourcedPlan.apply(document: sourcedDoc, isLocked: false, undoManager: nil))
    }
    func testNoOpMakesNoUndoAndUnchangedOpaqueRowsRemainExact() throws {
        var file = fixture()
        file.devices[0].mappings[1].rawMidiControlName = "vendor control"
        let d = file.devices[0], doc = TraktorMappingDocument(mappingFile: file), undo = UndoManager()
        let noop = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: .init(comment: "one"))], file: file, revision: doc.explanationRevision)
        XCTAssertTrue(noop.isEmpty)
        XCTAssertFalse(try noop.apply(document: doc, isLocked: false, undoManager: undo)); XCTAssertFalse(undo.canUndo)
        let plan = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: .init(comment: "changed"))], file: file, revision: doc.explanationRevision)
        XCTAssertTrue(try plan.apply(document: doc, isLocked: false, undoManager: nil))
        XCTAssertEqual(doc.mappingFile.allMappings[1], d.mappings[1])
    }
    func testDeleteCleansAnnotationsAndDuplicateDoesNotInventProvenance() throws {
        var file = fixture()
        let d = file.devices[0], copyID = UUID()
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [.init(mappingID: d.mappings[0].id, midi: SXMJSONMIDI(d.mappings[0].midiAssignment))])
        let doc = TraktorMappingDocument(mappingFile: file)
        let plan = try AssistantEditPlan.prepare(operations: [.init(kind: .delete, deviceID: d.id, rowID: d.mappings[0].id), .init(kind: .duplicate, deviceID: d.id, rowID: d.mappings[1].id, newRowID: copyID)], file: file, revision: doc.explanationRevision)
        XCTAssertTrue(try plan.apply(document: doc, isLocked: false, undoManager: nil))
        XCTAssertEqual(doc.mappingFile.interchangeMetadata?.localOverrides.count, 0)
        XCTAssertEqual(doc.mappingFile.interchangeMetadata?.physicalControls.count, 0)
    }
    func testExplicitMIDIEditDisclosesOpaqueLossAndConditionCanClear() throws {
        var file = fixture()
        file.devices[0].mappings[0].rawMidiControlName = "vendor control"
        file.devices[0].mappings[0].modifier1Condition = ModifierCondition(modifier: 1, value: 0)
        let d = file.devices[0], doc = TraktorMappingDocument(mappingFile: file)
        let patch = AssistantRowPatch(midi: SXMJSONMIDI(d.mappings[0].midiAssignment), clearModifier1Condition: true)
        let plan = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: patch)], file: file, revision: doc.explanationRevision)
        XCTAssertFalse(plan.warnings.isEmpty)
        XCTAssertNil(plan.changes.first?.after?.rawMidiControlName)
        XCTAssertNil(plan.changes.first?.after?.modifier1Condition)
    }
    func testCatalogueDirectionScalarAndUnknownFieldsReject() throws {
        let file = fixture(), d = file.devices[0]
        for patch in [AssistantRowPatch(commandID: 999999), .init(ioType: .all), .init(rotarySensitivity: -.infinity), .init(rotaryAcceleration: 2), .init(ledMinMidi: -1)] {
            XCTAssertThrowsError(try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: d.mappings[0].id, patch: patch)], file: file, revision: "r"))
        }
        for json in ["{\"comment\":\"x\",\"rawMidiBindingID\":3}", "{\"midi\":{\"kind\":\"note\",\"channel\":1,\"number\":2,\"extra\":true}}"] {
            XCTAssertThrowsError(try JSONDecoder().decode(AssistantRowPatch.self, from: Data(json.utf8)))
        }
        let json = "{\"kind\":\"delete\",\"deviceID\":\"\(d.id)\",\"rowID\":\"\(d.mappings[0].id)\",\"extra\":true}"
        XCTAssertThrowsError(try JSONDecoder().decode(AssistantEditOperation.self, from: Data(json.utf8)))
        XCTAssertThrowsError(try AssistantEditPlan.prepare(operations: Array(repeating: .init(kind: .delete, deviceID: d.id, rowID: d.mappings[0].id), count: 101), file: file, revision: "r"))
    }
    func testWarningsRetainDiagnosticPathAndAffectedRowIdentity() throws {
        var file = fixture()
        for index in 0...1 { file.devices[0].mappings[index].commandID = 999999 }
        let d = file.devices[0]
        let plan = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: d.mappings[2].id, patch: .init(comment: "review warnings"))], file: file, revision: "r")
        for index in 0...1 {
            XCTAssertTrue(plan.warnings.contains { $0.contains("$.devices[0].mappings[\(index)].commandID") && $0.contains(d.mappings[index].id.uuidString) })
        }
    }

    func testReorderRejectsMoreThanOneHundredAffectedRows() throws {
        var file = fixture()
        file.devices[0].mappings = (0..<101).map { MappingEntry(commandID: 100, comment: "row \($0)") }
        let d = file.devices[0]
        // Rotate rather than reverse: an odd reverse leaves its middle row unmoved.
        let rotated = Array(d.mappings.dropFirst().map(\.id)) + [d.mappings[0].id]
        XCTAssertThrowsError(try AssistantEditPlan.prepare(operations: [.init(kind: .reorder, deviceID: d.id, rowOrder: rotated)], file: file, revision: "r")) { error in
            XCTAssertTrue(error.localizedDescription.contains("100 affected rows"))
        }
        file.devices[0].mappings.removeLast()
        let hundred = file.devices[0]
        let accepted = try AssistantEditPlan.prepare(operations: [.init(kind: .reorder, deviceID: hundred.id, rowOrder: Array(hundred.mappings.reversed().map(\.id)))], file: file, revision: "r")
        XCTAssertEqual(accepted.changes.count, 100)
    }

    func testParsedNativeFixtureNoOpIsByteExact() throws {
        for name in ["traktor-4.4.x-sanitized-complete.tsi", "traktor-4.5.1-xone-k3-benchmark-05-core-safe.tsi"] {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TSI/" + name)
            let bytes = try Data(contentsOf: url)
            let file = try TSIParser().parseDocument(bytes)
            let d = try XCTUnwrap(file.devices.first), row = try XCTUnwrap(d.mappings.first)
            let doc = TraktorMappingDocument(mappingFile: file), undo = UndoManager()
            let plan = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: row.id, patch: .init(comment: row.comment))], file: file, revision: doc.explanationRevision)
            XCTAssertTrue(plan.isEmpty)
            XCTAssertFalse(try plan.apply(document: doc, isLocked: false, undoManager: undo))
            XCTAssertFalse(undo.canUndo)
            XCTAssertEqual(try TSIWriter().write(doc.mappingFile), bytes, name)
            XCTAssertEqual(doc.mappingFile.sourceEnvelope, file.sourceEnvelope)
        }
    }

    func testParsedNativeExceptionalCMADSurvivesNoOpAndCommentEdit() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TSI/traktor-4.5.1-xone-k3-benchmark-05-core-safe.tsi")
        let bytes = try Data(contentsOf: url)
        let source = try TSIParser().parseDocument(bytes)
        let encoded = try XCTUnwrap(source.sourceEnvelope?.controllerValues.first)
        var binary = try TSIParser().decodeBase64(encoded)
        let payload = try XCTUnwrap(source.allMappings.first?.importedCMAD?.payload)
        let range = try XCTUnwrap(binary.range(of: payload))
        var exceptionalPayload = payload
        exceptionalPayload.replaceSubrange(28..<32, with: [0x7F, 0xC0, 0x12, 0x34])
        binary.replaceSubrange(range, with: exceptionalPayload)
        let exceptionalBytes = Data(String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: encoded, with: binary.base64EncodedString()).utf8)
        let file = try TSIParser().parseDocument(exceptionalBytes)
        let d = file.devices[0], row = d.mappings[0]
        XCTAssertEqual(row.rotarySensitivity.bitPattern, 0x7FC0_1234)
        let doc = TraktorMappingDocument(mappingFile: file)
        let noop = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: row.id, patch: .init(comment: row.comment))], file: file, revision: doc.explanationRevision)
        XCTAssertFalse(try noop.apply(document: doc, isLocked: false, undoManager: nil))
        XCTAssertEqual(try TSIWriter().write(doc.mappingFile), exceptionalBytes)
        let edit = try AssistantEditPlan.prepare(operations: [.init(kind: .update, deviceID: d.id, rowID: row.id, patch: .init(comment: "Assistant native preservation"))], file: file, revision: doc.explanationRevision)
        XCTAssertTrue(try edit.apply(document: doc, isLocked: false, undoManager: nil))
        var expected = file
        expected.devices[0].mappings[0].comment = "Assistant native preservation"
        XCTAssertEqual(doc.mappingFile, expected)
        XCTAssertEqual(doc.mappingFile.sourceEnvelope, file.sourceEnvelope)
        XCTAssertEqual(doc.mappingFile.allMappings[0].importedCMAD, row.importedCMAD)
        let output = try TSIWriter().write(doc.mappingFile)
        XCTAssertEqual(output, try TSIWriter().write(expected))
        let reparsed = try TSIParser().parseDocument(output)
        XCTAssertEqual(reparsed.allMappings[0].comment, "Assistant native preservation")
        XCTAssertEqual(reparsed.allMappings[0].rotarySensitivity.bitPattern, 0x7FC0_1234)
        for index in d.mappings.indices.dropFirst() {
            XCTAssertEqual(reparsed.allMappings[index].importedCMAD?.payload, d.mappings[index].importedCMAD?.payload)
        }
    }

}
