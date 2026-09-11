import XCTest
@testable import XtremeMapping

final class Issue9CompatibilityTests: XCTestCase {
    func testNativeLoadingAlternativeIdentityAndNoOpPreservation() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/TSI/traktor-4.5.1-load-selected-alternative.tsi")
        let source = try Data(contentsOf: url)
        let file = try TSIParser().parseDocument(source)
        XCTAssertEqual(file.allMappings.count, 1)
        XCTAssertEqual(file.allMappings.first?.commandID, 3079)
        XCTAssertEqual(TraktorCommands.name(for: 3079), "Load Selected (loading alternative)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 3079).verification, .legacy)
        XCTAssertTrue(TraktorCommands.descriptor(for: 3079).supportedDirections.isEmpty)
        XCTAssertEqual(try TSIWriter().write(file), source)
    }

    func testImportedInternalMIDIControlsUseGlobalTargetInBothDirections() throws {
        for id in 850...873 {
            for direction in [IODirection.input, .output] {
                let row = MappingEntry(commandID: id, ioType: direction, assignment: .global,
                                       midiChannel: 1, midiCC: 10)
                let source = try TSIWriter().write(MappingFile(devices: [Device(name: "Synthetic", mappings: [row])]))
                let imported = try TSIParser().parseDocument(source)
                XCTAssertEqual(imported.allMappings.first?.assignment, .global)
                XCTAssertEqual(try TSIWriter().write(imported), source)
            }
        }
    }

    func testInternalMIDIFamiliesAndStatusCommandsHaveNames() {
        let names = [520: "Track End Warning", 874: "Flux Reverse Playback On",
                     3079: "Load Selected (loading alternative)"]
            .merging(Dictionary(uniqueKeysWithValues: (850...873).map { id in
                let family = ["Button", "Knob", "Fader"][(id - 850) / 8]
                return (id, "MIDI \(family) \((id - 850) % 8 + 1)")
            })) { first, _ in first }
        for (id, name) in names {
            XCTAssertEqual(TraktorCommands.name(for: id), name)
            XCTAssertEqual(TraktorCommands.id(for: name), id)
            XCTAssertNotEqual(TraktorCommands.descriptor(for: id).verification, .unknown)
        }
    }

    func testRemixCellConditionsAcrossAllSlotsAndCells() {
        for id in 665...728 {
            let slot = (id - 665) / 16 + 1
            let cell = (id - 665) % 16 + 1
            XCTAssertEqual(TraktorConditionMetadata.name(for: id), "Slot \(slot) Cell \(cell) State")
            XCTAssertEqual(TraktorConditionMetadata.values(for: id).map(\.label), ["Empty", "Loaded", "Playing", "Waiting"])
            XCTAssertTrue(TraktorConditionMetadata.targetedConditionIDs.contains(id))
            XCTAssertEqual(TraktorConditionMetadata.targets(for: id).map(\.rawValue), [0, 1, 2, 3, UInt32.max])
            let original = ModifierCondition(modifier: id, value: 99, target: .deckC)
            XCTAssertEqual(TraktorConditionMetadata.replacingValue(of: original, with: 3),
                           ModifierCondition(modifier: id, value: 3, target: .deckC))
            XCTAssertEqual(TraktorConditionMetadata.selectingDeckCondition(728, target: .deckD, previous: original).value, 99)
            XCTAssertEqual(TraktorConditionMetadata.selectingDeckCondition(2302, target: .deckA, previous: original).value, 0)
        }
    }

    func testDeckFlavorConditionsUseReadableValuesWithoutReinterpretingUnknowns() {
        XCTAssertEqual(TraktorConditionMetadata.name(for: 2302), "Deck Flavor")
        XCTAssertEqual(TraktorConditionMetadata.values(for: 2302).map(\.label), ["Track Deck", "Remix Deck", "Stem Deck", "Live Input"])
        XCTAssertTrue(TraktorConditionMetadata.targetedConditionIDs.contains(2302))
        XCTAssertEqual(TraktorConditionMetadata.targets(for: 2302).map(\.rawValue), [0, 1, 2, 3, UInt32.max])
        let condition = ModifierCondition(modifier: 2302, value: 99, target: .unknown(42))
        XCTAssertEqual(condition.displayString, "Deck Flavor · Target 42 = 99")
        XCTAssertEqual(TraktorConditionMetadata.selectingDeckCondition(2302, target: .deckB, previous: condition).value, 99)
        XCTAssertNil(TraktorConditionMetadata.replacingValue(of: condition, with: 4))
    }
    func testConditionValueEditPreservesEveryOtherImportedByte() throws {
        for id in [665, 680, 681, 696, 697, 712, 713, 728, 2302] {
            var original = MappingEntry(commandID: 100, ioType: .input, assignment: .deckA,
                                        midiChannel: 1, midiCC: 23)
            original.comment = "Synthetic condition preservation"
            original.modifier1Condition = ModifierCondition(modifier: id, value: 99, target: .deckC)
            original.modifier2Condition = ModifierCondition(modifier: id, value: 0, target: .deviceTarget)
            let xml = try TSIWriter().write(MappingFile(devices: [Device(name: "Synthetic", mappings: [original])]))
            let imported = try XCTUnwrap(TSIParser().parseDocument(xml).allMappings.first)
            for (slot, offset) in [(\MappingEntry.modifier1Condition, 8), (\MappingEntry.modifier2Condition, 20)] {
                var edited = imported
                edited[keyPath: slot] = TraktorConditionMetadata.replacingValue(of: try XCTUnwrap(imported[keyPath: slot]), with: 3)
                var expected = try TSIWriter().preservingCMADPayload(for: imported)
                let valueOffset = 52 + imported.comment.utf16.count * 2 + offset
                expected.replaceSubrange(valueOffset..<(valueOffset + 4), with: [0, 0, 0, 3])
                XCTAssertEqual(try TSIWriter().preservingCMADPayload(for: edited), expected)
                var file = try TSIParser().parseDocument(xml)
                file.devices[0].mappings[0] = edited
                let reimported = try TSIParser().parseDocument(TSIWriter().write(file))
                XCTAssertEqual(reimported.allMappings.first?[keyPath: slot], edited[keyPath: slot])
            }
        }
    }

}
