import SwiftUI

/// Compact actions using the same surfaces, borders and accent as the mapping editor.
struct AssistantButtonStyle: ButtonStyle {
    var primary = false
    /// Action buttons adopt the editor's UPPERCASE + tracked label treatment.
    /// Set false for content-bearing buttons (e.g. prompt suggestions) that read as sentences.
    var uppercase = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Appearance(configuration: configuration, primary: primary, uppercase: uppercase, enabled: isEnabled)
    }

    private struct Appearance: View {
        let configuration: ButtonStyleConfiguration
        let primary: Bool
        let uppercase: Bool
        let enabled: Bool
        @State private var hovered = false
        @Environment(\.isFocused) private var focused

        var body: some View {
            label
                .padding(.horizontal, 10).padding(.vertical, 7)
                .foregroundStyle(primary && enabled ? AppThemeV2.Colors.stone950 : enabled ? AppThemeV2.Colors.stone200 : AppThemeV2.Colors.stone500)
                .background(background, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(focused || (hovered && enabled) ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600.opacity(enabled ? 1 : 0.5), lineWidth: 1))
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
        }
        @ViewBuilder private var label: some View {
            if uppercase {
                configuration.label
                    .font(AppThemeV2.Typography.sectionHeader)
                    .textCase(.uppercase)
                    .tracking(0.5)
            } else {
                configuration.label
                    .font(AppThemeV2.Typography.sectionHeader)
            }
        }
        private var background: Color {
            if !enabled { return AppThemeV2.Colors.stone800 }
            if primary { return configuration.isPressed ? AppThemeV2.Colors.amberDark : AppThemeV2.Colors.amber }
            return configuration.isPressed || hovered ? AppThemeV2.Colors.stone700 : AppThemeV2.Colors.stone800
        }
    }
}

/// Amber text button that replaces system-blue `.link` inside the Assistant so links stay on-palette.
struct AssistantLinkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Appearance(configuration: configuration, enabled: isEnabled)
    }

    private struct Appearance: View {
        let configuration: ButtonStyleConfiguration
        let enabled: Bool
        @State private var hovered = false

        var body: some View {
            configuration.label
                .font(AppThemeV2.Typography.body)
                .foregroundStyle(enabled ? (hovered ? AppThemeV2.Colors.amberLight : AppThemeV2.Colors.amber) : AppThemeV2.Colors.stone500)
                .underline(hovered && enabled)
                .opacity(configuration.isPressed ? 0.6 : 1)
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
        }
    }
}

/// Uppercase amber subsection label matching the editor's category-label convention.
struct AssistantSectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(AppThemeV2.Typography.micro)
            .tracking(0.5)
            .foregroundStyle(AppThemeV2.Colors.amber)
    }
}

/// Warning/error banner matching the editor's compatibility-notice treatment.
struct AssistantNoticeBanner: View {
    enum Kind { case warning, danger }
    let kind: Kind
    let text: String

    private var color: Color { kind == .warning ? AppThemeV2.Colors.warning : AppThemeV2.Colors.danger }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(color)
            Text(verbatim: text)
                .foregroundStyle(AppThemeV2.Colors.stone200)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(AppThemeV2.Typography.body)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm))
    }
}
