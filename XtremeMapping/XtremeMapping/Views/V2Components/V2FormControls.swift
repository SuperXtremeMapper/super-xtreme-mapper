//
//  V2FormControls.swift
//  SuperXtremeMapping
//
//  Custom form controls matching website mockup style
//

import SwiftUI

// MARK: - Section Header

/// Section header with "XX" prefix styling
struct V2SectionHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            Text("XX")
                .font(AppThemeV2.Typography.display)
                .foregroundColor(AppThemeV2.Colors.amber)

            Text(title.uppercased())
                .font(AppThemeV2.Typography.display)
                .foregroundColor(AppThemeV2.Colors.stone100)
        }
    }
}

// MARK: - Form Row

/// A labeled form row with consistent styling
struct V2FormRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .frame(width: 80, alignment: .leading)

            Spacer()

            content()
        }
        .padding(.vertical, AppThemeV2.Spacing.xs)
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                .fill(AppThemeV2.Colors.stone800.opacity(0.5))
        )
    }
}

// MARK: - Toggle

/// Custom toggle matching mockup style
struct V2Toggle: View {
    @Binding var isOn: Bool
    let label: String?

    init(isOn: Binding<Bool>, label: String? = nil) {
        self._isOn = isOn
        self.label = label
    }

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                // Track
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600)
                        .frame(width: 36, height: 20)

                    // Thumb
                    Circle()
                        .fill(AppThemeV2.Colors.stone100)
                        .frame(width: 16, height: 16)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                }
                .animation(.easeInOut(duration: 0.15), value: isOn)

                if let label = label {
                    Text(label)
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone400)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Dropdown

/// Custom dropdown/picker matching mockup style
struct V2Dropdown<T: Hashable>: View {
    let options: [T]
    @Binding var selection: T
    let labelFor: (T) -> String

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: { selection = option }) {
                    HStack {
                        Text(labelFor(option))
                        if selection == option {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Text(labelFor(selection))
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone200)

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(AppThemeV2.Colors.stone700)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

// MARK: - Text Input

/// Custom text field matching mockup style
struct V2TextField: View {
    let placeholder: String
    @Binding var text: String
    var isHighlighted: Bool = false

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(AppThemeV2.Typography.body)
            .foregroundColor(isHighlighted ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone200)
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(isHighlighted ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone700)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(isHighlighted ? AppThemeV2.Colors.amber.opacity(0.5) : AppThemeV2.Colors.stone600, lineWidth: 1)
            )
    }
}

// MARK: - Number Stepper

/// Custom number input with +/- buttons
struct V2NumberStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String?

    var body: some View {
        HStack(spacing: 0) {
            // Decrease button
            Button(action: decreaseValue) {
                Image(systemName: "minus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(value > range.lowerBound ? AppThemeV2.Colors.stone400 : AppThemeV2.Colors.stone600)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Value display
            Text("\(value)")
                .font(AppThemeV2.Typography.mono)
                .foregroundColor(AppThemeV2.Colors.stone200)
                .frame(minWidth: 30)

            // Increase button
            Button(action: increaseValue) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(value < range.upperBound ? AppThemeV2.Colors.stone400 : AppThemeV2.Colors.stone600)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .fill(AppThemeV2.Colors.stone700)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                .stroke(AppThemeV2.Colors.stone600, lineWidth: 1)
        )
    }

    private func decreaseValue() {
        if value > range.lowerBound {
            value -= 1
        }
    }

    private func increaseValue() {
        if value < range.upperBound {
            value += 1
        }
    }
}

// MARK: - Modifier Condition Button

/// Button for selecting modifier conditions (M1=0, M1=1, etc.)
struct V2ModifierButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(AppThemeV2.Typography.micro)
                .foregroundColor(isActive ? AppThemeV2.Colors.stone950 : AppThemeV2.Colors.stone500)
                .padding(.horizontal, AppThemeV2.Spacing.xs + 2)
                .padding(.vertical, AppThemeV2.Spacing.xxs + 1)
                .background(
                    RoundedRectangle(cornerRadius: AppThemeV2.Radius.xs)
                        .fill(isActive ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone700)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Divider

/// Custom divider with subtle styling
struct V2Divider: View {
    var body: some View {
        Rectangle()
            .fill(AppThemeV2.Colors.stone700)
            .frame(height: 1)
    }
}

// MARK: - Previews

#Preview("Form Controls") {
    VStack(alignment: .leading, spacing: 16) {
        V2SectionHeader(title: "SETTINGS")

        V2FormRow(label: "Type") {
            V2Dropdown(
                options: ["Button", "Fader", "Encoder"],
                selection: .constant("Button"),
                labelFor: { $0 }
            )
        }

        V2FormRow(label: "Channel") {
            V2NumberStepper(value: .constant(1), range: 1...16, label: nil)
        }

        V2FormRow(label: "Note/CC") {
            V2TextField(placeholder: "CC 20", text: .constant("CC 20"), isHighlighted: true)
                .frame(width: 80)
        }

        V2Divider()

        V2FormRow(label: "Invert") {
            V2Toggle(isOn: .constant(false))
        }

        V2FormRow(label: "Soft Takeover") {
            V2Toggle(isOn: .constant(true))
        }

        V2Divider()

        HStack(spacing: 4) {
            Text("M1")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.amber)
                .frame(width: 24)

            V2ModifierButton(label: "=0", isActive: true, action: {})
            V2ModifierButton(label: "=1", isActive: false, action: {})
            V2ModifierButton(label: "=2", isActive: false, action: {})
            V2ModifierButton(label: "Any", isActive: false, action: {})
        }
    }
    .padding(24)
    .frame(width: 280)
    .background(AppThemeV2.Colors.stone800)
    .preferredColorScheme(.dark)
}
