import SwiftUI
import AppKit

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
                Text("ABOUT")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(1)
                    .foregroundColor(AppThemeV2.Colors.amber)

                Text("Super Xtreme Mapper")
                    .font(AppThemeV2.Typography.body)
                    .foregroundColor(AppThemeV2.Colors.stone400)
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // App info section
            HStack(spacing: AppThemeV2.Spacing.md) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xxs) {
                    Text("Super Xtreme Mapper")
                        .font(AppThemeV2.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppThemeV2.Colors.stone200)

                    Text("A revived TSI Editor for Traktor")
                        .font(AppThemeV2.Typography.caption)
                        .foregroundColor(AppThemeV2.Colors.stone500)

                    Text("Version 0.1")
                        .font(AppThemeV2.Typography.micro)
                        .foregroundColor(AppThemeV2.Colors.amber)
                }
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Credits section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                Text("CREDITS")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
                    creditRow(title: "Xtreme Mapping (inspiration)", name: "Vincenzo Pietropaolo", link: "https://www.xtrememapping.com/")
                    creditRow(title: "TSI Research", name: "IvanZ", link: "https://github.com/ivanz")
                    creditRow(title: "CMDR Editor", name: "cmdr-editor", link: "https://cmdr-editor.github.io/cmdr/")
                }
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Feedback section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                Text("FEEDBACK")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                Button(action: sendFeedback) {
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Image(systemName: "envelope")
                            .font(.system(size: 10))
                        Text("BUG REPORT / FEEDBACK")
                            .font(AppThemeV2.Typography.micro)
                            .tracking(0.5)
                    }
                    .foregroundColor(AppThemeV2.Colors.stone200)
                    .padding(.horizontal, AppThemeV2.Spacing.md)
                    .padding(.vertical, AppThemeV2.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                            .fill(AppThemeV2.Colors.stone700)
                    )
                }
                .buttonStyle(.plain)

                Text("sxtrememapper@proton.me")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
            }

            Rectangle()
                .fill(AppThemeV2.Colors.stone700)
                .frame(height: 1)

            // Support section
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
                Text("SUPPORT SXM")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
                    .foregroundColor(AppThemeV2.Colors.stone400)

                Text("Super Xtreme Mapper is free and open source. If you find it useful, consider supporting development!")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppThemeV2.Spacing.sm) {
                    Button(action: { openURL(URL(string: "https://github.com/sponsors/nraford7")!) }) {
                        HStack(spacing: AppThemeV2.Spacing.xs) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                            Text("SPONSOR")
                                .font(AppThemeV2.Typography.micro)
                                .tracking(0.5)
                        }
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .padding(.horizontal, AppThemeV2.Spacing.md)
                        .padding(.vertical, AppThemeV2.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                .fill(AppThemeV2.Colors.stone700)
                        )
                    }
                    .buttonStyle(.plain)

                    CoffeeButton(openURL: openURL)
                }
            }

            Spacer()

            // Trademark disclaimer and Done button
            VStack(spacing: AppThemeV2.Spacing.md) {
                Text("Traktor is a registered trademark of Native Instruments GmbH.")
                    .font(AppThemeV2.Typography.micro)
                    .foregroundColor(AppThemeV2.Colors.stone600)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Text("DONE")
                            .font(AppThemeV2.Typography.micro)
                            .tracking(0.5)
                            .fontWeight(.semibold)
                            .foregroundColor(AppThemeV2.Colors.stone900)
                            .padding(.horizontal, AppThemeV2.Spacing.lg)
                            .padding(.vertical, AppThemeV2.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                                    .fill(AppThemeV2.Colors.amber)
                            )
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
        }
        .padding(AppThemeV2.Spacing.xl)
        .frame(width: 460, height: 600)
        .background(AppThemeV2.Colors.stone800)
        .preferredColorScheme(.dark)
    }

    private func creditRow(title: String, name: String, link: String? = nil) -> some View {
        HStack(spacing: AppThemeV2.Spacing.xs) {
            Text(title)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone300)
            Text("—")
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone600)
            Text(name)
                .font(AppThemeV2.Typography.caption)
                .foregroundColor(AppThemeV2.Colors.stone500)
            if let link = link, let url = URL(string: link) {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9))
                        .foregroundColor(AppThemeV2.Colors.amber)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func sendFeedback() {
        let subject = "Super Xtreme Mapper Feedback"
        let email = "sxtrememapper@proton.me"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Coffee Button with Hover Glow

struct CoffeeButton: View {
    let openURL: OpenURLAction
    @State private var isHovered = false

    var body: some View {
        Button(action: { openURL(URL(string: "https://ko-fi.com/superxtrememapper")!) }) {
            HStack(spacing: AppThemeV2.Spacing.xs) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 10))
                Text("BUY US A COFFEE")
                    .font(AppThemeV2.Typography.micro)
                    .tracking(0.5)
            }
            .foregroundColor(isHovered ? AppThemeV2.Colors.amber : AppThemeV2.Colors.stone200)
            .padding(.horizontal, AppThemeV2.Spacing.md)
            .padding(.vertical, AppThemeV2.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .fill(isHovered ? AppThemeV2.Colors.amberSubtle : AppThemeV2.Colors.stone700)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm)
                    .stroke(isHovered ? AppThemeV2.Colors.amber.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .shadow(
            color: isHovered ? AppThemeV2.Colors.amberGlow : .clear,
            radius: isHovered ? 8 : 0
        )
    }
}

#Preview("About Sheet") {
    AboutSheet()
}
