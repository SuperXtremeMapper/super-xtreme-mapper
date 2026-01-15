//
//  VoiceLearnOverlay.swift
//  XtremeMapping
//
//  Overlay UI for Voice Learn mode showing status, captured MIDI/voice, and disambiguation options.
//

import SwiftUI

/// Overlay displayed when voice mapping mode is active.
///
/// Shows:
/// - Status indicator (listening, processing, etc.)
/// - Pending MIDI indicator (if captured)
/// - Pending voice indicator (if captured)
/// - Disambiguation options (if confidence is low)
/// - Processing spinner when calling Claude API
struct VoiceLearnOverlay: View {
    @ObservedObject var coordinator: VoiceMappingCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            // Header with status
            headerSection

            V2Divider()

            // Two-row input section (always visible)
            inputRowsSection

            // Disambiguation options
            if let options = coordinator.disambiguationOptions {
                disambiguationSection(options: options)
            }

            // Processing indicator
            if coordinator.isProcessing {
                processingSection
            }

            // Instructions / status message
            statusSection

            // Bottom buttons: Cancel (left) and Next (right)
            buttonRow
        }
        .padding(AppThemeV2.Spacing.lg)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg)
                .fill(AppThemeV2.Colors.stone800)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg)
                .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 20)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            // Pulsing microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppThemeV2.Colors.amber)
                .shadow(color: AppThemeV2.Colors.amberGlow, radius: 8)

            Text("VOICE LEARN")
                .font(AppThemeV2.Typography.display)
                .foregroundColor(AppThemeV2.Colors.stone200)

            Spacer()

            // Status badge
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)

            Text(statusText.uppercased())
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.pill)
                .fill(statusColor.opacity(0.15))
        )
    }

    private var statusColor: Color {
        if coordinator.isProcessing {
            return AppThemeV2.Colors.amber
        } else if coordinator.disambiguationOptions != nil {
            return AppThemeV2.Colors.warning
        } else if coordinator.pendingMIDI != nil && coordinator.pendingVoice != nil {
            return AppThemeV2.Colors.success
        } else {
            return AppThemeV2.Colors.amber
        }
    }

    private var statusText: String {
        if coordinator.isProcessing {
            return "Processing"
        } else if coordinator.disambiguationOptions != nil {
            return "Choose"
        } else if coordinator.pendingMIDI != nil && coordinator.pendingVoice != nil {
            return "Ready"
        } else {
            return "Listening"
        }
    }

    // MARK: - Input Rows Section (Two rows: MIDI and Command)

    private var inputRowsSection: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            // Row 1: MIDI Input
            midiInputRow

            // Row 2: Command Result
            commandResultRow
        }
        .padding(AppThemeV2.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                .fill(AppThemeV2.Colors.stone800)
        )
    }

    private var midiInputRow: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            Image(systemName: "pianokeys")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(coordinator.pendingMIDI != nil ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600)
                .frame(width: 16)

            Text("MIDI")
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .frame(width: 50, alignment: .leading)

            if let midi = coordinator.pendingMIDI {
                Text(describeMIDI(midi))
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone300)
                    .lineLimit(1)
            } else {
                Text("Waiting for input...")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone600)
                    .italic()
            }

            Spacer()
        }
    }

    private var commandResultRow: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            Image(systemName: "waveform")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(coordinator.currentResult != nil ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600)
                .frame(width: 16)

            Text("CMD")
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .frame(width: 50, alignment: .leading)

            if let result = coordinator.currentResult {
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Text(result.command)
                        .font(AppThemeV2.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppThemeV2.Colors.stone200)

                    if let assignment = result.assignment {
                        Text("(\(assignment))")
                            .font(AppThemeV2.Typography.body)
                            .foregroundColor(AppThemeV2.Colors.stone400)
                    }

                    if let controllerType = result.controllerType {
                        Text("• \(controllerType)")
                            .font(AppThemeV2.Typography.caption)
                            .foregroundColor(AppThemeV2.Colors.stone500)
                    }
                }
                .lineLimit(1)
            } else if coordinator.pendingVoice != nil {
                Text("Processing: \"\(coordinator.pendingVoice!)\"")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .italic()
                    .lineLimit(1)
            } else {
                Text("Waiting for voice...")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone600)
                    .italic()
            }

            Spacer()
        }
    }

    // MARK: - Button Row (Cancel left, Next right)

    private var buttonRow: some View {
        HStack {
            // Cancel button (left)
            cancelButton

            Spacer()

            // Next button (right, yellow/amber)
            nextButton
        }
    }

    private var nextButton: some View {
        Button {
            coordinator.saveAndContinue()
        } label: {
            Text("NEXT")
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .fontWeight(.semibold)
                .foregroundColor(AppThemeV2.Colors.stone900)
                .padding(.horizontal, AppThemeV2.Spacing.lg)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(canSave ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone700)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .keyboardShortcut(.return, modifiers: [])
    }

    /// Whether there's a valid mapping to save
    private var canSave: Bool {
        coordinator.currentResult != nil && coordinator.pendingMIDI != nil
    }

    private func describeMIDI(_ message: MIDIMessage) -> String {
        if let cc = message.cc {
            return "Ch\(message.channel) CC \(cc)"
        } else if let note = message.note {
            return "Ch\(message.channel) Note \(note)"
        } else {
            return "Ch\(message.channel) Value \(message.value)"
        }
    }

    // MARK: - Disambiguation Section

    private func disambiguationSection(options: [CommandAlternative]) -> some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
            Text("Which command did you mean?")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone300)

            ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                disambiguationOptionRow(option: option, index: index)
            }

            Text("Say a number, press 1-\(min(options.count, 5)), or click")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
        }
    }

    private func disambiguationOptionRow(option: CommandAlternative, index: Int) -> some View {
        Button {
            coordinator.selectOption(index)
        } label: {
            HStack(alignment: .top, spacing: AppThemeV2.Spacing.md) {
                // Number badge
                Text("[\(index + 1)]")
                    .font(AppThemeV2.Typography.mono)
                    .foregroundColor(AppThemeV2.Colors.amber)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xxs) {
                    // Command name with assignment
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Text(option.command)
                            .font(AppThemeV2.Typography.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppThemeV2.Colors.stone200)

                        if let assignment = option.assignment {
                            Text("(\(assignment))")
                                .font(AppThemeV2.Typography.body)
                                .foregroundColor(AppThemeV2.Colors.stone400)
                        }
                    }

                    // Description
                    Text(option.description)
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                        .lineLimit(2)
                }

                Spacer()

                // Confidence indicator
                confidenceIndicator(option.confidence)
            }
            .padding(AppThemeV2.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                    .fill(AppThemeV2.Colors.stone800)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                    .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func confidenceIndicator(_ confidence: Double) -> some View {
        let percentage = Int(confidence * 100)
        let color: Color = confidence >= 0.7 ? AppThemeV2.Colors.success :
                          confidence >= 0.4 ? AppThemeV2.Colors.warning :
                          AppThemeV2.Colors.danger

        return Text("\(percentage)%")
            .font(AppThemeV2.Typography.micro)
            .foregroundColor(color)
            .padding(.horizontal, AppThemeV2.Spacing.xs)
            .padding(.vertical, AppThemeV2.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                    .fill(color.opacity(0.15))
            )
    }

    // MARK: - Processing Section

    private var processingSection: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppThemeV2.Colors.amber))
                .scaleEffect(0.8)

            Text("Understanding command...")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone400)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(AppThemeV2.Spacing.md)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Group {
            if !coordinator.statusMessage.isEmpty && !coordinator.isProcessing {
                Text(coordinator.statusMessage)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone400)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if coordinator.pendingMIDI == nil && coordinator.pendingVoice == nil && !coordinator.isProcessing && coordinator.disambiguationOptions == nil {
                VStack(spacing: AppThemeV2.Spacing.sm) {
                    Text("Press a MIDI control and say your command")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone300)

                    Text("Example: \"Control the volume on Deck B\"")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppThemeV2.Spacing.sm)
            }
        }
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button {
            if coordinator.disambiguationOptions != nil {
                coordinator.dismissOptions()
            } else {
                coordinator.deactivate()
            }
        } label: {
            Text(coordinator.disambiguationOptions != nil ? "CANCEL" : "CLOSE")
                .font(AppThemeV2.Typography.micro)
                .tracking(0.5)
                .foregroundColor(AppThemeV2.Colors.stone400)
                .padding(.horizontal, AppThemeV2.Spacing.md)
                .padding(.vertical, AppThemeV2.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .fill(AppThemeV2.Colors.stone700)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                        .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
    }
}

