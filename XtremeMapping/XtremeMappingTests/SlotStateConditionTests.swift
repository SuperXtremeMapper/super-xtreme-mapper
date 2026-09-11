import XCTest
import SwiftUI
@testable import XtremeMapping

@MainActor
final class SlotStateConditionTests: XCTestCase {
    func testNativeStateChoicesAndExplicitTargetChangesPreserveValues() {
        XCTAssertEqual(TraktorConditionMetadata.values(for: 247).map(\.label), ["Empty", "Loaded", "Playing"])
        XCTAssertEqual(TraktorConditionMetadata.values(for: 247).map(\.rawValue), [0, 1, 2])
        let imported = ModifierCondition(modifier: 247, value: 99, target: .unknown(8))
        XCTAssertEqual(TraktorConditionMetadata.selectingDeckCondition(247, target: .unknown(15), previous: imported),
                       ModifierCondition(modifier: 247, value: 99, target: .unknown(15)))
        XCTAssertEqual(TraktorConditionMetadata.selectingDeckCondition(100, target: .deckA, previous: imported).value, 0)
        XCTAssertEqual(TraktorConditionMetadata.replacingValue(of: imported, with: 2),
                       ModifierCondition(modifier: 247, value: 2, target: .unknown(8)))
        XCTAssertNil(TraktorConditionMetadata.replacingValue(of: imported, with: 3))
        XCTAssertEqual(TraktorConditionMetadata.targets(for: 247).map(\.rawValue), Array(UInt32(0)..<16))
        XCTAssertFalse(TraktorConditionMetadata.targets(for: 247).contains(.deviceTarget))
    }

