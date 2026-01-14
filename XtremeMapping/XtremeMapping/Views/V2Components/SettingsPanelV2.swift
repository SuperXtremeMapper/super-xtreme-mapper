//
//  SettingsPanelV2.swift
//  SuperXtremeMapping
//
//  V2 styled settings panel with custom form controls
//

import SwiftUI

/// V2 styled settings panel
struct SettingsPanelV2: View {
    @ObservedObject var document: TraktorMappingDocument
    let selectedMappings: Set<MappingEntry.ID>
    let isLocked: Bool

    // Action callbacks
    var onDuplicate: () -> Void = {}
    var onCopyMappedTo: () -> Void = {}
    var onPasteMappedTo: () -> Void = {}
    var onCopyModifiers: () -> Void = {}
    var onPasteModifiers: () -> Void = {}

    @Environment(\.undoManager) var undoManager

    // Local state for editing
    @State private var comment: String = ""
    @State private var assignment: TargetAssignment = .global
    @State private var controllerType: ControllerType = .button
    @State private var interactionMode: InteractionMode = .hold
    @State private var modifier1: ModifierCondition?
    @State private var modifier2: ModifierCondition?
    @State private var invert: Bool = false
    @State private var softTakeover: Bool = false
    @State private var setToValue: Float = 0.0
    @State private var rotarySensitivity: Float = 1.0
    @State private var rotaryAcceleration: Float = 0.0
    @State private var encoderMode: EncoderMode = .mode7Fh01h
    @State private var midiChannel: Int = 1

    private func registerChange() {
        document.noteChange()
        undoManager?.registerUndo(withTarget: document) { doc in
            doc.noteChange()
        }
    }

    private var selectedEntry: MappingEntry? {
        guard selectedMappings.count == 1,
              let id = selectedMappings.first else { return nil }
        return document.mappingFile.allMappings.first { $0.id == id }
    }

    private var isMultipleSelection: Bool {
        selectedMappings.count > 1
    }

