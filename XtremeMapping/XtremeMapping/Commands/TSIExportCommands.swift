import AppKit
import Darwin
import SwiftUI

private struct TSILossyExportAvailabilityKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var tsiLossyExportAvailable: Bool? {
        get { self[TSILossyExportAvailabilityKey.self] }
        set { self[TSILossyExportAvailabilityKey.self] = newValue }
    }
}

@MainActor
final class DocumentSaveCoordinator: NSObject {
    enum Intent: CaseIterable, Equatable {
        case save
        case saveAs
        case close
        case termination

        fileprivate var usesSavePanel: Bool { self == .saveAs }
    }

    typealias BeginSave = @MainActor (
        _ document: NSDocument,
        _ intent: Intent,
        _ coordinator: DocumentSaveCoordinator
    ) -> Void

    static let shared = DocumentSaveCoordinator()

    private let beginSave: BeginSave
    private var completions: [ObjectIdentifier: (Bool) -> Void] = [:]

    init(beginSave: BeginSave? = nil) {
        self.beginSave = beginSave ?? Self.beginAppKitSave
        super.init()
    }

    @discardableResult
    func save(
        document: NSDocument,
        intent: Intent,
        completion: @escaping (Bool) -> Void = { _ in }
    ) -> Bool {
        let identifier = ObjectIdentifier(document)
        guard completions[identifier] == nil else {
            completion(false)
            return false
        }

        let model = TraktorMappingDocument.registeredDocument(for: document)
        guard model?.beginCoordinatedWrite() != false else {
            completion(false)
            return false
        }

        completions[identifier] = completion
        beginSave(document, intent, self)
        return true
    }

    func completeSave(document: NSDocument, succeeded: Bool) {
        let identifier = ObjectIdentifier(document)
        guard let completion = completions.removeValue(forKey: identifier) else { return }
        guard let model = TraktorMappingDocument.registeredDocument(for: document) else {
            completion(succeeded)
            return
        }
        defer { model.endCoordinatedWrite() }

        if succeeded {
            do {
                _ = try model.commitPendingWriteIfPresent()
                completion(true)
            } catch {
                model.discardPendingWrite()
                NSApp.presentError(error)
                completion(false)
            }
        } else {
            model.discardPendingWrite()
            completion(false)
        }
    }

    @objc(document:didSave:contextInfo:)
    private func document(
        _ document: AnyObject,
        didSave succeeded: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        guard let document = document as? NSDocument else { return }
        completeSave(document: document, succeeded: succeeded)
    }

    private static func beginAppKitSave(
        document: NSDocument,
        intent: Intent,
        coordinator: DocumentSaveCoordinator
    ) {
        let selector = #selector(DocumentSaveCoordinator.document(_:didSave:contextInfo:))
        if intent.usesSavePanel {
            document.runModalSavePanel(
                for: .saveAsOperation,
                delegate: coordinator,
                didSave: selector,
                contextInfo: nil
            )
        } else {
            document.save(
                withDelegate: coordinator,
                didSave: selector,
                contextInfo: nil
            )
        }
    }
}

/// Success-only compatibility path for native responder saves and Save All.
/// The receipt commit is idempotent, so notification/callback order is safe.
@MainActor
final class DocumentSaveReceiptObserver: NSObject {
    typealias ErrorHandler = @MainActor (Error) -> Void

    private let center: NotificationCenter
    private let errorHandler: ErrorHandler

    init(
        center: NotificationCenter = .default,
        errorHandler: @escaping ErrorHandler = { NSApp.presentError($0) }
    ) {
        self.center = center
        self.errorHandler = errorHandler
        super.init()
        center.addObserver(
            self,
            selector: #selector(documentDidSave(_:)),
            name: Notification.Name("NSDocumentDidSaveNotification"),
            object: nil
        )
    }

    deinit {
        center.removeObserver(self)
    }

