//
//  AppThemeV2.swift
//  SuperXtremeMapping
//
//  Alternative design system matching website mockup aesthetic
//  "Pro Audio" - Dense, dark, glowing
//

import SwiftUI

/// V2 Design System - Matches website mockup aesthetic
/// Fully custom dark theme with amber accents and pro-audio styling
enum AppThemeV2 {

    // MARK: - Color Palette

    enum Colors {
        // Primary - Warm Amber
        static let amber = Color(hex: "f59e0b")
        static let amberLight = Color(hex: "fbbf24")
        static let amberDark = Color(hex: "d97706")
        static let amberGlow = Color(hex: "f59e0b").opacity(0.4)
        static let amberSubtle = Color(hex: "f59e0b").opacity(0.1)

        // Stone Neutrals (forced dark)
        static let stone950 = Color(hex: "0c0a09")  // Deepest background
        static let stone900 = Color(hex: "1c1917")  // Main background
        static let stone800 = Color(hex: "292524")  // Elevated surfaces
        static let stone700 = Color(hex: "44403c")  // Borders, dividers
        static let stone600 = Color(hex: "57534e")  // Disabled states
        static let stone500 = Color(hex: "78716c")  // Placeholder text
        static let stone400 = Color(hex: "a8a29e")  // Secondary text
        static let stone300 = Color(hex: "d6d3d1")  // Primary text
        static let stone200 = Color(hex: "e7e5e4")  // Bright text
        static let stone100 = Color(hex: "f5f5f4")  // White text

        // Semantic
        static let success = Color(hex: "10b981")
        static let warning = Color(hex: "f59e0b")
        static let danger = Color(hex: "ef4444")

        // I/O Colors
        static let inputBadge = stone300
        static let outputBadge = amber
    }

    // MARK: - Typography

    enum Typography {
        // Display - for headers like "XXMAPPINGS"
        static let display = Font.system(size: 13, weight: .bold, design: .default)

        // Section headers
        static let sectionHeader = Font.system(size: 11, weight: .semibold, design: .default)

        // Body text
        static let body = Font.system(size: 12, weight: .regular, design: .default)

        // Small labels
        static let caption = Font.system(size: 10, weight: .medium, design: .default)

        // Monospaced for MIDI values
        static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)

        // Tiny text for badges
        static let micro = Font.system(size: 9, weight: .bold, design: .default)
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius

    enum Radius {
        static let xs: CGFloat = 3
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let pill: CGFloat = 100
    }

    // MARK: - Shadows

    enum Shadows {
        static func glow(color: Color = Colors.amber, radius: CGFloat = 8) -> some View {
            EmptyView() // Placeholder - implemented via shadow modifier
        }

        static let amberGlow = (color: Colors.amberGlow, radius: CGFloat(12))
        static let subtleGlow = (color: Colors.amber.opacity(0.2), radius: CGFloat(6))
        static let cardShadow = (color: Color.black.opacity(0.4), radius: CGFloat(16))
    }

    // MARK: - Component Styles

    enum Components {
        // Toolbar
        static let toolbarHeight: CGFloat = 44
        static let toolbarBackground = Colors.stone800

        // Table
        static let tableRowHeight: CGFloat = 28
        static let tableHeaderHeight: CGFloat = 24

        // Settings Panel
        static let settingsPanelWidth: CGFloat = 280
        static let formRowHeight: CGFloat = 32
    }
}

// MARK: - Custom View Modifiers

extension View {
    /// Applies the V2 card/panel style
    func v2Card() -> some View {
        self
            .background(AppThemeV2.Colors.stone800)
            .cornerRadius(AppThemeV2.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg)
                    .stroke(AppThemeV2.Colors.stone700, lineWidth: 1)
            )
    }

    /// Applies amber glow effect
    func v2Glow(_ active: Bool = true) -> some View {
        self.shadow(
            color: active ? AppThemeV2.Colors.amberGlow : .clear,
            radius: active ? 12 : 0
        )
    }

    /// Applies selected/active state styling
    func v2Selected(_ selected: Bool = true) -> some View {
        self
            .background(selected ? AppThemeV2.Colors.amberSubtle : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(selected ? AppThemeV2.Colors.amber.opacity(0.3) : .clear, lineWidth: 1)
            )
    }

    /// Forces dark appearance on this view hierarchy
    func v2ForceDark() -> some View {
        self.preferredColorScheme(.dark)
    }
}

// MARK: - Color Extension for Hex Support

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
