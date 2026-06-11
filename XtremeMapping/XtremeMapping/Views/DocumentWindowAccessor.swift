//
//  DocumentWindowAccessor.swift
//  SuperXtremeMapping
//
//  Zero-size view that surfaces the hosting NSWindow (and its backing
//  NSDocument) to SwiftUI content the moment the view attaches to a window.
//  Replaces NSDocumentController guessing: the window controller's document
//  is the only authoritative link between a SwiftUI document view and its
//  NSDocument.
//

import SwiftUI
import AppKit

struct DocumentWindowAccessor: NSViewRepresentable {
    /// Called once when the view lands in a window — use to configure the
    /// window itself (e.g. set its identifier).
    var configureWindow: ((NSWindow) -> Void)?

    /// Called with the window controller's NSDocument once resolved.
    var onDocumentResolved: ((NSDocument) -> Void)?

    init(
        configureWindow: ((NSWindow) -> Void)? = nil,
        onDocumentResolved: ((NSDocument) -> Void)? = nil
    ) {
        self.configureWindow = configureWindow
        self.onDocumentResolved = onDocumentResolved
    }

    /// Convenience: document-resolution-only accessor.
    init(_ onDocumentResolved: @escaping (NSDocument) -> Void) {
        self.init(configureWindow: nil, onDocumentResolved: onDocumentResolved)
    }

    func makeNSView(context: Context) -> WindowObservingView {
        let view = WindowObservingView()
        view.configureWindow = configureWindow
        view.onDocumentResolved = onDocumentResolved
        return view
    }

    func updateNSView(_ nsView: WindowObservingView, context: Context) {
        nsView.configureWindow = configureWindow
        nsView.onDocumentResolved = onDocumentResolved
    }

    final class WindowObservingView: NSView {
        var configureWindow: ((NSWindow) -> Void)?
        var onDocumentResolved: ((NSDocument) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }

            configureWindow?(window)
            resolveDocument(in: window, allowRetry: true)
        }

        private func resolveDocument(in window: NSWindow, allowRetry: Bool) {
            guard onDocumentResolved != nil else { return }

            if let document = window.windowController?.document as? NSDocument {
                onDocumentResolved?(document)
            } else if allowRetry {
                // The window controller's document can attach slightly after
                // the view lands in the window — retry once on the next
                // runloop tick. The fileURL secondary lookup and pending-dirty
                // flush in TraktorMappingDocument cover any remaining gap.
                DispatchQueue.main.async { [weak self] in
                    guard let self, let window = self.window else { return }
                    self.resolveDocument(in: window, allowRetry: false)
                }
            }
        }
    }
}
