import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

nonisolated enum JSONImportFileReader {
    static func read(_ url: URL, maximumBytes: Int = 128 * 1024 * 1024) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var result = Data()
        while true {
            try Task.checkCancellation()
            let remaining = maximumBytes - result.count
            guard remaining >= 0 else { throw oversized() }
            // Read at most one byte beyond the bound, including files that grow during review.
            let chunk = try handle.read(upToCount: min(1024 * 1024, remaining + 1)) ?? Data()
            if chunk.isEmpty { return result }
            guard chunk.count <= remaining else { throw oversized() }
            result.append(chunk)
        }
    }

    private static func oversized() -> SXMJSONIssue {
        SXMJSONIssue(code: "json.resourceLimit", path: "$", message: "The JSON file exceeds the import size limit.")
    }
}

@MainActor
final class JSONImportCoordinator: ObservableObject {
    @Published private(set) var candidate: JSONImportCandidate?
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    private var generation = UUID()
    private var task: Task<Void, Never>?
    private let openDocument: (TraktorMappingDocument) -> Void
    private let reviewFile: @Sendable (URL) async throws -> JSONImportCandidate
    var onClose: (() -> Void)?

    init(
        openDocument: @escaping (TraktorMappingDocument) -> Void,
        reviewFile: @escaping @Sendable (URL) async throws -> JSONImportCandidate = { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try JSONImportFileReader.read(url)
            try Task.checkCancellation()
            return JSONImportService.review(data)
        }
    ) {
        self.openDocument = openDocument
        self.reviewFile = reviewFile
    }

    @discardableResult
    func begin(url: URL) -> Task<Void, Never> {
        task?.cancel()
        generation = UUID()
        let request = generation
        candidate = nil
        errorMessage = nil
        isWorking = true
        let reviewFile = self.reviewFile
        let pending = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let candidate = try await reviewFile(url)
                try Task.checkCancellation()
                return candidate
            }
            do {
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: {
                    worker.cancel()
                }
                guard let self, !Task.isCancelled, self.generation == request else { return }
                self.present(result)
            } catch {
                guard let self, !Task.isCancelled, self.generation == request else { return }
                self.isWorking = false
                self.errorMessage = error.localizedDescription
            }
        }
        task = pending
        return pending
    }

    func present(_ result: JSONImportCandidate) {
        candidate = result
        isWorking = false
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        candidate = nil
        isWorking = false
        onClose?()
    }

    func accept() {
        guard !isWorking, let candidate, candidate.canOpen,
              !candidate.diagnostics.contains(where: { $0.severity == .error }),
              let file = candidate.mappingFile else { return }
        let document = TraktorMappingDocument(mappingFile: file)
        document.noteChange()
        self.candidate = nil
        openDocument(document)
        onClose?()
    }
}

extension TraktorMappingDocument {
    func exportJSON(to destination: URL) throws {
        let data = try SXMJSONCodec.encode(mappingFile)
        try TSIExportDestinationValidator.validateNewDestination(source: fileURL, destination: destination)
        try TSIExclusiveAtomicWriter.publish(data, to: destination)
    }
}

private struct JSONExportAvailabilityKey: FocusedValueKey { typealias Value = Bool }
extension FocusedValues {
    var jsonExportAvailable: Bool? {
        get { self[JSONExportAvailabilityKey.self] }
        set { self[JSONExportAvailabilityKey.self] = newValue }
    }
}

@MainActor
struct JSONImportExportCommands: Commands {
    @Environment(\.newDocument) private var newDocument
    @FocusedValue(\.jsonExportAvailable) private var exportAvailable

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Import JSON…") {
                JSONImportWindowPresenter.shared.chooseFile { document in
                    newDocument { document }
                }
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            Button("Export JSON…") {
                // Resolve at invocation, so another document becoming active cannot reuse stale state.
                guard let backing = NSDocumentController.shared.currentDocument,
                      let document = TraktorMappingDocument.registeredDocument(for: backing) else { return }
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = (document.fileURL?.deletingPathExtension().lastPathComponent ?? "Mapping") + ".sxm.json"
                panel.title = "Export JSON"
                panel.message = "Choose a new file. The current TSI and its unsaved edits remain open."
                guard panel.runModal() == .OK, let url = panel.url else { return }
                do { try document.exportJSON(to: url) }
                catch { NSApp.presentError(error) }
            }
            .disabled(exportAvailable != true)
        }
    }
}

@MainActor
private final class JSONImportWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = JSONImportWindowPresenter()
    private var window: NSPanel?
    private var coordinator: JSONImportCoordinator?

    func chooseFile(openDocument: @escaping (TraktorMappingDocument) -> Void) {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let panel = NSOpenPanel()
        panel.title = "Import JSON"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let review = JSONImportCoordinator(openDocument: openDocument)
        let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 680, height: 560), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Review JSON Import"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 400)
        window.contentViewController = NSHostingController(rootView: JSONImportReviewSheet(coordinator: review, fileName: url.lastPathComponent))
        window.delegate = self
        review.onClose = { [weak self] in
            self?.window?.close()
            self?.window = nil
            self?.coordinator = nil
        }
        self.window = window
        self.coordinator = review
        window.center()
        window.makeKeyAndOrderFront(nil)
        review.begin(url: url)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        coordinator?.onClose = nil
        coordinator?.cancel()
        coordinator = nil
        window = nil
        return true
    }
}
