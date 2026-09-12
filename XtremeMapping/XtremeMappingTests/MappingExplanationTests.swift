import XCTest
@testable import XtremeMapping

final class MappingExplanationTests: XCTestCase {
    private let deviceAID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private let deviceBID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!

    func testSnapshotIncludesEveryDeviceAndRowWithMeaningfulAndOpaqueFacts() throws {
        var known = MappingEntry(
            id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!,
            commandID: 249,
            ioType: .input,
            assignment: .deckB,
            interactionMode: .direct,
            midiChannel: 3,
            midiCC: 22,
            modifier1Condition: ModifierCondition(modifier: 1, value: 2, target: .deckB),
            comment: "Filter amount",
            controllerType: .faderOrKnob,
            invert: true,
            softTakeover: true,
            setToValue: 0.75
        )
        let opaque = MappingEntry(
            id: UUID(uuidString: "40000000-0000-0000-0000-000000000004")!,
            commandID: 99_999,
            ioType: .output,
            rawMidiControlName: "Vendor Native Wheel",
            comment: "Opaque feedback",
            rawDCDTControlType: 0xDEAD_BEEF,
            rawDCDTMinValueBits: 0x7FC0_0001
        )
        let file = MappingFile(devices: [
            Device(id: deviceAID, name: "Deck controller", comment: "Primary", inPort: "Input A", outPort: "Output A", mappings: [known]),
            Device(id: deviceBID, name: "Unknown controller", comment: "Secondary", mappings: [opaque])
        ], version: 4)

        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Club map", revision: "rev-7")

        XCTAssertEqual(snapshot.title, "Club map")
        XCTAssertEqual(snapshot.revision, "rev-7")
        XCTAssertEqual(snapshot.devices.map(\.id), [deviceAID, deviceBID])
        XCTAssertEqual(snapshot.rows.map(\.id), [known.id, opaque.id])
        let knownFact = try XCTUnwrap(snapshot.rows.first)
        XCTAssertEqual(knownFact.deviceID, deviceAID)
        XCTAssertEqual(knownFact.position, 1)
        XCTAssertEqual(knownFact.command, "Slot Filter Adjust")
        XCTAssertEqual(knownFact.direction, "In")
        XCTAssertEqual(knownFact.assignment, "Deck B")
        XCTAssertEqual(knownFact.midi, "Ch03 CC 022")
        XCTAssertEqual(knownFact.modifierReads, [1])
        XCTAssertTrue(knownFact.conditions.contains { $0.contains("Deck B") && $0.contains("M1") && $0.contains("2") })
        XCTAssertTrue(knownFact.details.contains { $0.contains("Soft Takeover") })
        XCTAssertTrue(knownFact.details.contains { $0.contains("Invert") })
        XCTAssertEqual(knownFact.comment, "Filter amount")
        let opaqueFact = try XCTUnwrap(snapshot.rows.last)
        XCTAssertEqual(opaqueFact.commandID, 99_999)
        XCTAssertTrue(opaqueFact.limitations.contains { $0.localizedCaseInsensitiveContains("unknown command") })
        XCTAssertTrue(opaqueFact.limitations.contains { $0.localizedCaseInsensitiveContains("opaque") })
        XCTAssertTrue(opaqueFact.midi.contains("Vendor Native Wheel"))
    }

    func testSnapshotUsesPinnedProfileEvidenceAndReportsCustomMapUncertainty() throws {
        let documented = MappingEntry(id: UUID(uuidString: "50000000-0000-0000-0000-000000000005")!, commandID: 100,
                                      ioType: .input, midiChannel: 1, midiCC: 16)
        let custom = MappingEntry(id: UUID(uuidString: "60000000-0000-0000-0000-000000000006")!, commandID: 100,
                                  ioType: .input, midiChannel: 7, midiCC: 99)
        var file = MappingFile(devices: [
            Device(id: deviceAID, name: "K2 factory", mappings: [documented]),
            Device(id: deviceBID, name: "K2 custom", mappings: [custom])
        ])
        let factoryConfig = ControllerConfiguration(profileID: "allen-heath.xone-k2", version: "1.0.0", globalChannel: 1,
                                                    layerMode: "off", unitMap: "factory")
        let customConfig = ControllerConfiguration(profileID: "allen-heath.xone-k2", version: "1.0.0", globalChannel: 7,
                                                   layerMode: "off", unitMap: "custom-1")
        file.interchangeMetadata = SXMJSONMetadata(
            profileReferences: [.init(profileID: "allen-heath.xone-k2", version: "1.0.0")],
            physicalControls: [
                .init(mappingID: documented.id, profileID: "allen-heath.xone-k2", controlID: "fader.1"),
                .init(mappingID: custom.id, profileID: "allen-heath.xone-k2", controlID: "fader.1")
            ],
            localOverrides: [],
            deviceProfiles: [
                .init(deviceID: deviceAID, configuration: factoryConfig),
                .init(deviceID: deviceBID, configuration: customConfig)
            ]
        )

        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Profiles", revision: "1")

        XCTAssertEqual(snapshot.devices[0].profile, "allen-heath.xone-k2@1.0.0")
        XCTAssertTrue(snapshot.rows[0].controls.contains { $0.contains("fader.1") })
        XCTAssertTrue(snapshot.rows[0].sources.contains { $0.localizedCaseInsensitiveContains("manufacturer") })
        XCTAssertTrue(snapshot.rows[0].sources.contains { $0.contains("e") })
        XCTAssertTrue(snapshot.rows[1].limitations.contains { $0.localizedCaseInsensitiveContains("custom unit map") })
        XCTAssertFalse(snapshot.rows[1].sources.contains { $0.localizedCaseInsensitiveContains("manufacturer-documented") })
    }

