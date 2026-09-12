import SwiftUI
import AppKit
import Combine

/// Owned by one document view; never retargets an open conversation to another file.
@MainActor
final class AssistantWindowController: NSObject, ObservableObject, NSWindowDelegate {
    private(set) var window: NSWindow?
    private var cleanup: (() -> Void)?
    private var undoProvider: (() -> UndoManager?)?

    func present(title: String, content: () -> AnyView, onClose: @escaping () -> Void, undoManager: @escaping () -> UndoManager? = { nil }) {
        if let window { window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 850, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 720, height: 560)
        window.contentView = NSHostingView(rootView: content())
        window.delegate = self
        window.level = .floating
        window.center()
        self.window = window
        cleanup = onClose
        undoProvider = undoManager
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { undoProvider?() }

    func close() { window?.close() }
    func windowWillClose(_ notification: Notification) {
        let action = cleanup
        cleanup = nil
        undoProvider = nil
        window?.delegate = nil
        window = nil
        action?()
    }
}
