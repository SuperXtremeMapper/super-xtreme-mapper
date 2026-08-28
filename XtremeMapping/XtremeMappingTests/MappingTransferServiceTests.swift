//
//  MappingTransferServiceTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

final class MappingTransferServiceTests: XCTestCase {
    func testPasteIntoEmptyFileCreatesGenericDeviceAndReturnsFreshIDsInSourceOrder() throws {
        var file = MappingFile()
        let source = [MappingEntry(commandID: 100), MappingEntry(commandID: 201)]

        let result = try MappingTransferService.insertCopies(source, into: &file)
        let inserted = result.insertedIDs

        XCTAssertEqual(file.devices.map(\.name), ["Generic MIDI"])
        XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [100, 201])
        XCTAssertEqual(inserted, Set(file.devices[0].mappings.map(\.id)))
        XCTAssertTrue(Set(source.map(\.id)).isDisjoint(with: inserted))
        XCTAssertEqual(result.destinationDeviceID, file.devices[0].id)
    }

    func testValidTargetAppendsOnlyToRequestedDevice() throws {
        let first = Device(name: "First", mappings: [MappingEntry(commandID: 7)])
        let target = Device(name: "Target", mappings: [MappingEntry(commandID: 9)])
        var file = MappingFile(devices: [first, target])

        let result = try MappingTransferService.insertCopies(
            [MappingEntry(commandID: 100), MappingEntry(commandID: 201)],
            into: &file,
            targetDeviceID: target.id
        )

        XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [7])
        XCTAssertEqual(file.devices[1].mappings.map(\.commandID), [9, 100, 201])
        XCTAssertEqual(result.insertedIDs, Set(file.devices[1].mappings.suffix(2).map(\.id)))
        XCTAssertEqual(result.destinationDeviceID, target.id)
    }

    func testStaleTargetThrowsWithoutChangingFile() {
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

        let before = file

        XCTAssertThrowsError(
            try MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file,
                targetDeviceID: UUID()
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransferError, .destinationUnavailable)
        }
        XCTAssertEqual(file, before)
    }

    func testMissingTargetInExistingFileThrowsWithoutChangingFile() {
        var file = MappingFile(devices: [Device(name: "Generic MIDI")])
        let before = file

        XCTAssertThrowsError(
            try MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransferError, .destinationRequired)
        }
        XCTAssertEqual(file, before)
    }

    func testImportedFileWithNoDevicesIsNotTreatedAsTrulyEmpty() throws {
        let clean = try TSIWriter().writeConverted(
            MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        let envelope = try XCTUnwrap(TSIParser().parseDocument(clean).sourceEnvelope)
        var file = MappingFile(sourceEnvelope: envelope)
        let before = file

        XCTAssertThrowsError(
            try MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file
            )
        ) { error in
            XCTAssertEqual(error as? MappingTransferError, .destinationRequired)
        }
        XCTAssertEqual(file, before)
    }

    func testConflictingDCDTCandidateFailsPreflightWithoutMutation() {
        let existing = MappingEntry(
            commandID: 100,
            ioType: .input,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 5
        )
        let conflicting = MappingEntry(
            commandID: 201,
            ioType: .input,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 7
        )
        let device = Device(name: "Generic MIDI", mappings: [existing])
        var file = MappingFile(devices: [device])
        let before = file

        XCTAssertThrowsError(
            try MappingTransferService.insertCopies(
                [conflicting],
                into: &file,
                targetDeviceID: device.id
            )
        ) { error in
            guard case .preflightFailed(let message) = error as? MappingTransferError else {
                return XCTFail("Expected a typed preflight failure, got \(error)")
            }
            XCTAssertTrue(message.contains("conflicting MIDI definitions"))
        }
        XCTAssertEqual(file, before)
    }

    func testEmptySourceDoesNotCreateDeviceOrChangeFile() throws {
        var file = MappingFile()

        let result = try MappingTransferService.insertCopies([], into: &file)

        XCTAssertEqual(result.insertedIDs, [])
        XCTAssertNil(result.destinationDeviceID)
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
