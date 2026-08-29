//
//  DeckClonePresentationTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

@MainActor
final class DeckClonePresentationTests: XCTestCase {
    func testCloneMenuUsesApprovedDestinationLabelsAndRequests() {
        XCTAssertEqual(
            DeckClonePresentation.menuOptions.map(\.title),
            ["Deck B", "Deck C", "Deck D", "Decks B, C and D"]
        )
        XCTAssertEqual(
            DeckClonePresentation.menuOptions.map(\.destinations),
            [
                [.deckB],
                [.deckC],
                [.deckD],
                [.deckB, .deckC, .deckD],
            ]
        )
    }

    func testCloneMenuRequiresUnlockedLiveEligibleSelection() {
        let deckA = MappingEntry(commandID: 100, assignment: .deckA)
        let remixDeckA = MappingEntry(commandID: 101, assignment: .remixDeckASlot3)
        let global = MappingEntry(commandID: 102, assignment: .global)
        let file = MappingFile(devices: [
            Device(mappings: [deckA, remixDeckA, global]),
        ])
        let staleID = UUID()

        XCTAssertTrue(
            DeckClonePresentation.isCloneEnabled(
                isLocked: false,
                selectedMappingIDs: [deckA.id, global.id],
                in: file
            )
        )
        XCTAssertTrue(
            DeckClonePresentation.isCloneEnabled(
                isLocked: false,
                selectedMappingIDs: [remixDeckA.id],
                in: file
            )
        )
        XCTAssertFalse(
            DeckClonePresentation.isCloneEnabled(
                isLocked: true,
                selectedMappingIDs: [deckA.id],
                in: file
            )
        )
        XCTAssertFalse(
            DeckClonePresentation.isCloneEnabled(
                isLocked: false,
                selectedMappingIDs: [global.id, staleID],
                in: file
            )
        )
        XCTAssertFalse(
            DeckClonePresentation.isCloneEnabled(
                isLocked: false,
                selectedMappingIDs: [],
                in: file
            )
        )
    }

    func testReviewUsesOnlyApprovedPlainChoiceLabels() {
        XCTAssertEqual(
            MappingTransformReviewChoice.allCases.map(\.deckCloneTitle),
            ["Keep Existing", "Create Another", "Replace Existing"]
        )
    }

    func testChangeMenuOffersEveryMIDIChannelExactlyOnce() {
        XCTAssertEqual(DeckClonePresentation.midiChannels, Array(1...16))
    }

    func testStatusUsesExecutorSentenceAndSuppressesTrueNoOp() {
        let createdIDs = Set([UUID(), UUID()])
        let result = MappingTransformExecutionResult(
            createdIDs: createdIDs,
            duplicateSkipCount: 1,
            ignoredCount: 3
        )
        let noOp = MappingTransformExecutionResult(
            createdIDs: [],
            duplicateSkipCount: 0,
            ignoredCount: 0
        )

        XCTAssertEqual(
            DeckClonePresentation.statusText(for: result),
            "2 mappings created. 1 duplicate skipped. 3 other mappings ignored."
        )
        XCTAssertNil(DeckClonePresentation.statusText(for: noOp))
    }

    func testReviewHeadingUsesPlainSingularAndPluralCopy() {
        XCTAssertEqual(DeckClonePresentation.reviewHeading(itemCount: 1), "1 mapping needs review.")
        XCTAssertEqual(DeckClonePresentation.reviewHeading(itemCount: 2), "2 mappings need review.")
    }

    func testReviewStateRetainsPlannedCloneAndRequiresEveryConflictChoice() throws {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10
        )
        let existing = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 11
        )
        let file = MappingFile(devices: [Device(mappings: [source, existing])])
        let plannedID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB],
                makeMappingID: { plannedID }
            ),
            in: file
        )
        let item = try XCTUnwrap(plan.reviewItems.first)
        var state = DeckCloneReviewState(plan: plan)

        XCTAssertEqual(state.plan.reviewItems.first?.proposedMapping?.id, plannedID)
        XCTAssertFalse(state.canApply)

        state.setChoice(.createAnother, for: item)

        XCTAssertTrue(state.canApply)
        XCTAssertEqual(state.choices, [item.id: .createAnother])
        XCTAssertEqual(state.plan.reviewItems.first?.proposedMapping?.id, plannedID)
    }

    func testUnknownTargetReviewCannotOfferUnsafeChoiceOrApply() throws {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            modifier1Condition: ModifierCondition(
                modifier: 1,
                value: 1,
                target: .unknown(99)
            )
        )
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB]
            ),
            in: MappingFile(devices: [Device(mappings: [source])])
        )
        let item = try XCTUnwrap(plan.reviewItems.first)
        let state = DeckCloneReviewState(plan: plan)

        XCTAssertEqual(state.options(for: item), [])
        XCTAssertFalse(state.canApply)
    }
}
