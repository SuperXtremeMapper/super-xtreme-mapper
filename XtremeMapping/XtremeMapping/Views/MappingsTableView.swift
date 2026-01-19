//
//  MappingsTableView.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import AppKit

/// A table view displaying MIDI mappings with columns for all mapping properties.
///
/// Supports multiple selection, drag and drop reordering, and displays command name,
/// I/O direction, assignment, interaction mode, MIDI assignment, and modifier conditions.
struct MappingsTableView: View {
    /// The mappings to display (already filtered)
    let mappings: [MappingEntry]

    /// The set of selected mapping IDs
    @Binding var selection: Set<MappingEntry.ID>

    /// Whether editing is locked
    let isLocked: Bool

    /// Optional callback when mappings are dropped from another window
    var onDrop: (([MappingEntry]) -> Void)?

    /// Context menu callbacks
    var onCopy: (() -> Void)?
    var onPaste: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onDelete: (() -> Void)?
    var onAssignmentChange: ((TargetAssignment) -> Void)?
    var onControllerTypeChange: ((ControllerType) -> Void)?
    var onInteractionChange: ((InteractionMode) -> Void)?
    var onEncoderModeChange: ((EncoderMode) -> Void)?
    var onModifier1Change: ((ModifierCondition?) -> Void)?
    var onModifier2Change: ((ModifierCondition?) -> Void)?
    var onInvertToggle: (() -> Void)?

    /// Track the last single-clicked item for shift-selection anchor
    @State private var selectionAnchor: MappingEntry.ID?

    /// Current sort order for columns
    @State private var sortOrder = [KeyPathComparator(\MappingEntry.ioTypeSortKey)]

    /// Sorted mappings based on current sort order
    private var sortedMappings: [MappingEntry] {
        mappings.sorted(using: sortOrder)
    }

    /// Returns the valid interaction modes for the current selection
    /// If multiple items with different controller types are selected, returns the intersection
    private var validInteractionModesForSelection: [InteractionMode] {
        let selectedMappings = mappings.filter { selection.contains($0.id) }
        guard !selectedMappings.isEmpty else { return InteractionMode.allCases }

        // Get all controller types in selection
        let controllerTypes = Set(selectedMappings.map { $0.controllerType })

        // Find intersection of valid modes across all selected controller types
        var validModes = Set(InteractionMode.allCases)
        for type in controllerTypes {
            validModes = validModes.intersection(type.validInteractionModes)
        }

        // Return in a sensible order (matching allCases order)
        return InteractionMode.allCases.filter { validModes.contains($0) }
    }

    /// Returns whether the encoder mode menu should be shown (only for encoder type)
    private var showEncoderModeMenu: Bool {
        let selectedMappings = mappings.filter { selection.contains($0.id) }
        return selectedMappings.contains { $0.controllerType == .encoder }
    }

