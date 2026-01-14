# V2 UI Refinements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 13 UI/UX improvements to the XtremeMapping V2 interface including styling changes, functional fixes, and text updates.

**Architecture:** Changes span V2 components (toolbar, table, settings panel, welcome view), theme colors, and global text references. Each task is isolated and can be implemented independently.

**Tech Stack:** SwiftUI, macOS, AppThemeV2 design system

---

## Task 1: Table Background - Use Darker Stone950

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/V2TableRow.swift:172`

**Step 1: Update V2MappingsTable background color**

In `V2MappingsTable`, change the background from `stone900` to `stone950`:

```swift
// Line 172 - change from:
.background(AppThemeV2.Colors.stone900)
// To:
.background(AppThemeV2.Colors.stone950)
```

**Step 2: Verify visually in preview**

Run: Build and check the preview in Xcode

**Step 3: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/V2Components/V2TableRow.swift
git commit -m "style: darken table background to stone950

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 2: In/Out Buttons with Command Dropdown Menus

**Files:**
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift:391-455` (V2ActionBarFull)
- Reference: `XtremeMapping/XtremeMapping/Views/ActionBar.swift:259-362` (AddCommandMenuButton pattern)

**Step 1: Create V2AddCommandMenuButton component**

Add a new V2-styled version of AddCommandMenuButton with hover states and command hierarchy. Add to ContentView.swift after V2FilterDropdown:

```swift
/// A V2-styled button that shows a hierarchical menu of Traktor commands when clicked
struct V2AddCommandMenuButton: View {
    let icon: String
    let label: String
    let isDisabled: Bool
    let onCommandSelected: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Menu {
            ForEach(CommandHierarchy.categories) { category in
                categoryMenu(category)
            }
        } label: {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))

                Text(label.uppercased())
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .padding(.vertical, AppThemeV2.Spacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    @ViewBuilder
    private func categoryMenu(_ category: CommandCategory2) -> some View {
        if let subcategories = category.subcategories {
            Menu(category.name) {
                ForEach(subcategories) { subcategory in
                    subcategoryMenu(subcategory)
                }
            }
        } else if let commands = category.commands {
            Menu(category.name) {
                ForEach(commands) { command in
                    Button(command.name) {
                        onCommandSelected(command.name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryMenu(_ subcategory: CommandCategory2) -> some View {
        if let commands = subcategory.commands {
            Menu(subcategory.name) {
                ForEach(commands) { command in
                    Button(command.name) {
                        onCommandSelected(command.name)
                    }
                }
            }
        }
    }

    private var foregroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone500 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isHovered && !isDisabled { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isHovered && !isDisabled { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}
```

**Step 2: Update V2ActionBarFull to use new menu buttons**

Replace the simple V2ToolbarButton calls with V2AddCommandMenuButton and add the In/Out combo button:

```swift
struct V2ActionBarFull: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var isLocked: Bool
    @Binding var categoryFilter: CommandCategory
    @Binding var ioFilter: IODirection
    @Binding var searchText: String
    var onAddInput: (String) -> Void  // Changed: now takes command name
    var onAddOutput: (String) -> Void // Changed: now takes command name
    var onAddInOut: (String) -> Void  // New: for In/Out pair

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.md) {
            // Left side - Add buttons with command menus
            HStack(spacing: AppThemeV2.Spacing.xs) {
                V2AddCommandMenuButton(
                    icon: "arrow.down",
                    label: "Add In",
                    isDisabled: isLocked
                ) { commandName in
                    onAddInput(commandName)
                }

                V2AddCommandMenuButton(
                    icon: "arrow.up",
                    label: "Add Out",
                    isDisabled: isLocked
                ) { commandName in
                    onAddOutput(commandName)
                }

                V2AddCommandMenuButton(
                    icon: "arrow.up.arrow.down",
                    label: "In/Out",
                    isDisabled: isLocked
                ) { commandName in
                    onAddInOut(commandName)
                }

                Rectangle()
                    .fill(AppThemeV2.Colors.stone600)
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, AppThemeV2.Spacing.xs)

                // Wizard and Controller buttons (greyed out, no hover)
                V2DisabledToolbarButton(icon: "wand.and.stars")
                V2DisabledToolbarButton(icon: "slider.horizontal.3")
            }
            // ... rest of body
        }
    }
}
```

