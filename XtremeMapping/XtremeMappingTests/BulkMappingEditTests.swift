import XCTest
@testable import XtremeMapping

@MainActor
final class BulkMappingEditTests: XCTestCase {
    func testReplacementIsLiteralScopedAndCaseAware() throws {
        let a = MappingEntry(commandID: 100, comment: "Deck A / deck A / $1")
        let b = MappingEntry(commandID: 100, comment: "Deck A")
        let file = MappingFile(devices: [Device(mappings: [a, b])])
        let sensitive = try BulkMappingEditPlan.comments(in: file, selectedIDs: [a.id], find: "Deck A", replacement: "Deck B", matchCase: true)
        XCTAssertEqual(sensitive.changes.first?.after.comment, "Deck B / deck A / $1")
        let plan = try BulkMappingEditPlan.comments(in: file, selectedIDs: [a.id], find: "deck a", replacement: "$2", matchCase: false)
        XCTAssertEqual(plan.changes.count, 1)
        var result = file
        try plan.apply(to: &result)
        XCTAssertEqual(result.allMappings[0].comment, "$2 / $2 / $1")
        XCTAssertEqual(result.allMappings[1], b)
        XCTAssertTrue(try BulkMappingEditPlan.comments(in: file, selectedIDs: [a.id], find: "", replacement: "x", matchCase: true).changes.isEmpty)
    }

    func testStaleSelectionAndLockedApplicationCannotMutate() throws {
        let a = MappingEntry(commandID: 100, comment: "before")
        let file = MappingFile(devices: [Device(mappings: [a])])
        let plan = try BulkMappingEditPlan.comments(in: file, selectedIDs: [a.id], find: "before", replacement: "after", matchCase: true)
        let document = TraktorMappingDocument(mappingFile: file)
        XCTAssertFalse(try plan.apply(document: document, isLocked: true, undoManager: nil))
        XCTAssertEqual(document.mappingFile, file)
        document.mappingFile.devices[0].mappings[0].comment = "concurrent edit"
        let changed = document.mappingFile
        XCTAssertThrowsError(try plan.apply(document: document, isLocked: false, undoManager: nil))
        XCTAssertEqual(document.mappingFile, changed)
        XCTAssertThrowsError(try BulkMappingEditPlan.comments(in: file, selectedIDs: [UUID()], find: "before", replacement: "after", matchCase: true))
    }

    func testCompatibleCommandPreservesEveryOtherFieldAndIsOneUndoStep() throws {
        var a = MappingEntry.fullFieldSentinel
        a.commandID = 2333
        a.ioType = .output
        let b = MappingEntry.output(commandID: 2334)
        let file = MappingFile(devices: [Device(mappings: [a, b])])
        let plan = try BulkMappingEditPlan.command(in: file, selectedIDs: [a.id, b.id], commandID: 2340)
        let document = TraktorMappingDocument(mappingFile: file)
        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        XCTAssertTrue(try plan.apply(document: document, isLocked: false, undoManager: undo))
        undo.endUndoGrouping()
        var expected = a
        expected.commandID = 2340
        XCTAssertEqual(document.mappingFile.allMappings[0], expected)
        XCTAssertEqual(document.mappingFile.allMappings[1].commandID, 2340)
        undo.undo()
        XCTAssertEqual(document.mappingFile, file)
        undo.redo()
        XCTAssertEqual(document.mappingFile.allMappings[0], expected)
        XCTAssertThrowsError(try BulkMappingEditPlan.command(in: file, selectedIDs: [a.id], commandID: 100))
        var mixed = file
        mixed.devices[0].mappings[1].ioType = .input
        XCTAssertThrowsError(try BulkMappingEditPlan.command(in: mixed, selectedIDs: [a.id, b.id], commandID: 2340))
    }

    func testCompatibleCommandKeepsOpaqueImportedCMADBytes() throws {
        var row = MappingEntry.output(commandID: 2333)
        var payload = try TSIWriter().preservingCMADPayload(for: row)
        for offset in [12, 36, 40, 44] {
            payload.replaceSubrange(offset..<(offset + 4), with: [0x12, 0x34, 0x56, 0x78])
        }
        row.importedCMAD = try XCTUnwrap(ImportedCMAD(payload: payload, semanticAtImport: row))
        var file = MappingFile(devices: [Device(mappings: [row])])
        try BulkMappingEditPlan.command(in: file, selectedIDs: [row.id], commandID: 2340).apply(to: &file)
        XCTAssertEqual(try TSIWriter().preservingCMADPayload(for: file.allMappings[0]), payload)
    }

    func testImportedHotcueCommandEditRetainsProvenanceAndRoundtrips() throws {
        var seed = MappingEntry.output(commandID: 2333)
        seed.midiAssignment = try .note(channel: 4, number: 73)
        seed.comment = "cue LEDs"
        seed.modifier1Condition = ModifierCondition(modifier: 2334, value: 1, target: .deckB)
        seed.modifier2Condition = ModifierCondition(modifier: 100, value: 1, target: .deckA)
        seed.ledMinRangeData = 1
        seed.ledMaxRangeData = 4
        seed.ledMinMidi = 12
        seed.ledMaxMidi = 99
        seed.ledBlend = true
        seed.ledInvert = true
        var file = try TSIParser().parseDocument(TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: [seed])])))
        let source = file.sourceEnvelope
        let row = try XCTUnwrap(file.allMappings.first { $0.ioType == .output && $0.commandID == 2333 })
        let plan = try BulkMappingEditPlan.command(in: file, selectedIDs: [row.id], commandID: row.commandID == 2340 ? 2333 : 2340)
        try plan.apply(to: &file)
        XCTAssertEqual(file.sourceEnvelope, source)
        let reopened = try TSIParser().parseDocument(TSIWriter().write(file))
        let edited = try XCTUnwrap(file.allMappings.first { $0.id == row.id })
        let index = try XCTUnwrap(file.allMappings.firstIndex { $0.id == row.id })
        let saved = reopened.allMappings[index]
        XCTAssertEqual(saved.commandID, edited.commandID)
        XCTAssertEqual(saved.midiAssignment, row.midiAssignment)
        XCTAssertEqual(saved.comment, row.comment)
        XCTAssertEqual(saved.modifier1Condition, row.modifier1Condition)
        XCTAssertEqual(saved.modifier2Condition, row.modifier2Condition)
        XCTAssertEqual(saved.ledMinRangeData, row.ledMinRangeData)
        XCTAssertEqual(saved.ledMaxRangeData, row.ledMaxRangeData)
        XCTAssertEqual(saved.ledMinMidi, row.ledMinMidi)
        XCTAssertEqual(saved.ledMaxMidi, row.ledMaxMidi)
        XCTAssertEqual(saved.ledBlend, row.ledBlend)
        XCTAssertEqual(saved.ledInvert, row.ledInvert)
        XCTAssertEqual(saved.importedCMAD?.optionalBytes, row.importedCMAD?.optionalBytes)
    }
}
