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

    // MARK: - Canonical Slot Commands (replacing legacy fabricated 2900-2923)
    //
    // The 2900-2923 block was a Traktor-3-era fabrication. Traktor 4.4 uses
    // canonical Remix Deck commands with CMAD target = deckIndex * 4 + slotIndex.
    // Verify the canonical names resolve to their real IDs.
    func testCanonicalSlotCommandIds() {
        XCTAssertEqual(TraktorCommands.id(for: "Slot Volume"), 251)
        XCTAssertEqual(TraktorCommands.id(for: "Slot Mute On"), 259)
        XCTAssertEqual(TraktorCommands.id(for: "Slot Filter Adjust"), 249)
        XCTAssertEqual(TraktorCommands.id(for: "Slot Filter On"), 250)
        XCTAssertEqual(TraktorCommands.id(for: "Slot FX On"), 239)
    }

    // MARK: - Dynamic Name <-> ID Round-Trip Tests (Task 1.2)

    func testDynamicCommandNameIdRoundTrip() {
        let ranges: [ClosedRange<Int>] = [601...728, 2401...2404, 2548...2555]
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
        XCTAssertEqual(TraktorCommands.name(for: 99999), "Unknown command #99999")
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

    func testCommandLookupNamesHaveOnlyAuditedAmbiguity() {
        // 513 is a newly observed output descriptor whose native label is the
        // same as legacy ID 2251. ID-driven creation avoids the ambiguity and
        // the frozen legacy resolver deliberately keeps 2251 for name-only data.
        var seen: [String: Int] = [:]
        for (id, name) in TraktorCommands.commandLookup {
            if let existing = seen[name] {
                XCTAssertEqual(name, "Beat Phase")
                XCTAssertEqual(Set([existing, id]), Set([513, 2251]))
            }
            seen[name] = id
        }
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Beat Phase"), 2251)
    }

    func testLoopOutCommandsAreDistinctAndRoundTrip() {
        // 201 was mislabeled "Loop Out" in the legacy app catalog; the
        // canonical descriptor must use the audited Traktor 4.4.1 meaning.
        XCTAssertEqual(TraktorCommands.name(for: 201), "Reverse Playback On")
        XCTAssertEqual(TraktorCommands.name(for: 2393), "Loop Out / Set")
        XCTAssertEqual(TraktorCommands.id(for: TraktorCommands.name(for: 201)), 201)
        XCTAssertEqual(TraktorCommands.id(for: TraktorCommands.name(for: 2393)), 2393)
        XCTAssertTrue(TraktorCommands.isKnownCommand("Reverse Playback On"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Loop Out / Set"))
    }

    func testCommandHierarchyConsistentWithCommandLookup() {
        // Hierarchy labels are resolved from the authoritative descriptor,
        // rather than maintained as an independent copy.
        func walk(_ categories: [CommandCategory2]) {
            for category in categories {
                if let subcategories = category.subcategories {
                    walk(subcategories)
                }
                for item in category.commands ?? [] {
                    XCTAssertEqual(item.descriptor, TraktorCommands.descriptor(for: item.id))
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
        XCTAssertTrue(TraktorCommands.isKnownCommand("Deck Post-Fader Level (R)"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Modifier #3"))
        XCTAssertTrue(TraktorCommands.isKnownCommand("Slot FX On"))
    }

    func testIsKnownCommandRejectsUnknownNames() {
        XCTAssertFalse(TraktorCommands.isKnownCommand("Totally Made Up Knob"))
        XCTAssertFalse(TraktorCommands.isKnownCommand(""))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Slot 9 Cell 99 State"))
        XCTAssertFalse(TraktorCommands.isKnownCommand("Slot 4 FX On"))
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

    // MARK: - Audited Traktor 4.4.1 Catalog

    func testUnknownPositiveIDGetsStableUnknownDescriptor() {
        let descriptor = TraktorCommands.descriptor(for: 4242)
        XCTAssertEqual(descriptor.id, 4242)
        XCTAssertEqual(descriptor.name, "Unknown command #4242")
        XCTAssertEqual(descriptor.verification, .unknown)
        XCTAssertTrue(descriptor.supportedDirections.isEmpty)
    }

    func testZeroIsInvalidRatherThanUnknown() {
        let descriptor = TraktorCommands.descriptor(for: 0)
        XCTAssertEqual(descriptor.id, 0)
        XCTAssertEqual(descriptor.verification, .legacy)
        XCTAssertTrue(descriptor.supportedDirections.isEmpty)
    }

    func testKnownUnverifiedCommandIsLegacyNotCreatable() {
        let descriptor = TraktorCommands.descriptor(for: 8194)
        XCTAssertEqual(descriptor.verification, .legacy)
        XCTAssertNil(TraktorCommands.verifiedDescriptor(named: descriptor.name, supporting: .input))
    }

    func testMeterCommandsUseTargetSelectedIDs() {
        XCTAssertEqual(TraktorCommands.descriptor(for: 2688).name, "Deck Pre-Fader Level (L)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 2689).name, "Deck Pre-Fader Level (R)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 2690).name, "Deck Post-Fader Level (L)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 2691).name, "Deck Post-Fader Level (R)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 2703).name, "Master Out Level (L+R)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 2712).name, "Deck Pre-Fader Level (L+R)")
        XCTAssertEqual(TraktorCommands.descriptor(for: 2713).name, "Deck Post-Fader Level (L+R)")
    }

    func testConfirmedSemanticConflictsAreCorrected() {
        XCTAssertEqual(TraktorCommands.descriptor(for: 201).name, "Reverse Playback On")
        XCTAssertEqual(TraktorCommands.descriptor(for: 203).name, "Is In Active Loop")
        XCTAssertEqual(TraktorCommands.descriptor(for: 736).name, "Current Step")
        XCTAssertEqual(TraktorCommands.descriptor(for: 738).name, "Pattern Length")
        XCTAssertEqual(TraktorCommands.descriptor(for: 3139).name, "Load Preview Player into Deck")
    }

    func testCreationHierarchyContainsOnlyDirectionVerifiedCommands() {
        let commands = CommandHierarchy.flatten(CommandHierarchy.verifiedCategories(for: .input))
        XCTAssertFalse(commands.isEmpty)
        XCTAssertTrue(commands.allSatisfy { $0.verification == .verifiedTraktor441 })
        XCTAssertTrue(commands.allSatisfy { $0.supportedDirections.contains(.input) })
        XCTAssertFalse(commands.contains { $0.id == 2688 })
        XCTAssertFalse(commands.contains { $0.id == 728 })

        let paired = CommandHierarchy.flatten(CommandHierarchy.verifiedCategories(for: .all))
        XCTAssertTrue(paired.allSatisfy {
            $0.supportedDirections.isSuperset(of: [.input, .output])
        })
    }

    func testAuditedEvidenceCountsStayConservative() {
        XCTAssertEqual(Traktor441CommandEvidence.inputOnlyIDs.count, 85)
        XCTAssertEqual(Traktor441CommandEvidence.outputOnlyIDs.count, 79)
        XCTAssertEqual(Traktor441CommandEvidence.bothDirectionIDs.count, 72)
        XCTAssertEqual(
            Traktor441CommandEvidence.correctedOutputOnlyIDs.count
                + Traktor441CommandEvidence.correctedBothDirectionIDs.count,
            9
        )
    }

    func testObservedMissingDescriptorsAreVerifiedInTheirAuditedDirections() {
        XCTAssertNotNil(TraktorCommands.verifiedDescriptor(named: "Slot FX Amount (Submix)", supporting: .input))
        XCTAssertNotNil(TraktorCommands.verifiedDescriptor(named: "Beat Phase", supporting: .output))
        XCTAssertNotNil(TraktorCommands.verifiedDescriptor(named: "Selected Sample", supporting: .input))
        for step in 1...16 {
            let name = "Enable Step \(step)"
            XCTAssertNotNil(TraktorCommands.verifiedDescriptor(named: name, supporting: .input))
            XCTAssertNotNil(TraktorCommands.verifiedDescriptor(named: name, supporting: .output))
        }
    }

    func testAllNamesContainsOnlyVerifiedInputCommands() {
        XCTAssertEqual(
            TraktorCommands.allNames,
            TraktorCommands.verifiedDescriptors(supporting: .input).map(\.name)
        )
        XCTAssertFalse(TraktorCommands.allNames.contains("Cruise Mode On"))
        XCTAssertFalse(TraktorCommands.allNames.contains("Beat Phase"))
    }

    func testLegacyRenamedLabelsStillResolveToTheirHistoricIDs() {
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Loop Out"), 201)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Reloop"), 203)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Slot BPM Sync"), 261)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Slot Color"), 262)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Step Sequencer Pattern Length"), 736)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Step Sequencer Selected Sound"), 738)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Main Level (L)"), 2704)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "FX Unit 2 Level"), 2712)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "FX Unit 3 Level"), 2713)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Preview Player Position"), 3139)
        XCTAssertEqual(TraktorCommands.id(forLegacyName: "Play/Pause (Deck Common)"), 100)
    }

    func testLegacyDeckMeterLabelsStillResolveToTheirHistoricIDs() {
        let families: [(suffix: String, base: Int)] = [
            (" Pre-Fader Level (L)", 2688),
            (" Pre-Fader Level (R)", 2692),
            (" Post-Fader Level (L)", 2696),
            (" Post-Fader Level (R)", 2700),
        ]
        for (suffix, base) in families {
            for (index, deck) in ["A", "B", "C", "D"].enumerated() {
                XCTAssertEqual(
                    TraktorCommands.id(forLegacyName: "Deck \(deck)\(suffix)"),
                    base + index
                )
            }
        }
    }
}