**Step 3: Update ContentView to pass command names**

Update the callback signatures and add addInOutPair function:

```swift
// Update callback signatures
private func addInputMapping(commandName: String) {
    guard !isLocked else { return }
    registerChange()

    let newMapping = MappingEntry(
        commandName: commandName,
        ioType: .input,
        // ... rest unchanged
    )
    // ...
}

private func addOutputMapping(commandName: String) {
    // Similar update
}

private func addInOutPair(commandName: String) {
    guard !isLocked else { return }
    registerChange()

    let inputEntry = MappingEntry(
        commandName: commandName,
        ioType: .input,
        assignment: .global,
        interactionMode: .hold,
        midiChannel: 1
    )

    let outputEntry = MappingEntry(
        commandName: commandName,
        ioType: .output,
        assignment: .global,
        interactionMode: .output,
        midiChannel: 1
    )

    if document.mappingFile.devices.isEmpty {
        let device = Device(name: "Generic MIDI", mappings: [inputEntry, outputEntry])
        document.mappingFile.devices.append(device)
    } else {
        document.mappingFile.devices[0].mappings.append(contentsOf: [inputEntry, outputEntry])
    }

    selectedMappings = [inputEntry.id, outputEntry.id]
}
```

**Step 4: Commit**

```bash
git add XtremeMapping/XtremeMapping/ContentView.swift
git commit -m "feat: add command dropdown menus to In/Out buttons and restore In/Out pair button

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Add Hover State (Yellow Gold) to In/Out Buttons

This is handled in Task 2 by the `V2AddCommandMenuButton` component which has amber hover styling built in.

---

## Task 4: Grey Out Wizard and Controller Buttons (No Hover)

**Files:**
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`

**Step 1: Create V2DisabledToolbarButton component**

Add a disabled button variant with no hover state:

```swift
/// A permanently disabled toolbar button with greyed styling
struct V2DisabledToolbarButton: View {
    let icon: String
    let label: String?

    init(icon: String, label: String? = nil) {
        self.icon = icon
        self.label = label
    }

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))

            if let label = label {
                Text(label.uppercased())
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
            }
        }
        .foregroundColor(AppThemeV2.Colors.stone600)
        .padding(.horizontal, AppThemeV2.Spacing.sm)
        .padding(.vertical, AppThemeV2.Spacing.xs + 2)
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
```

**Step 2: Commit**

Combined with Task 2 commit.

---

## Task 5: Rearrange Toolbar Layout (Search Left, Filters Right)

**Files:**
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift:400-454` (V2ActionBarFull)

**Step 1: Restructure V2ActionBarFull layout**

Reorder elements: Add buttons | Wizard/Controller | Search (aligned with left pane) | Filters | Lock

```swift
var body: some View {
    HStack(spacing: AppThemeV2.Spacing.md) {
        // Left side - Add buttons and disabled buttons
        HStack(spacing: AppThemeV2.Spacing.xs) {
            // Add buttons (from Task 2)
            V2AddCommandMenuButton(icon: "arrow.down", label: "Add In", isDisabled: isLocked) { onAddInput($0) }
            V2AddCommandMenuButton(icon: "arrow.up", label: "Add Out", isDisabled: isLocked) { onAddOutput($0) }
            V2AddCommandMenuButton(icon: "arrow.up.arrow.down", label: "In/Out", isDisabled: isLocked) { onAddInOut($0) }

            Rectangle()
                .fill(AppThemeV2.Colors.stone600)
                .frame(width: 1, height: 20)
                .padding(.horizontal, AppThemeV2.Spacing.xs)

            V2DisabledToolbarButton(icon: "wand.and.stars")
            V2DisabledToolbarButton(icon: "slider.horizontal.3")
        }

        Spacer()

        // Right side - Search, then Filters, then Lock
        HStack(spacing: AppThemeV2.Spacing.sm) {
            V2SearchField(text: $searchText, placeholder: "Search...")
                .frame(width: 140)

            V2FilterDropdown(label: "Category", selection: $categoryFilter, options: CommandCategory.allCases)
            V2FilterDropdown(label: "I/O", selection: $ioFilter, options: IODirection.allCases)

            V2LockButtonIcon(isLocked: $isLocked)
        }
    }
    .padding(.horizontal, AppThemeV2.Spacing.lg)
    .padding(.vertical, AppThemeV2.Spacing.sm)
    .background(AppThemeV2.Colors.stone800)
    .overlay(
        Rectangle()
            .fill(AppThemeV2.Colors.stone700)
            .frame(height: 1),
        alignment: .bottom
    )
}
```

**Step 2: Commit**

```bash
git add XtremeMapping/XtremeMapping/ContentView.swift
git commit -m "style: rearrange toolbar - search left, filters right

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Lock Button - Icon Only, Same Color as Other Buttons

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/V2Toolbar.swift:65-93`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`

