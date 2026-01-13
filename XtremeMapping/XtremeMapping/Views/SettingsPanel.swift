//
//  SettingsPanel.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine

/// A panel displaying editable settings for selected mapping entries.
///
/// Shows different content based on selection state:
/// - No selection: "No selection" placeholder
/// - Multiple selection: Count of selected items
/// - Single selection: Full editable form with all mapping properties
struct SettingsPanel: View {
    /// The document containing all mappings
    @ObservedObject var document: TraktorMappingDocument

    /// The set of currently selected mapping IDs
    let selectedMappings: Set<MappingEntry.ID>

    /// Whether editing is locked
    let isLocked: Bool

    @Environment(\.undoManager) var undoManager

    /// Registers a change with the undo manager to mark document as edited
    private func registerChange() {
        undoManager?.registerUndo(withTarget: document) { doc in
            doc.objectWillChange.send()
        }
    }

    // Local state for editing
    @State private var comment: String = ""
    @State private var assignment: TargetAssignment = .global
    @State private var controllerType: ControllerType = .button
    @State private var interactionMode: InteractionMode = .hold
    @State private var modifier1: ModifierCondition?
    @State private var modifier2: ModifierCondition?
    @State private var invert: Bool = false

    // Type-specific options
    @State private var softTakeover: Bool = false
    @State private var setToValue: Float = 0.0
    @State private var rotarySensitivity: Float = 1.0
    @State private var rotaryAcceleration: Float = 0.0
    @State private var encoderMode: EncoderMode = .mode7Fh01h

    /// Returns the single selected entry if exactly one is selected
    private var selectedEntry: MappingEntry? {
        guard selectedMappings.count == 1,
              let id = selectedMappings.first else { return nil }
        return document.mappingFile.allMappings.first { $0.id == id }
    }

    /// Whether multiple items are selected
    private var isMultipleSelection: Bool {
        selectedMappings.count > 1
    }

