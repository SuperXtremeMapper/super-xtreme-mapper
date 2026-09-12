import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Read-only, document-scoped questions and reference exports.
struct MappingExplanationSheet: View {
    @ObservedObject var document: TraktorMappingDocument
    let selectedIDs: Set<UUID>
    let guideOnly: Bool
    let onShowMappings: (Set<UUID>) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var credentials: MappingAssistantCredentials
    @StateObject private var assistant: MappingAssistantCoordinator
    @AppStorage("mappingAssistantModel") private var modelID = MappingAssistantModel.sonnet.rawValue
    @State private var snapshot: MappingExplanationSnapshot?
    @State private var guide: MappingReferenceGuide?
    @State private var context: ExplanationContext?
    @State private var question = ""
    @State private var tab = 0
    @State private var includeSelection = false
    @State private var consent = false
    @State private var showKeys = false
    @State private var errorMessage: String?
    @State private var exportMessage: String?
    @State private var isBuilding = true

    init(document: TraktorMappingDocument, selectedIDs: Set<UUID>, guideOnly: Bool = false, onShowMappings: @escaping (Set<UUID>) -> Void) {
        self.document = document
        self.selectedIDs = selectedIDs
        self.guideOnly = guideOnly
        self.onShowMappings = onShowMappings
        let credentials = MappingAssistantCredentials()
        let keySnapshot = credentials.store
        _credentials = StateObject(wrappedValue: credentials)
        _assistant = StateObject(wrappedValue: MappingAssistantCoordinator(
            service: MappingAssistantService(apiKeyProvider: { keySnapshot.read() })))
    }

