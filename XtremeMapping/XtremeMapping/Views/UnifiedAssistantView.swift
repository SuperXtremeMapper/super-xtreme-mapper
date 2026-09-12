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
    private var canSend: Bool { current && validQuestion && consent && credentials.hasKey && !conversation.isWorking && !isBuilding }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Assistant").font(.title2.weight(.semibold))
                    Text(document.backingDocument?.displayName ?? document.fileURL?.lastPathComponent ?? "Untitled mapping")
                        .foregroundStyle(AppThemeV2.Colors.stone400)
                }
                Spacer()
                if isLocked { Label("Mapping locked", systemImage: "lock.fill") }
                Button("Reference guide / Export…") { sheet = .guide }.disabled(!current)
            }
            DisclosureGroup("AI connection and privacy") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Send shares your request, recent conversation, relevant mapping rows and captured MIDI with Anthropic using your stored key. API charges may apply. Original TSI data and full manuals are excluded. Voice uses Apple Speech and may send audio to Apple; transcripts stay in the composer until you send.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Toggle("Enable AI for this session", isOn: $consent).toggleStyle(.checkbox)
                        Picker("Model", selection: $modelID) {
                            ForEach(MappingAssistantModel.allCases, id: \.rawValue) { Text($0.label).tag($0.rawValue) }
                        }.frame(width: 220)
                        Button("API key settings…") { sheet = .keys }
                    }
                }.padding(.top, 6)
            }
            if !consent || !credentials.hasKey {
                Text("Local lookup and guide exports are ready. Enable AI in connection settings to chat and propose edits.")
                    .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if conversation.messages.isEmpty {
                            Text("Ask about your mapping, or describe a change.").font(.headline)
                            Text("Try “What does modifier 1 do?” or “Change these volume mappings to Deck B.” You can type or use voice. No controller is needed to ask questions.")
                                .foregroundStyle(AppThemeV2.Colors.stone400)
                        }
                        ForEach(conversation.messages) { message in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(message.role == "user" ? "You" : message.role == "system" ? "Session" : "Assistant").font(.headline)
                                    if message.revision != document.explanationRevision {
                                        Text("Earlier mapping revision").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                                    }
                                }
                                if message.answer == nil, !message.text.isEmpty { Text(verbatim: message.text) }
                                if let answer = message.answer {
                                    answerClaims("Facts", answer.facts, revision: message.revision)
                                    answerClaims("Interpretations", answer.interpretations, revision: message.revision)
                                    ForEach(Array(answer.unknowns.enumerated()), id: \.offset) { _, value in
                                        Text(verbatim: value).foregroundStyle(AppThemeV2.Colors.stone400)
                                    }
                                    Menu("Export reply…") {
                                        Button("Markdown…") { exportReply(answer, revision: message.revision, format: "md") }
                                        Button("Plain text…") { exportReply(answer, revision: message.revision, format: "txt") }
                                        Button("PDF…") { exportReply(answer, revision: message.revision, format: "pdf") }
                                    }.disabled(message.revision != document.explanationRevision)
                                }
                            }.id(message.id)
                        }
                        if let context = conversation.localContext, context.revision == document.explanationRevision {
                            localResults(context)
                        }
                        if let plan = conversation.pendingPlan, current { review(plan) }
                        Color.clear.frame(height: 1).id("bottom")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.trailing, 8).textSelection(.enabled)
                }
                .onChange(of: conversation.messages.count) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
            }
            if isBuilding { ProgressView("Reading mapping…").controlSize(.small) }
            if let error = errorMessage ?? conversation.errorMessage ?? input.errorMessage {
                Text(verbatim: error).foregroundStyle(AppThemeV2.Colors.danger).fixedSize(horizontal: false, vertical: true)
            }
            if question.count > 4_000 || question.utf8.count > 16 * 1024 {
                Text("Keep requests within 4000 characters and 16 KiB of text.").foregroundStyle(AppThemeV2.Colors.danger)
            }
            Divider()
            captureControls
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask a question or describe a change…", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(2...5).focused($composerFocused)
                VStack(spacing: 6) {
                    Button("Find locally") { findLocally() }.disabled(!current || !validQuestion || conversation.isWorking)
                    Button("Send") { send() }.buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: .command).disabled(!canSend)
                }
            }
            HStack {
                Toggle(isOn: Binding(get: { input.voiceEnabled }, set: { input.setVoiceEnabled($0) })) {
                    Label(input.isStartingVoice ? "Starting voice…" : input.voiceEnabled ? "Voice on · listening" : "Voice off", systemImage: input.voiceEnabled ? "mic.fill" : "mic.slash")
                }.toggleStyle(.switch).controlSize(.small)
                Text("Spoken input appears above. Replies are text.").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                Spacer()
                if conversation.isWorking {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { conversation.cancel() }
                }
                Text("\(question.count)/4000").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
        }
        .padding(20).font(AppThemeV2.Typography.body)
        .background(AppThemeV2.Colors.stone900).foregroundStyle(AppThemeV2.Colors.stone200).tint(AppThemeV2.Colors.amber)
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
            if enabled { credentials.refresh() } else { credentials.clear() }
        }
        .onChange(of: modelID) { _, _ in conversation.cancel() }
        .onChange(of: destinationID) { _, _ in input.clearCapture() }
        .onDisappear { input.stopAll(); conversation.cancel(); credentials.clear() }
        .sheet(item: $sheet, onDismiss: { if consent { credentials.refresh() } }) { item in
            switch item {
            case .guide: MappingExplanationSheet(document: document, selectedIDs: selectedIDs, guideOnly: true, onShowMappings: onShowMappings)
            case .keys: APIKeySettingsView()
            }
        }
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
                Picker("Destination", selection: $destinationID) {
                    Text("Choose device…").tag(Optional<UUID>.none)
                    ForEach(document.mappingFile.devices) { Text($0.name).tag(Optional($0.id)) }
                }.frame(maxWidth: 310)
                if let midi = input.capturedMIDI {
                    Text((try? midi.model().displayName) ?? "Captured MIDI").monospaced()
                    Button("Clear") { input.clearCapture() }
                } else if input.isLearning { Text("Move a control…").foregroundStyle(AppThemeV2.Colors.amber) }
                Spacer()
            }
            if !selectedIDs.isEmpty {
                Toggle("Use \(selectedIDs.count) selected mappings", isOn: $includeSelection).toggleStyle(.checkbox)
            }
        }
    }

    private func answerClaims(_ heading: String, _ claims: [MappingAssistantAnswer.Claim], revision: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if !claims.isEmpty { Text(heading).font(.subheadline.weight(.semibold)) }
            ForEach(Array(claims.enumerated()), id: \.offset) { _, claim in
                Text(verbatim: claim.text)
                if !claim.rowIDs.isEmpty {
                    Button("Show \(claim.rowIDs.count) source rows") { show(Set(claim.rowIDs)) }
                        .buttonStyle(.link).disabled(revision != document.explanationRevision)
                }
            }
        }
    }

    private func localResults(_ context: ExplanationContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source rows · \(context.rows.count) of \(context.totalRows)").font(.headline)
            ForEach(Array(context.limitations.enumerated()), id: \.offset) { _, value in
                Text(verbatim: value).font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
            if context.rows.isEmpty { Text("No matching rows. Try a command, MIDI address, device name or modifier number.") }
            ForEach(context.rows) { row in
                Button("\(row.deviceName) · row \(row.position) · \(row.command) · \(row.midi)") { show([row.id]) }.buttonStyle(.link)
            }
        }
    }

    private func review(_ plan: AssistantEditPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Review proposed changes").font(.headline)
            Text("\(plan.changes.count) affected rows · nothing applied yet")
            ForEach(plan.changes) { change in
                VStack(alignment: .leading, spacing: 4) {
                    Text(document.mappingFile.devices.first(where: { $0.id == change.deviceID })?.name ?? "Device").font(.subheadline.weight(.semibold))
                    Text("Row \(change.rowID.uuidString)").font(.caption).textSelection(.enabled)
                    ForEach(Array(change.summaries.enumerated()), id: \.offset) { _, value in Text(verbatim: value) }
                }
            }
            ForEach(Array(plan.warnings.enumerated()), id: \.offset) { _, warning in
                Text(verbatim: warning).foregroundStyle(AppThemeV2.Colors.warning)
            }
            HStack {
                Button("Apply changes") {
                    do { _ = try conversation.apply(document: document, isLocked: isLocked, undoManager: nil); input.clearCapture() }
                    catch { errorMessage = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(isLocked || conversation.isWorking || plan.isEmpty)
                Button("Discard proposal") { conversation.discardProposal() }
                Text("One Undo step").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
        }.padding(12).background(AppThemeV2.Colors.stone800, in: RoundedRectangle(cornerRadius: 8))
    }
    private func show(_ ids: Set<UUID>) {
        let valid = ids.intersection(Set(document.mappingFile.allMappings.map(\.id)))
        if !valid.isEmpty { onShowMappings(valid) }
    }
    private func findLocally() {
        guard current, let snapshot else { return }
        conversation.findLocally(question: question, snapshot: snapshot, selectedIDs: includeSelection ? selectedIDs : [])
    }
    private func send() {
        guard canSend, let snapshot else { return }
        credentials.refresh()
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
