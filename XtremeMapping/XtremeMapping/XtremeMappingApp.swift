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

@main
struct XtremeMappingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var welcomeState = WelcomeWindowState.shared

    var body: some Scene {
        // Welcome window shown on launch
        Window("Welcome to Super Xtreme Mapper", id: "welcome") {
            WelcomeView(
                onNewMapping: {
                    NSDocumentController.shared.newDocument(nil)
                },
                onOpenMapping: {
                    NSDocumentController.shared.openDocument(nil)
                }
            )
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

        // Document windows for TSI files
        DocumentGroup(newDocument: { TraktorMappingDocument() }) { file in
            ContentView(document: file.document, fileURL: file.fileURL)
                .onAppear {
                    file.document.updateFileURL(file.fileURL)
                }
                .onChange(of: file.fileURL) { _, newURL in
                    file.document.updateFileURL(newURL)
                }
        }
        .commands {
            EditCommands()

            // Help menu with feedback and about
            CommandGroup(replacing: .help) {
                Button("Bug Report / Feedback") {
                    let subject = "Super Xtreme Mapper Feedback"
                    let email = "sxtrememapper@proton.me"
                    if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button("About Super Xtreme Mapper") {
                    if let aboutWindow = NSApplication.shared.windows.first(where: { $0.title.contains("About") }) {
                        aboutWindow.makeKeyAndOrderFront(nil)
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
                        // TODO: Implement wizard
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

        // About window
        Window("About Super Xtreme Mapper", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
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

                Text("VERSION 0.1")
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
        .background(AppThemeV2.Colors.stone900)
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
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowDelegates: [ObjectIdentifier: DocumentWindowDelegateProxy] = [:]
    private var didSaveObserver: NSObjectProtocol?
    private var pendingTerminationDocuments: [NSDocument] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register our custom document controller
        _ = XtremeMappingDocumentController.shared
        NSDocumentController.shared.autosavingDelay = -1

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

        didSaveObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("NSDocumentDidSaveNotification"),
            object: nil,
            queue: .main
        ) { notification in
            guard let document = notification.object as? NSDocument else { return }
            let opKey = "NSDocumentSaveOperation"
            let opValue = (notification.userInfo?[opKey] as? NSNumber)?.intValue
            if let opValue, opValue == NSDocument.SaveOperationType.autosaveElsewhereOperation.rawValue {
                return
            }
            Task { @MainActor in
                TraktorMappingDocument.markClean(for: document.fileURL)
            }
        }

        // Show welcome window on launch (or create new document if user chose to skip)
        openWelcomeWindow()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Don't auto-create untitled document - show welcome window instead
        return false
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // Don't create untitled documents automatically
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no windows are visible, show the welcome window
        if !flag {
            openWelcomeWindow()
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let dirtyDocuments = NSDocumentController.shared.documents.filter { document in
            TraktorMappingDocument.isDirty(for: document.fileURL)
        }

        if dirtyDocuments.isEmpty {
            return .terminateNow
        }

        pendingTerminationDocuments = dirtyDocuments
        promptNextTerminationDocument()
        return .terminateLater
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }

        // Skip if this is the welcome window closing
        if closingWindow.title.contains("Welcome") {
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
        attachDocumentDelegateIfNeeded(to: window)
    }

    private func attachDocumentDelegateIfNeeded(to window: NSWindow) {
        guard window.windowController?.document != nil else { return }
        guard !(window.delegate is DocumentWindowDelegateProxy) else { return }

        let identifier = ObjectIdentifier(window)
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
        // Check if user has opted to skip the welcome screen
        let skipWelcome = UserDefaults.standard.bool(forKey: "skipWelcomeScreen")
        if skipWelcome {
            // Create a new blank document instead
            NSDocumentController.shared.newDocument(nil)
            return
        }

        // Find existing welcome window or trigger creation of new one
        let welcomeWindows = NSApplication.shared.windows.filter {
            $0.title.contains("Welcome")
        }

        if let existingWelcome = welcomeWindows.first {
            existingWelcome.makeKeyAndOrderFront(nil)
        } else {
            // Trigger SwiftUI to open the window via shared state
            DispatchQueue.main.async {
                WelcomeWindowState.shared.shouldShowWelcome = true
            }
        }
    }

    fileprivate func promptToSave(document: NSDocument, window: NSWindow?, completion: @escaping (SaveDecision) -> Void) {
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
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }

        let document = pendingTerminationDocuments.removeFirst()
        let window = document.windowControllers.first?.window

        promptToSave(document: document, window: window) { [weak self] decision in
            guard let self else { return }
            switch decision {
            case .save:
                self.save(document: document) { didSave in
                    if didSave {
                        self.promptNextTerminationDocument()
                    } else {
                        NSApp.reply(toApplicationShouldTerminate: false)
                    }
                }
            case .discard:
                Task { @MainActor in
                    TraktorMappingDocument.markClean(for: document.fileURL)
                    document.updateChangeCount(.changeCleared)
                }
                document.close()
                self.promptNextTerminationDocument()
            case .cancel:
                NSApp.reply(toApplicationShouldTerminate: false)
            }
        }
    }

    fileprivate func save(document: NSDocument, completion: @escaping (Bool) -> Void) {
        let identifier = ObjectIdentifier(document)
        SaveCallbackStore.shared.register(identifier: identifier, completion: completion)
        document.save(withDelegate: SaveCallbackStore.shared, didSave: #selector(SaveCallbackStore.document(_:didSave:contextInfo:)), contextInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(document).toOpaque()))
    }
}

// MARK: - Document Window Delegate

final class DocumentWindowDelegateProxy: NSObject, NSWindowDelegate {
    private weak var originalDelegate: NSWindowDelegate?
    private let appDelegate: AppDelegate

    init(originalDelegate: NSWindowDelegate?, appDelegate: AppDelegate) {
        self.originalDelegate = originalDelegate
        self.appDelegate = appDelegate
        super.init()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let originalDelegate = originalDelegate,
           let shouldClose = originalDelegate.windowShouldClose?(sender) {
            if !shouldClose {
                return false
            }
        }

        guard let document = sender.windowController?.document as? NSDocument else { return true }
        let dirty = TraktorMappingDocument.isDirty(for: document.fileURL)
        if !dirty {
            return true
        }

        appDelegate.promptToSave(document: document, window: sender) { [weak self] decision in
            guard let self else { return }
            switch decision {
            case .save:
                self.appDelegate.save(document: document) { didSave in
                    if didSave {
                        document.close()
                    }
                }
            case .discard:
                Task { @MainActor in
                    TraktorMappingDocument.markClean(for: document.fileURL)
                    document.updateChangeCount(.changeCleared)
                }
                document.close()
            case .cancel:
                break
            }
        }
        return false
    }
}

// MARK: - Save Callback Store

private final class SaveCallbackStore: NSObject {
    static let shared = SaveCallbackStore()
    private var completions: [ObjectIdentifier: (Bool) -> Void] = [:]

    func register(identifier: ObjectIdentifier, completion: @escaping (Bool) -> Void) {
        completions[identifier] = completion
    }

    @objc(document:didSave:contextInfo:)
    func document(_ document: AnyObject, didSave saved: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let document = document as? NSDocument else { return }
        let identifier = ObjectIdentifier(document)
        let completion = completions.removeValue(forKey: identifier)
        completion?(saved)
    }
}

private enum SaveDecision {
    case save
    case discard
    case cancel
}

// MARK: - Custom Document Controller

/// Custom document controller that closes blank documents when opening files
class XtremeMappingDocumentController: NSDocumentController {

    // Singleton instance
    private static let _shared = XtremeMappingDocumentController()

    override static var shared: NSDocumentController {
        return _shared
    }

    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, (any Error)?) -> Void) {
        // Before opening, find any untitled blank documents to close
        let untitledDocs = documents.filter { doc in
            // Document is untitled if it has no fileURL
            return doc.fileURL == nil
        }

        // Open the document
        super.openDocument(withContentsOf: url, display: displayDocument) { document, alreadyOpen, error in
            // If successfully opened a new document, close the untitled ones
            if document != nil && error == nil && !alreadyOpen {
                for untitledDoc in untitledDocs {
                    // Close without saving (it's blank)
                    untitledDoc.close()
                }
            }
            completionHandler(document, alreadyOpen, error)
        }
    }
}
