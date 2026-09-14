import XCTest
@testable import XtremeMapping

@MainActor
final class DeviceSidebarTests: XCTestCase {
    func testAddFromSidebarSelectsNewEmptyDeviceAndKeepsExistingMappings() throws {
        let row = MappingEntry(commandID: 100)
        let original = Device(name: "Generic MIDI", comment: "MIDI Device 1", mappings: [row])
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [original]))
        let added = try XCTUnwrap(DeviceSidebarActions.addDevice(to: document, undoManager: nil))
        XCTAssertEqual(document.activeDeviceID, added)
        XCTAssertEqual(document.mappingFile.devices[0], original)
        XCTAssertEqual(document.mappingFile.devices[1].comment, "MIDI Device 2")
        XCTAssertTrue(document.mappingFile.devices[1].mappings.isEmpty)
        XCTAssertEqual(try document.mappingDestination(selectedIDs: []), added)
    }

    func testAddDoesNotReuseAnExistingLabelAfterDeletion() throws {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [
            Device(name: "Generic MIDI", comment: "MIDI Device 2")
        ]))
        _ = try DeviceSidebarActions.addDevice(to: document, undoManager: nil)
        XCTAssertEqual(Set(document.mappingFile.devices.map(\.displayName)).count, 2)
    }

    func testStaleDeviceCannotRetargetControllerChooser() {
        let original = Device(name: "Generic MIDI")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [original]))
        document.activeDeviceID = original.id
        XCTAssertFalse(DeviceSidebarActions.selectDevice(UUID(), in: document))
        XCTAssertEqual(document.activeDeviceID, original.id)
        XCTAssertTrue(DeviceSidebarActions.selectDevice(nil, in: document))
        XCTAssertNil(document.activeDeviceID)
    }

    func testConnectionStatusUsesExplicitEndpointWhenNamesMatch() {
        let device = Device(name: "Generic MIDI", inPort: "Port 1")
        let sources = [MIDIEndpointIdentity(uniqueID: 11, name: "Port 1"), MIDIEndpointIdentity(uniqueID: 22, name: "Port 1")]
        XCTAssertEqual(DeviceSidebarPresentation.inputStatus(device: device, sourceID: nil, sources: sources), "Choose an input")
        XCTAssertEqual(DeviceSidebarPresentation.inputStatus(device: device, sourceID: 22, sources: sources), "Connected")
        XCTAssertEqual(DeviceSidebarPresentation.inputStatus(device: device, sourceID: 22, sources: [sources[0]]), "Offline")
    }

    func testUnconfiguredDeviceIsNotReportedAsConnected() {
        let device = Device(name: "Generic MIDI")
        let sources = [MIDIEndpointIdentity(uniqueID: 11, name: "Port 1")]
        XCTAssertEqual(DeviceSidebarPresentation.inputStatus(device: device, sourceID: nil, sources: sources), "Input not set")
    }
}
