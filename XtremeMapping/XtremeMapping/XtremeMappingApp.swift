//
//  XtremeMappingApp.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine
import AppKit

/// Shared state for managing welcome window visibility
class WelcomeWindowState: ObservableObject {
    static let shared = WelcomeWindowState()
    @Published var shouldShowWelcome = false
}

/// Shared state for managing update window visibility and pending release
class UpdateWindowState: ObservableObject {
    static let shared = UpdateWindowState()
    @Published var shouldShowUpdate = false
    @Published var pendingRelease: GitHubRelease?
}

/// Wrapper to give WelcomeView access to dismissWindow environment
struct WelcomeWindowContent: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        WelcomeView(
            onNewMapping: {
                dismissWindow(id: "welcome")
                NSDocumentController.shared.newDocument(nil)
            },
            onOpenMapping: {
                // Just trigger open - AppDelegate handles closing welcome when doc window appears
                NSDocumentController.shared.openDocument(nil)
            },
            onWizard: {
                dismissWindow(id: "welcome")
                openWindow(id: "modeSelection")
            }
        )
        .background(DocumentWindowAccessor(configureWindow: { window in
            // Stamp a deterministic identifier — SwiftUI does not guarantee
            // the scene id lands on NSWindow.identifier.
            window.identifier = AppDelegate.welcomeWindowIdentifier
        }))
    }
}

