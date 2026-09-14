import XCTest
@testable import XtremeMapping

final class DeviceManagementServiceTests: XCTestCase {
    func testAddAndUpdateCommitAllEditableDeviceFieldsAtomically() throws {
        var file = MappingFile()

        let deviceID = try DeviceManagementService.addDevice(
            name: "Generic MIDI",
            comment: "Deck controls",
            inPort: "Controller Input",
            outPort: "Controller Output",
            to: &file
        )

        XCTAssertEqual(file.devices.count, 1)
        XCTAssertEqual(file.devices[0].id, deviceID)
        XCTAssertEqual(file.devices[0].name, "Generic MIDI")
        XCTAssertEqual(file.devices[0].comment, "Deck controls")
        XCTAssertEqual(file.devices[0].inPort, "Controller Input")
        XCTAssertEqual(file.devices[0].outPort, "Controller Output")

        try DeviceManagementService.updateDevice(
            deviceID,
            name: "Kontrol X1",
            comment: "FX controls",
            inPort: "X1 Input",
            outPort: "X1 Output",
            in: &file
        )

        XCTAssertEqual(file.devices[0].name, "Kontrol X1")
        XCTAssertEqual(file.devices[0].comment, "FX controls")
        XCTAssertEqual(file.devices[0].inPort, "X1 Input")
        XCTAssertEqual(file.devices[0].outPort, "X1 Output")
    }

    func testInvalidAddAndStaleUpdateLeaveFileUnchanged() {
        let live = Device(name: "Generic MIDI", comment: "Keep")
        var file = MappingFile(devices: [live])
        let before = file

        XCTAssertThrowsError(
            try DeviceManagementService.addDevice(name: "   ", to: &file)
        ) { error in
            guard case .preflightFailed = error as? DeviceManagementError else {
                return XCTFail("Expected preflight failure, got \(error)")
            }
        }
        XCTAssertEqual(file, before)

        XCTAssertThrowsError(
            try DeviceManagementService.updateDevice(
                UUID(),
                name: "Kontrol X1",
                comment: "Changed",
                inPort: "Input",
                outPort: "Output",
                in: &file
            )
        ) { error in
            guard case .deviceUnavailable = error as? DeviceManagementError else {
                return XCTFail("Expected stale-device failure, got \(error)")
            }
        }
        XCTAssertEqual(file, before)
    }

    func testDuplicateAllocatesFreshIDsAndRemapsAllOwnedMetadata() throws {
        let sourceRow = MappingEntry(
            commandID: 100,
            rawMidiControlName: "Ch02.PitchBend",
            comment: "Original row",
            rawDCDTControlType: 5,
            rawDCDTMinValueBits: 0x3f80_0000
        )
        let sourceDevice = Device(
            name: "Generic MIDI",
            comment: "Original device",
            inPort: "In",
            outPort: "Out",
            mappings: [sourceRow]
        )
        var file = MappingFile(devices: [sourceDevice], version: 7)
        file.interchangeMetadata = metadata(
            deviceID: sourceDevice.id,
            mappingID: sourceRow.id,
            profileID: "vendor/controller"
        )

        let result = try DeviceManagementService.duplicateDevice(sourceDevice.id, in: &file)

        XCTAssertEqual(file.devices.count, 2)
        let copy = try XCTUnwrap(file.devices.last)
        let copiedRow = try XCTUnwrap(copy.mappings.first)
        XCTAssertEqual(result.deviceID, copy.id)
        XCTAssertEqual(result.mappingIDs, [copiedRow.id])
        XCTAssertNotEqual(copy.id, sourceDevice.id)
        XCTAssertNotEqual(copiedRow.id, sourceRow.id)
        XCTAssertEqual(copy.name, sourceDevice.name)
        XCTAssertEqual(copy.comment, "Original device copy")
        XCTAssertEqual(copy.inPort, sourceDevice.inPort)
        XCTAssertEqual(copy.outPort, sourceDevice.outPort)
        XCTAssertEqual(copiedRow.commandID, sourceRow.commandID)
        XCTAssertEqual(copiedRow.comment, sourceRow.comment)
        XCTAssertEqual(copiedRow.rawMidiControlName, "Ch02.PitchBend")
        XCTAssertEqual(copiedRow.rawDCDTControlType, 5)
        XCTAssertEqual(copiedRow.rawDCDTMinValueBits, 0x3f80_0000)
        XCTAssertEqual(file.devices[0].mappings[0], sourceRow)

        let metadata = try XCTUnwrap(file.interchangeMetadata)
        XCTAssertEqual(Set(metadata.deviceProfiles?.map(\.deviceID) ?? []), [sourceDevice.id, copy.id])
        XCTAssertEqual(Set(metadata.physicalControls.map(\.mappingID)), [sourceRow.id, copiedRow.id])
        XCTAssertEqual(Set(metadata.localOverrides.map(\.mappingID)), [sourceRow.id, copiedRow.id])
        XCTAssertEqual(metadata.profileReferences.count, 1)
    }

