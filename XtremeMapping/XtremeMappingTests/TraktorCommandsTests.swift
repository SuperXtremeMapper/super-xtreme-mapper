//
//  TraktorCommandsTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import XCTest
@testable import XtremeMapping

final class TraktorCommandsTests: XCTestCase {

    // MARK: - Known Command Lookup Tests

    func testPlayPauseCommand() {
        XCTAssertEqual(TraktorCommands.name(for: 100), "Play/Pause")
    }

    func testVolumeCommand() {
        XCTAssertEqual(TraktorCommands.name(for: 102), "Volume")
    }

    func testCueCommand() {
        XCTAssertEqual(TraktorCommands.name(for: 206), "Cue")
    }

    func testFilterCommand() {
        XCTAssertEqual(TraktorCommands.name(for: 320), "Filter")
    }

    func testFXDryWetCommand() {
        XCTAssertEqual(TraktorCommands.name(for: 365), "FX Dry/Wet")
    }

    func testSamplePageSelectorCommand() {
        XCTAssertEqual(TraktorCommands.name(for: 733), "Sample Page Selector")
    }

    func testEQCommands() {
        XCTAssertEqual(TraktorCommands.name(for: 301), "EQ Low")
        XCTAssertEqual(TraktorCommands.name(for: 302), "EQ Mid")
        XCTAssertEqual(TraktorCommands.name(for: 303), "EQ High")
    }

    func testFXUnitOnCommands() {
        XCTAssertEqual(TraktorCommands.name(for: 321), "FX Unit 1 On")
        XCTAssertEqual(TraktorCommands.name(for: 322), "FX Unit 2 On")
        XCTAssertEqual(TraktorCommands.name(for: 338), "FX Unit 3 On")
        XCTAssertEqual(TraktorCommands.name(for: 339), "FX Unit 4 On")
    }

    func testBrowserCommands() {
        XCTAssertEqual(TraktorCommands.name(for: 3200), "Browser Select Up/Down")
        XCTAssertEqual(TraktorCommands.name(for: 3221), "Browser Search")
    }

    // MARK: - Slot Cell Trigger Range Tests (601-664)

