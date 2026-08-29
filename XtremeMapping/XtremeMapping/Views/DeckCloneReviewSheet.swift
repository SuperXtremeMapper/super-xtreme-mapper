//
//  DeckCloneReviewSheet.swift
//  XtremeMapping
//

import SwiftUI

struct DeckCloneReviewRowPresentation: Equatable {
    let commandTitle: String
    let deviceTitle: String
    let destinationTitle: String
    let existingSummaries: [String]
    let cloneSummary: String?
    let choiceAccessibilityLabel: String
    let replacementAccessibilityLabel: String

    init(item: MappingTransformReviewItem, rowNumber: Int) {
        commandTitle = item.sourceMapping.commandName
        deviceTitle = item.sourceDeviceName
        destinationTitle = item.destination.deckCloneTitle
        existingSummaries = item.conflicts.map { Self.mappingSummary($0.mapping) }
        cloneSummary = item.proposedMapping.map { Self.mappingSummary($0) }

        choiceAccessibilityLabel = "Review item \(rowNumber): choose action for "
            + "\(commandTitle), \(destinationTitle), source device \(deviceTitle)."
        replacementAccessibilityLabel = "Review item \(rowNumber): choose mapping to replace "
            + "on source device \(deviceTitle)."
    }

    private static func mappingSummary(_ mapping: MappingEntry) -> String {
        "MIDI: \(mapping.mappedToDisplay); Comment: \(commentText(mapping.comment))"
    }

    private static func commentText(_ comment: String) -> String {
        comment.isEmpty ? "None" : comment
    }
}

struct DeckCloneReviewState {
    let plan: MappingTransformPlan
    private(set) var choices: [
        MappingTransformReviewItem.ID: MappingTransformReviewChoice
    ] = [:]
    private(set) var replacementTargets: [
        MappingTransformReviewItem.ID: MappingEntry.ID
    ] = [:]

    var decisions: [
        MappingTransformReviewItem.ID: MappingTransformReviewDecision
    ] {
        Dictionary(uniqueKeysWithValues: plan.reviewItems.compactMap { item in
            decision(for: item).map { (item.id, $0) }
        })
    }

    var canApply: Bool {
        !plan.reviewItems.isEmpty && plan.reviewItems.allSatisfy { item in
            !item.availableChoices.isEmpty && decision(for: item) != nil
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
            replacementTargets.removeValue(forKey: item.id)
            return
        }
        choices[item.id] = choice
        if choice == .replaceExisting, item.conflicts.count == 1 {
            replacementTargets[item.id] = item.conflicts[0].mapping.id
        } else if choice != .replaceExisting {
            replacementTargets.removeValue(forKey: item.id)
        }
    }

    mutating func setReplacementTarget(
        _ mappingID: MappingEntry.ID?,
        for item: MappingTransformReviewItem
    ) {
        guard let mappingID,
              item.conflicts.contains(where: { $0.mapping.id == mappingID }) else {
            replacementTargets.removeValue(forKey: item.id)
            return
        }
        replacementTargets[item.id] = mappingID
    }

    private func decision(
        for item: MappingTransformReviewItem
    ) -> MappingTransformReviewDecision? {
        switch choices[item.id] {
        case .keepExisting:
            .keepExisting
        case .createAnother:
            .createAnother
        case .replaceExisting:
            replacementTargets[item.id].map {
                .replaceExisting(existingMappingID: $0)
            }
        case nil:
            nil
        }
    }
}

struct DeckCloneReviewSheet: View {
    let onApply: ([MappingTransformReviewItem.ID: MappingTransformReviewDecision]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: DeckCloneReviewState

    init(
        plan: MappingTransformPlan,
        onApply: @escaping (
            [MappingTransformReviewItem.ID: MappingTransformReviewDecision]
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
                    ForEach(
                        Array(state.plan.reviewItems.enumerated()),
                        id: \.element.id
                    ) { offset, item in
                        reviewRow(item, rowNumber: offset + 1)
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
                    onApply(state.decisions)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!state.canApply)
            }
        }
        .padding(AppThemeV2.Spacing.xl)
        .frame(width: 520)
    }

    private func reviewRow(
        _ item: MappingTransformReviewItem,
        rowNumber: Int
    ) -> some View {
        let presentation = DeckCloneReviewRowPresentation(
            item: item,
            rowNumber: rowNumber
        )

        return VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.commandTitle)
                        .lineLimit(1)
                    Text(presentation.deviceTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(presentation.destinationTitle)
                    .foregroundStyle(.secondary)
            }

            ForEach(
                Array(presentation.existingSummaries.enumerated()),
                id: \.offset
            ) { offset, summary in
                mappingSummaryRow(label: offset == 0 ? "Existing" : "", summary: summary)
            }
            if let cloneSummary = presentation.cloneSummary {
                mappingSummaryRow(label: "Clone", summary: cloneSummary)
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
                .accessibilityLabel(presentation.choiceAccessibilityLabel)

                if state.choices[item.id] == .replaceExisting,
                   item.conflicts.count > 1 {
                    Picker("Replace", selection: replacementBinding(for: item)) {
                        Text("Choose mapping")
                            .tag(Optional<MappingEntry.ID>.none)
                        ForEach(Array(item.conflicts.enumerated()), id: \.element.id) {
                            offset, conflict in
                            Text("Existing \(offset + 1): \(conflict.mapping.mappedToDisplay)")
                                .tag(Optional(conflict.mapping.id))
                        }
                    }
                    .accessibilityLabel(presentation.replacementAccessibilityLabel)
                }
            }
        }
        .padding(.vertical, AppThemeV2.Spacing.md)
    }

    private func mappingSummaryRow(label: String, summary: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption.weight(.medium))
                .frame(width: 52, alignment: .leading)
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private func choiceBinding(
        for item: MappingTransformReviewItem
    ) -> Binding<MappingTransformReviewChoice?> {
        Binding(
            get: { state.choices[item.id] },
            set: { state.setChoice($0, for: item) }
        )
    }

    private func replacementBinding(
        for item: MappingTransformReviewItem
    ) -> Binding<MappingEntry.ID?> {
        Binding(
            get: { state.replacementTargets[item.id] },
            set: { state.setReplacementTarget($0, for: item) }
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
