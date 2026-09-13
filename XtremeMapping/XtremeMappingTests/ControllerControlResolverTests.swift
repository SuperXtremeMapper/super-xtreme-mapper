import XCTest
@testable import XtremeMapping

final class ControllerControlResolverTests: XCTestCase {
    private func configuration(_ model: String = "k2", mode: String = "off", channel: Int = 1) -> ControllerConfiguration {
        ControllerConfiguration(profileID: "allen-heath.xone-\(model)", version: "1.0.0", globalChannel: channel, layerMode: mode, unitMap: "factory")
    }
    private func bindings(_ id: String, _ config: ControllerConfiguration?, layer: ControllerProfile.Layer = .base,
                          direction: ControllerProfile.Direction = .send, file: StaticString = #filePath, line: UInt = #line) throws -> [ResolvedControllerBinding] {
        let result = try ControllerControlResolver(library: ControllerProfileLibrary()).resolve(controlID: id, configuration: config, layer: layer, direction: direction)
        guard case let .resolved(values) = result else {
            XCTFail("Expected resolved: \(result)", file: file, line: line)
            return []
        }
        return values
    }
    private func unresolved(_ id: String, _ config: ControllerConfiguration?, layer: ControllerProfile.Layer = .base,
                            direction: ControllerProfile.Direction = .send, file: StaticString = #filePath, line: UInt = #line) throws {
        let result = try ControllerControlResolver(library: ControllerProfileLibrary()).resolve(controlID: id, configuration: config, layer: layer, direction: direction)
        guard case let .unresolved(reason) = result else { return XCTFail("Expected unresolved: \(result)", file: file, line: line) }
        XCTAssertFalse(reason.isEmpty, file: file, line: line)
    }

    func testEveryModeAndControlFamilyAtChannelExtremes() throws {
        // Literal green-layer addresses, independently transcribed from manufacturer diagrams.
        let families: [(String, [Int])] = [
            ("matrix.1.1", [36,108,36,108,108]),
            ("pot.switch.1.1", [48,48,120,120,120]),
            ("encoder.top.1.push", [52,52,124,124,124]),
            ("encoder.bottom.1.push", [13,13,13,21,21]),
            ("button.bottom.right", [15,15,15,23,23]),
            ("encoder.top.1.turn", [0,0,0,0,44]),
            ("encoder.bottom.1.turn", [20,20,20,20,68]),
            ("encoder.bottom.2.turn", [21,21,21,21,69]),
            ("pot.1.1", [4,4,4,4,48]),
            ("fader.1", [16,16,16,16,60])
        ]
        for model in ["k2", "k3"] {
            for channel in [1,16] {
                for (index, mode) in ["off","switch-matrix","pot-switches","all-switches","all-controls"].enumerated() {
                    for (id, numbers) in families {
                        let result = try bindings(id, configuration(model, mode: mode, channel: channel), layer: .green)
                        XCTAssertEqual(result.map(\.midi.number), [numbers[index]], "\(model) \(mode) \(id)")
                        XCTAssertEqual(result.map(\.midi.channel), [channel])
                        XCTAssertEqual(result.map(\.provenance), ["manufacturer-documented"])
                        XCTAssertFalse(try XCTUnwrap(result.first).evidence.isEmpty)
                    }
                }
            }
        }
    }

    func testAmberAndBaseLayersUseExplicitAddresses() throws {
        for (layer, expected) in [(ControllerProfile.Layer.base, [0,16,20]), (.amber, [22,38,42]), (.green, [44,60,68])] {
            for (index, id) in ["encoder.top.1.turn","fader.1","encoder.bottom.1.turn"].enumerated() {
                XCTAssertEqual(try bindings(id, configuration(mode: "all-controls"), layer: layer).map(\.midi.number), [expected[index]])
            }
        }
    }

    func testMissingInvalidAndUnknownConfigurationNeverChoosesDefaults() throws {
        try unresolved("fader.1", nil)
        for channel in [0,17] { try unresolved("fader.1", configuration(channel: channel)) }
        try unresolved("fader.1", configuration(mode: "unsupported"))
        var config = configuration()
        config.version = "2.0.0"
        try unresolved("fader.1", config)
        config = configuration()
        config.profileID = "unknown"
        try unresolved("fader.1", config)
        config = configuration()
        config.unitMap = "unknown"
        try unresolved("fader.1", config)
        try unresolved("unknown-control", configuration())
    }

    func testK1DoesNotInheritLayersAndK2LayerButtonIsReserved() throws {
        XCTAssertEqual(try bindings("encoder.top.1.push", configuration("k1"), layer: .green).map(\.midi.number), [52])
        for mode in ["switch-matrix","pot-switches","all-switches","all-controls"] {
            try unresolved("fader.1", configuration("k1", mode: mode))
            for model in ["k2","k3"] {
                try unresolved("button.bottom.left", configuration(model, mode: mode))
                try unresolved("button.bottom.left", configuration(model, mode: mode), direction: .receive)
            }
        }
        XCTAssertEqual(try bindings("button.bottom.left", configuration()).map(\.midi.number), [12])
    }

