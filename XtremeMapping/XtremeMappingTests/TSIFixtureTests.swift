//
//  TSIFixtureTests.swift
//  XtremeMappingTests
//

import XCTest
import CryptoKit
@testable import XtremeMapping

final class TSIFixtureTests: XCTestCase {
    private enum FixtureValidationError: Error, Equatable {
        case hashMismatch(expected: String, actual: String)
        case unknownKeys(path: String, keys: [String])
    }

    private enum FixtureProvenance: String, Decodable {
        case realExport
        case generated
        case capturedFragment
    }

    private enum FixtureCompleteness: String, Decodable {
        case completeDocument
        case capturedFragment
    }

    private struct FixtureManifest: Decodable {
        let schemaVersion: Int
        let fixtures: [Fixture]

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case schemaVersion
            case fixtures
        }

        init(from decoder: Decoder) throws {
            try Self.rejectUnknownKeys(
                from: decoder,
                allowed: Set(CodingKeys.allCases.map(\.rawValue)),
                path: "manifest"
            )
            let values = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
            fixtures = try values.decode([Fixture].self, forKey: .fixtures)
        }

        private static func rejectUnknownKeys(
            from decoder: Decoder,
            allowed: Set<String>,
            path: String
        ) throws {
            let values = try decoder.container(keyedBy: AnyCodingKey.self)
            let unknown = values.allKeys.map(\.stringValue).filter { !allowed.contains($0) }.sorted()
            if !unknown.isEmpty {
                throw FixtureValidationError.unknownKeys(path: path, keys: unknown)
            }
        }
    }

    private struct Fixture: Decodable {
        struct RiskRun: Decodable, Equatable {
            let code: TSIPreservationRisk.Code
            let count: Int
        }

        let filename: String
        let sha256: String
        let provenance: FixtureProvenance
        let completeness: FixtureCompleteness
        let evidencedVersion: String?
        let controller: String
        let source: String
        let license: String
        let sanitization: [String]
        let expectedDisposition: TSIPreservationDisposition
        let expectedRiskCount: Int
        let expectedRiskCodes: [TSIPreservationRisk.Code]
        let expectedRiskRuns: [RiskRun]

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case filename
            case sha256
            case provenance
            case completeness
            case evidencedVersion
            case controller
            case source
            case license
            case sanitization
            case expectedDisposition
            case expectedRiskCount
            case expectedRiskCodes
            case expectedRiskRuns
        }

        init(from decoder: Decoder) throws {
            let dynamicValues = try decoder.container(keyedBy: AnyCodingKey.self)
            let allowed = Set(CodingKeys.allCases.map(\.rawValue))
            let unknown = dynamicValues.allKeys.map(\.stringValue)
                .filter { !allowed.contains($0) }
                .sorted()
            if !unknown.isEmpty {
                throw FixtureValidationError.unknownKeys(path: "fixture", keys: unknown)
            }

            let values = try decoder.container(keyedBy: CodingKeys.self)
            filename = try values.decode(String.self, forKey: .filename)
            sha256 = try values.decode(String.self, forKey: .sha256)
            provenance = try values.decode(FixtureProvenance.self, forKey: .provenance)
            completeness = try values.decode(FixtureCompleteness.self, forKey: .completeness)
            evidencedVersion = try values.decodeIfPresent(String.self, forKey: .evidencedVersion)
            controller = try values.decode(String.self, forKey: .controller)
            source = try values.decode(String.self, forKey: .source)
            license = try values.decode(String.self, forKey: .license)
            sanitization = try values.decode([String].self, forKey: .sanitization)
            expectedDisposition = try values.decode(
                TSIPreservationDisposition.self,
                forKey: .expectedDisposition
            )
            expectedRiskCount = try values.decode(Int.self, forKey: .expectedRiskCount)
            expectedRiskCodes = try values.decodeIfPresent(
                [TSIPreservationRisk.Code].self,
                forKey: .expectedRiskCodes
            ) ?? []
            expectedRiskRuns = try values.decodeIfPresent(
                [RiskRun].self,
                forKey: .expectedRiskRuns
            ) ?? []
            guard values.contains(.expectedRiskCodes) != values.contains(.expectedRiskRuns) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .expectedRiskCodes,
                    in: values,
                    debugDescription: "Specify exactly one risk sequence representation"
                )
            }
            guard expectedRiskRuns.allSatisfy({ $0.count > 0 }) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .expectedRiskRuns,
                    in: values,
                    debugDescription: "Risk run counts must be positive"
                )
            }
        }

        var encodedRiskCount: Int {
            expectedRiskCodes.isEmpty
                ? expectedRiskRuns.reduce(0) { $0 + $1.count }
                : expectedRiskCodes.count
        }
    }

    private struct AnyCodingKey: CodingKey {
        let stringValue: String
        let intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            intValue = nil
        }

        init?(intValue: Int) {
            stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    func testManifestMetadataAndHashesValidateBeforeFixturesAreUsed() throws {
        let manifest = try loadManifest()

        XCTAssertEqual(manifest.schemaVersion, 2)
        XCTAssertEqual(manifest.fixtures.map(\.filename), [
            "traktor-4.4.x-sanitized-complete.tsi",
            "generated-safe-minimal.tsi",
            "generated-unsafe-native.tsi",
            "traktor-4.5.1-xone-k3-benchmark-01-continuous.tsi",
            "traktor-4.5.1-xone-k3-benchmark-02-fx.tsi",
            "traktor-4.5.1-xone-k3-benchmark-03-sequencer.tsi",
            "traktor-4.5.1-xone-k3-benchmark-04-remix.tsi",
            "traktor-4.5.1-xone-k3-benchmark-05-core-safe.tsi",
            "traktor-4.5.1-xone-k3-benchmark-06-outputs-comments-modifiers.tsi",
        ])
        XCTAssertEqual(Set(manifest.fixtures.map(\.filename)).count, manifest.fixtures.count)
        let fixtureFiles = try FileManager.default.contentsOfDirectory(
            at: fixtureDirectory,
            includingPropertiesForKeys: nil
        )
            .filter { $0.pathExtension == "tsi" }
            .map(\.lastPathComponent)
            .sorted()
        XCTAssertEqual(fixtureFiles, manifest.fixtures.map(\.filename).sorted())

        for fixture in manifest.fixtures {
            XCTAssertEqual(fixture.filename, URL(fileURLWithPath: fixture.filename).lastPathComponent)
            XCTAssertFalse(fixture.controller.isEmpty, fixture.filename)
            XCTAssertFalse(fixture.source.isEmpty, fixture.filename)
            XCTAssertFalse(fixture.license.isEmpty, fixture.filename)
            XCTAssertFalse(fixture.sanitization.isEmpty, fixture.filename)
            XCTAssertEqual(fixture.sha256.count, 64, fixture.filename)
            XCTAssertTrue(fixture.sha256.allSatisfy { $0.isHexDigit && !$0.isUppercase }, fixture.filename)
            XCTAssertEqual(
                fixture.expectedRiskCount,
                fixture.encodedRiskCount,
                fixture.filename
            )
            let data = try loadFixture(fixture)
            XCTAssertEqual(sha256(data), fixture.sha256, fixture.filename)

            if fixture.provenance == .realExport {
                XCTAssertEqual(fixture.completeness, .completeDocument, fixture.filename)
                XCTAssertNotNil(fixture.evidencedVersion, fixture.filename)
            } else if fixture.provenance == .generated {
                XCTAssertNil(fixture.evidencedVersion, fixture.filename)
            }
        }
    }

    func testFixtureHarnessRejectsUnknownMetadataMissingFilesAndWrongHashes() throws {
        let manifestData = try Data(
            contentsOf: fixtureDirectory.appendingPathComponent("manifest.json")
        )
        let manifestText = try XCTUnwrap(String(data: manifestData, encoding: .utf8))
        let unknownMetadata = Data(
            manifestText.replacingOccurrences(
                of: "\"realExport\"",
                with: "\"unknownOrigin\""
            ).utf8
        )
        XCTAssertThrowsError(try JSONDecoder().decode(FixtureManifest.self, from: unknownMetadata))

        XCTAssertThrowsError(
            try validateHash(Data("changed fixture".utf8), expected: String(repeating: "0", count: 64))
        ) { error in
            XCTAssertTrue(error is FixtureValidationError)
        }
        XCTAssertThrowsError(
            try Data(contentsOf: fixtureDirectory.appendingPathComponent("missing.tsi"))
        )
    }

    func testManifestAcceptsRunLengthEncodedRiskSequences() throws {
        let json = Data(#"""
        {
          "schemaVersion": 2,
          "fixtures": [{
            "filename": "fixture.tsi",
            "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
            "provenance": "realExport",
            "completeness": "completeDocument",
            "evidencedVersion": "4.5.1",
            "controller": "Generic MIDI",
            "source": "test",
            "license": "test",
            "sanitization": ["test"],
            "expectedDisposition": "lossyConvertible",
            "expectedRiskCount": 3,
            "expectedRiskRuns": [{"code": "unusedMIDIDefinition", "count": 3}]
          }]
        }
        """#.utf8)

        XCTAssertNoThrow(try decodeManifest(json))
    }

    func testManifestRejectsUnknownRootAndFixtureKeys() throws {
        let manifestData = try Data(
            contentsOf: fixtureDirectory.appendingPathComponent("manifest.json")
        )
        let manifestText = try XCTUnwrap(String(data: manifestData, encoding: .utf8))
        let unknownRoot = Data(
            manifestText.replacingOccurrences(
                of: "\"schemaVersion\": 2,",
                with: "\"schemaVersion\": 2, \"unexpectedRoot\": true,"
            ).utf8
        )
        XCTAssertThrowsError(try decodeManifest(unknownRoot)) { error in
            XCTAssertEqual(
                error as? FixtureValidationError,
                .unknownKeys(path: "manifest", keys: ["unexpectedRoot"])
            )
        }

        let unknownFixture = Data(
            manifestText.replacingOccurrences(
                of: "\"filename\": \"traktor-4.4.x-sanitized-complete.tsi\",",
                with: "\"filename\": \"traktor-4.4.x-sanitized-complete.tsi\", \"unexpectedFixture\": true,"
            ).utf8
        )
        XCTAssertThrowsError(try decodeManifest(unknownFixture)) { error in
            XCTAssertEqual(
                error as? FixtureValidationError,
                .unknownKeys(path: "fixture", keys: ["unexpectedFixture"])
            )
        }
    }

    func testEveryCompleteDocumentFixtureHasExactDocumentLayerNoOp() throws {
        let completeFixtures = try loadManifest().fixtures.filter {
            $0.completeness == .completeDocument
        }
        XCTAssertEqual(completeFixtures.count, 9)

        for fixture in completeFixtures {
            let source = try loadFixture(fixture)
            let document = try TraktorMappingDocument(fileContents: source)
            let snapshot = try document.snapshot(contentType: .tsi)

            XCTAssertEqual(snapshot.plan.disposition, .originalPassthrough, fixture.filename)
            XCTAssertEqual(
                document.fileWrapper(for: snapshot).regularFileContents,
                source,
                fixture.filename
            )
            document.discardPendingWrite()
        }
    }

    func testComplete441FixtureOpensAndDocumentNoOpIsByteExact() throws {
        let fixture = try fixture(named: "traktor-4.4.x-sanitized-complete.tsi")
        let source = try loadFixture(fixture)
        let document = try TraktorMappingDocument(fileContents: source)

        XCTAssertFalse(document.mappingFile.devices.isEmpty)
        XCTAssertEqual(document.mappingFile.devices.first?.mappings.count, 112)
        XCTAssertTrue(document.mappingFile.devices[0].mappings.contains {
            $0.rawMidiControlName == "Ch16.CC.16"
                && $0.midiChannel == 16
                && $0.midiCC == 16
        })
        XCTAssertEqual(
            TSIWriter().preservationReport(for: document.mappingFile).disposition,
            fixture.expectedDisposition
        )
        assertRisks(document.mappingFile.sourceEnvelope?.risks ?? [], match: fixture)

        let snapshot = try document.snapshot(contentType: .tsi)
        let wrapper = document.fileWrapper(for: snapshot)
        XCTAssertEqual(snapshot.plan.disposition, .originalPassthrough)
        XCTAssertEqual(wrapper.regularFileContents, source)
        document.discardPendingWrite()
    }

    func testComplete451BenchmarkFixturesPreserveObservedCommandsAndAssignments() throws {
        let expectedRows = [
            "traktor-4.5.1-xone-k3-benchmark-01-continuous.tsi": 8,
            "traktor-4.5.1-xone-k3-benchmark-02-fx.tsi": 8,
            "traktor-4.5.1-xone-k3-benchmark-03-sequencer.tsi": 7,
            "traktor-4.5.1-xone-k3-benchmark-04-remix.tsi": 9,
            "traktor-4.5.1-xone-k3-benchmark-05-core-safe.tsi": 3,
            "traktor-4.5.1-xone-k3-benchmark-06-outputs-comments-modifiers.tsi": 8,
        ]

        for (name, rowCount) in expectedRows {
            let source = try loadFixture(try fixture(named: name))
            let document = try TraktorMappingDocument(fileContents: source)
            XCTAssertEqual(document.mappingFile.devices.first?.mappings.count, rowCount, name)
            XCTAssertEqual(document.mappingFile.devices.first?.inPort, "XONE:K3 (XONE:K3)", name)
        }

        let fxSource = try loadFixture(
            try fixture(named: "traktor-4.5.1-xone-k3-benchmark-02-fx.tsi")
        )
        let fxMappings = try TraktorMappingDocument(fileContents: fxSource)
            .mappingFile.devices.first?.mappings ?? []
        XCTAssertTrue(fxMappings.contains {
            $0.commandID == 335
                && $0.commandName == "FX Unit Mode Selector (Traktor 4.5.1)"
                && $0.assignment == .fxUnit1
        })
        XCTAssertFalse(fxMappings.contains { $0.commandID == 375 })

        let sequencerSource = try loadFixture(
            try fixture(named: "traktor-4.5.1-xone-k3-benchmark-03-sequencer.tsi")
        )
        let sequencerMappings = try TraktorMappingDocument(fileContents: sequencerSource)
            .mappingFile.devices.first?.mappings ?? []
        XCTAssertFalse(sequencerMappings.contains { $0.commandID == 739 })

        let safeCoreSource = try loadFixture(
            try fixture(named: "traktor-4.5.1-xone-k3-benchmark-05-core-safe.tsi")
        )
        let safeCoreMappings = try TraktorMappingDocument(fileContents: safeCoreSource)
            .mappingFile.devices.first?.mappings ?? []
        XCTAssertEqual(safeCoreMappings.map(\.commandID), [202, 2350, 2328])
        XCTAssertTrue(safeCoreMappings.allSatisfy {
            guard !(2548...2555).contains($0.commandID),
                  case nil = $0.modifier1Condition,
                  case nil = $0.modifier2Condition else {
                return false
            }
            return true
        })

        let outputSource = try loadFixture(
            try fixture(named: "traktor-4.5.1-xone-k3-benchmark-06-outputs-comments-modifiers.tsi")
        )
        let outputDocument = try TraktorMappingDocument(fileContents: outputSource)
        let outputMappings = outputDocument.mappingFile.devices.first?.mappings ?? []
        XCTAssertTrue(outputDocument.mappingFile.tsiCompatibilityWarnings.isEmpty)
        XCTAssertEqual(outputMappings.map(\.commandID), [100, 125, 202, 2350, 2548, 2548, 2548, 2548])
        XCTAssertEqual(outputMappings.prefix(4).map(\.ioType), [.output, .output, .output, .output])
        XCTAssertEqual(outputMappings.prefix(4).map(\.controllerType), [.led, .led, .led, .led])
        XCTAssertEqual(outputMappings.prefix(4).map(\.mappedToDisplay), [
            "Ch12 Note C2", "Ch12 Note C#2", "Ch12 Note D2", "Ch12 Note D#2",
        ])
        XCTAssertEqual(outputMappings.prefix(4).map(\.ledBlend), [true, false, false, true])
        XCTAssertEqual(outputMappings.prefix(4).map(\.ledInvert), [false, true, false, true])
        XCTAssertEqual(outputMappings.suffix(4).map(\.interactionMode), [
            .hold, .increment, .decrement, .reset,
        ])
        XCTAssertEqual(outputMappings.suffix(4).map(\.setToValue), [1, 0, 0, 0])
        XCTAssertEqual(outputMappings.map { $0.importedCMAD?.commentWasLossy }, [
            false, false, false, false, false, false, false, false,
        ])
        XCTAssertTrue(outputMappings[0].comment.contains("lengthy macro documentation"))
        XCTAssertEqual(outputMappings[1].comment, "D")
        XCTAssertTrue(outputMappings[2].comment.contains("café — 日本語 — ✓"))
        XCTAssertTrue(outputMappings[3].comment.contains("Emoji test 😀"))
    }

    func test451RemixFixtureEvidenceForStemsWizard() throws {
        let source = try loadFixture(
            try fixture(named: "traktor-4.5.1-xone-k3-benchmark-04-remix.tsi")
        )
        let mappings = try TraktorMappingDocument(fileContents: source)
            .mappingFile.devices.first?.mappings ?? []

        XCTAssertEqual(mappings.map(\.commandID), [251, 251, 259, 259, 249, 250, 239, 601, 664])

        let stemControls = Array(mappings.prefix(7))
        XCTAssertTrue(stemControls.allSatisfy { $0.ioType == .input })
        XCTAssertEqual(stemControls.map(\.assignment), [
            .remixDeckASlot1, .remixDeckASlot4,
            .remixDeckASlot1, .remixDeckASlot4,
            .remixDeckASlot1, .remixDeckASlot1, .remixDeckASlot1,
        ])
        XCTAssertEqual(stemControls.map(\.controllerType), [
            .faderOrKnob, .faderOrKnob,
            .button, .button,
            .faderOrKnob, .button, .button,
        ])
        XCTAssertEqual(stemControls.map(\.interactionMode), [
            .direct, .direct,
            .toggle, .toggle,
            .direct, .toggle, .toggle,
        ])
    }

    func testGeneratedSafeFixtureRegeneratesAtDocumentLayer() throws {
        let fixture = try fixture(named: "generated-safe-minimal.tsi")
        let source = try loadFixture(fixture)
        let document = try TraktorMappingDocument(fileContents: source)

        XCTAssertEqual(
            TSIWriter().preservationReport(for: document.mappingFile).disposition,
            fixture.expectedDisposition
        )
        assertRisks(document.mappingFile.sourceEnvelope?.risks ?? [], match: fixture)

        document.mappingFile.devices[0].comment = "fixture regeneration"
        let snapshot = try document.snapshot(contentType: .tsi)
        let output = try XCTUnwrap(document.fileWrapper(for: snapshot).regularFileContents)
        XCTAssertEqual(snapshot.plan.disposition, .regenerated)
        XCTAssertNotEqual(output, source)
        XCTAssertEqual(
            try TSIParser().parseDocument(output).devices.first?.comment,
            "fixture regeneration"
        )
        document.discardPendingWrite()
    }

    func testGeneratedUnsafeNativeFixtureHasStableRiskOrderAndRequiresConversion() throws {
        let fixture = try fixture(named: "generated-unsafe-native.tsi")
        let source = try loadFixture(fixture)
        let unchangedDocument = try TraktorMappingDocument(fileContents: source)

        XCTAssertEqual(
            TSIWriter().preservationReport(for: unchangedDocument.mappingFile).disposition,
            fixture.expectedDisposition
        )
        assertRisks(unchangedDocument.mappingFile.sourceEnvelope?.risks ?? [], match: fixture)

        let noOp = try unchangedDocument.snapshot(contentType: .tsi)
        XCTAssertEqual(
            unchangedDocument.fileWrapper(for: noOp).regularFileContents,
            source
        )
        unchangedDocument.discardPendingWrite()

        var edited = unchangedDocument.mappingFile
        edited.devices[0].comment = "converted fixture"
        let editedDocument = TraktorMappingDocument(mappingFile: edited)
        XCTAssertThrowsError(try editedDocument.snapshot(contentType: .tsi)) { error in
            XCTAssertEqual(
                error as? TSIPreservationError,
                .unsafeOverwrite(risks: edited.sourceEnvelope?.risks ?? [])
            )
        }

        let convertedPlan = try TSIWriter().makeConvertedWritePlan(for: edited)
        XCTAssertEqual(convertedPlan.report.disposition, .lossyConvertible)
        assertRisks(convertedPlan.report.risks, match: fixture)
        let convertedSnapshot = DocumentWriteSnapshot(
            mappingFile: edited,
            plan: convertedPlan,
            generation: 0
        )
        let convertedBytes = try XCTUnwrap(
            editedDocument.fileWrapper(for: convertedSnapshot).regularFileContents
        )
        let converted = try TSIParser().parseDocument(convertedBytes)
        XCTAssertEqual(converted.devices.first?.comment, "converted fixture")
        XCTAssertEqual(converted.devices.first?.name, "Generic MIDI")
    }

    private func fixture(named filename: String) throws -> Fixture {
        let manifest = try loadManifest()
        return try XCTUnwrap(manifest.fixtures.first { $0.filename == filename })
    }

    private func loadManifest() throws -> FixtureManifest {
        let data = try Data(contentsOf: fixtureDirectory.appendingPathComponent("manifest.json"))
        return try decodeManifest(data)
    }

    private func decodeManifest(_ data: Data) throws -> FixtureManifest {
        try JSONDecoder().decode(FixtureManifest.self, from: data)
    }

    private func loadFixture(_ fixture: Fixture) throws -> Data {
        let url = fixtureDirectory.appendingPathComponent(fixture.filename)
        let data = try Data(contentsOf: url)
        try validateHash(data, expected: fixture.sha256)
        return data
    }

    private func validateHash(_ data: Data, expected: String) throws {
        let actual = sha256(data)
        guard actual == expected else {
            throw FixtureValidationError.hashMismatch(expected: expected, actual: actual)
        }
    }

    private func assertRisks(
        _ risks: [TSIPreservationRisk],
        match fixture: Fixture,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(risks.count, fixture.expectedRiskCount, fixture.filename, file: file, line: line)
        XCTAssertEqual(
            fixture.expectedRiskRuns.isEmpty ? [] : riskRuns(for: risks),
            fixture.expectedRiskRuns,
            fixture.filename,
            file: file,
            line: line
        )
        if fixture.expectedRiskRuns.isEmpty {
            XCTAssertEqual(
                risks.map(\.code),
                fixture.expectedRiskCodes,
                fixture.filename,
                file: file,
                line: line
            )
        }
    }

    private func riskRuns(for risks: [TSIPreservationRisk]) -> [Fixture.RiskRun] {
        var result: [Fixture.RiskRun] = []
        for code in risks.map(\.code) {
            if let last = result.last, last.code == code {
                result[result.count - 1] = .init(code: code, count: last.count + 1)
            } else {
                result.append(.init(code: code, count: 1))
            }
        }
        return result
    }

    private var fixtureDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/TSI", isDirectory: true)
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