    /// Returns valid interaction modes for the current controller type,
    /// always including the current selection to prevent picker errors
    private var availableInteractionModes: [InteractionMode] {
        var modes = controllerType.validInteractionModes
        // Always include current selection to prevent "invalid selection" errors
        if !modes.contains(interactionMode) {
            modes.append(interactionMode)
        }
        return modes
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if selectedMappings.isEmpty {
                    emptySelectionView
                } else if isMultipleSelection {
                    multipleSelectionView
                } else if let entry = selectedEntry {
                    singleSelectionView(entry: entry)
                }

                Spacer()
            }
            .padding()
        }
        .onChange(of: selectedEntry) { _, newEntry in
            loadEntryValues(newEntry)
        }
    }

    // MARK: - View States

    /// View shown when no mappings are selected
    private var emptySelectionView: some View {
        Text("No selection")
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 40)
    }

    /// View shown when multiple mappings are selected - allows batch editing
    private var multipleSelectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(selectedMappings.count) items selected")
                .font(.headline)

            Divider()
                .background(AppTheme.dividerColor)

            // Assignment picker for batch edit
            VStack(alignment: .leading, spacing: 4) {
                Text("Assignment")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $assignment) {
                    ForEach(TargetAssignment.allCases, id: \.self) { target in
                        Text(target.displayName).tag(target)
                    }
                }
                .labelsHidden()
                .disabled(isLocked)
                .onChange(of: assignment) { _, newValue in
                    updateSelectedEntries { $0.assignment = newValue }
                }
            }

            Divider()
                .background(AppTheme.dividerColor)

            // Modifiers section for batch edit
            VStack(alignment: .leading, spacing: 8) {
                Text("Modifiers")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ModifierRow(
                    condition: $modifier1,
                    isLocked: isLocked,
                    onChanged: { newCondition in
                        updateSelectedEntries { $0.modifier1Condition = newCondition }
                    }
                )

                ModifierRow(
                    condition: $modifier2,
                    isLocked: isLocked,
                    onChanged: { newCondition in
                        updateSelectedEntries { $0.modifier2Condition = newCondition }
                    }
                )
            }

            Divider()
                .background(AppTheme.dividerColor)

            // Controller Type for batch edit
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type of Controller")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $controllerType) {
                        ForEach(ControllerType.allCases.filter { $0 != .led }, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .labelsHidden()
                    .disabled(isLocked)
                    .onChange(of: controllerType) { _, newValue in
                        updateSelectedEntries { mapping in
                            mapping.controllerType = newValue
                            if !newValue.validInteractionModes.contains(mapping.interactionMode) {
                                mapping.interactionMode = newValue.defaultInteractionMode
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Interaction Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("", selection: $interactionMode) {
                        ForEach(availableInteractionModes, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .disabled(isLocked)
                    .onChange(of: interactionMode) { _, newValue in
                        updateSelectedEntries { $0.interactionMode = newValue }
                    }
                }
            }

            Divider()
                .background(AppTheme.dividerColor)

            // Invert toggle for batch edit
            Toggle("Invert", isOn: $invert)
                .disabled(isLocked)
                .onChange(of: invert) { _, newValue in
                    updateSelectedEntries { $0.invert = newValue }
                }
        }
    }

    /// View shown when a single mapping is selected
    @ViewBuilder
    private func singleSelectionView(entry: MappingEntry) -> some View {
        // Command name display
        Text(entry.commandName)
            .font(.headline)

        Divider()
            .background(AppTheme.dividerColor)

        // Comment field
        VStack(alignment: .leading, spacing: 4) {
            Text("Comment")
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("", text: $comment)
                .textFieldStyle(.roundedBorder)
                .disabled(isLocked)
                .onChange(of: comment) { _, newValue in
                    updateEntry { $0.comment = newValue }
                }
        }

        Divider()
            .background(AppTheme.dividerColor)

        // Mapped to section
        VStack(alignment: .leading, spacing: 4) {
            Text("Mapped to")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text(entry.mappedToDisplay)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(5)

                Button("Learn") {
                    // TODO: MIDI learn functionality
                }
                .disabled(isLocked)

                Button("Reset") {
                    resetMappedTo()
                }
                .disabled(isLocked)
            }
        }

        // Assignment picker
        VStack(alignment: .leading, spacing: 4) {
            Text("Assignment")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("", selection: $assignment) {
                ForEach(TargetAssignment.allCases, id: \.self) { target in
                    Text(target.displayName).tag(target)
                }
            }
            .labelsHidden()
            .disabled(isLocked)
            .onChange(of: assignment) { _, newValue in
                updateEntry { $0.assignment = newValue }
            }
        }

        Divider()
            .background(AppTheme.dividerColor)

        // Modifiers section
        VStack(alignment: .leading, spacing: 8) {
            Text("Modifiers")
                .font(.caption)
                .foregroundColor(.secondary)

            ModifierRow(
                condition: $modifier1,
                isLocked: isLocked,
                onChanged: { newCondition in
                    updateEntry { $0.modifier1Condition = newCondition }
                }
            )

            ModifierRow(
                condition: $modifier2,
                isLocked: isLocked,
                onChanged: { newCondition in
                    updateEntry { $0.modifier2Condition = newCondition }
                }
            )
        }

        Divider()
            .background(AppTheme.dividerColor)

        // Controller Type section
        VStack(alignment: .leading, spacing: 8) {
            // Type of Controller picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Type of Controller")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $controllerType) {
                    ForEach(ControllerType.allCases.filter { $0 != .led }, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .labelsHidden()
                .disabled(isLocked)
                .onChange(of: controllerType) { _, newValue in
                    updateEntry { mapping in
                        mapping.controllerType = newValue
                        // Reset interaction mode if current mode is invalid for new type
                        if !newValue.validInteractionModes.contains(mapping.interactionMode) {
                            mapping.interactionMode = newValue.defaultInteractionMode
                            interactionMode = newValue.defaultInteractionMode
                        }
                    }
                }
            }

            // Interaction Mode picker (filtered by controller type)
            VStack(alignment: .leading, spacing: 4) {
                Text("Interaction Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $interactionMode) {
                    ForEach(availableInteractionModes, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .disabled(isLocked)
                .onChange(of: interactionMode) { _, newValue in
                    updateEntry { $0.interactionMode = newValue }
                }
            }

        }

        Divider()
            .background(AppTheme.dividerColor)

        // Type-specific options section
        typeSpecificOptionsView(entry: entry)

        // Invert toggle
        Toggle("Invert", isOn: $invert)
            .disabled(isLocked)
            .onChange(of: invert) { _, newValue in
                updateEntry { $0.invert = newValue }
            }
    }

    // MARK: - Type-Specific Options

    @ViewBuilder
    private func typeSpecificOptionsView(entry: MappingEntry) -> some View {
        switch controllerType {
        case .button:
            buttonOptionsView

        case .faderOrKnob:
            faderKnobOptionsView

        case .encoder:
            encoderOptionsView

        case .led:
            EmptyView()
        }
    }

    /// Options for Button controller type
    private var buttonOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Button Options")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                Text("Set to value")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                TextField("", value: $setToValue, format: .number.precision(.fractionLength(3)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .disabled(isLocked)
                    .onChange(of: setToValue) { _, newValue in
                        updateEntry { $0.setToValue = newValue }
                    }
            }
        }
    }

    /// Options for Fader/Knob controller type
    private var faderKnobOptionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fader / Knob")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Toggle("Soft Takeover", isOn: $softTakeover)
                .disabled(isLocked)
                .onChange(of: softTakeover) { _, newValue in
                    updateEntry { $0.softTakeover = newValue }
                }
        }
    }

    /// Options for Encoder controller type
    private var encoderOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rotary Encoder")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Encoder Mode picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Encoder Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $encoderMode) {
                    ForEach(EncoderMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .disabled(isLocked)
                .onChange(of: encoderMode) { _, newValue in
                    updateEntry { $0.encoderMode = newValue }
                }
            }

            // Rotary Sensitivity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Rotary Sensitivity")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(rotarySensitivity * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                Slider(value: $rotarySensitivity, in: 0...3, step: 0.01)
                    .controlSize(.small)
                    .disabled(isLocked)
                    .onChange(of: rotarySensitivity) { _, newValue in
                        updateEntry { $0.rotarySensitivity = newValue }
                    }
            }

            // Rotary Acceleration slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Rotary Acceleration")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(rotaryAcceleration * 100))%")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                Slider(value: $rotaryAcceleration, in: 0...1, step: 0.01)
                    .controlSize(.small)
                    .disabled(isLocked)
                    .onChange(of: rotaryAcceleration) { _, newValue in
                        updateEntry { $0.rotaryAcceleration = newValue }
                    }
            }
        }
    }

    // MARK: - Helper Methods

    /// Loads values from a mapping entry into local state
    private func loadEntryValues(_ entry: MappingEntry?) {
        guard let entry = entry else { return }
        comment = entry.comment
        assignment = entry.assignment
        controllerType = entry.controllerType
        interactionMode = entry.interactionMode
        modifier1 = entry.modifier1Condition
        modifier2 = entry.modifier2Condition
        invert = entry.invert

        // Type-specific options
        softTakeover = entry.softTakeover
        setToValue = entry.setToValue
        rotarySensitivity = entry.rotarySensitivity
        rotaryAcceleration = entry.rotaryAcceleration
        encoderMode = entry.encoderMode
    }

    /// Updates the selected entry with the given mutation (single selection only)
    private func updateEntry(_ mutation: (inout MappingEntry) -> Void) {
        guard let selectedId = selectedMappings.first,
              selectedMappings.count == 1 else { return }

        registerChange()

        // Find and update the entry in the document
        for deviceIndex in document.mappingFile.devices.indices {
            if let mappingIndex = document.mappingFile.devices[deviceIndex].mappings.firstIndex(where: { $0.id == selectedId }) {
                mutation(&document.mappingFile.devices[deviceIndex].mappings[mappingIndex])
                return
            }
        }
    }

    /// Updates all selected entries with the given mutation (batch editing)
    private func updateSelectedEntries(_ mutation: (inout MappingEntry) -> Void) {
        guard !selectedMappings.isEmpty else { return }

        registerChange()

        // Update all selected entries
        for deviceIndex in document.mappingFile.devices.indices {
            for mappingIndex in document.mappingFile.devices[deviceIndex].mappings.indices {
                let mappingId = document.mappingFile.devices[deviceIndex].mappings[mappingIndex].id
                if selectedMappings.contains(mappingId) {
                    mutation(&document.mappingFile.devices[deviceIndex].mappings[mappingIndex])
                }
            }
        }
    }

    /// Resets the MIDI assignment to default values
    private func resetMappedTo() {
        updateEntry { entry in
            entry.midiNote = nil
            entry.midiCC = nil
            entry.midiChannel = 1
        }
    }
}

#Preview {
    let doc = TraktorMappingDocument(
        mappingFile: MappingFile(
            devices: [
                Device(
                    name: "Generic MIDI",
                    mappings: [
                        MappingEntry(
                            commandName: "Filter",
                            ioType: .input,
                            assignment: .deckA,
                            interactionMode: .direct,
                            midiChannel: 1,
                            midiCC: 8,
                            comment: "Low-pass filter"
                        )
                    ]
                )
            ]
        )
    )

    SettingsPanel(
        document: doc,
        selectedMappings: [doc.mappingFile.devices[0].mappings[0].id],
        isLocked: false
    )
    .frame(width: 280, height: 500)
}