// MARK: - Preview

#Preview("Voice Learn - Listening") {
    ZStack {
        AppThemeV2.Colors.stone950
            .ignoresSafeArea()

        // Mock coordinator for preview
        VoiceLearnOverlayPreview(state: .listening)
    }
    .preferredColorScheme(.dark)
}

#Preview("Voice Learn - MIDI Captured") {
    ZStack {
        AppThemeV2.Colors.stone950
            .ignoresSafeArea()

        VoiceLearnOverlayPreview(state: .midiCaptured)
    }
    .preferredColorScheme(.dark)
}

#Preview("Voice Learn - Disambiguation") {
    ZStack {
        AppThemeV2.Colors.stone950
            .ignoresSafeArea()

        VoiceLearnOverlayPreview(state: .disambiguation)
    }
    .preferredColorScheme(.dark)
}

#Preview("Voice Learn - Processing") {
    ZStack {
        AppThemeV2.Colors.stone950
            .ignoresSafeArea()

        VoiceLearnOverlayPreview(state: .processing)
    }
    .preferredColorScheme(.dark)
}

// MARK: - Preview Helper

/// Preview wrapper that uses mock data instead of real coordinator
private struct VoiceLearnOverlayPreview: View {
    enum State {
        case listening
        case midiCaptured
        case voiceCaptured
        case bothCaptured
        case processing
        case disambiguation
    }

