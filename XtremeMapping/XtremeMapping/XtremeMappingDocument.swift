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

    /// Set when a change arrives before the backing NSDocument is resolved;
    /// flushed (once) the moment `backingDocument` attaches.
    private(set) var hasPendingDirty = false

    /// Weak reference to the backing NSDocument for change tracking.
    /// Resolved by `DocumentWindowAccessor` when the document window attaches.
    weak var backingDocument: NSDocument? {
        didSet {
            if let doc = backingDocument {
                // Instance-keyed association: the save callback resolves by
                // NSDocument identity first, because URL lookup misses
                // untitled first-save / Save As (new URL not registered yet).
                TraktorMappingDocument.nsDocumentRegistry.setObject(self, forKey: doc)
            }
            guard hasPendingDirty, let doc = backingDocument else { return }
            hasPendingDirty = false
            MainActor.assumeIsolated {
                doc.updateChangeCount(.changeDone)
            }
        }
    }

    private static let documentRegistry = NSMapTable<NSURL, TraktorMappingDocument>(
        keyOptions: .strongMemory,
        valueOptions: .weakMemory
    )

    /// NSDocument → SwiftUI document, weak on both sides so neither the
    /// AppKit document nor ours is kept alive by the registry.
    private static let nsDocumentRegistry = NSMapTable<NSDocument, TraktorMappingDocument>.weakToWeakObjects()

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
            throw error
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

        // Safe secondary: fileURL-keyed lookup (fileURL is unique per document).
        // Never guess via currentDocument/documents.first — a wrong cache
        // cross-wires dirty state between documents.
        if backingDocument == nil, let fileURL,
           let document = NSDocumentController.shared.document(for: fileURL) {
            backingDocument = document  // didSet flushes any pending dirty
        }

        if let doc = backingDocument {
            doc.updateChangeCount(.changeDone)
        } else {
            // Unresolved — remember the change; flushed when the window
            // accessor attaches the backing document.
            hasPendingDirty = true
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

        #if DEBUG
        if let fileURL {
            print("updateFileURL:", fileURL.lastPathComponent)
        } else {
            print("updateFileURL: nil")
        }
        #endif
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

    /// Clear dirty state for the document backed by `nsDocument`.
    /// Resolves by NSDocument identity first (covers untitled first-save and
    /// Save As, where the new URL isn't registered yet), URL second.
    @MainActor
    static func markClean(nsDocument: NSDocument) {
        if let document = nsDocumentRegistry.object(forKey: nsDocument) {
            document.isDirty = false
        } else {
            markClean(for: nsDocument.fileURL)
        }
    }
}
