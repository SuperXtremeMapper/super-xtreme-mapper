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
    @Environment(\.openWindow) private var openWindow
    @State private var selectedMappings: Set<MappingEntry.ID> = []
    @State private var categoryFilter: CommandCategory = .all
    @State private var ioFilter: IODirection = .all
    @State private var isLocked: Bool = false
    @State private var searchText: String = ""
    @State private var activeSheet: SheetType?
    @StateObject private var assistantWindow = AssistantWindowController()
    @State private var mappingTransferError: MappingTransferError?
    @State private var workflowDestinationError: MappingTransferError?
    @State private var deckCloneError: String?
    @State private var deckCloneStatus: String?
    @State private var isManualOrder = true
    @State private var compatibilityBannerDismissed = false
    @State private var profileMatchIDs: Set<UUID>?

    private var canReorder: Bool {
        !isLocked && profileMatchIDs == nil && isManualOrder && categoryFilter == .all && ioFilter == .all
            && searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sharedMIDIIDs: Set<UUID> {
        MappingTableOperations.sharedMIDIIDs(in: document.mappingFile, selectedIDs: selectedMappings)
    }

    private func moveMappings(_ ids: Set<UUID>, before target: UUID?) -> Bool {
        guard canReorder else { return false }
        return document.performUndoableMutation(actionName: "Move Mappings", undoManager: undoManager) { file in
            MappingTableOperations.moveAtBoundary(ids, before: target, in: &file)
        } ?? false
    }

    private func moveMappingsStep(down: Bool) {
        guard canReorder else { return }
        document.performUndoableMutation(actionName: "Move Mappings", undoManager: undoManager) { file in
            MappingTableOperations.step(selectedMappings, down: down, in: &file)
        }
    }

    private var mappingPasteDisabledReason: String? {
        if isLocked {
            return "Unlock the mapping before pasting."
        }
        if MappingTransferService.isTrulyEmpty(document.mappingFile) {
            return nil
        }
        guard !selectedMappings.isEmpty else {
            return "Select a mapping in the destination device before pasting."
        }
        guard MappingTransferService.destinationDeviceID(
            for: selectedMappings,
            in: document.mappingFile
        ) != nil else {
            return "Select mappings from only one destination device before pasting."
        }
        return nil
    }

    // Sheet types for single sheet modifier (avoids crash from multiple sheets)
    enum SheetType: Identifiable {
        case about
        case settings
        case controllerProfile(UUID)
        case deckClone(MappingTransformPlan)
        case replaceComments(Set<UUID>)
        case changeCommand(Set<UUID>)
        case cloneFX(Set<UUID>)

        var id: String {
            switch self {
            case .about:
                "about"
            case .settings:
                "settings"
            case .controllerProfile(let id): "controller-profile-\(id)"
            case .deckClone:
                "deck-clone"
            case .replaceComments: "replace-comments"
            case .changeCommand: "change-command"
            case .cloneFX: "clone-fx"
            }
        }
    }

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
                return categoryMatch && ioMatch && searchMatch && (profileMatchIDs?.contains(entry.id) ?? true)
            }
        }
    }

    private var rootStack: some View {
        VStack(spacing: 0) {
            // V2 Action bar
            V2ActionBarFull(
                document: document,
                isLocked: $isLocked,
                categoryFilter: $categoryFilter,
                ioFilter: $ioFilter,
                searchText: $searchText,
                isManualOrder: $isManualOrder,
                onAddInput: addInputMapping,
                onAddOutput: addOutputMapping,
                onAddInOut: addInOutPair,
                onAbout: { activeSheet = .about },
                onSettings: { activeSheet = .settings },
                onAssistant: { launchAssistant() },
                onWizard: launchWizard
            )

            if !compatibilityBannerDismissed && !document.mappingFile.tsiCompatibilityWarnings.isEmpty {
                compatibilityWarningBanner
            }

            // Main content
            editorSplit

            // V2 Status bar
            HStack(spacing: AppThemeV2.Spacing.sm) {
                if !sharedMIDIIDs.isEmpty {
                    Label("\(sharedMIDIIDs.count) share MIDI", systemImage: "link")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundStyle(AppThemeV2.Colors.danger)
                        .help("Rows sharing a MIDI assignment with the selection. Shared controls may be intentional.")
                } else {
                    Circle()
                        .fill(AppThemeV2.Colors.amber)
                        .frame(width: 6, height: 6)
                    Text("REMINDER: Back up important mappings before making changes")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.amber)
                }
                Spacer()
                if let deckCloneStatus {
                    Text(deckCloneStatus)
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone300)
                }
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
    }

    var body: some View {
        rootStack
        .focusedSceneValue(\.mappingDocument, document)
        .focusedSceneValue(\.selectedMappingIDs, $selectedMappings)
        .focusedSceneValue(\.mappingIsLocked, isLocked)
        .frame(minWidth: 1000, minHeight: 500)
        .background(AppThemeV2.Colors.stone950)
        .preferredColorScheme(.dark)
        .onChange(of: selectedMappings) { _, selection in
            // Insert/duplicate/clone operations must reveal the rows they select.
            if let profileMatchIDs, !selection.isSubset(of: profileMatchIDs) {
                self.profileMatchIDs = nil
            }
        }
        .onDeleteCommand {
            deleteSelectedMappings()
        }
        .onChange(of: document.mappingFile.tsiCompatibilityWarnings.count) { _, _ in
            // Re-show the notice if the set of preserved assignments changes.
            compatibilityBannerDismissed = false
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .about:
                AboutSheet()
            case .settings:
                APIKeySettingsView()
            case .controllerProfile(let deviceID):
                ControllerProfileSheet(document: document, deviceID: deviceID, isLocked: isLocked, undoManager: undoManager) { ids in
                    categoryFilter = .all
                    ioFilter = .all
                    searchText = ""
                    profileMatchIDs = ids
                    selectedMappings = ids
                }
            case .replaceComments(let ids):
                BulkMappingEditSheet(document: document, selectedIDs: ids, isLocked: isLocked, undoManager: undoManager, mode: .comments)
            case .changeCommand(let ids):
                BulkMappingEditSheet(document: document, selectedIDs: ids, isLocked: isLocked, undoManager: undoManager, mode: .command)
            case .cloneFX(let ids):
                FXCloneSheet(document: document, selectedMappingIDs: ids, isLocked: isLocked) { result in
                    selectedMappings = result.createdIDs
                    deckCloneStatus = result.statusText
                }
            case .deckClone(let plan):
                DeckCloneReviewSheet(plan: plan) { decisions in
                    activeSheet = nil
                    executeDeckClone(plan, decisions: decisions)
                }
            }
        }
        .alert(
            "Couldn't Transfer Mappings",
            isPresented: Binding(
                get: { mappingTransferError != nil },
                set: { if !$0 { mappingTransferError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { mappingTransferError = nil }
        } message: {
            Text(mappingTransferError?.localizedDescription ?? "The transfer failed.")
        }
        .alert(
            "Choose a Mapping Device",
            isPresented: Binding(
                get: { workflowDestinationError != nil },
                set: { if !$0 { workflowDestinationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { workflowDestinationError = nil }
        } message: {
            Text(
                workflowDestinationError?.localizedDescription
                    ?? "Select a mapping in the device you want to edit."
            )
        }
        .alert(
            "Couldn't Clone Mappings",
            isPresented: Binding(
                get: { deckCloneError != nil },
                set: { if !$0 { deckCloneError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deckCloneError = nil }
        } message: {
            Text(deckCloneError ?? "The clone failed.")
        }
        .onDisappear { assistantWindow.close() }
        // Handle mode activation from welcome screen
        .onReceive(NotificationCenter.default.publisher(for: .activateVoiceMode)) { notification in
            guard let target = notification.object as? NSDocument,
                  target === document.backingDocument else { return }
            launchAssistant()
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

    private var compatibilityWarningBanner: some View {
        let warnings = document.mappingFile.tsiCompatibilityWarnings
        return HStack(spacing: AppThemeV2.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppThemeV2.Colors.warning)
            Text(
                "\(warnings.count) native MIDI assignment\(warnings.count == 1 ? "" : "s") preserved in compatibility mode. Reassign MIDI to make \(warnings.count == 1 ? "it" : "them") editable."
            )
            .font(AppThemeV2.Typography.caption)
            .foregroundColor(AppThemeV2.Colors.stone300)
            Spacer()
            Button { compatibilityBannerDismissed = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppThemeV2.Colors.stone400)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Dismiss this notice")
            .accessibilityLabel("Dismiss compatibility notice")
        }
        .padding(.horizontal, AppThemeV2.Spacing.lg)
        .padding(.vertical, AppThemeV2.Spacing.sm)
        .background(AppThemeV2.Colors.warning.opacity(0.12))
        .help(warnings.map(\.message).joined(separator: "\n"))
        .accessibilityLabel("TSI compatibility warning")
        .accessibilityValue(warnings.map(\.message).joined(separator: " "))
    }

    // MARK: - Editor split

    /// The table + inspector split. Extracted from `body` so the main view's
    /// expression stays within the Swift type-checker's complexity budget.
    private var editorSplit: some View {
        HSplitView {
            // Left: Mappings Table
            VStack(alignment: .leading, spacing: 0) {
                mappingsHeader
                V2Divider()
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
                    pasteDisabledReason: mappingPasteDisabledReason,
                    onDuplicate: duplicateSelected,
                    onDelete: deleteSelectedMappings,
                    canCloneDeckA: DeckClonePresentation.isCloneEnabled(
                        isLocked: isLocked,
                        selectedMappingIDs: selectedMappings,
                        in: document.mappingFile
                    ),
                    onCloneDeckA: requestDeckClone,
                    onAssignmentChange: { assignment in
                        changeSelectedDeck(to: assignment)
                    },
                    onMIDIChannelChange: changeSelectedMIDIChannel,
                    onCommentChange: changeSelectedComment,
                    onControllerTypeChange: { type in
                        updateSelectedMappings { mapping in
                            guard mapping.ioType == .input else { return }
                            mapping.controllerType = type
                            // Reset interaction mode to default for new type if current mode is invalid
                            if !type.validInteractionModes.contains(mapping.interactionMode) {
                                mapping.interactionMode = type.defaultInteractionMode
                            }
                        }
                    },
                    onInteractionChange: { mode in
                        updateSelectedMappings { if $0.ioType == .input { $0.interactionMode = mode } }
                    },
                    onEncoderModeChange: { mode in
                        updateSelectedMappings { if $0.ioType == .input { $0.setEncoderMode(mode) } }
                    },
                    onModifier1Change: { condition in
                        updateSelectedMappings { $0.modifier1Condition = condition }
                    },
                    onModifier2Change: { condition in
                        updateSelectedMappings { $0.modifier2Condition = condition }
                    },
                    onInvertToggle: {
                        updateSelectedMappings { if $0.ioType == .output { $0.ledInvert.toggle() } else { $0.invert.toggle() } }
                    },
                    sharedMIDIIDs: sharedMIDIIDs,
                    isManualOrder: $isManualOrder,
                    canReorder: canReorder,
                    onMove: { ids, target in moveMappings(ids, before: target) },
                    onMoveStep: { moveMappingsStep(down: $0) },
                    onReplaceComments: { activeSheet = .replaceComments(selectedMappings) },
                    onChangeCommand: { activeSheet = .changeCommand(selectedMappings) },
                    onCloneFX: { activeSheet = .cloneFX(selectedMappings) },
                    onAskAboutSelection: { launchAssistant(attachSelection: true) }
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
            .frame(width: 260)
        }
    }

    // MARK: - Mappings header

    /// The mappings pane header: title, controller setup, and the ordering /
    /// selection actions grouped at the right. Split into sub-views so the
    /// type-checker does not choke on one large expression.
    private var mappingsHeader: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            V2SectionHeader(title: "MAPPINGS")
            if profileMatchIDs != nil {
                Button("Show all mappings") { profileMatchIDs = nil }
                    .buttonStyle(.plain)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.amber)
            }
            Spacer()
        }
        .padding(.horizontal, AppThemeV2.Spacing.lg)
        .frame(height: AppThemeV2.Components.sectionHeaderHeight)
        .background(AppThemeV2.Colors.stone800)
    }

    // MARK: - Assistant and Wizard

    private func resolvedWorkflowDestinationDeviceID() throws -> Device.ID? {
        try MappingTransferService.workflowDestinationDeviceID(
            for: selectedMappings,
            in: document.mappingFile
        )
    }

    private func launchWizard() {
        guard !isLocked else { return }
        let destinationDeviceID: Device.ID?
        do {
            destinationDeviceID = try resolvedWorkflowDestinationDeviceID()
        } catch let error as MappingTransferError {
            workflowDestinationError = error
            return
        } catch {
            workflowDestinationError = .destinationRequired
            return
        }

        WizardTrace.write(" V2ActionBar.onWizard: setting pendingDocument=\(ObjectIdentifier(document)) (doc has \(document.mappingFile.devices.count) devices, \(document.mappingFile.allMappings.count) mappings)")
        WizardCoordinator.pendingDocument = document
        WizardCoordinator.pendingDestinationDeviceID = destinationDeviceID
        NotificationCenter.default.post(name: .wizardDocumentChanged, object: document)
        openWindow(id: "wizard")
    }

    private func launchAssistant(attachSelection: Bool = false) {
        let session = UnifiedAssistantSession()
        assistantWindow.present(title: "Assistant — \(document.backingDocument?.displayName ?? document.fileURL?.lastPathComponent ?? "Untitled mapping")", content: {
            AnyView(UnifiedAssistantView(document: document, selectedIDs: $selectedMappings,
                isLocked: $isLocked, session: session, attachSelection: attachSelection) { ids in
                categoryFilter = .all
                ioFilter = .all
                searchText = ""
                profileMatchIDs = ids
                selectedMappings = ids
            })
        }, onClose: { session.close() }, undoManager: { document.backingDocument?.undoManager ?? undoManager })
    }

    // MARK: - Actions

    private func addInputMapping(command: TraktorCommandDescriptor) {
        guard !isLocked else { return }

        let newMapping = MappingEntry.input(commandID: command.id)
        addMappings([newMapping], actionName: "Add Input Mapping")
    }

    private func addOutputMapping(command: TraktorCommandDescriptor) {
        guard !isLocked else { return }

        let newMapping = MappingEntry.output(commandID: command.id)
        addMappings([newMapping], actionName: "Add Output Mapping")
    }

    private func addInOutPair(command: TraktorCommandDescriptor) {
        guard !isLocked else { return }

        let inputEntry = MappingEntry.input(commandID: command.id)

        let outputEntry = MappingEntry.output(commandID: command.id)
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
            ClipboardManager.shared.pasteMappedTo(to: selectedMappings, in: &file)
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

    private func requestDeckClone(_ destinations: Set<DeckCloneDestination>) {
        deckCloneStatus = nil
        deckCloneError = nil

        guard DeckClonePresentation.isCloneEnabled(
            isLocked: isLocked,
            selectedMappingIDs: selectedMappings,
            in: document.mappingFile
        ) else { return }

        let plan = MappingTransformPlanner.plan(
            MappingTransformRequest(
                selectedMappingIDs: selectedMappings,
                destinations: destinations
            ),
            in: document.mappingFile
        )

        guard plan.statusText != nil else { return }
        if plan.reviewItems.isEmpty {
            executeDeckClone(plan, decisions: [:])
        } else {
            activeSheet = .deckClone(plan)
        }
    }

    private func executeDeckClone(
        _ plan: MappingTransformPlan,
        decisions: [MappingTransformReviewItem.ID: MappingTransformReviewDecision]
    ) {
        do {
            let result = try MappingTransformExecutor.execute(
                plan,
                decisions: decisions,
                in: document,
                undoManager: undoManager
            )
            guard let status = DeckClonePresentation.statusText(for: result) else {
                deckCloneStatus = nil
                return
            }
            selectedMappings = result.createdIDs
            deckCloneStatus = status
        } catch {
            deckCloneError = error.localizedDescription
        }
    }

    private func changeSelectedDeck(to assignment: TargetAssignment) {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        _ = document.performUndoableMutation(
            actionName: "Change Deck",
            undoManager: undoManager
        ) { file in
            for deviceIndex in file.devices.indices {
                for mappingIndex in file.devices[deviceIndex].mappings.indices {
                    let mappingID = file.devices[deviceIndex].mappings[mappingIndex].id
                    if selectedMappings.contains(mappingID) {
                        file.devices[deviceIndex].mappings[mappingIndex].assignment = assignment
                    }
                }
            }
        }
    }

    private func changeSelectedMIDIChannel(to channel: Int) {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        do {
            _ = try document.performUndoableMutation(
                actionName: "Change MIDI Channel",
                undoManager: undoManager
            ) { file in
                try MappingBatchEditor.applyChannel(
                    channel,
                    to: selectedMappings,
                    in: &file
                )
            }
        } catch {
            assertionFailure("Invalid context-menu MIDI channel: \(channel)")
        }
    }

    private func changeSelectedComment(to comment: String) {
        guard !isLocked, !selectedMappings.isEmpty else { return }

        _ = document.performUndoableMutation(
            actionName: "Apply Mapping Comment",
            undoManager: undoManager
        ) { file in
            MappingBatchEditor.applyComment(
                comment,
                to: selectedMappings,
                in: &file
            )
        }
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
        do {
            let transfer = try MappingTransferService.insertCopies(
                mappings,
                into: document,
                targetDeviceID: targetDeviceID,
                actionName: actionName,
                undoManager: undoManager
            )
            if let transfer {
                selectedMappings = transfer.insertedIDs
            }
        } catch let error as MappingTransferError {
            mappingTransferError = error
        } catch {
            mappingTransferError = .preflightFailed(error.localizedDescription)
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
    @Binding var isManualOrder: Bool
    var onAddInput: (TraktorCommandDescriptor) -> Void
    var onAddOutput: (TraktorCommandDescriptor) -> Void
    var onAddInOut: (TraktorCommandDescriptor) -> Void
    var onAbout: () -> Void
    var onSettings: () -> Void
    var onAssistant: (() -> Void)?
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

                // Assistant entry point. The standalone Wizard button was
                // removed — mapping creation by moving controls now lives in the
                // Assistant's Voice Learn (mic in the composer).
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    // Unified Assistant
                    if let assistantAction = onAssistant {
                        V2ToolbarButton(
                            icon: "bubble.left.and.bubble.right",
                            label: "Assistant",
                            action: assistantAction,
                            minWidth: 70
                        )
                        .help("Assistant — ask questions or describe mapping changes by text or voice")
                    }
                }
            }

            Spacer()

            // Filters, search, and app icons as one right-side group with
            // consistent spacing.
            HStack(spacing: AppThemeV2.Spacing.sm) {
                V2FilterMenu(categoryFilter: $categoryFilter, ioFilter: $ioFilter, isManualOrder: $isManualOrder)
                V2SearchField(text: $searchText, placeholder: "Search...")
                    .frame(width: 140)
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
        // Keep the original styled button + rollover, and overlay a transparent
        // menu that fills the whole button so a click anywhere opens the dropdown.
        visualButton
            .overlay {
                Menu {
                    ForEach(commandCategories) { category in
                        categoryMenu(category)
                    }
                } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .disabled(isDisabled)
            }
            .fixedSize()
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
        .frame(height: 24)
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
    var isActive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    private var highlighted: Bool { isActive || isHovered }

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(highlighted ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone400)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(highlighted ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone700)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(highlighted ? AppThemeV2.Colors.amber.opacity(0.5) : AppThemeV2.Colors.stone600, lineWidth: 1)
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

// MARK: - V2 Combined Filter Menu

/// A single circular filter button (funnel icon) that combines the category and
/// I/O direction filters into one menu, in the same style as the other circular
/// toolbar buttons.
struct V2FilterMenu: View {
    @Binding var categoryFilter: CommandCategory
    @Binding var ioFilter: IODirection
    @Binding var isManualOrder: Bool

    @State private var isHovered = false

    private var isFiltered: Bool {
        categoryFilter.rawValue.lowercased() != "all"
            || ioFilter.rawValue.lowercased() != "all"
    }

    var body: some View {
        ZStack {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(backgroundColor))
                .overlay(Circle().stroke(borderColor, lineWidth: 1))
                .shadow(
                    color: isHovered ? AppThemeV2.Colors.amberGlow : .clear,
                    radius: isHovered ? 6 : 0
                )

            Menu {
                Section("Category") {
                    ForEach(CommandCategory.allCases, id: \.self) { option in
                        Button { categoryFilter = option } label: {
                            HStack {
                                Text(option.rawValue.capitalized)
                                if categoryFilter == option { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Section("Direction") {
                    ForEach(IODirection.allCases, id: \.self) { option in
                        Button { ioFilter = option } label: {
                            HStack {
                                Text(option.rawValue.capitalized)
                                if ioFilter == option { Spacer(); Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                Section("Order") {
                    Button { isManualOrder = true } label: {
                        HStack {
                            Text("Manual")
                            if isManualOrder { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                    Button { isManualOrder = false } label: {
                        HStack {
                            Text("Auto")
                            if !isManualOrder { Spacer(); Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Color.clear.frame(width: 24, height: 24).contentShape(Circle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
        .frame(width: 28, height: 28)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
        .help("Filter mappings by category and direction")
    }

    private var foregroundColor: Color {
        (isFiltered || isHovered) ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone500
    }
    private var backgroundColor: Color {
        (isFiltered || isHovered) ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone800
    }
    private var borderColor: Color {
        (isFiltered || isHovered) ? AppThemeV2.Colors.amber.opacity(0.5) : AppThemeV2.Colors.stone700
    }
}

#Preview {
    ContentView(document: TraktorMappingDocument(), fileURL: nil)
        .frame(width: 1000, height: 600)
}
