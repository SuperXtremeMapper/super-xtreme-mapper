import XCTest
@testable import XtremeMapping

@MainActor
final class ControllerProfileWorkflowTests: XCTestCase {
    private func configuration() -> ControllerConfiguration {
        ControllerConfiguration(profileID: "allen-heath.xone-k2", version: "1.0.0", globalChannel: 15,
                                layerMode: "all-controls", unitMap: "factory")
    }

    func testApplyChangesOnlySelectedDeviceMetadataAndOneUndoRestoresIt() throws {
        let a = Device(name: "A", mappings: [MappingEntry(commandID: 100, midiChannel: 15, midiCC: 60)])
        let b = Device(name: "B")
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [a, b]))
        let undo = UndoManager()
        undo.groupsByEvent = false
        undo.beginUndoGrouping()
        try document.performUndoableMutation(actionName: "Controller Profile", undoManager: undo) { file in
            try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: a.id,
                expectedMetadata: nil, isLocked: false, to: &file)
        }
        undo.endUndoGrouping()
        XCTAssertEqual(document.mappingFile.devices, [a,b])
        XCTAssertEqual(document.mappingFile.interchangeMetadata?.deviceProfiles?.map(\.deviceID), [a.id])
        XCTAssertTrue(document.isDirty)
        undo.undo()
        XCTAssertNil(document.mappingFile.interchangeMetadata)
        undo.redo()
        XCTAssertEqual(document.mappingFile.interchangeMetadata?.deviceProfiles?.first?.configuration, configuration())
    }

    func testNoProfileAndIdenticalSettingsDoNotCreateMetadataChanges() throws {
        var file = MappingFile(devices: [Device(name: "A")])
        let id = file.devices[0].id
        try ControllerProfileWorkflow.apply(configuration: nil, deviceID: id, expectedMetadata: nil, isLocked: false, to: &file)
        XCTAssertNil(file.interchangeMetadata)
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: id, expectedMetadata: nil, isLocked: false, to: &file)
        let snapshot = file.interchangeMetadata
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: id, expectedMetadata: snapshot, isLocked: false, to: &file)
        XCTAssertEqual(file.interchangeMetadata, snapshot)
    }

    func testLockedStaleAndRemovedDeviceRejectAtomically() throws {
        var file = MappingFile(devices: [Device(name: "A")])
        let id = file.devices[0].id
        XCTAssertThrowsError(try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: id,
             expectedMetadata: nil, isLocked: true, to: &file))
        XCTAssertNil(file.interchangeMetadata)
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: id, expectedMetadata: nil, isLocked: false, to: &file)
        let before = file.interchangeMetadata
        XCTAssertThrowsError(try ControllerProfileWorkflow.apply(configuration: nil, deviceID: id,
             expectedMetadata: nil, isLocked: false, to: &file))
        XCTAssertEqual(file.interchangeMetadata, before)
        file.devices.removeAll()
        XCTAssertThrowsError(try ControllerProfileWorkflow.apply(configuration: nil, deviceID: id,
             expectedMetadata: before, isLocked: false, to: &file))
        XCTAssertEqual(file.interchangeMetadata, before)
    }

    func testOverrideIsDraftOnlyAndReplacesOnlySameContext() throws {
        var draft = configuration()
        let midi = try MIDIAssignment.controlChange(channel: 7, number: 99)
        try ControllerProfileWorkflow.setOverride(controlID: "fader.1", layer: .green, direction: .send,
             midi: midi, provenance: .midiLearn, in: &draft)
        try ControllerProfileWorkflow.setOverride(controlID: "fader.1", layer: .amber, direction: .send,
             midi: midi, provenance: .userSupplied, in: &draft)
        try ControllerProfileWorkflow.setOverride(controlID: "fader.1", layer: .green, direction: .send,
             midi: .controlChange(channel: 8, number: 60), provenance: .userSupplied, in: &draft)
        XCTAssertEqual(draft.overrides.count, 2)
        XCTAssertEqual(draft.overrides.first { $0.layer == .green }?.midi.channel, 8)
        XCTAssertThrowsError(try ControllerProfileWorkflow.setOverride(controlID: "fader.1", layer: .green,
            direction: .send, midi: .unassigned(channel: 1), provenance: .userSupplied, in: &draft))
        XCTAssertEqual(draft.overrides.count, 2)
    }

    func testRemovingOneProfileRetainsOtherDeviceAndLegacyAnnotations() throws {
        let a = Device(name: "A"), b = Device(name: "B")
        var file = MappingFile(devices: [a,b])
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: a.id, expectedMetadata: nil, isLocked: false, to: &file)
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: b.id, expectedMetadata: file.interchangeMetadata, isLocked: false, to: &file)
        let legacy = file.interchangeMetadata?.profileReferences
        try ControllerProfileWorkflow.apply(configuration: nil, deviceID: a.id, expectedMetadata: file.interchangeMetadata, isLocked: false, to: &file)
        XCTAssertEqual(file.interchangeMetadata?.deviceProfiles?.map(\.deviceID), [b.id])
        XCTAssertEqual(file.interchangeMetadata?.profileReferences, legacy)
    }
    func testInvalidConfigurationRejectsWithoutChangingExistingMetadata() throws {
        let device = Device(name: "A")
        var file = MappingFile(devices: [device])
        let legacy = SXMJSONMetadata(profileReferences: [.init(profileID: "unknown.future", version: "42")],
                                    physicalControls: [], localOverrides: [])
        file.interchangeMetadata = legacy
        var invalid = configuration()
        invalid.globalChannel = 17
        XCTAssertThrowsError(try ControllerProfileWorkflow.apply(configuration: invalid, deviceID: device.id,
            expectedMetadata: legacy, isLocked: false, to: &file))
        XCTAssertEqual(file.interchangeMetadata, legacy)
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: device.id,
            expectedMetadata: legacy, isLocked: false, to: &file)
        XCTAssertEqual(file.interchangeMetadata?.profileReferences.first, legacy.profileReferences.first)
        XCTAssertEqual(file.interchangeMetadata?.profileReferences.count, 2)
        let applied = file.interchangeMetadata
        try ControllerProfileWorkflow.apply(configuration: configuration(), deviceID: device.id,
            expectedMetadata: applied, isLocked: false, to: &file)
        XCTAssertEqual(file.interchangeMetadata?.profileReferences.count, 2)
    }

    func testOverridesRemainScopedAcrossModesMapsAndDirections() throws {
        var draft = configuration()
        let midi = try MIDIAssignment.note(channel: 3, number: 42)
        try ControllerProfileWorkflow.setOverride(controlID: "button.1", layer: .green, direction: .send,
            midi: midi, provenance: .userSupplied, in: &draft)
        draft.unitMap = "custom"
        try ControllerProfileWorkflow.setOverride(controlID: "button.1", layer: .green, direction: .send,
            midi: midi, provenance: .midiLearn, in: &draft)
        draft.layerMode = "none"
        try ControllerProfileWorkflow.setOverride(controlID: "button.1", layer: .green, direction: .send,
            midi: midi, provenance: .midiLearn, in: &draft)
        try ControllerProfileWorkflow.setOverride(controlID: "button.1", layer: .green, direction: .receive,
            midi: midi, provenance: .userSupplied, in: &draft)
        XCTAssertEqual(draft.overrides.count, 4)
        XCTAssertEqual(draft.overrides.first?.unitMap, "factory")
        XCTAssertEqual(draft.overrides.first?.provenance, .userSupplied)
    }

}
