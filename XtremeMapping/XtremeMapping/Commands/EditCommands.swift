//
//  EditCommands.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI

/// Custom Edit menu commands for mapping operations.
///
/// Provides keyboard shortcuts and menu items for:
/// - Duplicating mappings (⌘D)
/// - Copying/pasting MIDI assignments (⌥⌘C/⌥⌘V)
/// - Copying/pasting modifier conditions (⇧⌘C/⇧⌘V)
/// - Bulk operations for changing channel, assignment, etc.
struct EditCommands: Commands {
    @Environment(\.undoManager) private var undoManager

    /// Access to the currently focused document
    @FocusedValue(\.mappingDocument) var document

    /// Access to the currently selected mappings
    @FocusedBinding(\.selectedMappingIDs) var selectedMappings

    /// Window-local edit lock published through focused scene values.
    @FocusedValue(\.mappingIsLocked) private var isLocked

    /// Observed so `.disabled(...)` re-evaluates the moment something is
    /// copied — reading `ClipboardManager.shared` directly leaves the paste
    /// items stuck disabled until the next unrelated menu rebuild.
    @ObservedObject private var clipboard = ClipboardManager.shared

    private var mutationsLocked: Bool {
        isLocked ?? false
    }

    /// Returns the valid interaction modes for the current selection
    private var validInteractionModesForSelection: [InteractionMode] {
        guard let doc = document,
              let selected = selectedMappings,
              !selected.isEmpty else { return InteractionMode.allCases }

        let selectedMappings = doc.mappingFile.allMappings.filter { selected.contains($0.id) }
        let controllerTypes = Set(selectedMappings.map { $0.controllerType })

        var validModes = Set(InteractionMode.allCases)
        for type in controllerTypes {
            validModes = validModes.intersection(type.validInteractionModes)
        }

        return InteractionMode.allCases.filter { validModes.contains($0) }
    }

    /// Returns whether any selected mapping is an encoder
    private var hasEncoderSelected: Bool {
        guard let doc = document,
              let selected = selectedMappings,
              !selected.isEmpty else { return false }

        return doc.mappingFile.allMappings.contains { mapping in
            selected.contains(mapping.id) && mapping.controllerType == .encoder
        }
    }

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()

