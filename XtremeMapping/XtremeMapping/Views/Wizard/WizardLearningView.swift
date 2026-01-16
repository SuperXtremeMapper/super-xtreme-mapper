//
//  WizardLearningView.swift
//  XtremeMapping
//

import SwiftUI

struct WizardLearningView: View {
    @ObservedObject var coordinator: WizardCoordinator

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            tabContentSection
            navigationSection
        }
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppThemeV2.Spacing.sm) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppThemeV2.Colors.amber)
                Text("GUIDED MAPPING WIZARD")
                    .font(AppThemeV2.Typography.display)
                    .foregroundColor(AppThemeV2.Colors.stone200)
                Spacer()
                ModeToggle(isBasicMode: $coordinator.isBasicMode)
            }
            .padding(AppThemeV2.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    ForEach(WizardTab.allCases) { tab in
                        WizardTabButton(tab: tab, isSelected: coordinator.currentTab == tab) {
                            coordinator.switchToTab(tab)
                        }
                    }
                }
                .padding(.horizontal, AppThemeV2.Spacing.md)
            }
            .padding(.bottom, AppThemeV2.Spacing.sm)

            WizardProgressBar(progress: coordinator.tabProgress)
                .padding(.horizontal, AppThemeV2.Spacing.md)
            V2Divider().padding(.top, AppThemeV2.Spacing.sm)
        }
        .background(AppThemeV2.Colors.stone800)
    }

    private var tabContentSection: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            if let function = coordinator.currentFunction {
                functionSection(function)
            } else {
                tabCompleteSection
            }
            MIDIDisplayView(midiMessage: coordinator.pendingMIDI)
            Text(coordinator.statusMessage)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .frame(maxWidth: .infinity, alignment: .center)
            Spacer()
        }
        .padding(AppThemeV2.Spacing.lg)
    }

    private func functionSection(_ function: WizardFunction) -> some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
            Text(function.displayName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(AppThemeV2.Colors.stone200)
            HStack(spacing: AppThemeV2.Spacing.sm) {
                Image(systemName: controllerTypeIcon(function.controllerType))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppThemeV2.Colors.stone500)
                Text(controllerTypeHint(function.controllerType))
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }
            if coordinator.currentAssignments.count > 1 {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    ForEach(coordinator.currentAssignments, id: \.self) { assignment in
                        AssignmentIndicator(
                            assignment: assignment,
                            isCurrent: assignment == coordinator.currentAssignment,
                            isCaptured: coordinator.isCaptured(function: function, assignment: assignment)
                        )
                    }
                }
            }
        }
        .padding(AppThemeV2.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppThemeV2.Radius.md).fill(AppThemeV2.Colors.stone800))
    }

    private var tabCompleteSection: some View {
        VStack(spacing: AppThemeV2.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppThemeV2.Colors.success)
            Text("Tab Complete!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppThemeV2.Colors.stone200)
            Text("Click Next to continue to the next section, or Save & Finish.")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .multilineTextAlignment(.center)
        }
        .padding(AppThemeV2.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppThemeV2.Radius.md).fill(AppThemeV2.Colors.stone800))
    }

    private func controllerTypeIcon(_ type: ControllerType) -> String {
        switch type {
        case .button: return "circle.circle"
        case .faderOrKnob: return "slider.vertical.3"
        case .encoder: return "dial.min"
        case .led, .none: return "lightbulb"
        }
    }

    private func controllerTypeHint(_ type: ControllerType) -> String {
        switch type {
        case .button: return "Press a button"
        case .faderOrKnob: return "Move a fader or knob"
        case .encoder: return "Turn an encoder"
        case .led, .none: return "Press any control"
        }
    }

    private var navigationSection: some View {
        VStack(spacing: 0) {
            V2Divider()
            HStack {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    WizardSecondaryButton(title: "Cancel") { coordinator.cancel() }
                        .keyboardShortcut(.escape, modifiers: [])
                    WizardSecondaryButton(title: "Prev") { coordinator.previous() }
                        .keyboardShortcut(.leftArrow, modifiers: [])
                }
                Spacer()
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    WizardSecondaryButton(title: "Skip") { coordinator.skip() }
                    WizardSecondaryButton(title: "Next", action: { coordinator.next() }, isHighlighted: !coordinator.isAtLastStep)
                        .keyboardShortcut(.rightArrow, modifiers: [])
                    WizardPrimaryButton(title: "Save & Finish", action: { coordinator.saveToDocument() }, isEnabled: !coordinator.capturedMappings.isEmpty, isHighlighted: coordinator.isAtLastStep)
                        .keyboardShortcut(.return, modifiers: [.command])
                }
            }
            .padding(AppThemeV2.Spacing.md)
            .background(AppThemeV2.Colors.stone800)
        }
    }
}
