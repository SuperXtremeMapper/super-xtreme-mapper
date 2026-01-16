//
//  APIKeySettingsView.swift
//  XtremeMapping
//
//  Settings view for managing the Anthropic API key.
//

import SwiftUI

/// Settings view for configuring the Anthropic API key.
///
/// Provides a secure text field for entering the API key, with validation
/// feedback and save/clear functionality. The key is stored securely in
/// the macOS Keychain via APIKeyManager.
struct APIKeySettingsView: View {

    // MARK: - State

    @StateObject private var apiKeyManager = APIKeyManager.shared
    @State private var apiKeyInput: String = ""
    @State private var showingSaveConfirmation = false
    @State private var showingClearConfirmation = false
    @State private var validationState: ValidationState = .empty
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    // MARK: - Validation State

    private enum ValidationState {
        case empty
        case invalid
        case valid
        case saved

        var message: String {
            switch self {
            case .empty:
                return "Enter your Anthropic API key"
            case .invalid:
                return "Key should start with 'sk-ant-'"
            case .valid:
                return "Key format looks valid"
            case .saved:
                return "API key saved securely"
            }
        }

        var color: Color {
            switch self {
            case .empty:
                return AppThemeV2.Colors.stone500
            case .invalid:
                return AppThemeV2.Colors.danger
            case .valid:
                return AppThemeV2.Colors.success
            case .saved:
                return AppThemeV2.Colors.success
            }
        }

        var icon: String {
            switch self {
            case .empty:
                return "key"
            case .invalid:
                return "exclamationmark.triangle"
            case .valid:
                return "checkmark.circle"
            case .saved:
                return "checkmark.seal.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
                Text("API KEY")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(1)
                    .foregroundColor(AppThemeV2.Colors.amber)

                Text("Configure your Anthropic API key for Voice Learn")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // API Key Input Section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
                // Label
                Text("ANTHROPIC API KEY")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                // Secure text field
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    SecureField("sk-ant-...", text: $apiKeyInput)
                        .textFieldStyle(.plain)
                        .font(AppThemeV2.Typography.mono)
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .padding(AppThemeV2.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .fill(AppThemeV2.Colors.stone800)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .stroke(validationState.color.opacity(0.5), lineWidth: 1)
                        )
                        .onChange(of: apiKeyInput) { _, newValue in
                            updateValidationState(for: newValue)
                        }
                }

                // Validation feedback
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Image(systemName: validationState.icon)
                        .font(.system(size: 10))
                    Text(validationState.message)
                        .font(AppThemeV2.Typography.caption)
                }
                .foregroundColor(validationState.color)

                // Action buttons
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    // Save button
                    Button(action: saveAPIKey) {
                        HStack(spacing: AppThemeV2.Spacing.xs) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                            Text("SAVE")
                                .font(AppThemeV2.Typography.micro)
                                .tracking(0.5)
                        }
                        .foregroundColor(AppThemeV2.Colors.stone950)
                        .padding(.horizontal, AppThemeV2.Spacing.md)
                        .padding(.vertical, AppThemeV2.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .fill(validationState == .valid ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(validationState != .valid)

                    // Clear button
                    Button(action: { showingClearConfirmation = true }) {
                        HStack(spacing: AppThemeV2.Spacing.xs) {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .medium))
                            Text("CLEAR")
                                .font(AppThemeV2.Typography.micro)
                                .tracking(0.5)
                        }
                        .foregroundColor(apiKeyManager.hasAPIKey ? AppThemeV2.Colors.danger : AppThemeV2.Colors.stone600)
                        .padding(.horizontal, AppThemeV2.Spacing.md)
                        .padding(.vertical, AppThemeV2.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .fill(AppThemeV2.Colors.stone800)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .stroke(apiKeyManager.hasAPIKey ? AppThemeV2.Colors.danger.opacity(0.3) : AppThemeV2.Colors.stone700, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!apiKeyManager.hasAPIKey)

                    Spacer()
                }
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Help section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                Text("GET YOUR API KEY")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                Button(action: openAnthropicConsole) {
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                        Text("console.anthropic.com")
                            .font(AppThemeV2.Typography.body)
                            .underline()
                    }
                    .foregroundColor(AppThemeV2.Colors.amber)
                }
                .buttonStyle(.plain)

                Text("Sign up or log in to get your API key. Voice Learn uses Claude Haiku for fast, low-cost command interpretation (~$0.003/request).")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Support section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                Text("SUPPORT SXM")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                Text("Super Xtreme Mapper is free and open source. If you find it useful, consider supporting development!")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppThemeV2.Spacing.sm) {
                    Button(action: { openURL(URL(string: "https://github.com/sponsors/nraford7")!) }) {
                        HStack(spacing: AppThemeV2.Spacing.xs) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text("SPONSOR")
                                .font(AppThemeV2.Typography.micro)
                                .tracking(0.5)
                        }
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .padding(.horizontal, AppThemeV2.Spacing.md)
                        .padding(.vertical, AppThemeV2.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .fill(AppThemeV2.Colors.stone700)
                        )
                    }
                    .buttonStyle(.plain)

                    CoffeeButton(openURL: openURL)
                }
            }

            Spacer()

            // Bottom row: Status and Done button
            HStack {
                // Status indicator
                if apiKeyManager.hasAPIKey {
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Circle()
                            .fill(AppThemeV2.Colors.success)
                            .frame(width: 6, height: 6)
                        Text("API key configured")
                            .font(AppThemeV2.Typography.caption)
                            .foregroundColor(AppThemeV2.Colors.success)
                    }
                }

                Spacer()

                // Done button
                Button {
                    dismiss()
                } label: {
                    Text("DONE")
                        .font(AppThemeV2.Typography.micro)
                        .tracking(0.5)
                        .fontWeight(.semibold)
                        .foregroundColor(AppThemeV2.Colors.stone900)
                        .padding(.horizontal, AppThemeV2.Spacing.lg)
                        .padding(.vertical, AppThemeV2.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .fill(AppThemeV2.Colors.amber)
                        )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(AppThemeV2.Spacing.xl)
        .frame(width: 400, height: 500)
        .background(AppThemeV2.Colors.stone800)
        .preferredColorScheme(.dark)
        .onAppear {
            // Initialize with masked indication if key exists
            if apiKeyManager.hasAPIKey {
                validationState = .saved
            }
        }
        .alert("Clear API Key?", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearAPIKey()
            }
        } message: {
            Text("This will remove your API key from the Keychain. Voice Learn will not work until you enter a new key.")
        }
    }

    // MARK: - Actions

    private func updateValidationState(for key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            validationState = apiKeyManager.hasAPIKey ? .saved : .empty
        } else if APIKeyManager.isValidKeyFormat(trimmed) {
            validationState = .valid
        } else {
            validationState = .invalid
        }
    }

    private func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard APIKeyManager.isValidKeyFormat(trimmed) else { return }

        if apiKeyManager.saveAPIKey(trimmed) {
            apiKeyInput = ""
            validationState = .saved
            showingSaveConfirmation = true

            // Auto-dismiss confirmation after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showingSaveConfirmation = false
            }
        }
    }

    private func clearAPIKey() {
        apiKeyManager.deleteAPIKey()
        apiKeyInput = ""
        validationState = .empty
    }

    private func openAnthropicConsole() {
        if let url = URL(string: "https://console.anthropic.com") {
            openURL(url)
        }
    }
}

// MARK: - Preview

#Preview {
    APIKeySettingsView()
}
