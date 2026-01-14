//
//  ContentView.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var document: TraktorMappingDocument
    let fileURL: URL?
    @Environment(\.undoManager) var undoManager
    @State private var selectedMappings: Set<MappingEntry.ID> = []
    @State private var categoryFilter: CommandCategory = .all
    @State private var ioFilter: IODirection = .all
    @State private var isLocked: Bool = false
    @State private var clipboard: [MappingEntry] = []
    @State private var searchText: String = ""

    /// Registers a change with the undo manager to mark document as edited
    private func registerChange() {
        document.noteChange()
        undoManager?.registerUndo(withTarget: document) { doc in
            // Undo action - we don't fully implement undo, just mark as changed
            doc.noteChange()
        }
    }

    var filteredMappings: [MappingEntry] {
        document.mappingFile.allMappings.filter { entry in
            let categoryMatch = CommandCategoryMatcher.matches(entry, category: categoryFilter)
            let ioMatch = ioFilter == .all || entry.ioType == ioFilter
            let searchMatch = searchText.isEmpty || entry.commandName.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && ioMatch && searchMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // V2 Action bar
            V2ActionBarFull(
                document: document,
                isLocked: $isLocked,
                categoryFilter: $categoryFilter,
                ioFilter: $ioFilter,
                searchText: $searchText,
                onAddInput: addInputMapping,
                onAddOutput: addOutputMapping,
                onAddInOut: addInOutPair
            )

            // Main content
            HSplitView {
                // Left: Mappings Table
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        V2SectionHeader(title: "MAPPINGS")
                        Spacer()
                        Text("\(filteredMappings.count) items")
                            .font(AppThemeV2.Typography.caption)
                            .foregroundColor(AppThemeV2.Colors.stone500)
                    }
                    .padding(.horizontal, AppThemeV2.Spacing.lg)
                    .padding(.vertical, AppThemeV2.Spacing.md)

                    V2Divider()

                    // Mappings table
                    MappingsTableView(
                        mappings: filteredMappings,
                        selection: $selectedMappings,
                        isLocked: isLocked,
                        onDrop: { droppedMappings in
                            handleDroppedMappings(droppedMappings)
                        },
                        onCopy: copySelectedMappings,
                        onPaste: pasteSelectedMappings,
                        onDuplicate: duplicateSelected,
                        onDelete: deleteSelectedMappings,
                        onAssignmentChange: { assignment in
                            updateSelectedMappings { $0.assignment = assignment }
                        },
                        onControllerTypeChange: { type in
                            updateSelectedMappings { mapping in
                                mapping.controllerType = type
                                // Reset interaction mode to default for new type if current mode is invalid
                                if !type.validInteractionModes.contains(mapping.interactionMode) {
                                    mapping.interactionMode = type.defaultInteractionMode
                                }
                            }
                        },
                        onInteractionChange: { mode in
                            updateSelectedMappings { $0.interactionMode = mode }
                        },
                        onEncoderModeChange: { mode in
                            updateSelectedMappings { $0.encoderMode = mode }
                        },
                        onModifier1Change: { condition in
                            updateSelectedMappings { $0.modifier1Condition = condition }
                        },
                        onModifier2Change: { condition in
                            updateSelectedMappings { $0.modifier2Condition = condition }
                        },
                        onInvertToggle: {
                            updateSelectedMappings { $0.invert.toggle() }
                        }
                    )
                }
                .frame(minWidth: 500)
                .background(AppThemeV2.Colors.stone900)

                // Divider
                Rectangle()
                    .fill(AppThemeV2.Colors.stone700)
                    .frame(width: 1)

                // Right: Settings Panel
                SettingsPanelV2(
                    document: document,
                    selectedMappings: selectedMappings,
                    isLocked: isLocked,
                    onDuplicate: duplicateSelected,
                    onCopyMappedTo: copyMappedTo,
                    onPasteMappedTo: pasteMappedTo,
                    onCopyModifiers: copyModifiers,
                    onPasteModifiers: pasteModifiers
                )
                .frame(minWidth: 260, maxWidth: 300)
            }

            // V2 Status bar
            HStack(spacing: AppThemeV2.Spacing.sm) {
                Circle()
                    .fill(AppThemeV2.Colors.amber)
                    .frame(width: 6, height: 6)
                Text("BETA: Always backup your mappings before making changes")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.amber)
                Spacer()
                if !selectedMappings.isEmpty {
                    Text("\(selectedMappings.count) selected")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                }
            }
            .padding(.horizontal, AppThemeV2.Spacing.lg)
            .padding(.vertical, AppThemeV2.Spacing.sm)
            .background(AppThemeV2.Colors.stone800)
        }
        .focusedSceneValue(\.mappingDocument, document)
        .focusedSceneValue(\.selectedMappingIDs, $selectedMappings)
        .background(AppThemeV2.Colors.stone950)
        .preferredColorScheme(.dark)
        .onDeleteCommand {
            deleteSelectedMappings()
        }
    }

    // MARK: - Actions

    private func addInputMapping(commandName: String) {
        guard !isLocked else { return }
        registerChange()

        let newMapping = MappingEntry(
            commandName: commandName,
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiNote: 36
        )

        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: [newMapping])
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(newMapping)
        }

        selectedMappings = [newMapping.id]
    }

    private func addOutputMapping(commandName: String) {
        guard !isLocked else { return }
        registerChange()

        let newMapping = MappingEntry(
            commandName: commandName,
            ioType: .output,
            assignment: .deckA,
            interactionMode: .output,
            midiChannel: 1,
            midiNote: 36
        )

        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: [newMapping])
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(newMapping)
        }

        selectedMappings = [newMapping.id]
    }

    private func addInOutPair(commandName: String) {
        guard !isLocked else { return }
        registerChange()

        let inputEntry = MappingEntry(
            commandName: commandName,
            ioType: .input,
            assignment: .global,
            interactionMode: .hold,
            midiChannel: 1
        )

        let outputEntry = MappingEntry(
            commandName: commandName,
            ioType: .output,
            assignment: .global,
            interactionMode: .output,
            midiChannel: 1
        )

        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: [inputEntry, outputEntry])
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(contentsOf: [inputEntry, outputEntry])
        }

        selectedMappings = [inputEntry.id, outputEntry.id]
    }

    private func deleteSelectedMappings() {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        registerChange()

        // Remove selected mappings from all devices
        for deviceIndex in document.mappingFile.devices.indices {
            document.mappingFile.devices[deviceIndex].mappings.removeAll { mapping in
                selectedMappings.contains(mapping.id)
            }
        }

        // Clear selection
        selectedMappings.removeAll()
    }

    private func duplicateSelected() {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        registerChange()

        var newMappings: [MappingEntry] = []

        for deviceIndex in document.mappingFile.devices.indices {
            let selectedFromDevice = document.mappingFile.devices[deviceIndex].mappings.filter { mapping in
                selectedMappings.contains(mapping.id)
            }

            for original in selectedFromDevice {
                let duplicate = MappingEntry(
                    commandName: original.commandName,
                    ioType: original.ioType,
                    assignment: original.assignment,
                    interactionMode: original.interactionMode,
                    midiChannel: original.midiChannel,
                    midiNote: original.midiNote,
                    midiCC: original.midiCC,
                    modifier1Condition: original.modifier1Condition,
                    modifier2Condition: original.modifier2Condition,
                    comment: original.comment,
                    controllerType: original.controllerType,
                    invert: original.invert,
                    softTakeover: original.softTakeover,
                    setToValue: original.setToValue,
                    rotarySensitivity: original.rotarySensitivity,
                    rotaryAcceleration: original.rotaryAcceleration,
                    encoderMode: original.encoderMode
                )
                document.mappingFile.devices[deviceIndex].mappings.append(duplicate)
                newMappings.append(duplicate)
            }
        }

        // Select the duplicated items
        selectedMappings = Set(newMappings.map { $0.id })
    }

    private func copyMappedTo() {
        // TODO: Implement copy mapped to
    }

    private func pasteMappedTo() {
        // TODO: Implement paste mapped to
    }

    private func copyModifiers() {
        // TODO: Implement copy modifiers
    }

    private func pasteModifiers() {
        // TODO: Implement paste modifiers
    }

    private func copySelectedMappings() {
        guard !selectedMappings.isEmpty else { return }

        clipboard = document.mappingFile.allMappings.filter { mapping in
            selectedMappings.contains(mapping.id)
        }
    }

    private func pasteSelectedMappings() {
        guard !isLocked, !clipboard.isEmpty else { return }

        registerChange()

        var newMappings: [MappingEntry] = []

        for original in clipboard {
            let copy = MappingEntry(
                commandName: original.commandName,
                ioType: original.ioType,
                assignment: original.assignment,
                interactionMode: original.interactionMode,
                midiChannel: original.midiChannel,
                midiNote: original.midiNote,
                midiCC: original.midiCC,
                modifier1Condition: original.modifier1Condition,
                modifier2Condition: original.modifier2Condition,
                comment: original.comment,
                controllerType: original.controllerType,
                invert: original.invert,
                softTakeover: original.softTakeover,
                setToValue: original.setToValue,
                rotarySensitivity: original.rotarySensitivity,
                rotaryAcceleration: original.rotaryAcceleration,
                encoderMode: original.encoderMode
            )
            newMappings.append(copy)
        }

        // Add to first device or create one
        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: newMappings)
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(contentsOf: newMappings)
        }

        // Select the pasted items
        selectedMappings = Set(newMappings.map { $0.id })
    }

    private func updateSelectedMappings(_ mutation: (inout MappingEntry) -> Void) {
        guard !isLocked, !selectedMappings.isEmpty else { return }

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

    /// Handles mappings dropped from another window or document
    private func handleDroppedMappings(_ mappings: [MappingEntry]) {
        guard !isLocked, !mappings.isEmpty else { return }

        registerChange()

        // Create new entries with new IDs to avoid conflicts
        let newMappings = mappings.map { original in
            MappingEntry(
                commandName: original.commandName,
                ioType: original.ioType,
                assignment: original.assignment,
                interactionMode: original.interactionMode,
                midiChannel: original.midiChannel,
                midiNote: original.midiNote,
                midiCC: original.midiCC,
                modifier1Condition: original.modifier1Condition,
                modifier2Condition: original.modifier2Condition,
                comment: original.comment,
                controllerType: original.controllerType,
                invert: original.invert,
                softTakeover: original.softTakeover,
                setToValue: original.setToValue,
                rotarySensitivity: original.rotarySensitivity,
                rotaryAcceleration: original.rotaryAcceleration,
                encoderMode: original.encoderMode
            )
        }

        // Add to first device or create one
        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: newMappings)
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(contentsOf: newMappings)
        }

        // Select the newly added mappings
        selectedMappings = Set(newMappings.map { $0.id })
    }
}

