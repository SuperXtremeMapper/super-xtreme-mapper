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
    @State private var consent = false
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
            V2ToolbarButton(icon: "book.closed", label: "Guide", action: { sheet = .guide })
                .disabled(!current)
                .help("Open the complete local reference guide and export Markdown, text or PDF.")
            V2ToolbarButton(
                icon: "slider.horizontal.3",
                label: consent && credentials.hasKey ? model.label : "AI setup",
                action: { showConnection.toggle() },
                isActive: showConnection
            )
            .help("AI connection, model and privacy settings")
            .accessibilityValue(showConnection ? "Expanded" : "Collapsed")
        }.padding(.horizontal, 16).frame(height: AppThemeV2.Components.sectionHeaderHeight + 12)
            .background(AppThemeV2.Colors.stone800)
    }

    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AssistantSectionLabel("AI Connection")
                Spacer()
                Button("Done") { showConnection = false }
            }

            // Step 1 — turn AI on for this session.
            V2Toggle(isOn: $consent, label: "Enable AI for this session")

            // Step 2 — choose the model.
            settingsRow("Model") {
                V2Dropdown(options: MappingAssistantModel.allCases.map(\.rawValue), selection: $modelID,
                           labelFor: { MappingAssistantModel(rawValue: $0)?.label ?? $0 })
                    .frame(width: 200)
                Spacer(minLength: 0)
            }

            // Step 3 — add your API key, with clear status.
            settingsRow("API key") {
                Button("Set API key…") { sheet = .keys }.disabled(credentials.isLoading)
                if credentials.isLoading {
                    ProgressView().controlSize(.small)
                } else if credentials.hasKey {
                    Label("Saved", systemImage: "checkmark.seal.fill")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundStyle(AppThemeV2.Colors.success)
                } else if consent {
                    Label("Needed to Send", systemImage: "key")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundStyle(AppThemeV2.Colors.warning)
                }
                Spacer(minLength: 0)
            }

            V2Divider()

            Text("Privacy: Send shares your request, recent conversation, relevant mappings and any captured MIDI with Anthropic, and may incur API charges. Your original TSI data and the full manuals are never sent.")
                .font(AppThemeV2.Typography.caption)
                .foregroundStyle(AppThemeV2.Colors.stone500)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(16).background(AppThemeV2.Colors.stone800)
    }

    private func settingsRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(AppThemeV2.Typography.caption)
                .foregroundStyle(AppThemeV2.Colors.stone400)
                .frame(width: 64, alignment: .leading)
            content()
        }
    }

    private var isConversationEmpty: Bool {
        conversation.messages.isEmpty
            && conversation.localContext == nil
            && conversation.pendingPlan == nil
            && !conversation.isWorking
    }

    private var conversationArea: some View {
        Group {
            if isConversationEmpty {
                emptyConversation
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 20) {
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
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyConversation: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Your mapping, explained.").font(AppThemeV2.Typography.display)
                Text("Ask a question or describe an edit. Every proposed change is reviewed before it is applied.")
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("TRY").font(AppThemeV2.Typography.micro).tracking(0.5)
                    .foregroundStyle(AppThemeV2.Colors.amber)
                promptButton("Explain modifier 1", icon: "questionmark.bubble")
                promptButton("Which controls change the volume?", icon: "slider.horizontal.3")
                promptButton("Change the selected mappings to Deck B", icon: "pencil", usesSelection: true)
            }
            Text("No controller needed. The reference guide and exports work without AI.")
                .font(AppThemeV2.Typography.caption)
                .foregroundStyle(AppThemeV2.Colors.stone400)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 380)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(24)
    }

    /// A quiet suggestion chip in the app's palette (no heavy border).
    private func promptButton(_ text: String, icon: String, usesSelection: Bool = false) -> some View {
        Button { question = text; includeSelection = usesSelection; composerFocused = true } label: {
            Label(text, systemImage: icon)
                .font(AppThemeV2.Typography.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(AppThemeV2.Colors.stone800, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(AppThemeV2.Colors.stone700, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 360)
        .disabled(usesSelection && selectedIDs.isEmpty)
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
            TextField("Ask a question or describe a change…", text: $question, axis: .vertical)
                .textFieldStyle(.plain).lineLimit(2...5).focused($composerFocused)
                .padding(10).background(AppThemeV2.Colors.stone950, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm).stroke(composerFocused ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600, lineWidth: 1))
                .accessibilityLabel("Message to Assistant")
            HStack(spacing: 10) {
                Toggle(isOn: Binding(get: { input.voiceEnabled }, set: { input.setVoiceEnabled($0) })) {
                    Label(input.isStartingVoice ? "Starting…" : input.voiceEnabled ? "Listening" : "Voice", systemImage: input.voiceEnabled ? "mic.fill" : "mic")
                }.toggleStyle(.switch).controlSize(.small).fixedSize()
                    .help("Dictate into the message. Review it, then Send. Replies are text only.")
                Spacer(minLength: 0)
                if question.count > 3_000 {
                    Text("\(question.count)/4000").font(AppThemeV2.Typography.caption)
                        .foregroundStyle(question.count > 4_000 ? AppThemeV2.Colors.danger : AppThemeV2.Colors.stone400)
                }
                Button { send() } label: { Label("Send", systemImage: "arrow.up") }
                    .buttonStyle(AssistantButtonStyle(primary: true))
                    .keyboardShortcut(.return, modifiers: .command).disabled(!canSend)
                    .help("Send to \(model.label) (Command-Return)")
            }
            HStack(alignment: .top, spacing: 8) {
                Text(input.voiceEnabled ? "Apple Speech may send audio to Apple. Dictation stays here until you send." : "Voice uses Apple Speech. Replies are text only.")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
            }.font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            if question.count > 4_000 || question.utf8.count > 16 * 1024 {
                Text("Keep requests within 4000 characters and 16 KiB of text.").foregroundStyle(AppThemeV2.Colors.danger)
            }
        }.padding(16).background(AppThemeV2.Colors.stone800)
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
            ForEach(Array(context.limitations.enumerated()), id: \.offset) { _, value in
                Text(verbatim: value).font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
            if context.rows.isEmpty { Text("No matching rows. Try a command, MIDI address, device name or modifier number.") }
            ForEach(context.rows) { row in
                Button("\(row.deviceName) · row \(row.position) · \(row.command) · \(row.midi)") { show([row.id]) }.buttonStyle(AssistantLinkButtonStyle())
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
