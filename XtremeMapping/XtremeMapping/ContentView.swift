//
//  ContentView.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var document: TraktorMappingDocument
    @Environment(\.undoManager) var undoManager
    @State private var selectedMappings: Set<MappingEntry.ID> = []
    @State private var categoryFilter: CommandCategory = .all
    @State private var ioFilter: IODirection = .all
    @State private var isLocked: Bool = false
    @State private var clipboard: [MappingEntry] = []

    /// Registers a change with the undo manager to mark document as edited
    private func registerChange() {
        undoManager?.registerUndo(withTarget: document) { doc in
            // Undo action - we don't fully implement undo, just mark as changed
            doc.objectWillChange.send()
        }
    }

    var filteredMappings: [MappingEntry] {
        document.mappingFile.allMappings.filter { entry in
            let categoryMatch = CommandCategoryMatcher.matches(entry, category: categoryFilter)
            let ioMatch = ioFilter == .all || entry.ioType == ioFilter
            return categoryMatch && ioMatch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Action bar below window title
            ActionBar(document: document, isLocked: $isLocked)

            Divider()
                .background(AppTheme.dividerColor)

            // Main content
            HSplitView {
                // Left: Mappings Table
                VStack(alignment: .leading, spacing: 0) {
                    // Header with filters
                    HStack {
                        HStack(spacing: 0) {
                            Text("XX")
                                .font(AppTheme.headerFont)
                                .foregroundColor(AppTheme.accentColor)
                            Text("MAPPINGS")
                                .font(AppTheme.headerFont)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Text("Filters:")
                            .foregroundColor(AppTheme.secondaryTextColor)

                        Picker("Category", selection: $categoryFilter) {
                            ForEach(CommandCategory.allCases, id: \.self) { category in
                                Text(category.rawValue).tag(category)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 120)

                        Picker("I/O", selection: $ioFilter) {
                            ForEach(IODirection.allCases, id: \.self) { direction in
                                Text(direction.rawValue).tag(direction)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    .padding(.horizontal, AppTheme.contentPadding)
                    .padding(.vertical, AppTheme.headerPadding)

                    Divider()
                        .background(AppTheme.dividerColor)

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
                .frame(minWidth: AppTheme.minTableWidth)

                // Right: Settings Panel
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        HStack(spacing: 0) {
                            Text("XX")
                                .font(AppTheme.headerFont)
                                .foregroundColor(AppTheme.accentColor)
                            Text("SETTINGS")
                                .font(AppTheme.headerFont)
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Menu {
                            Button("Duplicate") { duplicateSelected() }
                            Divider()
                            Button("Copy Mapped to") { copyMappedTo() }
                            Button("Paste Mapped to") { pasteMappedTo() }
                            Button("Change Mapped to") { }
                            Divider()
                            Button("Copy Modifiers") { copyModifiers() }
                            Button("Paste Modifiers") { pasteModifiers() }
                        } label: {
                            Image(systemName: AppTheme.Icons.menu)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 30)
                    }
                    .padding(.horizontal, AppTheme.contentPadding)
                    .padding(.vertical, AppTheme.headerPadding)

                    Divider()
                        .background(AppTheme.dividerColor)

                    SettingsPanel(
                        document: document,
                        selectedMappings: selectedMappings,
                        isLocked: isLocked
                    )
                }
                .frame(minWidth: AppTheme.minSettingsPanelWidth, maxWidth: AppTheme.maxSettingsPanelWidth)
            }

            // Beta warning status bar
            HStack {
                Text("BETA: Always backup your mappings before making changes")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.accentColor)
                Spacer()
            }
            .padding(.horizontal, AppTheme.contentPadding)
            .padding(.vertical, 6)
            .background(AppTheme.surfaceColor)
        }
        .focusedSceneValue(\.mappingDocument, document)
        .focusedSceneValue(\.selectedMappingIDs, $selectedMappings)
        .background(AppTheme.backgroundColor)
        .onDeleteCommand {
            deleteSelectedMappings()
        }
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

#Preview {
    ContentView(document: TraktorMappingDocument())
}
