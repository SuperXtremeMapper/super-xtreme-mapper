//
//  DeckCloneReviewSheet.swift
//  XtremeMapping
//

import SwiftUI

struct DeckCloneReviewState {
    let plan: MappingTransformPlan
    private(set) var choices: [
        MappingTransformReviewItem.ID: MappingTransformReviewChoice
    ] = [:]

    var canApply: Bool {
        !plan.reviewItems.isEmpty && plan.reviewItems.allSatisfy { item in
            !item.availableChoices.isEmpty && choices[item.id] != nil
        }
    }

    func options(
        for item: MappingTransformReviewItem
    ) -> [MappingTransformReviewChoice] {
        item.availableChoices
    }

    mutating func setChoice(
        _ choice: MappingTransformReviewChoice?,
        for item: MappingTransformReviewItem
    ) {
        guard let choice, item.availableChoices.contains(choice) else {
            choices.removeValue(forKey: item.id)
            return
        }
        choices[item.id] = choice
    }
}

struct DeckCloneReviewSheet: View {
    let onApply: ([MappingTransformReviewItem.ID: MappingTransformReviewChoice]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: DeckCloneReviewState

    init(
        plan: MappingTransformPlan,
        onApply: @escaping (
            [MappingTransformReviewItem.ID: MappingTransformReviewChoice]
        ) -> Void
    ) {
        self.onApply = onApply
        _state = State(initialValue: DeckCloneReviewState(plan: plan))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            Text(
                DeckClonePresentation.reviewHeading(
                    itemCount: state.plan.reviewItems.count
                )
            )
            .font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(state.plan.reviewItems) { item in
                        reviewRow(item)
                        if item.id != state.plan.reviewItems.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxHeight: 320)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Clone") {
                    onApply(state.choices)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!state.canApply)
            }
        }
        .padding(AppThemeV2.Spacing.xl)
        .frame(width: 520)
    }

    private func reviewRow(_ item: MappingTransformReviewItem) -> some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.sourceMapping.commandName)
                    .lineLimit(1)
                Spacer()
                Text(item.destination.deckCloneTitle)
                    .foregroundStyle(.secondary)
            }

            if state.options(for: item).isEmpty {
                Text("Cannot clone safely.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Action", selection: choiceBinding(for: item)) {
                    ForEach(state.options(for: item), id: \.self) { choice in
                        Text(choice.deckCloneTitle)
                            .tag(Optional(choice))
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .padding(.vertical, AppThemeV2.Spacing.md)
    }

    private func choiceBinding(
        for item: MappingTransformReviewItem
    ) -> Binding<MappingTransformReviewChoice?> {
        Binding(
            get: { state.choices[item.id] },
            set: { state.setChoice($0, for: item) }
        )
    }
}

private extension DeckCloneDestination {
    var deckCloneTitle: String {
        switch self {
        case .deckB:
            "Deck B"
        case .deckC:
            "Deck C"
        case .deckD:
            "Deck D"
        }
    }
}
