//
//  WizardSetupView.swift
//  XtremeMapping
//

import SwiftUI
import CoreMIDI

// MARK: - Channel Button

struct ChannelButton: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(count == 1 ? "1 Channel" : "\(count) Channels")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(isSelected ? AppThemeV2.Colors.stone900 : (isHovered ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone400))
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(isSelected ? AppThemeV2.Colors.amber : (isHovered ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone700))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(isSelected ? AppThemeV2.Colors.amberLight : (isHovered ? AppThemeV2.Colors.amber.opacity(0.5) : Color.clear), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .shadow(
            color: isSelected ? AppThemeV2.Colors.amberGlow : .clear,
            radius: isSelected ? 8 : 0
        )
    }
}

// MARK: - Wizard Setup View

struct WizardSetupView: View {
    @ObservedObject var coordinator: WizardCoordinator
    @State private var availableInputPorts: [String] = []
    @State private var availableOutputPorts: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            headerSection
            V2Divider()
            formSection
            Spacer()
            buttonSection
        }
        .padding(AppThemeV2.Spacing.lg)
        .onAppear { loadMIDIPorts() }
        .onChange(of: coordinator.setupConfig.inputPort) { _, newInput in
            // Auto-sync output port to match input port if available
            if availableOutputPorts.contains(newInput) {
                coordinator.setupConfig.outputPort = newInput
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppThemeV2.Colors.amber)
            Text("GUIDED MAPPING SETUP")
                .font(AppThemeV2.Typography.display)
                .foregroundColor(AppThemeV2.Colors.stone200)
            Spacer()
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
            formRow(label: "Controller Name") {
                V2TextField(placeholder: "Controller name", text: $coordinator.setupConfig.controllerName)
                    .frame(maxWidth: 320)
            }
            formRow(label: "Number of Channels") {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    ChannelButton(count: 1, isSelected: coordinator.setupConfig.numberOfChannels == 1, action: { coordinator.setupConfig.numberOfChannels = 1 })
                    ChannelButton(count: 2, isSelected: coordinator.setupConfig.numberOfChannels == 2, action: { coordinator.setupConfig.numberOfChannels = 2 })
                    ChannelButton(count: 4, isSelected: coordinator.setupConfig.numberOfChannels == 4, action: { coordinator.setupConfig.numberOfChannels = 4 })
                    Spacer()
                }
            }
            formRow(label: "Device Target") {
                V2Dropdown(
                    options: [.deviceTarget, .deckA, .deckB, .deckC, .deckD],
                    selection: $coordinator.setupConfig.deviceTarget,
                    labelFor: deviceTargetLabel
                )
            }
            formRow(label: "MIDI Input Port") {
                V2Dropdown(
                    options: [""] + availableInputPorts,
                    selection: $coordinator.setupConfig.inputPort,
                    labelFor: { $0.isEmpty ? "Select…" : $0 }
                )
            }
            formRow(label: "MIDI Output Port") {
                V2Dropdown(
                    options: [""] + availableOutputPorts,
                    selection: $coordinator.setupConfig.outputPort,
                    labelFor: { $0.isEmpty ? "No Output" : $0 }
                )
            }
        }
        .padding(AppThemeV2.Spacing.md)
        .background(RoundedRectangle(cornerRadius: AppThemeV2.Radius.md).fill(AppThemeV2.Colors.stone800))
    }

    private func deviceTargetLabel(_ target: TargetAssignment) -> String {
        switch target {
        case .deviceTarget: return "Focus"
        case .deckA: return "Deck A"
        case .deckB: return "Deck B"
        case .deckC: return "Deck C"
        case .deckD: return "Deck D"
        default: return target.displayName
        }
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            Text(label.uppercased())
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(AppThemeV2.Colors.amber)
            content()
        }
    }

    private var buttonSection: some View {
        HStack {
            WizardSecondaryButton(title: "Cancel") { coordinator.cancel() }
                .keyboardShortcut(.escape, modifiers: [])
            Spacer()
            WizardPrimaryButton(title: "Start Wizard", action: { coordinator.beginLearning() }, isEnabled: coordinator.setupConfig.isValid)
                .keyboardShortcut(.return, modifiers: [])
        }
    }

    private func loadMIDIPorts() {
        var inputPorts: [String] = []
        var outputPorts: [String] = []
        let sourceCount = MIDIGetNumberOfSources()
        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let name = getMIDIObjectName(source) { inputPorts.append(name) }
        }
        let destCount = MIDIGetNumberOfDestinations()
        for i in 0..<destCount {
            let dest = MIDIGetDestination(i)
            if let name = getMIDIObjectName(dest) { outputPorts.append(name) }
        }
        availableInputPorts = inputPorts
        availableOutputPorts = outputPorts

        // Default input port to first available
        if coordinator.setupConfig.inputPort.isEmpty, let first = inputPorts.first {
            coordinator.setupConfig.inputPort = first
            // Also default output port to same device if available
            if outputPorts.contains(first) {
                coordinator.setupConfig.outputPort = first
            }
        }
    }

    private func getMIDIObjectName(_ obj: MIDIObjectRef) -> String? {
        var name: Unmanaged<CFString>?
        let result = MIDIObjectGetStringProperty(obj, kMIDIPropertyName, &name)
        if result == noErr, let cfName = name?.takeRetainedValue() { return cfName as String }
        return nil
    }
}
