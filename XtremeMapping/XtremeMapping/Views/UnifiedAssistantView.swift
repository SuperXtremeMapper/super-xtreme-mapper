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
         session: UnifiedAssistantSession, onShowMappings: @escaping (Set<UUID>) -> Void) {
        self.document = document; _selectedIDs = selectedIDs; _isLocked = isLocked
        self.onShowMappings = onShowMappings
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
            Button { sheet = .guide } label: { Label("Guide & export", systemImage: "book.closed") }
                .disabled(!current).help("Open the complete local reference guide and export Markdown, text or PDF.")
            Button { showConnection.toggle() } label: {
                Label(consent && credentials.hasKey ? model.label : "AI setup", systemImage: "slider.horizontal.3")
            }
            .help("AI connection, model and privacy settings")
            .accessibilityValue(showConnection ? "Expanded" : "Collapsed")
        }.padding(.horizontal, 16).padding(.vertical, 12)
            .background(AppThemeV2.Colors.stone800)
    }

    private var connectionSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                AssistantSectionLabel("AI CONNECTION")
                Spacer()
                Button("Done") { showConnection = false }
            }
            Text("Send shares your request, recent conversation, relevant mappings and captured MIDI with Anthropic. API charges may apply. Original TSI preservation data and full manuals are excluded.")
                .foregroundStyle(AppThemeV2.Colors.stone400).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                V2Toggle(isOn: $consent, label: "Enable AI for this session")
                Spacer(minLength: 0)
                V2Dropdown(options: MappingAssistantModel.allCases.map(\.rawValue), selection: $modelID,
                           labelFor: { MappingAssistantModel(rawValue: $0)?.label ?? $0 })
                    .frame(width: 195)
                Button("API key…") { sheet = .keys }.disabled(credentials.isLoading)
            }
            if credentials.isLoading {
                ProgressView("Waiting for Keychain access… You can close this session at any time.").controlSize(.small)
            } else if consent && !credentials.hasKey {
                Label("Add your Anthropic API key to enable Send.", systemImage: "key")
                    .foregroundStyle(AppThemeV2.Colors.warning)
            }
        }.padding(16).background(AppThemeV2.Colors.stone800)
    }

    private var conversationArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if conversation.messages.isEmpty { emptyConversation }
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

    private var emptyConversation: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your mapping, explained.").font(AppThemeV2.Typography.display)
                Text("Ask a question or describe an edit. Every proposed change is reviewed before it is applied.")
                    .foregroundStyle(AppThemeV2.Colors.stone400).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 8) {
                promptButton("Explain modifier 1", icon: "questionmark.bubble")
                promptButton("Which controls change the volume?", icon: "slider.horizontal.3")
                promptButton("Change the selected mappings to Deck B", icon: "pencil", usesSelection: true)
            }
            Text("No controller needed. The reference guide and exports work without AI.")
                .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone400)
        }.padding(.vertical, 12)
    }

    private func promptButton(_ text: String, icon: String, usesSelection: Bool = false) -> some View {
        Button { question = text; includeSelection = usesSelection; composerFocused = true } label: {
            Label(text, systemImage: icon).frame(maxWidth: .infinity, alignment: .leading)
        }.buttonStyle(AssistantButtonStyle(uppercase: false))
            .frame(maxWidth: 370).disabled(usesSelection && selectedIDs.isEmpty)
    }

    private func messageView(_ message: AssistantConversationMessage) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(message.role == "user" ? "YOU" : message.role == "system" ? "SESSION" : "ASSISTANT",
                      systemImage: message.role == "user" ? "person.crop.circle" : "text.bubble")
                    .font(AppThemeV2.Typography.sectionHeader).foregroundStyle(AppThemeV2.Colors.stone400)
                if message.revision != document.explanationRevision {
                    Text("Earlier version").font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.warning)
                }
                Spacer()
                if let answer = message.answer {
                    Menu {
                        Button("Markdown…") { exportReply(answer, revision: message.revision, format: "md") }
                        Button("Plain text…") { exportReply(answer, revision: message.revision, format: "txt") }
                        Button("PDF…") { exportReply(answer, revision: message.revision, format: "pdf") }
                    } label: { Label("Export reply", systemImage: "square.and.arrow.up") }
                    .fixedSize().disabled(message.revision != document.explanationRevision)
                }
            }
            if message.answer == nil, !message.text.isEmpty { Text(verbatim: message.text).lineSpacing(3) }
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
        .padding(message.role == "user" ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(message.role == "user" ? AppThemeV2.Colors.stone800 : .clear,
                    in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.md))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isBuilding { ProgressView("Reading mapping…").controlSize(.small) }
            if let error = errorMessage ?? conversation.errorMessage ?? input.errorMessage {
                AssistantNoticeBanner(kind: .danger, text: error)
            }
            DisclosureGroup(isExpanded: $showMIDI) {
                captureControls.padding(.top, 8)
            } label: {
                HStack {
                    Label("MIDI control", systemImage: "pianokeys").font(AppThemeV2.Typography.sectionHeader)
                    if let midi = input.capturedMIDI {
                        Text((try? midi.model().displayName) ?? "Captured").font(AppThemeV2.Typography.mono)
                            .foregroundStyle(AppThemeV2.Colors.amber)
                        if let device = document.mappingFile.devices.first(where: { $0.id == destinationID }) {
                            Text(device.name).lineLimit(1).foregroundStyle(AppThemeV2.Colors.stone400)
                        }
                    } else {
                        Text(input.isLearning ? "Listening…" : "Optional")
                            .foregroundStyle(input.isLearning ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone400)
                    }
                }
            }
            .onChange(of: showMIDI) { _, expanded in
                if expanded { showConnection = false } else { input.stopMIDI() }
            }
            if !selectedIDs.isEmpty {
                V2Toggle(isOn: $includeSelection, label: "Use \(selectedIDs.count) selected mappings")
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
                Text("\(question.count)/4000").font(AppThemeV2.Typography.caption)
                    .foregroundStyle(question.count > 4_000 ? AppThemeV2.Colors.danger : AppThemeV2.Colors.stone400)
                Button { send() } label: { Label("Send", systemImage: "arrow.up") }
                    .buttonStyle(AssistantButtonStyle(primary: true))
                    .keyboardShortcut(.return, modifiers: .command).disabled(!canSend)
                    .help("Send to \(model.label) (Command-Return)")
            }
            HStack(alignment: .top, spacing: 8) {
                Text(input.voiceEnabled ? "Apple Speech may send audio to Apple. Dictation stays here until you send." : "Voice uses Apple Speech. Replies are text only.")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if !consent || !credentials.hasKey {
                    Button("Set up AI to chat") { showConnection = true }.buttonStyle(AssistantLinkButtonStyle()).fixedSize()
                }
            }.font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            if question.count > 4_000 || question.utf8.count > 16 * 1024 {
                Text("Keep requests within 4000 characters and 16 KiB of text.").foregroundStyle(AppThemeV2.Colors.danger)
            }
        }.padding(16).background(AppThemeV2.Colors.stone800)
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
                Button(input.isLearning ? "Cancel MIDI capture" : "Learn a control") {
                    if input.isLearning { input.stopMIDI() } else { input.learnControl() }
                }.disabled(conversation.isWorking || destinationID == nil || isLocked)
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
            AssistantSectionLabel("Review proposed changes")
            Text("\(plan.changes.count) affected rows · not applied").foregroundStyle(AppThemeV2.Colors.stone400)
            ForEach(plan.changes) { change in
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.mappingFile.devices.first(where: { $0.id == change.deviceID })?.name ?? "Device").font(AppThemeV2.Typography.sectionHeader)
                    DisclosureGroup("Row details") {
                        Text(change.rowID.uuidString).font(AppThemeV2.Typography.mono).textSelection(.enabled)
                    }
                    ForEach(Array(change.summaries.enumerated()), id: \.offset) { _, value in Text(verbatim: value) }
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
                Text("One Undo step").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
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
