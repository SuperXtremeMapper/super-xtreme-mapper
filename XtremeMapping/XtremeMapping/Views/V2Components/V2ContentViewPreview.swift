//
//  V2ContentViewPreview.swift
//  SuperXtremeMapping
//
//  Complete preview of the V2 design system applied to the app
//  Run this preview in Xcode to see the new visual style
//

import SwiftUI

/// Settings panel with V2 styling
struct V2SettingsPanel: View {
    @State private var controllerType = "Button"
    @State private var interactionMode = "Hold"
    @State private var channel = 1
    @State private var midiValue = "CC 20"
    @State private var invert = false
    @State private var softTakeover = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                V2SectionHeader(title: "SETTINGS")
                Spacer()
                Button(action: {}) {
                    Image(systemName: "line.3.horizontal")
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppThemeV2.Spacing.lg)
            .padding(.vertical, AppThemeV2.Spacing.md)

            V2Divider()

            ScrollView {
                VStack(spacing: AppThemeV2.Spacing.sm) {
                    // MIDI Section
                    sectionLabel("MIDI ASSIGNMENT")

                    V2FormRow(label: "Type") {
                        V2Dropdown(
                            options: ["Button", "Fader", "Encoder", "LED"],
                            selection: $controllerType,
                            labelFor: { $0 }
                        )
                    }

                    V2FormRow(label: "Channel") {
                        V2NumberStepper(value: $channel, range: 1...16, label: nil)
                    }

                    V2FormRow(label: "Note/CC") {
                        V2TextField(placeholder: "CC 20", text: $midiValue, isHighlighted: true)
                            .frame(width: 80)
                    }

                    V2FormRow(label: "Interaction") {
                        V2Dropdown(
                            options: ["Hold", "Toggle", "Direct", "Relative"],
                            selection: $interactionMode,
                            labelFor: { $0 }
                        )
                    }

                    V2Divider()
                        .padding(.vertical, AppThemeV2.Spacing.sm)

                    // Options Section
                    sectionLabel("OPTIONS")

                    V2FormRow(label: "Invert") {
                        V2Toggle(isOn: $invert)
                    }

                    V2FormRow(label: "Soft Takeover") {
                        V2Toggle(isOn: $softTakeover)
                    }

                    V2Divider()
                        .padding(.vertical, AppThemeV2.Spacing.sm)

                    // Modifiers Section
                    sectionLabel("MODIFIERS")

                    modifierRow(label: "M1", activeValue: 0)
                    modifierRow(label: "M2", activeValue: nil)
                }
                .padding(AppThemeV2.Spacing.md)
            }
        }
        .background(AppThemeV2.Colors.stone800)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppThemeV2.Typography.micro)
            .tracking(1)
            .foregroundColor(AppThemeV2.Colors.amber)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, AppThemeV2.Spacing.xs)
    }

    private func modifierRow(label: String, activeValue: Int?) -> some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Text(label)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.amber)
                .fontWeight(.bold)
                .frame(width: 24)

            V2ModifierButton(label: "Any", isActive: activeValue == nil, action: {})
            V2ModifierButton(label: "=0", isActive: activeValue == 0, action: {})
            V2ModifierButton(label: "=1", isActive: activeValue == 1, action: {})
            V2ModifierButton(label: "=2", isActive: activeValue == 2, action: {})

            Spacer()
        }
        .padding(.vertical, AppThemeV2.Spacing.xxs)
    }
}

/// Complete V2 content view preview
struct V2ContentViewPreview: View {
    @State private var categoryFilter: CommandCategory = .all
    @State private var ioFilter: IODirection = .all
    @State private var isLocked = false
    @State private var selection: Set<UUID> = []

    // Sample data
    private let sampleMappings = [
        MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .toggle,
            midiChannel: 1,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Tempo Bend +",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 20
        ),
        MappingEntry(
            commandName: "Play State LED",
            ioType: .output,
            assignment: .deckA,
            interactionMode: .output,
            midiChannel: 1,
            midiNote: 42
        ),
        MappingEntry(
            commandName: "Sync",
            ioType: .input,
            assignment: .deckB,
            interactionMode: .toggle,
            midiChannel: 2,
            midiNote: 43,
            modifier1Condition: ModifierCondition(modifier: 1, value: 0)
        ),
        MappingEntry(
            commandName: "Master Volume",
            ioType: .input,
            assignment: .global,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 7
        ),
        MappingEntry(
            commandName: "Filter",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 8,
            controllerType: .faderOrKnob
        ),
        MappingEntry(
            commandName: "Browse Encoder",
            ioType: .input,
            assignment: .global,
            interactionMode: .relative,
            midiChannel: 1,
            midiCC: 64,
            controllerType: .encoder
        ),
        MappingEntry(
            commandName: "Cue",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiNote: 44,
            modifier1Condition: ModifierCondition(modifier: 1, value: 1),
            modifier2Condition: ModifierCondition(modifier: 2, value: 0)
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            V2ActionBar(
                document: TraktorMappingDocument(),
                isLocked: $isLocked,
                categoryFilter: $categoryFilter,
                ioFilter: $ioFilter
            )

            // Main content
            HStack(spacing: 0) {
                // Left: Mappings panel
                VStack(spacing: 0) {
                    // Panel header
                    HStack {
                        V2SectionHeader(title: "MAPPINGS")
                        Spacer()
                        Text("\(sampleMappings.count) items")
                            .font(AppThemeV2.Typography.caption)
                            .foregroundColor(AppThemeV2.Colors.stone500)
                    }
                    .padding(.horizontal, AppThemeV2.Spacing.lg)
                    .padding(.vertical, AppThemeV2.Spacing.md)

                    V2Divider()

                    // Table
                    V2MappingsTable(
                        mappings: sampleMappings,
                        selection: $selection
                    )
                }
                .background(AppThemeV2.Colors.stone900)

                // Vertical divider
                Rectangle()
                    .fill(AppThemeV2.Colors.stone700)
                    .frame(width: 1)

                // Right: Settings panel
                V2SettingsPanel()
                    .frame(width: 280)
            }

            // Status bar
            HStack {
                Circle()
                    .fill(AppThemeV2.Colors.amber)
                    .frame(width: 6, height: 6)
                Text("BETA: Always backup your mappings before making changes")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.amber)
                Spacer()
            }
            .padding(.horizontal, AppThemeV2.Spacing.lg)
            .padding(.vertical, AppThemeV2.Spacing.sm)
            .background(AppThemeV2.Colors.stone800)
        }
        .background(AppThemeV2.Colors.stone950)
        .preferredColorScheme(.dark)
        .onAppear {
            // Pre-select second row for demo
            if let second = sampleMappings.dropFirst().first {
                selection = [second.id]
            }
        }
    }
}

// MARK: - Preview

#Preview("V2 Full App") {
    V2ContentViewPreview()
        .frame(width: 1100, height: 600)
}

#Preview("V2 Settings Panel") {
    V2SettingsPanel()
        .frame(width: 280, height: 500)
        .preferredColorScheme(.dark)
}

#Preview("Current vs V2 Comparison") {
    HStack(spacing: 0) {
        // Current design placeholder
        VStack {
            Text("CURRENT DESIGN")
                .font(.headline)
                .padding()
            Spacer()
            Text("(Uses native macOS styling)")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))

        Divider()

        // V2 design
        V2ContentViewPreview()
            .frame(maxWidth: .infinity)
    }
    .frame(width: 1400, height: 600)
}
