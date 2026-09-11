import SwiftUI

struct FXCloneSheet: View {
    @ObservedObject var document: TraktorMappingDocument
    let selectedMappingIDs: Set<MappingEntry.ID>
    let isLocked: Bool
    let onApplied: (MappingTransformExecutionResult) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @State private var source: FXCloneUnit = .unit1
    @State private var destination: FXCloneUnit = .unit2
    @State private var preview: FXClonePlan?
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Clone FX Unit Mappings").font(.title2.weight(.semibold))
            Text("Clone selected mappings assigned to one FX unit into another. FX units are independent of decks.")
                .foregroundStyle(.secondary)
            HStack {
                Picker("Source", selection: $source) {
                    ForEach(FXCloneUnit.allCases) { Text($0.title).tag($0) }
                }
                Picker("Destination", selection: $destination) {
                    ForEach(FXCloneUnit.allCases) { Text($0.title).tag($0) }
                }
            }
            Text("MIDI, conditions, comments and settings are preserved. Exact duplicates on the same device are skipped; other assignments are excluded.")
                .font(.callout).foregroundStyle(.secondary)
            if source == destination {
                Text("Choose a different destination FX unit.").foregroundStyle(.orange)
            } else if let preview {
                Text("\(preview.inserts.count) to create · \(preview.duplicateSkipCount) duplicates skipped · \(preview.ignoredCount) excluded")
                if preview.inserts.isEmpty {
                    Text("No new mappings to create from this selection.").foregroundStyle(.secondary)
                }
            }
            if let errorText { Text(errorText).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Clone Mappings") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLocked || source == destination || preview?.inserts.isEmpty != false)
            }
        }
        .padding(24).frame(width: 560)
        .onAppear { refresh() }
        .onChange(of: source) { _, _ in refresh() }
        .onChange(of: destination) { _, _ in refresh() }
    }

    private func refresh() {
        preview = FXCloneService.plan(selectedMappingIDs: selectedMappingIDs, source: source,
                                      destination: destination, in: document.mappingFile)
        errorText = nil
    }

    private func apply() {
        guard let preview else { return }
        do {
            let result = try FXCloneService.execute(preview, in: document, isLocked: isLocked, undoManager: undoManager)
            onApplied(result)
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
