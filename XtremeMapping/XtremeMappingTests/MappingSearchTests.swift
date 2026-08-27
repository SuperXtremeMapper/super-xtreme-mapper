//
//  MappingSearchTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

@MainActor
final class MappingSearchTests: XCTestCase {
    func testMappingCommentMatchesOnlyItsRow() {
        let target = MappingEntry(commandID: 100, comment: "shift layer macro")
        let other = MappingEntry(commandID: 201, comment: "transport")
        let device = Device(
            name: "X1",
            comment: "club setup",
            mappings: [target, other]
        )

        XCTAssertTrue(MappingSearch.matches(target, in: device, query: "layer"))
        XCTAssertFalse(MappingSearch.matches(other, in: device, query: "layer"))
    }

    func testDeviceCommentMatchesEveryOwnedRowAndNoRowsFromAnotherDevice() {
        let firstRows = [MappingEntry(commandID: 100), MappingEntry(commandID: 201)]
        let secondRow = MappingEntry(commandID: 202)
        let firstDevice = Device(
            name: "X1 MK3",
            comment: "Noah macros",
            mappings: firstRows
        )
        let secondDevice = Device(
            name: "X1 MK3",
            comment: "Guest mappings",
            mappings: [secondRow]
        )

        XCTAssertTrue(
            firstRows.allSatisfy {
                MappingSearch.matches($0, in: firstDevice, query: "noah")
            }
        )
        XCTAssertFalse(MappingSearch.matches(secondRow, in: secondDevice, query: "noah"))
    }

    func testSearchesCommandNameMappingCommentDeviceNameAndDeviceComment() {
        let row = MappingEntry(commandID: 100, comment: "shift layer macro")
        let device = Device(
            name: "Kontrol X1",
            comment: "booth setup",
            mappings: [row]
        )

        XCTAssertTrue(MappingSearch.matches(row, in: device, query: "Play/Pause"))
        XCTAssertTrue(MappingSearch.matches(row, in: device, query: "layer"))
        XCTAssertTrue(MappingSearch.matches(row, in: device, query: "Kontrol"))
        XCTAssertTrue(MappingSearch.matches(row, in: device, query: "booth"))
        XCTAssertFalse(MappingSearch.matches(row, in: device, query: "browser"))
    }

    func testSearchTrimsAndMatchesCaseAndDiacriticInsensitively() {
        let row = MappingEntry(commandID: 100, comment: "Écho Macro")
        let device = Device(name: "Generic MIDI", mappings: [row])

        XCTAssertTrue(MappingSearch.matches(row, in: device, query: "  ECHO\n"))
    }

    func testEmptyAndWhitespaceQueriesMatch() {
        let row = MappingEntry(commandID: 100)
        let device = Device(name: "Generic MIDI", mappings: [row])

        XCTAssertTrue(MappingSearch.matches(row, in: device, query: ""))
        XCTAssertTrue(MappingSearch.matches(row, in: device, query: " \n\t "))
    }
}
