//
//  WelcomeView.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI

/// Welcome screen shown on app launch with options to create, open, or use wizard
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    var onNewMapping: () -> Void
    var onOpenMapping: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AppThemeV2.Spacing.md) {
                // Logo with glow effect
                ZStack {
                    // Glow behind logo
                    Circle()
                        .fill(AppThemeV2.Colors.amberGlow)
                        .frame(width: 100, height: 100)
                        .blur(radius: 30)

                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                }

                // App name with amber accent
                VStack(spacing: AppThemeV2.Spacing.xs) {
                    Text("SUPER XTREME")
                        .font(.system(size: 24, weight: .black))
                        .tracking(2)
                        .foregroundColor(AppThemeV2.Colors.stone100)

                    Text("MAPPER")
                        .font(.system(size: 32, weight: .black))
                        .tracking(4)
                        .foregroundColor(AppThemeV2.Colors.amber)
                }

                // Version badge
                Text("BETA v0.1")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(1)
                    .fontWeight(.bold)
                    .foregroundColor(AppThemeV2.Colors.stone950)
                    .padding(.horizontal, AppThemeV2.Spacing.sm)
                    .padding(.vertical, AppThemeV2.Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(AppThemeV2.Colors.amber)
                    )

                // Tagline
                Text("A revived TSI Editor for Traktor,\nin the spirit of Xtreme Mapping (RIP)")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone400)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 40)
            .padding(.bottom, 40)

            // Divider
            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)
                .padding(.horizontal, 32)

            // Options
            VStack(spacing: AppThemeV2.Spacing.md) {
                WelcomeButton(
                    title: "New Mapping",
                    subtitle: "Create a blank controller mapping",
                    icon: "doc.badge.plus",
                    action: {
                        onNewMapping()
                        dismiss()
                    }
                )

                WelcomeButton(
                    title: "Open Mapping",
                    subtitle: "Open an existing .tsi file",
                    icon: "folder",
                    action: {
                        onOpenMapping()
                        dismiss()
                    }
                )

                WelcomeButton(
                    title: "Mapping Wizard",
                    subtitle: "Coming soon...",
                    icon: "wand.and.stars",
                    isDisabled: true,
                    action: {}
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 32)

            Spacer()

            // Footer with beta warning
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Circle()
                    .fill(AppThemeV2.Colors.amber)
                    .frame(width: 6, height: 6)

                Text("Warning: This is a private beta for testing purposes only. Be sure to make a copy of any .tsi file you want to edit... just in case it gets totally fucked.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.amber.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(width: 420, height: 680)
        .background(AppThemeV2.Colors.stone900)
        .preferredColorScheme(.dark)
    }
}

/// A styled button for the welcome screen with V2 styling
struct WelcomeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppThemeV2.Spacing.md) {
                // Icon with background
                ZStack {
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(isDisabled ? AppThemeV2.Colors.stone700 : AppThemeV2.Colors.amberSubtle)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isDisabled ? AppThemeV2.Colors.stone500 : AppThemeV2.Colors.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(AppThemeV2.Typography.display)
                        .tracking(0.5)
                        .foregroundColor(isDisabled ? AppThemeV2.Colors.stone500 : AppThemeV2.Colors.stone100)

                    Text(subtitle)
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                }

                Spacer()

                if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppThemeV2.Colors.stone500)
                }
            }
            .padding(.horizontal, AppThemeV2.Spacing.md)
            .padding(.vertical, AppThemeV2.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                    .fill(isHovered && !isDisabled ? AppThemeV2.Colors.stone800 : AppThemeV2.Colors.stone800.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                    .stroke(
                        isHovered && !isDisabled ? AppThemeV2.Colors.amber.opacity(0.5) : AppThemeV2.Colors.stone700,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isHovered && !isDisabled ? AppThemeV2.Colors.amberGlow : .clear,
                radius: isHovered ? 8 : 0
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    WelcomeView(
        onNewMapping: {},
        onOpenMapping: {}
    )
}
