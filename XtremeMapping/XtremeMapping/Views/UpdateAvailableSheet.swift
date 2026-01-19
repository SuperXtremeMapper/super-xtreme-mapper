//
//  UpdateAvailableSheet.swift
//  XtremeMapping
//
//  Modal dialog shown when an update is available.
//

import SwiftUI

struct UpdateAvailableSheet: View {
    let release: GitHubRelease
    let onDismiss: () -> Void

    @StateObject private var updateService = UpdateService.shared
    @State private var ignoreVersion = false
    @State private var errorMessage: String?
    @State private var showError = false

    private var remoteVersion: String {
        updateService.parseVersion(from: release.tagName)
    }

    var body: some View {
        VStack(spacing: AppThemeV2.Spacing.lg) {
            // Header
            VStack(spacing: AppThemeV2.Spacing.sm) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)

                Text("Update Available")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppThemeV2.Colors.stone200)

                Text("v\(remoteVersion) is now available")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }

            // Release Notes
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
                Text("What's New:")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
                    .textCase(.uppercase)

                ScrollView {
                    Text(release.body)
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone300)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .padding(AppThemeV2.Spacing.sm)
                .background(AppThemeV2.Colors.stone800)
                .cornerRadius(AppThemeV2.Radius.sm)
            }

            // Ignore checkbox (hidden during download)
            if !updateService.isDownloading {
                Toggle(isOn: $ignoreVersion) {
                    Text("Ignore this version")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
                .toggleStyle(.checkbox)
            }

            // Progress bar (shown during download)
            if updateService.isDownloading {
                VStack(spacing: AppThemeV2.Spacing.xs) {
                    ProgressView(value: updateService.downloadProgress)
                        .progressViewStyle(.linear)
                        .tint(AppThemeV2.Colors.amber)

                    Text("\(Int(updateService.downloadProgress * 100))%")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
            }

            // Buttons
            if !updateService.isDownloading {
                HStack(spacing: AppThemeV2.Spacing.md) {
                    Button("Not Now") {
                        if ignoreVersion {
                            UpdatePreferences.ignore(version: remoteVersion)
                        }
                        onDismiss()
                    }
                    .buttonStyle(UpdateSecondaryButtonStyle())

                    Spacer()

                    Button("Download") {
                        Task {
                            await downloadUpdate()
                        }
                    }
                    .buttonStyle(UpdatePrimaryButtonStyle())
                }
            }
        }
        .padding(AppThemeV2.Spacing.xl)
        .frame(width: 400)
        .background(AppThemeV2.Colors.stone900)
        .alert("Download Error", isPresented: $showError) {
            Button("Open Website") {
                updateService.openWebsiteDownload()
                onDismiss()
            }
            Button("Cancel", role: .cancel) {
                onDismiss()
            }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    private func downloadUpdate() async {
        guard let asset = updateService.findDMGAsset(in: release) else {
            errorMessage = UpdateError.noDMGAsset.errorDescription
            showError = true
            return
        }

        do {
            let dmgURL = try await updateService.downloadUpdate(asset: asset)
            try updateService.mountDMG(at: dmgURL)
            onDismiss()
        } catch let error as UpdateError {
            errorMessage = error.errorDescription
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Button Styles

private struct UpdatePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppThemeV2.Typography.caption)
            .fontWeight(.semibold)
            .foregroundColor(AppThemeV2.Colors.stone900)
            .padding(.horizontal, AppThemeV2.Spacing.lg)
            .padding(.vertical, AppThemeV2.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(configuration.isPressed ? AppThemeV2.Colors.amber.opacity(0.8) : AppThemeV2.Colors.amber)
            )
    }
}

private struct UpdateSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppThemeV2.Typography.caption)
            .foregroundColor(AppThemeV2.Colors.stone300)
            .padding(.horizontal, AppThemeV2.Spacing.lg)
            .padding(.vertical, AppThemeV2.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
