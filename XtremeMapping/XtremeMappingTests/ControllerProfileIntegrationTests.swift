import XCTest
@testable import XtremeMapping

/// Exercises the actual pinned bundle, not hand-written stand-ins for manufacturer data.
final class ControllerProfileIntegrationTests: XCTestCase {
    func testBundleLoadsExact47ProfilesAndPreservesLegacyVersions() throws {
        let library = try ControllerProfileLibrary()
        XCTAssertEqual(library.profiles.count, 47)
        XCTAssertEqual(library.profiles.filter { $0.schemaVersion == 2 }.count, 44)
        XCTAssertEqual(library.profiles.filter { $0.coverageState == .partial }.count, 8)
        XCTAssertEqual(library.profiles.filter { $0.coverageState == .documentationOnly }.count, 13)
        for id in ["allen-heath.xone-k1", "allen-heath.xone-k2", "allen-heath.xone-k3"] {
            XCTAssertEqual(try library.profile(id: id, version: "1.0.0").schemaVersion, 1)
        }
        for profile in library.profiles {
            XCTAssertEqual(profile.version, "1.0.0")
            XCTAssertEqual(profile.controls.isEmpty, profile.coverageState == .documentationOnly, profile.id)
        }
    }

    func testEveryGeneratedBindingResolvesOnlyItsSupportedDocumentedAddress() throws {
        let library = try ControllerProfileLibrary()
        let resolver = ControllerControlResolver(library: library)
        var availableCount = 0
        var documentedCount = 0
        for profile in library.profiles where profile.schemaVersion == 2 {
            let evidenceIDs = Set(profile.evidence.map(\.id))
            var modelAvailableCount = 0
            for control in profile.controls {
                for binding in control.bindings {
                    var configuration = ControllerConfiguration(profileID: profile.id, version: profile.version,
                        globalChannel: 13, layerMode: try XCTUnwrap(binding.modeID), unitMap: "factory")
                    configuration.portID = binding.portID
                    let result = resolver.resolve(controlID: control.id, configuration: configuration,
                        layer: .base, direction: binding.direction)
                    XCTAssertFalse(binding.evidence.isEmpty)
                    XCTAssertTrue(Set(binding.evidence).isSubset(of: evidenceIDs))
                    XCTAssertNotNil(binding.semantics)
                    if binding.support == .available {
                        availableCount += 1
                        modelAvailableCount += 1
                        guard case let .resolved(values) = result else {
                            XCTFail("Unavailable scalar \(profile.id) \(control.id): \(result)")
                            continue
                        }
                        XCTAssertEqual(values.count, 1)
                        XCTAssertEqual(values.first?.midi.number, binding.number)
                        XCTAssertEqual(values.first?.midi.channel, binding.channel ?? 13)
                        XCTAssertEqual(values.first?.evidence, binding.evidence)
                    } else {
                        documentedCount += 1
                        guard case let .unresolved(reason) = result else {
                            XCTFail("Unsupported record became scalar: \(profile.id) \(control.id)")
                            continue
                        }
                        XCTAssertFalse(reason.isEmpty)
                    }
                }
            }
            if profile.coverageState == .documentationOnly {
                XCTAssertEqual(modelAvailableCount, 0)
            } else {
                XCTAssertGreaterThan(modelAvailableCount, 0, profile.id)
            }
        }
        XCTAssertGreaterThan(availableCount, 20_000)
        XCTAssertGreaterThan(documentedCount, 100)
    }

    func testXone96FaderUsesConfirmedChannelAndSelectorsRemainDiscreteNotes() throws {
        let library = try ControllerProfileLibrary()
        let profile = try library.profile(id: "allen-heath.xone-96", version: "1.0.0")
        XCTAssertEqual(profile.defaultChannel, 16)
        let fader = try XCTUnwrap(profile.controls.first { $0.id == "b0001" })
        XCTAssertEqual(fader.bindings.first?.kind, .controlChange)
        XCTAssertEqual(fader.bindings.first?.number, 0)
        XCTAssertNil(fader.bindings.first?.channel)
        let selectors = profile.controls.flatMap(\.bindings).filter { $0.context == "rotary switch position USB 1" }
        XCTAssertFalse(selectors.isEmpty)
        XCTAssertTrue(selectors.allSatisfy { $0.kind == .note && $0.portID == nil })
        XCTAssertTrue((profile.ports ?? []).isEmpty)
    }

