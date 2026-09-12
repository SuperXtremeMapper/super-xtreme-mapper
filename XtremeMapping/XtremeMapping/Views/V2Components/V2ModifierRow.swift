import SwiftUI

/// One modifier-condition row rendered as two aligned columns: the condition
/// selector and its value. Writing only happens on an explicit menu choice, so
/// loading or displaying an imported condition never resets its target,
/// identifier or opaque value. A `None` condition keeps the row's width and
/// height and disables its empty value field.
struct V2ModifierRow: View {
    @Binding var condition: ModifierCondition?
    let isLocked: Bool
    /// True when a multi-selection's rows hold different conditions here; the
    /// row shows "Multiple values" and never presents one row's value as shared.
    var isMixed: Bool = false
    let onChanged: (ModifierCondition?) -> Void

    /// Fixed value-column width so both stacked rows line up.
    private let valueColumnWidth: CGFloat = 84

    private var conditionTitle: String {
        if isMixed { return "Multiple values" }
        return condition.map { TraktorConditionMetadata.name(for: $0.modifier) } ?? "None"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xxs) {
            HStack(spacing: AppThemeV2.Spacing.sm) {
                // Condition column — fills the remaining width.
                Menu {
                    conditionMenuItems
                } label: {
                    chrome(
                        title: conditionTitle,
                        dimmed: isMixed || condition == nil,
                        interactive: !isLocked
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Condition type")

                // Value column — fixed width so both rows align.
                valueColumn
                    .frame(width: valueColumnWidth)
            }

            // Supporting context for targeted or preserved conditions, shown
            // below the aligned row so it never shifts the columns.
            if !isMixed, let condition {
                if TraktorConditionMetadata.hasTarget(for: condition.modifier) {
                    Text(TraktorConditionMetadata.targetLabel(condition.target, for: condition.modifier))
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
                if TraktorConditionMetadata.values(for: condition.modifier).isEmpty {
                    Text("Preserved native condition")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                }
            }
        }
        .disabled(isLocked)
    }

    // MARK: - Value column

    @ViewBuilder private var valueColumn: some View {
        if isMixed {
            chrome(title: "—", dimmed: true, interactive: false)
        } else if let condition {
            let values = TraktorConditionMetadata.values(for: condition.modifier)
            if values.isEmpty {
                // Opaque/native value: shown, not editable here.
                chrome(title: "\(condition.value)", dimmed: false, interactive: false)
            } else {
                Menu {
                    ForEach(values) { value in
                        Button(value.label) {
                            if let edited = TraktorConditionMetadata.replacingValue(
                                of: condition, with: value.rawValue) {
                                applySelection(edited)
                            }
                        }
                    }
                } label: {
                    chrome(
                        title: TraktorConditionMetadata.valueLabel(for: condition),
                        dimmed: false,
                        interactive: !isLocked
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .accessibilityLabel("Condition value")
            }
        } else {
            // None: disabled placeholder that preserves width and height.
            chrome(title: "—", dimmed: true, interactive: false)
        }
    }

    // MARK: - Condition menu

    @ViewBuilder private var conditionMenuItems: some View {
        Button("None") { applySelection(nil) }
        ForEach(1...8, id: \.self) { number in
            Button("M\(number)") {
                // Retain a known modifier's imported target when the user
                // chooses its identifier again.
                let sameModifier = condition?.modifier == number
                applySelection(ModifierCondition(modifier: number,
                    value: sameModifier ? condition?.value ?? 0 : 0,
                    target: sameModifier ? condition?.target ?? .deckA : .deckA))
            }
        }
        Divider()
        ForEach(TraktorConditionMetadata.targetedConditionIDs.filter {
            !TraktorConditionMetadata.isRemixCellState($0)
        }, id: \.self) { identifier in
            conditionMenu(identifier)
        }
        Menu("Remix Cell State") {
            ForEach(1...4, id: \.self) { slot in
                Menu("Slot \(slot)") {
                    ForEach(1...16, id: \.self) { cell in
                        conditionMenu(664 + (slot - 1) * 16 + cell)
                    }
                }
            }
        }
    }

    private func conditionMenu(_ identifier: Int) -> some View {
        Menu(TraktorConditionMetadata.name(for: identifier)) {
            ForEach(TraktorConditionMetadata.targets(for: identifier), id: \.self) { target in
                Button(TraktorConditionMetadata.targetLabel(target, for: identifier)) {
                    applySelection(TraktorConditionMetadata.selectingDeckCondition(
                        identifier, target: target, previous: condition))
                }
            }
        }
    }

    // MARK: - Shared dropdown chrome

    /// The closed-dropdown look shared by the condition and value columns, so
    /// they read as the same control family as the rest of the inspector.
    private func chrome(title: String, dimmed: Bool, interactive: Bool) -> some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Text(title)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(dimmed ? AppThemeV2.Colors.stone500 : AppThemeV2.Colors.stone200)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: AppThemeV2.Spacing.xs)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(interactive ? AppThemeV2.Colors.stone500 : AppThemeV2.Colors.stone600)
        }
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(AppThemeV2.Colors.stone700)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    func applySelection(_ value: ModifierCondition?) {
        // An explicit choice can match the displayed row but differ from
        // other rows in a batch. Always deliver it to the selection editor.
        guard !isLocked else { return }
        condition = value
        onChanged(value)
    }
}