    private var availableInteractionModes: [InteractionMode] {
        var modes = controllerType.validInteractionModes
        if !modes.contains(interactionMode) {
            modes.append(interactionMode)
        }
        return modes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                V2SectionHeader(title: "SETTINGS")
                Spacer()
                Menu {
                    Button("Duplicate") { onDuplicate() }
                    Divider()
                    Button("Copy Mapped to") { onCopyMappedTo() }
                    Button("Paste Mapped to") { onPasteMappedTo() }
                    Divider()
                    Button("Copy Modifiers") { onCopyModifiers() }
                    Button("Paste Modifiers") { onPasteModifiers() }
                } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppThemeV2.Colors.stone400)
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, AppThemeV2.Spacing.lg)
            .padding(.vertical, AppThemeV2.Spacing.md)

            V2Divider()

            // Content
            ScrollView {
                VStack(spacing: AppThemeV2.Spacing.md) {
                    if selectedMappings.isEmpty {
                        emptySelectionView
                    } else if isMultipleSelection {
                        multipleSelectionView
                    } else if let entry = selectedEntry {
                        singleSelectionView(entry: entry)
                    }
                }
                .padding(AppThemeV2.Spacing.md)
            }
        }
        .background(AppThemeV2.Colors.stone800)
        .onChange(of: selectedEntry) { _, newEntry in
            loadEntryValues(newEntry)
        }
    }

    // MARK: - Empty Selection

    private var emptySelectionView: some View {
        VStack(spacing: AppThemeV2.Spacing.md) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 32))
                .foregroundColor(AppThemeV2.Colors.stone600)
            Text("No selection")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone500)
            Text("Select a mapping to edit")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone600)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppThemeV2.Spacing.xxl)
    }

    // MARK: - Multiple Selection

    private var multipleSelectionView: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
            // Selection count badge
            HStack {
                Text("\(selectedMappings.count) ITEMS SELECTED")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.amber)
                    .padding(.horizontal, AppThemeV2.Spacing.sm)
                    .padding(.vertical, AppThemeV2.Spacing.xs)
                    .background(
                        Capsule().fill(AppThemeV2.Colors.amberSubtle)
                    )
                Spacer()
            }

            sectionLabel("ASSIGNMENT")
            assignmentPicker

            V2Divider()

            sectionLabel("TYPE")
            controllerTypePicker
            interactionModePicker

            V2Divider()

            sectionLabel("MODIFIERS")
            modifierControls

            V2Divider()

            invertToggle
        }
    }

    // MARK: - Single Selection

    @ViewBuilder
    private func singleSelectionView(entry: MappingEntry) -> some View {
        // Command name
        Text(entry.commandName)
            .font(AppThemeV2.Typography.display)
            .foregroundColor(AppThemeV2.Colors.stone100)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Comment
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            sectionLabel("COMMENT")
            V2TextField(placeholder: "Add a comment...", text: $comment)
                .disabled(isLocked)
                .onChange(of: comment) { _, newValue in
                    updateEntry { $0.comment = newValue }
                }
        }

        V2Divider()

        // Mapped To
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            sectionLabel("MAPPED TO")
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Text(entry.mappedToDisplay)
                    .font(AppThemeV2.Typography.mono)
                    .foregroundColor(AppThemeV2.Colors.amber)
                    .padding(.horizontal, AppThemeV2.Spacing.sm)
                    .padding(.vertical, AppThemeV2.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .fill(AppThemeV2.Colors.amberSubtle)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .stroke(AppThemeV2.Colors.amber.opacity(0.3), lineWidth: 1)
                    )

                V2SmallButton(label: "Learn", action: {})
                    .disabled(isLocked)
            }
        }

        V2Divider()

        sectionLabel("MIDI")
        midiChannelControl
        assignmentPicker

        V2Divider()

        sectionLabel("CONTROLLER")
        controllerTypePicker
        interactionModePicker

        // Type-specific options
        typeSpecificOptions(for: entry)

        V2Divider()

        sectionLabel("MODIFIERS")
        modifierControls

        V2Divider()

        invertToggle
    }

    // MARK: - Reusable Controls

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppThemeV2.Typography.micro)
            .tracking(1)
            .foregroundColor(AppThemeV2.Colors.amber)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assignmentPicker: some View {
        V2FormRow(label: "Assignment") {
            V2Dropdown(
                options: TargetAssignment.allCases,
                selection: $assignment,
                labelFor: { $0.displayName }
            )
            .disabled(isLocked)
            .onChange(of: assignment) { _, newValue in
                if isMultipleSelection {
                    updateSelectedEntries { $0.assignment = newValue }
                } else {
                    updateEntry { $0.assignment = newValue }
                }
            }
        }
    }

    private var midiChannelControl: some View {
        V2FormRow(label: "Channel") {
            V2NumberStepper(value: $midiChannel, range: 1...16, label: nil)
                .disabled(isLocked)
                .onChange(of: midiChannel) { _, newValue in
                    updateEntry { $0.midiChannel = newValue }
                }
        }
    }

    private var controllerTypePicker: some View {
        V2FormRow(label: "Type") {
            V2Dropdown(
                options: ControllerType.allCases.filter { $0 != .led },
                selection: $controllerType,
                labelFor: { $0.displayName }
            )
            .disabled(isLocked)
            .onChange(of: controllerType) { _, newValue in
                let update: (inout MappingEntry) -> Void = { mapping in
                    mapping.controllerType = newValue
                    if !newValue.validInteractionModes.contains(mapping.interactionMode) {
                        mapping.interactionMode = newValue.defaultInteractionMode
                        interactionMode = newValue.defaultInteractionMode
                    }
                }
                if isMultipleSelection {
                    updateSelectedEntries(update)
                } else {
                    updateEntry(update)
                }
            }
        }
    }

    private var interactionModePicker: some View {
        V2FormRow(label: "Interaction") {
            V2Dropdown(
                options: availableInteractionModes,
                selection: $interactionMode,
                labelFor: { $0.displayName }
            )
            .disabled(isLocked)
            .onChange(of: interactionMode) { _, newValue in
                if isMultipleSelection {
                    updateSelectedEntries { $0.interactionMode = newValue }
                } else {
                    updateEntry { $0.interactionMode = newValue }
                }
            }
        }
    }

    private var modifierControls: some View {
        VStack(spacing: AppThemeV2.Spacing.sm) {
            V2ModifierRow(label: "M1", condition: $modifier1, isLocked: isLocked) { newCondition in
                if isMultipleSelection {
                    updateSelectedEntries { $0.modifier1Condition = newCondition }
                } else {
                    updateEntry { $0.modifier1Condition = newCondition }
                }
            }
            V2ModifierRow(label: "M2", condition: $modifier2, isLocked: isLocked) { newCondition in
                if isMultipleSelection {
                    updateSelectedEntries { $0.modifier2Condition = newCondition }
                } else {
                    updateEntry { $0.modifier2Condition = newCondition }
                }
            }
        }
    }

    private var invertToggle: some View {
        V2FormRow(label: "Invert") {
            V2Toggle(isOn: $invert)
                .disabled(isLocked)
                .onChange(of: invert) { _, newValue in
                    if isMultipleSelection {
                        updateSelectedEntries { $0.invert = newValue }
                    } else {
                        updateEntry { $0.invert = newValue }
                    }
                }
        }
    }

    // MARK: - Type-Specific Options

    @ViewBuilder
    private func typeSpecificOptions(for entry: MappingEntry) -> some View {
        switch controllerType {
        case .button:
            V2FormRow(label: "Set to Value") {
                V2TextField(
                    placeholder: "0.000",
                    text: Binding(
                        get: { String(format: "%.3f", setToValue) },
                        set: { setToValue = Float($0) ?? 0 }
                    )
                )
                .frame(width: 70)
                .disabled(isLocked)
                .onChange(of: setToValue) { _, newValue in
                    updateEntry { $0.setToValue = newValue }
                }
            }

        case .faderOrKnob:
            V2FormRow(label: "Soft Takeover") {
                V2Toggle(isOn: $softTakeover)
                    .disabled(isLocked)
                    .onChange(of: softTakeover) { _, newValue in
                        updateEntry { $0.softTakeover = newValue }
                    }
            }

        case .encoder:
            VStack(spacing: AppThemeV2.Spacing.sm) {
                V2FormRow(label: "Encoder Mode") {
                    V2Dropdown(
                        options: EncoderMode.allCases,
                        selection: $encoderMode,
                        labelFor: { $0.displayName }
                    )
                    .disabled(isLocked)
                    .onChange(of: encoderMode) { _, newValue in
                        updateEntry { $0.encoderMode = newValue }
                    }
                }

                V2SliderRow(
                    label: "Sensitivity",
                    value: $rotarySensitivity,
                    range: 0...3,
                    isLocked: isLocked,
                    format: { "\(Int($0 * 100))%" }
                ) { newValue in
                    updateEntry { $0.rotarySensitivity = newValue }
                }

                V2SliderRow(
                    label: "Acceleration",
                    value: $rotaryAcceleration,
                    range: 0...1,
                    isLocked: isLocked,
                    format: { "\(Int($0 * 100))%" }
                ) { newValue in
                    updateEntry { $0.rotaryAcceleration = newValue }
                }
            }

        case .led:
            EmptyView()
        }
    }

    // MARK: - Helper Methods

    private func loadEntryValues(_ entry: MappingEntry?) {
        guard let entry = entry else { return }
        comment = entry.comment
        assignment = entry.assignment
        controllerType = entry.controllerType
        interactionMode = entry.interactionMode
        modifier1 = entry.modifier1Condition
        modifier2 = entry.modifier2Condition
        invert = entry.invert
        softTakeover = entry.softTakeover
        setToValue = entry.setToValue
        rotarySensitivity = entry.rotarySensitivity
        rotaryAcceleration = entry.rotaryAcceleration
        encoderMode = entry.encoderMode
        midiChannel = entry.midiChannel
    }

    private func updateEntry(_ mutation: (inout MappingEntry) -> Void) {
        guard let selectedId = selectedMappings.first,
              selectedMappings.count == 1 else { return }

        registerChange()

        for deviceIndex in document.mappingFile.devices.indices {
            if let mappingIndex = document.mappingFile.devices[deviceIndex].mappings.firstIndex(where: { $0.id == selectedId }) {
                mutation(&document.mappingFile.devices[deviceIndex].mappings[mappingIndex])
                return
            }
        }
    }

    private func updateSelectedEntries(_ mutation: (inout MappingEntry) -> Void) {
        guard !selectedMappings.isEmpty else { return }

        registerChange()

        for deviceIndex in document.mappingFile.devices.indices {
            for mappingIndex in document.mappingFile.devices[deviceIndex].mappings.indices {
                let mappingId = document.mappingFile.devices[deviceIndex].mappings[mappingIndex].id
                if selectedMappings.contains(mappingId) {
                    mutation(&document.mappingFile.devices[deviceIndex].mappings[mappingIndex])
                }
            }
        }
    }
}