**Step 1: Create V2LockButtonIcon component**

Add a simpler icon-only lock button:

```swift
/// Lock toggle button with icon only, matching other button styling
struct V2LockButtonIcon: View {
    @Binding var isLocked: Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: { isLocked.toggle() }) {
            Image(systemName: isLocked ? "lock.fill" : "lock.open")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(foregroundColor)
                .frame(width: 28, height: 28)
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(isLocked ? "Unlock editing" : "Lock editing")
    }

    private var foregroundColor: Color {
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}
```

**Step 2: Update V2ActionBarFull to use new lock button**

Replace `V2LockButton(isLocked: $isLocked)` with `V2LockButtonIcon(isLocked: $isLocked)`

**Step 3: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/V2Components/V2Toolbar.swift XtremeMapping/XtremeMapping/ContentView.swift
git commit -m "style: simplify lock button to icon-only with standard button styling

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Left Align Command Title and Section Headings in Settings

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift:171-176, 240-245`

**Step 1: Left-align command title**

```swift
// Line 171-176, change from:
Text(entry.commandName)
    .font(AppThemeV2.Typography.display)
    .foregroundColor(AppThemeV2.Colors.stone100)
// To:
Text(entry.commandName)
    .font(AppThemeV2.Typography.display)
    .foregroundColor(AppThemeV2.Colors.stone100)
    .frame(maxWidth: .infinity, alignment: .leading)
```

**Step 2: Left-align section labels**

```swift
// Line 240-245, change sectionLabel function:
private func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(AppThemeV2.Typography.micro)
        .tracking(1)
        .foregroundColor(AppThemeV2.Colors.amber)
        .frame(maxWidth: .infinity, alignment: .leading)
}
```

**Step 3: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift
git commit -m "style: left-align command title and section headings in settings panel

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Remove Duplicate Chevron from Dropdowns

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/V2FormControls.swift:117-139`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift:465-509` (V2FilterDropdown)

**Step 1: Check and hide menu indicator**

The SwiftUI Menu adds its own chevron by default. Add `.menuIndicator(.hidden)` to both V2Dropdown and V2FilterDropdown:

```swift
// In V2Dropdown (V2FormControls.swift line ~138)
.menuStyle(.borderlessButton)
.menuIndicator(.hidden)  // Add this line

// In V2FilterDropdown (ContentView.swift line ~506)
.menuStyle(.borderlessButton)
.menuIndicator(.hidden)  // Add this line
.fixedSize()
```

**Step 2: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/V2Components/V2FormControls.swift XtremeMapping/XtremeMapping/ContentView.swift
git commit -m "fix: remove duplicate chevron from dropdown menus

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Fix Minus Button on Channel Stepper

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/V2FormControls.swift:176-211`

**Step 1: Verify and fix V2NumberStepper logic**

The current implementation looks correct, but the button may not be responding. Ensure the button is not being blocked:

```swift
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
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)

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
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
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
```

**Step 2: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/V2Components/V2FormControls.swift
git commit -m "fix: ensure minus button works correctly on channel stepper

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Fix Modifier Settings - V1 Picker+Stepper Style with V2 Theme

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift:492-524` (V2ModifierRow)

**Step 1: Replace V2ModifierRow with picker+stepper approach**

Replace the button-based V2ModifierRow with a V2-styled version of the V1 approach:

```swift
/// V2 styled modifier row with picker for M1-M8 and stepper for values 0-7
struct V2ModifierRow: View {
    let label: String
    @Binding var condition: ModifierCondition?
    let isLocked: Bool
    let onChanged: (ModifierCondition?) -> Void

