//
//  XtremeMappingDocument.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

extension UTType {
    static var tsi: UTType {
        UTType(exportedAs: "com.native-instruments.traktor.tsi")
    }
}

/// Reference-based document that properly tracks changes for save prompts
final class TraktorMappingDocument: ReferenceFileDocument {
    typealias Snapshot = MappingFile

    @Published var mappingFile: MappingFile
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false

    private static let documentRegistry = NSMapTable<NSURL, TraktorMappingDocument>(
        keyOptions: .strongMemory,
        valueOptions: .weakMemory
    )

    static var readableContentTypes: [UTType] { [.tsi] }

    init(mappingFile: MappingFile = MappingFile()) {
        self.mappingFile = mappingFile
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Parse TSI file
        let parser = TSIParser()

        do {
            // Step 1: Extract Base64-encoded binary data from XML
            let base64String = try TSIParser.extractControllerData(from: data)

            // Step 2: Decode Base64 to binary data
            let binaryData = try parser.decodeBase64(base64String)

            // Step 3: Parse frames from binary data
            let frames = try parser.parseFrames(from: binaryData)

            // Step 4: Interpret frames into mappings
            self.mappingFile = try TSIInterpreter.interpret(frames: frames)

        } catch {
            print("TSI Parser error: \(error)")
            // Fall back to empty file on parse error
            self.mappingFile = MappingFile()
        }
    }

    func snapshot(contentType: UTType) throws -> MappingFile {
        return mappingFile
    }

    func fileWrapper(snapshot: MappingFile, configuration: WriteConfiguration) throws -> FileWrapper {
        let writer = TSIWriter()
        let data = writer.write(snapshot)
        return FileWrapper(regularFileWithContents: data)
    }

    @MainActor
    func noteChange() {
        isDirty = true
        objectWillChange.send()
        let controller = NSDocumentController.shared
        if let fileURL, let document = controller.document(for: fileURL) {
            document.updateChangeCount(.changeDone)
            print("noteChange: update via fileURL", fileURL.lastPathComponent, "edited:", document.isDocumentEdited,
                  "docId:", ObjectIdentifier(document))
        } else if let document = controller.currentDocument {
            document.updateChangeCount(.changeDone)
            print("noteChange: update via currentDocument", document.displayName ?? "Unknown",
                  "edited:", document.isDocumentEdited, "docId:", ObjectIdentifier(document))
        } else if let document = controller.documents.first {
            // Fallback for new/untitled documents: use the first (and likely only) open document
            // This works when wizard window is focused and currentDocument returns nil
            document.updateChangeCount(.changeDone)
            print("noteChange: update via documents.first", document.displayName ?? "Unknown",
                  "edited:", document.isDocumentEdited, "docId:", ObjectIdentifier(document))
        } else {
            print("noteChange: no NSDocument found", "fileURL:", fileURL?.absoluteString ?? "nil",
                  "documents:", controller.documents.count)
        }
    }

    @MainActor
    func updateFileURL(_ fileURL: URL?) {
        if let oldURL = self.fileURL as NSURL? {
            TraktorMappingDocument.documentRegistry.removeObject(forKey: oldURL)
        }

        self.fileURL = fileURL

        if let fileURL = fileURL as NSURL? {
            TraktorMappingDocument.documentRegistry.setObject(self, forKey: fileURL)
        }

        if let fileURL {
            print("updateFileURL:", fileURL.lastPathComponent)
        } else {
            print("updateFileURL: nil")
        }
    }

    static func isDirty(for fileURL: URL?) -> Bool {
        guard let fileURL = fileURL as NSURL? else { return false }
        return documentRegistry.object(forKey: fileURL)?.isDirty ?? false
    }

    @MainActor
    static func markClean(for fileURL: URL?) {
        guard let fileURL = fileURL as NSURL? else { return }
        documentRegistry.object(forKey: fileURL)?.isDirty = false
    }
}