    @objc private func documentDidSave(_ notification: Notification) {
        guard let document = notification.object as? NSDocument else { return }
        let operationKey = "NSDocumentSaveOperation"
        if let operation = (notification.userInfo?[operationKey] as? NSNumber)?.intValue,
           operation == NSDocument.SaveOperationType.autosaveElsewhereOperation.rawValue {
            return
        }
        guard let model = TraktorMappingDocument.registeredDocument(for: document) else { return }
        do {
            _ = try model.commitPendingWriteIfPresent()
        } catch {
            model.discardPendingWrite()
            errorHandler(error)
        }
    }
}

enum TSIExportError: Error, Equatable, LocalizedError {
    case destinationMatchesSource
    case destinationAlreadyExists
    case requiresLossyConvertible

    var errorDescription: String? {
        switch self {
        case .destinationMatchesSource:
            "Choose a destination that is not the source TSI or an alias of it."
        case .destinationAlreadyExists:
            "Choose a new destination. Converted export never replaces an existing filesystem entry."
        case .requiresLossyConvertible:
            "Converted export is available only when the preservation report identifies lossy source data."
        }
    }
}

enum TSIExportDestinationValidator {
    static func validateNewDestination(source: URL?, destination: URL) throws {
        if let source, isSameFile(source: source, destination: destination) {
            throw TSIExportError.destinationMatchesSource
        }
        if entryExistsWithoutFollowing(at: destination) {
            throw TSIExportError.destinationAlreadyExists
        }
    }

    static func isSameFile(source: URL, destination: URL) -> Bool {
        let standardizedSource = source.standardizedFileURL
        let standardizedDestination = destination.standardizedFileURL
        if standardizedSource.path == standardizedDestination.path {
            return true
        }

        let resolvedSource = standardizedSource.resolvingSymlinksInPath().standardizedFileURL
        let resolvedDestination = standardizedDestination.resolvingSymlinksInPath().standardizedFileURL
        if resolvedSource.path == resolvedDestination.path {
            return true
        }

        let caseSensitive = volumeIsCaseSensitive(at: resolvedSource)
        if canonicalPathsMatch(resolvedSource, resolvedDestination, caseSensitive: caseSensitive) {
            return true
        }

        let keys: Set<URLResourceKey> = [.fileResourceIdentifierKey]
        guard let sourceIdentifier = try? resolvedSource.resourceValues(forKeys: keys).fileResourceIdentifier,
              let destinationIdentifier = try? resolvedDestination.resourceValues(forKeys: keys).fileResourceIdentifier,
              let sourceObject = sourceIdentifier as? NSObject,
              let destinationObject = destinationIdentifier as? NSObject else {
            return false
        }
        return sourceObject.isEqual(destinationObject)
    }

    static func canonicalPathsMatch(
        _ lhs: URL,
        _ rhs: URL,
        caseSensitive: Bool
    ) -> Bool {
        let left = lhs.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        let right = rhs.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        if caseSensitive {
            return left == right
        }
        return left.compare(right, options: [.caseInsensitive, .literal]) == .orderedSame
    }

    private static func volumeIsCaseSensitive(at url: URL) -> Bool {
        var probe = url
        while !FileManager.default.fileExists(atPath: probe.path),
              probe.pathComponents.count > 1 {
            probe.deleteLastPathComponent()
        }
        return (try? probe.resourceValues(
            forKeys: [.volumeSupportsCaseSensitiveNamesKey]
        ).volumeSupportsCaseSensitiveNames) ?? true
    }

    private static func entryExistsWithoutFollowing(at url: URL) -> Bool {
        var status = stat()
        return url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return lstat(path, &status) == 0
        }
    }
}