    private var model: MappingAssistantModel { MappingAssistantModel(rawValue: modelID) ?? .sonnet }
    private var current: Bool { snapshot?.revision == document.explanationRevision }
    private var canAsk: Bool {
        current && consent && credentials.hasKey && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && question.count <= 4_000 && !assistant.isWorking
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(guideOnly ? "Reference Guide" : "Mapping Explanation").font(.title2.weight(.semibold))
                Spacer()
                if let snapshot { Text("\(snapshot.devices.count) devices · \(snapshot.rows.count) mappings").foregroundStyle(AppThemeV2.Colors.stone400) }
            }
            Text("Explore your mappings, trace answers to rows, and create a reference guide.")
                .foregroundStyle(AppThemeV2.Colors.stone400)
            HStack {
                if !guideOnly {
                    Picker("View", selection: $tab) {
                        Text("Reference guide").tag(0)
                        Text("Questions").tag(1)
                    }.pickerStyle(.segmented).frame(width: 310)
                }
                Spacer()
                exportMenu("Export guide…", content: guide).disabled(!current || guide == nil)
            }
            Divider()
            if isBuilding {
                ProgressView("Preparing mapping facts…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tab == 0, let guide {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Text(guide.title).font(.title3.weight(.semibold))
                        Text("Complete local reference · no AI or API key needed")
                            .foregroundStyle(AppThemeV2.Colors.stone400)
                        ForEach(Array(guide.sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(section.heading).font(.headline)
                                ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                                    Text(verbatim: paragraph).frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }.textSelection(.enabled).padding(.trailing, 12)
                }
            } else if snapshot != nil {
                questionsView
            } else {
                Text("The mapping facts could not be prepared. Close this sheet and try again.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let message = errorMessage ?? assistant.errorMessage {
                Text(message).foregroundStyle(AppThemeV2.Colors.danger).fixedSize(horizontal: false, vertical: true)
            }
            if let exportMessage { Text(exportMessage).foregroundStyle(AppThemeV2.Colors.stone400) }
            Divider()
            HStack {
                Text("Read only · your mapping stays unchanged")
                    .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                Spacer()
                Button("Done") { assistant.cancel(); dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .font(AppThemeV2.Typography.body)
        .padding(24)
        .frame(width: 940, height: 700)
        .background(AppThemeV2.Colors.stone900)
        .foregroundStyle(AppThemeV2.Colors.stone200)
        .tint(AppThemeV2.Colors.amber)
        .task(id: document.explanationRevision) { await prepareSnapshot() }
        .onChange(of: question) { _, _ in clearAnswer() }
        .onChange(of: includeSelection) { _, _ in clearAnswer() }
        .onChange(of: consent) { _, enabled in
            assistant.cancel()
            if enabled { credentials.refresh() } else { credentials.clear() }
        }
        .onChange(of: modelID) { _, _ in assistant.cancel() }
        .onDisappear { assistant.cancel(); credentials.clear() }
        .sheet(isPresented: $showKeys, onDismiss: {
            if consent { credentials.refresh() }
        }) { APIKeySettingsView() }
    }

    private var questionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField("Find filter mappings, explain modifier 1, or ask about a control…", text: $question)
                    .textFieldStyle(.roundedBorder).onSubmit { findLocally() }
                Button("Find locally") { findLocally() }.disabled(!current || question.isEmpty)
            }
            HStack {
                if !selectedIDs.isEmpty {
                    Toggle("Use \(selectedIDs.count) selected rows and their devices", isOn: $includeSelection)
                        .toggleStyle(.checkbox)
                }
                Spacer()
                Text("\(question.count) / 4000").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
            Text("AI sends your question and relevant rows, including comments, to Anthropic.")
                .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            DisclosureGroup("AI context and privacy") {
                Text("Ask AI sends your question and up to 80 relevant mapping rows to Anthropic: device names, comments, commands, MIDI assignments, conditions, controller settings and relevant profile evidence. Original TSI data, full manuals and API keys are excluded from the context. Requests may incur API charges. Nothing is sent until you enable AI and choose Ask AI.")
                    .foregroundStyle(AppThemeV2.Colors.stone400).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Toggle("Enable AI for this session", isOn: $consent).toggleStyle(.checkbox)
                Picker("Model", selection: $modelID) {
                    ForEach(MappingAssistantModel.allCases, id: \.rawValue) { item in Text(item.label).tag(item.rawValue) }
                }.frame(width: 205)
                if !credentials.hasKey { Button("API key settings…") { showKeys = true } }
                Spacer()
                if assistant.isWorking {
                    ProgressView().controlSize(.small)
                    Button("Cancel request") { assistant.cancel() }
                } else {
                    Button("Ask AI") { ask() }.disabled(!canAsk)
                }
            }
            if !credentials.hasKey {
                Text("Local lookup and all guide exports work without an API key.")
                    .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let answer = assistant.answer, current {
                        Text("AI explanation · review against the referenced rows")
                            .font(.headline)
                        claims("Facts from supplied rows", answer.facts)
                        claims("Interpretations", answer.interpretations)
                        if !answer.unknowns.isEmpty {
                            Text("Unknowns and limitations").font(.headline)
                            ForEach(Array(answer.unknowns.enumerated()), id: \.offset) { _, text in Text(verbatim: text) }
                        }
                        exportMenu("Export explanation…", content: answerGuide(answer))
                        Divider()
                    }
                    if let context {
                        Text("Local context · \(context.rows.count) of \(context.totalRows) rows")
                            .font(.headline)
                        if context.omittedRows > 0 {
                            Text("\(context.omittedRows) rows are outside this context. The reference guide covers the complete mapping.")
                                .foregroundStyle(AppThemeV2.Colors.stone400)
                        }
                        ForEach(Array(context.limitations.enumerated()), id: \.offset) { _, text in
                            Text(verbatim: text).foregroundStyle(AppThemeV2.Colors.stone400)
                        }
                        if context.rows.isEmpty { Text("No matching rows. Try a command, device name, MIDI address or modifier number.") }
                        ForEach(context.rows) { row in
                            VStack(alignment: .leading, spacing: 3) {
                                Button { show([row.id]) } label: {
                                    Text("\(row.deviceName) · row \(row.position) · \(row.command)")
                                }.buttonStyle(.link)
                                Text("\(row.direction) · \(row.assignment) · \(row.midi)")
                                Text(row.conditions.isEmpty ? "No conditions" : row.conditions.joined(separator: "; "))
                                    .foregroundStyle(AppThemeV2.Colors.stone400)
                            }
                        }
                    } else {
                        Text("Try “filter”, “modifier 1”, a control name, or a MIDI address. Find locally shows the source rows; Ask AI explains the retrieved facts.")
                            .foregroundStyle(AppThemeV2.Colors.stone400)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }
        }
    }

    private func claims(_ heading: String, _ values: [MappingAssistantAnswer.Claim]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !values.isEmpty { Text(heading).font(.headline) }
            ForEach(Array(values.enumerated()), id: \.offset) { _, claim in
                Text(verbatim: claim.text)
                if !claim.rowIDs.isEmpty {
                    Button("Show \(claim.rowIDs.count) referenced rows") { show(Set(claim.rowIDs)) }.buttonStyle(.link)
                }
            }
        }
    }

    private func show(_ ids: Set<UUID>) {
        guard current, let snapshot else { return }
        let valid = ids.intersection(Set(snapshot.rows.map(\.id)))
        guard !valid.isEmpty else { return }
        assistant.cancel()
        onShowMappings(valid)
        dismiss()
    }

    private func clearAnswer() { assistant.cancel(); context = nil; errorMessage = nil }
    private func findLocally() {
        guard current, let snapshot else { return }
        assistant.cancel()
        errorMessage = nil
        guard question.count <= 4_000 else { errorMessage = "Keep the question within 4000 characters."; return }
        context = MappingExplanationQuery.retrieve(question: question, snapshot: snapshot,
            selectedIDs: includeSelection ? selectedIDs : [])
    }
    private func ask() {
        guard canAsk else { return }
        credentials.refresh()
        guard credentials.hasKey else { errorMessage = "Add an Anthropic API key in API key settings."; return }
        findLocally()
        guard let context else { return }
        do {
            let data = try JSONEncoder().encode(context)
            assistant.ask(question: question, contextJSON: data, allowedRowIDs: Set(context.rows.map(\.id)),
                revision: context.revision, model: model)
        } catch { errorMessage = error.localizedDescription }
    }

    private func prepareSnapshot() async {
        let revision = document.explanationRevision
        assistant.invalidate(revision: revision)
        snapshot = nil; guide = nil; context = nil; errorMessage = nil; isBuilding = true
        let file = document.mappingFile
        let title = document.backingDocument?.displayName ?? document.fileURL?.lastPathComponent ?? "Untitled mapping"
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let facts = try MappingExplanationSnapshot.build(file: file, title: title, revision: revision)
            try Task.checkCancellation()
            let guide = try MappingReferenceGuide.build(snapshot: facts)
            try Task.checkCancellation()
            return (facts, guide)
        }
        do {
            let result = try await withTaskCancellationHandler { try await worker.value } onCancel: { worker.cancel() }
            guard !Task.isCancelled, document.explanationRevision == revision else { return }
            snapshot = result.0; guide = result.1; isBuilding = false
        } catch {
            guard !Task.isCancelled, document.explanationRevision == revision else { return }
            errorMessage = error.localizedDescription; isBuilding = false
        }
    }

