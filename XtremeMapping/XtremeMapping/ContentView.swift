//
//  ContentView.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine

extension MappingTransferService {
    /// Returns a destination only when the current selection belongs to one
    /// device. Nil deliberately preserves Task 7's first-device fallback.
    static func destinationDeviceID(
        for selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: MappingFile
    ) -> Device.ID? {
        let owners = mappingFile.devices.filter { device in
            device.mappings.contains { selectedIDs.contains($0.id) }
        }
        return owners.count == 1 ? owners[0].id : nil
    }

    /// Duplicates each selected source row at the end of its owning device.
    /// Sources are captured before insertion so device and document order are
    /// stable and freshly inserted IDs cannot become sources in the same pass.
    @discardableResult
    static func duplicateSelection(
        _ selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    ) -> Set<MappingEntry.ID> {
        let batches = mappingFile.devices.map { device in
            (
                device.id,
                device.mappings.filter { selectedIDs.contains($0.id) }
            )
        }

        var insertedIDs: Set<MappingEntry.ID> = []
        for (deviceID, source) in batches where !source.isEmpty {
            insertedIDs.formUnion(
                insertCopies(source, into: &mappingFile, targetDeviceID: deviceID)
            )
        }
        return insertedIDs
    }
}

struct ContentView: View {
    @ObservedObject var document: TraktorMappingDocument
    let fileURL: URL?
    @Environment(\.undoManager) var undoManager
    @Environment(\.openWindow) private var openWindow
    @State private var selectedMappings: Set<MappingEntry.ID> = []
    @State private var categoryFilter: CommandCategory = .all
    @State private var ioFilter: IODirection = .all
    @State private var isLocked: Bool = false
    @State private var searchText: String = ""
    @State private var activeSheet: SheetType?
    @State private var showIntelMacAlert = false

    // Sheet types for single sheet modifier (avoids crash from multiple sheets)
    enum SheetType: Identifiable {
        case about
        case settings
        var id: Self { self }
    }

    /// Check if running on Apple Silicon
    private var isAppleSilicon: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    // Voice Learn coordinator
    @StateObject private var voiceCoordinator = VoiceMappingCoordinator(
        midiManager: MIDIInputManager.shared,
        voiceManager: VoiceInputManager(),
        claudeService: ClaudeAPIService(apiKeyProvider: {
            APIKeyManager.shared.activeKey
        })
    )

