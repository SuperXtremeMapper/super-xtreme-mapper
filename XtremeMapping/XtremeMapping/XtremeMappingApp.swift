//
//  XtremeMappingApp.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine

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
        Window("Welcome to XXtreme Mapping", id: "welcome") {
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
            ContentView(document: file.document)
        }
        .commands {
            EditCommands()

            // Help menu with feedback and about
            CommandGroup(replacing: .help) {
                Button("Bug Report / Feedback") {
                    let subject = "XXtreme Mapper Feedback"
                    let email = "XXtremeMapper@protonmail.com"
                    if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button("About XXtreme Mapping") {
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
        Window("About XXtreme Mapping", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

}

// MARK: - About View

/// About window showing credits and acknowledgments
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            // App icon and name
            VStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)

                Text("XXtreme Mapping")
                    .font(.title)
                    .fontWeight(.bold)

                Text("A revived TSI Editor for Traktor,\nin the spirit of Xtreme Mapping (RIP)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Version 0.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Credits section
            VStack(alignment: .leading, spacing: 12) {
                Text("Credits & Acknowledgments")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
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

            Divider()

            // Feedback button
            Button(action: sendFeedback) {
                HStack {
                    Image(systemName: "envelope")
                    Text("Bug Report / Feedback")
                }
            }
            .buttonStyle(.borderedProminent)

            Text("XXtremeMapper@protonmail.com")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Trademark disclaimer
            Text("Traktor is a registered trademark of Native Instruments GmbH. Its use does not imply affiliation with or endorsement by the trademark owner.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(width: 400)
    }

    @ViewBuilder
    private func creditRow(title: String, name: String, description: String, link: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .fontWeight(.semibold)

                if let link = link {
                    Button(action: { openURL(URL(string: link)!) }) {
                        Image(systemName: "link")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accentColor)
                }
            }

            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(.vertical, 4)
    }

    private func sendFeedback() {
        let subject = "XXtreme Mapper Feedback"
        let email = "XXtremeMapper@protonmail.com"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - App Delegate

/// App delegate to handle launch behavior and document management
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register our custom document controller
        _ = XtremeMappingDocumentController.shared

        // Observe window close notifications to reopen welcome when last document closes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
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
            // Delay check to allow document to fully close
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.checkAndShowWelcomeIfNeeded()
            }
        }
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
