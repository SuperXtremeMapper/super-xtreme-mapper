//
//  ClipboardManagerTests.swift
//  XtremeMappingTests
//
//  Tests for ClipboardManager clipboard operations
//

import Combine
import XCTest
@testable import XtremeMapping

final class ClipboardManagerTests: XCTestCase {

    var clipboard: ClipboardManager!

    override func setUp() {
        super.setUp()
        // Get fresh state - clear any existing clipboard data
        clipboard = ClipboardManager.shared
        clipboard.mappedToClipboard = nil
        clipboard.modifiersClipboard = nil
        clipboard.copyMappings([])
    }

    override func tearDown() {
        clipboard.mappedToClipboard = nil
        clipboard.modifiersClipboard = nil
        clipboard.copyMappings([])
        super.tearDown()
    }

    // MARK: - Observation Contract Tests
    // EditCommands observes ClipboardManager so `.disabled(...)` re-evaluates
    // on copy — these pin the objectWillChange emissions that relies on.

    func testCopyMappedToEmitsObjectWillChange() {
        let entry = MappingEntry(midiChannel: 1, midiNote: 60)
        var emissions = 0
        let cancellable = clipboard.objectWillChange.sink { emissions += 1 }
        defer { cancellable.cancel() }

        clipboard.copyMappedTo(from: entry)

        XCTAssertGreaterThan(emissions, 0, "copyMappedTo must publish objectWillChange")
    }

    func testCopyModifiersEmitsObjectWillChange() {
        let entry = MappingEntry(midiChannel: 1)
        var emissions = 0
        let cancellable = clipboard.objectWillChange.sink { emissions += 1 }
        defer { cancellable.cancel() }

        clipboard.copyModifiers(from: entry)

        XCTAssertGreaterThan(emissions, 0, "copyModifiers must publish objectWillChange")
    }

    // MARK: - Initial State Tests

    func testInitialStateHasNoMappedToData() {
        XCTAssertFalse(clipboard.hasMappedToData)
        XCTAssertNil(clipboard.mappedToClipboard)
    }

    func testInitialStateHasNoModifiersData() {
        XCTAssertFalse(clipboard.hasModifiersData)
        XCTAssertNil(clipboard.modifiersClipboard)
    }

    // MARK: - Copy Mapped To Tests

    func testCopyMappedToWithNote() {
        let entry = MappingEntry(
            midiChannel: 5,
            midiNote: 60,
            midiCC: nil
        )

        clipboard.copyMappedTo(from: entry)

        XCTAssertTrue(clipboard.hasMappedToData)
        XCTAssertEqual(clipboard.mappedToClipboard?.midiAssignment, try? .note(channel: 5, number: 60))
    }

    func testCopyMappedToWithCC() {
        let entry = MappingEntry(
            midiChannel: 10,
            midiNote: nil,
            midiCC: 74
        )

        clipboard.copyMappedTo(from: entry)

        XCTAssertTrue(clipboard.hasMappedToData)
        XCTAssertEqual(
            clipboard.mappedToClipboard?.midiAssignment,
            try? .controlChange(channel: 10, number: 74)
        )
    }

    // MARK: - Paste Mapped To Tests

    func testPasteMappedToUpdatesEntry() {
        // Set up clipboard
        let sourceEntry = MappingEntry(
            midiChannel: 3,
            midiNote: 48,
            midiCC: nil
        )
        clipboard.copyMappedTo(from: sourceEntry)

        // Paste to target
        var targetEntry = MappingEntry(
            midiChannel: 1,
            midiNote: nil,
            midiCC: 64
        )

        clipboard.pasteMappedTo(to: &targetEntry)

        XCTAssertEqual(targetEntry.midiChannel, 3)
        XCTAssertEqual(targetEntry.midiNote, 48)
        XCTAssertNil(targetEntry.midiCC)
    }

    func testMappedToClipboardPastesOneExclusiveAssignmentAndPreservesOtherFields() throws {
        let assignment = try MIDIAssignment.controlChange(channel: 16, number: 0)
        let source = MappingEntry(commandID: 100, midiAssignment: assignment)
        var target = MappingEntry.fullFieldSentinel
        var expected = target
        expected.midiAssignment = assignment

        clipboard.copyMappedTo(from: source)
        clipboard.pasteMappedTo(to: &target)

        XCTAssertEqual(clipboard.mappedToClipboard?.midiAssignment, assignment)
        XCTAssertEqual(target, expected)
        XCTAssertNil(target.midiNote)
        XCTAssertEqual(target.midiCC, 0)
    }

    func testPasteMappedToDoesNothingWhenEmpty() {
        var entry = MappingEntry(
            midiChannel: 7,
            midiNote: 100,
            midiCC: nil
        )

        // Clipboard is empty
        clipboard.pasteMappedTo(to: &entry)

        // Entry unchanged
        XCTAssertEqual(entry.midiChannel, 7)
        XCTAssertEqual(entry.midiNote, 100)
    }

    // MARK: - Copy Modifiers Tests

    func testCopyModifiersWithBothConditions() {
        let entry = MappingEntry(
            modifier1Condition: ModifierCondition(modifier: 1, value: 3),
            modifier2Condition: ModifierCondition(modifier: 5, value: 7)
        )

        clipboard.copyModifiers(from: entry)

        XCTAssertTrue(clipboard.hasModifiersData)
        XCTAssertEqual(clipboard.modifiersClipboard?.modifier1?.modifier, 1)
        XCTAssertEqual(clipboard.modifiersClipboard?.modifier1?.value, 3)
        XCTAssertEqual(clipboard.modifiersClipboard?.modifier2?.modifier, 5)
        XCTAssertEqual(clipboard.modifiersClipboard?.modifier2?.value, 7)
    }