    var body: some View {
        Table(sortedMappings, selection: $selection, sortOrder: $sortOrder) {
            // Column order: I/O, Assignment, Command, Type, Interaction, MIDI, Mod 1, Mod 2

            TableColumn("I/O", value: \.ioTypeSortKey) { entry in
                    Text(entry.ioType == .input ? "IN" : "OUT")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(entry.ioType == .input ? AppThemeV2.Colors.stone400 : AppThemeV2.Colors.stone900)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(entry.ioType == .input ? AppThemeV2.Colors.stone700 : AppThemeV2.Colors.amber)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(60)

                TableColumn("Assignment", value: \.assignmentSortKey) { entry in
                    Text(entry.assignment.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 70, ideal: 90)

                TableColumn("Command", value: \.commandName) { entry in
                    Text(entry.commandName)
                        .font(.system(size: 12))
                        .foregroundColor(AppThemeV2.Colors.stone100)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 120, ideal: 180)

                TableColumn("Type", value: \.controllerTypeSortKey) { entry in
                    Text(entry.controllerType.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppThemeV2.Colors.stone300)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 60, ideal: 75)

                TableColumn("Interaction", value: \.interactionSortKey) { entry in
                    Text(entry.interactionMode.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(AppThemeV2.Colors.stone300)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 60, ideal: 80)

                TableColumn("MIDI", value: \.mappedToDisplay) { entry in
                    Text(entry.mappedToDisplay)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .width(min: 90, ideal: 110)

                TableColumn("Mod 1", value: \.modifier1SortKey) { entry in
                    Group {
                        if let mod = entry.modifier1Condition {
                            Text(mod.displayString)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppThemeV2.Colors.stone300)
                        } else {
                            Text("-")
                                .font(.system(size: 11))
                                .foregroundColor(AppThemeV2.Colors.stone600)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .width(50)

                TableColumn("Mod 2", value: \.modifier2SortKey) { entry in
                    Group {
                        if let mod = entry.modifier2Condition {
                            Text(mod.displayString)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppThemeV2.Colors.stone300)
                        } else {
                            Text("-")
                                .font(.system(size: 11))
                                .foregroundColor(AppThemeV2.Colors.stone600)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .width(50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .background(AppThemeV2.Colors.stone800)
        .introspectTableView { _ in
            // Introspection triggers amber selection proxy installation
        }
            .dropDestination(for: MappingEntry.self) { items, location in
                // Handle drop from another window
                onDrop?(items)
                return !items.isEmpty
            }
            .contextMenu {
                if !selection.isEmpty && !isLocked {
                    Button("Copy") { onCopy?() }
                        .keyboardShortcut("c", modifiers: .command)

                    Button("Paste") { onPaste?() }
                        .keyboardShortcut("v", modifiers: .command)

                    Divider()

                    Button("Duplicate") { onDuplicate?() }
                        .keyboardShortcut("d", modifiers: .command)

                    Button("Delete") { onDelete?() }
                        .keyboardShortcut(.delete, modifiers: [])

                    Divider()

                    // Assignment submenu
                    Menu("Assignment") {
                        ForEach(TargetAssignment.allCases, id: \.self) { assignment in
                            Button(assignment.displayName) {
                                onAssignmentChange?(assignment)
                            }
                        }
                    }

                    // Controller Type submenu
                    Menu("Type") {
                        ForEach(ControllerType.allCases.filter { $0 != .led }, id: \.self) { type in
                            Button(type.displayName) {
                                onControllerTypeChange?(type)
                            }
                        }
                    }

                    // Interaction submenu - only shows valid modes for selected controller type(s)
                    Menu("Interaction") {
                        ForEach(validInteractionModesForSelection, id: \.self) { mode in
                            Button(mode.displayName) {
                                onInteractionChange?(mode)
                            }
                        }
                    }

                    // Encoder Mode submenu - only shown when encoder type is selected
                    if showEncoderModeMenu {
                        Menu("Encoder Mode") {
                            ForEach(EncoderMode.allCases, id: \.self) { mode in
                                Button(mode.displayName) {
                                    onEncoderModeChange?(mode)
                                }
                            }
                        }
                    }

                    Divider()

                    // Modifier 1 submenu
                    Menu("Modifier 1") {
                        Button("None") { onModifier1Change?(nil) }
                        Divider()
                        ForEach(1...8, id: \.self) { mod in
                            Menu("M\(mod)") {
                                ForEach(0...7, id: \.self) { value in
                                    Button("= \(value)") {
                                        onModifier1Change?(ModifierCondition(modifier: mod, value: value))
                                    }
                                }
                            }
                        }
                    }

                    // Modifier 2 submenu
                    Menu("Modifier 2") {
                        Button("None") { onModifier2Change?(nil) }
                        Divider()
                        ForEach(1...8, id: \.self) { mod in
                            Menu("M\(mod)") {
                                ForEach(0...7, id: \.self) { value in
                                    Button("= \(value)") {
                                        onModifier2Change?(ModifierCondition(modifier: mod, value: value))
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button("Invert") { onInvertToggle?() }
                }
            }
        .onChange(of: selection) { oldSelection, newSelection in
            handleSelectionChange(oldSelection: oldSelection, newSelection: newSelection)
        }
    }

    /// Handles selection changes to support shift-click range selection
    private func handleSelectionChange(oldSelection: Set<MappingEntry.ID>, newSelection: Set<MappingEntry.ID>) {
        // If selection is cleared, reset anchor
        if newSelection.isEmpty {
            selectionAnchor = nil
            return
        }

        // Find what was added
        let added = newSelection.subtracting(oldSelection)

        // If exactly one item was added and shift is held, do range selection
        if added.count == 1,
           let newId = added.first,
           let anchor = selectionAnchor,
           NSEvent.modifierFlags.contains(.shift) {

            // Find indices of anchor and new selection in sorted mappings
            if let anchorIndex = sortedMappings.firstIndex(where: { $0.id == anchor }),
               let newIndex = sortedMappings.firstIndex(where: { $0.id == newId }) {

                // Select all items between anchor and new selection (inclusive)
                let startIndex = min(anchorIndex, newIndex)
                let endIndex = max(anchorIndex, newIndex)

                var rangeSelection = Set<MappingEntry.ID>()
                for index in startIndex...endIndex {
                    rangeSelection.insert(sortedMappings[index].id)
                }

                // Update selection to include the range
                selection = rangeSelection
            }
        } else if newSelection.count == 1 {
            // Single selection - update anchor
            selectionAnchor = newSelection.first
        }
    }
}

/// Preview with sample data
#Preview {
    let sampleMappings = [
        MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .toggle,
            midiChannel: 1,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Tempo Bend +",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 20
        ),
        MappingEntry(
            commandName: "Play State",
            ioType: .output,
            assignment: .deckA,
            interactionMode: .output,
            midiChannel: 1,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckB,
            interactionMode: .toggle,
            midiChannel: 2,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Master Volume",
            ioType: .input,
            assignment: .global,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 7
        )
    ]

    return MappingsTableView(
        mappings: sampleMappings,
        selection: .constant([]),
        isLocked: false
    )
    .frame(width: 800, height: 300)
    .preferredColorScheme(.dark)
}

// MARK: - Table Introspection for Custom Selection Color

/// Extension to introspect and customize NSTableView
extension View {
    func introspectTableView(customize: @escaping (NSTableView) -> Void) -> some View {
        background(TableViewFinder(customize: customize))
    }
}

/// Helper view to find and customize NSTableView with amber selection
private struct TableViewFinder: NSViewRepresentable {
    let customize: (NSTableView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let tableView = findTableView(in: view) {
                customize(tableView)
                // Install custom delegate that forwards to original
                AmberSelectionDelegateProxy.install(on: tableView)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed - delegate proxy handles everything
    }

    private func findTableView(in view: NSView) -> NSTableView? {
        var current: NSView? = view
        while let v = current {
            if let scrollView = v as? NSScrollView,
               let tableView = scrollView.documentView as? NSTableView {
                return tableView
            }
            for subview in v.subviews {
                if let found = findTableViewInHierarchy(subview) {
                    return found
                }
            }
            current = v.superview
        }
        return nil
    }

    private func findTableViewInHierarchy(_ view: NSView) -> NSTableView? {
        if let scrollView = view as? NSScrollView,
           let tableView = scrollView.documentView as? NSTableView {
            return tableView
        }
        for subview in view.subviews {
            if let found = findTableViewInHierarchy(subview) {
                return found
            }
        }
        return nil
    }
}

/// Proxy delegate that forwards all calls to original delegate while providing custom row views
private class AmberSelectionDelegateProxy: NSObject, NSTableViewDelegate {
    private weak var originalDelegate: NSTableViewDelegate?
    private static var installedTables = Set<ObjectIdentifier>()

    static func install(on tableView: NSTableView) {
        let tableId = ObjectIdentifier(tableView)
        guard !installedTables.contains(tableId) else { return }

        let proxy = AmberSelectionDelegateProxy()
        proxy.originalDelegate = tableView.delegate
        tableView.delegate = proxy

        // Store strong reference to prevent deallocation
        objc_setAssociatedObject(tableView, "amberProxy", proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        installedTables.insert(tableId)

        // Force reload after delegate swap to ensure data displays correctly
        // (delegate change can cause NSTableView to lose sync with its data source)
        tableView.reloadData()
    }

    // MARK: - Row View (our customization)

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return AmberTableRowView()
    }

    // MARK: - Forward all other delegate methods

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
}

/// Custom row view with amber selection highlight
private class AmberTableRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        if selectionHighlightStyle != .none {
            // Golden yellow selection color - more visible
            let goldColor = NSColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.35)
            goldColor.setFill()
            let selectionRect = bounds.insetBy(dx: 2, dy: 1)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
            path.fill()

            // Golden border - more prominent
            let borderColor = NSColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 0.7)
            borderColor.setStroke()
            path.lineWidth = 1
            path.stroke()
        }
    }

    override var isEmphasized: Bool {
        get { true }  // Always use emphasized (focused) appearance
        set { }
    }

    // Prevent system selection color from showing
    override var selectionHighlightStyle: NSTableView.SelectionHighlightStyle {
        get { .regular }
        set { }
    }
}
