//
//  MappingTransformServiceTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

final class MappingTransformServiceTests: XCTestCase {
    func testDeckACloneTranslatesEachRequestedDestinationAndPreservesSource() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 7,
            midiCC: 42,
            modifier1Condition: ModifierCondition(
                modifier: 3,
                value: 2,
                target: .deckA
            ),
            comment: "Deck A transport",
            controllerType: .button,
            invert: true,
            autoRepeat: true
        )
        let file = MappingFile(devices: [Device(name: "Controller", mappings: [source])])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckD, .deckB, .deckC]
            ),
            in: file
        )

        XCTAssertEqual(plan.inserts.map(\.destination), [.deckB, .deckC, .deckD])
        XCTAssertEqual(plan.inserts.map(\.mapping.assignment), [.deckB, .deckC, .deckD])
        XCTAssertEqual(
            plan.inserts.map { $0.mapping.modifier1Condition?.target },
            [.deckB, .deckC, .deckD]
        )
        XCTAssertEqual(
            plan.inserts.map(\.mapping.comment),
            ["Deck B transport", "Deck C transport", "Deck D transport"]
        )
        XCTAssertEqual(plan.inserts.map(\.mapping.midiChannel), [7, 7, 7])
        XCTAssertEqual(plan.inserts.map(\.mapping.midiCC), [42, 42, 42])
        XCTAssertEqual(plan.inserts.map(\.mapping.interactionMode), [.hold, .hold, .hold])
        XCTAssertTrue(plan.inserts.allSatisfy { $0.mapping.invert && $0.mapping.autoRepeat })
        XCTAssertEqual(file.devices[0].mappings, [source])
    }

    func testSingleDestinationRequestsCloneDeckAToBCTAndD() {
        let source = MappingEntry(commandID: 100, assignment: .deckA)
        let file = MappingFile(devices: [Device(name: "Controller", mappings: [source])])

        let assignments = [DeckCloneDestination.deckB, .deckC, .deckD].map { destination in
            MappingTransformPlanner.plan(
                MappingTransformRequest(
                    selectedMappingIDs: [source.id],
                    destinations: [destination]
                ),
                in: file
            ).inserts.map(\.mapping.assignment)
        }

        XCTAssertEqual(assignments, [[.deckB], [.deckC], [.deckD]])
    }

    func testRemixDeckACloneKeepsSlotNumberForEveryDestination() {
        let sources = [
            MappingEntry(commandID: 239, assignment: .remixDeckASlot1),
            MappingEntry(commandID: 249, assignment: .remixDeckASlot2),
            MappingEntry(commandID: 250, assignment: .remixDeckASlot3),
            MappingEntry(commandID: 251, assignment: .remixDeckASlot4)
        ]
        let file = MappingFile(devices: [Device(name: "Controller", mappings: sources)])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: Set(sources.map(\.id)),
                destinations: [.deckB, .deckC, .deckD]
            ),
            in: file
        )

        XCTAssertEqual(plan.inserts.map(\.mapping.assignment), [
            .remixDeckBSlot1, .remixDeckBSlot2, .remixDeckBSlot3, .remixDeckBSlot4,
            .remixDeckCSlot1, .remixDeckCSlot2, .remixDeckCSlot3, .remixDeckCSlot4,
            .remixDeckDSlot1, .remixDeckDSlot2, .remixDeckDSlot3, .remixDeckDSlot4
        ])
    }

    func testOnlyDeckAConditionTargetsTranslate() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            modifier1Condition: ModifierCondition(modifier: 1, value: 1, target: .deckA),
            modifier2Condition: ModifierCondition(modifier: 2, value: 2, target: .deckC)
        )
        let file = MappingFile(devices: [Device(name: "Controller", mappings: [source])])

        let clone = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckD]
            ),
            in: file
        ).inserts[0].mapping

        XCTAssertEqual(clone.modifier1Condition?.target, .deckD)
        XCTAssertEqual(clone.modifier2Condition?.target, .deckC)
    }

    func testUnknownActiveConditionTargetProducesBlockedReviewWithoutClone() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            modifier1Condition: ModifierCondition(
                modifier: 1,
                value: 1,
                target: .unknown(0xCAFE_BABE)
            )
        )
        let file = MappingFile(devices: [Device(name: "Controller", mappings: [source])])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertEqual(plan.reviewItems.count, 1)
        XCTAssertEqual(
            plan.reviewItems[0].reason,
            .unknownConditionTarget(rawValue: 0xCAFE_BABE)
        )
        XCTAssertNil(plan.reviewItems[0].proposedMapping)
        XCTAssertTrue(plan.reviewItems[0].availableChoices.isEmpty)
    }

    func testCommentTranslationPreservesRecognizedTokenCasingAndLeavesBareLetters() {
        let comments = [
            "Deck A Loop",
            "DECK A PLAY",
            "deck a sync",
            "[A] Hotcue",
            "A: Tempo",
            "AUX Send | Layer A | Macro A1 | Load A Track"
        ]
        let sources = comments.enumerated().map { offset, comment in
            MappingEntry(
                commandID: 100 + offset,
                assignment: .deckA,
                comment: comment
            )
        }
        let file = MappingFile(devices: [Device(name: "Controller", mappings: sources)])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: Set(sources.map(\.id)),
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertEqual(plan.inserts.map(\.mapping.comment), [
            "Deck B Loop",
            "DECK B PLAY",
            "deck b sync",
            "[B] Hotcue",
            "B: Tempo",
            "AUX Send | Layer A | Macro A1 | Load A Track"
        ])
    }

    func testIneligibleSelectedRowsAreIgnoredAndStaleIDsAreNotCounted() {
        let eligible = MappingEntry(commandID: 100, assignment: .deckA)
        let ineligible = [
            MappingEntry(commandID: 101, assignment: .global),
            MappingEntry(commandID: 102, assignment: .deviceTarget),
            MappingEntry(commandID: 103, assignment: .fxUnit1),
            MappingEntry(commandID: 104, assignment: .deckB),
            MappingEntry(commandID: 105, assignment: .remixDeckBSlot1)
        ]
        let device = Device(name: "Controller", mappings: [eligible] + ineligible)
        let file = MappingFile(devices: [device])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: Set(([eligible] + ineligible).map(\.id) + [UUID()]),
                destinations: [.deckC]
            ),
            in: file
        )

        XCTAssertEqual(plan.inserts.map(\.sourceMappingID), [eligible.id])
        XCTAssertEqual(plan.ignoredMappingIDs, Set(ineligible.map(\.id)))
        XCTAssertEqual(plan.statusText, "1 mapping created. 5 other mappings ignored.")
    }

    func testClonesKeepSourceDeviceAndSourceOrderWithinDestinationGroups() {
        let first = MappingEntry(commandID: 100, assignment: .deckA)
        let unselected = MappingEntry(commandID: 101, assignment: .deckA)
        let second = MappingEntry(commandID: 102, assignment: .deckA)
        let third = MappingEntry(commandID: 103, assignment: .deckA)
        let firstDevice = Device(name: "First", mappings: [first, unselected, second])
        let secondDevice = Device(name: "Second", mappings: [third])
        let file = MappingFile(devices: [firstDevice, secondDevice])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [first.id, second.id, third.id],
                destinations: [.deckC, .deckB]
            ),
            in: file
        )

        XCTAssertEqual(plan.inserts.map(\.destination), [
            .deckB, .deckB, .deckB, .deckC, .deckC, .deckC
        ])
        XCTAssertEqual(plan.inserts.map(\.sourceMappingID), [
            first.id, second.id, third.id, first.id, second.id, third.id
        ])
        XCTAssertEqual(plan.inserts.map(\.deviceID), [
            firstDevice.id, firstDevice.id, secondDevice.id,
            firstDevice.id, firstDevice.id, secondDevice.id
        ])
    }

    func testEveryPlannedCloneHasFreshUniqueIDAndBecomesSelected() {
        let first = MappingEntry(commandID: 100, assignment: .deckA)
        let second = MappingEntry(commandID: 101, assignment: .deckA)
        let sourceIDs = Set([first.id, second.id])
        let file = MappingFile(devices: [Device(name: "Controller", mappings: [first, second])])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: sourceIDs,
                destinations: [.deckB, .deckC, .deckD]
            ),
            in: file
        )
        let createdIDs = Set(plan.inserts.map(\.mapping.id))

        XCTAssertEqual(createdIDs.count, 6)
        XCTAssertTrue(createdIDs.isDisjoint(with: sourceIDs))
        XCTAssertEqual(plan.newSelectionIDs, createdIDs)
    }

    func testRepeatedPlanningWithSameRequestProducesEqualPlanAndFreshProposedIDs() {
        let safeSource = MappingEntry(commandID: 100, assignment: .deckA)
        let conflictingSource = MappingEntry(
            commandID: 101,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10
        )
        let existingTarget = MappingEntry(
            commandID: 101,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 11
        )
        let file = MappingFile(devices: [
            Device(
                name: "Controller",
                mappings: [safeSource, conflictingSource, existingTarget]
            )
        ])
        let request = MappingTransformRequest(
            selectedMappingIDs: [safeSource.id, conflictingSource.id],
            destinations: [.deckB]
        )

        let firstPlan = MappingTransformPlanner.plan(request, in: file)
        let secondPlan = MappingTransformPlanner.plan(request, in: file)
        let proposedIDs = firstPlan.inserts.map(\.mapping.id)
            + firstPlan.reviewItems.compactMap(\.proposedMapping?.id)
        let existingIDs = Set(file.allMappings.map(\.id))

        XCTAssertEqual(firstPlan, secondPlan)
        XCTAssertEqual(Set(proposedIDs).count, 2)
        XCTAssertTrue(Set(proposedIDs).isDisjoint(with: existingIDs))
    }

    func testRepeatedPlanningDeterministicallyResolvesInjectedExistingIDCollision() {
        let source = MappingEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10
        )
        let existing = MappingEntry(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            commandID: 100,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 11
        )
        let file = MappingFile(devices: [
            Device(name: "Controller", mappings: [source, existing])
        ])
        let injectedIDs = [source.id, existing.id]
        var allocationCallCount = 0
        let request = MappingTransformRequest(
            selectedMappingIDs: [source.id],
            destinations: [.deckB, .deckC],
            makeMappingID: {
                defer { allocationCallCount += 1 }
                let id = injectedIDs[allocationCallCount]
                return id
            }
        )

        let firstPlan = MappingTransformPlanner.plan(request, in: file)
        let secondPlan = MappingTransformPlanner.plan(request, in: file)
        let proposedIDs = Set(
            firstPlan.inserts.map(\.mapping.id)
                + firstPlan.reviewItems.compactMap(\.proposedMapping?.id)
        )

        XCTAssertEqual(firstPlan, secondPlan)
        XCTAssertEqual(allocationCallCount, 2)
        XCTAssertEqual(proposedIDs.count, 2)
        XCTAssertTrue(proposedIDs.isDisjoint(with: Set(file.allMappings.map(\.id))))
    }

    func testEmptyAndStaleOnlyRequestsHaveNoStatusMessage() {
        let source = MappingEntry(commandID: 100, assignment: .deckA)
        let file = MappingFile(devices: [Device(name: "Controller", mappings: [source])])

        let emptySelection = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [],
                destinations: [.deckB]
            ),
            in: file
        )
        let emptyDestinations = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: []
            ),
            in: file
        )
        let staleOnly = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [UUID()],
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertNil(emptySelection.statusText)
        XCTAssertNil(emptyDestinations.statusText)
        XCTAssertNil(staleOnly.statusText)
    }

    func testClonePreservesOpaqueImportedStateWhileChangingOnlyOwnedSemantics() throws {
        let original = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 3,
            midiNote: 64,
            modifier1Condition: ModifierCondition(modifier: 2, value: 5, target: .deckA),
            comment: "Deck A cue"
        )
        let encoded = try TSIWriter().writeConverted(
            MappingFile(devices: [Device(name: "Controller", mappings: [original])])
        )
        let importedFile = try TSIParser().parseDocument(encoded)
        let importedSource = try XCTUnwrap(importedFile.allMappings.first)
        let importedState = try XCTUnwrap(importedSource.importedCMAD)

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [importedSource.id],
                destinations: [.deckB]
            ),
            in: importedFile
        )
        let clone = try XCTUnwrap(plan.inserts.first?.mapping)

        XCTAssertEqual(clone.importedCMAD, importedState)
        XCTAssertEqual(importedFile.allMappings.first, importedSource)
        XCTAssertEqual(clone.assignment, .deckB)
        XCTAssertEqual(clone.modifier1Condition?.target, .deckB)
        XCTAssertEqual(clone.comment, "Deck B cue")
        XCTAssertEqual(clone.midiAssignment, importedSource.midiAssignment)
    }

    func testExactDuplicateInSourceDeviceIsSkippedButSameRowInOtherDeviceIsNot() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 2,
            midiCC: 7,
            comment: "Deck A play",
            invert: true
        )
        let exactTarget = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 7,
            comment: "Deck B play",
            invert: true
        )
        let file = MappingFile(devices: [
            Device(name: "Source", mappings: [source, exactTarget]),
            Device(name: "Other", mappings: [exactTarget.copyWithNewID()])
        ])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertEqual(plan.duplicateSkips.count, 1)
        XCTAssertEqual(plan.duplicateSkips[0].existingMappingID, exactTarget.id)
        XCTAssertTrue(plan.reviewItems.isEmpty)
        XCTAssertEqual(plan.statusText, "0 mappings created. 1 duplicate skipped.")
    }

    func testFunctionalMatchWithDifferentMIDIOrCommentNeedsReview() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A primary"
        )
        let existing = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            interactionMode: .hold,
            midiChannel: 2,
            midiCC: 11,
            comment: "Deck B alternate"
        )
        let device = Device(name: "Controller", mappings: [source, existing])
        let file = MappingFile(devices: [device])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertTrue(plan.inserts.isEmpty)
        XCTAssertEqual(plan.reviewItems.count, 1)
        XCTAssertEqual(plan.reviewItems[0].reason, .functionalConflict)
        XCTAssertEqual(plan.reviewItems[0].conflicts.map(\.mapping.id), [existing.id])
        XCTAssertEqual(plan.reviewItems[0].proposedMapping?.midiCC, 10)
        XCTAssertEqual(plan.reviewItems[0].availableChoices, [
            .keepExisting, .createAnother, .replaceExisting
        ])
        XCTAssertEqual(plan.statusText, "1 mapping needs review.")
    }

    func testOneProposalWithMultipleFunctionalConflictsProducesOneReviewItem() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A source"
        )
        let firstExisting = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 11,
            comment: "Deck B first"
        )
        let secondExisting = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 3,
            midiNote: 60,
            comment: "Deck B second"
        )
        let file = MappingFile(devices: [
            Device(name: "Controller", mappings: [source, firstExisting, secondExisting])
        ])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertEqual(plan.reviewItems.count, 1)
        XCTAssertEqual(
            plan.reviewItems[0].conflicts.map(\.mapping.id),
            [firstExisting.id, secondExisting.id]
        )
        XCTAssertEqual(plan.statusText, "1 mapping needs review.")
    }

    func testSameMIDIDifferentCommandMacroDoesNotConflict() {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10
        )
        let macroPeer = MappingEntry(
            commandID: 101,
            assignment: .deckB,
            midiChannel: 1,
            midiCC: 10
        )
        let file = MappingFile(devices: [
            Device(name: "Controller", mappings: [source, macroPeer])
        ])

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id],
                destinations: [.deckB]
            ),
            in: file
        )

        XCTAssertEqual(plan.inserts.count, 1)
        XCTAssertTrue(plan.reviewItems.isEmpty)
        XCTAssertTrue(plan.duplicateSkips.isEmpty)
    }
}
