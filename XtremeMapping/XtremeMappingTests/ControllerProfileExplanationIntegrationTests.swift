import XCTest
@testable import XtremeMapping

final class ControllerProfileExplanationIntegrationTests: XCTestCase {
    func testDocumentationOnlyProfileDoesNotInventControlNames() throws {
        let row = MappingEntry(commandID: 100, ioType: .input, midiChannel: 1, midiNote: 11)
        let device = Device(name: "F1", mappings: [row])
        var file = MappingFile(devices: [device])
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [],
            deviceProfiles: [.init(deviceID: device.id, configuration: .init(profileID: "native-instruments.traktor-kontrol-f1",
                version: "1.0.0", globalChannel: 1, layerMode: "documented", unitMap: "factory"))])
        let original = file
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "F1", revision: "partial")
        XCTAssertTrue(snapshot.rows[0].controls.isEmpty)
        XCTAssertTrue(snapshot.rows[0].limitations.contains { $0.contains("no physical-control addresses") })
        XCTAssertEqual(file, original)
    }

    func testFixedChannelProfileEvidenceReachesAssistantWithoutChangingRows() throws {
        let matched = MappingEntry(commandID: 100, ioType: .input, midiChannel: 1, midiNote: 11)
        let unrelated = MappingEntry(commandID: 100, ioType: .input, midiChannel: 15, midiNote: 11)
        let device = Device(name: "FLX4", mappings: [matched, unrelated])
        var file = MappingFile(devices: [device])
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [],
            deviceProfiles: [.init(deviceID: device.id, configuration: .init(profileID: "pioneer-dj.ddj-flx4",
                version: "1.0.0", globalChannel: 15, layerMode: "documented", unitMap: "factory"))])
        let original = file
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Controller integration", revision: "v2")
        XCTAssertTrue(snapshot.rows[0].controls.contains { $0.contains("PLAY/PAUSE") })
        XCTAssertTrue(snapshot.rows[0].sources.contains { $0.contains("https://") })
        XCTAssertFalse(snapshot.rows[1].controls.contains { $0.contains("PLAY/PAUSE") })
        XCTAssertEqual(file, original)
    }
}
