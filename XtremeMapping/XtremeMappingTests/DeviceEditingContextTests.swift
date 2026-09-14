import XCTest
@testable import XtremeMapping

@MainActor
final class DeviceEditingContextTests: XCTestCase {
    func testPortUndoClearsNewPhysicalEndpointBinding() throws {
        let device = Device(name: "Generic MIDI", inPort: "Left")
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        let undo = UndoManager()
        undo.groupsByEvent = false
        doc.midiSourceIDs[device.id] = 11
        undo.beginUndoGrouping()
        doc.performUndoableMutation(actionName: "Change input", undoManager: undo) { file in
            file.devices[0].inPort = "Right"
        }
        undo.endUndoGrouping()
        doc.midiSourceIDs[device.id] = 22
        undo.undo()
        XCTAssertEqual(doc.mappingFile.devices[0].inPort, "Left")
        XCTAssertNil(doc.midiSourceIDs[device.id], "Undo must not keep capturing from Right")
    }

    func testMappingEditKeepsExplicitEndpointBinding() {
        let device = Device(name: "Generic MIDI", inPort: "Left")
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
        doc.midiSourceIDs[device.id] = 11
        doc.mappingFile.devices[0].mappings.append(MappingEntry(commandID: 100))
        XCTAssertEqual(doc.midiSourceIDs[device.id], 11)
    }

    func testExplicitDeviceCanReceiveMappingsWhileEmpty() throws {
        let row = MappingEntry(commandID: 100)
        let first = Device(name: "First", mappings: [row])
        let second = Device(name: "Second")
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [first, second]))
        doc.activeDeviceID = second.id
        XCTAssertEqual(try doc.mappingDestination(selectedIDs: [row.id]), second.id)
    }

    func testAllDevicesRequiresUnambiguousDestination() throws {
        let row = MappingEntry(commandID: 100)
        let first = Device(name: "First", mappings: [row])
        let second = Device(name: "Second")
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [first, second]))
        XCTAssertThrowsError(try doc.mappingDestination(selectedIDs: []))
        XCTAssertEqual(try doc.mappingDestination(selectedIDs: [row.id]), first.id)
        XCTAssertThrowsError(try doc.mappingDestination(selectedIDs: [row.id, UUID()]))
    }

    func testStaleExplicitDestinationNeverFallsBackToSoleDevice() {
        let doc = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "First")]))
        doc.activeDeviceID = UUID()
        XCTAssertThrowsError(try doc.mappingDestination(selectedIDs: []))
    }

    func testEmptyAndSingleDeviceDefaults() throws {
        let doc = TraktorMappingDocument()
        XCTAssertNil(try doc.mappingDestination(selectedIDs: []))
        let device = Device(name: "First")
        doc.mappingFile.devices = [device]
        XCTAssertEqual(try doc.mappingDestination(selectedIDs: []), device.id)
        XCTAssertFalse(doc.isDirty)
        doc.activeDeviceID = device.id
        XCTAssertFalse(doc.isDirty, "Device selection is session state, not a file edit")
    }
}
