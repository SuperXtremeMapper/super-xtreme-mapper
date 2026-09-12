import XCTest
import AppKit
@testable import XtremeMapping

final class ControllerProfileMetadataTests: XCTestCase {
    private func annotated(_ file: MappingFile, channel: Int = 16) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: SXMJSONCodec.encode(file)) as? [String: Any])
        object["schemaVersion"] = 2
        object["metadata"] = ["profileReferences": [], "physicalControls": [], "localOverrides": [],
            "deviceProfiles": file.devices.enumerated().map { index, device in
                ["deviceID": device.id.uuidString, "configuration": ["profileID": "unavailable.profile", "version": "99.7.1", "globalChannel": index == 0 ? channel : 1, "layerMode": "future-mode", "unitMap": "custom-2", "feedbackMode": "unknown", "overrides": []]] as [String: Any]
            }]
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testV2TwoDevicesAndUnknownPinsSurviveExactly() throws {
        let data = try annotated(MappingFile(devices: [Device(name: "One"), Device(name: "Two")]))
        let review = JSONImportService.review(data)
        XCTAssertTrue(review.canOpen, "\(review.diagnostics)")
        let file = try XCTUnwrap(review.mappingFile)
        let encoded = try SXMJSONCodec.encode(file)
        let before = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? NSDictionary)
        let after = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? NSDictionary)
        XCTAssertEqual(before["metadata"] as? NSDictionary, after["metadata"] as? NSDictionary)
        XCTAssertEqual(after["schemaVersion"] as? Int, 2)
        XCTAssertTrue(review.diagnostics.contains { $0.code == "profile.unresolved" && $0.severity == .warning })
    }

    func testV1RejectsV2MetadataAndV2RejectsNestedUnknownKeys() throws {
        let data = try annotated(MappingFile(devices: [Device(name: "One")]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["schemaVersion"] = 1
        XCTAssertThrowsError(try SXMJSONCodec.decode(JSONSerialization.data(withJSONObject: object)))
        object["schemaVersion"] = 2
        var metadata = try XCTUnwrap(object["metadata"] as? [String: Any])
        var profiles = try XCTUnwrap(metadata["deviceProfiles"] as? [[String: Any]])
        var configuration = try XCTUnwrap(profiles[0]["configuration"] as? [String: Any])
        configuration["channelTypo"] = 1
        profiles[0]["configuration"] = configuration
        metadata["deviceProfiles"] = profiles
        object["metadata"] = metadata
        XCTAssertThrowsError(try SXMJSONCodec.decode(JSONSerialization.data(withJSONObject: object)))
    }

    func testOutOfRangeConfigurationChannelsBlockImport() throws {
        for channel in [0, 17] {
            let review = JSONImportService.review(try annotated(MappingFile(devices: [Device(name: "One")]), channel: channel))
            XCTAssertFalse(review.canOpen)
            XCTAssertTrue(review.diagnostics.contains { $0.code == "metadata.channel" && $0.severity == .error })
        }
    }

    func testDanglingDeviceAndLegacyMappingReferencesWarnAndSurvive() throws {
        let data = try annotated(MappingFile(devices: [Device(name: "One")]))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["devices"] = []
        var metadata = try XCTUnwrap(object["metadata"] as? [String: Any])
        metadata["physicalControls"] = [["mappingID": UUID().uuidString, "profileID": "unknown", "controlID": "unknown"]]
        metadata["localOverrides"] = [["mappingID": UUID().uuidString, "midi": ["kind": "note", "channel": 1, "number": 60]]]
        object["metadata"] = metadata
        let review = JSONImportService.review(try JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(review.canOpen, "\(review.diagnostics)")
        XCTAssertEqual(review.diagnostics.filter { $0.code == "metadata.reference" && $0.severity == .warning }.count, 3)
        XCTAssertNotNil(review.mappingFile?.interchangeMetadata)
    }

    func testDuplicateDeviceConfigurationBlocksImport() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: annotated(MappingFile(devices: [Device(name: "One")]))) as? [String: Any])
        var metadata = try XCTUnwrap(object["metadata"] as? [String: Any])
        let profiles = try XCTUnwrap(metadata["deviceProfiles"] as? [[String: Any]])
        metadata["deviceProfiles"] = profiles + profiles
        object["metadata"] = metadata
        let review = JSONImportService.review(try JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(review.canOpen)
        XCTAssertTrue(review.diagnostics.contains { $0.code == "metadata.duplicateDevice" })
    }

    func testScopedOverridesRoundTripAndDuplicateIdentityBlocksImport() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: annotated(MappingFile(devices: [Device(name: "One")]))) as? [String: Any])
        var metadata = try XCTUnwrap(object["metadata"] as? [String: Any])
        var profiles = try XCTUnwrap(metadata["deviceProfiles"] as? [[String: Any]])
        var configuration = try XCTUnwrap(profiles[0]["configuration"] as? [String: Any])
        let override: [String: Any] = ["controlID": "future.control", "layerMode": "future-mode", "unitMap": "custom-2", "layer": "green", "direction": "send", "midi": ["kind": "controlChange", "channel": 16, "number": 127], "provenance": "midi-learn"]
        var differentContext = override
        differentContext["unitMap"] = "custom-3"
        configuration["overrides"] = [override, differentContext]
        profiles[0]["configuration"] = configuration
        metadata["deviceProfiles"] = profiles
        object["metadata"] = metadata
        let data = try JSONSerialization.data(withJSONObject: object)
        let review = JSONImportService.review(data)
        XCTAssertTrue(review.canOpen, "\(review.diagnostics)")
        let file = try XCTUnwrap(review.mappingFile)
        let exported = try XCTUnwrap(JSONSerialization.jsonObject(with: SXMJSONCodec.encode(file)) as? [String: Any])
        XCTAssertEqual(exported["metadata"] as? NSDictionary, metadata as NSDictionary)
        configuration["overrides"] = [override, override]
        profiles[0]["configuration"] = configuration
        metadata["deviceProfiles"] = profiles
        object["metadata"] = metadata
        let duplicate = JSONImportService.review(try JSONSerialization.data(withJSONObject: object))
        XCTAssertFalse(duplicate.canOpen)
        XCTAssertTrue(duplicate.diagnostics.contains { $0.code == "metadata.duplicateOverride" })
    }

    func testEmptyDeviceProfilesUsesV2AndLegacyMetadataUsesV1() throws {
        var file = MappingFile(devices: [Device(name: "One")])
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [])
        XCTAssertEqual(try SXMJSONCodec.document(from: SXMJSONCodec.encode(file)).schemaVersion, 1)
        file.interchangeMetadata?.deviceProfiles = []
        XCTAssertEqual(try SXMJSONCodec.document(from: SXMJSONCodec.encode(file)).schemaVersion, 2)
        XCTAssertEqual(try SXMJSONCodec.decode(SXMJSONCodec.encode(file)).interchangeMetadata?.deviceProfiles, [])
    }

    func testKnownProfileSettingsAndUnsupportedModesStayPinned() throws {
        var file = MappingFile(devices: [Device(name: "K2"), Device(name: "K3")])
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [], deviceProfiles: [
            .init(deviceID: file.devices[0].id, configuration: .init(profileID: "allen-heath.xone-k2", version: "1.0.0", globalChannel: 1, layerMode: "all-controls", unitMap: "factory")),
            .init(deviceID: file.devices[1].id, configuration: .init(profileID: "allen-heath.xone-k3", version: "1.0.0", globalChannel: 16, layerMode: "future", unitMap: "future", feedbackMode: "future"))])
        let review = JSONImportService.review(try SXMJSONCodec.encode(file))
        XCTAssertTrue(review.canOpen, "\(review.diagnostics)")
        XCTAssertEqual(review.mappingFile?.interchangeMetadata, file.interchangeMetadata)
        XCTAssertEqual(review.diagnostics.filter { $0.code == "profile.configurationUnresolved" }.count, 3)
    }

    @MainActor
    func testMetadataOnlyMutationUndoRedo() {
        let document = TraktorMappingDocument(mappingFile: MappingFile(devices: [Device(name: "One")]))
        let undo = UndoManager()
        undo.groupsByEvent = false
        let metadata = SXMJSONMetadata(profileReferences: [.init(profileID: "future", version: "9")], physicalControls: [], localOverrides: [])
        undo.beginUndoGrouping()
        document.performUndoableMutation(actionName: "Profile", undoManager: undo) { $0.interchangeMetadata = metadata }
        undo.endUndoGrouping()
        XCTAssertEqual(document.mappingFile.interchangeMetadata, metadata)
        XCTAssertTrue(undo.canUndo)
        undo.undo()
        XCTAssertNil(document.mappingFile.interchangeMetadata)
        XCTAssertTrue(undo.canRedo)
        undo.redo()
        XCTAssertEqual(document.mappingFile.interchangeMetadata, metadata)
        undo.removeAllActions()
        let noChange: Void? = document.performUndoableMutation(actionName: "Profile", undoManager: undo) { $0.interchangeMetadata = metadata }
        XCTAssertNil(noChange)
        XCTAssertFalse(undo.canUndo)
    }

    func testRepeatedMixedPinsRetainEveryUnresolvedReferenceDiagnostic() throws {
        let row = MappingEntry()
        var document = try SXMJSONCodec.document(from: SXMJSONCodec.encode(
            MappingFile(devices: [Device(name: "Controller", mappings: [row])])))
        let k1 = "allen-heath.xone-k1"
        let k2 = "allen-heath.xone-k2"
        let k3 = "allen-heath.xone-k3"
        let repeatedPins: [SXMJSONMetadata.Profile] = [
            .init(profileID: k1, version: "1.0.0"),
            .init(profileID: k1, version: "99.0.0"),
            .init(profileID: k2, version: "99.0.0"),
            .init(profileID: k3, version: nil),
            .init(profileID: "future", version: "1.0.0")
        ]
        var references: [SXMJSONMetadata.Profile] = []
        var controls: [SXMJSONMetadata.Control] = []
        var expected: [String] = []
        for index in 0..<200 {
            references += repeatedPins
            for offset in 1..<5 {
                expected.append("profile.unresolved:$.metadata.profileReferences[\(index * 5 + offset)]")
            }
            // A known version permits its known control even beside an unavailable pin.
            // Other model IDs must not borrow that control or their unpinned catalogue data.
            controls += [
                .init(mappingID: row.id, profileID: k1, controlID: "fader.1"),
                .init(mappingID: row.id, profileID: k1, controlID: "absent-control"),
                .init(mappingID: row.id, profileID: k2, controlID: "fader.1"),
                .init(mappingID: row.id, profileID: k3, controlID: "fader.1"),
                .init(mappingID: row.id, profileID: "future", controlID: "fader.1")
            ]
        }
        for index in controls.indices where index % 5 != 0 {
            expected.append("profile.controlUnresolved:$.metadata.physicalControls[\(index)].controlID")
        }
        document.metadata = SXMJSONMetadata(profileReferences: references, physicalControls: controls, localOverrides: [])
        let issues = ControllerProfileMetadataValidation.validate(document)
        XCTAssertEqual(issues.map { "\($0.code):\($0.path)" }, expected)
        XCTAssertTrue(issues.allSatisfy { $0.severity == .warning })
    }

    func testAnnotationPreservesEveryAcceptedTSIFixture() throws {
        let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/TSI")
        var count = 0
        for url in try FileManager.default.contentsOfDirectory(at: fixtures, includingPropertiesForKeys: nil) where url.pathExtension == "tsi" {
            let bytes = try Data(contentsOf: url)
            guard let parsed = try? TSIParser().parseDocument(bytes), (try? TSIWriter().write(parsed)) == bytes else { continue }
            let restored = try SXMJSONCodec.decode(annotated(parsed))
            XCTAssertEqual(try TSIWriter().write(restored), bytes, url.lastPathComponent)
            count += 1
        }
        XCTAssertGreaterThan(count, 0)
    }
}