    func testDeleteRemovesDeviceAndOnlyMetadataOwnedByItsDeviceAndRows() throws {
        let deletedRow = MappingEntry(commandID: 100)
        let keptRow = MappingEntry(commandID: 201)
        let deletedDevice = Device(name: "Generic MIDI", mappings: [deletedRow])
        let keptDevice = Device(name: "Kontrol X1", mappings: [keptRow])
        var file = MappingFile(devices: [deletedDevice, keptDevice])
        var annotations = metadata(
            deviceID: deletedDevice.id,
            mappingID: deletedRow.id,
            profileID: "vendor/deleted"
        )
        let kept = metadata(
            deviceID: keptDevice.id,
            mappingID: keptRow.id,
            profileID: "vendor/kept"
        )
        annotations.profileReferences += kept.profileReferences
        annotations.physicalControls += kept.physicalControls
        annotations.localOverrides += kept.localOverrides
        annotations.deviceProfiles = (annotations.deviceProfiles ?? []) + (kept.deviceProfiles ?? [])
        file.interchangeMetadata = annotations

        try DeviceManagementService.deleteDevice(deletedDevice.id, in: &file)

        XCTAssertEqual(file.devices.map(\.id), [keptDevice.id])
        let metadata = try XCTUnwrap(file.interchangeMetadata)
        XCTAssertEqual(metadata.deviceProfiles?.map(\.deviceID), [keptDevice.id])
        XCTAssertEqual(metadata.physicalControls.map(\.mappingID), [keptRow.id])
        XCTAssertEqual(metadata.localOverrides.map(\.mappingID), [keptRow.id])
        XCTAssertEqual(metadata.profileReferences.count, 2)
    }

    func testCopyRequiresLiveExplicitOwnersAndRemapsSafeRowMetadata() throws {
        let selected = MappingEntry(commandID: 100)
        let source = Device(name: "Generic MIDI", mappings: [selected])
        let destination = Device(name: "Kontrol X1")
        var file = MappingFile(devices: [source, destination])
        file.interchangeMetadata = metadata(
            deviceID: source.id,
            mappingID: selected.id,
            profileID: "vendor/controller"
        )
        file.interchangeMetadata?.deviceProfiles?.append(
            .init(
                deviceID: destination.id,
                configuration: configuration(profileID: "vendor/controller")
            )
        )

        let result = try DeviceManagementService.transferMappings(
            [selected.id],
            from: source.id,
            to: destination.id,
            mode: .copy,
            in: &file
        )

        let copied = try XCTUnwrap(file.devices[1].mappings.first)
        XCTAssertEqual(result.deviceID, destination.id)
        XCTAssertEqual(result.mappingIDs, [copied.id])
        XCTAssertNotEqual(copied.id, selected.id)
        XCTAssertEqual(file.devices[0].mappings.map(\.id), [selected.id])
        XCTAssertEqual(Set(file.interchangeMetadata?.physicalControls.map(\.mappingID) ?? []), [selected.id, copied.id])
        XCTAssertEqual(Set(file.interchangeMetadata?.localOverrides.map(\.mappingID) ?? []), [selected.id, copied.id])
    }

    func testMovePreservesIDsAndDropsPhysicalControlForDifferentDestinationProfile() throws {
        let selected = MappingEntry(commandID: 100)
        let source = Device(name: "Generic MIDI", mappings: [selected])
        let destination = Device(name: "Kontrol X1")
        var file = MappingFile(devices: [source, destination])
        file.interchangeMetadata = metadata(
            deviceID: source.id,
            mappingID: selected.id,
            profileID: "vendor/source"
        )
        file.interchangeMetadata?.deviceProfiles?.append(
            .init(
                deviceID: destination.id,
                configuration: configuration(profileID: "vendor/destination")
            )
        )

        let result = try DeviceManagementService.transferMappings(
            [selected.id],
            from: source.id,
            to: destination.id,
            mode: .move,
            in: &file
        )

        XCTAssertTrue(file.devices[0].mappings.isEmpty)
        XCTAssertEqual(file.devices[1].mappings.map(\.id), [selected.id])
        XCTAssertEqual(result.mappingIDs, [selected.id])
        XCTAssertTrue(file.interchangeMetadata?.physicalControls.isEmpty == true)
        XCTAssertEqual(file.interchangeMetadata?.localOverrides.map(\.mappingID), [selected.id])
    }

