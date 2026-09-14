//
//  SettingsPanelV2.swift
//  SuperXtremeMapping
//
//  V2 styled settings panel with custom form controls
//

import SwiftUI

/// Separates programmatic selection loading from an explicit dropdown choice.
/// Only the latter returns a mode that should be written back to the mapping.
struct EncoderModeDraft: Equatable, Sendable {
    enum Change: Equatable, Sendable {
        case selectionLoad(EncoderMode)
        case userSelection(EncoderMode)
    }

    private(set) var value: EncoderMode = .mode7Fh01h

    @discardableResult
    mutating func apply(_ change: Change) -> EncoderMode? {
        switch change {
        case .selectionLoad(let mode):
            value = mode
            return nil
        case .userSelection(let mode):
            value = mode
            return mode
        }
    }
}

/// Separates selection loading from an explicit MIDI channel edit. This keeps
/// SwiftUI state reconciliation from replacing an opaque native assignment.
struct MIDIChannelDraft: Equatable, Sendable {
    enum Change: Equatable, Sendable {
        case selectionLoad(Int)
        case userSelection(Int)
    }

    private(set) var value: Int = 1

    @discardableResult
    mutating func apply(_ change: Change) -> Int? {
        switch change {
        case .selectionLoad(let channel):
            value = channel
            return nil
        case .userSelection(let channel):
            value = channel
            return channel
        }
    }
}

struct CommentDraftState<SelectionID: Equatable> {
    var text: String = ""

    private var reconciledSelectionID: SelectionID?
    private var reconciledPersistedComment: String?
    private var hasReconciled = false

    mutating func reconcile(
        selectionID: SelectionID?,
        persistedComment: String?
    ) {
        guard !hasReconciled
                || reconciledSelectionID != selectionID
                || reconciledPersistedComment != persistedComment else { return }

        reconciledSelectionID = selectionID
        reconciledPersistedComment = persistedComment
        hasReconciled = true
        text = persistedComment ?? ""
    }
}

