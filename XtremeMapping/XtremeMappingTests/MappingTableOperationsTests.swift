import XCTest
@testable import XtremeMapping

@MainActor
final class MappingTableOperationsTests: XCTestCase {
    func testSharedMIDIIncludesEveryMatchingRowButSeparatesDeviceDirectionKindAndChannel() throws {
        var a = MappingEntry(commandID: 100)
        a.midiAssignment = try .note(channel: 1, number: 60)
        var b = MappingEntry(commandID: 201)
        b.midiAssignment = a.midiAssignment
        var cc = b.copyWithNewID(); cc.midiAssignment = try .controlChange(channel: 1, number: 60)
        var channel = b.copyWithNewID(); channel.midiAssignment = try .note(channel: 2, number: 60)
        var output = b.copyWithNewID(); output.ioType = .output
        let other = b.copyWithNewID()
        let file = MappingFile(devices: [Device(mappings: [a, b, cc, channel, output, MappingEntry()]), Device(mappings: [other])])
        XCTAssertEqual(MappingTableOperations.sharedMIDIIDs(in: file, selectedIDs: [a.id]), [a.id, b.id])
        XCTAssertTrue(MappingTableOperations.sharedMIDIIDs(in: file, selectedIDs: [cc.id]).isEmpty)
        XCTAssertTrue(MappingTableOperations.sharedMIDIIDs(in: file, selectedIDs: []).isEmpty)
    }

    func testMoveSelectionPreservesDocumentOrderAndRoundTrips() throws {
        let rows = [100, 201, 202, 203].map { (value: Int) in MappingEntry(commandID: value, comment: "Row \(value)") }
        var file = MappingFile(devices: [Device(name: "Order", mappings: rows)])
        XCTAssertTrue(MappingTableOperations.move([rows[3].id, rows[1].id], before: rows[0].id, in: &file))
        XCTAssertEqual(file.devices[0].mappings.map(\.id), [rows[1].id, rows[3].id, rows[0].id, rows[2].id])
        let reopened = try TSIParser().parseDocument(TSIWriter().write(file))
        XCTAssertEqual(reopened.devices[0].mappings.map(\.comment), ["Row 201", "Row 203", "Row 100", "Row 202"])
        let importedOrder = reopened.devices[0].mappings
        var imported = reopened
        XCTAssertTrue(MappingTableOperations.move([importedOrder[3].id], before: importedOrder[0].id, in: &imported))
        let saved = try TSIParser().parseDocument(TSIWriter().write(imported))
        XCTAssertEqual(saved.devices[0].mappings.map(\.comment), ["Row 202", "Row 201", "Row 203", "Row 100"])
    }

    func testMoveRejectsCrossDeviceStaleAndSelfTargetsWithoutMutation() {
        let rows = (0..<4).map { _ in MappingEntry(commandID: 100) }
        var file = MappingFile(devices: [Device(mappings: Array(rows.prefix(2))), Device(mappings: Array(rows.suffix(2)))])
        let original = file
        XCTAssertFalse(MappingTableOperations.move([rows[0].id], before: rows[2].id, in: &file))
        XCTAssertFalse(MappingTableOperations.move([rows[0].id, UUID()], before: rows[1].id, in: &file))
        XCTAssertFalse(MappingTableOperations.move([rows[0].id], before: rows[0].id, in: &file))
        XCTAssertEqual(file, original)
    }

    func testDragBoundaryAtNextDeviceMeansEndOfSourceDevice() {
        let rows = (0..<5).map { _ in MappingEntry(commandID: 100) }
        var file = MappingFile(devices: [Device(mappings: Array(rows.prefix(3))), Device(mappings: Array(rows.suffix(2)))])
        let originalSecond = file.devices[1]
        XCTAssertTrue(MappingTableOperations.moveAtBoundary([rows[0].id], before: rows[3].id, in: &file))
        XCTAssertEqual(file.devices[0].mappings.map(\.id), [rows[1].id, rows[2].id, rows[0].id])
        XCTAssertEqual(file.devices[1], originalSecond)
        let before = file
        XCTAssertFalse(MappingTableOperations.moveAtBoundary([rows[1].id], before: rows[4].id, in: &file))
        XCTAssertEqual(file, before)
    }

    func testMoveDownPreservesGroupOrderAndSupportsUndo() {
        let rows = (0..<5).map { _ in MappingEntry(commandID: 100) }
        let doc = TraktorMappingDocument()
        doc.mappingFile = MappingFile(devices: [Device(mappings: rows)])
        let original = doc.mappingFile
        let ids: Set<UUID> = [rows[1].id, rows[3].id]
        let undo = UndoManager(); undo.groupsByEvent = false
        undo.beginUndoGrouping()
        doc.performUndoableMutation(actionName: "Move Mappings", undoManager: undo) { file in
            MappingTableOperations.step(ids, down: true, in: &file)
        }
        undo.endUndoGrouping()
        XCTAssertEqual(doc.mappingFile.devices[0].mappings.map(\.id), [rows[0].id, rows[2].id, rows[4].id, rows[1].id, rows[3].id])
        undo.undo(); XCTAssertEqual(doc.mappingFile, original)
        var atEnd = original
        XCTAssertFalse(MappingTableOperations.step([rows[4].id], down: true, in: &atEnd))
    }
}