// MARK: - Additional V2 Components

struct V2SmallButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(AppThemeV2.Typography.micro)
                .foregroundColor(AppThemeV2.Colors.stone300)
                .padding(.horizontal, AppThemeV2.Spacing.sm)
                .padding(.vertical, AppThemeV2.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(AppThemeV2.Colors.stone700)
                )
        }
        .buttonStyle(.plain)
    }
}

/// V2 styled modifier row with picker for M1-M8 and stepper for values 0-7
struct V2ModifierRow: View {
    let label: String
    @Binding var condition: ModifierCondition?
    let isLocked: Bool
    let onChanged: (ModifierCondition?) -> Void

    @State private var selectedModifier: Int = 0
    @State private var selectedValue: Int = 0

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            // Label
            Text(label)
                .font(AppThemeV2.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(AppThemeV2.Colors.amber)
                .frame(width: 24)

            // Modifier picker (None, M1-M8)
            Menu {
                Button("-") {
                    selectedModifier = 0
                    updateCondition()
                }
                ForEach(1...8, id: \.self) { num in
                    Button("M\(num)") {
                        selectedModifier = num
                        updateCondition()
                    }
                }
            } label: {
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Text(selectedModifier == 0 ? "-" : "M\(selectedModifier)")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone200)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(AppThemeV2.Colors.stone500)
                }
                .padding(.horizontal, AppThemeV2.Spacing.sm)
                .padding(.vertical, AppThemeV2.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(AppThemeV2.Colors.stone700)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(isLocked)

            // Value display and stepper (only if modifier selected)
            if selectedModifier > 0 {
                HStack(spacing: AppThemeV2.Spacing.xxs) {
                    Text("=")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)

                    V2NumberStepper(
                        value: $selectedValue,
                        range: 0...7,
                        label: nil
                    )
                    .disabled(isLocked)
                    .onChange(of: selectedValue) { _, _ in
                        updateCondition()
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            loadFromCondition()
        }
        .onChange(of: condition) { _, _ in
            loadFromCondition()
        }
    }

    private func loadFromCondition() {
        if let cond = condition {
            selectedModifier = cond.modifier
            selectedValue = cond.value
        } else {
            selectedModifier = 0
            selectedValue = 0
        }
    }

    private func updateCondition() {
        let newCondition: ModifierCondition?
        if selectedModifier == 0 {
            newCondition = nil
        } else {
            newCondition = ModifierCondition(modifier: selectedModifier, value: selectedValue)
        }

        if condition != newCondition {
            condition = newCondition
            onChanged(newCondition)
        }
    }
}

struct V2SliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let isLocked: Bool
    let format: (Float) -> String
    let onChanged: (Float) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            HStack {
                Text(label)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                Spacer()
                Text(format(value))
                    .font(AppThemeV2.Typography.mono)
                    .foregroundColor(AppThemeV2.Colors.stone300)
            }

            Slider(value: $value, in: range)
                .tint(AppThemeV2.Colors.amber)
                .disabled(isLocked)
                .onChange(of: value) { _, newValue in
                    onChanged(newValue)
                }
        }
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                .fill(AppThemeV2.Colors.stone800.opacity(0.5))
        )
    }
}

#Preview {
    SettingsPanelV2(
        document: TraktorMappingDocument(),
        selectedMappings: [],
        isLocked: false
    )
    .frame(width: 280, height: 600)
    .preferredColorScheme(.dark)
}