    func testTransferRejectsStaleSourceDestinationAndSelectionWithoutMutation() {
        let selected = MappingEntry(commandID: 100)
        let source = Device(name: "Generic MIDI", mappings: [selected])
        let destination = Device(name: "Kontrol X1")
        let cases: [(Device.ID, Device.ID, Set<MappingEntry.ID>, DeviceManagementError)] = [
            (UUID(), destination.id, [selected.id], .deviceUnavailable(source.id)),
            (source.id, UUID(), [selected.id], .deviceUnavailable(destination.id)),
            (source.id, destination.id, [UUID()], .mappingUnavailable([]))
        ]

        for (requestedSource, requestedDestination, mappingIDs, expectedKind) in cases {
            var file = MappingFile(devices: [source, destination])
            let before = file

            XCTAssertThrowsError(
                try DeviceManagementService.transferMappings(
                    mappingIDs,
                    from: requestedSource,
                    to: requestedDestination,
                    mode: .move,
                    in: &file
                )
            ) { error in
                switch (error as? DeviceManagementError, expectedKind) {
                case (.deviceUnavailable, .deviceUnavailable), (.mappingUnavailable, .mappingUnavailable): break
                default: XCTFail("Unexpected error \(error)")
                }
            }
            XCTAssertEqual(file, before)
        }
    }

    func testTransferPreflightFailureKeepsRowsMetadataAndOpaqueOriginalsUnchanged() {
        let selected = MappingEntry(
            commandID: 100,
            ioType: .input,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 7
        )
        let existing = MappingEntry(
            commandID: 201,
            ioType: .input,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 5
        )
        let source = Device(name: "Generic MIDI", mappings: [selected])
        let destination = Device(name: "Kontrol X1", mappings: [existing])
        var file = MappingFile(devices: [source, destination])
        file.interchangeMetadata = metadata(
            deviceID: source.id,
            mappingID: selected.id,
            profileID: "vendor/controller"
        )
        let before = file
        let beforeMetadata = file.interchangeMetadata

        XCTAssertThrowsError(
            try DeviceManagementService.transferMappings(
                [selected.id],
                from: source.id,
                to: destination.id,
                mode: .move,
                in: &file
            )
        ) { error in
            guard case .preflightFailed(let message) = error as? DeviceManagementError else {
                return XCTFail("Expected preflight failure, got \(error)")
            }
            XCTAssertTrue(message.contains("conflicting MIDI definitions"))
        }
        XCTAssertEqual(file, before)
        XCTAssertEqual(file.interchangeMetadata, beforeMetadata)
        XCTAssertEqual(file.devices[0].mappings[0].rawMidiControlName, "Ch02.PitchBend")
        XCTAssertEqual(file.devices[0].mappings[0].rawDCDTControlType, 7)
    }

    func testSelectedDeviceExportKeepsSemanticConfigurationAndDetachesRawSource() throws {
        let firstRow = MappingEntry(commandID: 100)
        let secondRow = MappingEntry(commandID: 201)
        let first = Device(name: "Generic MIDI", mappings: [firstRow])
        let second = Device(name: "Kontrol X1", mappings: [secondRow])
        let importedData = try TSIWriter().writeConverted(MappingFile(devices: [first, second]))
        var file = try TSIParser().parseDocument(importedData)
        let importedFirst = file.devices[0]
        let importedSecond = file.devices[1]
        var annotations = metadata(
            deviceID: importedFirst.id,
            mappingID: importedFirst.mappings[0].id,
            profileID: "vendor/first"
        )
        let other = metadata(
            deviceID: importedSecond.id,
            mappingID: importedSecond.mappings[0].id,
            profileID: "vendor/second"
        )
        annotations.profileReferences += other.profileReferences
        annotations.physicalControls += other.physicalControls
        annotations.localOverrides += other.localOverrides
        annotations.deviceProfiles = (annotations.deviceProfiles ?? []) + (other.deviceProfiles ?? [])
        file.interchangeMetadata = annotations

        let exported = try DeviceManagementService.selectedDeviceExport(importedFirst.id, from: file)

        XCTAssertEqual(exported.version, file.version)
        XCTAssertEqual(exported.devices.map(\.id), [importedFirst.id])
        XCTAssertEqual(exported.devices[0].mappings.map(\.id), [importedFirst.mappings[0].id])
        XCTAssertNil(exported.sourceEnvelope)
        XCTAssertEqual(exported.interchangeMetadata?.deviceProfiles?.map(\.deviceID), [importedFirst.id])
        XCTAssertEqual(exported.interchangeMetadata?.physicalControls.map(\.mappingID), [importedFirst.mappings[0].id])
        XCTAssertEqual(exported.interchangeMetadata?.localOverrides.map(\.mappingID), [importedFirst.mappings[0].id])
        XCTAssertEqual(exported.interchangeMetadata?.profileReferences.map(\.profileID), ["vendor/first"])
        XCTAssertNoThrow(try TSIWriter().makeConvertedWritePlan(for: exported))
    }