    func testNativeFixtureAndSingleValueEditPreserveOtherBytes() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/TSI/traktor-4.5.1-slot-state-conditions.tsi")
        let rows = try TraktorMappingDocument(fileContents: Data(contentsOf: url)).mappingFile.allMappings
        XCTAssertEqual(rows.count, 3)
        for (row, tuples) in zip(rows, [[(0, 0), (3, 1)], [(8, 1), (11, 2)], [(12, 2), (15, 0)]]) {
            for (actual, tuple) in zip([row.modifier1Condition, row.modifier2Condition], tuples) {
                XCTAssertEqual(actual, ModifierCondition(modifier: 247, value: tuple.1,
                    target: ModifierConditionTarget(rawValue: UInt32(tuple.0))))
            }
            for (keyPath, offset) in [(\MappingEntry.modifier1Condition, 8), (\MappingEntry.modifier2Condition, 20)] {
                var edited = row
                var expected = try TSIWriter().preservingCMADPayload(for: row)
                edited[keyPath: keyPath] = TraktorConditionMetadata.replacingValue(
                    of: try XCTUnwrap(row[keyPath: keyPath]), with: 2)
                let valueOffset = 52 + row.comment.utf16.count * 2 + offset
                expected.replaceSubrange(valueOffset..<(valueOffset + 4), with: [0, 0, 0, 2])
                XCTAssertEqual(try TSIWriter().preservingCMADPayload(for: edited), expected)
            }
        }
    }

    func testBothConditionSlotsSupportBatchUndoAndLock() {
        var first = MappingEntry.output(commandID: 100)
        first.modifier1Condition = ModifierCondition(modifier: 247, value: 1, target: .unknown(8))
        var second = first.copyWithNewID()
        second.modifier1Condition = nil
        let document = TraktorMappingDocument()
        document.mappingFile = MappingFile(devices: [Device(mappings: [first, second])])
        let original = document.mappingFile.allMappings
        let undo = UndoManager()
        undo.groupsByEvent = false
        let selection: Set<MappingEntry.ID> = [first.id, second.id]
        for slot in [\MappingEntry.modifier1Condition, \MappingEntry.modifier2Condition] {
            let choice = ModifierCondition(modifier: 247, value: 2, target: .unknown(15))
            let locked = V2ModifierRow(condition: .constant(first[keyPath: slot]), isLocked: true) { _ in
                XCTFail("Locked condition delivered a mutation")
            }
            locked.applySelection(choice)
            XCTAssertFalse(SettingsPanelV2.updateSelectedEntries(selection, in: document, isLocked: true, undoManager: undo) {
                $0[keyPath: slot] = choice
            })
            let row = V2ModifierRow(condition: .constant(first[keyPath: slot]), isLocked: false) { value in
                SettingsPanelV2.updateSelectedEntries(selection, in: document, isLocked: false, undoManager: undo) {
                    $0[keyPath: slot] = value
                }
            }
            undo.beginUndoGrouping()
            row.applySelection(choice)
            undo.endUndoGrouping()
            XCTAssertTrue(document.mappingFile.allMappings.allSatisfy { $0[keyPath: slot] == choice })
            undo.undo()
            XCTAssertEqual(document.mappingFile.allMappings, original)
            undo.redo()
            XCTAssertTrue(document.mappingFile.allMappings.allSatisfy { $0[keyPath: slot] == choice })
            undo.undo()
        }
    }

    func testUnsupportedSlotDeviceTargetIsPreservedButCannotBeCloned() {
        var row = MappingEntry.output(commandID: 100)
        row.assignment = .deckA
        row.modifier2Condition = ModifierCondition(modifier: 247, value: 1, target: .deviceTarget)
        XCTAssertEqual(row.modifier2Condition?.displayString, "Slot State · Target 4294967295 = Loaded")
        let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [row])])
        let plan = MappingTransformPlanner.plan(MappingTransformRequest(
            selectedMappingIDs: [row.id], destinations: [.deckB]), in: file)
        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertEqual(plan.reviewItems.first?.reason, .unknownConditionTarget(rawValue: UInt32.max))
    }

    func testSlotTargetsDisplayInTheirConditionContext() {
        XCTAssertEqual(ModifierCondition(modifier: 247, value: 99, target: .deckB).displayString,
                       "Slot State · Remix Deck A · Slot 2 = 99")
        XCTAssertEqual(ModifierCondition(modifier: 247, value: 99, target: .unknown(8)).displayString,
                       "Slot State · Remix Deck C · Slot 1 = 99")
        XCTAssertEqual(ModifierCondition(modifier: 247, value: 99, target: .unknown(15)).displayString,
                       "Slot State · Remix Deck D · Slot 4 = 99")
        XCTAssertEqual(ModifierCondition(modifier: 100, value: 1, target: .deckB).displayString,
                       "Deck Play · Deck B = On")
    }

    func testCloneTranslatesEveryDeckASlotAndPreservesOtherDeckSlots() throws {
        let destinations: [(DeckCloneDestination, UInt32)] = [(.deckB, 4), (.deckC, 8), (.deckD, 12)]
        for (destination, base) in destinations {
            for raw: UInt32 in 0..<16 {
                var row = MappingEntry.output(commandID: 100)
                row.assignment = .deckA
                row.modifier1Condition = ModifierCondition(modifier: 247, value: 1,
                    target: ModifierConditionTarget(rawValue: raw))
                // The same raw target has a different meaning for Deck Play.
                row.modifier2Condition = ModifierCondition(modifier: 100, value: 1, target: .deckB)
                let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [row])])
                let plan = MappingTransformPlanner.plan(MappingTransformRequest(
                    selectedMappingIDs: [row.id], destinations: [destination]), in: file)
                XCTAssertTrue(plan.reviewItems.isEmpty, "Slot target \(raw)")
                let clone = try XCTUnwrap(plan.inserts.first?.mapping)
                XCTAssertEqual(clone.modifier1Condition?.target.rawValue, raw < 4 ? base + raw : raw)
                XCTAssertEqual(clone.modifier1Condition?.value, 1)
                XCTAssertEqual(clone.modifier2Condition, row.modifier2Condition)
            }
        }
    }

    func testUnknownSlotTargetStillBlocksCloneAndRoundTripsUnchanged() throws {
        var row = MappingEntry.output(commandID: 100)
        row.assignment = .deckA
        row.modifier1Condition = ModifierCondition(modifier: 247, value: 99, target: .unknown(77))
        let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [row])])
        let plan = MappingTransformPlanner.plan(MappingTransformRequest(
            selectedMappingIDs: [row.id], destinations: [.deckB]), in: file)
        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertEqual(plan.reviewItems.first?.reason, .unknownConditionTarget(rawValue: 77))
        let imported = try TraktorMappingDocument(fileContents: TSIWriter().write(file))
        XCTAssertEqual(imported.mappingFile.allMappings.first?.modifier1Condition, row.modifier1Condition)
    }

    func testAllSlotTargetValueTuplesSurviveTSIAndCodableRoundTrip() throws {
        let rows = try (0..<16).flatMap { raw in
            try (0...2).map { value in
                var row = MappingEntry.output(commandID: 100)
                row.midiAssignment = try .note(channel: 16, number: raw * 3 + value)
                row.comment = "SXM slot target \(raw), value \(value)"
                row.modifier1Condition = ModifierCondition(modifier: 247, value: value,
                    target: ModifierConditionTarget(rawValue: UInt32(raw)))
                row.modifier2Condition = ModifierCondition(modifier: 247, value: 2 - value,
                    target: ModifierConditionTarget(rawValue: UInt32(15 - raw)))
                return row
            }
        }
        let file = MappingFile(devices: [Device(name: "Generic MIDI", comment: "SXM slot state generated TEMP",
            inPort: "None", outPort: "None", mappings: rows)])
        let imported = try TraktorMappingDocument(fileContents: TSIWriter().write(file))
        XCTAssertEqual(imported.mappingFile.allMappings.count, 48)
        for (actual, expected) in zip(imported.mappingFile.allMappings, rows) {
            XCTAssertEqual(actual.modifier1Condition, expected.modifier1Condition)
            XCTAssertEqual(actual.modifier2Condition, expected.modifier2Condition)
            let copied = try JSONDecoder().decode(MappingEntry.self, from: JSONEncoder().encode(actual))
            XCTAssertEqual(copied.modifier1Condition, expected.modifier1Condition)
            XCTAssertEqual(copied.modifier2Condition, expected.modifier2Condition)
        }
        if ProcessInfo.processInfo.environment["SXM_SLOT_GENERATE_VALIDATION"] == "1" {
            var probe = file
            probe.devices[0].mappings = (0..<16).map { rows[$0 * 3 + $0 % 3] }
            try TSIWriter().write(probe).write(to: FileManager.default.temporaryDirectory
                .appendingPathComponent("sxm-slot-state-generated.tsi"), options: .atomic)
        }
    }
}
