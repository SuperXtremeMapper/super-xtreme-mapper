import XCTest
@testable import XtremeMapping

final class ControllerProfileCoverageTests: XCTestCase {
    private func binding(_ fields: String) throws -> ControllerProfile.Binding {
        try JSONDecoder().decode(ControllerProfile.Binding.self, from: Data("""
        {"direction":"send","layer":"base","encoding":"documented","evidence":[],"notes":[],\(fields)}
        """.utf8))
    }

    func testComplexValuesStillAllowScalarAddressLookupWithoutPromisingBehavior() throws {
        let value = try binding(#"""
        "kind":"controlChange","number":12,"channel":4,"semantics":"relative encoder with manufacturer-specific values"
        """#)
        XCTAssertEqual(ControllerProfileCoverage.availability(of: value), .addressLookup)
        XCTAssertEqual(ControllerProfileCoverage.channelDescription(of: value), "Fixed MIDI channel 4")
    }

    func testPairedMessageIsDocumentedOnlyEvenWithScalarComponentNumbers() throws {
        let value = try binding(#"""
        "kind":"compound","components":[{"kind":"controlChange","number":0,"role":"MSB"},{"kind":"controlChange","number":32,"role":"LSB"}]
        """#)
        XCTAssertEqual(ControllerProfileCoverage.availability(of: value), .documentedOnly)
        XCTAssertEqual(ControllerProfileCoverage.messageDescription(of: value), "Paired or compound MIDI message")
    }

    func testExplicitlyUnavailableScalarAndMissingAddressAreNeverPresentedAsLookup() throws {
        for fields in [#""kind":"note","number":60,"support":"documentedOnly""#,
                       #""kind":"controlChange""#] {
            XCTAssertEqual(ControllerProfileCoverage.availability(of: try binding(fields)), .documentedOnly)
        }
    }

    func testLegacyAddressUsesConfiguredChannel() throws {
        let value = try binding(#""kind":"note","number":60"#)
        XCTAssertEqual(ControllerProfileCoverage.availability(of: value), .addressLookup)
        XCTAssertEqual(ControllerProfileCoverage.channelDescription(of: value), "Uses configured MIDI channel")
    }

    func testLegacyDocumentationFollowsResolvedGroupRoutingAndFeedbackColors() throws {
        let library = try ControllerProfileLibrary()
        let profile = try library.profile(id: "allen-heath.xone-k2", version: "1.0.0")
        let configuration = ControllerConfiguration(profileID: profile.id, version: profile.version,
            globalChannel: 1, layerMode: "switch-matrix", unitMap: "factory")
        let cases: [(String, ControllerProfile.Layer, ControllerProfile.Direction, [Int], [ControllerProfile.Color?])] = [
            ("encoder.top.1.push", .green, .send, [52], [nil]),
            ("matrix.1.1", .amber, .receive, [72], [.amber]),
            ("matrix.1.1", .green, .receive, [108], [.green]),
            ("encoder.top.1.push", .amber, .receive, [52, 88, 124], [.red, .amber, .green])
        ]
        for (id, layer, direction, numbers, colors) in cases {
            let control = try XCTUnwrap(profile.controls.first { $0.id == id })
            let resolution = ControllerControlResolver(library: library).resolve(controlID: id,
                configuration: configuration, layer: layer, direction: direction)
            let displayed = ControllerProfileCoverage.resolvedManufacturerBindings(in: control, resolution: resolution)
            XCTAssertEqual(displayed.compactMap(\.number), numbers, id)
            XCTAssertEqual(displayed.map(\.color), colors, id)
        }
    }

    func testLocalOverrideDoesNotPresentUnmatchedManufacturerDocumentation() throws {
        let library = try ControllerProfileLibrary()
        let profile = try library.profile(id: "allen-heath.xone-k2", version: "1.0.0")
        let control = try XCTUnwrap(profile.controls.first { $0.id == "encoder.top.1.push" })
        var configuration = ControllerConfiguration(profileID: profile.id, version: profile.version,
            globalChannel: 1, layerMode: "switch-matrix", unitMap: "factory")
        try ControllerProfileWorkflow.setOverride(controlID: control.id, layer: .green, direction: .send,
            midi: .note(channel: 1, number: 99), provenance: .userSupplied, in: &configuration)
        let resolution = ControllerControlResolver(library: library).resolve(controlID: control.id,
            configuration: configuration, layer: .green, direction: .send)
        XCTAssertTrue(ControllerProfileCoverage.resolvedManufacturerBindings(in: control, resolution: resolution).isEmpty)
    }

}
