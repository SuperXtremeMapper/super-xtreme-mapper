//
//  WizardComponents.swift
//  XtremeMapping
//

import SwiftUI

// MARK: - Tab Button

struct WizardTabButton: View {
    let tab: WizardTab
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppThemeV2.Spacing.xxs) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(tab.rawValue)
                    .font(AppThemeV2.Typography.micro)
                    .lineLimit(1)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var foregroundColor: Color {
        if isSelected { return AppThemeV2.Colors.amber }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isSelected { return AppThemeV2.Colors.amberSubtle }
        if isHovered { return AppThemeV2.Colors.amberSubtle.opacity(0.5) }
        return Color.clear
    }
}

// MARK: - Assignment Indicator

struct AssignmentIndicator: View {
    let assignment: TargetAssignment
    let isCurrent: Bool
    let isCaptured: Bool

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Image(systemName: isCaptured ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isCaptured ? AppThemeV2.Colors.success : AppThemeV2.Colors.stone600)
            Text(assignment.displayName)
                .font(AppThemeV2.Typography.body)
                .foregroundColor(isCurrent ? AppThemeV2.Colors.stone200 : AppThemeV2.Colors.stone500)
        }
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(isCurrent ? AppThemeV2.Colors.stone700 : Color.clear)
        )
    }
}

// MARK: - MIDI Display

struct MIDIDisplayView: View {
    let midiMessage: MIDIMessage?

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            Image(systemName: "pianokeys")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(midiMessage != nil ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600)
            if let midi = midiMessage {
                Text(describeMIDI(midi))
                    .font(AppThemeV2.Typography.mono)
                    .foregroundColor(AppThemeV2.Colors.stone200)
            } else {
                Text("Waiting for MIDI input...")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .italic()
            }
            Spacer()
        }
        .padding(AppThemeV2.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                .fill(AppThemeV2.Colors.stone800)
        )
    }

    private func describeMIDI(_ message: MIDIMessage) -> String {
        if let cc = message.cc {
            return "Ch\(message.channel) CC \(String(format: "%03d", cc))"
        } else if let note = message.note {
            return "Ch\(message.channel) Note \(note)"
        }
        return "Ch\(message.channel) Value \(message.value)"
    }
}

// MARK: - Progress Bar

struct WizardProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                    .fill(AppThemeV2.Colors.stone700)
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                    .fill(AppThemeV2.Colors.amber)
                    .frame(width: geometry.size.width * CGFloat(progress))
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Basic/Advanced Toggle

struct ModeToggle: View {
    @Binding var isBasicMode: Bool

    var body: some View {
        HStack(spacing: 0) {
            ModeButton(title: "Basic", isSelected: isBasicMode) { isBasicMode = true }
            ModeButton(title: "Advanced", isSelected: !isBasicMode) { isBasicMode = false }
        }
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(AppThemeV2.Colors.stone800)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
        )
    }
}

private struct ModeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.vertical, AppThemeV2.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                        .fill(backgroundColor)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    private var foregroundColor: Color {
        if isSelected { return AppThemeV2.Colors.stone900 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isSelected { return AppThemeV2.Colors.amber }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return Color.clear
    }
}

// MARK: - Wizard Button Styles

struct WizardPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isHighlighted: Bool = false

    @State private var isHovered = false

    private var foregroundColor: Color {
        if !isEnabled { return AppThemeV2.Colors.stone500 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone200
    }

    private var backgroundColor: Color {
        if !isEnabled { return AppThemeV2.Colors.stone700 }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if !isEnabled { return AppThemeV2.Colors.stone600 }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .fontWeight(.semibold)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, AppThemeV2.Spacing.lg)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .shadow(
            color: isHovered && isEnabled ? AppThemeV2.Colors.amberGlow : .clear,
            radius: isHovered && isEnabled ? 8 : 0
        )
    }
}

struct WizardSecondaryButton: View {
    let title: String
    let action: () -> Void
    var isHighlighted: Bool = false
    var isPulsing: Bool = false

    @State private var isHovered = false

    private var foregroundColor: Color {
        if isHighlighted { return AppThemeV2.Colors.stone900 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isHighlighted { return AppThemeV2.Colors.amber }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isHighlighted { return AppThemeV2.Colors.amberLight }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(borderColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPulsing ? 1.05 : 1.0)
        .animation(
            isPulsing ?
                Animation.easeInOut(duration: 0.3).repeatForever(autoreverses: true) :
                .default,
            value: isPulsing
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .shadow(
            color: isPulsing ? AppThemeV2.Colors.amberGlow : (isHighlighted ? AppThemeV2.Colors.amberGlow : .clear),
            radius: isPulsing ? 12 : (isHighlighted ? 8 : 0)
        )
    }
}

// MARK: - Amber Toggle Style

struct AmberToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            configuration.label

            ZStack {
                // Track
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isOn ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone700)
                    .frame(width: 36, height: 20)

                // Thumb
                Circle()
                    .fill(configuration.isOn ? AppThemeV2.Colors.stone900 : AppThemeV2.Colors.stone400)
                    .frame(width: 16, height: 16)
                    .offset(x: configuration.isOn ? 8 : -8)
                    .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            }
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}