            // Duplicate selected mappings
            Button("Duplicate") {
                duplicateSelected()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))

            Divider()

            // Copy MIDI assignment
            Button("Copy Mapped to") {
                copyMappedTo()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])
            .disabled(selectedMappings?.count != 1)

            // Paste MIDI assignment
            Button("Paste Mapped to") {
                pasteMappedTo()
            }
            .keyboardShortcut("v", modifiers: [.command, .option])
            .disabled(
                mutationsLocked
                    || (selectedMappings?.isEmpty ?? true)
                    || !clipboard.hasMappedToData
            )

            // Reset MIDI assignment
            Button("Reset Mapped to") {
                resetMappedTo()
            }
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))

            // Change Mapped to submenu
            Menu("Change Mapped to") {
                Menu("Move to MIDI Channel") {
                    ForEach(1...16, id: \.self) { channel in
                        Button("Channel \(channel)") {
                            changeMidiChannel(to: channel)
                        }
                    }
                }
            }
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))

            // Change Assignment submenu
            Menu("Change Assignment") {
                Button("Device Target") { changeAssignment(to: .deviceTarget) }
                Divider()
                Button("Global") { changeAssignment(to: .global) }
                Divider()
                Button("Deck A") { changeAssignment(to: .deckA) }
                Button("Deck B") { changeAssignment(to: .deckB) }
                Button("Deck C") { changeAssignment(to: .deckC) }
                Button("Deck D") { changeAssignment(to: .deckD) }
                Divider()
                Button("FX Unit 1") { changeAssignment(to: .fxUnit1) }
                Button("FX Unit 2") { changeAssignment(to: .fxUnit2) }
                Button("FX Unit 3") { changeAssignment(to: .fxUnit3) }
                Button("FX Unit 4") { changeAssignment(to: .fxUnit4) }
            }
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))

            // Change Controller Type submenu
            Menu("Change Type") {
                Button("Button") { changeControllerType(to: .button) }
                Button("Fader / Knob") { changeControllerType(to: .faderOrKnob) }
                Button("Encoder") { changeControllerType(to: .encoder) }
            }
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))

            // Change Interaction submenu - only shows valid modes for selected controller type(s)
            Menu("Change Interaction") {
                ForEach(validInteractionModesForSelection, id: \.self) { mode in
                    Button(mode.displayName) {
                        changeInteractionMode(to: mode)
                    }
                }
            }
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))

            // Change Encoder Mode submenu - only enabled when encoder is selected
            Menu("Change Encoder Mode") {
                ForEach(EncoderMode.allCases, id: \.self) { mode in
                    Button(mode.displayName) {
                        changeEncoderMode(to: mode)
                    }
                }
            }
            .disabled(mutationsLocked || !hasEncoderSelected)

            Divider()

            // Copy modifier conditions
            Button("Copy Modifiers") {
                copyModifiers()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(selectedMappings?.count != 1)

            // Paste modifier conditions
            Button("Paste Modifiers") {
                pasteModifiers()
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            .disabled(
                mutationsLocked
                    || (selectedMappings?.isEmpty ?? true)
                    || !clipboard.hasModifiersData
            )

            // Clear modifiers
            Button("Clear Modifiers") {
                clearModifiers()
            }
            .disabled(mutationsLocked || (selectedMappings?.isEmpty ?? true))
        }
    }

    // MARK: - Action Implementations

    private func duplicateSelected() {
        guard !mutationsLocked,
              let doc = document,
              let selected = selectedMappings,
              !selected.isEmpty else { return }

        let insertedIDs = doc.performUndoableMutation(
            actionName: "Duplicate Mappings",
            undoManager: undoManager
        ) { file in
            MappingTransferService.duplicateSelection(selected, in: &file)
        }
        if let insertedIDs {
            selectedMappings = insertedIDs
        }
    }

    private func copyMappedTo() {
        guard let doc = document,
              let selected = selectedMappings,
              selected.count == 1,
              let entry = doc.mappingFile.allMappings.first(where: { selected.contains($0.id) }) else { return }
        ClipboardManager.shared.copyMappedTo(from: entry)
    }

    private func pasteMappedTo() {
        guard !mutationsLocked,
              ClipboardManager.shared.hasMappedToData else {
            return
        }

        mutateSelectedFile(actionName: "Paste Mapped To") { selected, file in
            ClipboardManager.shared.pasteMappedTo(to: selected, in: &file)
        }
    }

    private func resetMappedTo() {
        guard let assignment = try? MIDIAssignment.unassigned(channel: 1) else {
            return
        }

        mutateSelectedFile(actionName: "Reset Mapped To") { selected, file in
            MappingBatchEditor.apply(assignment, to: selected, in: &file)
        }
    }

    private func changeMidiChannel(to channel: Int) {
        mutateSelectedFile(actionName: "Change MIDI Channel") { selected, file in
            do {
                try MappingBatchEditor.applyChannel(channel, to: selected, in: &file)
            } catch {
                assertionFailure("Invalid MIDI channel from Edit menu: \(channel)")
            }
        }
    }

    private func changeAssignment(to assignment: TargetAssignment) {
        mutateSelected(actionName: "Change Assignment") { mapping in
            mapping.assignment = assignment
        }
    }

    private func changeControllerType(to type: ControllerType) {
        mutateSelected(actionName: "Change Controller Type") { mapping in
            mapping.controllerType = type
            if !type.validInteractionModes.contains(mapping.interactionMode) {
                mapping.interactionMode = type.defaultInteractionMode
            }
        }
    }

    private func changeInteractionMode(to mode: InteractionMode) {
        mutateSelected(actionName: "Change Interaction Mode") { mapping in
            if mapping.controllerType.validInteractionModes.contains(mode) {
                mapping.interactionMode = mode
            }
        }
    }

    private func changeEncoderMode(to mode: EncoderMode) {
        mutateSelected(actionName: "Change Encoder Mode") { mapping in
            mapping.setEncoderMode(mode)
        }
    }

    private func copyModifiers() {
        guard let doc = document,
              let selected = selectedMappings,
              selected.count == 1,
              let entry = doc.mappingFile.allMappings.first(where: { selected.contains($0.id) }) else { return }
        ClipboardManager.shared.copyModifiers(from: entry)
    }

    private func pasteModifiers() {
        guard !mutationsLocked,
              ClipboardManager.shared.hasModifiersData else { return }

        mutateSelected(actionName: "Paste Modifiers") { mapping in
            ClipboardManager.shared.pasteModifiers(to: &mapping)
        }
    }

    private func clearModifiers() {
        mutateSelected(actionName: "Clear Modifiers") { mapping in
            mapping.modifier1Condition = nil
            mapping.modifier2Condition = nil
        }
    }

    private func mutateSelected(
        actionName: String,
        _ mutation: (inout MappingEntry) -> Void
    ) {
        guard !mutationsLocked,
              let doc = document,
              let selected = selectedMappings,
              !selected.isEmpty else { return }

        _ = doc.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { file in
            for deviceIndex in file.devices.indices {
                for mappingIndex in file.devices[deviceIndex].mappings.indices {
                    let mappingID = file.devices[deviceIndex].mappings[mappingIndex].id
                    if selected.contains(mappingID) {
                        mutation(&file.devices[deviceIndex].mappings[mappingIndex])
                    }
                }
            }
        }
    }

    private func mutateSelectedFile(
        actionName: String,
        _ mutation: (Set<MappingEntry.ID>, inout MappingFile) -> Void
    ) {
        guard !mutationsLocked,
              let doc = document,
              let selected = selectedMappings,
              !selected.isEmpty else { return }

        _ = doc.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { file in
            mutation(selected, &file)
        }
    }
}

// MARK: - Focused Value Keys

/// Key for accessing the focused document
struct MappingDocumentKey: FocusedValueKey {
    typealias Value = TraktorMappingDocument
}

/// Key for accessing the selected mapping IDs
struct SelectedMappingIDsKey: FocusedValueKey {
    typealias Value = Binding<Set<MappingEntry.ID>>
}

/// Key for disabling document mutations from the focused window's Edit menu.
struct MappingIsLockedKey: FocusedValueKey {
    typealias Value = Bool
}

// MARK: - FocusedValues Extension

extension FocusedValues {
    /// The currently focused mapping document
    var mappingDocument: TraktorMappingDocument? {
        get { self[MappingDocumentKey.self] }
        set { self[MappingDocumentKey.self] = newValue }
    }

    /// The currently selected mapping IDs
    var selectedMappingIDs: Binding<Set<MappingEntry.ID>>? {
        get { self[SelectedMappingIDsKey.self] }
        set { self[SelectedMappingIDsKey.self] = newValue }
    }

    /// Whether the focused mapping document currently refuses edits.
    var mappingIsLocked: Bool? {
        get { self[MappingIsLockedKey.self] }
        set { self[MappingIsLockedKey.self] = newValue }
    }
}
