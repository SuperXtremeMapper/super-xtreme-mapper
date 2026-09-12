import SwiftUI

/// Compact actions using the same surfaces, borders and accent as the mapping editor.
struct AssistantButtonStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Appearance(configuration: configuration, primary: primary, enabled: isEnabled)
    }

    private struct Appearance: View {
        let configuration: ButtonStyleConfiguration
        let primary: Bool
        let enabled: Bool
        @State private var hovered = false
        @Environment(\.isFocused) private var focused

        var body: some View {
            configuration.label
                .font(AppThemeV2.Typography.sectionHeader)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .foregroundStyle(primary && enabled ? AppThemeV2.Colors.stone950 : enabled ? AppThemeV2.Colors.stone200 : AppThemeV2.Colors.stone500)
                .background(background, in: RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm))
                .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(focused || (hovered && enabled) ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone600.opacity(enabled ? 1 : 0.5), lineWidth: 1))
                .contentShape(Rectangle())
                .onHover { hovered = $0 }
        }
        private var background: Color {
            if !enabled { return AppThemeV2.Colors.stone800 }
            if primary { return configuration.isPressed ? AppThemeV2.Colors.amberDark : AppThemeV2.Colors.amber }
            return configuration.isPressed || hovered ? AppThemeV2.Colors.stone700 : AppThemeV2.Colors.stone800
        }
    }
}
