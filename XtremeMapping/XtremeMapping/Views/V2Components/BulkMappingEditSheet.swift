import SwiftUI

struct BulkMappingEditSheet: View {
    enum Mode { case comments, command }

    @ObservedObject var document: TraktorMappingDocument
    let selectedIDs: Set<UUID>
    let isLocked: Bool
    let undoManager: UndoManager?
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @State private var source: MappingFile
    @State private var find = ""
    @State private var replacement = ""
    @State private var matchCase = false
    @State private var commandID = 2333
    @State private var applyError: String?

    init(document: TraktorMappingDocument, selectedIDs: Set<UUID>, isLocked: Bool,
         undoManager: UndoManager?, mode: Mode) {
        self.document = document
        self.selectedIDs = selectedIDs
        self.isLocked = isLocked
        self.undoManager = undoManager
        self.mode = mode
        _source = State(initialValue: document.mappingFile)
        _commandID = State(initialValue: document.mappingFile.allMappings.first {
            selectedIDs.contains($0.id) && (2333...2340).contains($0.commandID)
        }?.commandID ?? 2333)
    }

    private var preview: Result<BulkMappingEditPlan, Error> {
        Result {
            switch mode {
            case .comments:
                return try .comments(in: source, selectedIDs: selectedIDs, find: find,
                                     replacement: replacement, matchCase: matchCase)
            case .command:
                return try .command(in: source, selectedIDs: selectedIDs, commandID: commandID)
            }
        }
    }

    private var plan: BulkMappingEditPlan? { try? preview.get() }
    private var validationError: String? {
        do {
            try preview.get().validate(in: document.mappingFile)
            return nil
        } catch { return error.localizedDescription }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(mode == .comments ? "Find and Replace Comments" : "Change Hotcue Commands")
                .font(.headline)
            Text("\(selectedIDs.count) selected mappings")
                .foregroundStyle(AppThemeV2.Colors.stone400)
            if mode == .comments {
                TextField("Find text", text: $find)
                TextField("Replace with (leave empty to remove)", text: $replacement)
                Toggle("Match case", isOn: $matchCase)
            } else {
                Picker("Command", selection: $commandID) {
                    ForEach(BulkMappingEditPlan.compatibleCommandIDs, id: \.self) { id in
                        Text(TraktorCommands.descriptor(for: id).name).tag(id)
                    }
                }
                Text("MIDI assignments, conditions, comments and LED settings are preserved.")
                    .foregroundStyle(AppThemeV2.Colors.stone400)
            }
            Divider()
            Text("\(plan?.changes.count ?? 0) mappings will change")
                .fontWeight(.semibold)
            HStack {
                Text("Before").frame(maxWidth: .infinity, alignment: .leading)
                Text("After").frame(maxWidth: .infinity, alignment: .leading)
            }.foregroundStyle(AppThemeV2.Colors.stone400)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(plan?.changes ?? []) { change in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(change.before.commandName) · \(change.before.midiAssignment.displayName)")
                                .font(AppThemeV2.Typography.caption)
                                .foregroundStyle(AppThemeV2.Colors.stone400)
                            HStack(alignment: .top, spacing: 16) {
                                Text(display(change.before)).frame(maxWidth: .infinity, alignment: .leading)
                                Text(display(change.after)).frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(AppThemeV2.Colors.amber)
                            }
                            Divider()
                        }
                    }
                }.textSelection(.enabled)
            }.frame(minHeight: 160, maxHeight: 300)
            if let error = applyError ?? validationError {
                Text(error).foregroundStyle(AppThemeV2.Colors.danger)
            }
            if isLocked { Text("Unlock editing to apply changes.").foregroundStyle(AppThemeV2.Colors.amber) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply Changes") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLocked || validationError != nil || (plan?.changes.isEmpty ?? true))
            }
        }
        .font(AppThemeV2.Typography.body)
        .padding(24)
        .frame(width: 640)
        .background(AppThemeV2.Colors.stone900)
        .foregroundStyle(AppThemeV2.Colors.stone200)
        .tint(AppThemeV2.Colors.amber)
    }

    private func display(_ entry: MappingEntry) -> String {
        mode == .comments ? (entry.comment.isEmpty ? "(empty)" : entry.comment) : entry.commandName
    }

    private func apply() {
        do {
            if try preview.get().apply(document: document, isLocked: isLocked, undoManager: undoManager) {
                dismiss()
            }
        } catch { applyError = error.localizedDescription }
    }
}
