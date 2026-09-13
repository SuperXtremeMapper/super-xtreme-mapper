import XCTest
@testable import XtremeMapping

final class XoneProfileEvidenceTests: XCTestCase {
    func testBundledProfilesHaveCompletePhysicalInventoryAndSeparateLEDTargets() throws {
        let library = try ControllerProfileLibrary()
        for model in ["k1", "k2", "k3"] {
            let profile = try library.profile(id: "allen-heath.xone-\(model)", version: "1.0.0")
            XCTAssertEqual(profile.defaultChannel, 15)
            XCTAssertEqual(profile.controls.count, 58)
            XCTAssertEqual(Set(profile.controls.map(\.physicalID)).count, 52)
            XCTAssertEqual(profile.controls.filter { $0.bindings.contains { $0.direction == .receive } }.count, 34)
            XCTAssertTrue(profile.evidence.allSatisfy { $0.verification.rawValue == "manufacturer-documented" })
            for control in profile.controls {
                XCTAssertFalse(control.bindings.isEmpty)
                for binding in control.bindings where binding.direction == .receive {
                    XCTAssertEqual(binding.layer, .base, "LED color is not an input layer")
                    XCTAssertNotNil(binding.color)
                    XCTAssertNil(binding.valueMin, "Manual does not define a universal LED threshold")
                    XCTAssertNil(binding.valueMax)
                }
            }
        }
    }

    func testK1BaseAddressesAndLEDColorsUseDifferentBindings() throws {
        let profile = try ControllerProfileLibrary().profile(id: "allen-heath.xone-k1", version: "1.0.0")
        for (index, cc) in [0, 1, 2, 3].enumerated() {
            XCTAssertEqual(try sendNumbers(profile, "encoder.top.\(index + 1).turn"), [cc])
        }
        for (index, cc) in [16, 17, 18, 19].enumerated() {
            XCTAssertEqual(try sendNumbers(profile, "fader.\(index + 1)"), [cc])
        }
        XCTAssertEqual(try sendNumbers(profile, "encoder.top.1.push"), [52])
        XCTAssertEqual(try receiveNumbers(profile, "encoder.top.1.push"), [52, 88, 124])
        XCTAssertEqual(try receiveNumbers(profile, "button.bottom.left"), [12, 16, 20])
        XCTAssertEqual(try receiveNumbers(profile, "button.bottom.right"), [15, 19, 23])
        XCTAssertEqual(profile.modes.map(\.id), ["off"])
    }

    func testK2AndK3ExplicitLayerAddressesIncludeBottomEncoderException() throws {
        let library = try ControllerProfileLibrary()
        for model in ["k2", "k3"] {
            let profile = try library.profile(id: "allen-heath.xone-\(model)", version: "1.0.0")
            for (controlID, numbers) in [
                ("encoder.top.1.turn", [0, 22, 44]),
                ("fader.1", [16, 38, 60]),
                ("encoder.bottom.1.turn", [20, 42, 68]),
                ("encoder.bottom.2.turn", [21, 43, 69]),
                ("encoder.bottom.1.push", [13, 17, 21]),
                ("encoder.bottom.2.push", [14, 18, 22]),
                ("pot.switch.2.3", [46, 82, 118])
            ] {
                XCTAssertEqual(try sendNumbers(profile, controlID), numbers, "\(model) \(controlID)")
            }
            XCTAssertEqual(try receiveNumbers(profile, "encoder.bottom.1.push"), [])
            let layer = try control(profile, "button.bottom.left")
            XCTAssertEqual(Set(layer.reservedInModes), ["switch-matrix", "pot-switches", "all-switches", "all-controls"])
            let potMode = try XCTUnwrap(profile.modes.first { $0.id == "pot-switches" })
            XCTAssertTrue(potMode.layeredGroups.contains(try control(profile, "encoder.top.1.push").group))
            XCTAssertFalse(potMode.layeredGroups.contains(try control(profile, "encoder.bottom.1.push").group))
            XCTAssertTrue(try XCTUnwrap(profile.modes.first { $0.id == "all-controls" }).softPickup)
        }
    }

    func testAllMatrixAddressesMatchManufacturerGrid() throws {
        // Top-to-bottom row order; literals independently read from the diagrams.
        let base = [[36,37,38,39], [32,33,34,35], [28,29,30,31], [24,25,26,27]]
        let amber = [[72,73,74,75], [68,69,70,71], [64,65,66,67], [60,61,62,63]]
        let green = [[108,109,110,111], [104,105,106,107], [100,101,102,103], [96,97,98,99]]
        let library = try ControllerProfileLibrary()
        for model in ["k1", "k2", "k3"] {
            let profile = try library.profile(id: "allen-heath.xone-\(model)", version: "1.0.0")
            for row in 0..<4 {
                for column in 0..<4 {
                    let id = "matrix.\(row + 1).\(column + 1)"
                    let expected = [base[row][column], amber[row][column], green[row][column]]
                    XCTAssertEqual(try sendNumbers(profile, id), model == "k1" ? [expected[0]] : expected)
                    XCTAssertEqual(try receiveNumbers(profile, id), expected)
                }
            }
        }
    }

    func testK3CustomSlotsNeverClaimFactoryBindingsAndNoteVelocitiesRemainUnknown() throws {
        let profile = try ControllerProfileLibrary().profile(id: "allen-heath.xone-k3", version: "1.0.0")
        XCTAssertEqual(profile.unitMaps.filter(\.usesFactoryBindings).map(\.id), ["factory"])
        XCTAssertEqual(profile.unitMaps.filter { !$0.usesFactoryBindings }.map(\.id), ["custom-1", "custom-2", "custom-3"])
        for binding in profile.controls.flatMap(\.bindings) where binding.kind == .note {
            XCTAssertNil(binding.valueMin)
            XCTAssertNil(binding.valueMax)
        }
    }

    private func control(_ profile: ControllerProfile, _ id: String) throws -> ControllerProfile.Control {
        try XCTUnwrap(profile.controls.first { $0.id == id }, "Missing \(id)")
    }
    private func sendNumbers(_ profile: ControllerProfile, _ id: String) throws -> [Int] {
        try control(profile, id).bindings.filter { $0.direction == .send }.map { try XCTUnwrap($0.number) }
    }
    private func receiveNumbers(_ profile: ControllerProfile, _ id: String) throws -> [Int] {
        try control(profile, id).bindings.filter { $0.direction == .receive }.map { try XCTUnwrap($0.number) }
    }
}