    func testFeedbackDirectionsAndK3DeclaredMode() throws {
        XCTAssertEqual(try bindings("matrix.1.1", configuration("k1"), direction: .receive).map(\.midi.number), [36,72,108])
        XCTAssertEqual(try bindings("matrix.1.1", configuration(), direction: .receive).map(\.midi.number), [36,72,108])
        XCTAssertEqual(try bindings("matrix.1.1", configuration(mode: "switch-matrix"), layer: .amber, direction: .receive).map(\.color), [.amber])
        XCTAssertEqual(try bindings("encoder.top.1.push", configuration(mode: "switch-matrix"), layer: .amber, direction: .receive).map(\.color), [.red,.amber,.green])
        try unresolved("encoder.bottom.1.push", configuration(), direction: .receive)
        try unresolved("fader.1", configuration(), direction: .receive)
        var config = configuration("k3")
        try unresolved("matrix.1.1", config, direction: .receive)
        config.feedbackMode = "linked"
        try unresolved("matrix.1.1", config, direction: .receive)
        config.feedbackMode = "remote"
        XCTAssertEqual(try bindings("matrix.1.1", config, direction: .receive).map(\.color), [.red,.amber,.green])
        config.layerMode = "pot-switches"
        XCTAssertEqual(try bindings("matrix.1.1", config, layer: .green, direction: .receive).map(\.color), [.green])
    }

    func testOverrideIsLimitedToOneControlDirectionMapModeAndLayer() throws {
        var config = configuration("k3", mode: "all-controls")
        config.unitMap = "custom-1"
        try unresolved("fader.1", config, layer: .green)
        let override = ControllerControlOverride(controlID: "fader.1", layerMode: "all-controls", unitMap: "custom-1", layer: .green, direction: .send, midi: SXMJSONMIDI(try .controlChange(channel: 16, number: 99)), provenance: .midiLearn)
        config.overrides = [override]
        let result = try bindings("fader.1", config, layer: .green)
        XCTAssertEqual(result.map(\.midi.number), [99])
        XCTAssertEqual(result.map(\.midi.channel), [16])
        XCTAssertEqual(result.map(\.provenance), ["midi-learn"])
        try unresolved("fader.2", config, layer: .green)
        try unresolved("fader.1", config, layer: .amber)
        try unresolved("fader.1", config, layer: .green, direction: .receive)
        config.unitMap = "custom-2"
        try unresolved("fader.1", config, layer: .green)
        config.unitMap = "custom-1"
        config.layerMode = "off"
        try unresolved("fader.1", config, layer: .green)
    }

    func testInvalidOrDuplicateOverridesDoNotFallBackOrCrash() throws {
        var config = configuration()
        var override = ControllerControlOverride(controlID: "fader.1", layerMode: "off", unitMap: "factory", layer: .base, direction: .send, midi: SXMJSONMIDI(try .controlChange(channel: 2, number: 99)), provenance: .userSupplied)
        config.overrides = [override]
        XCTAssertEqual(try bindings("fader.1", config).map(\.midi.number), [99])
        config.overrides = [override, override]
        try unresolved("fader.1", config)
        override.midi.number = 128
        config.overrides = [override]
        try unresolved("fader.1", config)
        override.midi = SXMJSONMIDI(try .unassigned(channel: 1))
        config.overrides = [override]
        try unresolved("fader.1", config)
    }

