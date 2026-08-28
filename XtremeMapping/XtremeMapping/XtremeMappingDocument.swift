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

nonisolated struct DocumentWriteSnapshot: Sendable {
    let mappingFile: MappingFile
    let plan: TSIWritePlan
    let generation: UInt64
}

nonisolated enum DocumentSaveLifecycleError: Error, Equatable, LocalizedError {
    case writeAlreadyInFlight
    case noWriteInFlight

    var errorDescription: String? {
        switch self {
        case .writeAlreadyInFlight:
            "A save is already in progress for this document."
        case .noWriteInFlight:
            "There is no pending document write to complete."
        }
    }
}

/// Reference-based document that properly tracks changes for save prompts
final class TraktorMappingDocument: ReferenceFileDocument {
    typealias Snapshot = DocumentWriteSnapshot

    private enum WriteReceiptOrigin: Equatable {
        case coordinated
        case uncoordinated
    }

    private struct PendingWriteReceipt {
        let snapshot: DocumentWriteSnapshot
        let origin: WriteReceiptOrigin
    }

    @Published var mappingFile: MappingFile
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false

    /// Set when a change arrives before the backing NSDocument is resolved;
    /// flushed (once) the moment `backingDocument` attaches.
    private(set) var hasPendingDirty = false
    private var nextWriteGeneration: UInt64 = 0
    private var pendingWrite: PendingWriteReceipt?
    private var coordinatedWriteInFlight = false
    private var coordinatedSnapshotPrepared = false

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

    init(fileContents data: Data) throws {
        self.mappingFile = try TSIParser().parseDocument(data)
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        do {
            self.mappingFile = try TSIParser().parseDocument(data)
        } catch {
            print("TSI Parser error: \(error)")
            throw error
        }
    }

    func prepareWriteSnapshot() throws -> DocumentWriteSnapshot {
        let origin: WriteReceiptOrigin
        if coordinatedWriteInFlight {
            guard !coordinatedSnapshotPrepared else {
                throw DocumentSaveLifecycleError.writeAlreadyInFlight
            }
            origin = .coordinated
        } else {
            if pendingWrite?.origin == .coordinated {
                throw DocumentSaveLifecycleError.writeAlreadyInFlight
            }
            // NSDocument serializes writes. For an uncoordinated write, arrival
            // of the next serialized snapshot is the only safe boundary at
            // which this model can treat the old receipt as abandoned.
            origin = .uncoordinated
        }

        let capturedMapping = mappingFile
        let plan = try TSIWriter().makeWritePlan(for: capturedMapping)
        nextWriteGeneration &+= 1
        let snapshot = DocumentWriteSnapshot(
            mappingFile: capturedMapping,
            plan: plan,
            generation: nextWriteGeneration
        )
        pendingWrite = PendingWriteReceipt(snapshot: snapshot, origin: origin)
        if origin == .coordinated {
            coordinatedSnapshotPrepared = true
        }
        return snapshot
    }

    func snapshot(contentType: UTType) throws -> DocumentWriteSnapshot {
        try prepareWriteSnapshot()
    }

    func fileWrapper(for snapshot: DocumentWriteSnapshot) -> FileWrapper {
        FileWrapper(regularFileWithContents: snapshot.plan.output)
    }

    func fileWrapper(
        snapshot: DocumentWriteSnapshot,
        configuration: WriteConfiguration
    ) throws -> FileWrapper {
        fileWrapper(for: snapshot)
    }

    /// Finalizes the sole receipt only after NSDocument reports success.
    func commitPendingWrite() throws {
        guard try commitPendingWriteIfPresent() else {
            throw DocumentSaveLifecycleError.noWriteInFlight
        }
    }