    func testSelectedDeviceExportRoundTripsThroughConvertedTSIAndJSONMetadata() throws {
        let row = MappingEntry(
            commandID: 100,
            ioType: .input,
            assignment: .deckA,
            interactionMode: .toggle,
            midiChannel: 2,
            midiNote: 48,
            comment: "Play control"
        )
        let device = Device(
            name: "Generic MIDI",
            comment: "Deck A",
            inPort: "Input A",
            outPort: "Output A",
            tsiVersion: "4.4.1",
            mappingFileRevision: 17,
            mappings: [row]
        )
        var file = MappingFile(devices: [device], version: 3)
        file.interchangeMetadata = metadata(
            deviceID: device.id,
            mappingID: row.id,
            profileID: "vendor/controller"
        )

        let exported = try DeviceManagementService.selectedDeviceExport(device.id, from: file)
        let tsiRoundTrip = try TSIParser().parseDocument(
            TSIWriter().makeConvertedWritePlan(for: exported).output
        )

        XCTAssertEqual(tsiRoundTrip.devices.count, 1)
        XCTAssertEqual(tsiRoundTrip.devices[0].comment, "Deck A")
        XCTAssertEqual(tsiRoundTrip.devices[0].inPort, "Input A")
        XCTAssertEqual(tsiRoundTrip.devices[0].outPort, "Output A")
        XCTAssertEqual(tsiRoundTrip.devices[0].mappings.count, 1)
        XCTAssertEqual(tsiRoundTrip.devices[0].mappings[0].commandID, 100)
        XCTAssertEqual(tsiRoundTrip.devices[0].mappings[0].assignment, .deckA)
        XCTAssertEqual(tsiRoundTrip.devices[0].mappings[0].midiChannel, 2)
        XCTAssertEqual(tsiRoundTrip.devices[0].mappings[0].midiNote, 48)

        let jsonRoundTrip = try SXMJSONCodec.decode(SXMJSONCodec.encode(exported))
        XCTAssertEqual(jsonRoundTrip.interchangeMetadata, exported.interchangeMetadata)
        XCTAssertEqual(jsonRoundTrip.devices, exported.devices)
    }

    func testTypicalImportedFileSupportsStructuralEditsAndOrdinarySaveReopen() throws {
        let originalData = try TSIWriter().writeConverted(
            MappingFile(devices: [
                Device(
                    name: "Generic MIDI",
                    comment: "Original",
                    inPort: "Original In",
                    outPort: "Original Out",
                    mappings: [MappingEntry(commandID: 100)]
                )
            ])
        )
        var imported = try TSIParser().parseDocument(originalData)
        let originalID = imported.devices[0].id

        try DeviceManagementService.updateDevice(
            originalID,
            name: "Generic MIDI",
            comment: "Updated",
            inPort: "Updated In",
            outPort: "Updated Out",
            in: &imported
        )
        let temporaryID = try DeviceManagementService.addDevice(
            name: "Kontrol X1",
            comment: "Temporary",
            to: &imported
        )
        let duplicate = try DeviceManagementService.duplicateDevice(originalID, in: &imported)
        try DeviceManagementService.deleteDevice(temporaryID, in: &imported)

        let ordinaryPlan = try TSIWriter().makeWritePlan(for: imported)
        let reopened = try TSIParser().parseDocument(ordinaryPlan.output)

        XCTAssertEqual(reopened.devices.count, 2)
        XCTAssertEqual(reopened.devices.map(\.comment), ["Updated", "Updated copy"])
        XCTAssertEqual(reopened.devices.map(\.inPort), ["Updated In", "Updated In"])
        XCTAssertEqual(reopened.devices.map(\.outPort), ["Updated Out", "Updated Out"])
        XCTAssertEqual(reopened.devices.map { $0.mappings.count }, [1, 1])
        XCTAssertEqual(duplicate.mappingIDs.count, 1)
    }

