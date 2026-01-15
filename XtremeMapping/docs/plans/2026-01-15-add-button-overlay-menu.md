# Add Button Overlay Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Restyle the Add In, Add Out, and In/Out buttons to match the Lock/About icon button style while preserving dropdown menu functionality.

**Architecture:** Use a ZStack overlay technique where:
1. A styled visual button (non-interactive) sits at the BOTTOM layer
2. A transparent Menu with invisible label sits on TOP to capture clicks
3. The container ZStack uses `.onHover` to synchronize hover state for the visual button
4. This ensures clicks go to the Menu while visuals match the icon button style

**Tech Stack:** SwiftUI, existing AppThemeV2 design system

**Why previous attempts likely failed:**
- Putting styled Button on top intercepts clicks → Menu never opens
- Using `.allowsHitTesting(false)` on visual layer might disable hover detection
- Menu label styling might have made it non-clickable

---

## Task 1: Create V2AddCommandMenuIconButton Component

**Files:**
- Modify: `XtremeMapping/ContentView.swift:469-563` (replace V2AddCommandMenuButton)

**Step 1: Create the new overlay-based component**

Replace the existing `V2AddCommandMenuButton` with a new `V2AddCommandMenuIconButton` that uses the overlay technique:

```swift
// MARK: - V2 Add Command Menu Icon Button (Overlay Technique)

/// An icon-only button styled like V2ToolbarIconButton that opens a command menu
/// Uses overlay technique: transparent Menu on top captures clicks, styled view below handles visuals
struct V2AddCommandMenuIconButton: View {
    let icon: String
    let tooltip: String
    let isDisabled: Bool
    let onCommandSelected: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        // ZStack: visual button below, transparent menu on top
        ZStack {
            // BOTTOM LAYER: Visual button (non-interactive, just for looks)
            visualButton

            // TOP LAYER: Transparent menu that captures clicks
            transparentMenu
        }
        .frame(width: 28, height: 28)
        .onHover { hovering in
            // Hover detection on container drives visual state
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .help(tooltip)
    }

    // The visual representation - matches V2ToolbarIconButton exactly
    private var visualButton: some View {
        Image(systemName: icon)
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
            .shadow(
                color: isHovered && !isDisabled ? AppThemeV2.Colors.amberGlow : .clear,
                radius: isHovered && !isDisabled ? 8 : 0
            )
    }

    // Transparent menu that sits on top and captures all clicks
    private var transparentMenu: some View {
        Menu {
            ForEach(CommandHierarchy.categories) { category in
                categoryMenu(category)
            }
        } label: {
            // Invisible hit area - same size as visual button
            Color.clear
                .frame(width: 28, height: 28)
                .contentShape(Rectangle()) // Ensure the clear area is clickable
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(isDisabled)
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
                    Button(command.name) { onCommandSelected(command.name) }
                }
            }
        }
    }

    @ViewBuilder
    private func subcategoryMenu(_ subcategory: CommandCategory2) -> some View {
        if let commands = subcategory.commands {
            Menu(subcategory.name) {
                ForEach(commands) { command in
                    Button(command.name) { onCommandSelected(command.name) }
                }
            }
        }
    }

    private var foregroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone600 }
        if isHovered { return AppThemeV2.Colors.amber }
        return AppThemeV2.Colors.stone400
    }

    private var backgroundColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone800 }
        if isHovered { return AppThemeV2.Colors.amberSubtle }
        return AppThemeV2.Colors.stone700
    }

    private var borderColor: Color {
        if isDisabled { return AppThemeV2.Colors.stone700 }
        if isHovered { return AppThemeV2.Colors.amber.opacity(0.5) }
        return AppThemeV2.Colors.stone600
    }
}
```

**Step 2: Update V2ActionBarFull to use the new component**

In the same file, update the `V2ActionBarFull` view to use the new icon buttons:

```swift
// In V2ActionBarFull, replace lines 427-430:
HStack(spacing: AppThemeV2.Spacing.xs) {
    V2AddCommandMenuIconButton(icon: "arrow.down", tooltip: "Add Input Mapping", isDisabled: isLocked) { onAddInput($0) }
    V2AddCommandMenuIconButton(icon: "arrow.up", tooltip: "Add Output Mapping", isDisabled: isLocked) { onAddOutput($0) }
    V2AddCommandMenuIconButton(icon: "arrow.up.arrow.down", tooltip: "Add Input/Output Pair", isDisabled: isLocked) { onAddInOut($0) }

    Rectangle()
        .fill(AppThemeV2.Colors.stone600)
        .frame(width: 1, height: 20)
        .padding(.horizontal, AppThemeV2.Spacing.xs)

    V2DisabledToolbarButton(icon: "wand.and.stars")
    V2DisabledToolbarButton(icon: "slider.horizontal.3")
}
```

**Step 3: Test the implementation**

1. Build and run the app
2. Verify the Add buttons now appear as icon-only squares (28x28) matching Lock/About style
3. Verify hover effect works (amber color, subtle glow)
4. Verify clicking opens the command menu dropdown
5. Verify selecting a command from the menu calls the appropriate action
6. Verify disabled state when locked (greyed out, no hover effect, menu doesn't open)

---

## Task 2: Clean Up Old Component (if Task 1 succeeds)

**Files:**
- Modify: `XtremeMapping/ContentView.swift`

**Step 1: Remove the old V2AddCommandMenuButton**

Delete the entire `V2AddCommandMenuButton` struct (lines ~469-563 in current file) since it's been replaced.

**Step 2: Verify build still succeeds**

Build to ensure no other code references the removed component.

---

## Fallback: Alternative Approach if Overlay Fails

If the overlay technique still doesn't work (menu doesn't open), try these alternatives:

**Alternative A: Use `.buttonStyle(.plain)` removal**
The Menu might work better without `.buttonStyle(.plain)` - try removing it.

**Alternative B: Use NSMenu programmatically**
Create a regular Button that programmatically shows an NSMenu:
```swift
Button {
    showNSMenu()
} label: {
    // styled content
}

func showNSMenu() {
    let menu = NSMenu()
    // populate menu
    menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
}
```

**Alternative C: Try different menuStyle**
Instead of `.menuStyle(.borderlessButton)`, try:
- `.menuStyle(.button)`
- No menuStyle at all (default)
- `.menuStyle(.automatic)`
