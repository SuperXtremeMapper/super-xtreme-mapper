//
//  MappingWizardWindow.swift
//  XtremeMapping
//
//  Main container view for the Mapping Wizard window.
//

import SwiftUI
import AppKit

struct MappingWizardWindow: View {
    @ObservedObject var coordinator: WizardCoordinator
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Group {
            switch coordinator.phase {
            case .setup:
                WizardSetupView(coordinator: coordinator)

            case .learning:
                WizardLearningView(coordinator: coordinator)

            case .complete:
                wizardCompleteView
            }
        }
        .frame(width: 600, height: 500)
        .background(AppThemeV2.Colors.stone900)
        .alert("Overwrite Existing Mappings?", isPresented: $coordinator.showOverwriteAlert) {
            Button("Overwrite") {
                coordinator.performSave(overwrite: true)
            }
            Button("Add New Only") {
                coordinator.performSave(overwrite: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The following commands already have mappings: \(coordinator.conflictingCommands.joined(separator: ", "))")
        }
        .onChange(of: coordinator.phase) { _, newPhase in
            // When user cancels (returns to setup with no mappings), close window
            if newPhase == .setup && coordinator.capturedMappings.isEmpty && !coordinator.setupConfig.controllerName.isEmpty {
                dismiss()
            }
        }
        .onChange(of: coordinator.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                coordinator.shouldDismiss = false
                dismiss()
            }
        }
    }

    // MARK: - Complete View

    private var wizardCompleteView: some View {
        VStack(spacing: AppThemeV2.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(AppThemeV2.Colors.success)

            Text("Wizard Complete!")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(AppThemeV2.Colors.stone200)

            Text("\(coordinator.capturedMappings.count) mappings saved to your document.")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)

            Spacer()

            HStack {
                WizardSecondaryButton(title: "Start Over") {
                    coordinator.reset()
                }

                Spacer()

                WizardPrimaryButton(title: "Great!", action: {
                    dismiss()
                })
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(AppThemeV2.Spacing.lg)
        }
        .padding(AppThemeV2.Spacing.lg)
    }
}

// MARK: - Window Content Wrapper

/// Wrapper that creates the coordinator and passes document
struct MappingWizardWindowContent: View {
    @StateObject private var coordinator = WizardCoordinator()

    var body: some View {
        MappingWizardWindow(coordinator: coordinator)
            .onAppear {
                // First check for document passed via shared state (most reliable)
                if let doc = WizardCoordinator.pendingDocument {
                    coordinator.start(document: doc)
                    WizardCoordinator.pendingDocument = nil
                    return
                }

                // Fallback: try NSDocumentController
                if let doc = NSDocumentController.shared.currentDocument as? TraktorMappingDocument {
                    coordinator.start(document: doc)
                } else if let frontDoc = NSDocumentController.shared.documents.first as? TraktorMappingDocument {
                    coordinator.start(document: frontDoc)
                } else {
                    // Delay and retry - document may not be registered yet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let doc = NSDocumentController.shared.documents.first as? TraktorMappingDocument {
                            coordinator.start(document: doc)
                        } else {
                            coordinator.statusMessage = "Error: Please open a document first"
                        }
                    }
                }
            }
    }
}
