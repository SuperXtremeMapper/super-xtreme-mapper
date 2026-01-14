# V2 UI Refinements Part 2 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 3 UI/UX improvements: button styling with glow, splash screen spacing consistency, and modifier dropdown layout.

**Architecture:** Changes to V2AddCommandMenuButton for glow effect, WelcomeView for consistent spacing, and V2ModifierRow for dual-dropdown layout.

**Tech Stack:** SwiftUI, macOS, AppThemeV2 design system

---

## Task 1: Add Glow Effect to In/Out/InOut Buttons

**Files:**
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift:477-560` (V2AddCommandMenuButton)

**What to change:**

The V2AddCommandMenuButton already has a border but needs a glow effect on hover like the wizard buttons. Add `.shadow()` modifier for the glow effect.

**Current code (around line 501-508):**
```swift
.background(
    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
        .fill(backgroundColor)
)
.overlay(
    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
        .stroke(borderColor, lineWidth: 1)
)
```

**Change to:**
```swift
.background(
    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
        .fill(backgroundColor)
)
.overlay(
    RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
        .stroke(borderColor, lineWidth: 1)
)
.shadow(
    color: isHovered && !isDisabled ? AppThemeV2.Colors.amberGlow : .clear,
    radius: isHovered && !isDisabled ? 8 : 0
)
```

This adds the amber glow effect on hover, matching the WelcomeButton style.

---

## Task 2: Fix Splash Screen Spacing Consistency

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/WelcomeView.swift`

**Goal:** Make spacing consistent:
1. Distance below tagline ("in the spirit of...") to divider = Distance from divider to first button
2. Distance from last button (Mapping Wizard) to warning = Distance from first button to divider

**Current structure:**
- Header VStack ends with `.padding(.bottom, 40)` (line 68)
- Options VStack has `.padding(.top, 32)` (line 107)
- Options VStack has `.padding(.bottom, 32)` (line 108)
- `Spacer()` between buttons and footer (line 110)
- Footer has `.padding(.bottom, 32)` (line 125)

**Changes needed:**

1. Change header `.padding(.bottom, 40)` to `.padding(.bottom, 32)` to match the button section top padding
2. Remove the `Spacer()` between the buttons and footer
3. Keep footer `.padding(.bottom, 32)` as-is (matches the button section bottom padding)

**Updated WelcomeView body structure:**
```swift
var body: some View {
    VStack(spacing: 0) {
        // Header
        VStack(spacing: AppThemeV2.Spacing.md) {
            // ... logo, app name, version badge, tagline unchanged
        }
        .padding(.top, 40)
        .padding(.bottom, 32)  // Changed from 40 to 32

        // Divider
        Rectangle()
            .fill(AppThemeV2.Colors.stone700)
            .frame(height: 1)
            .padding(.horizontal, 32)

        // Options
        VStack(spacing: AppThemeV2.Spacing.md) {
            // ... buttons unchanged
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 32)

        // REMOVED: Spacer()

        // Footer with beta warning
        HStack(spacing: AppThemeV2.Spacing.xs) {
            // ... unchanged
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    .frame(width: 420, height: 680)
    // ...
}
```

This makes:
- 32pt from tagline to divider (via header bottom padding)
- 32pt from divider to first button (via options top padding)
- 32pt from last button to warning (via options bottom padding, no Spacer eating space)
- 32pt from warning to bottom edge (via footer bottom padding)

---

## Task 3: Modifier Settings - Dual Dropdown Layout (No Labels)

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift:494-602` (V2ModifierRow)

**Goal:** Replace current layout (label + modifier dropdown + value stepper) with two side-by-side dropdowns (modifier | value) with no row label.

**Replace the entire V2ModifierRow struct with:**

```swift
/// V2 styled modifier row with two dropdowns: modifier number and value
struct V2ModifierRow: View {
    @Binding var condition: ModifierCondition?
    let isLocked: Bool
    let onChanged: (ModifierCondition?) -> Void

    @State private var selectedModifier: Int = 0
    @State private var selectedValue: Int = 0

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            // Modifier picker (None, M1-M8)
            Menu {
                Button("-") {
                    selectedModifier = 0
                    updateCondition()
                }
                ForEach(1...8, id: \.self) { num in
                    Button("M\(num)") {
                        selectedModifier = num
                        updateCondition()
                    }
                }
            } label: {
                HStack(spacing: AppThemeV2.Spacing.xs) {
                    Text(selectedModifier == 0 ? "-" : "M\(selectedModifier)")
                        .font(AppThemeV2.Typography.body)
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .frame(minWidth: 30)

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
            .disabled(isLocked)

            // Value picker (0-7) - only shown if modifier is selected
            if selectedModifier > 0 {
                Text("=")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)

                Menu {
                    ForEach(0...7, id: \.self) { val in
                        Button("\(val)") {
                            selectedValue = val
                            updateCondition()
                        }
                    }
                } label: {
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Text("\(selectedValue)")
                            .font(AppThemeV2.Typography.body)
                            .foregroundColor(AppThemeV2.Colors.stone200)
                            .frame(minWidth: 20)

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
                .disabled(isLocked)
            }

            Spacer()
        }
        .onAppear {
            loadFromCondition()
        }
        .onChange(of: condition) { _, _ in
            loadFromCondition()
        }
    }

    private func loadFromCondition() {
        if let cond = condition {
            selectedModifier = cond.modifier
            selectedValue = cond.value
        } else {
            selectedModifier = 0
            selectedValue = 0
        }
    }

    private func updateCondition() {
        let newCondition: ModifierCondition?
        if selectedModifier == 0 {
            newCondition = nil
        } else {
            newCondition = ModifierCondition(modifier: selectedModifier, value: selectedValue)
        }

        if condition != newCondition {
            condition = newCondition
            onChanged(newCondition)
        }
    }
}
```

**Also update the modifierControls call site** (around line 320-336) to remove the `label` parameter:

```swift
private var modifierControls: some View {
    VStack(spacing: AppThemeV2.Spacing.sm) {
        V2ModifierRow(condition: $modifier1, isLocked: isLocked) { newCondition in
            if isMultipleSelection {
                updateSelectedEntries { $0.modifier1Condition = newCondition }
            } else {
                updateEntry { $0.modifier1Condition = newCondition }
            }
        }
        V2ModifierRow(condition: $modifier2, isLocked: isLocked) { newCondition in
            if isMultipleSelection {
                updateSelectedEntries { $0.modifier2Condition = newCondition }
            } else {
                updateEntry { $0.modifier2Condition = newCondition }
            }
        }
    }
}
```

---

## Summary

| Task | Description | File |
|------|-------------|------|
| 1 | Add glow effect to In/Out buttons | ContentView.swift |
| 2 | Fix splash screen spacing | WelcomeView.swift |
| 3 | Modifier dual-dropdown layout | SettingsPanelV2.swift |

All tasks are independent and can be implemented in parallel.
