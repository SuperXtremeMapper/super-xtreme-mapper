import AppKit
import XCTest
@testable import XtremeMapping

@MainActor
final class DocumentUndoFallbackTests: XCTestCase {
    func testMenuMutationWithoutEnvironmentManagerUndoesOnlyRowsAndPreservesProfile() throws {
        let row = MappingEntry(commandID: 100, midiChannel: 15, midiCC: 60)
        let device = Device(name: "Controller", mappings: [row])
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let backing = NSDocument()
        document.backingDocument = backing
        let undo = try XCTUnwrap(backing.undoManager)
        undo.groupsByEvent = false
        let configuration = ControllerConfiguration(profileID: "allen-heath.xone-k2", version: "1.0.0",
            globalChannel: 15, layerMode: "all-controls", unitMap: "factory")

        undo.beginUndoGrouping()
        try document.performUndoableMutation(actionName: "Controller Profile", undoManager: undo) { file in
            try ControllerProfileWorkflow.apply(configuration: configuration, deviceID: device.id,
                expectedMetadata: nil, isLocked: false, to: &file)
        }
        undo.endUndoGrouping()
        let profileMetadata = document.mappingFile.interchangeMetadata
        undo.beginUndoGrouping()
        document.performUndoableMutation(actionName: "Duplicate Mappings", undoManager: nil) { file in
            MappingTransferService.duplicateSelection([row.id], in: &file)
        }
        undo.endUndoGrouping()
        XCTAssertEqual(document.mappingFile.devices[0].mappings.count, 2)
        XCTAssertEqual(undo.undoActionName, "Duplicate Mappings")

        undo.undo()
        XCTAssertEqual(document.mappingFile.devices[0].mappings.count, 1)
        XCTAssertEqual(document.mappingFile.interchangeMetadata, profileMetadata)
        undo.redo()
        XCTAssertEqual(document.mappingFile.devices[0].mappings.count, 2)
        XCTAssertEqual(document.mappingFile.interchangeMetadata, profileMetadata)
        undo.undo()
        undo.undo()
        XCTAssertEqual(document.mappingFile.devices[0].mappings.count, 1)
        XCTAssertNil(document.mappingFile.interchangeMetadata)
        XCTAssertFalse(backing.isDocumentEdited)
    }

    func testExplicitManagerTakesPrecedenceOverBackingDocumentManager() throws {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "A")]))
        let backing = NSDocument()
        document.backingDocument = backing
        let nativeUndo = try XCTUnwrap(backing.undoManager)
        let explicitUndo = UndoManager()
        explicitUndo.groupsByEvent = false
        explicitUndo.beginUndoGrouping()
        document.performUndoableMutation(actionName: "Rename", undoManager: explicitUndo) { file in
            file.devices[0].name = "B"
        }
        explicitUndo.endUndoGrouping()
        XCTAssertTrue(explicitUndo.canUndo)
        XCTAssertFalse(nativeUndo.canUndo)
        explicitUndo.undo()
        XCTAssertEqual(document.mappingFile.devices[0].name, "A")
    }
}
