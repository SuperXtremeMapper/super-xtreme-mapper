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
    @Published private(set) var originalData: Data?
    @Published private(set) var repairPlan: JSONRepairPlan?
    @Published private(set) var isRepairing = false
    @Published private(set) var repairStatus = ""
    @Published private(set) var repairError: String?
    @Published private(set) var repairUnavailableReason: String?
    @Published private(set) var isRepairAccepted = false
    private var originalCandidate: JSONImportCandidate?
    private var repairInput: JSONRepairInput?
    private var generation = UUID()
    private var repairGeneration = UUID()
    private var task: Task<Void, Never>?
    private var repairTask: Task<Void, Never>?
    private let openDocument: (TraktorMappingDocument) -> Void
    private let reviewFile: (@Sendable (URL) async throws -> JSONImportCandidate)?
    private let readData: @Sendable (URL) async throws -> Data
    private let repairService: any JSONRepairing
    private let repairCredentials: MappingAssistantCredentials
    var onClose: (() -> Void)?
    var canRequestRepair: Bool { !isWorking && !isRepairing && candidate?.canOpen == false && repairInput != nil && repairPlan == nil }

    init(
        openDocument: @escaping (TraktorMappingDocument) -> Void,
        reviewFile: (@Sendable (URL) async throws -> JSONImportCandidate)? = nil,
        readData: @escaping @Sendable (URL) async throws -> Data = { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return try JSONImportFileReader.read(url)
        },
        repairService: (any JSONRepairing)? = nil,
        repairCredentials: MappingAssistantCredentials? = nil
    ) {
        self.openDocument = openDocument
        self.reviewFile = reviewFile
        self.readData = readData
        let credentials = repairCredentials ?? MappingAssistantCredentials()
        self.repairCredentials = credentials
        let store = credentials.store
        self.repairService = repairService ?? JSONRepairService(apiKeyProvider: { store.read() })
    }

    @discardableResult
    func begin(url: URL) -> Task<Void, Never> {
        task?.cancel()
        resetRepair()
        generation = UUID()
        let request = generation
        candidate = nil
        originalCandidate = nil
        originalData = nil
        errorMessage = nil
        isWorking = true
        let reviewFile = self.reviewFile
        let readData = self.readData
        let pending = Task { [weak self] in
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let data: Data?
                let candidate: JSONImportCandidate
                if let reviewFile {
                    data = nil
                    candidate = try await reviewFile(url)
                } else {
                    let bytes = try await readData(url)
                    data = bytes
                    try Task.checkCancellation()
                    candidate = JSONImportService.review(bytes)
                }
                var input: JSONRepairInput?
                var unavailable: String?
                if !candidate.canOpen, let data {
                    do { input = try JSONRepairInput(original: data) }
                    catch { unavailable = error.localizedDescription }
                }
                try Task.checkCancellation()
                return (candidate, data, input, unavailable)
            }
            do {
                let result = try await withTaskCancellationHandler {
                    try await worker.value
                } onCancel: { worker.cancel() }
                guard let self, !Task.isCancelled, self.generation == request else { return }
                self.candidate = result.0
                self.originalCandidate = result.0
                self.originalData = result.1
                self.repairInput = result.2
                self.repairUnavailableReason = result.3
                self.isWorking = false
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
        task?.cancel()
        generation = UUID()
        resetRepair()
        originalData = nil
        originalCandidate = result
        candidate = result
        errorMessage = nil
        isWorking = false
    }

    @discardableResult
    func requestRepair(consent: Bool) -> Task<Void, Never>? {
        guard consent, canRequestRepair, let input = repairInput else { return nil }
        let request = generation
        repairGeneration = UUID()
        let repairRequest = repairGeneration
        let service = repairService
        repairError = nil
        isRepairing = true
        repairStatus = "Waiting for Keychain access…"
        let credentials = repairCredentials
        let pending = Task { [weak self] in
            await credentials.refreshAsync()
            guard let self, !Task.isCancelled, self.generation == request, self.repairGeneration == repairRequest else { return }
            guard credentials.hasKey else {
                self.isRepairing = false
                self.repairError = "Add an Anthropic API key in Settings, then try AI repair again."
                return
            }
            self.repairStatus = "Proposing and validating a repair…"
            let worker = Task.detached(priority: .userInitiated) {
                try Task.checkCancellation()
                let patches = try await service.propose(for: input)
                try Task.checkCancellation()
                let plan = try JSONRepairPlan(input: input, patches: patches)
                try Task.checkCancellation()
                return plan
            }
            do {
                let plan = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
                guard !Task.isCancelled, self.generation == request, self.repairGeneration == repairRequest else { return }
                self.repairPlan = plan
                self.isRepairing = false
                self.repairCredentials.clear()
            } catch {
                guard !Task.isCancelled, self.generation == request, self.repairGeneration == repairRequest else { return }
                self.isRepairing = false
                self.repairCredentials.clear()
                // Never surface arbitrary injected transport error bodies or credentials.
                if let safe = error as? JSONRepairError { self.repairError = safe.localizedDescription }
                else if let safe = error as? MappingAssistantService.ServiceError {
                    if case .network = safe { self.repairError = "The repair request could not be completed. Check your connection and try again." }
                    else { self.repairError = safe.localizedDescription }
                } else { self.repairError = "The repair request could not be completed. No changes were made." }
            }
        }
        repairTask = pending
        return pending
    }

    func acceptRepair() {
        guard !isWorking, !isRepairing, !isRepairAccepted, let plan = repairPlan,
              plan.candidate.canOpen, plan.candidate.canWriteTSI else { return }
        candidate = plan.candidate
        isRepairAccepted = true
    }

    func cancelRepair() {
        repairGeneration = UUID()
        repairTask?.cancel()
        repairTask = nil
        isRepairing = false
        repairStatus = ""
        repairCredentials.clear()
    }

    func discardRepair() {
        cancelRepair()
        repairPlan = nil
        repairError = nil
        isRepairAccepted = false
        candidate = originalCandidate
    }

    private func resetRepair() {
        cancelRepair()
        repairInput = nil
        repairPlan = nil
        repairError = nil
        repairUnavailableReason = nil
        isRepairAccepted = false
    }

    func cancel() {
        generation = UUID()
        task?.cancel()
        task = nil
        resetRepair()
        candidate = nil
        originalCandidate = nil
        originalData = nil
        isWorking = false
        onClose?()
    }

    func accept() {
        guard !isWorking, !isRepairing, let candidate, candidate.canOpen,
              !candidate.diagnostics.contains(where: { $0.severity == .error }),
              let file = candidate.mappingFile else { return }
        let document = TraktorMappingDocument(mappingFile: file)
        document.noteChange()
        generation = UUID()
        resetRepair()
        self.candidate = nil
        originalCandidate = nil
        originalData = nil
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
            Button("Export SXM Data (JSON)…") {
                // Resolve at invocation, so another document becoming active cannot reuse stale state.
                guard let backing = NSDocumentController.shared.currentDocument,
                      let document = TraktorMappingDocument.registeredDocument(for: backing) else { return }
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.json]
                panel.nameFieldStringValue = (document.fileURL?.deletingPathExtension().lastPathComponent ?? "Mapping") + ".sxm.json"
                panel.title = "Export SXM Data (JSON)"
                panel.message = "Save your full SXM work — including controller profiles and address overrides that a Traktor TSI cannot retain. Save (TSI) writes the Traktor mapping; the current TSI and its unsaved edits stay open."
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
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 500)
        let host = NSHostingView(rootView: JSONImportReviewSheet(coordinator: review, fileName: url.lastPathComponent))
        // AppKit owns panel geometry as diagnostics and repair controls appear.
        host.sizingOptions = []
        host.frame = NSRect(origin: .zero, size: window.contentLayoutRect.size)
        host.autoresizingMask = [.width, .height]
        let container = NSView(frame: host.frame)
        container.addSubview(host)
        window.contentView = container
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