@main
struct XtremeMappingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @StateObject private var welcomeState = WelcomeWindowState.shared
    @StateObject private var updateState = UpdateWindowState.shared
    @FocusedValue(\.tsiLossyExportAvailable) private var tsiLossyExportAvailable

    var body: some Scene {
        // Welcome window shown on launch
        Window("Welcome to Super Xtreme Mapper", id: "welcome") {
            WelcomeWindowContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .onChange(of: welcomeState.shouldShowWelcome) { _, shouldShow in
            if shouldShow {
                openWindow(id: "welcome")
                welcomeState.shouldShowWelcome = false
            }
        }

        // Mapping Wizard window
        Window("Mapping Wizard", id: "wizard") {
            MappingWizardWindowContent()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Mode Selection window
        Window("Create New Mapping", id: "modeSelection") {
            ModeSelectionWindow()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Update Available window
        Window("Update Available", id: "update") {
            if let release = updateState.pendingRelease {
                UpdateAvailableSheet(release: release) {
                    dismissWindow(id: "update")
                    updateState.pendingRelease = nil
                }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .onChange(of: updateState.shouldShowUpdate) { _, shouldShow in
            if shouldShow {
                openWindow(id: "update")
                updateState.shouldShowUpdate = false
            }
        }

        // Document windows for TSI files
        DocumentGroup(newDocument: { TraktorMappingDocument() }) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
                .focusedValue(
                    \.tsiLossyExportAvailable,
                    !file.document.lossyExportRisks.isEmpty
                )
                .background(DocumentWindowAccessor { nsDoc in
                    file.document.backingDocument = nsDoc
                })
                .onAppear {
                    file.document.updateFileURL(file.fileURL)

                    // Fast path: fileURL-keyed lookup (unique per document).
                    // The window accessor above resolves untitled documents;
                    // never guess via documents.first.
                    DispatchQueue.main.async {
                        if let fileURL = file.fileURL,
                           let nsDoc = NSDocumentController.shared.document(for: fileURL) {
                            file.document.backingDocument = nsDoc
                        }
                        file.document.objectWillChange.send()
                    }
                }
                .onChange(of: file.fileURL) { _, newURL in
                    file.document.updateFileURL(newURL)
                    if let newURL, let nsDoc = NSDocumentController.shared.document(for: newURL) {
                        file.document.backingDocument = nsDoc
                    }
                }
        }
        .defaultSize(width: 1200, height: 700)
        .commands {
            EditCommands()

            // Availability comes from focused document state. Consulting
            // NSDocumentController here re-enters SwiftUI while it constructs
            // PlatformDocumentController and crashes during launch.
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    TSIExportCommandActions.saveCurrentDocument(as: false)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("Save As…") {
                    TSIExportCommandActions.saveCurrentDocument(as: true)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Export Lossy Converted Copy…") {
                    TSIExportCommandActions.exportCurrentDocument()
                }
                .disabled(tsiLossyExportAvailable != true)
            }

            // Help menu with feedback and about
            CommandGroup(replacing: .help) {
                Button("Super Xtreme Mapper Help") {
                    if let url = URL(string: "https://superxtrememapper.github.io/super-xtreme-mapper/") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Menu("Support SXM") {
                    Button("GitHub Sponsors") {
                        if let url = URL(string: "https://github.com/sponsors/nraford7") {
                            NSWorkspace.shared.open(url)
                        }
                    }

                    Button("Buy Me a Coffee") {
                        if let url = URL(string: "https://ko-fi.com/superxtrememapper") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Divider()

                Button("Bug Report / Feedback") {
                    let subject = "Super Xtreme Mapper Feedback"
                    let email = "sxtrememapper@proton.me"
                    if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            // Custom New menu with controller templates
            CommandGroup(replacing: .newItem) {
                Menu("New") {
                    Button("Generic MIDI") {
                        NSDocumentController.shared.newDocument(nil)
                    }
                    .keyboardShortcut("n", modifiers: .command)

                    Divider()

                    Button("Setup Wizard...") {
                        // Wizard requires an open document - use Wizard button in document window
                        // or create new document first, then open wizard from there
                    }
                    .disabled(true)

                    Divider()

                    Button("Kontrol X1") {
                        // TODO: Create from template
                    }
                    .disabled(true)

                    Button("Kontrol S2") {
                        // TODO: Create from template
                    }
                    .disabled(true)

                    Button("Kontrol S4") {
                        // TODO: Create from template
                    }
                    .disabled(true)
                }
            }
        }

        // Settings window (Command+, on macOS)
        Settings {
            APIKeySettingsView()
        }
    }

}

// MARK: - About View

/// About window showing credits and acknowledgments with V2 styling
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: AppThemeV2.Spacing.lg) {
            // App icon and name with glow
            VStack(spacing: AppThemeV2.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(AppThemeV2.Colors.amberGlow)
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)

                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)
                }

                VStack(spacing: AppThemeV2.Spacing.xxs) {
                    Text("SUPER XTREME")
                        .font(.system(size: 18, weight: .black))
                        .tracking(1.5)
                        .foregroundColor(AppThemeV2.Colors.stone100)

                    Text("MAPPER")
                        .font(.system(size: 22, weight: .black))
                        .tracking(2)
                        .foregroundColor(AppThemeV2.Colors.amber)
                }

                Text("A revived TSI Editor for Traktor,\nin the spirit of Xtreme Mapping (RIP)")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone400)
                    .multilineTextAlignment(.center)

                Text("VERSION \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0")")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(1)
                    .foregroundColor(AppThemeV2.Colors.stone950)
                    .padding(.horizontal, AppThemeV2.Spacing.sm)
                    .padding(.vertical, AppThemeV2.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppThemeV2.Colors.amber)
                    )
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Credits section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
                Text("CREDITS & ACKNOWLEDGMENTS")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(1)
                    .foregroundColor(AppThemeV2.Colors.amber)

                VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                    creditRow(
                        title: "Original Xtreme Mapping",
                        name: "Vincenzo Pietropaolo",
                        description: "Creator of the original Xtreme Mapping app that inspired this project"
                    )

                    creditRow(
                        title: "IvanZ",
                        name: "GitHub Contributor",
                        description: "TSI format research and documentation",
                        link: "https://github.com/ivanz"
                    )

                    creditRow(
                        title: "CMDR Team",
                        name: "cmdr-editor",
                        description: "Traktor command database and TSI editor",
                        link: "https://cmdr-editor.github.io/cmdr/"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Feedback button
            Button(action: sendFeedback) {
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Image(systemName: "envelope")
                        .font(.system(size: 12, weight: .semibold))
                    Text("BUG REPORT / FEEDBACK")
                        .font(AppThemeV2.Typography.micro)
                        .tracking(0.5)
                }
                .foregroundColor(AppThemeV2.Colors.stone950)
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(AppThemeV2.Colors.amber)
                )
            }
            .buttonStyle(.plain)

            Text("sxtrememapper@proton.me")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Trademark disclaimer
            Text("Traktor is a registered trademark of Native Instruments GmbH. Its use does not imply affiliation with or endorsement by the trademark owner.")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(width: 400)
        .background(AppThemeV2.Colors.stone800)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func creditRow(title: String, name: String, description: String, link: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(AppThemeV2.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppThemeV2.Colors.stone200)

                if let link = link {
                    Button(action: { openURL(URL(string: link)!) }) {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppThemeV2.Colors.amber)
                }
            }

            Text(name)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone400)

            Text(description)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .italic()
        }
        .padding(.vertical, 4)
    }

    private func sendFeedback() {
        let subject = "Super Xtreme Mapper Feedback"
        let email = "sxtrememapper@proton.me"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - App Delegate

/// App delegate to handle launch behavior and document management
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    typealias SavePromptPresenter = @MainActor (
        _ document: NSDocument,
        _ window: NSWindow?,
        _ completion: @escaping (SaveDecision) -> Void
    ) -> Void
    typealias TerminationReplier = @MainActor (Bool) -> Void

    /// Identifier stamped onto the welcome window by its content view's
    /// window accessor (SwiftUI does not guarantee the scene id propagates).
    static let welcomeWindowIdentifier = NSUserInterfaceItemIdentifier("sxm-welcome")

    private var windowDelegates: [ObjectIdentifier: DocumentWindowDelegateProxy] = [:]
    private var saveCommandResponders: [ObjectIdentifier: DocumentSaveCommandResponder] = [:]
    private var closeSentinelControllers: [ObjectIdentifier: NSWindowController] = [:]
    private var pendingTerminationDocuments: [NSDocument] = []
    private let saveCoordinator: DocumentSaveCoordinator
    private let savePromptPresenter: SavePromptPresenter?
    private let terminationReply: TerminationReplier

    override init() {
        self.saveCoordinator = .shared
        self.savePromptPresenter = nil
        self.terminationReply = { NSApp.reply(toApplicationShouldTerminate: $0) }
        super.init()
    }

    init(
        saveCoordinator: DocumentSaveCoordinator,
        savePromptPresenter: SavePromptPresenter?,
        terminationReply: @escaping TerminationReplier = {
            NSApp.reply(toApplicationShouldTerminate: $0)
        }
    ) {
        self.saveCoordinator = saveCoordinator
        self.savePromptPresenter = savePromptPresenter
        self.terminationReply = terminationReply
        super.init()
    }

    /// Identify the welcome window by identifier — NEVER by title (a document
    /// named "Welcome Mix.tsi" must not match).
    static func isWelcomeWindow(_ window: NSWindow) -> Bool {
        guard let rawValue = window.identifier?.rawValue else { return false }
        return rawValue == welcomeWindowIdentifier.rawValue || rawValue.hasPrefix("welcome")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disable autosaving (users should save manually)
        Self.disablePeriodicAutosave(on: .shared)

        // Observe window close notifications to reopen welcome when last document closes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeMain(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: nil
        )

        // Check for updates on launch, then show welcome window
        checkForUpdatesOnLaunch()
    }

    static func disablePeriodicAutosave(on documentController: NSDocumentController) {
        // AppKit documents 0 as the value that disables periodic autosaving.
        documentController.autosavingDelay = 0
    }

    /// Check for updates on app launch, then show welcome window
    private func checkForUpdatesOnLaunch() {
        Task { @MainActor in
            do {
                if let release = try await UpdateService.shared.checkForUpdate() {
                    // Update available - show update window first
                    UpdateWindowState.shared.pendingRelease = release
                    UpdateWindowState.shared.shouldShowUpdate = true
                    // Show welcome window after a short delay so update window appears on top
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.openWelcomeWindow()
                    }
                } else {
                    // No update - show welcome window immediately
                    openWelcomeWindow()
                }
            } catch {
                // Silent fail for auto-check, still show welcome window
                print("Update check failed: \(error)")
                openWelcomeWindow()
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Return false to prevent DocumentGroup from auto-creating a document
        return false
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // We handle untitled file by showing welcome instead
        openWelcomeWindow()
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openWelcomeWindow()
        }
        // Return false to prevent system from showing open dialog
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Use NSDocument's built-in isDocumentEdited tracking
        let dirtyDocuments = NSDocumentController.shared.documents.filter { $0.isDocumentEdited }

        if dirtyDocuments.isEmpty {
            return .terminateNow
        }

        pendingTerminationDocuments = dirtyDocuments
        promptNextTerminationDocument()
        return .terminateLater
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        // Release the proxy (and its strongly-held original delegate) so
        // closed windows don't stay alive forever. Deferred one tick:
        // NSWindow.delegate is weak and delegate windowWillClose delivery is
        // notification-based with unspecified observer ordering — releasing
        // synchronously here could deallocate the proxy before the original
        // delegate receives its close callback.
        let closingKey = ObjectIdentifier(closingWindow)
        if let responder = saveCommandResponders.removeValue(forKey: closingKey),
           closingWindow.nextResponder === responder {
            closingWindow.nextResponder = responder.nextResponder
        }
        DispatchQueue.main.async { [weak self] in
            self?.windowDelegates.removeValue(forKey: closingKey)
        }

        // Skip if this is the welcome window closing
        if AppDelegate.isWelcomeWindow(closingWindow) {
            return
        }

        // Check if this window belongs to a document
        let isDocumentWindow = NSDocumentController.shared.documents.contains { doc in
            doc.windowControllers.contains { $0.window == closingWindow }
        }

        // Only check for welcome reopen if a document window is closing
        if isDocumentWindow {
            if let doc = NSDocumentController.shared.documents.first(where: { document in
                document.windowControllers.contains { $0.window == closingWindow }
            }) {
                print("windowWillClose: doc", doc.displayName ?? "Unknown", "edited:", doc.isDocumentEdited)
            } else {
                print("windowWillClose: document window but no matching NSDocument")
            }
            // Delay check to allow document to fully close
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndShowWelcomeIfNeeded()
            }
        }
    }

    @objc private func windowDidBecomeMain(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // If a document window became main, close the welcome window
        if window.windowController?.document != nil {
            if let welcomeWindow = NSApplication.shared.windows.first(where: { AppDelegate.isWelcomeWindow($0) }) {
                welcomeWindow.close()
            }
        }

        attachDocumentDelegateIfNeeded(to: window)
    }

    func attachDocumentDelegateIfNeeded(to window: NSWindow) {
        guard let controller = window.windowController,
              let document = controller.document as? NSDocument else { return }
        guard !(window.delegate is DocumentWindowDelegateProxy) else { return }

        // NSWindow asks NSDocument.shouldCloseWindowController before it asks
        // windowShouldClose. A false flag bypasses native canClose only when
        // another controller exists, so retain a no-window sentinel for the
        // lifetime of the document and let our proxy own every close decision.
        controller.shouldCloseDocument = false
        let documentIdentifier = ObjectIdentifier(document)
        if closeSentinelControllers[documentIdentifier] == nil {
            let sentinel = NSWindowController(window: nil)
            sentinel.shouldCloseDocument = false
            document.addWindowController(sentinel)
            closeSentinelControllers[documentIdentifier] = sentinel
        }

        let identifier = ObjectIdentifier(window)
        if saveCommandResponders[identifier] == nil {
            let responder = DocumentSaveCommandResponder(
                document: document,
                appDelegate: self
            )
            responder.nextResponder = window.nextResponder
            window.nextResponder = responder
            saveCommandResponders[identifier] = responder
        }

        if windowDelegates[identifier] == nil {
            windowDelegates[identifier] = DocumentWindowDelegateProxy(
                originalDelegate: window.delegate,
                appDelegate: self
            )
        }

        window.delegate = windowDelegates[identifier]
    }

    private func checkAndShowWelcomeIfNeeded() {
        // Use NSDocumentController to check for open documents
        let openDocuments = NSDocumentController.shared.documents

        // If no documents remain, show welcome
        if openDocuments.isEmpty {
            openWelcomeWindow()
        }
    }

    private func openWelcomeWindow() {
        // Find existing welcome window or trigger creation via SwiftUI
        let welcomeWindows = NSApplication.shared.windows.filter { AppDelegate.isWelcomeWindow($0) }

        if let existingWelcome = welcomeWindows.first {
            existingWelcome.makeKeyAndOrderFront(nil)
        } else {
            DispatchQueue.main.async {
                WelcomeWindowState.shared.shouldShowWelcome = true
            }
        }
    }

    fileprivate func promptToSave(document: NSDocument, window: NSWindow?, completion: @escaping (SaveDecision) -> Void) {
        if let savePromptPresenter {
            savePromptPresenter(document, window, completion)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to the document \"\(document.displayName ?? "Untitled")\"?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")

        let handler: (NSApplication.ModalResponse) -> Void = { response in
            switch response {
            case .alertFirstButtonReturn:
                completion(.save)
            case .alertSecondButtonReturn:
                completion(.discard)
            default:
                completion(.cancel)
            }
        }

        if let window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    private func promptNextTerminationDocument() {
        guard !pendingTerminationDocuments.isEmpty else {
            terminationReply(true)
            return
        }

        let document = pendingTerminationDocuments.removeFirst()
        let window = document.windowControllers.first?.window

        promptToSave(document: document, window: window) { [weak self] decision in
            guard let self else { return }
            switch decision {
            case .save:
                self.save(document: document, intent: .termination) { didSave in
                    if didSave {
                        self.promptNextTerminationDocument()
                    } else {
                        self.terminationReply(false)
                    }
                }
            case .discard:
                Task { @MainActor in
                    TraktorMappingDocument.markClean(for: document.fileURL)
                    document.updateChangeCount(.changeCleared)
                }
                self.closeDocument(document)
                self.promptNextTerminationDocument()
            case .cancel:
                self.terminationReply(false)
            }
        }
    }

    fileprivate func save(
        document: NSDocument,
        intent: DocumentSaveCoordinator.Intent = .save,
        completion: @escaping (Bool) -> Void
    ) {
        saveCoordinator.save(
            document: document,
            intent: intent,
            completion: completion
        )
    }

    fileprivate func saveAllDocuments() {
        for document in NSDocumentController.shared.documents where document.isDocumentEdited {
            save(document: document, intent: .save) { _ in }
        }
    }

    fileprivate func hasOtherVisibleWindow(
        for document: NSDocument,
        excluding window: NSWindow
    ) -> Bool {
        document.windowControllers.contains { controller in
            guard let candidate = controller.window else { return false }
            return candidate !== window && candidate.isVisible
        }
    }

    fileprivate func closeWindow(_ window: NSWindow, document: NSDocument) {
        if hasOtherVisibleWindow(for: document, excluding: window) {
            window.windowController?.close()
        } else {
            closeDocument(document)
        }
    }

    fileprivate func closeDocument(_ document: NSDocument) {
        let identifier = ObjectIdentifier(document)
        if let sentinel = closeSentinelControllers.removeValue(forKey: identifier) {
            document.removeWindowController(sentinel)
        }
        document.close()
    }
}

