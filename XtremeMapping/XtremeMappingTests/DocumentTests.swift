//
//  DocumentTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import XCTest
import AppKit
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

    // MARK: - Undoable Mutation Tests

    @MainActor
    func testUndoableMutationRestoresWholeMappingFileAndRedo() throws {
        let original = MappingFile(
            devices: [
                Device(
                    name: "Original Device",
                    comment: "Preserve device metadata",
                    inPort: "Input Port",
                    outPort: "Output Port",
                    tsiVersion: "4.4.1",
                    mappingFileRevision: 17,
                    mappings: [.fullFieldSentinel]
                )
            ],
            version: 7
        )
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        let insertedIDs = document.performUndoableMutation(
            actionName: "Paste Mappings",
            undoManager: undoManager
        ) { file in
            file.version = 8
            file.devices[0].comment = "Changed device metadata"
            return MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file,
                targetDeviceID: file.devices[0].id
            )
        }

        let insertedID = try XCTUnwrap(insertedIDs?.first)
        let changed = document.mappingFile
        XCTAssertEqual(changed.version, 8)
        XCTAssertEqual(changed.devices[0].comment, "Changed device metadata")
        XCTAssertEqual(changed.devices[0].mappings.last?.id, insertedID)

        undoManager.undo()
        XCTAssertEqual(document.mappingFile, original)

        undoManager.redo()
        XCTAssertEqual(document.mappingFile, changed)
    }

    @MainActor
    func testBatchPasteRegistersOneUndoAction() {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        let insertedIDs = document.performUndoableMutation(
            actionName: "Paste 2 Mappings",
            undoManager: undoManager
        ) { file in
            MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100), MappingEntry(commandID: 201)],
                into: &file
            )
        }

        XCTAssertEqual(insertedIDs?.count, 2)
        XCTAssertTrue(undoManager.canUndo)
        XCTAssertEqual(undoManager.undoActionName, "Paste 2 Mappings")

        undoManager.undo()
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(undoManager.canUndo, "one undo must restore the entire batch")
        XCTAssertTrue(undoManager.canRedo)
    }

    @MainActor
    func testNoOpMutationReturnsNilWithoutDirtyingOrChangingSelection() {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()
        let existingSelection = Set([UUID()])
        var selection = existingSelection

        let insertedIDs: Set<MappingEntry.ID>? = document.performUndoableMutation(
            actionName: "Paste Mappings",
            undoManager: undoManager
        ) { file in
            MappingTransferService.insertCopies([], into: &file)
        }
        if let insertedIDs {
            selection = insertedIDs
        }

        XCTAssertNil(insertedIDs)
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertEqual(selection, existingSelection)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(document.hasPendingDirty)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testPasteMutationReturnsOnlyFreshInsertedIDsForSelection() throws {
        let source = [MappingEntry.fullFieldSentinel, MappingEntry(commandID: 100)]
        let sourceIDs = Set(source.map(\.id))
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Destination")])
        )

        let selection = try XCTUnwrap(document.performUndoableMutation(
            actionName: "Paste Mappings",
            undoManager: UndoManager()
        ) { file in
            MappingTransferService.insertCopies(source, into: &file)
        })

        let inserted = Set(document.mappingFile.allMappings.map(\.id))
        XCTAssertEqual(selection, inserted)
        XCTAssertEqual(selection.count, source.count)
        XCTAssertTrue(selection.isDisjoint(with: sourceIDs))
    }

    // MARK: - Pending Dirty Tests (window-backed resolution)

    @MainActor
    func testNoteChangeWithoutBackingDocumentSetsPendingDirty() {
        // Fresh document: no backingDocument, no fileURL. With the
        // NSDocumentController guess-fallbacks deleted, noteChange must not
        // touch the shared controller — it records the dirty state locally.
        let doc = TraktorMappingDocument()
        XCTAssertFalse(doc.hasPendingDirty)

        doc.noteChange()

        XCTAssertTrue(doc.isDirty)
        XCTAssertTrue(doc.hasPendingDirty)
        XCTAssertNil(doc.backingDocument, "noteChange must never cache a guessed document")
    }

    @MainActor
    func testAssigningBackingDocumentFlushesPendingDirtyExactlyOnce() {
        let doc = TraktorMappingDocument()
        doc.noteChange()
        doc.noteChange()
        XCTAssertTrue(doc.hasPendingDirty)

        let nsDoc = ChangeCountRecordingDocument()
        doc.backingDocument = nsDoc

        XCTAssertEqual(nsDoc.recordedChanges, [.changeDone], "pending dirty flushes exactly once")
        XCTAssertFalse(doc.hasPendingDirty)

        // Re-assigning without new pending dirty must not flush again
        doc.backingDocument = nsDoc
        XCTAssertEqual(nsDoc.recordedChanges.count, 1)
    }

    @MainActor
    func testNoteChangeWithBackingDocumentUpdatesDirectly() {
        let doc = TraktorMappingDocument()
        let nsDoc = ChangeCountRecordingDocument()
        doc.backingDocument = nsDoc
        XCTAssertTrue(nsDoc.recordedChanges.isEmpty, "no pending dirty, nothing to flush")

        doc.noteChange()

        XCTAssertEqual(nsDoc.recordedChanges, [.changeDone])
        XCTAssertFalse(doc.hasPendingDirty)
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
    // MARK: - NSDocument-Instance Registry Tests (save-callback dirty clearing)

    @MainActor
    func testAssigningBackingDocumentRegistersInstanceAssociation() {
        // Untitled document: fileURL is nil, so only the NSDocument-instance
        // association can resolve it (URL-keyed lookup has nothing to key on).
        let doc = TraktorMappingDocument()
        let nsDoc = ChangeCountRecordingDocument()
        doc.backingDocument = nsDoc

        doc.noteChange()
        XCTAssertTrue(doc.isDirty)

        TraktorMappingDocument.markClean(nsDocument: nsDoc)
        XCTAssertFalse(doc.isDirty, "instance-keyed markClean must clear isDirty with fileURL nil")
    }

    @MainActor
    func testMarkCleanByInstanceFallsBackToURLLookup() {
        let testURL = URL(fileURLWithPath: "/tmp/instance-fallback.tsi")
        let doc = TraktorMappingDocument()
        doc.updateFileURL(testURL)
        doc.noteChange()
        XCTAssertTrue(doc.isDirty)

        // NSDocument never associated via backingDocument — only its
        // fileURL matches, exercising the URL fallback path.
        let nsDoc = NSDocument()
        nsDoc.fileURL = testURL
        TraktorMappingDocument.markClean(nsDocument: nsDoc)
        XCTAssertFalse(doc.isDirty)
    }

    @MainActor
    func testMarkCleanByUnknownInstanceWithNilURLIsNoOp() {
        let doc = TraktorMappingDocument()
        doc.noteChange()

        let stranger = NSDocument()
        TraktorMappingDocument.markClean(nsDocument: stranger)

        XCTAssertTrue(doc.isDirty, "an unrelated NSDocument must not clear another document's dirty state")
    }

    // MARK: - DocumentWindowDelegateProxy Forwarding Tests

    @MainActor
    func testDelegateProxyRespondsToForwardedSelectors() {
        let stub = StubWindowDelegate()
        let proxy = DocumentWindowDelegateProxy(originalDelegate: stub, appDelegate: AppDelegate())

        // Selector implemented only by the original delegate
        let willClose = #selector(NSWindowDelegate.windowWillClose(_:))
        XCTAssertTrue(proxy.responds(to: willClose))
        XCTAssertTrue(proxy.forwardingTarget(for: willClose) as? StubWindowDelegate === stub)

        // Selector implemented by neither
        let didMiniaturize = #selector(NSWindowDelegate.windowDidMiniaturize(_:))
        XCTAssertFalse(proxy.responds(to: didMiniaturize))
    }

    @MainActor
    func testDelegateProxyForwardsWindowWillCloseToOriginal() {
        let stub = StubWindowDelegate()
        let proxy = DocumentWindowDelegateProxy(originalDelegate: stub, appDelegate: AppDelegate())

        // Dispatch through the protocol (objc messaging) so the runtime's
        // forwarding machinery is exercised, not a direct Swift call.
        let delegate: NSWindowDelegate = proxy
        delegate.windowWillClose?(Notification(name: NSWindow.willCloseNotification))

        XCTAssertTrue(stub.windowWillCloseCalled)
    }

    @MainActor
    func testDelegateProxyStillInterceptsWindowShouldClose() {
        // The proxy implements windowShouldClose itself, so the runtime never
        // consults forwardingTarget for it — interception is preserved.
        XCTAssertTrue(DocumentWindowDelegateProxy.instancesRespond(
            to: #selector(NSWindowDelegate.windowShouldClose(_:))
        ))

        let stub = StubWindowDelegate()
        let proxy = DocumentWindowDelegateProxy(originalDelegate: stub, appDelegate: AppDelegate())

        let window = makeOffscreenWindow()
        defer { window.orderOut(nil) }

        // Proxy's own logic runs: consults the original first, then falls
        // through to "no document attached → allow close".
        let shouldClose = proxy.windowShouldClose(window)
        XCTAssertTrue(shouldClose)
        XCTAssertTrue(stub.windowShouldCloseCalled, "proxy consults the original delegate")
    }

    // MARK: - Welcome Window Identification Tests

    @MainActor
    func testIsWelcomeWindowMatchesIdentifier() {
        let window = makeOffscreenWindow()
        defer { window.orderOut(nil) }
        window.identifier = NSUserInterfaceItemIdentifier("sxm-welcome")
        window.title = "Anything"

        XCTAssertTrue(AppDelegate.isWelcomeWindow(window))
    }

    @MainActor
    func testIsWelcomeWindowAcceptsSwiftUIPrefixFallback() {
        let window = makeOffscreenWindow()
        defer { window.orderOut(nil) }
        window.identifier = NSUserInterfaceItemIdentifier("welcome-AppWindow-1")
        window.title = "Untitled"

        XCTAssertTrue(AppDelegate.isWelcomeWindow(window))
    }

    @MainActor
    func testIsWelcomeWindowNeverMatchesTitle() {
        // A document named "Welcome Mix.tsi" must not be mistaken for the
        // welcome window — titles are user data, identifiers are ours.
        let window = makeOffscreenWindow()
        defer { window.orderOut(nil) }
        window.title = "Welcome Mix.tsi"
        XCTAssertNil(window.identifier)

        XCTAssertFalse(AppDelegate.isWelcomeWindow(window))
    }
}

// MARK: - Test Helpers

@MainActor
private func makeOffscreenWindow() -> NSWindow {
    let window = NSWindow(
        contentRect: NSRect(x: -2000, y: -2000, width: 100, height: 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    window.isReleasedWhenClosed = false
    return window
}

/// Stub NSWindowDelegate recording which delegate methods were invoked.
final class StubWindowDelegate: NSObject, NSWindowDelegate {
    private(set) var windowWillCloseCalled = false
    private(set) var windowShouldCloseCalled = false

    func windowWillClose(_ notification: Notification) {
        windowWillCloseCalled = true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        windowShouldCloseCalled = true
        return true
    }
}

/// NSDocument double that records updateChangeCount calls without touching
/// real document machinery.
final class ChangeCountRecordingDocument: NSDocument {
    private(set) var recordedChanges: [NSDocument.ChangeType] = []

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        recordedChanges.append(change)
        // Deliberately no super call — keep the double inert.
    }
}

extension UTType {
    static var tsi: UTType {
        UTType(importedAs: "com.native-instruments.traktor.tsi")
    }
}
