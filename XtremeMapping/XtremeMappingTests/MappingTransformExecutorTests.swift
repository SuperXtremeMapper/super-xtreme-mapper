//
//  MappingTransformExecutorTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

final class MappingTransformExecutorTests: XCTestCase {
    @MainActor
    func testKeepExistingOmitsConflictAndReturnsFinalCounts() throws {
        let fixture = makeConflictFixture()
        let plan = makePlan(for: fixture.source.id, in: fixture.file)
        let review = try XCTUnwrap(plan.reviewItems.first)
        let document = TraktorMappingDocument(mappingFile: fixture.file)
        let undoManager = UndoManager()

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: [review.id: .keepExisting],
            in: document,
            undoManager: undoManager
        )

        XCTAssertEqual(document.mappingFile, fixture.file)
        XCTAssertEqual(result.createdIDs, [])
        XCTAssertEqual(result.createdCount, 0)
        XCTAssertEqual(result.duplicateSkipCount, 0)
        XCTAssertEqual(result.ignoredCount, 0)
        XCTAssertEqual(result.statusText, "0 mappings created.")
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testCreateAnotherKeepsExistingAndSourceAndSelectsPlannedClone() throws {
        let fixture = makeConflictFixture()
        let plan = makePlan(for: fixture.source.id, in: fixture.file)
        let review = try XCTUnwrap(plan.reviewItems.first)
        let proposed = try XCTUnwrap(review.proposedMapping)
        let document = TraktorMappingDocument(mappingFile: fixture.file)
        let undoManager = UndoManager()

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: [review.id: .createAnother],
            in: document,
            undoManager: undoManager
        )

