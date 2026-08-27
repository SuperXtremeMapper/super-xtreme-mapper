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
    @State private var comment: String = ""
    @State private var batchCommentDraft: String = ""
    @State private var selectedDeviceID: Device.ID?
    @State private var deviceCommentDraft: String = ""
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
    @State private var midiChannel: Int = 1
    @State private var batchAssignmentKind: MIDIAssignment.Kind = .unassigned
    @State private var batchChannel: Int = 1
    @State private var batchNumber: Int = 0
    @State private var isLearning: Bool = false
    @State private var midiListeningLease: MIDIInputManager.ListeningLease?
    @State private var hasLearnedMIDI: Bool = false  // True when MIDI received during current learn session
    @State private var learnedCCValues: [Int] = []   // Track CC values to detect fader vs encoder
    @StateObject private var midiManager = MIDIInputManager.shared

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
            .padding(.vertical, AppThemeV2.Spacing.sm)
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

                    V2Divider()
                    deviceCommentSection
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
        .onChange(of: selectedDeviceID) { _, newDeviceID in
            loadDeviceComment(for: newDeviceID)
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
        // Command name (smaller than section headers, but prominent)
        Text(entry.commandName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(AppThemeV2.Colors.stone200)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Comment
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            sectionLabel("COMMENT")
            commentEditor(
                text: $comment,
                placeholder: "Add a comment...",
                accessibilityLabel: "Comment for 1 selected mapping"
            )
            HStack {
                Spacer()
                V2SmallButton(label: "Save", action: saveSingleMappingComment)
                    .disabled(isLocked || comment == entry.comment)
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
                    .foregroundColor(showGold ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone400)
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

                V2SmallButton(label: "Learn", action: toggleLearnMode, isActive: isLearning)
                    .disabled(isLocked || isLearnOwnedElsewhere)
                    .accessibilityLabel(
                        isLearning ? "Stop MIDI Learn" : "Learn MIDI assignment"
                    )
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
                        text: $deviceCommentDraft,
                        placeholder: "Add a device comment...",
                        accessibilityLabel: "Comment for 1 selected device of \(deviceCommentOptions.count)"
                    )

                    HStack {
                        Spacer()
                        V2SmallButton(label: "Save", action: saveDeviceComment)
                            .disabled(
                                isLocked
                                    || selectedDevice == nil
                                    || deviceCommentDraft == selectedDevice?.comment
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
            V2NumberStepper(value: $midiChannel, range: 1...16, label: nil)
                .disabled(isLocked)
                .onChange(of: midiChannel) { _, newValue in
                    updateEntry { $0.midiChannel = newValue }
                }
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

                V2SmallButton(
                    label: "Apply to \(selectedMappings.count)",
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
            V2ModifierRow(condition: $modifier1, isLocked: isLocked) { newCondition in
                if isMultipleSelection {
                    updateSelectedEntries { $0.modifier1Condition = newCondition }
                } else {
                    updateEntry { $0.modifier1Condition = newCondition }
                }
            }
            V2ModifierRow(condition: $modifier2, isLocked: isLocked) { newCondition in
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
        guard let lease = midiManager.acquireListeningLease(
            onMIDIReceived: { [self] message in
                handleMIDILearned(message)
            }
        ) else {
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
            entry.controllerType = detectedType
            entry.interactionMode = detectedInteraction
        }

        // Update local state to reflect changes
        midiChannel = message.channel
        controllerType = detectedType
        interactionMode = detectedInteraction
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
        encoderModeDraft.apply(.selectionLoad(entry.encoderMode))
        midiChannel = entry.midiChannel
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
        batchAssignmentKind = .unassigned
        batchChannel = 1
        batchNumber = 0
    }

    private func saveSingleMappingComment() {
        guard !isLocked,
              selectedMappings.count == 1,
              let selectedID = selectedMappings.first else { return }

        _ = document.performUndoableMutation(
            actionName: "Edit Mapping Comment",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.applyComment(comment, to: [selectedID], in: &file)
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

        _ = document.performUndoableMutation(
            actionName: "Edit Device Comment",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.applyDeviceComment(
                deviceCommentDraft,
                to: selectedDeviceID,
                in: &file
            )
        }
    }

    private func synchronizeDeviceCommentSelection() {
        let deviceIDs = document.mappingFile.devices.map(\.id)
        guard !deviceIDs.isEmpty else {
            selectedDeviceID = nil
            deviceCommentDraft = ""
            return
        }

        if let selectedDeviceID, deviceIDs.contains(selectedDeviceID) {
            return
        }

        selectedDeviceID = deviceIDs[0]
        loadDeviceComment(for: deviceIDs[0])
    }

    private func loadDeviceComment(for deviceID: Device.ID?) {
        guard let deviceID,
              let device = document.mappingFile.devices.first(where: {
                  $0.id == deviceID
              }) else {
            deviceCommentDraft = ""
            return
        }

        deviceCommentDraft = device.comment
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
        guard !isLocked, isMultipleSelection else { return }

        _ = document.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.apply(assignment, to: selectedMappings, in: &file)
        }
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
struct V2ModifierRow: View {
    @Binding var condition: ModifierCondition?
    let isLocked: Bool
    let onChanged: (ModifierCondition?) -> Void

    @State private var selectedModifier: Int = 0
    @State private var selectedValue: Int = 0

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
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
                        .frame(minWidth: 30)

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

            // Value picker (0-7) - only shown if modifier is selected
            if selectedModifier > 0 {
                Text("=")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)

                Menu {
                    ForEach(0...7, id: \.self) { val in
                        Button("\(val)") {
                            selectedValue = val
                            updateCondition()
                        }
                    }
                } label: {
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Text("\(selectedValue)")
                            .font(AppThemeV2.Typography.body)
                            .foregroundColor(AppThemeV2.Colors.stone200)
                            .frame(minWidth: 20)

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
