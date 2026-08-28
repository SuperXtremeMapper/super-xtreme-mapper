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

    func testSnapshotOwnsExactImmutableWritePlanBytes() throws {
        let device = Device(name: "Test Device", mappings: [
            MappingEntry(commandName: "Play", midiChannel: 1, midiNote: 60)
        ])
        let mappingFile = MappingFile(devices: [device])
        let doc = TraktorMappingDocument(mappingFile: mappingFile)

        let snapshot = try doc.snapshot(contentType: .tsi)
        let plannedBytes = snapshot.plan.output
        doc.mappingFile.devices[0].comment = "edited after snapshot"
        let wrapper = doc.fileWrapper(for: snapshot)

        XCTAssertEqual(snapshot.mappingFile.devices.count, 1)
        XCTAssertEqual(snapshot.mappingFile.devices.first?.name, "Test Device")
        XCTAssertEqual(snapshot.mappingFile.devices.first?.mappings.count, 1)
        XCTAssertEqual(wrapper.regularFileContents, plannedBytes)
        XCTAssertNotEqual(snapshot.mappingFile, doc.mappingFile)
        XCTAssertEqual(snapshot.plan.disposition, .regenerated)
        doc.discardPendingWrite()
    }

    func testDocumentInitializationUsesDocumentParserAndRetainsSourceEnvelope() throws {
        let source = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        let document = try TraktorMappingDocument(fileContents: source)

        XCTAssertEqual(document.mappingFile.sourceEnvelope?.originalXML, source)
        XCTAssertEqual(document.mappingFile.devices.count, 1)
    }

    @MainActor
    func testConcurrentWriteReceiptIsRefusedAndDiscardAllowsRetry() throws {
        let nsDocument = ChangeCountRecordingDocument()
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        let coordinator = DocumentSaveCoordinator { _, _, _ in }
        XCTAssertTrue(coordinator.save(document: nsDocument, intent: .save))
        let first = try document.prepareWriteSnapshot()

        XCTAssertThrowsError(try document.prepareWriteSnapshot()) {
            XCTAssertEqual($0 as? DocumentSaveLifecycleError, .writeAlreadyInFlight)
        }

        coordinator.completeSave(document: nsDocument, succeeded: false)
        let retry = try document.prepareWriteSnapshot()
        XCTAssertGreaterThan(retry.generation, first.generation)
        document.discardPendingWrite()
    }

    func testFailedUncoordinatedReceiptIsReplacedByNextSerializedSnapshot() throws {
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        let orphan = try document.prepareWriteSnapshot()
        document.mappingFile.devices[0].comment = "retry after native failure"

        let retry = try document.prepareWriteSnapshot()

        XCTAssertGreaterThan(retry.generation, orphan.generation)
        XCTAssertNotEqual(retry.plan.output, orphan.plan.output)
        document.discardPendingWrite()
    }

    @MainActor
    func testRegeneratedSaveCommitReparsesBytesAndSecondSavePassesThemThrough() throws {
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.noteChange()
        let first = try document.prepareWriteSnapshot()

        try document.commitPendingWrite()

        XCTAssertEqual(document.mappingFile.sourceEnvelope?.originalXML, first.plan.output)
        XCTAssertFalse(document.isDirty)
        let second = try document.prepareWriteSnapshot()
        XCTAssertEqual(second.plan.disposition, .originalPassthrough)
        XCTAssertEqual(second.plan.output, first.plan.output)
        document.discardPendingWrite()
    }

    @MainActor
    func testEditDuringSaveKeepsNewerMappingDirtyAgainstCommittedEnvelope() throws {
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.noteChange()
        let savedSnapshot = try document.prepareWriteSnapshot()
        document.mappingFile.devices[0].comment = "newer edit"
        document.noteChange()

        try document.commitPendingWrite()

        XCTAssertEqual(document.mappingFile.devices[0].comment, "newer edit")
        XCTAssertEqual(
            document.mappingFile.sourceEnvelope?.originalXML,
            savedSnapshot.plan.output
        )
        XCTAssertTrue(document.isDirty)
        let next = try document.prepareWriteSnapshot()
        XCTAssertEqual(next.plan.disposition, .regenerated)
        XCTAssertNotEqual(next.plan.output, savedSnapshot.plan.output)
        document.discardPendingWrite()
    }

    @MainActor
    func testSaveCoordinatorDiscardsFailureAndRetryCommitsForEverySaveIntent() throws {
        let nsDocument = ChangeCountRecordingDocument()
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        var started: [DocumentSaveCoordinator.Intent] = []
        let coordinator = DocumentSaveCoordinator { _, intent, _ in
            started.append(intent)
        }

        for intent in DocumentSaveCoordinator.Intent.allCases {
            var result: Bool?
            XCTAssertTrue(coordinator.save(document: nsDocument, intent: intent) {
                result = $0
            })
            let failedSnapshot = try document.prepareWriteSnapshot()
            if intent == .saveAs {
                XCTAssertEqual(failedSnapshot.plan.disposition, .originalPassthrough)
            }
            coordinator.completeSave(document: nsDocument, succeeded: false)
            XCTAssertEqual(result, false)

            if intent == .saveAs {
                document.mappingFile.devices[0].comment = "regenerated Save As"
                document.noteChange()
            }
            result = nil
            XCTAssertTrue(coordinator.save(document: nsDocument, intent: intent) {
                result = $0
            })
            let retrySnapshot = try document.prepareWriteSnapshot()
            if intent == .saveAs {
                XCTAssertEqual(retrySnapshot.plan.disposition, .regenerated)
            }
            coordinator.completeSave(document: nsDocument, succeeded: true)
            XCTAssertEqual(result, true)
            document.noteChange()
        }

        XCTAssertEqual(started, DocumentSaveCoordinator.Intent.allCases.flatMap { [$0, $0] })
    }

    @MainActor
    func testCoordinatorRefusesOverlappingRequestWithoutReplacingCompletion() throws {
        let nsDocument = ChangeCountRecordingDocument()
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        var first: Bool?
        var second: Bool?
        let coordinator = DocumentSaveCoordinator { _, _, _ in }

        XCTAssertTrue(coordinator.save(document: nsDocument, intent: .save) { first = $0 })
        XCTAssertFalse(coordinator.save(document: nsDocument, intent: .saveAs) { second = $0 })
        XCTAssertEqual(second, false)
        _ = try document.prepareWriteSnapshot()
        coordinator.completeSave(document: nsDocument, succeeded: true)

        XCTAssertEqual(first, true)
    }

    @MainActor
    func testAppKitCoordinatorRoutesSaveAndSaveAsThroughActualSelectorCompletion() throws {
        let nsDocument = AppKitSaveRecordingDocument()
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        let coordinator = DocumentSaveCoordinator()
        var saveResult: Bool?

        XCTAssertTrue(coordinator.save(document: nsDocument, intent: .save) {
            saveResult = $0
        })
        XCTAssertEqual(nsDocument.routes, [.save])
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: false)
        XCTAssertEqual(saveResult, false)
        XCTAssertTrue(nsDocument.isDocumentEdited)

        var saveAsResult: Bool?
        XCTAssertTrue(coordinator.save(document: nsDocument, intent: .saveAs) {
            saveAsResult = $0
        })
        XCTAssertEqual(nsDocument.routes, [.save, .savePanel(.saveAsOperation)])
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: true)

        XCTAssertEqual(saveAsResult, true)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(nsDocument.isDocumentEdited)
    }

    @MainActor
    func testNativeResponderSaveCommitsThroughRealAppKitCompletion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("native-save.tsi")
        let nsDocument = RealAppKitWritableDocument()
        nsDocument.fileURL = destination
        nsDocument.fileType = UTType.tsi.identifier
        let controller = NSWindowController(window: makeOffscreenWindow())
        let window = try XCTUnwrap(controller.window)
        nsDocument.addWindowController(controller)
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        nsDocument.dataProvider = {
            try document.prepareWriteSnapshot().plan.output
        }
        document.mappingFile.devices[0].comment = "saved by responder action"
        document.noteChange()
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let appDelegate = AppDelegate(
            saveCoordinator: DocumentSaveCoordinator(),
            savePromptPresenter: nil
        )
        appDelegate.attachDocumentDelegateIfNeeded(to: window)

        XCTAssertTrue(
            window.tryToPerform(#selector(NSDocument.save(_:)), with: nil),
            "The inserted AppKit responder must own native saveDocument:"
        )
        waitUntil(timeout: 2) {
            FileManager.default.fileExists(atPath: destination.path) && !document.isDirty
        }

        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(nsDocument.isDocumentEdited)
        XCTAssertEqual(
            document.mappingFile.sourceEnvelope?.originalXML,
            try Data(contentsOf: destination)
        )
    }

    @MainActor
    func testNativeResponderSaveAsAndSaveAllUseCoordinatorCallbacks() throws {
        let nsDocument = AppKitSaveRecordingDocument()
        let controller = NSWindowController(window: makeOffscreenWindow())
        let window = try XCTUnwrap(controller.window)
        nsDocument.addWindowController(controller)
        NSDocumentController.shared.addDocument(nsDocument)
        defer {
            NSDocumentController.shared.removeDocument(nsDocument)
            window.orderOut(nil)
        }
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        let appDelegate = AppDelegate(
            saveCoordinator: DocumentSaveCoordinator(),
            savePromptPresenter: nil
        )
        appDelegate.attachDocumentDelegateIfNeeded(to: window)

        XCTAssertTrue(window.tryToPerform(#selector(NSDocument.saveAs(_:)), with: nil))
        XCTAssertEqual(nsDocument.routes, [.savePanel(.saveAsOperation)])
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: false)

        XCTAssertTrue(
            window.tryToPerform(
                #selector(NSDocumentController.saveAllDocuments(_:)),
                with: nil
            )
        )
        XCTAssertEqual(nsDocument.routes, [.savePanel(.saveAsOperation), .save])
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: true)
        XCTAssertFalse(document.isDirty)
    }

    @MainActor
    func testCommitFailurePreventsDirtyCloseAndLeavesReceiptRetryable() throws {
        let nsDocument = AppKitSaveRecordingDocument()
        let controller = NSWindowController(window: makeOffscreenWindow())
        let window = try XCTUnwrap(controller.window)
        nsDocument.addWindowController(controller)
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        let coordinator = DocumentSaveCoordinator(
            commitWrite: { _ in throw CocoaError(.fileReadCorruptFile) },
            presentError: { _ in }
        )
        let appDelegate = AppDelegate(
            saveCoordinator: coordinator,
            savePromptPresenter: { _, _, completion in completion(.save) }
        )
        appDelegate.attachDocumentDelegateIfNeeded(to: window)
        let proxy = try XCTUnwrap(window.delegate as? DocumentWindowDelegateProxy)

        XCTAssertFalse(proxy.windowShouldClose(window))
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: true)

        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(document.isDirty)
        XCTAssertTrue(
            nsDocument.isDocumentEdited,
            "A failed preservation commit must restore AppKit's dirty state for the next close"
        )
        let retry = try document.prepareWriteSnapshot()
        document.discardPendingWrite()
        XCTAssertGreaterThan(retry.generation, 1)
    }

    @MainActor
    func testCommitFailureRepliesDoNotTerminate() throws {
        let nsDocument = AppKitSaveRecordingDocument()
        NSDocumentController.shared.addDocument(nsDocument)
        defer { NSDocumentController.shared.removeDocument(nsDocument) }
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        let coordinator = DocumentSaveCoordinator(
            commitWrite: { _ in throw CocoaError(.fileReadCorruptFile) },
            presentError: { _ in }
        )
        var replies: [Bool] = []
        let appDelegate = AppDelegate(
            saveCoordinator: coordinator,
            savePromptPresenter: { _, _, completion in completion(.save) },
            terminationReply: { replies.append($0) }
        )

        XCTAssertEqual(appDelegate.applicationShouldTerminate(NSApp), .terminateLater)
        XCTAssertEqual(nsDocument.routes, [.save])
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: true)

        XCTAssertEqual(replies, [false])
        XCTAssertTrue(document.isDirty)
        XCTAssertTrue(nsDocument.isDocumentEdited)
        let retry = try document.prepareWriteSnapshot()
        document.discardPendingWrite()
        XCTAssertGreaterThan(retry.generation, 1)
    }

    @MainActor
    func testClosingOneOfTwoDocumentWindowsDoesNotCloseTheOther() throws {
        let nsDocument = AppKitSaveRecordingDocument()
        let firstController = NSWindowController(window: makeOffscreenWindow())
        let secondController = NSWindowController(window: makeOffscreenWindow())
        let firstWindow = try XCTUnwrap(firstController.window)
        let secondWindow = try XCTUnwrap(secondController.window)
        nsDocument.addWindowController(firstController)
        nsDocument.addWindowController(secondController)
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        firstWindow.orderFront(nil)
        secondWindow.orderFront(nil)
        defer {
            firstWindow.orderOut(nil)
            secondWindow.orderOut(nil)
        }
        var prompts: [(SaveDecision) -> Void] = []
        let appDelegate = AppDelegate(
            saveCoordinator: DocumentSaveCoordinator(),
            savePromptPresenter: { _, _, completion in prompts.append(completion) }
        )
        appDelegate.attachDocumentDelegateIfNeeded(to: firstWindow)
        appDelegate.attachDocumentDelegateIfNeeded(to: secondWindow)
        let firstProxy = try XCTUnwrap(firstWindow.delegate as? DocumentWindowDelegateProxy)
        let secondProxy = try XCTUnwrap(secondWindow.delegate as? DocumentWindowDelegateProxy)

        XCTAssertFalse(firstProxy.windowShouldClose(firstWindow))
        XCTAssertFalse(firstWindow.isVisible)
        XCTAssertTrue(secondWindow.isVisible)
        XCTAssertTrue(nsDocument.windowControllers.contains(secondController))
        XCTAssertTrue(document.isDirty)
        XCTAssertTrue(prompts.isEmpty, "A non-last window close must not prompt for the shared document")

        XCTAssertFalse(secondProxy.windowShouldClose(secondWindow))
        XCTAssertEqual(prompts.count, 1)
        prompts.removeFirst()(.cancel)
        XCTAssertTrue(secondWindow.isVisible)
        XCTAssertTrue(document.isDirty)

        XCTAssertFalse(secondProxy.windowShouldClose(secondWindow))
        prompts.removeFirst()(.save)
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: true)
        XCTAssertFalse(secondWindow.isVisible)
        XCTAssertFalse(document.isDirty)
    }

    @MainActor
    func testDocumentClosePreflightDefersToProxyAndSaveCompletionControlsClose() throws {
        let nsDocument = AppKitSaveRecordingDocument()
        let controller = NSWindowController(window: makeOffscreenWindow())
        let window = try XCTUnwrap(controller.window)
        nsDocument.addWindowController(controller)
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        document.backingDocument = nsDocument
        document.noteChange()
        window.orderFront(nil)
        defer { window.orderOut(nil) }

        var prompts: [(SaveDecision) -> Void] = []
        let coordinator = DocumentSaveCoordinator()
        let appDelegate = AppDelegate(
            saveCoordinator: coordinator,
            savePromptPresenter: { _, _, completion in
                prompts.append(completion)
            }
        )
        appDelegate.attachDocumentDelegateIfNeeded(to: window)
        let proxy = try XCTUnwrap(window.delegate as? DocumentWindowDelegateProxy)

        XCTAssertFalse(controller.shouldCloseDocument)
        XCTAssertEqual(nsDocument.windowControllers.count, 2)
        let preflight = WindowClosePreflightRecorder()
        nsDocument.shouldCloseWindowController(
            controller,
            delegate: preflight,
            shouldClose: #selector(WindowClosePreflightRecorder.document(_:shouldClose:contextInfo:)),
            contextInfo: nil
        )
        XCTAssertEqual(preflight.results, [true], "AppKit preflight must complete synchronously")

        XCTAssertFalse(proxy.windowShouldClose(window))
        XCTAssertEqual(prompts.count, 1)
        prompts.removeFirst()(.cancel)
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(nsDocument.isDocumentEdited)

        XCTAssertFalse(proxy.windowShouldClose(window))
        prompts.removeFirst()(.save)
        XCTAssertEqual(nsDocument.routes.last, .save)
        _ = try document.prepareWriteSnapshot()
        nsDocument.finishSave(succeeded: false)
        XCTAssertTrue(window.isVisible)
        XCTAssertTrue(nsDocument.isDocumentEdited)
        let failureRetry = try document.prepareWriteSnapshot()
        document.discardPendingWrite()

        XCTAssertFalse(proxy.windowShouldClose(window))
        prompts.removeFirst()(.save)
        let successRetry = try document.prepareWriteSnapshot()
        XCTAssertGreaterThan(successRetry.generation, failureRetry.generation)
        nsDocument.finishSave(succeeded: true)

        XCTAssertFalse(window.isVisible)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(nsDocument.isDocumentEdited)
    }

    @MainActor
    func testAppDelegateDisablesPeriodicAutosaveWithDocumentedZeroValue() {
        let documentController = NSDocumentController()
        documentController.autosavingDelay = 30

        AppDelegate.disablePeriodicAutosave(on: documentController)

        XCTAssertEqual(documentController.autosavingDelay, 0)
    }

    @MainActor
    func testUndoAfterCommittedSaveDivergesFromSavedBaseline() throws {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.beginUndoGrouping()
        _ = document.performUndoableMutation(actionName: "Edit", undoManager: undoManager) {
            $0.devices[0].comment = "saved"
        }
        undoManager.endUndoGrouping()
        _ = try document.prepareWriteSnapshot()
        try document.commitPendingWrite()

        undoManager.undo()

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertTrue(document.isDirty)
        let next = try document.prepareWriteSnapshot()
        XCTAssertEqual(next.plan.disposition, .regenerated)
        document.discardPendingWrite()
    }

    @MainActor
    func testLossyConvertedExportReparsesAndDoesNotMutateDocumentState() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.tsi")
        let destinationURL = directory.appendingPathComponent("converted.tsi")
        let document = try makeLossyDocument(sourceURL: sourceURL)
        let backing = NSDocument()
        document.backingDocument = backing
        let undoManager = try XCTUnwrap(backing.undoManager)
        undoManager.registerUndo(withTarget: document) { _ in }
        let beforeMapping = document.mappingFile
        let beforeEnvelope = document.mappingFile.sourceEnvelope
        let beforeURL = document.fileURL
        let beforeDirty = document.isDirty
        let beforeCanUndo = undoManager.canUndo

        XCTAssertEqual(document.lossyExportRisks.map(\.code), [
            .unknownFrame,
            .extraXMLEntry,
        ])
        try document.exportLossyConvertedCopy(to: destinationURL)

        let exported = try Data(contentsOf: destinationURL)
        XCTAssertNoThrow(try TSIParser().parseDocument(exported))
        XCTAssertEqual(document.mappingFile, beforeMapping)
        XCTAssertEqual(document.mappingFile.sourceEnvelope, beforeEnvelope)
        XCTAssertEqual(document.fileURL, beforeURL)
        XCTAssertEqual(document.isDirty, beforeDirty)
        XCTAssertEqual(undoManager.canUndo, beforeCanUndo)
        XCTAssertThrowsError(try document.prepareWriteSnapshot()) {
            XCTAssertTrue($0 is TSIPreservationError)
        }
        XCTAssertThrowsError(try document.exportLossyConvertedCopy(to: directory))
        XCTAssertEqual(document.mappingFile, beforeMapping)
        XCTAssertEqual(document.mappingFile.sourceEnvelope, beforeEnvelope)
        XCTAssertEqual(document.fileURL, beforeURL)
        XCTAssertEqual(document.isDirty, beforeDirty)
        XCTAssertEqual(undoManager.canUndo, beforeCanUndo)
    }

    @MainActor
    func testLossyExportRejectsStandardizedSymlinkCaseUnicodeAndResourceAliases() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("Résumé.tsi")
        let document = try makeLossyDocument(sourceURL: sourceURL)
        let beforeMapping = document.mappingFile
        let beforeEnvelope = document.mappingFile.sourceEnvelope
        let beforeURL = document.fileURL
        let beforeDirty = document.isDirty

        let standardizedAlias = directory.appendingPathComponent("folder/../Résumé.tsi")
        XCTAssertThrowsError(try document.exportLossyConvertedCopy(to: standardizedAlias)) {
            XCTAssertEqual($0 as? TSIExportError, .destinationMatchesSource)
        }

        let symlink = directory.appendingPathComponent("source-link.tsi")
        try FileManager.default.createSymbolicLink(at: symlink, withDestinationURL: sourceURL)
        XCTAssertThrowsError(try document.exportLossyConvertedCopy(to: symlink)) {
            XCTAssertEqual($0 as? TSIExportError, .destinationMatchesSource)
        }

        let hardLink = directory.appendingPathComponent("source-hard-link.tsi")
        try FileManager.default.linkItem(at: sourceURL, to: hardLink)
        XCTAssertThrowsError(try document.exportLossyConvertedCopy(to: hardLink)) {
            XCTAssertEqual($0 as? TSIExportError, .destinationMatchesSource)
        }

        XCTAssertTrue(TSIExportDestinationValidator.canonicalPathsMatch(
            sourceURL,
            directory.appendingPathComponent("résumé.tsi"),
            caseSensitive: false
        ))
        XCTAssertTrue(TSIExportDestinationValidator.canonicalPathsMatch(
            sourceURL,
            directory.appendingPathComponent("Résumé.tsi"),
            caseSensitive: true
        ))
        XCTAssertEqual(document.mappingFile, beforeMapping)
        XCTAssertEqual(document.mappingFile.sourceEnvelope, beforeEnvelope)
        XCTAssertEqual(document.fileURL, beforeURL)
        XCTAssertEqual(document.isDirty, beforeDirty)
    }

    @MainActor
    func testLossyExportRefusesExistingDestinationWithoutChangingEitherFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("source.tsi")
        let destinationURL = directory.appendingPathComponent("existing.tsi")
        let document = try makeLossyDocument(sourceURL: sourceURL)
        let sourceBefore = try Data(contentsOf: sourceURL)
        let destinationBefore = Data("existing destination".utf8)
        try destinationBefore.write(to: destinationURL)
        let mappingBefore = document.mappingFile

        XCTAssertThrowsError(try document.exportLossyConvertedCopy(to: destinationURL)) {
            XCTAssertEqual($0 as? TSIExportError, .destinationAlreadyExists)
        }

        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceBefore)
        XCTAssertEqual(try Data(contentsOf: destinationURL), destinationBefore)
        XCTAssertEqual(document.mappingFile, mappingBefore)
    }

    func testExclusiveAtomicExportPublisherNeverFollowsOrReplacesExistingDestination() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("existing.tsi")
        let existing = Data("keep me".utf8)
        try existing.write(to: destination)

        XCTAssertThrowsError(
            try TSIExclusiveAtomicWriter.publish(Data("replacement".utf8), to: destination)
        ) {
            XCTAssertEqual($0 as? TSIExportError, .destinationAlreadyExists)
        }
        XCTAssertEqual(try Data(contentsOf: destination), existing)
    }

    func testLossyRiskWarningIncludesOrderedDetail() {
        let risks = [
            TSIPreservationRisk(code: .unknownFrame, path: "/DIOM/JUNK", detail: "JUNK"),
            TSIPreservationRisk(code: .extraXMLEntry, path: "/NIXML/Entry"),
        ]

        XCTAssertEqual(
            TSIExportRiskPresenter.warningText(for: risks),
            "1. unknownFrame: /DIOM/JUNK — JUNK\n2. extraXMLEntry: /NIXML/Entry"
        )
    }

    @MainActor
    private func makeLossyDocument(sourceURL: URL) throws -> TraktorMappingDocument {
        let cleanBytes = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        var imported = try TSIParser().parseDocument(cleanBytes)
        let envelope = try XCTUnwrap(imported.sourceEnvelope)
        imported.sourceEnvelope = TSIRawEnvelope(
            originalXML: envelope.originalXML,
            controllerValues: envelope.controllerValues,
            primaryFrames: envelope.primaryFrames,
            baseline: envelope.baseline,
            risks: [
                .init(code: .unknownFrame, path: "/DIOM[0]/JUNK[0]"),
                .init(code: .extraXMLEntry, path: "/NIXML[0]/TraktorSettings[0]/Entry[0]"),
            ]
        )
        imported.devices[0].comment = "converted edit"
        try cleanBytes.write(to: sourceURL, options: .atomic)
        let document = TraktorMappingDocument(mappingFile: imported)
        document.updateFileURL(sourceURL)
        document.noteChange()
        return document
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
            return try! MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file,
                targetDeviceID: file.devices[0].id
            ).insertedIDs
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
    func testThrowingUndoableMutationDoesNotAssignDirtyOrRegisterUndo() throws {
        struct ExpectedFailure: Error {}

        let original = MappingFile(devices: [
            Device(name: "Generic MIDI", mappings: [MappingEntry(commandID: 100)])
        ])
        let document = TraktorMappingDocument(mappingFile: original)
        let backing = NSDocument()
        document.backingDocument = backing
        let undoManager = try XCTUnwrap(backing.undoManager)

        XCTAssertThrowsError(
            try document.performUndoableMutation(
                actionName: "Rejected Candidate",
                undoManager: undoManager
            ) { file -> Void in
                file.devices[0].mappings.append(MappingEntry(commandID: 101))
                throw ExpectedFailure()
            }
        ) { error in
            XCTAssertTrue(error is ExpectedFailure)
        }

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(backing.isDocumentEdited)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testBatchPasteRegistersOneUndoAction() throws {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        let transfer = try MappingTransferService.insertCopies(
            [MappingEntry(commandID: 100), MappingEntry(commandID: 201)],
            into: document,
            targetDeviceID: original.devices[0].id,
            actionName: "Paste 2 Mappings",
            undoManager: undoManager
        )

        XCTAssertEqual(transfer?.insertedIDs.count, 2)
        XCTAssertTrue(undoManager.canUndo)
        XCTAssertEqual(undoManager.undoActionName, "Paste 2 Mappings")

        undoManager.undo()
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(undoManager.canUndo, "one undo must restore the entire batch")
        XCTAssertTrue(undoManager.canRedo)
    }

    @MainActor
    func testFailedTransferPreflightDoesNotDirtyDocumentOrRegisterUndo() {
        let existing = MappingEntry(
            commandID: 100,
            ioType: .input,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 5
        )
        let conflicting = MappingEntry(
            commandID: 201,
            ioType: .input,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 7
        )
        let device = Device(name: "Generic MIDI", mappings: [existing])
        let original = MappingFile(devices: [device])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        XCTAssertThrowsError(
            try MappingTransferService.insertCopies(
                [conflicting],
                into: document,
                targetDeviceID: device.id,
                actionName: "Paste Mappings",
                undoManager: undoManager
            )
        )

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(document.hasPendingDirty)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testNoOpMutationReturnsNilWithoutDirtyingOrChangingSelection() throws {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()
        let existingSelection = Set([UUID()])
        var selection = existingSelection

        let transfer = try MappingTransferService.insertCopies(
            [],
            into: document,
            targetDeviceID: nil,
            actionName: "Paste Mappings",
            undoManager: undoManager
        )
        if let transfer {
            selection = transfer.insertedIDs
        }

        XCTAssertNil(transfer)
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertEqual(selection, existingSelection)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(document.hasPendingDirty)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testSharedSettingsMultiRowEditRestoresWholeRowsAndRedoes() {
        let first = MappingEntry.fullFieldSentinel
        let second = MappingEntry(
            commandID: 201,
            assignment: .deckB,
            interactionMode: .relative,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3),
            comment: "second",
            controllerType: .encoder,
            invert: true,
            rotarySensitivity: 1.75,
            rotaryAcceleration: 0.25
        )
        let untouched = MappingEntry(
            commandID: 202,
            assignment: .deckC,
            interactionMode: .direct,
            comment: "untouched",
            controllerType: .faderOrKnob,
            softTakeover: true
        )
        let original = MappingFile(devices: [
            Device(name: "First", mappings: [first]),
            Device(name: "Second", mappings: [second, untouched]),
        ])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        let didChange = SettingsPanelV2.updateSelectedEntries(
            Set([first.id, second.id]),
            in: document,
            isLocked: false,
            undoManager: undoManager
        ) { entry in
            entry.assignment = .deckD
        }

        var expectedFirst = first
        expectedFirst.assignment = .deckD
        var expectedSecond = second
        expectedSecond.assignment = .deckD
        var edited = original
        edited.devices[0].mappings[0] = expectedFirst
        edited.devices[1].mappings[0] = expectedSecond
        XCTAssertTrue(didChange)
        XCTAssertEqual(document.mappingFile, edited)
        XCTAssertEqual(undoManager.undoActionName, "Edit Mapping Settings")

        undoManager.undo()
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(undoManager.canUndo, "the shared edit must be one undo action")

        undoManager.redo()
        XCTAssertEqual(document.mappingFile, edited)
    }

    @MainActor
    func testSharedSettingsNoOpDoesNotRegisterUndo() {
        let entry = MappingEntry(commandID: 100, assignment: .deckA)
        let original = MappingFile(devices: [Device(mappings: [entry])])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        let didChange = SettingsPanelV2.updateSelectedEntries(
            [entry.id],
            in: document,
            isLocked: false,
            undoManager: undoManager
        ) { mapping in
            mapping.assignment = .deckA
        }

        XCTAssertFalse(didChange)
        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(document.isDirty)
        XCTAssertFalse(document.hasPendingDirty)
        XCTAssertFalse(undoManager.canUndo)
    }

    @MainActor
    func testSharedSettingsLockedEditDoesNotMutateOrRegisterUndo() {
        let entry = MappingEntry(commandID: 100, assignment: .deckA)
        let original = MappingFile(devices: [Device(mappings: [entry])])
        let document = TraktorMappingDocument(mappingFile: original)
        let undoManager = UndoManager()

        let didChange = SettingsPanelV2.updateSelectedEntries(
            [entry.id],
            in: document,
            isLocked: true,
            undoManager: undoManager
        ) { mapping in
            mapping.assignment = .deckD
        }

        XCTAssertFalse(didChange)
        XCTAssertEqual(document.mappingFile, original)
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
            try! MappingTransferService.insertCopies(
                source,
                into: &file,
                targetDeviceID: file.devices[0].id
            ).insertedIDs
        })

        let inserted = Set(document.mappingFile.allMappings.map(\.id))
        XCTAssertEqual(selection, inserted)
        XCTAssertEqual(selection.count, source.count)
        XCTAssertTrue(selection.isDisjoint(with: sourceIDs))
    }

    @MainActor
    func testBackingDocumentUndoManagerEditThenUndoReturnsClean() throws {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let backingDocument = NSDocument()
        document.backingDocument = backingDocument
        let undoManager = try XCTUnwrap(backingDocument.undoManager)
        undoManager.groupsByEvent = false

        undoManager.beginUndoGrouping()
        let insertedIDs = document.performUndoableMutation(
            actionName: "Paste Mappings",
            undoManager: undoManager
        ) { file in
            try! MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file,
                targetDeviceID: file.devices[0].id
            ).insertedIDs
        }
        undoManager.endUndoGrouping()

        XCTAssertEqual(insertedIDs?.count, 1)
        XCTAssertTrue(backingDocument.isDocumentEdited)

        undoManager.undo()

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertFalse(
            backingDocument.isDocumentEdited,
            "undoing the only edit must return the real NSDocument to clean"
        )
    }

    @MainActor
    func testBackingDocumentUndoAfterSaveIsEditedBecauseStateDiverged() throws {
        let original = MappingFile(devices: [Device(name: "Generic MIDI")])
        let document = TraktorMappingDocument(mappingFile: original)
        let backingDocument = NSDocument()
        document.backingDocument = backingDocument
        let undoManager = try XCTUnwrap(backingDocument.undoManager)
        undoManager.groupsByEvent = false

        undoManager.beginUndoGrouping()
        _ = document.performUndoableMutation(
            actionName: "Paste Mappings",
            undoManager: undoManager
        ) { file in
            try! MappingTransferService.insertCopies(
                [MappingEntry(commandID: 100)],
                into: &file,
                targetDeviceID: file.devices[0].id
            ).insertedIDs
        }
        undoManager.endUndoGrouping()
        let saved = document.mappingFile

        backingDocument.updateChangeCount(.changeCleared)
        TraktorMappingDocument.markClean(nsDocument: backingDocument)
        XCTAssertFalse(backingDocument.isDocumentEdited)
        XCTAssertFalse(document.isDirty)

        undoManager.undo()

        XCTAssertEqual(document.mappingFile, original)
        XCTAssertNotEqual(document.mappingFile, saved)
        XCTAssertTrue(
            backingDocument.isDocumentEdited,
            "undoing away from the saved snapshot must mark the document edited"
        )
        XCTAssertTrue(document.isDirty)
    }

    @MainActor
    func testUndoRegistrationDoesNotRetainStandaloneUndoManager() {
        let document = TraktorMappingDocument(
            mappingFile: MappingFile(devices: [Device(name: "Generic MIDI")])
        )
        weak var releasedUndoManager: UndoManager?

        autoreleasepool {
            let undoManager = UndoManager()
            undoManager.groupsByEvent = false
            undoManager.beginUndoGrouping()
            _ = document.performUndoableMutation(
                actionName: "Paste Mappings",
                undoManager: undoManager
            ) { file in
                try! MappingTransferService.insertCopies(
                    [MappingEntry(commandID: 100)],
                    into: &file,
                    targetDeviceID: file.devices[0].id
                ).insertedIDs
            }
            undoManager.endUndoGrouping()
            releasedUndoManager = undoManager
        }

        XCTAssertNil(
            releasedUndoManager,
            "undo registrations must not form an UndoManager → closure → UndoManager cycle"
        )
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

@MainActor
private func waitUntil(
    timeout: TimeInterval,
    condition: () -> Bool
) {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while !condition(), Date() < deadline {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
    }
    XCTAssertTrue(condition(), "Condition was not satisfied before timeout")
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

@MainActor
final class RealAppKitWritableDocument: NSDocument {
    var dataProvider: (() throws -> Data)?

    override func data(ofType typeName: String) throws -> Data {
        guard let dataProvider else {
            throw CocoaError(.fileWriteUnknown)
        }
        return try dataProvider()
    }
}

@MainActor
final class AppKitSaveRecordingDocument: NSDocument {
    enum Route: Equatable {
        case save
        case savePanel(NSDocument.SaveOperationType)
    }

    private struct PendingCallback {
        let delegate: AnyObject
        let selector: Selector
        let contextInfo: UnsafeMutableRawPointer?
    }

    private(set) var routes: [Route] = []
    private var callbacks: [PendingCallback] = []

    override func save(
        withDelegate delegate: Any?,
        didSave didSaveSelector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        routes.append(.save)
        recordCallback(delegate: delegate, selector: didSaveSelector, contextInfo: contextInfo)
    }

    override func runModalSavePanel(
        for saveOperation: NSDocument.SaveOperationType,
        delegate: Any?,
        didSave didSaveSelector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        routes.append(.savePanel(saveOperation))
        recordCallback(delegate: delegate, selector: didSaveSelector, contextInfo: contextInfo)
    }

    func finishSave(succeeded: Bool) {
        guard !callbacks.isEmpty else {
            preconditionFailure("No AppKit save callback is pending")
        }
        if succeeded {
            updateChangeCount(.changeCleared)
        }
        let callback = callbacks.removeFirst()
        typealias SaveCallback = @convention(c) (
            AnyObject,
            Selector,
            NSDocument,
            Bool,
            UnsafeMutableRawPointer?
        ) -> Void
        let implementation = callback.delegate.method(for: callback.selector)
        let function = unsafeBitCast(implementation, to: SaveCallback.self)
        function(
            callback.delegate,
            callback.selector,
            self,
            succeeded,
            callback.contextInfo
        )
    }

    private func recordCallback(
        delegate: Any?,
        selector: Selector?,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let delegate = delegate as AnyObject?, let selector else {
            preconditionFailure("Coordinator must provide an AppKit completion selector")
        }
        callbacks.append(PendingCallback(
            delegate: delegate,
            selector: selector,
            contextInfo: contextInfo
        ))
    }
}

@MainActor
final class WindowClosePreflightRecorder: NSObject {
    private(set) var results: [Bool] = []

    @objc(document:shouldClose:contextInfo:)
    func document(
        _ document: NSDocument,
        shouldClose: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        results.append(shouldClose)
    }
}

extension UTType {
    static var tsi: UTType {
        UTType(importedAs: "com.native-instruments.traktor.tsi")
    }
}
