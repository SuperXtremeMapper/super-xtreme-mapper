//
//  V2Toolbar.swift
//  SuperXtremeMapping
//
//  Custom toolbar matching website mockup style
//

import SwiftUI

/// Custom toolbar button with icon and optional glow
struct V2ToolbarButton: View {
    let icon: String
    let label: String?
    let action: () -> Void
    var isActive: Bool = false
    var isDestructive: Bool = false

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                if let label = label {
                    Text(label.uppercased())
                        .font(AppThemeV2.Typography.micro)
                        .tracking(0.5)
                }
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(borderColor, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .shadow(color: isActive ? AppThemeV2.Colors.amberGlow : .clear, radius: isActive ? 8 : 0)
    }

    private var foregroundColor: Color {
        if isDestructive { return AppThemeV2.Colors.danger }
        if isActive { return AppThemeV2.Colors.amber }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isActive { return AppThemeV2.Colors.amberSubtle }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isDestructive { return AppThemeV2.Colors.danger.opacity(0.5) }
        if isActive { return AppThemeV2.Colors.amber.opacity(0.5) }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}

/// Lock toggle button with special styling
struct V2LockButton: View {
    @Binding var isLocked: Bool

    var body: some View {
        Button {
            isLocked.toggle()
        } label: {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    .font(.system(size: 11, weight: .medium))

                Text(isLocked ? "LOCKED" : "UNLOCKED")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
            }
            .foregroundColor(isLocked ? AppThemeV2.Colors.danger : AppThemeV2.Colors.success)
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(isLocked ? AppThemeV2.Colors.danger.opacity(0.15) : AppThemeV2.Colors.success.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(isLocked ? AppThemeV2.Colors.danger.opacity(0.4) : AppThemeV2.Colors.success.opacity(0.4), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isLocked)
    }
}

/// Lock toggle button with icon only, matching other button styling
struct V2LockButtonIcon: View {
    @Binding var isLocked: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: { isLocked.toggle() }) {
            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(borderColor, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(isLocked ? "Unlock editing" : "Lock editing")
    }

    private var foregroundColor: Color {
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}

/// The main V2 action toolbar
struct V2ActionBar: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var isLocked: Bool
    @Binding var categoryFilter: CommandCategory
    @Binding var ioFilter: IODirection
    @State private var searchText: String = ""

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.md) {
            // Left side - Add buttons
            HStack(spacing: AppThemeV2.Spacing.xs) {
                V2ToolbarButton(icon: "plus", label: "In", action: addInput)
                V2ToolbarButton(icon: "plus", label: "Out", action: addOutput)

                Divider()
                    .frame(height: 20)
                    .background(AppThemeV2.Colors.stone600)

                V2ToolbarButton(icon: "wand.and.stars", label: nil, action: {})
                V2ToolbarButton(icon: "slider.horizontal.3", label: nil, action: {})
            }

            Spacer()

            // Center - Filters
            HStack(spacing: AppThemeV2.Spacing.md) {
                V2FilterPillRow(label: nil, selection: $categoryFilter)
                V2IOFilterPills(selection: $ioFilter)
            }

            Spacer()

            // Right side - Search and Lock
            HStack(spacing: AppThemeV2.Spacing.sm) {
                V2SearchField(text: $searchText, placeholder: "Search...")
                    .frame(width: 140)

                V2LockButton(isLocked: $isLocked)
            }
        }
        .padding(.horizontal, AppThemeV2.Spacing.lg)
        .padding(.vertical, AppThemeV2.Spacing.sm)
        .background(AppThemeV2.Colors.stone800)
        .overlay(
            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private func addInput() {
        // Add input mapping
    }

    private func addOutput() {
        // Add output mapping
    }
}

// MARK: - Preview

#Preview("V2 Toolbar") {
    VStack(spacing: 0) {
        V2ActionBar(
            document: TraktorMappingDocument(),
            isLocked: .constant(false),
            categoryFilter: .constant(.all),
            ioFilter: .constant(.all)
        )

        Rectangle()
            .fill(AppThemeV2.Colors.stone800)
            .frame(height: 300)
    }
    .frame(width: 900)
    .preferredColorScheme(.dark)
}

#Preview("V2 Toolbar Locked") {
    VStack(spacing: 0) {
        V2ActionBar(
            document: TraktorMappingDocument(),
            isLocked: .constant(true),
            categoryFilter: .constant(.decks),
            ioFilter: .constant(.input)
        )

        Rectangle()
            .fill(AppThemeV2.Colors.stone800)
            .frame(height: 300)
    }
    .frame(width: 900)
    .preferredColorScheme(.dark)
}