    func testSlot1CellTriggerRange() {
        XCTAssertEqual(TraktorCommands.name(for: 601), "Slot 1 Cell 1 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 608), "Slot 1 Cell 8 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 616), "Slot 1 Cell 16 Trigger")
    }

    func testSlot2CellTriggerRange() {
        XCTAssertEqual(TraktorCommands.name(for: 617), "Slot 2 Cell 1 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 624), "Slot 2 Cell 8 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 632), "Slot 2 Cell 16 Trigger")
    }

    func testSlot3CellTriggerRange() {
        XCTAssertEqual(TraktorCommands.name(for: 633), "Slot 3 Cell 1 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 640), "Slot 3 Cell 8 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 648), "Slot 3 Cell 16 Trigger")
    }

    func testSlot4CellTriggerRange() {
        XCTAssertEqual(TraktorCommands.name(for: 649), "Slot 4 Cell 1 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 656), "Slot 4 Cell 8 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 664), "Slot 4 Cell 16 Trigger")
    }

    // MARK: - Slot Cell State Range Tests (665-728)

    func testSlot1CellStateRange() {
        XCTAssertEqual(TraktorCommands.name(for: 665), "Slot 1 Cell 1 State")
        XCTAssertEqual(TraktorCommands.name(for: 672), "Slot 1 Cell 8 State")
        XCTAssertEqual(TraktorCommands.name(for: 680), "Slot 1 Cell 16 State")
    }

    func testSlot2CellStateRange() {
        XCTAssertEqual(TraktorCommands.name(for: 681), "Slot 2 Cell 1 State")
        XCTAssertEqual(TraktorCommands.name(for: 688), "Slot 2 Cell 8 State")
        XCTAssertEqual(TraktorCommands.name(for: 696), "Slot 2 Cell 16 State")
    }

    func testSlot3CellStateRange() {
        XCTAssertEqual(TraktorCommands.name(for: 697), "Slot 3 Cell 1 State")
        XCTAssertEqual(TraktorCommands.name(for: 704), "Slot 3 Cell 8 State")
        XCTAssertEqual(TraktorCommands.name(for: 712), "Slot 3 Cell 16 State")
    }

    func testSlot4CellStateRange() {
        XCTAssertEqual(TraktorCommands.name(for: 713), "Slot 4 Cell 1 State")
        XCTAssertEqual(TraktorCommands.name(for: 720), "Slot 4 Cell 8 State")
        XCTAssertEqual(TraktorCommands.name(for: 728), "Slot 4 Cell 16 State")
    }

    // MARK: - Modifier Range Tests (2548-2555)

    func testModifierRange() {
        XCTAssertEqual(TraktorCommands.name(for: 2548), "Modifier #1")
        XCTAssertEqual(TraktorCommands.name(for: 2549), "Modifier #2")
        XCTAssertEqual(TraktorCommands.name(for: 2550), "Modifier #3")
        XCTAssertEqual(TraktorCommands.name(for: 2551), "Modifier #4")
        XCTAssertEqual(TraktorCommands.name(for: 2552), "Modifier #5")
        XCTAssertEqual(TraktorCommands.name(for: 2553), "Modifier #6")
        XCTAssertEqual(TraktorCommands.name(for: 2554), "Modifier #7")
        XCTAssertEqual(TraktorCommands.name(for: 2555), "Modifier #8")
    }

    // MARK: - Duplicate Track Deck Range Tests (2401-2404)

    func testDuplicateTrackDeckRange() {
        XCTAssertEqual(TraktorCommands.name(for: 2401), "Duplicate Track Deck A")
        XCTAssertEqual(TraktorCommands.name(for: 2402), "Duplicate Track Deck B")
        XCTAssertEqual(TraktorCommands.name(for: 2403), "Duplicate Track Deck C")
        XCTAssertEqual(TraktorCommands.name(for: 2404), "Duplicate Track Deck D")
    }

    // MARK: - Per-Slot Command Tests (2900-2923)

    func testPerSlotCommandIds() {
        // Test Slot Volume commands
        XCTAssertEqual(TraktorCommands.id(for: "Slot 1 Volume"), 2900)
        XCTAssertEqual(TraktorCommands.id(for: "Slot 2 Volume"), 2901)
        XCTAssertEqual(TraktorCommands.id(for: "Slot 3 Volume"), 2902)
        XCTAssertEqual(TraktorCommands.id(for: "Slot 4 Volume"), 2903)

        // Test Slot Mute commands
        XCTAssertEqual(TraktorCommands.id(for: "Slot 1 Mute"), 2904)
        XCTAssertEqual(TraktorCommands.id(for: "Slot 4 Mute"), 2907)

        // Test Slot Filter commands
        XCTAssertEqual(TraktorCommands.id(for: "Slot 1 Filter"), 2908)
        XCTAssertEqual(TraktorCommands.id(for: "Slot 1 Filter On"), 2912)

        // Test Slot FX commands
        XCTAssertEqual(TraktorCommands.id(for: "Slot 1 FX Send"), 2916)
        XCTAssertEqual(TraktorCommands.id(for: "Slot 1 FX On"), 2920)
    }

    func testPerSlotCommandNames() {
        // Test reverse lookup
        XCTAssertEqual(TraktorCommands.name(for: 2900), "Slot 1 Volume")
        XCTAssertEqual(TraktorCommands.name(for: 2903), "Slot 4 Volume")
        XCTAssertEqual(TraktorCommands.name(for: 2907), "Slot 4 Mute")
        XCTAssertEqual(TraktorCommands.name(for: 2920), "Slot 1 FX On")
    }

    // MARK: - Dynamic Name <-> ID Round-Trip Tests (Task 1.2)

    func testDynamicCommandNameIdRoundTrip() {
        let ranges: [ClosedRange<Int>] = [601...728, 2401...2404, 2548...2555, 2688...2703, 2900...2923]
        for range in ranges {
            for commandId in range {
                let name = TraktorCommands.name(for: commandId)
                XCTAssertEqual(
                    TraktorCommands.id(for: name), commandId,
                    "ID \(commandId) -> '\(name)' did not round-trip back to \(commandId)"
                )
            }
        }
    }

    // MARK: - Unknown Command Fallback Tests

    func testUnknownCommandReturnsCommandNumber() {
        XCTAssertEqual(TraktorCommands.name(for: 99999), "Command #99999")
    }

    func testZeroCommandReturnsCommandNumber() {
        XCTAssertEqual(TraktorCommands.name(for: 0), "Command #0")
    }

    func testNegativeCommandReturnsCommandNumber() {
        XCTAssertEqual(TraktorCommands.name(for: -1), "Command #-1")
    }

    // MARK: - Edge Cases

    func testBoundaryBetweenSlot4TriggerAndSlot1State() {
        // 664 is last Slot 4 Cell Trigger, 665 is first Slot 1 Cell State
        XCTAssertEqual(TraktorCommands.name(for: 664), "Slot 4 Cell 16 Trigger")
        XCTAssertEqual(TraktorCommands.name(for: 665), "Slot 1 Cell 1 State")
    }

    func testBoundaryBetweenSlot4StateAndSamplePageSelector() {
        // 728 is last Slot 4 Cell State, 729-733 are other commands
        XCTAssertEqual(TraktorCommands.name(for: 728), "Slot 4 Cell 16 State")
        XCTAssertEqual(TraktorCommands.name(for: 733), "Sample Page Selector")
    }

    func testGapBetweenRanges() {
        // 729-732 are individual commands, not in a range
        XCTAssertEqual(TraktorCommands.name(for: 729), "Cell Load Modifier")
        XCTAssertEqual(TraktorCommands.name(for: 730), "Cell Delete Modifier")
        XCTAssertEqual(TraktorCommands.name(for: 731), "Cell Reverse Modifier")
        XCTAssertEqual(TraktorCommands.name(for: 732), "Cell Capture Modifier")
    }

    // MARK: - Duplicate Name / Deterministic Resolution Tests (M8)

    func testCommandLookupNamesAreUnique() {
        // Two distinct Traktor commands must never share a display name —
        // id(for:) would otherwise silently rewrite one to the other on save.
        var seen: [String: Int] = [:]
        for (id, name) in TraktorCommands.commandLookup {
            if let existing = seen[name] {
                XCTFail("Duplicate command name '\(name)' for IDs \(min(existing, id)) and \(max(existing, id))")
            }
            seen[name] = id
        }
    }

    func testLoopOutCommandsAreDistinctAndRoundTrip() {
        // 201 (CUE/LOOP "Loop Out") and 2393 (advanced-deck "Loop Out / Set",
        // paired with 2392 "Loop In / Set Cue") are different commands.
        XCTAssertEqual(TraktorCommands.name(for: 201), "Loop Out")
        XCTAssertEqual(TraktorCommands.name(for: 2393), "Loop Out / Set")
        XCTAssertEqual(TraktorCommands.id(for: TraktorCommands.name(for: 201)), 201)
        XCTAssertEqual(TraktorCommands.id(for: TraktorCommands.name(for: 2393)), 2393)
        XCTAssertTrue(TraktorCommands.isKnownCommand("Loop Out"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Loop Out / Set"))
    }

    func testCommandHierarchyConsistentWithCommandLookup() {
        // Every menu item must resolve to its own ID — ContentView creates
        // mappings from hierarchy NAMES, so a name that resolves elsewhere
        // would silently map a different command than the one clicked.
        func walk(_ categories: [CommandCategory2]) {
            for category in categories {
                if let subcategories = category.subcategories {
                    walk(subcategories)
                }
                for item in category.commands ?? [] {
                    XCTAssertEqual(
                        TraktorCommands.id(for: item.name), item.id,
                        "Hierarchy item '\(item.name)' (id \(item.id)) resolves to \(TraktorCommands.id(for: item.name))"
                    )
                }
            }
        }
        walk(CommandHierarchy.categories)
    }

    // MARK: - isKnownCommand Tests (Task 2.3)

    func testIsKnownCommandAcceptsLookupTableNames() {
        XCTAssertTrue(TraktorCommands.isKnownCommand("Play/Pause"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Volume"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("FX Dry/Wet"))
    }

    func testIsKnownCommandAcceptsDynamicRangeNames() {
        XCTAssertTrue(TraktorCommands.isKnownCommand("Slot 2 Cell 5 State"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Slot 3 Cell 16 Trigger"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Duplicate Track Deck C"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Deck B Post-Fader Level (R)"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Modifier #3"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Slot 4 FX On"))
    }

    func testIsKnownCommandRejectsUnknownNames() {
        XCTAssertFalse(TraktorCommands.isKnownCommand("Totally Made Up Knob"))
        XCTAssertFalse(TraktorCommands.isKnownCommand(""))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Slot 9 Cell 99 State"))
    }

    func testIsKnownCommandRejectsOutOfRangeDynamicNames() {
        // id(for:) reverse-parses dynamic families without bounds checks
        // ("Slot 1 Cell 17 Trigger" → 617, which is really Slot 2 Cell 1) —
        // the round-trip check must reject anything name(for:) wouldn't produce.
        XCTAssertFalse(TraktorCommands.isKnownCommand("Slot 1 Cell 17 Trigger"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Slot 1 Cell 999 Trigger"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Modifier #-1"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Modifier #999"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Modifier #9"))
        // In-range neighbours stay accepted
        XCTAssertTrue(TraktorCommands.isKnownCommand("Slot 1 Cell 16 Trigger"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Modifier #8"))
    }

    func testIsKnownCommandRejectsCommandNumberFallbackStrings() {
        // id(for:) parses any "Command #N" back to N, so these resolve to a
        // nonzero ID — they must still be rejected as unknown.
        XCTAssertFalse(TraktorCommands.isKnownCommand("Command #99999"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Command #100"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Command #0"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Command #-1"))
    }
}