    let state: State

    var body: some View {
        // Create a placeholder view that mimics the real overlay
        // Since we can't easily mock the coordinator, show static UI
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            // Header
            HStack(spacing: AppThemeV2.Spacing.sm) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppThemeV2.Colors.amber)

                Text("VOICE LEARN")
                    .font(AppThemeV2.Typography.display)
                    .foregroundColor(AppThemeV2.Colors.stone200)

                Spacer()

                // Status badge
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 6, height: 6)

                    Text(badgeText.uppercased())
                        .font(AppThemeV2.Typography.micro)
                        .tracking(0.5)
                        .foregroundColor(badgeColor)
                }
                .padding(.horizontal, AppThemeV2.Spacing.sm)
                .padding(.vertical, AppThemeV2.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.pill)
                        .fill(badgeColor.opacity(0.15))
                )
            }

            V2Divider()

            // State-specific content
            switch state {
            case .listening:
                VStack(spacing: AppThemeV2.Spacing.sm) {
                    Text("Press a MIDI control and say your command")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone300)

                    Text("Example: \"Control the volume on Deck B\"")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                        .italic()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, AppThemeV2.Spacing.sm)

            case .midiCaptured, .voiceCaptured, .bothCaptured:
                capturedInputsPreview

            case .processing:
                capturedInputsPreview
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppThemeV2.Colors.amber))
                        .scaleEffect(0.8)

                    Text("Understanding command...")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(AppThemeV2.Spacing.md)

            case .disambiguation:
                disambiguationPreview
            }

            // Cancel button
            HStack {
                Spacer()
                Text(state == .disambiguation ? "CANCEL" : "CLOSE")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)
                    .padding(.horizontal, AppThemeV2.Spacing.md)
                    .padding(.vertical, AppThemeV2.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .fill(AppThemeV2.Colors.stone700)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
                    )
            }
        }
        .padding(AppThemeV2.Spacing.lg)
        .frame(width: 400)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg)
                .fill(AppThemeV2.Colors.stone800)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg)
                .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
        )
    }

    private var badgeColor: Color {
        switch state {
        case .listening: return AppThemeV2.Colors.amber
        case .midiCaptured, .voiceCaptured: return AppThemeV2.Colors.amber
        case .bothCaptured: return AppThemeV2.Colors.success
        case .processing: return AppThemeV2.Colors.amber
        case .disambiguation: return AppThemeV2.Colors.warning
        }
    }

    private var badgeText: String {
        switch state {
        case .listening: return "Listening"
        case .midiCaptured, .voiceCaptured: return "Listening"
        case .bothCaptured: return "Ready"
        case .processing: return "Processing"
        case .disambiguation: return "Choose"
        }
    }

    private var capturedInputsPreview: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            if state == .midiCaptured || state == .bothCaptured || state == .processing {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    Image(systemName: "pianokeys")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppThemeV2.Colors.amber)
                        .frame(width: 16)

                    Text("MIDI")
                        .font(AppThemeV2.Typography.micro)
                        .tracking(0.5)
                        .foregroundColor(AppThemeV2.Colors.stone500)

                    Text("Ch1 CC 7")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone300)
                }
            }

            if state == .voiceCaptured || state == .bothCaptured || state == .processing {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppThemeV2.Colors.amber)
                        .frame(width: 16)

                    Text("VOICE")
                        .font(AppThemeV2.Typography.micro)
                        .tracking(0.5)
                        .foregroundColor(AppThemeV2.Colors.stone500)

                    Text("\"volume on deck B\"")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone300)
                }
            }
        }
        .padding(AppThemeV2.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                .fill(AppThemeV2.Colors.stone800)
        )
    }

    private var disambiguationPreview: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
            Text("Which command did you mean?")
                .font(AppThemeV2.Typography.body)
                .foregroundColor(AppThemeV2.Colors.stone300)

            // Option 1
            optionRow(index: 1, command: "Deck Volume", assignment: "Deck B", description: "Controls the volume fader for Deck B", confidence: 0.72)

            // Option 2
            optionRow(index: 2, command: "Headphone Volume", assignment: nil, description: "Controls headphone/cue volume", confidence: 0.58)

            // Option 3
            optionRow(index: 3, command: "Master Volume", assignment: nil, description: "Controls main output volume", confidence: 0.45)

            Text("Say a number, press 1-3, or click")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
        }
    }

    private func optionRow(index: Int, command: String, assignment: String?, description: String, confidence: Double) -> some View {
        HStack(alignment: .top, spacing: AppThemeV2.Spacing.md) {
            Text("[\(index)]")
                .font(AppThemeV2.Typography.mono)
                .foregroundColor(AppThemeV2.Colors.amber)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xxs) {
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Text(command)
                        .font(AppThemeV2.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppThemeV2.Colors.stone200)

                    if let assignment = assignment {
                        Text("(\(assignment))")
                            .font(AppThemeV2.Typography.body)
                            .foregroundColor(AppThemeV2.Colors.stone400)
                    }
                }

                Text(description)
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }

            Spacer()

            // Confidence
            let percentage = Int(confidence * 100)
            let color: Color = confidence >= 0.7 ? AppThemeV2.Colors.success :
                              confidence >= 0.4 ? AppThemeV2.Colors.warning :
                              AppThemeV2.Colors.danger

            Text("\(percentage)%")
                .font(AppThemeV2.Typography.micro)
                .foregroundColor(color)
                .padding(.horizontal, AppThemeV2.Spacing.xs)
                .padding(.vertical, AppThemeV2.Spacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                        .fill(color.opacity(0.15))
                )
        }
        .padding(AppThemeV2.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                .fill(AppThemeV2.Colors.stone800)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.md)
                .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
        )
    }
}
