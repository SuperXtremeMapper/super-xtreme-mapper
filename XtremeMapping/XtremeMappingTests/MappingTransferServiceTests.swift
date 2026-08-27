//
//  MappingTransferServiceTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

final class MappingTransferServiceTests: XCTestCase {
    func testPasteIntoEmptyFileCreatesGenericDeviceAndReturnsFreshIDsInSourceOrder() {
        var file = MappingFile()
        let source = [MappingEntry(commandID: 100), MappingEntry(commandID: 201)]

        let inserted = MappingTransferService.insertCopies(source, into: &file)

        XCTAssertEqual(file.devices.map(\.name), ["Generic MIDI"])
        XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [100, 201])
        XCTAssertEqual(inserted, Set(file.devices[0].mappings.map(\.id)))
        XCTAssertTrue(Set(source.map(\.id)).isDisjoint(with: inserted))
    }

    func testValidTargetAppendsOnlyToRequestedDevice() {
        let first = Device(name: "First", mappings: [MappingEntry(commandID: 7)])
        let target = Device(name: "Target", mappings: [MappingEntry(commandID: 9)])
        var file = MappingFile(devices: [first, target])

        let inserted = MappingTransferService.insertCopies(
            [MappingEntry(commandID: 100), MappingEntry(commandID: 201)],
            into: &file,
            targetDeviceID: target.id
        )

        XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [7])
        XCTAssertEqual(file.devices[1].mappings.map(\.commandID), [9, 100, 201])
        XCTAssertEqual(inserted, Set(file.devices[1].mappings.suffix(2).map(\.id)))
    }

    func testStaleTargetFallsBackToFirstDeviceWithoutChangingItsMetadata() {
        let first = Device(
            name: "Original",
            comment: "Keep this",
            inPort: "Input",
            outPort: "Output",
            tsiVersion: "4.4.1",
            mappingFileRevision: 17
        )
        let second = Device(name: "Second")
        var file = MappingFile(devices: [first, second])

        let inserted = MappingTransferService.insertCopies(
            [MappingEntry(commandID: 100)],
            into: &file,
            targetDeviceID: UUID()
        )

        XCTAssertEqual(file.devices[0].name, "Original")
        XCTAssertEqual(file.devices[0].comment, "Keep this")
        XCTAssertEqual(file.devices[0].inPort, "Input")
        XCTAssertEqual(file.devices[0].outPort, "Output")
        XCTAssertEqual(file.devices[0].tsiVersion, "4.4.1")
        XCTAssertEqual(file.devices[0].mappingFileRevision, 17)
        XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [100])
        XCTAssertTrue(file.devices[1].mappings.isEmpty)
        XCTAssertEqual(inserted, Set(file.devices[0].mappings.map(\.id)))
    }

    func testEmptySourceDoesNotCreateDeviceOrChangeFile() {
        var file = MappingFile()

        let inserted = MappingTransferService.insertCopies([], into: &file)

        XCTAssertEqual(inserted, [])
        XCTAssertTrue(file.devices.isEmpty)
    }

    func testDuplicateSelectionKeepsRowsInEachSourceDeviceAndDocumentOrder() {
        let firstSelected = MappingEntry(commandID: 100)
        let firstUnselected = MappingEntry(commandID: 7)
        let secondSelected = MappingEntry(commandID: 201)
        let thirdSelected = MappingEntry(commandID: 202)
        let secondUnselected = MappingEntry(commandID: 9)
        var file = MappingFile(devices: [
            Device(
                name: "First",
                mappings: [firstSelected, firstUnselected, secondSelected]
            ),
            Device(
                name: "Second",
                mappings: [thirdSelected, secondUnselected]
            )
        ])
        let sourceIDs = Set([firstSelected.id, secondSelected.id, thirdSelected.id])

        let inserted = MappingTransferService.duplicateSelection(sourceIDs, in: &file)

        XCTAssertEqual(
            file.devices[0].mappings.map(\.commandID),
            [100, 7, 201, 100, 201]
        )
        XCTAssertEqual(
            file.devices[1].mappings.map(\.commandID),
            [202, 9, 202]
        )
        let duplicatedIDs = Set(
            file.devices[0].mappings.suffix(2).map(\.id)
                + file.devices[1].mappings.suffix(1).map(\.id)
        )
        XCTAssertEqual(inserted, duplicatedIDs)
        XCTAssertEqual(inserted.count, 3)
        XCTAssertTrue(inserted.isDisjoint(with: sourceIDs))
    }

    func testDestinationDeviceRequiresExactlyOneSelectedOwner() {
        let first = MappingEntry(commandID: 100)
        let second = MappingEntry(commandID: 201)
        let firstDevice = Device(name: "First", mappings: [first])
        let secondDevice = Device(name: "Second", mappings: [second])
        let file = MappingFile(devices: [firstDevice, secondDevice])

        XCTAssertEqual(
            MappingTransferService.destinationDeviceID(
                for: Set([first.id]),
                in: file
            ),
            firstDevice.id
        )
        XCTAssertNil(MappingTransferService.destinationDeviceID(for: [], in: file))
        XCTAssertNil(
            MappingTransferService.destinationDeviceID(
                for: Set([first.id, second.id]),
                in: file
            )
        )
        XCTAssertNil(
            MappingTransferService.destinationDeviceID(
                for: Set([UUID()]),
                in: file
            )
        )
    }
}
