//
//  WelcomeView.swift
//  XXtremeMapping
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
            VStack(spacing: 12) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)

                Text("XXtreme Mapping")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("BETA v0.1")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentColor)

                Text("A revived TSI Editor for Traktor,\nin the spirit of Xtreme Mapping (RIP)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.mutedTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 32)
            .padding(.bottom, 32)

            // Options
            VStack(spacing: 16) {
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
            .padding(.bottom, 32)

            Spacer()

            // Footer with beta warning
            Text("Warning: This is a private beta for testing purposes only. Be sure to make a copy of any .tsi file you want to edit… just in case it gets totally fucked.")
                .font(.caption2)
                .foregroundColor(AppTheme.mutedTextColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .frame(width: 420, height: 580)
        .background(AppTheme.surfaceColor)
    }
}

/// A styled button for the welcome screen
struct WelcomeButton: View {
    let title: String
    let subtitle: String
    let icon: String
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isDisabled ? AppTheme.mutedTextColor : AppTheme.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isDisabled ? AppTheme.mutedTextColor : .primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.mutedTextColor)
                }

                Spacer()

                if !isDisabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.mutedTextColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .fill(isHovered && !isDisabled ? AppTheme.hoverColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(isDisabled ? AppTheme.mutedTextColor.opacity(0.3) : AppTheme.dividerColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    WelcomeView(
        onNewMapping: {},
        onOpenMapping: {}
    )
}