    func testRiskyImportedSourceRejectsDeviceMutationBeforeChangingDocument() throws {
        var file = try riskyImportedFile()
        let before = file

        XCTAssertThrowsError(
            try DeviceManagementService.addDevice(
                name: "Generic MIDI",
                comment: "Must not be added",
                to: &file
            )
        ) { error in
            guard case .preflightFailed(let message) = error as? DeviceManagementError else {
                return XCTFail("Expected ordinary-save preflight failure, got \(error)")
            }
            XCTAssertTrue(message.contains("normal save cannot preserve"))
            XCTAssertTrue(message.contains("partialCMAD"))
        }
        XCTAssertEqual(file, before)
        XCTAssertEqual(file.sourceEnvelope, before.sourceEnvelope)
    }

    func testRiskyImportedSourceStillAllowsDeliberateSelectedDeviceConversion() throws {
        let file = try riskyImportedFile()
        let selectedID = file.devices[0].id

        let exported = try DeviceManagementService.selectedDeviceExport(
            selectedID,
            from: file
        )

        XCTAssertNil(exported.sourceEnvelope)
        XCTAssertEqual(exported.devices.count, 1)
        XCTAssertNoThrow(try TSIWriter().makeConvertedWritePlan(for: exported))
    }

    @MainActor
    func testDeviceServiceMutationIsOneUndoableDocumentTransaction() throws {
        let row = MappingEntry(commandID: 100)
        let source = Device(name: "Generic MIDI", mappings: [row])
        let destination = Device(name: "Kontrol X1")
        var initial = MappingFile(devices: [source, destination])
        initial.interchangeMetadata = metadata(
            deviceID: source.id,
            mappingID: row.id,
            profileID: "vendor/controller"
        )
        let document = TraktorMappingDocument(mappingFile: initial)
        let undo = UndoManager()

        let transactionResult = try document.performUndoableMutation(
            actionName: "Move Mappings",
            undoManager: undo
        ) { file in
            try DeviceManagementService.transferMappings(
                [row.id],
                from: source.id,
                to: destination.id,
                mode: .move,
                in: &file
            )
        }
        let moved = document.mappingFile

        XCTAssertEqual(transactionResult?.mappingIDs, [row.id])
        XCTAssertTrue(document.mappingFile.devices[0].mappings.isEmpty)
        XCTAssertEqual(document.mappingFile.devices[1].mappings.map(\.id), [row.id])
        XCTAssertTrue(undo.canUndo)

        undo.undo()
        XCTAssertEqual(document.mappingFile, initial)
        XCTAssertEqual(document.mappingFile.interchangeMetadata, initial.interchangeMetadata)

        undo.redo()
        XCTAssertEqual(document.mappingFile, moved)
        XCTAssertEqual(document.mappingFile.interchangeMetadata, moved.interchangeMetadata)
    }

    private func metadata(
        deviceID: Device.ID,
        mappingID: MappingEntry.ID,
        profileID: String
    ) -> SXMJSONMetadata {
        SXMJSONMetadata(
            profileReferences: [.init(profileID: profileID, version: "1")],
            physicalControls: [
                .init(mappingID: mappingID, profileID: profileID, controlID: "play")
            ],
            localOverrides: [
                .init(
                    mappingID: mappingID,
                    midi: SXMJSONMIDI(try! .note(channel: 1, number: 60))
                )
            ],
            deviceProfiles: [
                .init(deviceID: deviceID, configuration: configuration(profileID: profileID))
            ]
        )
    }

    private func configuration(profileID: String) -> ControllerConfiguration {
        ControllerConfiguration(
            profileID: profileID,
            version: "1",
            globalChannel: 1,
            layerMode: "default",
            unitMap: "default"
        )
    }

    private func riskyImportedFile() throws -> MappingFile {
        let data = try TSIWriter().writeConverted(
            MappingFile(devices: [
                Device(
                    name: "Generic MIDI",
                    mappings: [MappingEntry(commandID: 100)]
                )
            ])
        )
        var file = try TSIParser().parseDocument(data)
        let envelope = try XCTUnwrap(file.sourceEnvelope)
        file.sourceEnvelope = TSIRawEnvelope(
            originalXML: envelope.originalXML,
            controllerValues: envelope.controllerValues,
            primaryFrames: envelope.primaryFrames,
            baseline: envelope.baseline,
            risks: [.init(code: .partialCMAD, path: "/Device[0]/Mapping[0]/CMAD[0]")]
        )
        return file
    }
}
