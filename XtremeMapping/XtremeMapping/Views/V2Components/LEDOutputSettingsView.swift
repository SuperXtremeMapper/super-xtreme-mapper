import SwiftUI

/// Values shown for a selection are separate from the explicit edits to apply.
/// A mixed or untouched field never becomes a replacement value implicitly.
struct LEDOutputDraft {
    let entries: [MappingEntry]
    private(set) var patch = LEDOutputSettings.Patch()

    init(entries: [MappingEntry]) { self.entries = entries }

    func commonText(_ field: LEDOutputSettings.Field) -> String? {
        guard let first = entries.first,
              let value = LEDOutputSettings.text(for: field, in: first),
              entries.allSatisfy({ LEDOutputSettings.text(for: field, in: $0) == value }) else { return nil }
        return value
    }

    func commonFlag(blend: Bool) -> Bool? {
        guard let first = entries.first else { return nil }
        let value = blend ? first.ledBlend : first.ledInvert
        return entries.allSatisfy({ (blend ? $0.ledBlend : $0.ledInvert) == value }) ? value : nil
    }

    func text(_ field: LEDOutputSettings.Field) -> String {
        let edited: String?
        switch field {
        case .controllerMinimum: edited = patch.controllerMinimum
        case .controllerMaximum: edited = patch.controllerMaximum
        case .midiMinimum: edited = patch.midiMinimum
        case .midiMaximum: edited = patch.midiMaximum
        }
        return edited ?? commonText(field) ?? ""
    }

    mutating func setText(_ text: String, for field: LEDOutputSettings.Field) {
        switch field {
        case .controllerMinimum: patch.controllerMinimum = text
        case .controllerMaximum: patch.controllerMaximum = text
        case .midiMinimum: patch.midiMinimum = text
        case .midiMaximum: patch.midiMaximum = text
        }
    }

    mutating func setFlag(_ value: Bool, blend: Bool) {
        if blend { patch.blend = value } else { patch.invert = value }
    }

    func flag(blend: Bool) -> Bool? {
        (blend ? patch.blend : patch.invert) ?? commonFlag(blend: blend)
    }

    @MainActor
    @discardableResult
    static func apply(_ patch: LEDOutputSettings.Patch, selectedIDs: Set<MappingEntry.ID>, document: TraktorMappingDocument, isLocked: Bool, undoManager: UndoManager?) throws -> Bool {
        guard !isLocked, !patch.isEmpty else { return false }
        let replacement = try LEDOutputSettings.applying(patch, to: selectedIDs, in: document.mappingFile)
        guard replacement != document.mappingFile else { return false }
        return document.performUndoableMutation(actionName: "Edit LED Output", undoManager: undoManager) { file in
            file = replacement
            return true
        } ?? false
    }
}

struct LEDOutputSettingsView: View {
    @ObservedObject var document: TraktorMappingDocument
    let selectedIDs: Set<MappingEntry.ID>
    let isLocked: Bool
    @Environment(\.undoManager) private var undoManager
    @State private var draft = LEDOutputDraft(entries: [])
    @State private var errorMessage: String?

    private var entries: [MappingEntry] {
        document.mappingFile.allMappings.filter { selectedIDs.contains($0.id) }
    }

    private var hasCompleteLEDRecords: Bool {
        entries.allSatisfy { LEDOutputSettings.hasEditableLEDFields(in: $0) }
    }

    private var canEditRange: Bool { LEDOutputSettings.canEditControllerRange(in: entries) }

    private var domainHelp: String? {
        guard let first = entries.first,
              let domain = TraktorOutputMetadata.domain(for: first.commandID),
              entries.allSatisfy({
                  TraktorOutputMetadata.domain(for: $0.commandID) == domain
                      && $0.ledMinRangeType == domain.rangeType
                      && $0.ledMaxRangeType == domain.rangeType
              }) else { return nil }
        return domain.help
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            Text("LED OUTPUT")
                .font(AppThemeV2.Typography.micro)
                .tracking(1)
                .foregroundColor(AppThemeV2.Colors.amber)
            V2FormRow(label: "Type") { Text("LED / Output") }
            rangeField("Controller Min", field: .controllerMinimum, enabled: canEditRange)
            rangeField("Controller Max", field: .controllerMaximum, enabled: canEditRange)
            if let domainHelp {
                Text(domainHelp)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }
            if !hasCompleteLEDRecords {
                Text("This imported mapping has an incomplete LED record. Original data is preserved.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            } else if !canEditRange {
                Text("Controller ranges are read-only for unknown encodings or selections with different value domains. Original values are preserved.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }
            rangeField("MIDI Min", field: .midiMinimum, enabled: true)
            rangeField("MIDI Max", field: .midiMaximum, enabled: true)
            Text("MIDI values: 0–127. Colour and brightness depend on the receiving controller.")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone400)
            flagField("Blend", blend: true)
                .help("Blend scales continuous feedback across the MIDI range. Disable it for discrete LED states.")
            flagField("Output Invert", blend: false)
            if let errorMessage {
                Text(errorMessage)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.warning)
                    .accessibilityLabel("LED settings error: \(errorMessage)")
            }
            HStack {
                Spacer()
                V2SmallButton(label: "Apply LED", action: apply)
                    .disabled(isLocked || !hasCompleteLEDRecords || draft.patch.isEmpty)
                    .accessibilityLabel("Apply LED settings to \(entries.count) selected outputs")
            }
        }
        .font(AppThemeV2.Typography.body)
        .foregroundColor(AppThemeV2.Colors.stone200)
        .onAppear { reload() }
        .onChange(of: entries) { _, _ in reload() }
    }

    private func rangeField(_ label: String, field: LEDOutputSettings.Field, enabled: Bool) -> some View {
        V2FormRow(label: label) {
            V2TextField(
                placeholder: enabled ? "Mixed" : "Unknown / mixed",
                text: Binding(get: { draft.text(field) }, set: { draft.setText($0, for: field); errorMessage = nil })
            )
            .disabled(isLocked || !hasCompleteLEDRecords || !enabled)
            .onSubmit { apply() }
            .accessibilityLabel(label)
        }
    }

    private func flagField(_ label: String, blend: Bool) -> some View {
        V2FormRow(label: label) {
            Picker(label, selection: Binding<Int>(
                get: { draft.flag(blend: blend).map { $0 ? 1 : 0 } ?? -1 },
                set: { if $0 >= 0 { draft.setFlag($0 == 1, blend: blend); errorMessage = nil } }
            )) {
                if draft.flag(blend: blend) == nil { Text("Mixed").tag(-1) }
                Text("Off").tag(0)
                Text("On").tag(1)
            }
            .labelsHidden()
            .disabled(isLocked || !hasCompleteLEDRecords)
            .accessibilityLabel(label)
        }
    }

    private func reload() {
        draft = LEDOutputDraft(entries: entries)
        errorMessage = nil
    }

    private func apply() {
        guard hasCompleteLEDRecords else { return }
        do {
            _ = try LEDOutputDraft.apply(draft.patch, selectedIDs: selectedIDs, document: document, isLocked: isLocked, undoManager: undoManager)
            if !isLocked { reload() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
