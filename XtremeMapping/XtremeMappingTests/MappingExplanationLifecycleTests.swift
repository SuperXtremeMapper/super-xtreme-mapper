import XCTest
@testable import XtremeMapping

@MainActor
final class MappingExplanationLifecycleTests: XCTestCase {
    func testReadingFactsAndExportingGuideLeavesDocumentUntouched() throws {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [
            Device(name: "Read only", mappings: [MappingEntry(commandID: 100)])
        ]))
        let before = document.mappingFile
        let revision = document.explanationRevision
        let facts = try MappingExplanationSnapshot.build(file: before, title: "Test", revision: revision)
        let guide = try MappingReferenceGuide.build(snapshot: facts)
        XCTAssertFalse(guide.markdown.isEmpty)
        XCTAssertFalse(guide.plainText.isEmpty)
        XCTAssertEqual(document.mappingFile, before)
        XCTAssertEqual(document.mappingFile.interchangeMetadata, before.interchangeMetadata)
        XCTAssertEqual(document.explanationRevision, revision)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(document.hasPendingDirty)
    }

    func testRevisionsTrackRowsMetadataAndUndoWithoutChangingReadState() {
        let row = MappingEntry(commandID: 100)
        let device = Device(name: "Test", mappings: [row])
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let other = TraktorMappingDocument(mappingFile: document.mappingFile)
        let initial = document.explanationRevision
        XCTAssertNotEqual(initial, other.explanationRevision)
        XCTAssertFalse(document.isDirty)
        XCTAssertEqual(initial, document.explanationRevision)
        document.mappingFile.devices[0].mappings[0].comment = "changed"
        let edited = document.explanationRevision
        XCTAssertNotEqual(initial, edited)

        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        document.performUndoableMutation(actionName: "Profile", undoManager: undo) { file in
            file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [])
        }
        undo.endUndoGrouping()
        let annotated = document.explanationRevision
        XCTAssertNotEqual(edited, annotated)
        undo.undo()
        XCTAssertNotEqual(annotated, document.explanationRevision)
        XCTAssertNotEqual(edited, document.explanationRevision, "Undo invalidates old answer context even when content returns")
        XCTAssertNil(document.mappingFile.interchangeMetadata)
        XCTAssertEqual(document.mappingFile.devices[0].mappings[0].comment, "changed")
    }
}