/// Publishes a complete file atomically without following or replacing any
/// destination entry. The exclusive rename closes the final TOCTOU window.
enum TSIExclusiveAtomicWriter {
    static func publish(_ data: Data, to destination: URL) throws {
        let directory = destination.deletingLastPathComponent()
        let temporary = directory.appendingPathComponent(
            ".sxm-export-\(UUID().uuidString).tmp"
        )
        let descriptor: Int32 = temporary.withUnsafeFileSystemRepresentation { path in
            guard let path else { return Int32(-1) }
            return Darwin.open(
                path,
                O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,
                S_IRUSR | S_IWUSR
            )
        }
        guard descriptor >= 0 else { throw posixError(errno) }

        var descriptorIsOpen = true
        var temporaryExists = true
        defer {
            if descriptorIsOpen { _ = Darwin.close(descriptor) }
            if temporaryExists {
                temporary.withUnsafeFileSystemRepresentation { path in
                    if let path { _ = unlink(path) }
                }
            }
        }

        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                guard let baseAddress = bytes.baseAddress else { break }
                let count = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    bytes.count - offset
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    throw posixError(errno)
                }
                offset += count
            }
        }
        guard fsync(descriptor) == 0 else { throw posixError(errno) }
        guard Darwin.close(descriptor) == 0 else { throw posixError(errno) }
        descriptorIsOpen = false

        let renameResult: Int32 = temporary.withUnsafeFileSystemRepresentation { sourcePath in
            destination.withUnsafeFileSystemRepresentation { destinationPath in
                guard let sourcePath, let destinationPath else { return Int32(-1) }
                return renameatx_np(
                    AT_FDCWD,
                    sourcePath,
                    AT_FDCWD,
                    destinationPath,
                    UInt32(RENAME_EXCL)
                )
            }
        }
        guard renameResult == 0 else {
            if errno == EEXIST {
                throw TSIExportError.destinationAlreadyExists
            }
            throw posixError(errno)
        }
        temporaryExists = false
    }

    private static func posixError(_ code: Int32) -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
}

enum TSIExportRiskPresenter {
    static func warningText(for risks: [TSIPreservationRisk]) -> String {
        risks.enumerated().map { index, risk in
            let detail = risk.detail.isEmpty ? "" : " — \(risk.detail)"
            return "\(index + 1). \(risk.code.rawValue): \(risk.path)\(detail)"
        }.joined(separator: "\n")
    }
}

extension TraktorMappingDocument {
    var lossyExportRisks: [TSIPreservationRisk] {
        let report = TSIWriter().preservationReport(for: mappingFile)
        return report.disposition == .lossyConvertible ? report.risks : []
    }

    func exportLossyConvertedCopy(to destination: URL) throws {
        let writer = TSIWriter()
        let plan = try writer.makeConvertedWritePlan(for: mappingFile)
        guard plan.report.disposition == .lossyConvertible else {
            throw TSIExportError.requiresLossyConvertible
        }

        _ = try TSIParser().parseDocument(plan.output)
        // Recompute identity after serialization and parsing. Publication then
        // uses an exclusive atomic rename, so a swapped alias cannot replace
        // the source (or any other existing filesystem entry).
        try TSIExportDestinationValidator.validateNewDestination(
            source: fileURL,
            destination: destination
        )
        try TSIExclusiveAtomicWriter.publish(plan.output, to: destination)
        _ = try TSIParser().parseDocument(Data(contentsOf: destination))
    }
}

@MainActor
enum TSIExportCommandActions {
    static func saveCurrentDocument(as saveAs: Bool) {
        guard let document = NSDocumentController.shared.currentDocument else { return }
        DocumentSaveCoordinator.shared.save(
            document: document,
            intent: saveAs ? .saveAs : .save
        )
    }

    private static var currentDocument: TraktorMappingDocument? {
        guard let nsDocument = NSDocumentController.shared.currentDocument else { return nil }
        return TraktorMappingDocument.registeredDocument(for: nsDocument)
    }

    static func exportCurrentDocument() {
        guard let document = currentDocument else { return }
        let risks = document.lossyExportRisks
        guard !risks.isEmpty else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Export a lossy converted copy?"
        alert.informativeText = TSIExportRiskPresenter.warningText(for: risks)
        alert.addButton(withTitle: "Choose Destination…")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.tsi]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "Converted Copy.tsi"
        guard panel.runModal() == .OK, let destination = panel.url else { return }

        do {
            try document.exportLossyConvertedCopy(to: destination)
        } catch {
            NSApp.presentError(error)
        }
    }
}