    func testCopyModifiersWithNoConditions() {
        let entry = MappingEntry(
            modifier1Condition: nil,
            modifier2Condition: nil
        )

        clipboard.copyModifiers(from: entry)

        XCTAssertTrue(clipboard.hasModifiersData)
        XCTAssertNil(clipboard.modifiersClipboard?.modifier1)
        XCTAssertNil(clipboard.modifiersClipboard?.modifier2)
    }

    func testCopyModifiersWithOnlyModifier1() {
        let entry = MappingEntry(
            modifier1Condition: ModifierCondition(modifier: 4, value: 2),
            modifier2Condition: nil
        )

        clipboard.copyModifiers(from: entry)

        XCTAssertTrue(clipboard.hasModifiersData)
        XCTAssertEqual(clipboard.modifiersClipboard?.modifier1?.modifier, 4)
        XCTAssertEqual(clipboard.modifiersClipboard?.modifier1?.value, 2)
        XCTAssertNil(clipboard.modifiersClipboard?.modifier2)
    }

    // MARK: - Paste Modifiers Tests

    func testPasteModifiersUpdatesEntry() {
        // Set up clipboard
        let sourceEntry = MappingEntry(
            modifier1Condition: ModifierCondition(modifier: 2, value: 5),
            modifier2Condition: ModifierCondition(modifier: 8, value: 0)
        )
        clipboard.copyModifiers(from: sourceEntry)

        // Paste to target
        var targetEntry = MappingEntry(
            modifier1Condition: nil,
            modifier2Condition: nil
        )

        clipboard.pasteModifiers(to: &targetEntry)

        XCTAssertEqual(targetEntry.modifier1Condition?.modifier, 2)
        XCTAssertEqual(targetEntry.modifier1Condition?.value, 5)
        XCTAssertEqual(targetEntry.modifier2Condition?.modifier, 8)
        XCTAssertEqual(targetEntry.modifier2Condition?.value, 0)
    }

    func testPasteModifiersClearsExisting() {
        // Set up clipboard with no modifiers
        let sourceEntry = MappingEntry(
            modifier1Condition: nil,
            modifier2Condition: nil
        )
        clipboard.copyModifiers(from: sourceEntry)

        // Target has modifiers
        var targetEntry = MappingEntry(
            modifier1Condition: ModifierCondition(modifier: 1, value: 1),
            modifier2Condition: ModifierCondition(modifier: 2, value: 2)
        )

        clipboard.pasteModifiers(to: &targetEntry)

        // Modifiers should be cleared
        XCTAssertNil(targetEntry.modifier1Condition)
        XCTAssertNil(targetEntry.modifier2Condition)
    }

    func testPasteModifiersDoesNothingWhenEmpty() {
        var entry = MappingEntry(
            modifier1Condition: ModifierCondition(modifier: 6, value: 4),
            modifier2Condition: nil
        )

        // Clipboard is empty
        clipboard.pasteModifiers(to: &entry)

        // Entry unchanged
        XCTAssertEqual(entry.modifier1Condition?.modifier, 6)
        XCTAssertEqual(entry.modifier1Condition?.value, 4)
    }

    // MARK: - Overwrite Tests

    func testCopyOverwritesPreviousData() {
        let entry1 = MappingEntry(midiChannel: 1, midiNote: 10, midiCC: nil)
        let entry2 = MappingEntry(midiChannel: 16, midiNote: nil, midiCC: 127)

        clipboard.copyMappedTo(from: entry1)
        clipboard.copyMappedTo(from: entry2)

        XCTAssertEqual(
            clipboard.mappedToClipboard?.midiAssignment,
            try? .controlChange(channel: 16, number: 127)
        )
    }

    // MARK: - Mapping Group Clipboard Tests

    func testCopyMappingsReplacesPriorGroupAndPreservesSourceIDsAndOrder() {
        let first = MappingEntry.fullFieldSentinel
        let second = MappingEntry(commandID: 201)
        let replacement = MappingEntry(commandID: 100)

        clipboard.copyMappings([first, second])
        clipboard.copyMappings([replacement])

        XCTAssertTrue(clipboard.hasMappingsData)
        XCTAssertEqual(clipboard.mappingsClipboard.map(\.id), [replacement.id])
        XCTAssertEqual(clipboard.mappingsClipboard.map(\.commandID), [100])
    }

    func testCopyMappingsEmptyResetsGroupClipboard() {
        clipboard.copyMappings([MappingEntry(commandID: 100)])

        clipboard.copyMappings([])

        XCTAssertFalse(clipboard.hasMappingsData)
        XCTAssertTrue(clipboard.mappingsClipboard.isEmpty)
    }

    func testRepeatedInsertionOfClipboardSnapshotsCreatesFreshIDsAndPreservesOrder() {
        let source = [MappingEntry(commandID: 100), MappingEntry(commandID: 201)]
        clipboard.copyMappings(source)
        var file = MappingFile()

        let firstPaste = MappingTransferService.insertCopies(clipboard.mappingsClipboard, into: &file)
        let secondPaste = MappingTransferService.insertCopies(clipboard.mappingsClipboard, into: &file)

        XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [100, 201, 100, 201])
        XCTAssertTrue(firstPaste.isDisjoint(with: secondPaste))
        XCTAssertTrue(Set(source.map(\.id)).isDisjoint(with: firstPaste))
        XCTAssertTrue(Set(source.map(\.id)).isDisjoint(with: secondPaste))
    }
}
