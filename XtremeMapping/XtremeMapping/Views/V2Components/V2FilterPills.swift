//
//  V2FilterPills.swift
//  SuperXtremeMapping
//
//  Custom pill-shaped filter buttons matching website mockup style
//

import SwiftUI

/// A single pill-shaped filter button
struct V2FilterPill<T: Hashable>: View {
    let title: String
    let value: T
    @Binding var selection: T

    private var isSelected: Bool {
        selection == value
    }

    var body: some View {
        Button(action: { selection = value }) {
            Text(title.uppercased())
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(isSelected ? AppThemeV2.Colors.stone950 : AppThemeV2.Colors.stone500)
                .padding(.horizontal, AppThemeV2.Spacing.sm)
                .padding(.vertical, AppThemeV2.Spacing.xs)
                .background(
                    Capsule()
                        .fill(isSelected ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone700)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/// A row of filter pills for category selection
struct V2FilterPillRow<T: Hashable & CaseIterable>: View where T.AllCases: RandomAccessCollection, T: RawRepresentable, T.RawValue == String {
    let label: String?
    @Binding var selection: T

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            if let label = label {
                Text(label)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }

            ForEach(Array(T.allCases), id: \.self) { item in
                V2FilterPill(title: item.rawValue, value: item, selection: $selection)
            }
        }
    }
}

/// IO Direction filter pills (In/Out/All)
struct V2IOFilterPills: View {
    @Binding var selection: IODirection

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.xxs) {
            ForEach(IODirection.allCases, id: \.self) { direction in
                Button(action: { selection = direction }) {
                    Group {
                        switch direction {
                        case .all:
                            Text("ALL")
                        case .input:
                            Text("IN")
                        case .output:
                            Text("OUT")
                        }
                    }
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(pillForeground(for: direction))
                    .padding(.horizontal, AppThemeV2.Spacing.sm)
                    .padding(.vertical, AppThemeV2.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(pillBackground(for: direction))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func pillForeground(for direction: IODirection) -> Color {
        if selection == direction {
            return AppThemeV2.Colors.stone950
        }
        return AppThemeV2.Colors.stone500
    }

    private func pillBackground(for direction: IODirection) -> Color {
        guard selection == direction else {
            return AppThemeV2.Colors.stone700
        }
        switch direction {
        case .all: return AppThemeV2.Colors.amber
        case .input: return AppThemeV2.Colors.stone300
        case .output: return AppThemeV2.Colors.amber
        }
    }
}

/// Search field matching mockup style - subdued appearance to reduce visual weight
struct V2SearchField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppThemeV2.Colors.stone600)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone400)
        }
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(AppThemeV2.Colors.stone800)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Filter Pills") {
    VStack(spacing: 20) {
        // Category pills
        HStack {
            Text("Category:")
                .foregroundColor(AppThemeV2.Colors.stone500)
            V2FilterPillRow(label: nil, selection: .constant(CommandCategory.all))
        }

        // IO pills
        HStack {
            Text("I/O:")
                .foregroundColor(AppThemeV2.Colors.stone500)
            V2IOFilterPills(selection: .constant(.all))
        }

        // Search
        V2SearchField(text: .constant(""), placeholder: "Search...")
            .frame(width: 150)
    }
    .padding(40)
    .background(AppThemeV2.Colors.stone800)
    .preferredColorScheme(.dark)
}
