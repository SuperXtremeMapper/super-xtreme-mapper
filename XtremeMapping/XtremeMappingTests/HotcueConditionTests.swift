import XCTest
import SwiftUI
@testable import XtremeMapping

@MainActor
final class HotcueConditionTests: XCTestCase {
    func testExplicitNoneClearsMixedSelectionEvenWhenDisplayedConditionIsNone() {
        let first = MappingEntry.output(commandID: 2333)
        var second = MappingEntry.output(commandID: 2334)
        second.modifier1Condition = ModifierCondition(modifier: 2334, value: 0)
        let document = TraktorMappingDocument()
        document.mappingFile = MappingFile(devices: [Device(mappings: [first, second])])
        let row = V2ModifierRow(condition: .constant(nil), isLocked: false) { selected in
            SettingsPanelV2.updateSelectedEntries([first.id, second.id], in: document, isLocked: false, undoManager: nil) {
                $0.modifier1Condition = selected
            }
        }
        row.applySelection(nil)
        XCTAssertTrue(document.mappingFile.allMappings.allSatisfy { $0.modifier1Condition == nil })
    }

    func testHotcueNamesStatesAndTargetsAreDistinctFromModifiers() {
        let cue = ModifierCondition(modifier: 2333, value: 0, target: .deckA)
        XCTAssertEqual(cue.wireID, 2333)
        XCTAssertEqual(cue.displayString, "Hotcue 1 State · Deck A = Cue")
        XCTAssertEqual(TraktorConditionMetadata.values(for: 2333).map(\.label), ["No Hotcue", "Cue", "Fade-In", "Fade-Out", "Load", "Grid", "Loop"])
        XCTAssertEqual(ModifierCondition(modifier: 1, value: 7).displayString, "M1 = 7")
        XCTAssertEqual(TraktorConditionMetadata.values(for: 1).map(\.rawValue), Array(0...7))
        XCTAssertTrue(TraktorConditionMetadata.values(for: 98765).isEmpty)
        XCTAssertEqual(ModifierCondition(modifier: 98765, value: 10).displayString, "Condition 98765 = 10")
    }

    func testConditionChoicePreservesTargetWhenEditingValue() {
        let condition = ModifierCondition(modifier: 2334, value: 0, target: .deckB)
        let edited = TraktorConditionMetadata.replacingValue(of: condition, with: 5)
        XCTAssertEqual(edited?.target, .deckB)
        XCTAssertEqual(edited?.modifier, 2334)
        XCTAssertEqual(edited?.value, 5)
        XCTAssertNil(TraktorConditionMetadata.replacingValue(of: condition, with: 99))
        XCTAssertNil(TraktorConditionMetadata.replacingValue(of: ModifierCondition(modifier: 98765, value: 0), with: 5))
    }

