//
//  ModifierRow.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI

/// A row component for editing a single modifier condition.
///
/// Displays a picker for selecting modifier number (M1-M8 or none) and
/// a stepper for the condition value (0-7).
struct ModifierRow: View {
    /// The current modifier condition, or nil if no modifier is set
    @Binding var condition: ModifierCondition?

    /// Whether editing is locked
    let isLocked: Bool

    /// Callback when the condition changes
    var onChanged: ((ModifierCondition?) -> Void)?

    // Local state for the picker and stepper
    @State private var selectedModifier: Int = 0
    @State private var selectedValue: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            // Modifier selector (None, M1-M8)
            Picker("", selection: $selectedModifier) {
                Text("-").tag(0)
                ForEach(1...8, id: \.self) { num in
                    Text("M\(num)").tag(num)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(isLocked)

            // Value stepper (0-7)
            HStack(spacing: 4) {
                Text("=")
                    .foregroundColor(.secondary)

                Text("\(selectedValue)")
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 16)

                Stepper("", value: $selectedValue, in: 0...7)
                    .labelsHidden()
                    .disabled(isLocked || selectedModifier == 0)
            }
        }
        .onAppear {
            // Initialize from the binding
            if let condition = condition {
                selectedModifier = condition.modifier
                selectedValue = condition.value
            } else {
                selectedModifier = 0
                selectedValue = 0
            }
        }
        .onChange(of: selectedModifier) { _, newModifier in
            updateCondition(modifier: newModifier, value: selectedValue)
        }
        .onChange(of: selectedValue) { _, newValue in
            updateCondition(modifier: selectedModifier, value: newValue)
        }
        .onChange(of: condition) { _, newCondition in
            // Sync from external changes
            if let newCondition = newCondition {
                if selectedModifier != newCondition.modifier {
                    selectedModifier = newCondition.modifier
                }
                if selectedValue != newCondition.value {
                    selectedValue = newCondition.value
                }
            } else if selectedModifier != 0 {
                selectedModifier = 0
                selectedValue = 0
            }
        }
    }

    /// Updates the condition binding based on the current modifier and value
    private func updateCondition(modifier: Int, value: Int) {
        let newCondition: ModifierCondition?
        if modifier == 0 {
            newCondition = nil
        } else {
            newCondition = ModifierCondition(modifier: modifier, value: value)
        }

        // Only update if changed
        if condition != newCondition {
            condition = newCondition
            onChanged?(newCondition)
        }
    }
}

#Preview("No Modifier") {
    ModifierRow(
        condition: .constant(nil),
        isLocked: false
    )
    .padding()
    .frame(width: 200)
}

#Preview("With Modifier M4 = 2") {
    ModifierRow(
        condition: .constant(ModifierCondition(modifier: 4, value: 2)),
        isLocked: false
    )
    .padding()
    .frame(width: 200)
}

#Preview("Locked") {
    ModifierRow(
        condition: .constant(ModifierCondition(modifier: 1, value: 0)),
        isLocked: true
    )
    .padding()
    .frame(width: 200)
}