    @State private var selectedModifier: Int = 0
    @State private var selectedValue: Int = 0

    var body: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            // Label
            Text(label)
                .font(AppThemeV2.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(AppThemeV2.Colors.amber)
                .frame(width: 24)

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

            // Value display and stepper (only if modifier selected)
            if selectedModifier > 0 {
                HStack(spacing: AppThemeV2.Spacing.xxs) {
                    Text("=")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)

                    V2NumberStepper(
                        value: $selectedValue,
                        range: 0...7,
                        label: nil
                    )
                    .disabled(isLocked)
                    .onChange(of: selectedValue) { _, _ in
                        updateCondition()
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            loadFromCondition()
        }
        .onChange(of: condition) { _, newCondition in
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

**Step 2: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift
git commit -m "fix: replace modifier buttons with picker+stepper for full M1-M8 and 0-7 support

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 11: Rename "Super Xtreme Mapping" to "Super Xtreme Mapper"

**Files to modify:**
- `XtremeMapping/XtremeMapping/Views/WelcomeView.swift:41-44`
- `XtremeMapping/XtremeMapping/Views/ActionBar.swift:394, 510`
- `XtremeMapping/XtremeMapping/Theme/AppTheme.swift` (if present)
- `XtremeMapping/XtremeMapping/XtremeMappingApp.swift`
- `XtremeMapping/XtremeMapping/Info.plist`
- `XtremeMapping/website/*.html`

**Step 1: Update WelcomeView**

```swift
// Line 41-44, change from:
Text("MAPPING")
// To:
Text("MAPPER")
```

**Step 2: Update AboutSheet in ActionBar.swift**

```swift
// Line 394
Text("Super Xtreme Mapper")

// Line 510
let subject = "Super Xtreme Mapper Feedback"
```

**Step 3: Update any remaining references**

Search and replace "Super Xtreme Mapping" with "Super Xtreme Mapper" in all Swift files.

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: rename 'Super Xtreme Mapping' to 'Super Xtreme Mapper' throughout codebase

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task 12: Fix Splash Screen Spacing

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/WelcomeView.swift:127`

**Step 1: Increase frame height**

```swift
// Line 127, change from:
.frame(width: 420, height: 620)
// To:
.frame(width: 420, height: 680)
```

**Step 2: Alternatively, reduce padding or make content scrollable**

If increasing height isn't desired, wrap content in ScrollView or reduce padding:

```swift
// Option A: Reduce footer padding
.padding(.bottom, 20)  // was 32

// Option B: Reduce header padding
.padding(.top, 32)  // was 40
.padding(.bottom, 32)  // was 40
```

**Step 3: Commit**

```bash
git add XtremeMapping/XtremeMapping/Views/WelcomeView.swift
git commit -m "fix: adjust splash screen height to prevent content cutoff

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

## Task Summary

| Task | Description | Complexity |
|------|-------------|------------|
| 1 | Table background to stone950 | Simple |
| 2 | In/Out buttons with command dropdown | Medium |
| 3 | Hover states (covered in Task 2) | - |
| 4 | Greyed wizard/controller buttons | Simple |
| 5 | Rearrange toolbar layout | Medium |
| 6 | Lock button icon-only | Simple |
| 7 | Left-align settings headings | Simple |
| 8 | Remove duplicate chevrons | Simple |
| 9 | Fix minus button on stepper | Simple |
| 10 | Fix modifier settings | Medium |
| 11 | Rename to "Mapper" | Simple |
| 12 | Fix splash screen spacing | Simple |

---

## Execution Notes

- Tasks 1-12 are largely independent and can be implemented by separate subagents in parallel where sensible
- Tasks 2, 3, 4, 5, 6 all modify ContentView.swift and should be done together
- Build and test after each commit to ensure no regressions
- The app uses SwiftUI previews - use these to verify visual changes
