//
//  AppTheme.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI

/// Centralized theme constants for consistent styling across the app.
///
/// The Xtreme Mapping theme uses the "Vinyl Warmth" design system with
/// warm amber accents and stone neutrals for a professional DJ software aesthetic.
enum AppTheme {

    // MARK: - Primary Colors (Amber)

    /// Primary accent color (warm amber)
    static let accentColor = Color(hex: "f59e0b")

    /// Lighter amber for highlights
    static let accentLight = Color(hex: "fbbf24")

    /// Darker amber for pressed states
    static let accentDark = Color(hex: "d97706")

    /// Secondary accent for highlights
    static let secondaryAccent = Color(hex: "f59e0b").opacity(0.7)

    // MARK: - Secondary Colors (Violet)

    /// Secondary color for complementary accents
    static let secondaryColor = Color(hex: "8b5cf6")

    /// Lighter violet
    static let secondaryLight = Color(hex: "a78bfa")

    /// Darker violet
    static let secondaryDark = Color(hex: "7c3aed")

    // MARK: - Semantic Colors

    /// Success state color
    static let successColor = Color(hex: "10b981")

    /// Warning state color
    static let warningColor = Color(hex: "f59e0b")

    /// Danger/error state color
    static let dangerColor = Color(hex: "ef4444")

    // MARK: - Neutral Colors (Warm Stone)

    /// Background color for main window
    static let backgroundColor = Color(nsColor: .windowBackgroundColor)

    /// Background color for table and list views
    static let tableBackground = Color(nsColor: .controlBackgroundColor)

    /// Warm surface background for cards/panels
    static let surfaceColor = Color(hex: "292524")

    /// Slightly elevated surface
    static let surfaceElevatedColor = Color(hex: "44403c")

    /// Color for selected rows (warm amber selection)
    static let selectionColor = Color(hex: "f59e0b").opacity(0.3)

    /// Color for hover states
    static let hoverColor = Color(hex: "f59e0b").opacity(0.1)

    /// Color for dividers and separators
    static let dividerColor = Color(hex: "f59e0b").opacity(0.4)

    /// Color for input mappings
    static let inputColor = Color.primary

    /// Color for output mappings (warm amber)
    static let outputColor = Color(hex: "f59e0b")

    /// Color for locked state indicator
    static let lockedColor = Color(hex: "ef4444")

    /// Color for secondary/placeholder text
    static let secondaryTextColor = Color.secondary

    /// Muted text color
    static let mutedTextColor = Color(hex: "a8a29e")

    // MARK: - Fonts

    /// Font for section headers (MAPPINGS, SETTINGS)
    static let headerFont = Font.headline

    /// Font for labels and captions
    static let labelFont = Font.caption

    /// Font for body text
    static let bodyFont = Font.body

    /// Font for monospaced content (MIDI values)
    static let monospacedFont = Font.system(.body, design: .monospaced)

    // MARK: - Spacing

    /// Standard padding for content areas
    static let contentPadding: CGFloat = 16

    /// Padding for header areas
    static let headerPadding: CGFloat = 8

    /// Spacing between form elements
    static let formSpacing: CGFloat = 16

    /// Spacing between items in a group
    static let itemSpacing: CGFloat = 8

    // MARK: - Sizes

    /// Minimum width for the mappings table panel
    static let minTableWidth: CGFloat = 500

    /// Minimum width for the settings panel
    static let minSettingsPanelWidth: CGFloat = 250

    /// Maximum width for the settings panel
    static let maxSettingsPanelWidth: CGFloat = 300

    /// Standard corner radius for controls
    static let cornerRadius: CGFloat = 5

    // MARK: - Toolbar Icons

    /// SF Symbol names for toolbar buttons
    enum Icons {
        static let addIn = "arrow.down.to.line"
        static let addOut = "arrow.up.to.line"
        static let addInOut = "arrow.up.arrow.down"
        static let wizard = "wand.and.stars"
        static let controller = "slider.horizontal.3"
        static let locked = "lock.fill"
        static let unlocked = "lock.open"
        static let menu = "line.3.horizontal"
    }
}

// MARK: - View Extensions

extension View {
    /// Applies the standard header style for section titles
    func headerStyle() -> some View {
        self
            .font(AppTheme.headerFont)
            .foregroundColor(AppTheme.accentColor)
    }

    /// Applies the standard label style for form labels
    func labelStyle() -> some View {
        self
            .font(AppTheme.labelFont)
            .foregroundColor(AppTheme.secondaryTextColor)
    }

    /// Applies the warm amber divider style
    func warmDivider() -> some View {
        Divider()
            .background(AppTheme.dividerColor)
    }

    /// Applies a warm glow effect for focused/active elements
    func warmGlow(_ isActive: Bool = true) -> some View {
        self.shadow(
            color: isActive ? AppTheme.accentColor.opacity(0.3) : .clear,
            radius: isActive ? 8 : 0
        )
    }

    /// Applies a card-like surface style
    func surfaceStyle() -> some View {
        self
            .background(AppTheme.surfaceColor)
            .cornerRadius(AppTheme.cornerRadius)
    }
}

// MARK: - Color Extension for Hex

extension Color {
    /// Creates a color from a hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