    func testMatchingReturnsEveryCompatibleRowInDeviceOrder() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        let input = MappingEntry(ioType: .input, assignment: .deckA, midiChannel: 1, midiCC: 16)
        var duplicate = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 16)
        duplicate.modifier1Condition = ModifierCondition(modifier: 2, value: 3)
        duplicate.assignment = .deckB
        duplicate.comment = "Different mapping purpose"
        let all = MappingEntry(ioType: .all, midiChannel: 1, midiCC: 16)
        let output = MappingEntry(ioType: .output, midiChannel: 1, midiCC: 16)
        let wrongKind = MappingEntry(midiChannel: 1, midiNote: 16)
        let wrongChannel = MappingEntry(midiChannel: 2, midiCC: 16)
        let device = Device(mappings: [wrongKind,input,output,duplicate,wrongChannel,all])
        let sends = try bindings("fader.1", configuration())
        XCTAssertEqual(resolver.matchingRows(bindings: sends + sends, device: device), [input.id,duplicate.id,all.id])
        let receive = ResolvedControllerBinding(midi: try .controlChange(channel: 1, number: 16), direction: .receive, color: nil, provenance: "user-supplied", evidence: [])
        XCTAssertEqual(resolver.matchingRows(bindings: [receive], device: device), [output.id,all.id])
        XCTAssertEqual(resolver.matchingRows(bindings: sends, device: Device()), [])
    }

    // MARK: - Reverse physical-name mapping (index + remap)

    /// send→input, receive→output, and all-direction rows each map to the control name.
    func testPhysicalNamesMapEachDirectionToControlName() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        let config = configuration() // K2, mode "off", channel 1; fader.1 = CC 16, "Fader 1".
        let input = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 16)
        let all = MappingEntry(ioType: .all, midiChannel: 1, midiCC: 16)
        // matrix.1.1 (name "A") has a documented receive (LED) binding at note 36 (base).
        let output = MappingEntry(ioType: .output, midiChannel: 1, midiNote: 36)
        let device = Device(mappings: [input, all, output])
        let names = resolver.physicalNames(configuration: config, device: device)
        XCTAssertEqual(names[input.id], "Fader 1")
        XCTAssertEqual(names[all.id], "Fader 1")
        XCTAssertEqual(names[output.id], "A")
    }

    /// The one-shot convenience composes reverseNameIndex + physicalNames(index:).
    func testOneShotComposesTwoStepAPI() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        let config = configuration()
        let input = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 16)
        let device = Device(mappings: [input])
        let index = resolver.reverseNameIndex(configuration: config)
        XCTAssertEqual(resolver.physicalNames(index: index, device: device),
                       resolver.physicalNames(configuration: config, device: device))
    }

    /// Opaque rows (raw control name / raw binding id) and unassigned MIDI are omitted.
    func testOpaqueAndUnassignedRowsAreOmitted() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        let config = configuration()
        let rawName = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 16, rawMidiControlName: "Native.Thing")
        let rawBinding = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 16, rawMidiBindingID: 42)
        let unassigned = MappingEntry(ioType: .input, midiAssignment: try .unassigned(channel: 1))
        let device = Device(mappings: [rawName, rawBinding, unassigned])
        let names = resolver.physicalNames(configuration: config, device: device)
        XCTAssertNil(names[rawName.id])
        XCTAssertNil(names[rawBinding.id])
        XCTAssertNil(names[unassigned.id])
        XCTAssertTrue(names.isEmpty)
    }

    /// FIX 1: an address shared by two differently named controls resolves to NO name.
    /// Faderfox UC4: CC ch1 #32 (send) is claimed by both an Encoder and a Fader; the
    /// unshared CC ch1 #8 belongs only to "Encoder 1".
    func testAmbiguousSharedAddressYieldsNoName() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        let config = ControllerConfiguration(profileID: "faderfox.faderfox-uc4", version: "1.0.0",
                                             globalChannel: 1, layerMode: "setup-1", unitMap: "factory")
        let ambiguous = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 32)
        let unambiguous = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 8)
        let device = Device(mappings: [ambiguous, unambiguous])
        let names = resolver.physicalNames(configuration: config, device: device)
        XCTAssertNil(names[ambiguous.id], "Ambiguous shared address must produce a blank name.")
        XCTAssertEqual(names[unambiguous.id], "Encoder 1 — Factory setup 1, group 1 — Channel 1 — Input")
    }

    /// FIX 2: a fully port-scoped profile resolves names once a port is defaulted, and
    /// resolves NOTHING when portID is nil.
    func testPortScopedProfileResolvesOnlyWithDefaultedPort() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        // APC mini mk2: every binding is port-scoped. Track Button 1 (port-0) = note 100.
        let row = MappingEntry(ioType: .input, midiChannel: 1, midiNote: 100)
        let device = Device(mappings: [row])

        var noPort = ControllerConfiguration(profileID: "akai-professional.akai-apc-mini-mk2", version: "1.0.0",
                                             globalChannel: 1, layerMode: "documented", unitMap: "factory")
        XCTAssertTrue(resolver.physicalNames(configuration: noPort, device: device).isEmpty,
                      "Port-scoped bindings must not resolve when portID is nil.")

        noPort.portID = "port-0" // mirrors chooseProfile defaulting to the first port.
        XCTAssertEqual(resolver.physicalNames(configuration: noPort, device: device)[row.id],
                       "Track Button 1 — Port 0 — Channel 1 — Input")
    }

    /// Rows from multiple devices combine into one name map.
    func testMultipleDevicesCombine() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        let config = configuration()
        let index = resolver.reverseNameIndex(configuration: config)
        let rowA = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 16)
        let rowB = MappingEntry(ioType: .input, midiChannel: 1, midiCC: 17) // fader.2 = CC 17.
        var combined = resolver.physicalNames(index: index, device: Device(mappings: [rowA]))
        for (id, name) in resolver.physicalNames(index: index, device: Device(mappings: [rowB])) {
            combined[id] = name
        }
        XCTAssertEqual(combined[rowA.id], "Fader 1")
        XCTAssertEqual(combined[rowB.id], "Fader 2")
    }

    /// An override address maps to its control's name.
    func testOverrideAddressMapsToControlName() throws {
        let resolver = try ControllerControlResolver(library: ControllerProfileLibrary())
        var config = configuration()
        let override = ControllerControlOverride(controlID: "fader.1", layerMode: "off", unitMap: "factory",
                                                 layer: .base, direction: .send,
                                                 midi: SXMJSONMIDI(try .controlChange(channel: 2, number: 99)),
                                                 provenance: .userSupplied)
        config.overrides = [override]
        let row = MappingEntry(ioType: .input, midiChannel: 2, midiCC: 99)
        let names = resolver.physicalNames(configuration: config, device: Device(mappings: [row]))
        XCTAssertEqual(names[row.id], "Fader 1")
    }
}