    func testHotcueConditionCodableAndTSIRoundTrip() throws {
        var output = MappingEntry.output(commandID: 2333)
        output.modifier1Condition = ModifierCondition(modifier: 2333, value: 0, target: .deckA)
        output.modifier2Condition = ModifierCondition(modifier: 2334, value: 5, target: .deckB)
        let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [output])])
        let copied = try JSONDecoder().decode(MappingEntry.self, from: JSONEncoder().encode(output))
        XCTAssertEqual(copied.modifier1Condition, output.modifier1Condition)
        let parser = TSIParser()
        let binary = try parser.decodeBase64(TSIParser.extractControllerData(from: TSIWriter().write(file)))
        let decoded = try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary)).allMappings[0]
        XCTAssertEqual(decoded.modifier1Condition, output.modifier1Condition)
        XCTAssertEqual(decoded.modifier2Condition, output.modifier2Condition)
    }

    func testNativeReferenceProvesEmptyStateTargetsAndFractionalRange() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/TSI/traktor-4.5.1-led-ranges-hotcue-conditions.tsi")
        let document = try TraktorMappingDocument(fileContents: Data(contentsOf: url))
        let rows = document.mappingFile.allMappings
        XCTAssertEqual(rows.count, 6)
        XCTAssertEqual(rows[0].modifier1Condition, ModifierCondition(modifier: 2333, value: 0, target: .deckA))
        XCTAssertEqual(rows[0].modifier2Condition, ModifierCondition(modifier: 2334, value: 5, target: .deckB))
        XCTAssertEqual(rows[1].modifier1Condition?.value, Int(UInt32.max))
        XCTAssertEqual(rows[1].modifier2Condition, ModifierCondition(modifier: 2340, value: 0, target: .deckD))
        XCTAssertEqual(rows[2].modifier2Condition?.target, .deviceTarget)
        XCTAssertEqual(rows[3].modifier1Condition?.value, 1)
        XCTAssertEqual(rows[3].modifier2Condition?.value, 4)
        XCTAssertEqual(rows[4].modifier1Condition?.value, 2)
        XCTAssertEqual(rows[4].modifier2Condition?.value, 3)
        let gain = rows[5]
        XCTAssertEqual(gain.commandID, 117)
        XCTAssertEqual(gain.ledMinRangeType, 2)
        XCTAssertEqual(gain.ledMinRangeData, Int(Float(0.25).bitPattern))
        XCTAssertEqual(gain.ledMaxRangeData, Int(Float(0.75).bitPattern))
        XCTAssertEqual(LEDOutputSettings.text(for: .controllerMinimum, in: gain), "0.25")
        XCTAssertTrue(gain.ledBlend)
    }

    func testDeckCloneTranslatesCueTargetAndPreservesDeviceTargetAndLEDSettings() throws {
        var output = MappingEntry.output(commandID: 2333)
        output.assignment = .deckA
        output.modifier1Condition = ModifierCondition(modifier: 2333, value: Int(UInt32.max), target: .deckA)
        output.modifier2Condition = ModifierCondition(modifier: 2340, value: 5, target: .deviceTarget)
        output.ledMinMidi = 1
        output.ledMaxMidi = 12
        let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [output])])
        let plan = MappingTransformPlanner.plan(MappingTransformRequest(selectedMappingIDs: [output.id], destinations: [.deckB]), in: file)
        XCTAssertTrue(plan.reviewItems.isEmpty)
        let clone = try XCTUnwrap(plan.inserts.first?.mapping)
        XCTAssertEqual(clone.modifier1Condition?.target, .deckB)
        XCTAssertEqual(clone.modifier1Condition?.value, Int(UInt32.max))
        XCTAssertEqual(clone.modifier2Condition?.target, .deviceTarget)
        XCTAssertEqual(clone.ledMinMidi, 1)
        XCTAssertEqual(clone.ledMaxMidi, 12)
        XCTAssertEqual(clone.ledMinRangeData, output.ledMinRangeData)
    }

    func testExportedColourRulesAndContinuousOutput() throws {
        var cue = MappingEntry.output(commandID: 2333)
        cue.assignment = .deckA
        cue.midiAssignment = try .note(channel: 16, number: 120)
        cue.comment = "SXM cue: controller 0-0, MIDI 0-1, Cue condition"
        cue.modifier1Condition = ModifierCondition(modifier: 2333, value: 0, target: .deckA)
        cue = try LEDOutputSettings.Patch(controllerMinimum: "0", controllerMaximum: "0", midiMinimum: "0", midiMaximum: "1", blend: false, invert: false).applying(to: cue)
        var empty = cue.copyWithNewID()
        empty.comment = "SXM empty: controller -1 to -1, MIDI 0-0, No Hotcue condition"
        empty.modifier1Condition?.value = Int(UInt32.max)
        empty = try LEDOutputSettings.Patch(controllerMinimum: "-1", controllerMaximum: "-1", midiMaximum: "0").applying(to: empty)
        var loop = cue.copyWithNewID()
        loop.comment = "SXM loop: controller 5-5, MIDI 0-12, Loop condition"
        loop.modifier1Condition?.value = 5
        loop = try LEDOutputSettings.Patch(controllerMinimum: "5", controllerMaximum: "5", midiMaximum: "12").applying(to: loop)
        var gain = MappingEntry.output(commandID: 117)
        gain.comment = "SXM gain: controller 0.25-0.75, MIDI 10-100, Blend on, Invert on"
        gain.midiAssignment = try .controlChange(channel: 16, number: 119)
        gain = try LEDOutputSettings.Patch(controllerMinimum: "0.25", controllerMaximum: "0.75", midiMinimum: "10", midiMaximum: "100", blend: true, invert: true).applying(to: gain)
        let file = MappingFile(devices: [Device(name: "Generic MIDI", comment: "SXM generated LED validation TEMP", inPort: "None", outPort: "None", mappings: [cue, empty, loop, gain])])
        let data = try TSIWriter().write(file)
        let parser = TSIParser()
        let binary = try parser.decodeBase64(TSIParser.extractControllerData(from: data))
        let decoded = try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary)).allMappings
        XCTAssertEqual(decoded.count, 4)
        XCTAssertEqual(decoded[1].modifier1Condition?.value, Int(UInt32.max))
        XCTAssertEqual(decoded[1].ledMinRangeData, Int(UInt32.max))
        XCTAssertEqual(decoded[2].ledMaxMidi, 12)
        XCTAssertEqual(decoded[3].ledMinRangeData, Int(Float(0.25).bitPattern))
        XCTAssertTrue(decoded[3].ledInvert)
        // Opt-in artifact for a native Traktor compatibility probe. Normal
        // test runs have no file-system output beyond the test runner.
        if ProcessInfo.processInfo.environment["SXM_LED_GENERATE_VALIDATION"] == "1" {
            try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("sxm-led-generated-smoke.tsi"), options: .atomic)
        }
    }
}
