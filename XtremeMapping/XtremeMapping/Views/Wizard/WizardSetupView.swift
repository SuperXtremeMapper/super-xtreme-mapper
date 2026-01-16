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
            Text("\(count) Channels")
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
    }

    private var headerSection: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppThemeV2.Colors.amber)
            Text("GUIDED MAPPING WIZARD")
                .font(AppThemeV2.Typography.display)
                .foregroundColor(AppThemeV2.Colors.stone200)
            Spacer()
        }
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
            formRow(label: "Controller Name") {
                TextField("Controller Name", text: $coordinator.setupConfig.controllerName)
                    .textFieldStyle(.plain)
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone200)
                    .padding(AppThemeV2.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm).fill(AppThemeV2.Colors.stone800))
            }
            formRow(label: "Number of Channels") {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    ChannelButton(count: 2, isSelected: coordinator.setupConfig.numberOfChannels == 2, action: { coordinator.setupConfig.numberOfChannels = 2 })
                    ChannelButton(count: 4, isSelected: coordinator.setupConfig.numberOfChannels == 4, action: { coordinator.setupConfig.numberOfChannels = 4 })
                    Spacer()
                }
            }
            formRow(label: "Device Target") {
                Picker("", selection: $coordinator.setupConfig.deviceTarget) {
                    Text("Focus").tag(TargetAssignment.deviceTarget)
                    Text("Deck A").tag(TargetAssignment.deckA)
                    Text("Deck B").tag(TargetAssignment.deckB)
                    Text("Deck C").tag(TargetAssignment.deckC)
                    Text("Deck D").tag(TargetAssignment.deckD)
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            formRow(label: "MIDI Input Port") {
                Picker("", selection: $coordinator.setupConfig.inputPort) {
                    Text("Select...").tag("")
                    ForEach(availableInputPorts, id: \.self) { port in
                        Text(port).tag(port)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            formRow(label: "MIDI Output Port") {
                Picker("", selection: $coordinator.setupConfig.outputPort) {
                    Text("No Output").tag("")
                    ForEach(availableOutputPorts, id: \.self) { port in
                        Text(port).tag(port)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
        .padding(AppThemeV2.Spacing.md)
        .background(RoundedRectangle(cornerRadius: AppThemeV2.Radius.md).fill(AppThemeV2.Colors.stone800))
    }

    private func formRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            Text(label.uppercased())
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(AppThemeV2.Colors.stone500)
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
        if coordinator.setupConfig.inputPort.isEmpty, let first = inputPorts.first {
            coordinator.setupConfig.inputPort = first
        }
    }

    private func getMIDIObjectName(_ obj: MIDIObjectRef) -> String? {
        var name: Unmanaged<CFString>?
        let result = MIDIObjectGetStringProperty(obj, kMIDIPropertyName, &name)
        if result == noErr, let cfName = name?.takeRetainedValue() { return cfName as String }
        return nil
    }
}
