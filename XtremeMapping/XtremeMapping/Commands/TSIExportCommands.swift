import AppKit
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

        if succeeded {
            do {
                try model.commitPendingWrite()
                completion(true)
            } catch DocumentSaveLifecycleError.noWriteInFlight {
                // NSDocument may complete a no-op save without requesting a
                // file wrapper. There is no receipt to correlate in that case.
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

enum TSIExportError: Error, Equatable, LocalizedError {
    case destinationMatchesSource
    case requiresLossyConvertible

    var errorDescription: String? {
        switch self {
        case .destinationMatchesSource:
            "Choose a destination that is not the source TSI or an alias of it."
        case .requiresLossyConvertible:
            "Converted export is available only when the preservation report identifies lossy source data."
        }
    }
}

enum TSIExportDestinationValidator {
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
}

extension TraktorMappingDocument {
    var lossyExportRisks: [TSIPreservationRisk] {
        let report = TSIWriter().preservationReport(for: mappingFile)
        return report.disposition == .lossyConvertible ? report.risks : []
    }

    func exportLossyConvertedCopy(to destination: URL) throws {
        let writer = TSIWriter()
        let report = writer.preservationReport(for: mappingFile)
        guard report.disposition == .lossyConvertible else {
            if report.disposition == .unwritable {
                _ = try writer.writeConverted(mappingFile)
            }
            throw TSIExportError.requiresLossyConvertible
        }

        if let fileURL,
           TSIExportDestinationValidator.isSameFile(
               source: fileURL,
               destination: destination
           ) {
            throw TSIExportError.destinationMatchesSource
        }

        let output = try writer.writeConverted(mappingFile)
        _ = try TSIParser().parseDocument(output)
        try output.write(to: destination, options: .atomic)
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
        alert.informativeText = risks.enumerated().map { index, risk in
            "\(index + 1). \(risk.code.rawValue): \(risk.path)"
        }.joined(separator: "\n")
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
