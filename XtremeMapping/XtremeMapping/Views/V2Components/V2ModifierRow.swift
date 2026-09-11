import SwiftUI

/// Writes only explicit menu choices. Loading or displaying an imported
/// condition never resets its target, identifier or opaque value.
struct V2ModifierRow: View {
    @Binding var condition: ModifierCondition?
    let isLocked: Bool
    let onChanged: (ModifierCondition?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            Menu {
                Button("None") { applySelection(nil) }
                ForEach(1...8, id: \.self) { number in
                    Button("M\(number)") {
                        // Retain a known modifier's imported target when the
                        // user chooses its identifier again.
                        let sameModifier = condition?.modifier == number
                        applySelection(ModifierCondition(modifier: number,
                            value: sameModifier ? condition?.value ?? 0 : 0,
                            target: sameModifier ? condition?.target ?? .deckA : .deckA))
                    }
                }
                Divider()
                ForEach(TraktorConditionMetadata.targetedConditionIDs, id: \.self) { identifier in
                    Menu(TraktorConditionMetadata.name(for: identifier)) {
                        ForEach(TraktorConditionMetadata.targets(for: identifier), id: \.self) { target in
                            Button(TraktorConditionMetadata.targetLabel(target, for: identifier)) {
                                applySelection(TraktorConditionMetadata.selectingDeckCondition(
                                    identifier, target: target, previous: condition))
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text(condition.map { TraktorConditionMetadata.name(for: $0.modifier) } ?? "None")
                    Spacer()
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("Condition type")

            if let condition {
                if TraktorConditionMetadata.hasTarget(for: condition.modifier) {
                    Text(TraktorConditionMetadata.targetLabel(condition.target, for: condition.modifier))
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
                let values = TraktorConditionMetadata.values(for: condition.modifier)
                if values.isEmpty {
                    Text("Value \(condition.value) · Preserved native condition")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                } else {
                    HStack {
                        Text("Value").foregroundColor(AppThemeV2.Colors.stone400)
                        Spacer()
                        Menu {
                            ForEach(values) { value in
                                Button(value.label) {
                                    if let edited = TraktorConditionMetadata.replacingValue(of: condition, with: value.rawValue) {
                                        applySelection(edited)
                                    }
                                }
                            }
                        } label: {
                            Text(TraktorConditionMetadata.valueLabel(for: condition))
                        }
                        .menuStyle(.borderlessButton)
                        .accessibilityLabel("Condition value")
                    }
                }
            }
        }
        .font(AppThemeV2.Typography.body)
        .foregroundColor(AppThemeV2.Colors.stone200)
        .padding(AppThemeV2.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm).fill(AppThemeV2.Colors.stone700))
        .disabled(isLocked)
    }

    func applySelection(_ value: ModifierCondition?) {
        // An explicit choice can match the displayed row but differ from
        // other rows in a batch. Always deliver it to the selection editor.
        guard !isLocked else { return }
        condition = value
        onChanged(value)
    }
}
