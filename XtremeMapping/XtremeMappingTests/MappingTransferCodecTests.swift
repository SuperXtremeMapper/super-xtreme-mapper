//
//  MappingTransferCodecTests.swift
//  XtremeMappingTests
//

import XCTest
import UniformTypeIdentifiers
@testable import XtremeMapping

final class MappingTransferCodecTests: XCTestCase {
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

        let inserted = MappingTransferService.insertCopies(decoded, into: &destination)

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
