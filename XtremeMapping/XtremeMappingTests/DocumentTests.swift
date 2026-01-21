//
//  DocumentTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import XCTest
import UniformTypeIdentifiers
@testable import XtremeMapping

final class DocumentTests: XCTestCase {
    func testDocumentReadableTypes() {
        let types = TraktorMappingDocument.readableContentTypes
        XCTAssertEqual(types.count, 1)
        XCTAssertEqual(types.first?.identifier, "com.native-instruments.traktor.tsi")
    }

    func testDocumentDefaultInit() {
        let doc = TraktorMappingDocument()
        XCTAssertTrue(doc.mappingFile.devices.isEmpty)
    }

    func testDocumentWithMappingFile() {
        let device = Device(name: "Test Device")
        let mappingFile = MappingFile(devices: [device])
        let doc = TraktorMappingDocument(mappingFile: mappingFile)
        XCTAssertEqual(doc.mappingFile.devices.count, 1)
    }

    // MARK: - Dirty State Tests

    func testDocumentStartsClean() {
        let doc = TraktorMappingDocument()
        XCTAssertFalse(doc.isDirty)
    }

    @MainActor
    func testNoteChangeSetsIsDirty() {
        let doc = TraktorMappingDocument()
        XCTAssertFalse(doc.isDirty)

        doc.noteChange()

        XCTAssertTrue(doc.isDirty)
    }

    func testBackingDocumentPropertyExists() {
        let doc = TraktorMappingDocument()
        // backingDocument should be nil initially (no NSDocument attached yet)
        XCTAssertNil(doc.backingDocument)
    }

    @MainActor
    func testNoteChangeMultipleTimesStaysDirty() {
        let doc = TraktorMappingDocument()

        doc.noteChange()
        doc.noteChange()
        doc.noteChange()

        XCTAssertTrue(doc.isDirty)
    }

    // MARK: - Snapshot Tests

    func testSnapshotReturnsCurrentMappingFile() throws {
        let device = Device(name: "Test Device", mappings: [
            MappingEntry(commandName: "Play", midiChannel: 1, midiNote: 60)
        ])
        let mappingFile = MappingFile(devices: [device])
        let doc = TraktorMappingDocument(mappingFile: mappingFile)

        let snapshot = try doc.snapshot(contentType: .tsi)

        XCTAssertEqual(snapshot.devices.count, 1)
        XCTAssertEqual(snapshot.devices.first?.name, "Test Device")
        XCTAssertEqual(snapshot.devices.first?.mappings.count, 1)
    }

    @MainActor
    func testMarkCleanResetsStaticDirtyTracking() {
        let testURL = URL(fileURLWithPath: "/tmp/test.tsi")

        // Initially should not be dirty
        XCTAssertFalse(TraktorMappingDocument.isDirty(for: testURL))

        // Create doc and make it dirty
        let doc = TraktorMappingDocument()
        doc.updateFileURL(testURL)
        doc.noteChange()

        // Now mark clean via static method
        TraktorMappingDocument.markClean(for: testURL)
        XCTAssertFalse(TraktorMappingDocument.isDirty(for: testURL))
    }
}

// MARK: - Test Helpers

extension UTType {
    static var tsi: UTType {
        UTType(importedAs: "com.native-instruments.traktor.tsi")
    }
}