    func testFLX4PreservesFixedPlayChannelAndRefusesPairedTempo() throws {
        let library = try ControllerProfileLibrary()
        let profile = try library.profile(id: "pioneer-dj.ddj-flx4", version: "1.0.0")
        let play = try XCTUnwrap(profile.controls.first { $0.id == "b00001" }?.bindings.first)
        XCTAssertEqual(play.kind, .note)
        XCTAssertEqual(play.number, 11)
        XCTAssertEqual(play.channel, 1)
        let tempo = try XCTUnwrap(profile.controls.first { $0.id == "b00071" }?.bindings.first)
        XCTAssertEqual(tempo.kind, .compound)
        XCTAssertEqual(tempo.support, .documentedOnly)
        XCTAssertNil(tempo.number)
        XCTAssertEqual(tempo.components?.map(\.number), [0, 32])
        XCTAssertTrue(try XCTUnwrap(tempo.semantics).contains("MSB:0x7F"))
    }

    func testLaunchpadXRetainsProgrammerAddressAndPaletteWithoutInventingInputChannel() throws {
        let library = try ControllerProfileLibrary()
        let profile = try library.profile(id: "novation.launchpad-x", version: "1.0.0")
        let pad = try XCTUnwrap(profile.controls.first { $0.id == "b00001" }?.bindings.first)
        XCTAssertEqual(pad.kind, .note)
        XCTAssertEqual(pad.number, 11)
        XCTAssertNil(pad.channel)
        XCTAssertEqual(pad.modeID, "programmer")
        XCTAssertTrue(profile.controls.flatMap(\.bindings).contains { $0.encoding == .palette && $0.direction == .receive })
        XCTAssertTrue((profile.coverageNotes ?? []).contains { $0.contains("only a UI starting value") })
    }

    func testFactorySetupsAndExplicitPortsDoNotLeakAcrossContexts() throws {
        let library = try ControllerProfileLibrary()
        let resolver = ControllerControlResolver(library: library)
        let uc4 = try library.profile(id: "faderfox.faderfox-uc4", version: "1.0.0")
        XCTAssertEqual(Set(uc4.modes.map(\.id)), Set((1...18).map { "setup-\($0)" }))
        let first = try XCTUnwrap(uc4.controls.first)
        let wrongSetup = ControllerConfiguration(profileID: uc4.id, version: uc4.version,
            globalChannel: 1, layerMode: "setup-2", unitMap: "factory")
        guard case .unresolved = resolver.resolve(controlID: first.id, configuration: wrongSetup, layer: .base, direction: .send)
        else { return XCTFail("Factory setup 1 leaked into setup 2") }
        let apc = try library.profile(id: "akai-professional.akai-apc-mini-mk2", version: "1.0.0")
        XCTAssertEqual(Set((apc.ports ?? []).map(\.id)), ["port-0", "port-1"])
        let portControl = try XCTUnwrap(apc.controls.first { $0.bindings.first?.portID == "port-1" })
        let binding = try XCTUnwrap(portControl.bindings.first)
        var wrongPort = ControllerConfiguration(profileID: apc.id, version: apc.version,
            globalChannel: 1, layerMode: try XCTUnwrap(binding.modeID), unitMap: "factory")
        wrongPort.portID = "port-0"
        guard case .unresolved = resolver.resolve(controlID: portControl.id, configuration: wrongPort, layer: .base, direction: binding.direction)
        else { return XCTFail("Port 1 binding leaked into port 0") }
    }
}