// MARK: - Document Window Delegate

/// Intercepts AppKit's standard responder actions before they reach
/// NSDocument's completion-blind action methods. Every user-visible save route
/// therefore enters the same receipt-owning coordinator.
@MainActor
final class DocumentSaveCommandResponder: NSResponder {
    private weak var document: NSDocument?
    private weak var appDelegate: AppDelegate?

    init(document: NSDocument, appDelegate: AppDelegate) {
        self.document = document
        self.appDelegate = appDelegate
        super.init()
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc(saveDocument:)
    private func routeSave(_ sender: Any?) {
        guard let document else { return }
        appDelegate?.save(document: document, intent: .save) { _ in }
    }

    @objc(saveDocumentAs:)
    private func routeSaveAs(_ sender: Any?) {
        guard let document else { return }
        appDelegate?.save(document: document, intent: .saveAs) { _ in }
    }

    @objc(saveAllDocuments:)
    private func routeSaveAll(_ sender: Any?) {
        appDelegate?.saveAllDocuments()
    }
}

@MainActor
final class DocumentWindowDelegateProxy: NSObject, NSWindowDelegate {
    private let originalDelegate: NSWindowDelegate?
    private let appDelegate: AppDelegate

    init(originalDelegate: NSWindowDelegate?, appDelegate: AppDelegate) {
        self.originalDelegate = originalDelegate
        self.appDelegate = appDelegate
        super.init()
    }

