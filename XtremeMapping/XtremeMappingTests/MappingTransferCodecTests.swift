//
//  MappingTransferCodecTests.swift
//  XtremeMappingTests
//

import XCTest
import UniformTypeIdentifiers
@testable import XtremeMapping

final class MappingTransferCodecTests: XCTestCase {
    func testBuiltApplicationExportsMappingBatchUTType() throws {
        let expectedIdentifier = "com.superxtrememapping.mapping-batch"
        XCTAssertEqual(UTType.mappingBatch.identifier, expectedIdentifier)
        XCTAssertTrue(UTType.mappingBatch.conforms(to: .json))
        XCTAssertTrue(UTType.mappingBatch.conforms(to: .data))

        let declarations = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "UTExportedTypeDeclarations")
                as? [[String: Any]]
        )
        let declaration = try XCTUnwrap(declarations.first { declaration in
            declaration["UTTypeIdentifier"] as? String == expectedIdentifier
        })
        let conformances = try XCTUnwrap(declaration["UTTypeConformsTo"] as? [String])

        XCTAssertEqual(Set(conformances), Set(["public.json", "public.data"]))
    }

    func testCodecRoundTripsOrderedFullFieldMappingsWithoutChangingIDs() throws {
        let first = MappingEntry.fullFieldSentinel
        var second = first.copyWithNewID()
        second.commandID = 100
        second.comment = "Second ordered mapping"
        let source = [first, second]

        let encoded = try MappingBatchCodec.encode(source)
        let decoded = try MappingBatchCodec.decode(encoded)

        XCTAssertEqual(decoded, source)
        XCTAssertEqual(decoded.map(\.id), source.map(\.id))
        XCTAssertEqual(decoded.map(\.comment), ["Macro 🧪\nsecond line", "Second ordered mapping"])
    }

    func testCodecPreservesSourceIDsUntilTransferInsertionCreatesFreshIDs() throws {
        let source = [MappingEntry.fullFieldSentinel, MappingEntry(commandID: 201)]
        let sourceIDs = Set(source.map(\.id))
        let decoded = try MappingBatchCodec.decode(MappingBatchCodec.encode(source))
        var destination = MappingFile(devices: [Device(name: "Destination")])

        XCTAssertEqual(Set(decoded.map(\.id)), sourceIDs)

        let inserted = try MappingTransferService.insertCopies(
            decoded,
            into: &destination,
            targetDeviceID: destination.devices[0].id
        ).insertedIDs

        XCTAssertEqual(inserted.count, source.count)
        XCTAssertTrue(inserted.isDisjoint(with: sourceIDs))
        XCTAssertEqual(destination.allMappings.map(\.commandID), source.map(\.commandID))
        XCTAssertEqual(destination.allMappings[0].comment, source[0].comment)
        XCTAssertEqual(destination.allMappings[0].rawDCDTEncoderMode, 3)
    }

    @MainActor
    func testItemProviderPublishesAndLoadsCustomMappingBatch() async throws {
        let source = [MappingEntry.fullFieldSentinel, MappingEntry(commandID: 100)]
        let provider = MappingBatchCodec.itemProvider(for: source)

        XCTAssertTrue(
            provider.hasItemConformingToTypeIdentifier(UTType.mappingBatch.identifier)
        )

        let decoded = try await MappingBatchCodec.load(from: [provider])

        XCTAssertEqual(decoded, source)
    }

    @MainActor
    func testProviderLoadIgnoresUnrelatedProvidersAndFindsMappingBatch() async throws {
        let unrelated = NSItemProvider(object: "ordinary text" as NSString)
        let source = [MappingEntry.fullFieldSentinel]
        let mappingProvider = MappingBatchCodec.itemProvider(for: source)

        let decoded = try await MappingBatchCodec.load(
            from: [unrelated, mappingProvider]
        )

        XCTAssertEqual(decoded, source)
    }

    @MainActor
    func testProviderLoadRejectsOnlyUnrelatedProviders() async {
        let unrelated = NSItemProvider(object: "ordinary text" as NSString)

        do {
            _ = try await MappingBatchCodec.load(from: [unrelated])
            XCTFail("An unrelated provider must not decode as a mapping batch")
        } catch {
            XCTAssertFalse(error is DecodingError)
        }
    }
}