    func testConfiguredProfileFindsControlsAcrossLayersWithoutLegacyAnnotations() throws {
        let greenFader = MappingEntry(id: UUID(uuidString: "61000000-0000-0000-0000-000000000006")!, commandID: 249,
                                      ioType: .input, midiChannel: 4, midiCC: 60)
        var file = MappingFile(devices: [Device(id: deviceAID, name: "Layered K2", mappings: [greenFader])])
        let configuration = ControllerConfiguration(profileID: "allen-heath.xone-k2", version: "1.0.0", globalChannel: 4,
                                                    layerMode: "all-controls", unitMap: "factory")
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [],
                                                   deviceProfiles: [.init(deviceID: deviceAID, configuration: configuration)])

        let row = try XCTUnwrap(MappingExplanationSnapshot.build(file: file, title: "Layers", revision: "1").rows.first)

        XCTAssertTrue(row.controls.contains { $0.contains("fader.1") && $0.localizedCaseInsensitiveContains("green") })
        XCTAssertTrue(row.sources.contains { $0.localizedCaseInsensitiveContains("manufacturer") })
        XCTAssertTrue(row.sources.contains { $0.contains("http") || $0.localizedCaseInsensitiveContains("page") })
        XCTAssertTrue(row.details.contains { $0.contains("allen-heath.xone-k2@1.0.0") })
        XCTAssertTrue(row.details.contains { $0.contains("all-controls") && $0.contains("factory") })
    }

    func testNonLayeredProfileDoesNotInventGreenLayerMatches() throws {
        let row = MappingEntry(commandID: 249, ioType: .input, midiChannel: 2, midiCC: 16)
        var file = MappingFile(devices: [Device(id: deviceAID, name: "K1", mappings: [row])])
        let configuration = ControllerConfiguration(profileID: "allen-heath.xone-k1", version: "1.0.0", globalChannel: 2,
                                                    layerMode: "off", unitMap: "factory")
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [],
                                                   deviceProfiles: [.init(deviceID: deviceAID, configuration: configuration)])

        let fact = try XCTUnwrap(MappingExplanationSnapshot.build(file: file, title: "K1", revision: "1").rows.first)

        XCTAssertTrue(fact.controls.contains { $0.contains("fader.1") && $0.contains("Fader") && $0.contains("send") })
        XCTAssertFalse(fact.controls.contains { $0.localizedCaseInsensitiveContains("green layer") })
    }

    func testCancelledSnapshotBuildThrowsCancellation() async throws {
        let mappings = (0..<20_000).map { MappingEntry(commandID: 100, comment: "row \($0)") }
        let file = MappingFile(devices: [Device(id: deviceAID, name: "Large", mappings: mappings)])
        let task = Task.detached {
            try MappingExplanationSnapshot.build(file: file, title: "Large", revision: "1")
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("A cancelled snapshot build must not publish a complete stale snapshot")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testOutputModifierObservesStateAndDoesNotClaimToWriteIt() throws {
        let output = MappingEntry(commandID: 2548, ioType: .output)
        let input = MappingEntry(commandID: 2549, ioType: .input)
        let rows = try MappingExplanationSnapshot.build(
            file: MappingFile(devices: [Device(id: deviceAID, name: "Modifiers", mappings: [output, input])]),
            title: "Directions", revision: "1"
        ).rows

        XCTAssertEqual(rows[0].modifierWrites, [])
        XCTAssertTrue(rows[0].details.contains { $0.localizedCaseInsensitiveContains("observes modifier 1") })
        XCTAssertEqual(rows[1].modifierWrites, [2])
    }

    func testModifierDependenciesStayInsideSelectedDevice() throws {
        let selected = MappingEntry(id: UUID(uuidString: "70000000-0000-0000-0000-000000000007")!, commandID: 100,
                                    modifier1Condition: ModifierCondition(modifier: 1, value: 1))
        let writerA = MappingEntry(id: UUID(uuidString: "80000000-0000-0000-0000-000000000008")!, commandID: 2548)
        let writerB = MappingEntry(id: UUID(uuidString: "90000000-0000-0000-0000-000000000009")!, commandID: 2548)
        let readerB = MappingEntry(id: UUID(uuidString: "a0000000-0000-0000-0000-00000000000a")!, commandID: 101,
                                   modifier1Condition: ModifierCondition(modifier: 1, value: 1))
        let file = MappingFile(devices: [
            Device(id: deviceAID, name: "A", mappings: [selected, writerA]),
            Device(id: deviceBID, name: "B", mappings: [writerB, readerB])
        ])
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Modifiers", revision: "2")

        let context = MappingExplanationQuery.retrieve(question: "How is M1 used?", snapshot: snapshot,
                                                       selectedIDs: [selected.id], limit: 80)

        XCTAssertEqual(context.rows.map(\.id), [selected.id, writerA.id])
        XCTAssertEqual(context.rows[0].modifierReads, [1])
        XCTAssertEqual(context.rows[1].modifierWrites, [1])
    }

    func testRetrievalFindsRelevantRowAfterFirstHundredAndKeepsSelectedFirst() throws {
        let unrelated = (0..<105).map { index in
            MappingEntry(commandID: 100, comment: "ordinary row \(index)")
        }
        let target = MappingEntry(id: UUID(uuidString: "b0000000-0000-0000-0000-00000000000b")!, commandID: 200,
                                  comment: "unique nebula filter control")
        let selected = unrelated[90]
        let file = MappingFile(devices: [Device(id: deviceAID, name: "Large", mappings: unrelated + [target])])
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Large", revision: "3")

        let context = MappingExplanationQuery.retrieve(question: "nebula filter", snapshot: snapshot,
                                                       selectedIDs: [selected.id], limit: 2)

        XCTAssertEqual(context.rows.map(\.id), [selected.id, target.id])
        XCTAssertEqual(context.totalRows, 106)
        XCTAssertEqual(context.omittedRows, 104)
        XCTAssertTrue(context.limitations.contains { $0.contains("104") && $0.localizedCaseInsensitiveContains("omitted") })
    }

    func testConversationalQuestionDoesNotFillResultsWithStopwordMatches() throws {
        let unrelated = (0..<100).map { index in
            MappingEntry(commandID: 100, comment: "the ordinary transport control \(index)")
        }
        let filter = MappingEntry(commandID: 249, comment: "resonant sweep")
        let snapshot = try MappingExplanationSnapshot.build(
            file: MappingFile(devices: [Device(id: deviceAID, name: "Large", mappings: unrelated + [filter])]),
            title: "Search", revision: "1"
        )

        let context = MappingExplanationQuery.retrieve(question: "What does the filter do?", snapshot: snapshot, limit: 5)

        XCTAssertEqual(context.rows.first?.id, filter.id)
        XCTAssertFalse(context.rows.contains { $0.comment.hasPrefix("the ordinary") })
    }

    func testExplicitModifierQuestionFindsLateReaderAndSameDeviceWriter() throws {
        let unrelated = (0..<100).map { MappingEntry(commandID: 100, comment: "profile version 1 ordinary row \($0)") }
        let reader = MappingEntry(commandID: 101, modifier1Condition: ModifierCondition(modifier: 1, value: 1))
        let writer = MappingEntry(commandID: 2548, ioType: .input)
        let snapshot = try MappingExplanationSnapshot.build(
            file: MappingFile(devices: [Device(id: deviceAID, name: "Modifier map", mappings: unrelated + [reader, writer])]),
            title: "Modifiers", revision: "1"
        )

        let context = MappingExplanationQuery.retrieve(question: "Explain modifier 1", snapshot: snapshot, limit: 80)

        XCTAssertEqual(context.rows.map(\.id), [reader.id, writer.id])
    }

    func testNoMatchReturnsNoUnrelatedRows() throws {
        let file = MappingFile(devices: [Device(id: deviceAID, name: "Small", mappings: [
            MappingEntry(commandID: 100, comment: "play button"),
            MappingEntry(commandID: 101, comment: "cue button")
        ])])
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Small", revision: "4")

        let context = MappingExplanationQuery.retrieve(question: "quasar resonance", snapshot: snapshot)

        XCTAssertTrue(context.rows.isEmpty)
        XCTAssertEqual(context.omittedRows, 2)
        XCTAssertTrue(context.limitations.contains { $0.localizedCaseInsensitiveContains("no matching") })
    }

    func testContextNeverExceedsNinetySixKiBAndReportsTruncatedStringsAndRows() throws {
        let huge = String(repeating: "long imported comment 🧪 ", count: 8_000)
        let mappings = (0..<10).map { index in
            MappingEntry(commandID: 100, comment: "needle \(index) \(huge)")
        }
        let file = MappingFile(devices: [Device(id: deviceAID, name: "Huge", mappings: mappings)])
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Huge", revision: "5")

        let context = MappingExplanationQuery.retrieve(question: "needle", snapshot: snapshot, limit: 80)
        let encoded = try JSONEncoder().encode(context)

        XCTAssertLessThanOrEqual(encoded.count, 96 * 1024)
        XCTAssertGreaterThan(context.omittedRows, 0)
        XCTAssertTrue(context.limitations.contains { $0.localizedCaseInsensitiveContains("truncated") })
        XCTAssertTrue(context.limitations.contains { $0.contains(String(context.omittedRows)) })
        XCTAssertTrue(context.rows.allSatisfy { !$0.comment.isEmpty && $0.comment.count < huge.count })
    }

    func testTopLevelLimitationsCannotPushContextPastNinetySixKiB() throws {
        let huge = String(repeating: "profile-\"\\🧪", count: 20_000)
        let row = MappingEntry(commandID: 100, comment: "selected")
        var file = MappingFile(devices: [Device(id: deviceAID, name: "Huge metadata", mappings: [row])])
        let configuration = ControllerConfiguration(profileID: huge, version: huge, globalChannel: 1,
                                                    layerMode: huge, unitMap: huge)
        file.interchangeMetadata = SXMJSONMetadata(profileReferences: [], physicalControls: [], localOverrides: [],
                                                   deviceProfiles: [.init(deviceID: deviceAID, configuration: configuration)])
        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Huge metadata", revision: "1")

        let context = MappingExplanationQuery.retrieve(question: "selected", snapshot: snapshot,
                                                       selectedIDs: [row.id])

        XCTAssertLessThanOrEqual(try JSONEncoder().encode(context).count, 96 * 1024)
        XCTAssertTrue(context.limitations.contains { $0.localizedCaseInsensitiveContains("truncated") })
    }

    func testImportedPreservationRisksBecomeFactsWithoutIncludingSourceBytes() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/TSI/traktor-4.4.x-sanitized-complete.tsi")
        let file = try TSIParser().parseDocument(Data(contentsOf: fixtureURL))

        let snapshot = try MappingExplanationSnapshot.build(file: file, title: "Imported", revision: "1")
        let guide = try MappingReferenceGuide.build(snapshot: snapshot)
        let joined = snapshot.limitations.joined(separator: " ")

        XCTAssertTrue(joined.contains("partialCMAD"))
        XCTAssertTrue(guide.plainText.contains("partialCMAD"))
        XCTAssertFalse(joined.contains("NIXML"))
        XCTAssertFalse(joined.contains("DeviceIO.Config.Controller"))
    }

    func testImportedUnknownEnumsRemainExplicitOnRowWithoutSourceEnvelope() throws {
        var row = MappingEntry(commandID: 100, assignment: .global, interactionMode: .hold, controllerType: .button)
        var payload = Data(repeating: 0, count: 120)
        func store(_ value: UInt32, at offset: Int) {
            var bigEndian = value.bigEndian
            withUnsafeBytes(of: &bigEndian) { payload.replaceSubrange(offset..<(offset + 4), with: $0) }
        }
        store(99, at: 0)
        store(98, at: 4)
        store(97, at: 8)
        store(UInt32(bitPattern: 96), at: 12)
        row.importedCMAD = try XCTUnwrap(ImportedCMAD(payload: payload, semanticAtImport: row))

        let fact = try XCTUnwrap(MappingExplanationSnapshot.build(
            file: MappingFile(devices: [Device(id: deviceAID, mappings: [row])]), title: "Opaque", revision: "1"
        ).rows.first)
        let limitations = fact.limitations.joined(separator: " ")

        for code in ["proprietaryDeviceType", "coercedControllerType", "coercedInteractionMode", "coercedTargetAssignment"] {
            XCTAssertTrue(limitations.contains(code), "Missing \(code)")
        }
    }

    func testBroadNumericFreeQueryHandlesTenThousandRelevantRoots() throws {
        let mappings = (0..<10_000).map { MappingEntry(commandID: 100, comment: "needle row \($0)") }
        let snapshot = try MappingExplanationSnapshot.build(
            file: MappingFile(devices: [Device(id: deviceAID, name: "Large", mappings: mappings)]),
            title: "Large", revision: "1"
        )

        let context = MappingExplanationQuery.retrieve(question: "needle", snapshot: snapshot, limit: 80)

        XCTAssertEqual(context.rows.count, 80)
        XCTAssertEqual(context.rows.first?.id, mappings.first?.id)
        XCTAssertEqual(context.omittedRows, 9_920)
    }
}