    /// Idempotent finalization used by the coordinator's AppKit completion.
    @discardableResult
    func commitPendingWriteIfPresent() throws -> Bool {
        guard let pendingReceipt = pendingWrite else { return false }
        let receipt = pendingReceipt.snapshot

        if receipt.plan.disposition == .regenerated {
            let reparsed = try TSIParser().parseDocument(receipt.plan.output)
            guard let parsedEnvelope = reparsed.sourceEnvelope else {
                throw CocoaError(.fileReadCorruptFile)
            }
            mappingFile.sourceEnvelope = TSIRawEnvelope(
                originalXML: parsedEnvelope.originalXML,
                controllerValues: parsedEnvelope.controllerValues,
                primaryFrames: parsedEnvelope.primaryFrames,
                baseline: receipt.plan.baseline,
                risks: parsedEnvelope.risks
            )
        }

        pendingWrite = nil
        let savedMappingIsCurrent = receipt.plan.baseline.matches(mappingFile)
        isDirty = !savedMappingIsCurrent
        if savedMappingIsCurrent {
            hasPendingDirty = false
        }
        objectWillChange.send()
        return true
    }

    /// Cancels correlation after a failed or user-cancelled NSDocument save.
    func discardPendingWrite() {
        pendingWrite = nil
    }

    /// Marks the AppKit operation before it can request a SwiftUI snapshot.
    /// The separate prepared bit keeps receipt creation serialized until the
    /// AppKit completion ends the operation.
    func beginCoordinatedWrite() -> Bool {
        guard !coordinatedWriteInFlight else { return false }
        coordinatedWriteInFlight = true
        coordinatedSnapshotPrepared = false
        return true
    }

    func endCoordinatedWrite() {
        coordinatedWriteInFlight = false
        coordinatedSnapshotPrepared = false
    }

    @MainActor
    func noteChange() {
        noteChange(registeredWith: nil)
    }

    /// Publishes the in-memory mutation and records a non-undo-managed AppKit
    /// change. NSDocument observes registrations on its own UndoManager, so a
    /// transaction using that manager must not also increment change count.
    @MainActor
    private func noteChange(registeredWith undoManager: UndoManager?) {
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
            if let undoManager, doc.undoManager === undoManager {
                return
            }
            doc.updateChangeCount(.changeDone)
        } else {
            // Unresolved — remember the change; flushed when the window
            // accessor attaches the backing document.
            hasPendingDirty = true
        }
    }

    /// Applies one value-typed document mutation and registers the complete
    /// prior snapshot as a single undo operation. A mutation that leaves the
    /// file unchanged has no dirty-state or undo side effects.
    @MainActor
    func performUndoableMutation<Result>(
        actionName: String,
        undoManager: UndoManager?,
        _ mutation: (inout MappingFile) -> Result
    ) -> Result? {
        let before = mappingFile
        var after = before
        let result = mutation(&after)

        guard after != before else { return nil }

        mappingFile = after
        noteChange(registeredWith: undoManager)
        registerUndoSnapshot(before, actionName: actionName, undoManager: undoManager)
        return result
    }

    @MainActor
    private func restoreSnapshot(
        _ snapshot: MappingFile,
        actionName: String,
        undoManager: UndoManager
    ) {
        let inverse = mappingFile
        guard inverse != snapshot else { return }

        mappingFile = snapshot
        noteChange(registeredWith: undoManager)
        registerUndoSnapshot(inverse, actionName: actionName, undoManager: undoManager)
    }

    @MainActor
    private func registerUndoSnapshot(
        _ snapshot: MappingFile,
        actionName: String,
        undoManager: UndoManager?
    ) {
        guard let undoManager else { return }

        undoManager.registerUndo(withTarget: self) { [weak undoManager] document in
            guard let undoManager else { return }
            document.restoreSnapshot(
                snapshot,
                actionName: actionName,
                undoManager: undoManager
            )
        }
        undoManager.setActionName(actionName)
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

    static func registeredDocument(for nsDocument: NSDocument) -> TraktorMappingDocument? {
        nsDocumentRegistry.object(forKey: nsDocument)
            ?? nsDocument.fileURL.flatMap { documentRegistry.object(forKey: $0 as NSURL) }
    }
}
