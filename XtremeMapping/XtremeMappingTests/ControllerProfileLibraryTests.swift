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
            (fixture.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":3"), "$.schemaVersion"),
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
        assertInvalid(String(repeating: " ", count: 12_000_001), path: "$")
        assertInvalid(String(repeating: "[", count: 40) + "0" + String(repeating: "]", count: 40), path: "$")
    }

    private var v2: String {
        fixture.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":2,\"ports\":[{\"id\":\"usb\",\"name\":\"USB\"}]")
    }

    func testV2FixedChannelAndExactModePortIsolation() throws {
        let json = v2.replacingOccurrences(of: "\"number\":16", with: "\"number\":16,\"channel\":7,\"modeID\":\"off\",\"portID\":\"usb\"")
        let library = try ControllerProfileLibrary(resources: [resource(json)])
        let resolver = ControllerControlResolver(library: library)
        var config = ControllerConfiguration(profileID: "test.controller", version: "1.0.0", globalChannel: 2, layerMode: "off", unitMap: "factory")
        guard case .unresolved = resolver.resolve(controlID: "fader.1", configuration: config, layer: .base, direction: .send) else { return XCTFail("Unselected port must not resolve") }
        config.portID = "usb"
        guard case let .resolved(values) = resolver.resolve(controlID: "fader.1", configuration: config, layer: .base, direction: .send) else { return XCTFail("Expected selected port") }
        XCTAssertEqual(values.map(\.midi.channel), [7])
        XCTAssertEqual(values.map(\.midi.number), [16])
        config.portID = "unknown"
        guard case .unresolved = resolver.resolve(controlID: "fader.1", configuration: config, layer: .base, direction: .send) else { return XCTFail("Unknown port must not resolve") }
    }

    func testV2ModeSelectionDoesNotCombineAlternativeAddresses() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(v2.utf8)) as? [String: Any])
        var modes = try XCTUnwrap(object["modes"] as? [[String: Any]])
        var alternate = modes[0]
        alternate["id"] = "alternate"
        modes.append(alternate)
        object["modes"] = modes
        var controls = try XCTUnwrap(object["controls"] as? [[String: Any]])
        var bindings = try XCTUnwrap(controls[0]["bindings"] as? [[String: Any]])
        bindings[0]["modeID"] = "off"
        var second = bindings[0]
        second["modeID"] = "alternate"
        second["number"] = 33
        bindings.append(second)
        controls[0]["bindings"] = bindings
        object["controls"] = controls
        let library = try ControllerProfileLibrary(resources: [.init(name: "fixture.json", data: JSONSerialization.data(withJSONObject: object))])
        for (mode, number) in [("off", 16), ("alternate", 33)] {
            let config = ControllerConfiguration(profileID: "test.controller", version: "1.0.0", globalChannel: 2, layerMode: mode, unitMap: "factory")
            guard case let .resolved(values) = ControllerControlResolver(library: library).resolve(controlID: "fader.1", configuration: config, layer: .base, direction: .send) else { return XCTFail("Expected selected mode") }
            XCTAssertEqual(values.map(\.midi.number), [number])
        }
    }

    func testV2CompoundCannotFlattenAndRoundTrips() throws {
        let json = v2.replacingOccurrences(of: "\"kind\":\"controlChange\",\"number\":16,\"encoding\":\"absolute7Bit\"", with: "\"kind\":\"compound\",\"encoding\":\"paired14Bit\",\"support\":\"documentedOnly\",\"components\":[{\"kind\":\"controlChange\",\"number\":16,\"role\":\"MSB\"},{\"kind\":\"controlChange\",\"number\":48,\"role\":\"LSB\"}],\"semantics\":\"0...16383\"")
        let library = try ControllerProfileLibrary(resources: [resource(json)])
        let profile = try library.profile(id: "test.controller", version: "1.0.0")
        XCTAssertNil(profile.controls[0].bindings[0].number)
        XCTAssertEqual(try JSONDecoder().decode(ControllerProfile.self, from: JSONEncoder().encode(profile)), profile)
        let config = ControllerConfiguration(profileID: profile.id, version: profile.version, globalChannel: 2, layerMode: "off", unitMap: "factory")
        guard case let .unresolved(reason) = ControllerControlResolver(library: library).resolve(controlID: "fader.1", configuration: config, layer: .base, direction: .send) else { return XCTFail("Compound must not flatten") }
        XCTAssertTrue(reason.contains("generic"))
    }

    func testV2RejectsInvalidContextsAndV1RejectsV2Semantics() {
        for (field, path) in [("\"channel\":0,", "channel"), ("\"channel\":17,", "channel"), ("\"modeID\":\"missing\",", "modeID"), ("\"portID\":\"missing\",", "portID")] {
            assertInvalid(v2.replacingOccurrences(of: "\"number\":16", with: field + "\"number\":16"), path: "$.controls[0].bindings[0]." + path)
        }
        assertInvalid(fixture.replacingOccurrences(of: "\"number\":16", with: "\"channel\":2,\"number\":16"), path: "$.controls[0].bindings[0]")
        assertInvalid(v2.replacingOccurrences(of: "\"number\":16", with: "\"number\":null"), path: "$.controls[0].bindings[0].number")
    }

    func testOverridesCaptureAndRetainExactPortContext() throws {
        var config = ControllerConfiguration(profileID: "test.controller", version: "1.0.0", globalChannel: 2, layerMode: "off", unitMap: "factory")
        for port in ["usb", "din"] {
            config.portID = port
            try ControllerProfileWorkflow.setOverride(controlID: "fader.1", layer: .base, direction: .send, midi: .controlChange(channel: 3, number: 99), provenance: .midiLearn, in: &config)
        }
        XCTAssertEqual(config.overrides.map(\.portID), ["usb", "din"])
        XCTAssertEqual(try JSONDecoder().decode(ControllerConfiguration.self, from: JSONEncoder().encode(config)), config)
    }

    func testV2OverrideNeverLeaksFromSelectedPortToUnselectedPort() throws {
        let library = try ControllerProfileLibrary(resources: [resource(v2)])
        let resolver = ControllerControlResolver(library: library)
        var config = ControllerConfiguration(profileID: "test.controller", version: "1.0.0", globalChannel: 2, layerMode: "off", unitMap: "factory")
        config.portID = "usb"
        try ControllerProfileWorkflow.setOverride(controlID: "fader.1", layer: .base, direction: .send, midi: .controlChange(channel: 3, number: 99), provenance: .midiLearn, in: &config)
        for (port, expected) in [(Optional("usb"), 99), (nil, 16)] {
            config.portID = port
            guard case let .resolved(values) = resolver.resolve(controlID: "fader.1", configuration: config, layer: .base, direction: .send) else { return XCTFail("Expected scalar") }
            XCTAssertEqual(values.map(\.midi.number), [expected])
        }
    }

    private func assertInvalid(_ json: String, path expectedPath: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try ControllerProfileLibrary(resources: [resource(json)]), file: file, line: line) { error in
            guard case let ControllerProfileLibraryError.invalidResource(resource, path, _) = error else { return XCTFail("Unexpected error: \(error)", file: file, line: line) }
            XCTAssertEqual(resource, "fixture.json", file: file, line: line)
            XCTAssertEqual(path, expectedPath, file: file, line: line)
        }
    }
}
