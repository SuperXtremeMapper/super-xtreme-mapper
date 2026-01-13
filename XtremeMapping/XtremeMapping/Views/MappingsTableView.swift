//
//  MappingsTableView.swift
//  XXtremeMapping
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
    @State private var sortOrder = [KeyPathComparator(\MappingEntry.commandName)]

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
            TableColumn("Command", value: \.commandName) { entry in
                Text(entry.commandName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .width(min: 100, ideal: 150)

            TableColumn("I/O", value: \.ioTypeSortKey) { entry in
                Text(entry.ioType == .input ? "In" : "Out")
                    .foregroundColor(entry.ioType == .input ? AppTheme.inputColor : AppTheme.outputColor)
                    .fontWeight(entry.ioType == .output ? .medium : .regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .width(35)

            TableColumn("Assignment", value: \.assignmentSortKey) { entry in
                Text(entry.assignment.displayName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .width(min: 60, ideal: 80)

            TableColumn("Type", value: \.controllerTypeSortKey) { entry in
                Text(entry.controllerType.displayName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .width(min: 60, ideal: 80)

            TableColumn("Interaction", value: \.interactionSortKey) { entry in
                Text(entry.interactionMode.displayName)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .width(min: 50, ideal: 70)

            TableColumn("Mapped to", value: \.mappedToDisplay) { entry in
                Text(entry.mappedToDisplay)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .width(min: 90, ideal: 110)

            TableColumn("Mod. 1", value: \.modifier1SortKey) { entry in
                Group {
                    if let mod = entry.modifier1Condition {
                        Text(mod.displayString)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("-")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .width(55)

            TableColumn("Mod. 2", value: \.modifier2SortKey) { entry in
                Group {
                    if let mod = entry.modifier2Condition {
                        Text(mod.displayString)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("-")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .width(55)
        }
        .tableStyle(.bordered)
        .alternatingRowBackgrounds(.enabled)
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
            commandName: "Filter",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 8
        ),
        MappingEntry(
            commandName: "Filter On",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .toggle,
            midiChannel: 1,
            midiNote: 36,
            modifier1Condition: ModifierCondition(modifier: 1, value: 0)
        ),
        MappingEntry(
            commandName: "Key On",
            ioType: .output,
            assignment: .deckB,
            interactionMode: .output,
            midiChannel: 2,
            midiNote: 48,
            modifier1Condition: ModifierCondition(modifier: 2, value: 1),
            modifier2Condition: ModifierCondition(modifier: 3, value: 2)
        )
    ]

    return MappingsTableView(
        mappings: sampleMappings,
        selection: .constant([]),
        isLocked: false
    )
    .frame(width: 700, height: 300)
}