        XCTAssertEqual(
            document.mappingFile.devices[0].mappings,
            [fixture.source, fixture.existing, proposed]
        )
        XCTAssertEqual(result.createdIDs, [proposed.id])
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(result.statusText, "1 mapping created.")
        XCTAssertEqual(undoManager.undoActionName, "Clone Deck A Mappings")
    }

    @MainActor
    func testReplaceExistingRemovesOnlyReferencedMappingInReferencedDevice() throws {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A source"
        )
        let referenced = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 11,
            comment: "Deck B referenced"
        )
        let sameValueOtherID = referenced.copyWithNewID()
        let sameValueOtherDevice = referenced.copyWithNewID()
        let sourceDevice = Device(
            name: "Source Device",
            mappings: [source, referenced, sameValueOtherID]
        )
        let otherDevice = Device(name: "Other Device", mappings: [sameValueOtherDevice])
        let file = MappingFile(devices: [sourceDevice, otherDevice])
        let plan = makePlan(for: source.id, in: file)
        let review = try XCTUnwrap(plan.reviewItems.first(where: {
            $0.reason == .functionalConflict(existingMappingID: referenced.id)
        }))
        let proposed = try XCTUnwrap(review.proposedMapping)
        let document = TraktorMappingDocument(mappingFile: file)

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: Dictionary(
                uniqueKeysWithValues: plan.reviewItems.map { item in
                    (item.id, item.id == review.id ? .replaceExisting : .keepExisting)
                }
            ),
            in: document,
            undoManager: UndoManager()
        )

        XCTAssertEqual(
            document.mappingFile.devices[0].mappings,
            [source, sameValueOtherID, proposed]
        )
        XCTAssertEqual(document.mappingFile.devices[1].mappings, [sameValueOtherDevice])
        XCTAssertEqual(result.createdIDs, [proposed.id])
    }

    @MainActor
    func testSafeInsertsPreserveSourcesAndReturnActualCreatedSelectionAndCounts() throws {
        let first = MappingEntry(commandID: 100, assignment: .deckA, comment: "Deck A first")
        let second = MappingEntry(commandID: 101, assignment: .deckA, comment: "Deck A second")
        let ignored = MappingEntry(commandID: 102, assignment: .global)
        let duplicate = MappingEntry(commandID: 100, assignment: .deckC, comment: "Deck C first")
        let device = Device(
            name: "Controller",
            mappings: [first, second, ignored, duplicate]
        )
        let file = MappingFile(devices: [device])
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [first.id, second.id, ignored.id],
                destinations: [.deckC]
            ),
            in: file
        )
        let expectedCreatedIDs = Set(plan.inserts.map(\.mapping.id))
        let document = TraktorMappingDocument(mappingFile: file)

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: [:],
            in: document,
            undoManager: UndoManager()
        )

        XCTAssertEqual(Array(document.mappingFile.devices[0].mappings.prefix(4)), device.mappings)
        XCTAssertEqual(result.createdIDs, expectedCreatedIDs)
        XCTAssertEqual(result.createdCount, 1)
        XCTAssertEqual(result.duplicateSkipCount, 1)
        XCTAssertEqual(result.ignoredCount, 1)
        XCTAssertEqual(
            result.statusText,
            "1 mapping created. 1 duplicate skipped. 1 other mapping ignored."
        )
    }

    @MainActor
    func testPlannedDuplicateReferenceExecutesAgainstEarlierInsert() throws {
        let first = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A shared"
        )
        let second = first.copyWithNewID()
        let original = MappingFile(devices: [
            Device(name: "Controller", mappings: [first, second])
        ])
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [first.id, second.id],
                destinations: [.deckB]
            ),
            in: original
        )
        let inserted = try XCTUnwrap(plan.inserts.first?.mapping)
        let duplicate = try XCTUnwrap(plan.duplicateSkips.first)
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        XCTAssertEqual(plan.inserts.count, 1)
        XCTAssertEqual(plan.duplicateSkips.count, 1)
        XCTAssertEqual(duplicate.existingMappingID, inserted.id)

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: [:],
            in: document,
            undoManager: undoManager
        )

        XCTAssertEqual(document.mappingFile.devices[0].mappings, [first, second, inserted])
        XCTAssertEqual(result.createdIDs, [inserted.id])
        XCTAssertEqual(result.duplicateSkipCount, 1)
        XCTAssertEqual(undoManager.undoActionName, "Clone Deck A Mappings")
    }

    @MainActor
    func testReplacingPlannedConflictRemovesEarlierInsertFromCreatedSelection() throws {
        let first = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A first"
        )
        let second = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 2,
            midiCC: 11,
            comment: "Deck A second"
        )
        let original = MappingFile(devices: [
            Device(name: "Controller", mappings: [first, second])
        ])
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [first.id, second.id],
                destinations: [.deckB]
            ),
            in: original
        )
        let earlierInsert = try XCTUnwrap(plan.inserts.first?.mapping)
        let review = try XCTUnwrap(plan.reviewItems.first)
        let replacement = try XCTUnwrap(review.proposedMapping)
        let document = TraktorMappingDocument(mappingFile: original)

        XCTAssertEqual(
            review.reason,
            .functionalConflict(existingMappingID: earlierInsert.id)
        )

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: [review.id: .replaceExisting],
            in: document,
            undoManager: UndoManager()
        )

        XCTAssertEqual(document.mappingFile.devices[0].mappings, [first, second, replacement])
        XCTAssertEqual(result.createdIDs, [replacement.id])
        XCTAssertFalse(result.createdIDs.contains(earlierInsert.id))
    }

    @MainActor
    func testMultipleReplaceChoicesRemoveSharedLiveTargetOnceAndInsertEveryProposal() throws {
        let first = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A first"
        )
        let second = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 2,
            midiCC: 11,
            comment: "Deck A second"
        )
        let existing = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 3,
            midiCC: 12,
            comment: "Deck B existing"
        )
        let original = MappingFile(devices: [
            Device(name: "Controller", mappings: [first, second, existing])
        ])
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [first.id, second.id],
                destinations: [.deckB]
            ),
            in: original
        )
        let proposals = try plan.reviewItems.map { try XCTUnwrap($0.proposedMapping) }
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        XCTAssertEqual(plan.reviewItems.count, 2)
        XCTAssertEqual(
            plan.reviewItems.map(\.reason),
            Array(repeating: .functionalConflict(existingMappingID: existing.id), count: 2)
        )

        let result = try MappingTransformExecutor.execute(
            plan,
            choices: Dictionary(
                uniqueKeysWithValues: plan.reviewItems.map { ($0.id, .replaceExisting) }
            ),
            in: document,
            undoManager: undoManager
        )

        XCTAssertEqual(document.mappingFile.devices[0].mappings, [first, second] + proposals)
        XCTAssertEqual(result.createdIDs, Set(proposals.map(\.id)))
        XCTAssertEqual(result.createdIDs.count, 2)
        XCTAssertEqual(undoManager.undoActionName, "Clone Deck A Mappings")
    }

    @MainActor
    func testExecutionIsOneUndoAndRedoThroughDocument() throws {
        let first = MappingEntry(commandID: 100, assignment: .deckA)
        let second = MappingEntry(commandID: 101, assignment: .deckA)
        let original = MappingFile(devices: [
            Device(name: "Controller", mappings: [first, second])
        ])
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [first.id, second.id],
                destinations: [.deckB, .deckC]
            ),
            in: original
        )
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        _ = try MappingTransformExecutor.execute(
            plan,
            choices: [:],
            in: document,
            undoManager: undoManager
        )
        let executed = document.mappingFile

        XCTAssertEqual(executed.allMappings.count, 6)
        XCTAssertEqual(undoManager.undoActionName, "Clone Deck A Mappings")
        undoManager.undo()
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()
        XCTAssertEqual(document.mappingFile, executed)
        XCTAssertTrue(undoManager.canUndo)
    }

    @MainActor
    func testFullCandidateWriterFailureLeavesDocumentAndUndoStackUnchanged() throws {
        let source = MappingEntry(commandID: 100, assignment: .deckA)
        let unrelatedInvalid = MappingEntry(
            commandID: Int(UInt32.max) + 1,
            assignment: .global
        )
        let original = MappingFile(devices: [
            Device(name: "Valid Source", mappings: [source]),
            Device(name: "Unrelated Invalid Device", mappings: [unrelatedInvalid])
        ])
        let plan = makePlan(for: source.id, in: original)
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        XCTAssertThrowsError(
            try MappingTransformExecutor.execute(
                plan,
                choices: [:],
                in: document,
                undoManager: undoManager
            )
        ) { error in
            guard case .preflightFailed = error as? MappingTransformExecutionError else {
                return XCTFail("Expected preflightFailed, got \(error)")
            }
        }

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
    }

    @MainActor
    func testChangedSourceMakesPlanStaleWithoutDocumentOrUndoMutation() throws {
        let source = MappingEntry(commandID: 100, assignment: .deckA, comment: "Deck A source")
        let plannedFile = MappingFile(devices: [Device(name: "Controller", mappings: [source])])
        let plan = makePlan(for: source.id, in: plannedFile)
        var staleFile = plannedFile
        staleFile.devices[0].mappings[0].comment = "Deck A changed after planning"
        let document = TraktorMappingDocument(mappingFile: staleFile)
        let undoManager = UndoManager()

        XCTAssertThrowsError(
            try MappingTransformExecutor.execute(
                plan,
                choices: [:],
                in: document,
                undoManager: undoManager
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransformExecutionError, .stalePlan)
        }

        XCTAssertEqual(document.mappingFile, staleFile)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(undoManager.canUndo)
        XCTAssertFalse(undoManager.canRedo)
    }

    @MainActor
    func testRemovedIgnoredReferenceMakesPlanStaleWithoutMutation() throws {
        let source = MappingEntry(commandID: 100, assignment: .deckA)
        let ignored = MappingEntry(commandID: 101, assignment: .global)
        let plannedFile = MappingFile(devices: [
            Device(name: "Controller", mappings: [source, ignored])
        ])
        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [source.id, ignored.id],
                destinations: [.deckB]
            ),
            in: plannedFile
        )
        var staleFile = plannedFile
        staleFile.devices[0].mappings.removeAll { $0.id == ignored.id }
        let document = TraktorMappingDocument(mappingFile: staleFile)
        let undoManager = UndoManager()

        XCTAssertThrowsError(
            try MappingTransformExecutor.execute(
                plan,
                choices: [:],
                in: document,
                undoManager: undoManager
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransformExecutionError, .stalePlan)
        }

        XCTAssertEqual(document.mappingFile, staleFile)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testStaleReplacementReferenceFailsRatherThanDeletingSameValuePeer() throws {
        let fixture = makeConflictFixture()
        let plan = makePlan(for: fixture.source.id, in: fixture.file)
        let review = try XCTUnwrap(plan.reviewItems.first)
        var staleFile = fixture.file
        staleFile.devices[0].mappings.removeAll { $0.id == fixture.existing.id }
        staleFile.devices[0].mappings.append(fixture.existing.copyWithNewID())
        let document = TraktorMappingDocument(mappingFile: staleFile)
        let undoManager = UndoManager()

        XCTAssertThrowsError(
            try MappingTransformExecutor.execute(
                plan,
                choices: [review.id: .replaceExisting],
                in: document,
                undoManager: undoManager
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransformExecutionError, .stalePlan)
        }

        XCTAssertEqual(document.mappingFile, staleFile)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testBlockedUnknownTargetCannotBeForceCreated() throws {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            modifier1Condition: ModifierCondition(
                modifier: 1,
                value: 1,
                target: .unknown(0xCAFE_BABE)
            )
        )
        let original = MappingFile(devices: [Device(name: "Controller", mappings: [source])])
        let plan = makePlan(for: source.id, in: original)
        let blocked = try XCTUnwrap(plan.reviewItems.first)
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        XCTAssertThrowsError(
            try MappingTransformExecutor.execute(
                plan,
                choices: [blocked.id: .createAnother],
                in: document,
                undoManager: undoManager
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransformExecutionError, .blockedReviewItem)
        }

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(undoManager.canUndo)
    }

    private func makeConflictFixture() -> (
        source: MappingEntry,
        existing: MappingEntry,
        file: MappingFile
    ) {
        let source = MappingEntry(
            commandID: 100,
            assignment: .deckA,
            midiChannel: 1,
            midiCC: 10,
            comment: "Deck A source"
        )
        let existing = MappingEntry(
            commandID: 100,
            assignment: .deckB,
            midiChannel: 2,
            midiCC: 11,
            comment: "Deck B existing"
        )
        return (
            source,
            existing,
            MappingFile(devices: [
                Device(name: "Controller", mappings: [source, existing])
            ])
        )
    }

    private func makePlan(
        for sourceID: MappingEntry.ID,
        in file: MappingFile
    ) -> MappingTransformPlan {
        MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: [sourceID],
                destinations: [.deckB]
            ),
            in: file
        )
    }
}
