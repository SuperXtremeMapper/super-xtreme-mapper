import SwiftUI
import AppKit

/// A transparent native button owns the entire painted surface; SwiftUI keeps
/// drawing the existing background, border, text, and hover glow underneath it.
struct CommandMenuHitArea: NSViewRepresentable {
    let categories: [CommandCategory2]
    let isDisabled: Bool
    let label: String
    let onHover: (Bool) -> Void
    let onSelect: (TraktorCommandDescriptor) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> HitButton {
        let button = HitButton()
        button.isTransparent = true
        button.isBordered = false
        button.target = button
        button.action = #selector(HitButton.openMenu)
        return button
    }

    func updateNSView(_ button: HitButton, context: Context) {
        context.coordinator.parent = self
        button.isEnabled = !isDisabled
        button.setAccessibilityLabel(label)
        button.toolTip = label
        button.hoverChanged = onHover
        button.commandMenu = context.coordinator.makeMenu(categories)
    }

    final class Coordinator: NSObject {
        var parent: CommandMenuHitArea
        init(_ parent: CommandMenuHitArea) { self.parent = parent }

        func makeMenu(_ categories: [CommandCategory2]) -> NSMenu {
            let menu = NSMenu()
            for category in categories {
                let item = NSMenuItem(title: category.name, action: nil, keyEquivalent: "")
                let children = makeMenu(category.subcategories ?? [])
                for command in category.commands ?? [] {
                    let action = NSMenuItem(title: command.name, action: #selector(selectCommand(_:)), keyEquivalent: "")
                    action.target = self
                    action.representedObject = command.descriptor
                    children.addItem(action)
                }
                item.submenu = children
                menu.addItem(item)
            }
            return menu
        }

        @objc private func selectCommand(_ sender: NSMenuItem) {
            guard !parent.isDisabled, let descriptor = sender.representedObject as? TraktorCommandDescriptor else { return }
            parent.onSelect(descriptor)
        }
    }

    final class HitButton: NSButton {
        var commandMenu: NSMenu?
        var hoverChanged: ((Bool) -> Void)?
        private var hoverTracking: NSTrackingArea?

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
        }

        override func updateTrackingAreas() {
            if let hoverTracking { removeTrackingArea(hoverTracking) }
            let tracking = NSTrackingArea(rect: .zero,
                options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
            addTrackingArea(tracking)
            hoverTracking = tracking
            super.updateTrackingAreas()
        }

        override func mouseEntered(with event: NSEvent) { hoverChanged?(true) }
        override func mouseExited(with event: NSEvent) { hoverChanged?(false) }

        @objc func openMenu() {
            guard isEnabled else { return }
            commandMenu?.popUp(positioning: nil,
                at: NSPoint(x: bounds.minX, y: isFlipped ? bounds.maxY : bounds.minY), in: self)
            if let window {
                hoverChanged?(bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)))
            }
        }
    }
}
