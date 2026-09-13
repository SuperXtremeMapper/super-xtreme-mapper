import XCTest
@testable import XtremeMapping

final class ControllerDocumentationOnlyTests: XCTestCase {
    private func object(state: String? = "documentationOnly") -> [String: Any] {
        var value: [String: Any] = ["schemaVersion": 2, "id": "test.documents", "version": "1.0.0", "manufacturer": "Test", "model": "Documented device", "defaultChannel": 1,
            "sources": [["id": "manual", "url": "https://example.com/manual", "revision": "1", "sha256": String(repeating: "a", count: 64)]],
            "evidence": [["id": "e1", "sourceID": "manual", "locator": "Page 4: MIDI mode", "verification": "manufacturer-documented"]],
            "modes": [["id": "documented", "name": "Documented settings", "layeredGroups": [], "softPickup": false, "evidence": ["e1"]]],
            "unitMaps": [["id": "factory", "usesFactoryBindings": true, "evidence": ["e1"]]], "controls": [],
            "limitations": [["message": "No numeric address map is established.", "evidence": ["e1"]]], "configurationEvidence": ["e1"],
            "coverageNotes": ["MIDI mode is documented; addresses require a template or MIDI Learn."]]
        value["coverageState"] = state
        return value
    }
    private func library(_ object: [String: Any]) throws -> ControllerProfileLibrary {
        try ControllerProfileLibrary(resources: [.init(name: "documents.json", data: JSONSerialization.data(withJSONObject: object))])
    }
    func testExplicitDocumentationOnlyCatalogueEntryLoadsWithoutInventedControls() throws {
        let lib = try library(object())
        let profile = try lib.profile(id: "test.documents", version: "1.0.0")
        XCTAssertTrue(profile.controls.isEmpty)
        let config = ControllerConfiguration(profileID: profile.id, version: profile.version, globalChannel: 1, layerMode: "documented", unitMap: "factory")
        guard case .unresolved = ControllerControlResolver(library: lib).resolve(controlID: "imaginary", configuration: config, layer: .base, direction: .send) else { return XCTFail("No invented mapping") }
        XCTAssertTrue(ControllerProfileCoverage.summary(of: profile).contains("No control addresses"))
        XCTAssertEqual(try JSONDecoder().decode(ControllerProfile.self, from: JSONEncoder().encode(profile)), profile)
    }
    func testEmptyOrdinaryOrPartialProfileStillFails() {
        XCTAssertThrowsError(try library(object(state: nil)))
        XCTAssertThrowsError(try library(object(state: "partial")))
    }
    func testDocumentationOnlyRequiresExplicitCoverageExplanation() {
        var value = object(); value["coverageNotes"] = []
        XCTAssertThrowsError(try library(value))
    }
}