    // MARK: - Forward all other delegate methods (mirrors AmberSelectionDelegateProxy)

    override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        }
        return originalDelegate?.responds(to: aSelector) ?? false
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if originalDelegate?.responds(to: aSelector) == true {
            return originalDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let originalDelegate = originalDelegate,
           let shouldClose = originalDelegate.windowShouldClose?(sender) {
            if !shouldClose {
                return false
            }
        }

        guard let document = sender.windowController?.document as? NSDocument else { return true }
        if appDelegate.hasOtherVisibleWindow(for: document, excluding: sender) {
            appDelegate.closeWindow(sender, document: document)
            return false
        }
        if !document.isDocumentEdited {
            appDelegate.closeWindow(sender, document: document)
            return false
        }

        appDelegate.promptToSave(document: document, window: sender) { [weak self] decision in
            guard let self else { return }
            switch decision {
            case .save:
                self.appDelegate.save(document: document, intent: .close) { didSave in
                    if didSave {
                        self.appDelegate.closeWindow(sender, document: document)
                    }
                }
            case .discard:
                Task { @MainActor in
                    TraktorMappingDocument.markClean(nsDocument: document)
                    document.updateChangeCount(.changeCleared)
                    self.appDelegate.closeWindow(sender, document: document)
                }
            case .cancel:
                break
            }
        }
        return false
    }
}

enum SaveDecision {
    case save
    case discard
    case cancel
}