    private func answerGuide(_ answer: MappingAssistantAnswer) -> MappingReferenceGuide {
        var sections: [MappingReferenceGuide.Section] = []
        sections.append(.init(heading: "AI interpretation", paragraphs: [
            "Question: " + question,
            "Model: " + model.label,
            "Review against the source rows. This explanation covers only the supplied context, not the whole mapping.",
            "Context: \(context?.rows.count ?? 0) of \(context?.totalRows ?? 0) rows."
        ]))
        for (label, claims) in [("Facts from supplied rows", answer.facts), ("Interpretations", answer.interpretations)] {
            sections.append(.init(heading: label, paragraphs: claims.map {
                $0.text + ($0.rowIDs.isEmpty ? "" : "\nRows: " + $0.rowIDs.map(\.uuidString).joined(separator: ", "))
            }))
        }
        sections.append(.init(heading: "Unknowns and limitations", paragraphs: answer.unknowns + (context?.limitations ?? [])))
        return MappingReferenceGuide(title: "Explanation — \(snapshot?.title ?? "Mapping")",
            revision: snapshot?.revision ?? "", sections: sections)
    }

    private func exportMenu(_ label: String, content: MappingReferenceGuide?) -> some View {
        Menu(label) {
            Button("Markdown…") { if let content { export(content, format: "md") } }
            Button("Plain text…") { if let content { export(content, format: "txt") } }
            Button("PDF…") { if let content { export(content, format: "pdf") } }
        }.disabled(content == nil || !current)
    }
    private func export(_ content: MappingReferenceGuide, format: String) {
        guard current else { return }
        let revision = document.explanationRevision
        let panel = NSSavePanel()
        panel.title = "Export \(format == "pdf" ? "PDF" : "documentation")"
        panel.allowedContentTypes = format == "pdf" ? [.pdf] : [UTType(filenameExtension: format) ?? .plainText]
        panel.nameFieldStringValue = "Mapping guide.\(format)"
        panel.message = "Export the reviewed content to a new file."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard document.explanationRevision == revision else {
            errorMessage = "The mapping changed. Review the refreshed guide before exporting."; return
        }
        do {
            let data = try format == "pdf" ? MappingGuidePDF.render(content) : Data((format == "md" ? content.markdown : content.plainText).utf8)
            try TSIExportDestinationValidator.validateNewDestination(source: document.fileURL, destination: url)
            try TSIExclusiveAtomicWriter.publish(data, to: url)
            exportMessage = "Exported \(url.lastPathComponent)"
        } catch { errorMessage = error.localizedDescription }
    }
}