    var filteredMappings: [MappingEntry] {
        document.mappingFile.devices.flatMap { device in
            device.mappings.filter { entry in
                let categoryMatch = CommandCategoryMatcher.matches(
                    entry,
                    category: categoryFilter
                )
                let ioMatch = ioFilter == .all || entry.ioType == ioFilter
                let searchMatch = MappingSearch.matches(
                    entry,
                    in: device,
                    query: searchText
                )
                return categoryMatch && ioMatch && searchMatch
            }
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
                onAddInOut: addInOutPair,
                onAbout: { activeSheet = .about },
                onSettings: { activeSheet = .settings },
                voiceCoordinator: voiceCoordinator,
                onVoiceToggle: toggleVoiceLearn,
                onWizard: {
                    WizardTrace.write(" V2ActionBar.onWizard: setting pendingDocument=\(ObjectIdentifier(document)) (doc has \(document.mappingFile.devices.count) devices, \(document.mappingFile.allMappings.count) mappings)")
                    WizardCoordinator.pendingDocument = document
                    NotificationCenter.default.post(name: .wizardDocumentChanged, object: document)
                    openWindow(id: "wizard")
                }
            )

            // Main content
            HSplitView {
                // Left: Mappings Table
                VStack(alignment: .leading, spacing: 0) {
                    // Section header (matches XXSETTINGS height)
                    HStack {
                        V2SectionHeader(title: "MAPPINGS")
                        Spacer()
                    }
                    .padding(.horizontal, AppThemeV2.Spacing.lg)
                    .padding(.vertical, AppThemeV2.Spacing.sm)
                    .background(AppThemeV2.Colors.stone800)

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
                        onPasteMappings: pasteMappings,
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
                            updateSelectedMappings { $0.setEncoderMode(mode) }
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
                .background(AppThemeV2.Colors.stone800)

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
        .focusedSceneValue(\.mappingIsLocked, isLocked)
        .frame(minWidth: 1000, minHeight: 500)
        .background(AppThemeV2.Colors.stone950)
        .preferredColorScheme(.dark)
        .onDeleteCommand {
            deleteSelectedMappings()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .about:
                AboutSheet()
            case .settings:
                APIKeySettingsView()
            }
        }
        .alert("Apple Silicon Required", isPresented: $showIntelMacAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Voice Learn requires an Apple Silicon Mac (M1 or later). Intel Macs are not currently supported.")
        }
        // Voice Learn overlay
        .overlay {
            if voiceCoordinator.isActive {
                ZStack {
                    // Semi-transparent background
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Optional: dismiss on background tap
                        }

                    VoiceLearnOverlay(coordinator: voiceCoordinator)
                }
            }
        }
        // Keyboard shortcuts for disambiguation selection (1-5)
        .onKeyPress("1") { handleDisambiguationKey(0) }
        .onKeyPress("2") { handleDisambiguationKey(1) }
        .onKeyPress("3") { handleDisambiguationKey(2) }
        .onKeyPress("4") { handleDisambiguationKey(3) }
        .onKeyPress("5") { handleDisambiguationKey(4) }
        // Handle mode activation from welcome screen
        .onReceive(NotificationCenter.default.publisher(for: .activateVoiceMode)) { _ in
            // Delay to ensure document is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                toggleVoiceLearn()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .activateWizardMode)) { _ in
            // Delay to ensure document is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Set document and notify wizard (works whether window exists or is created fresh)
                WizardCoordinator.pendingDocument = document
                NotificationCenter.default.post(name: .wizardDocumentChanged, object: document)
                openWindow(id: "wizard")
            }
        }
        .onAppear {
            WizardTrace.write(" ContentView.onAppear: flag=\(WizardCoordinator.pendingWizardForNextNewDocument) document=\(ObjectIdentifier(document))")
            if WizardCoordinator.pendingWizardForNextNewDocument {
                WizardCoordinator.pendingWizardForNextNewDocument = false
                WizardTrace.write(" ContentView.onAppear: CLAIMED flag, opening wizard")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    WizardCoordinator.pendingDocument = document
                    NotificationCenter.default.post(name: .wizardDocumentChanged, object: document)
                    openWindow(id: "wizard")
                    WizardTrace.write(" ContentView.onAppear: openWindow(wizard) called, pendingDocument set")
                }
            }
        }
    }

    // MARK: - Voice Learn

    @discardableResult
    private func addVoiceMapping(midi: MIDIMessage, result: VoiceCommandResult) -> UUID? {
        guard !isLocked,
              let command = TraktorCommands.verifiedDescriptor(
                named: result.command,
                supporting: .input
              ),
              let midiAssignment = MIDIAssignment(learnMessage: midi) else { return nil }

        // Parse assignment from result
        let assignment = parseAssignment(result.assignment)

        // Parse controller type and get its default interaction mode
        let controllerType = parseControllerType(result.controllerType)
        let interactionMode = controllerType.defaultInteractionMode

        // Create the new mapping entry
        let newMapping = MappingEntry(
            commandID: command.id,
            ioType: .input,
            assignment: assignment,
            interactionMode: interactionMode,
            midiAssignment: midiAssignment,
            controllerType: controllerType
        )

        let insertedID = document.performUndoableMutation(
            actionName: "Add Voice Mapping",
            undoManager: undoManager
        ) { file in
            if file.devices.isEmpty {
                file.devices.append(Device(name: "Generic MIDI", mappings: [newMapping]))
            } else {
                file.devices[0].mappings.append(newMapping)
            }
            return newMapping.id
        }
        guard let insertedID else { return nil }

        selectedMappings = [insertedID]
        return insertedID
    }

    private func parseAssignment(_ assignmentString: String?) -> TargetAssignment {
        guard let str = assignmentString?.lowercased() else { return .global }

        if str.contains("deck a") { return .deckA }
        if str.contains("deck b") { return .deckB }
        if str.contains("deck c") { return .deckC }
        if str.contains("deck d") { return .deckD }
        if str.contains("fx") || str.contains("effect") {
            if str.contains("1") { return .fxUnit1 }
            if str.contains("2") { return .fxUnit2 }
            if str.contains("3") { return .fxUnit3 }
            if str.contains("4") { return .fxUnit4 }
            return .fxUnit1
        }
        if str.contains("global") || str.contains("master") || str.contains("browser") {
            return .global
        }

        return .global
    }

    private func parseControllerType(_ controllerTypeString: String?) -> ControllerType {
        guard let str = controllerTypeString?.lowercased() else { return .faderOrKnob }

        if str.contains("button") || str.contains("pad") || str.contains("trigger") {
            return .button
        }
        if str.contains("encoder") || str.contains("rotary") || str.contains("jog") {
            return .encoder
        }
        if str.contains("fader") || str.contains("knob") || str.contains("slider") || str.contains("pot") {
            return .faderOrKnob
        }

        // Default to fader/knob for continuous controls
        return .faderOrKnob
    }

    private func toggleVoiceLearn() {
        if voiceCoordinator.isActive {
            voiceCoordinator.deactivate()
        } else {
            // Check for Apple Silicon before activating
            guard isAppleSilicon else {
                showIntelMacAlert = true
                return
            }
            voiceCoordinator.setDocument(document)
            // Result-returning insertion seam: nil means the document refused
            // the mapping (e.g. locked), and the coordinator won't record it.
            voiceCoordinator.insertMapping = { midi, result in
                addVoiceMapping(midi: midi, result: result)
            }
            voiceCoordinator.activate()
        }
    }

    private func handleDisambiguationKey(_ index: Int) -> KeyPress.Result {
        guard voiceCoordinator.isActive,
              let options = voiceCoordinator.disambiguationOptions,
              index < options.count else {
            return .ignored
        }

        voiceCoordinator.selectOption(index)
        return .handled
    }

    // MARK: - Actions

    private func addInputMapping(command: TraktorCommandDescriptor) {
        guard !isLocked else { return }

        let newMapping = MappingEntry(
            commandID: command.id,
            ioType: .input
        )
        addMappings([newMapping], actionName: "Add Input Mapping")
    }

    private func addOutputMapping(command: TraktorCommandDescriptor) {
        guard !isLocked else { return }

        let newMapping = MappingEntry(
            commandID: command.id,
            ioType: .output
        )
        addMappings([newMapping], actionName: "Add Output Mapping")
    }

    private func addInOutPair(command: TraktorCommandDescriptor) {
        guard !isLocked else { return }

        let inputEntry = MappingEntry(
            commandID: command.id,
            ioType: .input
        )

        let outputEntry = MappingEntry(
            commandID: command.id,
            ioType: .output
        )
        addMappings([inputEntry, outputEntry], actionName: "Add Input/Output Pair")
    }

    private func addMappings(_ mappings: [MappingEntry], actionName: String) {
        guard !isLocked, !mappings.isEmpty else { return }

        let insertedIDs = document.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { file -> Set<MappingEntry.ID> in
            if file.devices.isEmpty {
                file.devices.append(Device(name: "Generic MIDI", mappings: mappings))
            } else {
                file.devices[0].mappings.append(contentsOf: mappings)
            }
            return Set(mappings.map(\.id))
        }

        if let insertedIDs {
            selectedMappings = insertedIDs
        }
    }

    private func deleteSelectedMappings() {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        let result: Void? = document.performUndoableMutation(
            actionName: "Delete Mappings",
            undoManager: undoManager
        ) { file in
            for deviceIndex in file.devices.indices {
                file.devices[deviceIndex].mappings.removeAll { mapping in
                    selectedMappings.contains(mapping.id)
                }
            }
        }

        if result != nil {
            selectedMappings.removeAll()
        }
    }

    private func duplicateSelected() {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        let insertedIDs = document.performUndoableMutation(
            actionName: "Duplicate Mappings",
            undoManager: undoManager
        ) { file in
            MappingTransferService.duplicateSelection(selectedMappings, in: &file)
        }

        if let insertedIDs {
            selectedMappings = insertedIDs
        }
    }

    private func copyMappedTo() {
        guard selectedMappings.count == 1,
              let entry = document.mappingFile.allMappings.first(where: { selectedMappings.contains($0.id) }) else { return }
        ClipboardManager.shared.copyMappedTo(from: entry)
    }

    private func pasteMappedTo() {
        guard !isLocked, !selectedMappings.isEmpty, ClipboardManager.shared.hasMappedToData else { return }

        _ = document.performUndoableMutation(
            actionName: "Paste Mapped To",
            undoManager: undoManager
        ) { file in
            for deviceIndex in file.devices.indices {
                for mappingIndex in file.devices[deviceIndex].mappings.indices {
                    let mappingID = file.devices[deviceIndex].mappings[mappingIndex].id
                    if selectedMappings.contains(mappingID) {
                        ClipboardManager.shared.pasteMappedTo(
                            to: &file.devices[deviceIndex].mappings[mappingIndex]
                        )
                    }
                }
            }
        }
    }

    private func copyModifiers() {
        guard selectedMappings.count == 1,
              let entry = document.mappingFile.allMappings.first(where: { selectedMappings.contains($0.id) }) else { return }
        ClipboardManager.shared.copyModifiers(from: entry)
    }

    private func pasteModifiers() {
        guard !isLocked, !selectedMappings.isEmpty, ClipboardManager.shared.hasModifiersData else { return }

        _ = document.performUndoableMutation(
            actionName: "Paste Modifiers",
            undoManager: undoManager
        ) { file in
            for deviceIndex in file.devices.indices {
                for mappingIndex in file.devices[deviceIndex].mappings.indices {
                    let mappingID = file.devices[deviceIndex].mappings[mappingIndex].id
                    if selectedMappings.contains(mappingID) {
                        ClipboardManager.shared.pasteModifiers(
                            to: &file.devices[deviceIndex].mappings[mappingIndex]
                        )
                    }
                }
            }
        }
    }

    private func copySelectedMappings() {
        guard !selectedMappings.isEmpty else { return }

        ClipboardManager.shared.copyMappings(
            document.mappingFile.allMappings.filter { selectedMappings.contains($0.id) }
        )
    }

    private func pasteSelectedMappings() {
        pasteMappings(ClipboardManager.shared.mappingsClipboard)
    }

    private func pasteMappings(_ mappings: [MappingEntry]) {
        insertTransferredMappings(mappings, actionName: "Paste Mappings")
    }

    private func updateSelectedMappings(_ mutation: (inout MappingEntry) -> Void) {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        _ = document.performUndoableMutation(
            actionName: "Edit Mappings",
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
        }
    }

    /// Handles mappings dropped from another window or document
    private func handleDroppedMappings(_ mappings: [MappingEntry]) {
        insertTransferredMappings(mappings, actionName: "Drop Mappings")
    }

    private func insertTransferredMappings(
        _ mappings: [MappingEntry],
        actionName: String
    ) {
        guard !isLocked, !mappings.isEmpty else { return }

        let targetDeviceID = MappingTransferService.destinationDeviceID(
            for: selectedMappings,
            in: document.mappingFile
        )
        let insertedIDs = document.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { file in
            MappingTransferService.insertCopies(
                mappings,
                into: &file,
                targetDeviceID: targetDeviceID
            )
        }

        if let insertedIDs {
            selectedMappings = insertedIDs
        }
    }
}

