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
    }

    private struct Fixture: Decodable {
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
    }

    func testManifestMetadataAndHashesValidateBeforeFixturesAreUsed() throws {
        let manifest = try loadManifest()

        XCTAssertEqual(manifest.schemaVersion, 1)
        XCTAssertEqual(manifest.fixtures.map(\.filename), [
            "traktor-4.4.x-sanitized-complete.tsi",
            "generated-safe-minimal.tsi",
            "generated-unsafe-native.tsi",
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
            XCTAssertGreaterThanOrEqual(
                fixture.expectedRiskCount,
                fixture.expectedRiskCodes.count,
                fixture.filename
            )
            XCTAssertEqual(
                Set(fixture.expectedRiskCodes).count,
                fixture.expectedRiskCodes.count,
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
        return try JSONDecoder().decode(FixtureManifest.self, from: data)
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
        var seen: Set<TSIPreservationRisk.Code> = []
        let orderedUniqueCodes = risks.map(\.code).filter { seen.insert($0).inserted }
        XCTAssertEqual(
            orderedUniqueCodes,
            fixture.expectedRiskCodes,
            fixture.filename,
            file: file,
            line: line
        )
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