// MARK: - V2 Action Bar (Full version for main app)

struct V2ActionBarFull: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var isLocked: Bool
    @Binding var categoryFilter: CommandCategory
    @Binding var ioFilter: IODirection
    @Binding var searchText: String
    var onAddInput: (String) -> Void
    var onAddOutput: (String) -> Void
    var onAddInOut: (String) -> Void

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.md) {
            // Left side - Add buttons with command menus
            HStack(spacing: AppThemeV2.Spacing.xs) {
                V2AddCommandMenuButton(icon: "arrow.down", label: "Add In", isDisabled: isLocked) { onAddInput($0) }
                V2AddCommandMenuButton(icon: "arrow.up", label: "Add Out", isDisabled: isLocked) { onAddOutput($0) }
                V2AddCommandMenuButton(icon: "arrow.up.arrow.down", label: "In/Out", isDisabled: isLocked) { onAddInOut($0) }

                Rectangle()
                    .fill(AppThemeV2.Colors.stone600)
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, AppThemeV2.Spacing.xs)

                V2DisabledToolbarButton(icon: "wand.and.stars")
                V2DisabledToolbarButton(icon: "slider.horizontal.3")
            }

            Spacer()

            // Right side - Search, then Filters, then Lock
            HStack(spacing: AppThemeV2.Spacing.sm) {
                V2SearchField(text: $searchText, placeholder: "Search...")
                    .frame(width: 140)

                V2FilterDropdown(label: "Category", selection: $categoryFilter, options: CommandCategory.allCases)
                V2FilterDropdown(label: "I/O", selection: $ioFilter, options: IODirection.allCases)

                V2LockButtonIcon(isLocked: $isLocked)
            }
        }
        .padding(.horizontal, AppThemeV2.Spacing.lg)
        .padding(.vertical, AppThemeV2.Spacing.sm)
        .background(AppThemeV2.Colors.stone800)
        .overlay(
            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - V2 Add Command Menu Button

/// A V2-styled button that shows a hierarchical menu of Traktor commands when clicked
struct V2AddCommandMenuButton: View {
    let icon: String
    let label: String
    let isDisabled: Bool
    let onCommandSelected: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach(CommandHierarchy.categories) { category in
                categoryMenu(category)
            }
        } label: {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label.uppercased())
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: isHovered && !isDisabled ? AppThemeV2.Colors.amberGlow : .clear,
                radius: isHovered && !isDisabled ? 8 : 0
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private func categoryMenu(_ category: CommandCategory2) -> some View {
        if let subcategories = category.subcategories {
            Menu(category.name) {
                ForEach(subcategories) { subcategory in
                    subcategoryMenu(subcategory)
                }
            }
        } else if let commands = category.commands {
            Menu(category.name) {
                ForEach(commands) { command in
                    Button(command.name) { onCommandSelected(command.name) }
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryMenu(_ subcategory: CommandCategory2) -> some View {
        if let commands = subcategory.commands {
            Menu(subcategory.name) {
                ForEach(commands) { command in
                    Button(command.name) { onCommandSelected(command.name) }
                }
            }
        }
    }

    private var foregroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone500 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isHovered && !isDisabled { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isHovered && !isDisabled { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}

// MARK: - V2 Disabled Toolbar Button

/// A permanently disabled toolbar button with greyed styling and no hover
struct V2DisabledToolbarButton: View {
    let icon: String
    let label: String?

    init(icon: String, label: String? = nil) {
        self.icon = icon
        self.label = label
    }

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            if let label = label {
                Text(label.uppercased())
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
            }
        }
        .foregroundColor(AppThemeV2.Colors.stone600)
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(AppThemeV2.Colors.stone800)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
        )
    }
}

// MARK: - V2 Filter Dropdown

/// A styled dropdown menu for filtering with V2 aesthetics
struct V2FilterDropdown<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let label: String
    @Binding var selection: T
    let options: [T]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    HStack {
                        Text(option.rawValue.capitalized)
                        if selection == option {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Text(label.uppercased())
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                Text(selection.rawValue.uppercased())
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .fontWeight(.bold)
                    .foregroundColor(AppThemeV2.Colors.amber)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs + 2)
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
        .fixedSize()
    }
}

#Preview {
    ContentView(document: TraktorMappingDocument(), fileURL: nil)
        .frame(width: 1000, height: 600)
}
