//
//  ClipboardManagerTests.swift
//  XtremeMappingTests
//
//  Tests for ClipboardManager clipboard operations
//

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
    }

    override func tearDown() {
        clipboard.mappedToClipboard = nil
        clipboard.modifiersClipboard = nil
        super.tearDown()
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
        XCTAssertEqual(clipboard.mappedToClipboard?.midiChannel, 5)
        XCTAssertEqual(clipboard.mappedToClipboard?.midiNote, 60)
        XCTAssertNil(clipboard.mappedToClipboard?.midiCC)
    }

    func testCopyMappedToWithCC() {
        let entry = MappingEntry(
            midiChannel: 10,
            midiNote: nil,
            midiCC: 74
        )

        clipboard.copyMappedTo(from: entry)

        XCTAssertTrue(clipboard.hasMappedToData)
        XCTAssertEqual(clipboard.mappedToClipboard?.midiChannel, 10)
        XCTAssertNil(clipboard.mappedToClipboard?.midiNote)
        XCTAssertEqual(clipboard.mappedToClipboard?.midiCC, 74)
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

        XCTAssertEqual(clipboard.mappedToClipboard?.midiChannel, 16)
        XCTAssertNil(clipboard.mappedToClipboard?.midiNote)
        XCTAssertEqual(clipboard.mappedToClipboard?.midiCC, 127)
    }
}
