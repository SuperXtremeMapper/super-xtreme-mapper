//
//  EditCommands.swift
//  XXtremeMapping
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
    /// Access to the currently focused document
    @FocusedValue(\.mappingDocument) var document

    /// Access to the currently selected mappings
    @FocusedBinding(\.selectedMappingIDs) var selectedMappings

    /// Clipboard for MIDI assignment (mapped to) data
    @FocusedValue(\.mappedToClipboard) var mappedToClipboard

    /// Clipboard for modifier conditions
    @FocusedValue(\.modifiersClipboard) var modifiersClipboard

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
            .disabled(selectedMappings?.isEmpty ?? true)

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
            .disabled(selectedMappings?.isEmpty ?? true || mappedToClipboard == nil)

            // Reset MIDI assignment
            Button("Reset Mapped to") {
                resetMappedTo()
            }
            .disabled(selectedMappings?.isEmpty ?? true)

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
            .disabled(selectedMappings?.isEmpty ?? true)

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
            .disabled(selectedMappings?.isEmpty ?? true)

            // Change Controller Type submenu
            Menu("Change Type") {
                Button("Button") { changeControllerType(to: .button) }
                Button("Fader / Knob") { changeControllerType(to: .faderOrKnob) }
                Button("Encoder") { changeControllerType(to: .encoder) }
            }
            .disabled(selectedMappings?.isEmpty ?? true)

            // Change Interaction submenu - only shows valid modes for selected controller type(s)
            Menu("Change Interaction") {
                ForEach(validInteractionModesForSelection, id: \.self) { mode in
                    Button(mode.displayName) {
                        changeInteractionMode(to: mode)
                    }
                }
            }
            .disabled(selectedMappings?.isEmpty ?? true)

            // Change Encoder Mode submenu - only enabled when encoder is selected
            Menu("Change Encoder Mode") {
                ForEach(EncoderMode.allCases, id: \.self) { mode in
                    Button(mode.displayName) {
                        changeEncoderMode(to: mode)
                    }
                }
            }
            .disabled(!hasEncoderSelected)

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
            .disabled(selectedMappings?.isEmpty ?? true || modifiersClipboard == nil)

            // Clear modifiers
            Button("Clear Modifiers") {
                clearModifiers()
            }
            .disabled(selectedMappings?.isEmpty ?? true)
        }
    }

    // MARK: - Action Implementations

    private func duplicateSelected() {
        guard let doc = document,
              let selected = selectedMappings,
              !selected.isEmpty else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            let device = doc.mappingFile.devices[deviceIndex]
            let toDuplicate = device.mappings.filter { selected.contains($0.id) }

            for mapping in toDuplicate {
                let duplicate = MappingEntry(
                    commandName: mapping.commandName,
                    ioType: mapping.ioType,
                    assignment: mapping.assignment,
                    interactionMode: mapping.interactionMode,
                    midiChannel: mapping.midiChannel,
                    midiNote: mapping.midiNote,
                    midiCC: mapping.midiCC,
                    modifier1Condition: mapping.modifier1Condition,
                    modifier2Condition: mapping.modifier2Condition,
                    comment: mapping.comment,
                    controllerType: mapping.controllerType,
                    invert: mapping.invert
                )
                doc.mappingFile.devices[deviceIndex].mappings.append(duplicate)
            }
        }
    }

    private func copyMappedTo() {
        // TODO: Implement with AppStorage or custom clipboard
    }

    private func pasteMappedTo() {
        // TODO: Implement with AppStorage or custom clipboard
    }

    private func resetMappedTo() {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].midiNote = nil
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].midiCC = nil
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].midiChannel = 1
                }
            }
        }
    }

    private func changeMidiChannel(to channel: Int) {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].midiChannel = channel
                }
            }
        }
    }

    private func changeAssignment(to assignment: TargetAssignment) {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].assignment = assignment
                }
            }
        }
    }

    private func changeControllerType(to type: ControllerType) {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].controllerType = type
                    // Reset interaction mode if current mode is invalid for new type
                    let currentMode = doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].interactionMode
                    if !type.validInteractionModes.contains(currentMode) {
                        doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].interactionMode = type.defaultInteractionMode
                    }
                }
            }
        }
    }

    private func changeInteractionMode(to mode: InteractionMode) {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    // Only change if the mode is valid for this controller type
                    let controllerType = doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].controllerType
                    if controllerType.validInteractionModes.contains(mode) {
                        doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].interactionMode = mode
                    }
                }
            }
        }
    }

    private func changeEncoderMode(to mode: EncoderMode) {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].encoderMode = mode
                }
            }
        }
    }

    private func copyModifiers() {
        // TODO: Implement with AppStorage or custom clipboard
    }

    private func pasteModifiers() {
        // TODO: Implement with AppStorage or custom clipboard
    }

    private func clearModifiers() {
        guard let doc = document,
              let selected = selectedMappings else { return }

        doc.noteChange()

        for deviceIndex in doc.mappingFile.devices.indices {
            for mappingIndex in doc.mappingFile.devices[deviceIndex].mappings.indices {
                if selected.contains(doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].id) {
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].modifier1Condition = nil
                    doc.mappingFile.devices[deviceIndex].mappings[mappingIndex].modifier2Condition = nil
                }
            }
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

/// Key for the mapped to clipboard (MIDI channel, note, CC)
struct MappedToClipboardKey: FocusedValueKey {
    typealias Value = MappedToClipboardData
}

/// Key for the modifiers clipboard
struct ModifiersClipboardKey: FocusedValueKey {
    typealias Value = ModifiersClipboardData
}

/// Data structure for copied MIDI assignment
struct MappedToClipboardData {
    var midiChannel: Int
    var midiNote: Int?
    var midiCC: Int?
}

/// Data structure for copied modifier conditions
struct ModifiersClipboardData {
    var modifier1: ModifierCondition?
    var modifier2: ModifierCondition?
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

    /// Clipboard data for mapped to (MIDI assignment)
    var mappedToClipboard: MappedToClipboardData? {
        get { self[MappedToClipboardKey.self] }
        set { self[MappedToClipboardKey.self] = newValue }
    }

    /// Clipboard data for modifier conditions
    var modifiersClipboard: ModifiersClipboardData? {
        get { self[ModifiersClipboardKey.self] }
        set { self[ModifiersClipboardKey.self] = newValue }
    }
}