private struct DeviceCommentOption: Identifiable, Hashable {
    let id: Device.ID
    let label: String
}

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
    @State private var mappingCommentDraft = CommentDraftState<MappingEntry.ID>()
    @State private var batchCommentDraft: String = ""
    @State private var selectedDeviceID: Device.ID?
    @State private var deviceCommentDraft = CommentDraftState<Device.ID>()
    @State private var isDeviceCommentsExpanded: Bool = false
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
    @State private var encoderModeDraft = EncoderModeDraft()
    @State private var midiChannelDraft = MIDIChannelDraft()
    @State private var batchAssignmentKind: MIDIAssignment.Kind = .unassigned
    @State private var batchChannel: Int = 1
    @State private var batchNumber: Int = 0
    @State private var learnError: String?
    @State private var isLearning: Bool = false
    @State private var midiListeningLease: MIDIInputManager.ListeningLease?
    @State private var hasLearnedMIDI: Bool = false  // True when MIDI received during current learn session
    @State private var learnedCCValues: [Int] = []   // Track CC values to detect fader vs encoder
    @StateObject private var midiManager = MIDIInputManager.shared

    private var selectedEntry: MappingEntry? {
        guard selectedMappings.count == 1,
              let id = selectedMappings.first else { return nil }
        return document.mappingFile.allMappings.first { $0.id == id }
    }

    private var selectedEntries: [MappingEntry] {
        document.mappingFile.allMappings.filter { selectedMappings.contains($0.id) }
    }

    private var allOutputs: Bool {
        !selectedEntries.isEmpty && selectedEntries.allSatisfy { $0.ioType == .output }
    }

    private var allInputs: Bool {
        !selectedEntries.isEmpty && selectedEntries.allSatisfy { $0.ioType == .input }
    }

    private var outputDestinationContext: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            ForEach(document.mappingFile.devices.filter { device in
                device.mappings.contains { selectedMappings.contains($0.id) }
            }) { device in
                Text("\(device.name): OUT port \(device.outPort.isEmpty ? "Not set" : device.outPort)")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }
        }
    }

    private var isMultipleSelection: Bool {
        selectedMappings.count > 1
    }

    private var deviceCommentOptions: [DeviceCommentOption] {
        let names = document.mappingFile.devices.map { device in
            device.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Unnamed Device"
                : device.name
        }
        let nameCounts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        var ordinals: [String: Int] = [:]

        return zip(document.mappingFile.devices, names).map { device, name in
            ordinals[name, default: 0] += 1
            let label = nameCounts[name, default: 0] > 1
                ? "\(name) (\(ordinals[name, default: 0]))"
                : name
            return DeviceCommentOption(id: device.id, label: label)
        }
    }

    private var selectedDevice: Device? {
        guard let selectedDeviceID else { return nil }
        return document.mappingFile.devices.first { $0.id == selectedDeviceID }
    }

    private var hasActiveListeningLease: Bool {
        guard let midiListeningLease else { return false }
        return midiManager.ownsListeningLease(midiListeningLease)
    }

    private var isLearnOwnedElsewhere: Bool {
        !hasActiveListeningLease && !midiManager.isListenerIdle
    }

    private var availableInteractionModes: [InteractionMode] {
        var modes = controllerType.validInteractionModes.filter { $0 != .none }
        if !modes.contains(interactionMode) && interactionMode != .none {
            modes.append(interactionMode)
        }
        return modes.isEmpty ? [.hold] : modes  // Fallback to hold if no valid modes
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
            .frame(height: AppThemeV2.Components.sectionHeaderHeight)
            .background(AppThemeV2.Colors.stone800)

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

                    // Device Comment hidden for now.
                }
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.top, AppThemeV2.Spacing.sm)  // Less top padding to align with table headers
                .padding(.bottom, AppThemeV2.Spacing.md)
            }
            .background(AppThemeV2.Colors.stone800)
        }
        .background(AppThemeV2.Colors.stone800)
        .onChange(of: selectedMappings) { _, _ in
            stopLearning()
            resetBatchAssignmentDraft()
            batchCommentDraft = ""
        }
        .onChange(of: selectedEntry) { _, newEntry in
            loadEntryValues(newEntry)
        }
        .onChange(of: midiManager.activeListeningLease) { _, _ in
            resetLearningStateIfOwnershipWasLost()
        }
        .alert("MIDI Learn unavailable", isPresented: Binding(get: { learnError != nil }, set: { if !$0 { learnError = nil } })) {
            Button("OK", role: .cancel) { learnError = nil }
        } message: { Text(learnError ?? "") }
        .onChange(of: document.midiSourceIDs) { _, _ in stopLearning() }
        .onChange(of: document.mappingFile.devices.map { "\($0.id):\($0.inPort)" }) { _, _ in stopLearning() }
        .onChange(of: selectedDeviceID) { _, newDeviceID in
            reconcileDeviceComment(for: newDeviceID)
        }
        .onChange(of: selectedDevice?.comment) { _, _ in
            reconcileDeviceComment(for: selectedDeviceID)
        }
        .onChange(of: document.mappingFile.devices.map(\.id)) { _, _ in
            synchronizeDeviceCommentSelection()
        }
        .onAppear {
            loadEntryValues(selectedEntry)
            synchronizeDeviceCommentSelection()
        }
        .onDisappear {
            stopLearning()
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

            sectionLabel("COMMENT")
            commentEditor(
                text: $batchCommentDraft,
                placeholder: "Comment for selected mappings...",
                accessibilityLabel: "Comment for \(selectedMappings.count) selected mappings"
            )
            HStack {
                Spacer()
                V2SmallButton(
                    label: "Apply to \(selectedMappings.count)",
                    action: applyBatchComment
                )
                .disabled(isLocked)
                .accessibilityLabel(
                    "Apply comment to \(selectedMappings.count) selected mappings"
                )
            }

            V2Divider()

            sectionLabel("MIDI ASSIGNMENT")
            batchMIDIAssignmentControls

            V2Divider()

            sectionLabel("ASSIGNMENT")
            assignmentPicker

            V2Divider()

            if allOutputs {
                outputDestinationContext
                LEDOutputSettingsView(document: document, selectedIDs: selectedMappings, isLocked: isLocked)
            } else if allInputs {
                sectionLabel("TYPE")
                controllerTypePicker
                interactionModePicker
                // Invert belongs with the interaction settings, not conditions.
                invertToggle
            } else {
                Text("Select only OUT mappings for LED settings, or only IN mappings for input controls.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }

            V2Divider()

            sectionLabel("MODIFIER CONDITIONS")
            modifierControls
        }
    }

    // MARK: - Single Selection

    @ViewBuilder
    private func singleSelectionView(entry: MappingEntry) -> some View {
        // Command name (smaller than section headers, but prominent)
        Text(entry.commandName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppThemeV2.Colors.stone200)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Comment
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            sectionLabel("COMMENT")
            commentEditor(
                text: $mappingCommentDraft.text,
                placeholder: "Add a comment...",
                accessibilityLabel: "Comment for 1 selected mapping"
            )
            HStack {
                Spacer()
                V2SmallButton(label: "Save", action: saveSingleMappingComment)
                    .disabled(isLocked || mappingCommentDraft.text == entry.comment)
                    .accessibilityLabel("Save comment for 1 selected mapping")
            }
        }

        V2Divider()

        // Mapped To
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            sectionLabel("MAPPED TO")
            HStack(spacing: AppThemeV2.Spacing.xs) {
                // Text box is gold only when learning AND has received MIDI during this session
                let showGold = isLearning && hasLearnedMIDI
                Text(entry.mappedToDisplay)
                    .font(AppThemeV2.Typography.mono)
                    .foregroundColor(
                        entry.tsiCompatibilityWarning != nil
                            ? AppThemeV2.Colors.warning
                            : (showGold ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone400)
                    )
                    .padding(.horizontal, AppThemeV2.Spacing.sm)
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .fill(showGold ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone700)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .stroke(showGold ? AppThemeV2.Colors.amber.opacity(0.3) : AppThemeV2.Colors.stone600, lineWidth: 1)
                    )
                    .help(entry.tsiCompatibilityWarning?.message ?? "")

                V2SmallButton(label: "Learn", action: toggleLearnMode, isActive: isLearning)
                    .disabled(isLocked || isLearnOwnedElsewhere)
                    .accessibilityLabel(
                        isLearning ? "Stop MIDI Learn" : "Learn MIDI assignment"
                    )
            }
        }

        V2Divider()

        sectionLabel("MIDI")
        if entry.ioType == .output {
            outputDestinationContext
            batchMIDIAssignmentControls
        } else {
            midiChannelControl
        }
        assignmentPicker

        V2Divider()

        if entry.ioType == .output {
            LEDOutputSettingsView(document: document, selectedIDs: selectedMappings, isLocked: isLocked)
        } else {
            sectionLabel("CONTROLLER")
            controllerTypePicker
            interactionModePicker
            typeSpecificOptions(for: entry)
            // Invert belongs with the interaction settings, not the conditions.
            invertToggle
        }

        V2Divider()

        sectionLabel("MODIFIER CONDITIONS")
        modifierControls
    }

    // MARK: - Device Comment

    private var deviceCommentSection: some View {
        DisclosureGroup(isExpanded: $isDeviceCommentsExpanded) {
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                if deviceCommentOptions.isEmpty {
                    Text("No devices in this mapping file")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, AppThemeV2.Spacing.xs)
                        .accessibilityLabel("No devices available for comments")
                } else {
                    V2FormRow(label: "Device") {
                        Picker("Device", selection: $selectedDeviceID) {
                            ForEach(deviceCommentOptions) { option in
                                Text(option.label).tag(Optional(option.id))
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .disabled(isLocked)
                        .accessibilityLabel(
                            "Select 1 device from \(deviceCommentOptions.count) devices"
                        )
                    }

                    commentEditor(
                        text: $deviceCommentDraft.text,
                        placeholder: "Add a device comment...",
                        accessibilityLabel: "Comment for 1 selected device of \(deviceCommentOptions.count)"
                    )

                    HStack {
                        Spacer()
                        V2SmallButton(label: "Save", action: saveDeviceComment)
                            .disabled(
                                isLocked
                                    || selectedDevice == nil
                                    || deviceCommentDraft.text == selectedDevice?.comment
                            )
                            .accessibilityLabel(
                                "Save comment for 1 selected device of \(deviceCommentOptions.count)"
                            )
                    }
                }
            }
            .padding(.top, AppThemeV2.Spacing.sm)
        } label: {
            sectionLabel("DEVICE COMMENT")
        }
        .tint(AppThemeV2.Colors.stone400)
        .accessibilityLabel(
            "Device comments, \(document.mappingFile.devices.count) devices"
        )
    }

    // MARK: - Reusable Controls

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppThemeV2.Typography.micro)
            .tracking(1)
            .foregroundColor(AppThemeV2.Colors.amber)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commentEditor(
        text: Binding<String>,
        placeholder: String,
        accessibilityLabel: String
    ) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone200)
                .scrollContentBackground(.hidden)
                .padding(4)

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 72, maxHeight: 140)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(AppThemeV2.Colors.stone700)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
        )
        .disabled(isLocked)
        .accessibilityLabel(accessibilityLabel)
    }

    private var assignmentPicker: some View {
        V2FormRow(label: "Assignment") {
            V2Dropdown(
                options: TargetAssignment.allCases.filter { $0 != .none },
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
            V2NumberStepper(
                value: Binding(
                    get: { midiChannelDraft.value },
                    set: { newValue in
                        guard let editedChannel = midiChannelDraft.apply(
                            .userSelection(newValue)
                        ) else { return }
                        updateEntry { $0.midiChannel = editedChannel }
                    }
                ),
                range: 1...16,
                label: nil
            )
            .disabled(isLocked || selectedEntry?.tsiCompatibilityWarning != nil)
            .help(
                selectedEntry?.tsiCompatibilityWarning == nil
                    ? ""
                    : "Use MIDI Learn to replace this preserved native assignment."
            )
        }
    }

    private var batchMIDIAssignmentControls: some View {
        VStack(spacing: AppThemeV2.Spacing.sm) {
            V2FormRow(label: "Type") {
                V2Dropdown(
                    options: [.note, .controlChange, .unassigned],
                    selection: $batchAssignmentKind,
                    labelFor: batchAssignmentKindLabel
                )
                .disabled(isLocked)
            }

            V2FormRow(label: "Channel") {
                V2NumberStepper(value: $batchChannel, range: 1...16, label: nil)
                    .disabled(isLocked)
            }

            if batchAssignmentKind != .unassigned {
                V2FormRow(label: batchAssignmentKind == .note ? "Note" : "CC") {
                    V2NumberStepper(value: $batchNumber, range: 0...127, label: nil)
                        .disabled(isLocked)
                }
            }

            HStack(spacing: AppThemeV2.Spacing.xs) {
                Spacer()

                if isMultipleSelection {
                    V2SmallButton(
                        label: "Learn",
                        action: toggleLearnMode,
                        isActive: isLearning
                    )
                    .disabled(isLocked || isLearnOwnedElsewhere)
                    .accessibilityLabel(
                        isLearning
                            ? "Stop MIDI Learn for selected mappings"
                            : "Learn one MIDI assignment for selected mappings"
                    )
                }

                V2SmallButton(
                    label: isMultipleSelection ? "Apply to \(selectedMappings.count)" : "Apply MIDI",
                    action: applyBatchAssignmentDraft
                )
                .disabled(isLocked)
                .accessibilityLabel(
                    "Apply MIDI assignment to \(selectedMappings.count) selected mappings"
                )
            }
        }
    }

    private var controllerTypePicker: some View {
        V2FormRow(label: "Type") {
            V2Dropdown(
                options: ControllerType.allCases.filter { $0 != .led && $0 != .none },
                selection: $controllerType,
                labelFor: { $0.displayName }
            )
            .disabled(isLocked)
            .onChange(of: controllerType) { _, newValue in
                let update: (inout MappingEntry) -> Void = { mapping in
                    guard mapping.ioType == .input else { return }
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
                    updateSelectedEntries { if $0.ioType == .input { $0.interactionMode = newValue } }
                } else {
                    updateEntry { if $0.ioType == .input { $0.interactionMode = newValue } }
                }
            }
        }
    }

    private var modifierControls: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            Text("Run this mapping only when these conditions match.")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Column headers: Condition on the left, Value on the right, to
            // match the dropdown row layout below.
            HStack(spacing: AppThemeV2.Spacing.sm) {
                Text("Condition")
                Spacer()
                Text("Value")
            }
            .font(AppThemeV2.Typography.caption)
            .foregroundColor(AppThemeV2.Colors.stone500)

            modifierRow(keyPath: \.modifier1Condition, binding: $modifier1)

            // The two conditions combine with AND.
            Text("AND")
                .font(AppThemeV2.Typography.micro)
                .tracking(1)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

            modifierRow(keyPath: \.modifier2Condition, binding: $modifier2)
        }
    }

    /// Renders one condition row. For a single selection it edits the loaded
    /// value directly; for a mixed multi-selection it reports differing values
    /// as "Multiple values" and applies an explicit choice across the selection
    /// without mutating anything on display.
    @ViewBuilder
    private func modifierRow(
        keyPath: WritableKeyPath<MappingEntry, ModifierCondition?>,
        binding: Binding<ModifierCondition?>
    ) -> some View {
        if isMultipleSelection {
            let common = commonModifier(keyPath)
            V2ModifierRow(
                condition: .constant(common.value),
                isLocked: isLocked,
                isMixed: common.mixed
            ) { newCondition in
                updateSelectedEntries { $0[keyPath: keyPath] = newCondition }
            }
        } else {
            V2ModifierRow(condition: binding, isLocked: isLocked) { newCondition in
                updateEntry { $0[keyPath: keyPath] = newCondition }
            }
        }
    }

    /// The shared value across the selection, plus whether the rows differ.
    private func commonModifier(
        _ keyPath: KeyPath<MappingEntry, ModifierCondition?>
    ) -> (value: ModifierCondition?, mixed: Bool) {
        let values = selectedEntries.map { $0[keyPath: keyPath] }
        guard let first = values.first else { return (nil, false) }
        let mixed = values.dropFirst().contains { $0 != first }
        return (mixed ? nil : first, mixed)
    }

    private var invertToggle: some View {
        V2FormRow(label: "Invert") {
            V2Toggle(isOn: $invert)
                .disabled(isLocked)
                .onChange(of: invert) { _, newValue in
                    if isMultipleSelection {
                        updateSelectedEntries { if $0.ioType == .input { $0.invert = newValue } }
                    } else {
                        updateEntry { if $0.ioType == .input { $0.invert = newValue } }
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
                if entry.commandID == TraktorLoopValueMetadata.commandID {
                    Picker("Loop size", selection: Binding(
                        get: { setToValue },
                        set: { value in
                            setToValue = value
                            updateEntry { $0.setToValue = value }
                        }
                    )) {
                        ForEach(TraktorLoopValueMetadata.choices(including: setToValue)) { choice in
                            Text(choice.label).tag(choice.value)
                        }
                    }
                    .labelsHidden()
                    .disabled(isLocked)
                } else {
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
                        selection: Binding(
                            get: { encoderModeDraft.value },
                            set: { newValue in
                                guard let editedMode = encoderModeDraft.apply(
                                    .userSelection(newValue)
                                ) else { return }
                                updateEntry { $0.setEncoderMode(editedMode) }
                            }
                        ),
                        labelFor: { $0.displayName }
                    )
                    .disabled(isLocked)
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

        case .none:
            EmptyView()
        }
    }

    // MARK: - Learn Mode

    private func toggleLearnMode() {
        if isLearning {
            stopLearning()
        } else {
            startLearning()
        }
    }

    private func startLearning() {
        guard !isLocked,
              !selectedMappings.isEmpty,
              !isLearning,
              midiListeningLease == nil else { return }

        hasLearnedMIDI = false  // Reset when starting a new learn session
        learnedCCValues = []    // Reset value tracking
        guard let ownerID = MappingTransferService.destinationDeviceID(for: selectedMappings, in: document.mappingFile),
              let owner = document.mappingFile.devices.first(where: { $0.id == ownerID }) else {
            learnError = "Select mappings from one device before learning."
            return
        }
        learnError = nil
        guard let lease = midiManager.acquireListeningLease(
            desiredInputPort: owner.inPort,
            requireSpecificSource: document.mappingFile.devices.count > 1,
            desiredSourceID: document.midiSourceIDs[ownerID],
            onMIDIReceived: { [self] message in
                handleMIDILearned(message)
            }
        ) else {
            learnError = "Set a unique input port for this device and connect its controller before learning."
            return
        }

        midiListeningLease = lease
        isLearning = true
    }

    private func stopLearning() {
        guard isLearning || midiListeningLease != nil else { return }

        if let lease = midiListeningLease,
           midiManager.ownsListeningLease(lease) {
            midiManager.releaseListeningLease(lease)
        }

        midiListeningLease = nil
        resetLearningUIState()
    }

    private func resetLearningUIState() {
        isLearning = false
        hasLearnedMIDI = false  // Reset when stopping learn
        learnedCCValues = []    // Reset value tracking
    }

    private func resetLearningStateIfOwnershipWasLost() {
        guard isLearning,
              let lease = midiListeningLease,
              !midiManager.ownsListeningLease(lease) else { return }

        midiListeningLease = nil
        resetLearningUIState()
    }

    private func handleMIDILearned(_ message: MIDIMessage) {
        guard isLearning,
              let lease = midiListeningLease,
              midiManager.ownsListeningLease(lease),
              let learnedAssignment = MIDIAssignment(learnMessage: message) else {
            return
        }

        // Mark that we've received MIDI during this learn session
        hasLearnedMIDI = true

        if isMultipleSelection {
            batchAssignmentKind = learnedAssignment.kind
            batchChannel = learnedAssignment.channel
            batchNumber = learnedAssignment.number ?? 0
            applyBatchAssignment(
                learnedAssignment,
                actionName: "Learn MIDI Assignment"
            )
            stopLearning()
            return
        }

        // Track CC values for better fader vs encoder detection
        if message.cc != nil {
            learnedCCValues.append(message.value)
            // Keep only last 20 values to avoid memory buildup
            if learnedCCValues.count > 20 {
                learnedCCValues.removeFirst()
            }
        } else {
            // Reset CC tracking if we get a note (switching control types)
            learnedCCValues = []
        }

        // Detect controller type based on accumulated data
        let detectedType = detectControllerType(from: message)
        let detectedInteraction = detectedType.defaultInteractionMode

        // Single-row Learn keeps its existing controller-type inference.
        updateEntry { entry in
            entry.midiAssignment = learnedAssignment

            // Auto-assign controller type and interaction mode
            Self.applyLearnedControllerType(detectedType, to: &entry)
        }

        // Update local state to reflect changes
        midiChannelDraft.apply(.selectionLoad(message.channel))
        controllerType = selectedEntry?.controllerType ?? detectedType
        interactionMode = selectedEntry?.interactionMode ?? detectedInteraction
    }

    static func applyLearnedControllerType(_ detectedType: ControllerType, to entry: inout MappingEntry) {
        entry.controllerType = entry.ioType == .output ? .led : detectedType
        if entry.ioType == .output {
            entry.interactionMode = .output
        } else if !detectedType.validInteractionModes.contains(entry.interactionMode) {
            entry.interactionMode = detectedType.defaultInteractionMode
        }
    }

    /// Detects the controller type based on MIDI message and value history
    private func detectControllerType(from message: MIDIMessage) -> ControllerType {
        // Note messages are typically buttons
        if message.note != nil {
            return .button
        }

        // For CC messages, analyze the value history to detect fader vs encoder
        if message.cc != nil {
            // If we have enough CC values, analyze the pattern
            if learnedCCValues.count >= 2 {
                // Count how many values are in encoder zones vs middle range
                var encoderZoneCount = 0
                var middleRangeCount = 0

                for value in learnedCCValues {
                    if isEncoderValue(value) {
                        encoderZoneCount += 1
                    } else if value >= 6 && value <= 121 {
                        // Middle range values (not encoder zones) indicate fader
                        middleRangeCount += 1
                    }
                }

                // If ANY values are in the middle range, it's a fader
                // (encoders never send values like 20, 50, 80, etc.)
                if middleRangeCount > 0 {
                    return .faderOrKnob
                }

                // If all values are in encoder zones, it's an encoder
                if encoderZoneCount == learnedCCValues.count {
                    return .encoder
                }
            }

            // With limited data, check the single value
            if isEncoderValue(message.value) {
                return .encoder
            }

            return .faderOrKnob
        }

        // Default to button
        return .button
    }

    /// Check if a CC value is typical of an encoder (relative mode values)
    private func isEncoderValue(_ value: Int) -> Bool {
        // Low zone: 0-5 (relative decrement or zero)
        // High zone: 122-127 (relative increment in 7Fh/01h mode)
        // Center zone: 61-67 (relative values in 3Fh/41h mode)
        return (value >= 0 && value <= 5) ||
               (value >= 122 && value <= 127) ||
               (value >= 61 && value <= 67)
    }

    // MARK: - Helper Methods

    private func loadEntryValues(_ entry: MappingEntry?) {
        mappingCommentDraft.reconcile(
            selectionID: entry?.id,
            persistedComment: entry?.comment
        )
        guard let entry = entry else { return }
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
        encoderModeDraft.apply(.selectionLoad(entry.encoderMode))
        midiChannelDraft.apply(.selectionLoad(entry.midiChannel))
        batchAssignmentKind = entry.midiAssignment.kind
        batchChannel = entry.midiAssignment.channel
        batchNumber = entry.midiAssignment.number ?? 0
    }

    private func batchAssignmentKindLabel(_ kind: MIDIAssignment.Kind) -> String {
        switch kind {
        case .note:
            return "Note"
        case .controlChange:
            return "CC"
        case .unassigned:
            return "Unassigned"
        }
    }

    private func resetBatchAssignmentDraft() {
        batchAssignmentKind = selectedEntry?.midiAssignment.kind ?? .unassigned
        batchChannel = selectedEntry?.midiAssignment.channel ?? 1
        batchNumber = selectedEntry?.midiAssignment.number ?? 0
    }

    private func saveSingleMappingComment() {
        guard !isLocked,
              selectedMappings.count == 1,
              let selectedID = selectedMappings.first else { return }

        let savedComment = mappingCommentDraft.text
        let didSave = document.performUndoableMutation(
            actionName: "Edit Mapping Comment",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.applyComment(savedComment, to: [selectedID], in: &file)
            return true
        } ?? false

        if didSave {
            mappingCommentDraft.reconcile(
                selectionID: selectedID,
                persistedComment: savedComment
            )
        }
    }

    private func applyBatchComment() {
        guard !isLocked, isMultipleSelection else { return }

        _ = document.performUndoableMutation(
            actionName: "Apply Mapping Comment",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.applyComment(
                batchCommentDraft,
                to: selectedMappings,
                in: &file
            )
        }
    }

    private func saveDeviceComment() {
        guard !isLocked, let selectedDeviceID else { return }

        let savedComment = deviceCommentDraft.text
        let didSave = document.performUndoableMutation(
            actionName: "Edit Device Comment",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.applyDeviceComment(
                savedComment,
                to: selectedDeviceID,
                in: &file
            )
            return true
        } ?? false

        if didSave {
            deviceCommentDraft.reconcile(
                selectionID: selectedDeviceID,
                persistedComment: savedComment
            )
        }
    }

    private func synchronizeDeviceCommentSelection() {
        let deviceIDs = document.mappingFile.devices.map(\.id)
        guard !deviceIDs.isEmpty else {
            selectedDeviceID = nil
            reconcileDeviceComment(for: nil)
            return
        }

        if let selectedDeviceID, deviceIDs.contains(selectedDeviceID) {
            reconcileDeviceComment(for: selectedDeviceID)
            return
        }

        selectedDeviceID = deviceIDs[0]
        reconcileDeviceComment(for: deviceIDs[0])
    }

    private func reconcileDeviceComment(for deviceID: Device.ID?) {
        let persistedComment = document.mappingFile.devices.first(where: {
            $0.id == deviceID
        })?.comment
        deviceCommentDraft.reconcile(
            selectionID: deviceID,
            persistedComment: persistedComment
        )
    }

    private func applyBatchAssignmentDraft() {
        let assignment: MIDIAssignment?
        switch batchAssignmentKind {
        case .note:
            assignment = try? .note(channel: batchChannel, number: batchNumber)
        case .controlChange:
            assignment = try? .controlChange(channel: batchChannel, number: batchNumber)
        case .unassigned:
            assignment = try? .unassigned(channel: batchChannel)
        }

        guard let assignment else { return }
        applyBatchAssignment(assignment, actionName: "Assign MIDI")
    }

    private func applyBatchAssignment(
        _ assignment: MIDIAssignment,
        actionName: String
    ) {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        _ = document.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.apply(assignment, to: selectedMappings, in: &file)
        }
    }

    private func updateEntry(_ mutation: (inout MappingEntry) -> Void) {
        guard selectedMappings.count == 1 else { return }

        Self.updateSelectedEntries(
            selectedMappings,
            in: document,
            isLocked: isLocked,
            undoManager: undoManager,
            mutation
        )
    }

    private func updateSelectedEntries(_ mutation: (inout MappingEntry) -> Void) {
        Self.updateSelectedEntries(
            selectedMappings,
            in: document,
            isLocked: isLocked,
            undoManager: undoManager,
            mutation
        )
    }

    @MainActor
    @discardableResult
    static func updateSelectedEntries(
        _ selectedMappings: Set<MappingEntry.ID>,
        in document: TraktorMappingDocument,
        isLocked: Bool,
        undoManager: UndoManager?,
        _ mutation: (inout MappingEntry) -> Void
    ) -> Bool {
        guard !isLocked, !selectedMappings.isEmpty else { return false }

        let didChange = document.performUndoableMutation(
            actionName: "Edit Mapping Settings",
            undoManager: undoManager
        ) { file in
            for deviceIndex in file.devices.indices {
                for mappingIndex in file.devices[deviceIndex].mappings.indices {
                    let mappingID = file.devices[deviceIndex].mappings[mappingIndex].id
                    if selectedMappings.contains(mappingID) {
                        mutation(&file.devices[deviceIndex].mappings[mappingIndex])
                    }
                }
            }

            return true
        }

        return didChange ?? false
    }
}

// MARK: - Additional V2 Components

struct V2SmallButton: View {
    let label: String
    let action: () -> Void
    var isActive: Bool = false

    @State private var isHovered = false

    private var foregroundColor: Color {
        if isActive { return AppThemeV2.Colors.stone900 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone300
    }

    private var backgroundColor: Color {
        if isActive { return AppThemeV2.Colors.amber }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isActive { return AppThemeV2.Colors.amberLight }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return Color.clear
    }

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(AppThemeV2.Typography.micro)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, AppThemeV2.Spacing.sm)
                .frame(height: 24)  // Match text field height
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(borderColor, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .shadow(
            color: isActive ? AppThemeV2.Colors.amberGlow : .clear,
            radius: isActive ? 8 : 0
        )
    }
}

/// V2 styled modifier row with two dropdowns: modifier number and value

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
