//
//  V2TableRow.swift
//  SuperXtremeMapping
//
//  Custom table row styling matching website mockup
//

import SwiftUI

// MARK: - IO Badge

/// Badge showing IN or OUT with appropriate styling
struct V2IOBadge: View {
    let direction: IODirection

    var body: some View {
        Text(direction == .input ? "IN" : "OUT")
            .font(AppThemeV2.Typography.micro)
            .fontWeight(.bold)
            .tracking(0.5)
            .foregroundColor(direction == .input ? AppThemeV2.Colors.stone300 : AppThemeV2.Colors.stone950)
            .padding(.horizontal, AppThemeV2.Spacing.xs + 2)
            .padding(.vertical, AppThemeV2.Spacing.xxs)
            .background(
                Capsule()
                    .fill(direction == .input ? AppThemeV2.Colors.stone700 : AppThemeV2.Colors.amber)
            )
    }
}

// MARK: - Table Header

/// Custom table header row with amber text
struct V2TableHeader: View {
    var body: some View {
        HStack(spacing: 0) {
            headerCell("I/O", width: 60, alignment: .leading)
            headerCell("ASSIGNMENT", width: 90, alignment: .leading)
            headerCell("COMMAND", width: nil, alignment: .leading)  // Flexible
            headerCell("TYPE", width: 75, alignment: .leading)
            headerCell("INTERACTION", width: 80, alignment: .leading)
            headerCell("MIDI", width: 110, alignment: .leading)
            headerCell("MOD 1", width: 50, alignment: .leading)
            headerCell("MOD 2", width: 50, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppThemeV2.Colors.stone800)
        .overlay(
            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func headerCell(_ title: String, width: CGFloat?, alignment: Alignment = .leading) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(AppThemeV2.Colors.amber)
            .frame(width: width, alignment: alignment)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: alignment)
    }
}

// MARK: - Table Row

/// Custom table row for a mapping entry
struct V2MappingRow: View {
    let mapping: MappingEntry
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // I/O Badge
            V2IOBadge(direction: mapping.ioType)
                .frame(width: 50)

            // Assignment
            Text(mapping.assignment.displayName)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .frame(width: 80, alignment: .leading)

            // Command
            Text(mapping.commandName)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone300)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Controller Type
            Text(mapping.controllerType.displayName)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .frame(width: 70)

            // Interaction
            Text(mapping.interactionMode.displayName)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .frame(width: 80)

            // Mapped To (MIDI)
            Text(mapping.mappedToDisplay)
                .font(AppThemeV2.Typography.mono)
                .foregroundColor(AppThemeV2.Colors.stone300)
                .frame(width: 100)

            // Modifier 1
            modifierCell(mapping.modifier1Condition)
                .frame(width: 55)

            // Modifier 2
            modifierCell(mapping.modifier2Condition)
                .frame(width: 55)
        }
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs + 2)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                .fill(isSelected ? AppThemeV2.Colors.amberSubtle : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                .stroke(isSelected ? AppThemeV2.Colors.amber.opacity(0.4) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private func modifierCell(_ condition: ModifierCondition?) -> some View {
        if let cond = condition {
            Text(cond.displayString)
                .font(AppThemeV2.Typography.mono)
                .foregroundColor(AppThemeV2.Colors.stone300)
        } else {
            Text("-")
                .font(AppThemeV2.Typography.mono)
                .foregroundColor(AppThemeV2.Colors.stone600)
        }
    }
}

// MARK: - Complete Table View

/// Custom table view matching website mockup
struct V2MappingsTable: View {
    let mappings: [MappingEntry]
    @Binding var selection: Set<MappingEntry.ID>

    var body: some View {
        VStack(spacing: 0) {
            V2TableHeader()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(mappings) { mapping in
                        V2MappingRow(
                            mapping: mapping,
                            isSelected: selection.contains(mapping.id),
                            onSelect: { toggleSelection(mapping.id) }
                        )
                    }
                }
                .padding(.vertical, AppThemeV2.Spacing.xs)
            }
        }
        .background(AppThemeV2.Colors.stone950)
    }

    private func toggleSelection(_ id: MappingEntry.ID) {
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }
}

// MARK: - Preview

#Preview("Table Rows") {
    let sampleMappings = [
        MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .toggle,
            midiChannel: 1,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Tempo Bend +",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 20
        ),
        MappingEntry(
            commandName: "Play State",
            ioType: .output,
            assignment: .deckA,
            interactionMode: .output,
            midiChannel: 1,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Sync",
            ioType: .input,
            assignment: .deckB,
            interactionMode: .toggle,
            midiChannel: 2,
            midiNote: 43,
            modifier1Condition: ModifierCondition(modifier: 1, value: 0)
        ),
        MappingEntry(
            commandName: "Master Volume",
            ioType: .input,
            assignment: .global,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 7,
            modifier1Condition: ModifierCondition(modifier: 1, value: 1),
            modifier2Condition: ModifierCondition(modifier: 2, value: 0)
        )
    ]

    V2MappingsTable(
        mappings: sampleMappings,
        selection: .constant([sampleMappings[1].id])
    )
    .frame(width: 800, height: 300)
    .preferredColorScheme(.dark)
}
