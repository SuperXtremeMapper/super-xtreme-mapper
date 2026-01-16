//
//  ModeSelectionWindow.swift
//  XtremeMapping
//
//  Mode selection window: Voice Command or Guided Setup
//

import SwiftUI

struct ModeSelectionWindow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: AppThemeV2.Spacing.lg) {
            // Header
            headerSection

            V2Divider()

            // Options
            VStack(spacing: AppThemeV2.Spacing.md) {
                ModeOptionButton(
                    title: "Voice Command",
                    subtitle: "Speak commands to create mappings",
                    icon: "mic.fill",
                    caveat: "Requires Anthropic API key and Apple Silicon Mac",
                    action: selectVoiceMode
                )

                ModeOptionButton(
                    title: "Guided Setup",
                    subtitle: "Step-by-step wizard for common functions",
                    icon: "wand.and.stars",
                    caveat: nil,
                    action: selectGuidedMode
                )
            }
            .padding(.horizontal, AppThemeV2.Spacing.lg)

            Spacer()

            // Cancel button
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(AppThemeV2.Colors.stone700)
                )
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(AppThemeV2.Spacing.lg)
        }
        .frame(width: 420, height: 380)
        .background(AppThemeV2.Colors.stone800)
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        VStack(spacing: AppThemeV2.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(AppThemeV2.Colors.amberGlow)
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(AppThemeV2.Colors.amber)
            }

            Text("CREATE NEW MAPPING")
                .font(.system(size: 18, weight: .bold))
                .tracking(1.5)
                .foregroundColor(AppThemeV2.Colors.stone200)

            Text("Choose how you want to create your controller mapping")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppThemeV2.Spacing.lg)
        .padding(.horizontal, AppThemeV2.Spacing.lg)
    }

    private func selectVoiceMode() {
        dismiss()
        // Create new document and activate voice mode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSDocumentController.shared.newDocument(nil)
            // Post notification to activate voice mode
            NotificationCenter.default.post(name: .activateVoiceMode, object: nil)
        }
    }

    private func selectGuidedMode() {
        dismiss()
        // Create new document and open wizard
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSDocumentController.shared.newDocument(nil)
            // Post notification to open wizard
            NotificationCenter.default.post(name: .activateWizardMode, object: nil)
        }
    }
}

// MARK: - Mode Option Button

struct ModeOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let caveat: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppThemeV2.Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(isHovered ? AppThemeV2.Colors.amber : AppThemeV2.Colors.amberSubtle)
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isHovered ? AppThemeV2.Colors.stone900 : AppThemeV2.Colors.amber)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(AppThemeV2.Typography.display)
                        .tracking(0.5)
                        .foregroundColor(isHovered ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone100)

                    Text(subtitle)
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)

                    if let caveat = caveat {
                        Text(caveat)
                            .font(AppThemeV2.Typography.micro)
                            .foregroundColor(AppThemeV2.Colors.warning)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }
            .padding(.horizontal, AppThemeV2.Spacing.md)
            .padding(.vertical, AppThemeV2.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                    .fill(isHovered ? AppThemeV2.Colors.stone700 : AppThemeV2.Colors.stone800.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                    .stroke(isHovered ? AppThemeV2.Colors.amber.opacity(0.5) : AppThemeV2.Colors.stone700, lineWidth: 1)
            )
            .shadow(
                color: isHovered ? AppThemeV2.Colors.amberGlow : .clear,
                radius: isHovered ? 8 : 0
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let activateVoiceMode = Notification.Name("activateVoiceMode")
    static let activateWizardMode = Notification.Name("activateWizardMode")
}
