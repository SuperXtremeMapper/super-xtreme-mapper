import SwiftUI
import AppKit

struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppThemeV2.Colors.stone500)
                }
                .buttonStyle(.plain)
                .padding(12)
            }

            // Main content
            VStack(spacing: 20) {
                // App icon and name
                VStack(spacing: 8) {
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 64, height: 64)

                    Text("Super Xtreme Mapper")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppThemeV2.Colors.stone100)

                    Text("A revived TSI Editor for Traktor,\nin the spirit of Xtreme Mapping (RIP)")
                        .font(.subheadline)
                        .foregroundColor(AppThemeV2.Colors.stone500)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Version 0.1")
                        .font(.caption)
                        .foregroundColor(AppThemeV2.Colors.amber)
                }

                Divider()
                    .background(AppThemeV2.Colors.stone700)

                // Credits section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Credits & Acknowledgments")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppThemeV2.Colors.stone200)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        creditRow(
                            title: "Original Xtreme Mapping",
                            name: "Vincenzo Pietropaolo",
                            description: "Creator of the original Xtreme Mapping app that inspired this project"
                        )

                        creditRow(
                            title: "IvanZ",
                            name: "GitHub Contributor",
                            description: "TSI format research and documentation",
                            link: "https://github.com/ivanz"
                        )

                        creditRow(
                            title: "CMDR Team",
                            name: "cmdr-editor",
                            description: "Traktor command database and TSI editor",
                            link: "https://cmdr-editor.github.io/cmdr/"
                        )
                    }
                    .padding(.leading, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .background(AppThemeV2.Colors.stone700)

                // Feedback button
                Button {
                    sendFeedback()
                } label: {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Bug Report / Feedback")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppThemeV2.Colors.amber)

                Text("sxtrememapper@proton.me")
                    .font(.caption)
                    .foregroundColor(AppThemeV2.Colors.stone500)

                Divider()
                    .background(AppThemeV2.Colors.stone700)

                // Support section
                VStack(spacing: 12) {
                    Text("Support Development")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppThemeV2.Colors.stone200)

                    HStack(spacing: 16) {
                        Button {
                            if let url = URL(string: "https://github.com/sponsors/nraford7") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.fill")
                                Text("GitHub Sponsors")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppThemeV2.Colors.stone600)

                        Button {
                            if let url = URL(string: "https://ko-fi.com/superxtrememapper") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cup.and.saucer.fill")
                                Text("Buy Me a Coffee")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppThemeV2.Colors.stone600)
                    }
                }

                Divider()
                    .background(AppThemeV2.Colors.stone700)

                // Trademark disclaimer
                Text("Traktor is a registered trademark of Native Instruments GmbH. Its use does not imply affiliation with or endorsement by the trademark owner.")
                    .font(.caption2)
                    .foregroundColor(AppThemeV2.Colors.stone500)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 400)
        .background(AppThemeV2.Colors.stone800)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func creditRow(title: String, name: String, description: String, link: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppThemeV2.Colors.stone200)

                if let link = link, let url = URL(string: link) {
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppThemeV2.Colors.amber)
                }
            }

            Text(name)
                .font(.caption2)
                .foregroundColor(AppThemeV2.Colors.stone500)

            Text(description)
                .font(.caption2)
                .foregroundColor(AppThemeV2.Colors.stone500)
                .italic()
        }
        .padding(.vertical, 3)
    }

    private func sendFeedback() {
        let subject = "Super Xtreme Mapper Feedback"
        let email = "sxtrememapper@proton.me"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview("About Sheet") {
    AboutSheet()
}
