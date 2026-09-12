import XCTest
@testable import XtremeMapping

final class ControllerProfileLibraryTests: XCTestCase {
    private let fixture = #"""
    {"schemaVersion":1,"id":"test.controller","version":"1.0.0","manufacturer":"Test","model":"Controller","defaultChannel":15,
    "sources":[{"id":"manual","url":"https://example.com/manual.pdf","revision":"1","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}],
    "evidence":[{"id":"address","sourceID":"manual","locator":"p. 1","verification":"manufacturer-documented"}],
    "modes":[{"id":"off","name":"Off","layeredGroups":[],"softPickup":false,"evidence":["address"]}],
    "unitMaps":[{"id":"factory","usesFactoryBindings":true,"evidence":["address"]}],
    "controls":[{"id":"fader.1","physicalID":"fader.1","reservedInModes":[],"name":"Fader 1","aliases":[],"group":"faders","bindings":[{"direction":"send","layer":"base","kind":"controlChange","number":16,"encoding":"absolute7Bit","valueMin":0,"valueMax":127,"evidence":["address"],"notes":[]}],"evidence":["address"]}],
    "limitations":[],"configurationEvidence":["address"]}
    """#

    private func resource(_ json: String, name: String = "fixture.json") -> ControllerProfileResource {
        ControllerProfileResource(name: name, data: Data(json.utf8))
    }

    func testLoadsExactVersionAndPreservesAddressAndEvidence() throws {
        let library = try ControllerProfileLibrary(resources: [resource(fixture)])
        let profile = try library.profile(id: "test.controller", version: "1.0.0")
        XCTAssertEqual(profile.defaultChannel, 15)
        XCTAssertEqual(profile.controls.first?.bindings.first?.number, 16)
        XCTAssertEqual(profile.evidence.first?.sourceID, "manual")
    }

    func testUnknownVersionAndUnknownProfileAreUnavailableWithoutUpgrade() throws {
        let library = try ControllerProfileLibrary(resources: [resource(fixture)])
        for (id, version) in [("test.controller", "0.9.0"), ("unknown", "1.0.0")] {
            XCTAssertThrowsError(try library.profile(id: id, version: version)) { error in
                XCTAssertEqual(error as? ControllerProfileLibraryError, .unavailable(id: id, version: version))
            }
        }
    }

    func testDuplicateExactProfileVersionIsRejected() throws {
        XCTAssertThrowsError(try ControllerProfileLibrary(resources: [resource(fixture), resource(fixture, name: "second.json")])) { error in
            guard case let ControllerProfileLibraryError.invalidResource(resource, path, _) = error else { return XCTFail("Unexpected error: \(error)") }
            XCTAssertEqual(resource, "second.json")
            XCTAssertEqual(path, "$.id")
        }
    }

    func testRejectsMalformedAndInvalidResourceFieldsWithLocation() throws {
        let cases: [(String, String)] = [
            ("{", "$"),
            (fixture.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2"), "$.schemaVersion"),
            (fixture.replacingOccurrences(of: "\"defaultChannel\":15", with: "\"defaultChannel\":0"), "$.defaultChannel"),
            (fixture.replacingOccurrences(of: "\"defaultChannel\":15", with: "\"defaultChannel\":17"), "$.defaultChannel"),
            (fixture.replacingOccurrences(of: "\"number\":16", with: "\"number\":128"), "$.controls[0].bindings[0].number"),
            (fixture.replacingOccurrences(of: "\"number\":16", with: "\"number\":-1"), "$.controls[0].bindings[0].number"),
            (fixture.replacingOccurrences(of: "\"valueMin\":0", with: "\"valueMin\":128"), "$.controls[0].bindings[0].valueMin"),
            (fixture.replacingOccurrences(of: "\"sourceID\":\"manual\"", with: "\"sourceID\":\"missing\""), "$.evidence[0].sourceID"),
            (fixture.replacingOccurrences(of: "\"configurationEvidence\":[\"address\"]", with: "\"configurationEvidence\":[\"missing\"]"), "$.configurationEvidence[0]"),
            (fixture.replacingOccurrences(of: "\"direction\":\"send\"", with: "\"color\":\"red\",\"direction\":\"send\""), "$.controls[0].bindings[0].color")
        ]
        for (json, expectedPath) in cases {
            assertInvalid(json, path: expectedPath)
        }
    }

    func testRejectsDuplicateControlIDsAndMissingBindingEvidence() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        var controls = try XCTUnwrap(object["controls"] as? [[String: Any]])
        controls.append(controls[0])
        object["controls"] = controls
        assertInvalid(String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self), path: "$.controls[1].id")
        assertInvalid(fixture.replacingOccurrences(of: "\"evidence\":[\"address\"],\"notes\":[]", with: "\"evidence\":[],\"notes\":[]"), path: "$.controls[0].bindings[0].evidence")
    }

    func testAllowsUndocumentedValueRangeButRejectsPartialRange() throws {
        let noRange = fixture.replacingOccurrences(of: "\"valueMin\":0,\"valueMax\":127,", with: "")
        let library = try ControllerProfileLibrary(resources: [resource(noRange)])
        XCTAssertNil(try library.profile(id: "test.controller", version: "1.0.0").controls[0].bindings[0].valueMin)
        assertInvalid(fixture.replacingOccurrences(of: "\"valueMax\":127,", with: ""), path: "$.controls[0].bindings[0].valueMax")
    }

    func testRejectsUnknownModeAndGroupReferences() {
        assertInvalid(fixture.replacingOccurrences(of: "\"reservedInModes\":[]", with: "\"reservedInModes\":[\"missing\"]"), path: "$.controls[0].reservedInModes[0]")
        assertInvalid(fixture.replacingOccurrences(of: "\"layeredGroups\":[]", with: "\"layeredGroups\":[\"missing\"]"), path: "$.modes[0].layeredGroups[0]")
    }

    func testRejectsMismatchedMIDIKindsAndEncodings() {
        assertInvalid(fixture.replacingOccurrences(of: "\"encoding\":\"absolute7Bit\"", with: "\"encoding\":\"noteGate\""), path: "$.controls[0].bindings[0].encoding")
        let note = fixture.replacingOccurrences(of: "\"kind\":\"controlChange\"", with: "\"kind\":\"note\"")
        assertInvalid(note, path: "$.controls[0].bindings[0].encoding")
        assertInvalid(note.replacingOccurrences(of: "absolute7Bit", with: "relativeTwosComplement"), path: "$.controls[0].bindings[0].encoding")
    }

    func testAcceptsRelativeCCAndNoteGateBindings() throws {
        let relative = fixture.replacingOccurrences(of: "absolute7Bit", with: "relativeTwosComplement")
        let note = fixture.replacingOccurrences(of: "\"kind\":\"controlChange\"", with: "\"kind\":\"note\"").replacingOccurrences(of: "absolute7Bit", with: "noteGate")
        for json in [relative, note] {
            let library = try ControllerProfileLibrary(resources: [resource(json)])
            XCTAssertEqual(try library.profile(id: "test.controller", version: "1.0.0").controls[0].bindings.count, 1)
        }
    }

    func testRejectsControlsWithoutBindings() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(fixture.utf8)) as? [String: Any])
        var controls = try XCTUnwrap(object["controls"] as? [[String: Any]])
        controls[0]["bindings"] = []
        object["controls"] = controls
        assertInvalid(String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self), path: "$.controls[0].bindings")
    }

    func testRejectsOversizedAndDeepResourcesBeforeDecoding() {
        assertInvalid(String(repeating: " ", count: 2_000_001), path: "$")
        assertInvalid(String(repeating: "[", count: 40) + "0" + String(repeating: "]", count: 40), path: "$")
    }

    private func assertInvalid(_ json: String, path expectedPath: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try ControllerProfileLibrary(resources: [resource(json)]), file: file, line: line) { error in
            guard case let ControllerProfileLibraryError.invalidResource(resource, path, _) = error else { return XCTFail("Unexpected error: \(error)", file: file, line: line) }
            XCTAssertEqual(resource, "fixture.json", file: file, line: line)
            XCTAssertEqual(path, expectedPath, file: file, line: line)
        }
    }
}
