import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class UnifiedAssistantSession {
    let credentials: MappingAssistantCredentials
    let conversation: AssistantConversationCoordinator
    let input: AssistantInputCoordinator
    init() {
        let credentials = MappingAssistantCredentials()
        self.credentials = credentials
        let store = credentials.store
        conversation = AssistantConversationCoordinator(service: AssistantConversationService(apiKeyProvider: { store.read() }))
        input = AssistantInputCoordinator()
    }
    func close() { input.stopAll(); conversation.cancel(); credentials.clear() }
}

struct UnifiedAssistantView: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var selectedIDs: Set<UUID>
    @Binding var isLocked: Bool
    let onShowMappings: (Set<UUID>) -> Void
    @ObservedObject private var conversation: AssistantConversationCoordinator
    @ObservedObject private var input: AssistantInputCoordinator
    @ObservedObject private var credentials: MappingAssistantCredentials
    @AppStorage("mappingAssistantModel") private var modelID = MappingAssistantModel.sonnet.rawValue
    @State private var question = ""
    @AppStorage("mappingAssistantConsent") private var consent = false
    @State private var showConnection = false
    @State private var credentialRefresh = UUID()
    @State private var showMIDI = false
    @State private var includeSelection = false
    @State private var destinationID: UUID?
    @State private var snapshot: MappingExplanationSnapshot?
    @State private var isBuilding = true
    @State private var errorMessage: String?
    @State private var sheet: AssistantSheet?
    @FocusState private var composerFocused: Bool
    enum AssistantSheet: String, Identifiable { case guide, keys; var id: String { rawValue } }

    init(document: TraktorMappingDocument, selectedIDs: Binding<Set<UUID>>, isLocked: Binding<Bool>,
         session: UnifiedAssistantSession, attachSelection: Bool = false,
         onShowMappings: @escaping (Set<UUID>) -> Void) {
        self.document = document; _selectedIDs = selectedIDs; _isLocked = isLocked
        self.onShowMappings = onShowMappings
        // Opening from selected rows attaches them; a plain toolbar open does
        // not, so its scope reads as the whole mapping.
        _includeSelection = State(initialValue: attachSelection)
        conversation = session.conversation; input = session.input; credentials = session.credentials
    }
    private var current: Bool { snapshot?.revision == document.explanationRevision }
    private var model: MappingAssistantModel { MappingAssistantModel(rawValue: modelID) ?? .sonnet }
    private var validQuestion: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && question.count <= 4_000 && question.utf8.count <= 16 * 1024 }
    private var canSend: Bool { current && validQuestion && consent && credentials.hasKey && !credentials.isLoading && !conversation.isWorking && !isBuilding }

    var body: some View {
        VStack(spacing: 0) {
            header
            V2Divider()
            if showConnection {
                connectionSettings
                V2Divider()
            }
            conversationArea
            V2Divider()
            composer
        }
        .font(AppThemeV2.Typography.body)
        .buttonStyle(AssistantButtonStyle())
        .background(AppThemeV2.Colors.stone900)
        .foregroundStyle(AppThemeV2.Colors.stone200)
        .tint(AppThemeV2.Colors.amber)
        .preferredColorScheme(.dark)
        .task(id: document.explanationRevision) { await prepareSnapshot() }
        .onAppear {
            input.onTranscript = { text in
                question = question.isEmpty ? text : question + " " + text
                composerFocused = true
            }
            if document.mappingFile.devices.count == 1 { destinationID = document.mappingFile.devices.first?.id }
        }
        .onChange(of: consent) { _, enabled in
            conversation.cancel()
            if !enabled { credentials.clear() }
        }
        .task(id: "\(consent)-\(credentialRefresh)") { if consent { await credentials.refreshAsync() } }
        .onChange(of: showConnection) { _, expanded in if expanded { showMIDI = false } }
        .onChange(of: modelID) { _, _ in conversation.cancel() }
        .onChange(of: destinationID) { _, _ in input.clearCapture() }
        .onDisappear { input.stopAll(); conversation.cancel(); credentials.clear() }
        .sheet(item: $sheet, onDismiss: { credentialRefresh = UUID() }) { item in
            switch item {
            case .guide: MappingExplanationSheet(document: document, selectedIDs: selectedIDs, guideOnly: true, onShowMappings: onShowMappings)
            case .keys: APIKeySettingsView()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                V2SectionHeader(title: "ASSISTANT")
                Text(document.backingDocument?.displayName ?? document.fileURL?.lastPathComponent ?? "Untitled mapping")
                    .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            if isLocked { Image(systemName: "lock.fill").help("Mapping locked. Unlock it in the editor to apply changes.").accessibilityLabel("Mapping locked") }
            V2ToolbarIconButton(icon: "gearshape", action: { showConnection.toggle() })
                .help("AI setup — connection, model and privacy")
                .accessibilityLabel("AI setup")
                .accessibilityValue(showConnection ? "Expanded" : "Collapsed")
        }.padding(.horizontal, 16).frame(height: AppThemeV2.Components.sectionHeaderHeight + 12)
            .background(AppThemeV2.Colors.stone800)
    }

    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            HStack {
                AssistantSectionLabel("AI Connection")
                Spacer()
                V2SmallButton(label: "Done") { showConnection = false }
            }

            V2FormRow(label: "Enable AI") {
                V2Toggle(isOn: $consent)
            }

            V2FormRow(label: "Model") {
                V2Dropdown(
                    options: MappingAssistantModel.allCases.map(\.rawValue),
                    selection: $modelID,
                    labelFor: { MappingAssistantModel(rawValue: $0)?.label ?? $0 }
                )
            }

            V2FormRow(label: "API key") {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    if credentials.isLoading {
                        ProgressView().controlSize(.small)
                    } else if credentials.hasKey {
                        Label("Saved", systemImage: "checkmark.seal.fill")
                            .font(AppThemeV2.Typography.caption)
                            .foregroundStyle(AppThemeV2.Colors.success)
                    } else if consent {
                        Label("Needed", systemImage: "key")
                            .font(AppThemeV2.Typography.caption)
                            .foregroundStyle(AppThemeV2.Colors.warning)
                    }
                    V2SmallButton(label: credentials.hasKey ? "Change…" : "Set key…") { sheet = .keys }
                        .disabled(credentials.isLoading)
                }
            }

            Text("Send shares your request, recent conversation, relevant mappings and any captured MIDI with Anthropic, and may incur API charges. Your original TSI data and the full manuals are never sent.")
                .font(AppThemeV2.Typography.caption)
                .foregroundStyle(AppThemeV2.Colors.stone500)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppThemeV2.Spacing.xs)
        }
        .padding(16)
        .background(AppThemeV2.Colors.stone800)
    }

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    greetingBubble
                    if !consent || !credentials.hasKey { setupBubble }
                    ForEach(conversation.messages) { message in
                        messageView(message).id(message.id)
                    }
                    if let context = conversation.localContext, context.revision == document.explanationRevision {
                        localResults(context)
                    }
                    if let plan = conversation.pendingPlan, current { review(plan) }
                    if conversation.isWorking {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Working on your request…").foregroundStyle(AppThemeV2.Colors.stone400)
                            Button("Cancel") { conversation.cancel() }
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).textSelection(.enabled)
            }
            .onChange(of: conversation.messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            .onChange(of: conversation.isWorking) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The Assistant's opening message — always the first bubble in the thread.
    private var greetingBubble: some View {
        assistantBubble("Use this window to chat with your TSI file and controller. Ask questions about how it works, tell it what you want to change, or interact in any way with your Traktor commands and it (should) update automatically! Give it a shot — ask what a button or knob does, or which button or knob does something you want to try.")
    }

    /// Shown until AI is configured, in place of a hint below the composer.
    private var setupBubble: some View {
        assistantBubble("Click the Setup gear icon on the top right to add your API key to use this feature.")
    }

    private func assistantBubble(_ text: String) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assistant").font(AppThemeV2.Typography.micro).tracking(0.5)
                    .foregroundStyle(AppThemeV2.Colors.stone500)
                Text(verbatim: text).lineSpacing(3)
            }
            .padding(12)
            .frame(maxWidth: 460, alignment: .leading)
            .background(AppThemeV2.Colors.stone800, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg).stroke(AppThemeV2.Colors.stone700, lineWidth: 1))
            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func messageView(_ message: AssistantConversationMessage) -> some View {
        // Your messages sit on the right; the Assistant's replies on the left.
        let isUser = message.role == "user"
        let fill = isUser ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone800
        let stroke = isUser ? AppThemeV2.Colors.amber.opacity(0.35) : AppThemeV2.Colors.stone700

        return HStack(spacing: 0) {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isUser ? "You" : message.role == "system" ? "Session" : "Assistant")
                        .font(AppThemeV2.Typography.micro).tracking(0.5)
                        .foregroundStyle(AppThemeV2.Colors.stone500)
                    if message.revision != document.explanationRevision {
                        Text("· earlier version").font(AppThemeV2.Typography.caption)
                            .foregroundStyle(AppThemeV2.Colors.warning)
                    }
                    Spacer()
                    if let answer = message.answer {
                        Menu {
                            Button("Markdown…") { exportReply(answer, revision: message.revision, format: "md") }
                            Button("Plain text…") { exportReply(answer, revision: message.revision, format: "txt") }
                            Button("PDF…") { exportReply(answer, revision: message.revision, format: "pdf") }
                        } label: { Image(systemName: "square.and.arrow.up").font(.system(size: 11)) }
                        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                        .disabled(message.revision != document.explanationRevision)
                        .help("Export this reply")
                    }
                }
                if message.answer == nil, !message.text.isEmpty {
                    Text(verbatim: message.text).lineSpacing(3)
                }
                if let answer = message.answer {
                    answerClaims("Facts", answer.facts, revision: message.revision)
                    answerClaims("Interpretations", answer.interpretations, revision: message.revision)
                    if !answer.unknowns.isEmpty {
                        AssistantSectionLabel("Limitations")
                        ForEach(Array(answer.unknowns.enumerated()), id: \.offset) { _, value in
                            Text(verbatim: value).foregroundStyle(AppThemeV2.Colors.stone400)
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: 460, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg).stroke(stroke, lineWidth: 1))
            if !isUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isBuilding { ProgressView("Reading mapping…").controlSize(.small) }
            if let error = errorMessage ?? conversation.errorMessage ?? input.errorMessage {
                AssistantNoticeBanner(kind: .danger, text: error)
            }
            // Message box with the mic and send as circular icons on the right.
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask a question or describe a change…", text: $question)
                    .textFieldStyle(.plain).focused($composerFocused)
                    .frame(minHeight: 28)
                    .onSubmit { send() }
                    .accessibilityLabel("Message to Assistant")

                composerCircleButton(
                    systemName: input.voiceEnabled ? "mic.fill" : "mic",
                    active: input.voiceEnabled,
                    disabled: false,
                    action: { input.setVoiceEnabled(!input.voiceEnabled) }
                )
                .help("Dictate your message. Tap again to stop.")
                .accessibilityLabel(input.voiceEnabled ? "Stop voice dictation" : "Start voice dictation")

                composerCircleButton(
                    systemName: "arrow.up",
                    active: canSend,
                    disabled: !canSend,
                    action: { send() }
                )
                .keyboardShortcut(.return, modifiers: .command)
                .help("Send to \(model.label) (Command-Return)")
                .accessibilityLabel("Send")
            }
            .padding(8)
            .background(AppThemeV2.Colors.stone950, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg).stroke(composerFocused ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600, lineWidth: 1))

            if question.count > 4_000 || question.utf8.count > 16 * 1024 {
                Text("Keep requests within 4000 characters and 16 KiB of text.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundStyle(AppThemeV2.Colors.danger)
            }
        }.padding(16).background(AppThemeV2.Colors.stone800)
    }

    /// A 28pt circular icon button in the app's palette, for the composer's
    /// mic and send actions.
    private func composerCircleButton(systemName: String, active: Bool, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(active ? AppThemeV2.Colors.stone950 : (disabled ? AppThemeV2.Colors.stone500 : AppThemeV2.Colors.stone300))
                .frame(width: 28, height: 28)
                .background(Circle().fill(active ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone700))
                .overlay(Circle().stroke(active ? AppThemeV2.Colors.amberLight : AppThemeV2.Colors.stone600, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    /// A plain summary of what this request will be scoped to, with removable
    /// attachments. Selection and captured MIDI supplement each other; they are
    /// never forced into mutually exclusive modes.
    private var scopeSummary: some View {
        HStack(spacing: 8) {
            if includeSelection, !selectedIDs.isEmpty {
                scopeChip("Selected rows · \(selectedIDs.count)", systemImage: "checklist") {
                    includeSelection = false
                }
            } else {
                Text("Entire mapping")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                if !selectedIDs.isEmpty {
                    Button { includeSelection = true } label: {
                        Label("Attach \(selectedIDs.count) selected", systemImage: "plus")
                    }.buttonStyle(AssistantLinkButtonStyle()).fixedSize()
                }
            }

            if let midi = input.capturedMIDI {
                scopeChip("Captured control · \((try? midi.model().displayName) ?? "MIDI")",
                          systemImage: "pianokeys") {
                    input.clearCapture()
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func scopeChip(_ text: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 9, weight: .semibold))
            Text(text).font(AppThemeV2.Typography.caption).lineLimit(1)
            Button(action: remove) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }.buttonStyle(.plain).help("Remove from this request")
        }
        .foregroundStyle(AppThemeV2.Colors.amber)
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(AppThemeV2.Colors.amberSubtle))
        .overlay(Capsule().stroke(AppThemeV2.Colors.amber.opacity(0.3), lineWidth: 1))
    }

    private var captureControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if document.mappingFile.devices.isEmpty {
                HStack {
                    Text("Start with a MIDI device to create mappings.")
                    Button("Create MIDI device") {
                        guard !isLocked, MappingTransferService.isTrulyEmpty(document.mappingFile) else { return }
                        let device = Device(name: "Generic MIDI")
                        document.performUndoableMutation(actionName: "Create MIDI Device", undoManager: nil) { file in
                            file.devices.append(device)
                        }
                        destinationID = device.id
                    }.disabled(isLocked || !MappingTransferService.isTrulyEmpty(document.mappingFile))
                }
            }
            HStack {
                Button(input.isLearning ? "Cancel" : "Identify a control") {
                    if input.isLearning { input.stopMIDI() } else { input.learnControl() }
                }.disabled(conversation.isWorking || destinationID == nil || isLocked)
                .help("Capture a MIDI control as context for your request. This does not change any mapping.")
                V2Dropdown(options: [Optional<UUID>.none] + document.mappingFile.devices.map { Optional($0.id) },
                           selection: $destinationID,
                           labelFor: { id in
                               guard let id else { return "Choose device…" }
                               return document.mappingFile.devices.first(where: { $0.id == id })?.name ?? "Device"
                           })
                    .frame(maxWidth: 310)
                if let midi = input.capturedMIDI {
                    Text((try? midi.model().displayName) ?? "Captured MIDI").monospaced()
                    Button("Clear") { input.clearCapture() }
                } else if input.isLearning { Text("Move a control…").foregroundStyle(AppThemeV2.Colors.amber) }
                Spacer()
            }
        }
    }

    private func answerClaims(_ heading: String, _ claims: [MappingAssistantAnswer.Claim], revision: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !claims.isEmpty { AssistantSectionLabel(heading) }
            ForEach(Array(claims.enumerated()), id: \.offset) { _, claim in
                Text(verbatim: claim.text)
                if !claim.rowIDs.isEmpty {
                    Button("Show \(claim.rowIDs.count) source rows") { show(Set(claim.rowIDs)) }
                        .buttonStyle(AssistantLinkButtonStyle()).disabled(revision != document.explanationRevision)
                }
            }
        }
    }

    private func localResults(_ context: ExplanationContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AssistantSectionLabel("Source rows · \(context.rows.count) of \(context.totalRows)")
            if context.rows.isEmpty {
                Text("No matching rows. Try a command, MIDI address, device name or modifier number.")
                    .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
            // Only the matched rows — internal preservation notices are omitted.
            ForEach(context.rows.prefix(12)) { row in
                Button("\(row.deviceName) · row \(row.position) · \(row.command) · \(row.midi)") { show([row.id]) }
                    .buttonStyle(AssistantLinkButtonStyle())
            }
            if context.rows.count > 12 {
                Text("+ \(context.rows.count - 12) more matching rows")
                    .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone500)
            }
        }
    }

    private func review(_ plan: AssistantEditPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V2Divider()
            HStack {
                AssistantSectionLabel("Review proposed changes")
                Spacer()
                Button("Show these mappings") { show(Set(plan.changes.map(\.rowID))) }
                    .buttonStyle(AssistantLinkButtonStyle()).fixedSize()
                    .disabled(plan.changes.isEmpty)
            }
            Text("\(plan.changes.count) affected \(plan.changes.count == 1 ? "row" : "rows") · Pending · not yet applied")
                .foregroundStyle(AppThemeV2.Colors.stone400)
            ForEach(plan.changes) { change in
                let entry = document.mappingFile.allMappings.first { $0.id == change.rowID }
                let deviceName = document.mappingFile.devices.first(where: { $0.id == change.deviceID })?.name ?? "Device"
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(entry?.commandName ?? "Mapping")
                            .font(AppThemeV2.Typography.sectionHeader)
                            .foregroundStyle(AppThemeV2.Colors.stone200)
                        if let entry {
                            Text("\(deviceName) · \(entry.assignment.displayName)")
                                .font(AppThemeV2.Typography.caption)
                                .foregroundStyle(AppThemeV2.Colors.stone400)
                        } else {
                            Text(deviceName)
                                .font(AppThemeV2.Typography.caption)
                                .foregroundStyle(AppThemeV2.Colors.stone400)
                        }
                    }
                    // Before/after summaries lead; raw identifiers are tucked away.
                    ForEach(Array(change.summaries.enumerated()), id: \.offset) { _, value in Text(verbatim: value) }
                    DisclosureGroup("Technical details") {
                        Text(change.rowID.uuidString).font(AppThemeV2.Typography.mono).textSelection(.enabled)
                    }
                }
            }
            ForEach(Array(plan.warnings.enumerated()), id: \.offset) { _, warning in
                AssistantNoticeBanner(kind: .warning, text: warning)
            }
            HStack {
                Button("Apply changes") {
                    do { _ = try conversation.apply(document: document, isLocked: isLocked, undoManager: nil); input.clearCapture() }
                    catch { errorMessage = error.localizedDescription }
                }.buttonStyle(AssistantButtonStyle(primary: true)).disabled(isLocked || conversation.isWorking || plan.isEmpty)
                Button("Discard proposal") { conversation.discardProposal() }
                Text("Apply once, then Undo in the editor to revert.").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
        }.padding(12)
            .background(AppThemeV2.Colors.stone800, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg).stroke(AppThemeV2.Colors.stone700, lineWidth: 1))
    }
    private func show(_ ids: Set<UUID>) {
        let valid = ids.intersection(Set(document.mappingFile.allMappings.map(\.id)))
        if !valid.isEmpty { onShowMappings(valid) }
    }
    private func send() {
        guard canSend, let snapshot else { return }
        guard credentials.hasKey else { return }
        errorMessage = nil
        conversation.send(question: question, document: document, snapshot: snapshot,
            selectedIDs: includeSelection ? selectedIDs : [], capturedMIDI: input.capturedMIDI,
            destinationDeviceID: destinationID, model: model)
        question = ""
    }
    private func exportReply(_ answer: MappingAssistantAnswer, revision: String, format: String) {
        guard revision == document.explanationRevision else { return }
        let guide = MappingReferenceGuide(title: "Assistant reply", revision: revision, sections: [
            .init(heading: "Facts", paragraphs: answer.facts.map { $0.text + "\nRows: " + $0.rowIDs.map(\.uuidString).joined(separator: ", ") }),
            .init(heading: "Interpretations", paragraphs: answer.interpretations.map { $0.text + "\nRows: " + $0.rowIDs.map(\.uuidString).joined(separator: ", ") }),
            .init(heading: "Unknowns and limitations", paragraphs: answer.unknowns)
        ])
        let panel = NSSavePanel()
        panel.title = "Export Assistant reply"
        panel.allowedContentTypes = format == "pdf" ? [.pdf] : [UTType(filenameExtension: format) ?? .plainText]
        panel.nameFieldStringValue = "Assistant reply.\(format)"
        panel.message = "Save the reviewed reply to a new file."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard revision == document.explanationRevision else { errorMessage = "The mapping changed. Review a fresh reply before exporting."; return }
        do {
            let data = try format == "pdf" ? MappingGuidePDF.render(guide) : Data((format == "md" ? guide.markdown : guide.plainText).utf8)
            try TSIExportDestinationValidator.validateNewDestination(source: document.fileURL, destination: url)
            try TSIExclusiveAtomicWriter.publish(data, to: url)
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareSnapshot() async {
        let revision = document.explanationRevision
        conversation.invalidate(revision: revision)
        snapshot = nil; isBuilding = true; errorMessage = nil
        let file = document.mappingFile
        let title = document.backingDocument?.displayName ?? document.fileURL?.lastPathComponent ?? "Untitled mapping"
        let worker = Task.detached(priority: .userInitiated) {
            try MappingExplanationSnapshot.build(file: file, title: title, revision: revision)
        }
        do {
            let facts = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled, document.explanationRevision == revision else { return }
            snapshot = facts; isBuilding = false
            if let destinationID, !file.devices.contains(where: { $0.id == destinationID }) { self.destinationID = nil }
        } catch {
            guard !Task.isCancelled, document.explanationRevision == revision else { return }
            errorMessage = error.localizedDescription; isBuilding = false
        }
    }
}