// MARK: - V2 Action Bar (Full version for main app)

struct V2ActionBarFull: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var isLocked: Bool
    @Binding var categoryFilter: CommandCategory
    @Binding var ioFilter: IODirection
    @Binding var searchText: String
    var onAddInput: (TraktorCommandDescriptor) -> Void
    var onAddOutput: (TraktorCommandDescriptor) -> Void
    var onAddInOut: (TraktorCommandDescriptor) -> Void
    var onAbout: () -> Void
    var onSettings: () -> Void
    var voiceCoordinator: VoiceMappingCoordinator?
    var onVoiceToggle: (() -> Void)?
    var onWizard: (() -> Void)?

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.md) {
            // Left side - Add buttons with command menus (labeled style)
            HStack(spacing: AppThemeV2.Spacing.xs) {
                V2AddCommandMenuButton(icon: "arrow.down", label: "IN", tooltip: "Add Input Mapping", isDisabled: isLocked, direction: .input) { onAddInput($0) }
                V2AddCommandMenuButton(icon: "arrow.up", label: "OUT", tooltip: "Add Output Mapping", isDisabled: isLocked, direction: .output) { onAddOutput($0) }
                V2AddCommandMenuButton(icon: "arrow.up.arrow.down", label: "IN/OUT", tooltip: "Add Input/Output Pair", isDisabled: isLocked, direction: .all) { onAddInOut($0) }

                Rectangle()
                    .fill(AppThemeV2.Colors.stone600)
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, AppThemeV2.Spacing.xs)

                // Voice and Wizard buttons with consistent spacing
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    // Voice Learn button
                    if let coordinator = voiceCoordinator, let toggle = onVoiceToggle {
                        V2ToolbarButton(
                            icon: "mic.fill",
                            label: "Voice",
                            action: toggle,
                            isActive: coordinator.isActive,
                            minWidth: 70
                        )
                        .help("Voice Learn - Speak commands to create mappings")
                    }

                    // Wizard button
                    if let wizardAction = onWizard {
                        V2ToolbarButton(
                            icon: "wand.and.stars",
                            label: "Wizard",
                            action: wizardAction,
                            minWidth: 70
                        )
                        .help("Mapping Wizard - Guided setup for your controller")
                    }
                }
            }

            Spacer()

            // Center-right - Filters and Search
            HStack(spacing: AppThemeV2.Spacing.sm) {
                // Category filter
                V2CircularFilterMenu(
                    icon: "square.grid.2x2",
                    selection: $categoryFilter,
                    options: CommandCategory.allCases
                )

                // I/O filter
                V2CircularFilterMenu(
                    icon: "arrow.up.arrow.down",
                    selection: $ioFilter,
                    options: IODirection.allCases
                )

                // Search
                V2SearchField(text: $searchText, placeholder: "Search...")
                    .frame(width: 140)
            }

            // Right side - About and Settings
            HStack(spacing: AppThemeV2.Spacing.sm) {
                V2ToolbarIconButton(icon: "info.circle", action: onAbout)
                V2ToolbarIconButton(icon: "gearshape", action: onSettings)
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

// MARK: - V2 Add Command Menu Icon Button (Overlay Technique)

/// An icon-only button styled like V2ToolbarIconButton that opens a command menu
/// Uses overlay technique: transparent Menu on top captures clicks, styled view below handles visuals
struct V2AddCommandMenuIconButton: View {
    let icon: String
    let tooltip: String
    let isDisabled: Bool
    let direction: IODirection
    let onCommandSelected: (TraktorCommandDescriptor) -> Void

    var commandCategories: [CommandCategory2] {
        CommandHierarchy.verifiedCategories(for: direction)
    }

    @State private var isHovered = false

    var body: some View {
        // ZStack: visual button below, transparent menu on top
        ZStack {
            // BOTTOM LAYER: Visual button (non-interactive, just for looks)
            visualButton

            // TOP LAYER: Transparent menu that captures clicks
            transparentMenu
        }
        .frame(width: 28, height: 28)
        .onHover { hovering in
            // Hover detection on container drives visual state
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(tooltip)
    }

    // The visual representation - matches V2ToolbarIconButton exactly
    private var visualButton: some View {
        Image(systemName: icon)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(foregroundColor)
            .frame(width: 28, height: 28)
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

    // Transparent menu that sits on top and captures all clicks
    private var transparentMenu: some View {
        Menu {
            ForEach(commandCategories) { category in
                categoryMenu(category)
            }
        } label: {
            // Invisible hit area - same size as visual button
            Color.clear
                .frame(width: 28, height: 28)
                .contentShape(Rectangle()) // Ensure the clear area is clickable
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(isDisabled)
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
                    Button(command.name) { onCommandSelected(command.descriptor) }
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryMenu(_ subcategory: CommandCategory2) -> some View {
        if let commands = subcategory.commands {
            Menu(subcategory.name) {
                ForEach(commands) { command in
                    Button(command.name) { onCommandSelected(command.descriptor) }
                }
            }
        }
    }

    private var foregroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone600 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone800 }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone700 }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}

// MARK: - V2 Add Command Menu Button (with label)

/// A button with icon AND label that opens a command menu
struct V2AddCommandMenuButton: View {
    let icon: String
    let label: String
    let tooltip: String
    let isDisabled: Bool
    let direction: IODirection
    let onCommandSelected: (TraktorCommandDescriptor) -> Void

    var commandCategories: [CommandCategory2] {
        CommandHierarchy.verifiedCategories(for: direction)
    }

    @State private var isHovered = false

    var body: some View {
        ZStack {
            visualButton
            transparentMenu
        }
        .fixedSize()
        .contentShape(Rectangle())  // Make entire ZStack clickable
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(tooltip)
    }

    private var visualButton: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(label)
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

    private var transparentMenu: some View {
        Menu {
            ForEach(commandCategories) { category in
                categoryMenu(category)
            }
        } label: {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill the ZStack
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(isDisabled)
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
                    Button(command.name) { onCommandSelected(command.descriptor) }
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryMenu(_ subcategory: CommandCategory2) -> some View {
        if let commands = subcategory.commands {
            Menu(subcategory.name) {
                ForEach(commands) { command in
                    Button(command.name) { onCommandSelected(command.descriptor) }
                }
            }
        }
    }

    private var foregroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone600 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone800 }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone700 }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
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

// MARK: - V2 Toolbar Icon Button

/// Simple icon-only toolbar button with hover effects
struct V2ToolbarIconButton: View {
    let icon: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone400)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(isHovered ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone700)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(isHovered ? AppThemeV2.Colors.amber.opacity(0.5) : AppThemeV2.Colors.stone600, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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

// MARK: - V2 Circular Filter Menu

/// A small circular button that opens a filter dropdown menu
/// Uses overlay technique: transparent Menu on top captures clicks, styled view below handles visuals
struct V2CircularFilterMenu<T: Hashable & CaseIterable & RawRepresentable>: View where T.RawValue == String {
    let icon: String
    @Binding var selection: T
    let options: [T]

    @State private var isHovered = false

    /// Check if a non-default filter is active
    private var isFiltered: Bool {
        selection.rawValue.lowercased() != "all"
    }

    var body: some View {
        // ZStack: visual button below, transparent menu on top
        ZStack {
            // BOTTOM LAYER: Visual button (non-interactive, just for looks)
            visualButton

            // TOP LAYER: Transparent menu that captures clicks
            transparentMenu
        }
        .frame(width: 28, height: 28)
        .onHover { hovering in
            // Hover detection on container drives visual state
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    // The visual representation
    private var visualButton: some View {
        Image(systemName: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(foregroundColor)
            .frame(width: 28, height: 28)
            .background(
                Circle()
                    .fill(backgroundColor)
            )
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(
                color: isHovered ? AppThemeV2.Colors.amberGlow : .clear,
                radius: isHovered ? 6 : 0
            )
    }

    // Transparent menu that sits on top and captures all clicks
    private var transparentMenu: some View {
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
            // Invisible hit area - same size as visual button
            Color.clear
                .frame(width: 24, height: 24)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private var foregroundColor: Color {
        if isFiltered { return AppThemeV2.Colors.amber }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone500
    }

    private var backgroundColor: Color {
        if isFiltered { return AppThemeV2.Colors.amberSubtle }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone800
    }

    private var borderColor: Color {
        if isFiltered { return AppThemeV2.Colors.amber.opacity(0.5) }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone700
    }
}

#Preview {
    ContentView(document: TraktorMappingDocument(), fileURL: nil)
        .frame(width: 1000, height: 600)
}
