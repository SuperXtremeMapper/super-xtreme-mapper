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

    func testNoteChangeMultipleTimesStaysDirty() {
        let doc = TraktorMappingDocument()

        doc.noteChange()
        doc.noteChange()
        doc.noteChange()

        XCTAssertTrue(doc.isDirty)
    }

    // MARK: - Snapshot Tests

    func testSnapshotReturnsCurrentMappingFile() {
        let device = Device(name: "Test Device", mappings: [
            MappingEntry(commandName: "Play", midiChannel: 1, midiNote: 60)
        ])
        let mappingFile = MappingFile(devices: [device])
        let doc = TraktorMappingDocument(mappingFile: mappingFile)

        let snapshot = doc.snapshot(contentType: .tsi)

        XCTAssertEqual(snapshot.devices.count, 1)
        XCTAssertEqual(snapshot.devices.first?.name, "Test Device")
        XCTAssertEqual(snapshot.devices.first?.mappings.count, 1)
    }

    func testMarkCleanResetsStaticDirtyTracking() {
        let doc = TraktorMappingDocument()
        let testURL = URL(fileURLWithPath: "/tmp/test.tsi")
        doc.updateFileURL(testURL)

        // Mark dirty
        TraktorMappingDocument.markDirty(for: testURL)
        XCTAssertTrue(TraktorMappingDocument.isDirty(for: testURL))

        // Mark clean
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
