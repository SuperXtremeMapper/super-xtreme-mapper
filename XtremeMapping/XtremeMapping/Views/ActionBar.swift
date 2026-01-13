//
//  ActionBar.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI
import Combine

/// A horizontal action bar with buttons for adding mappings and managing the document.
/// Positioned below the window title and above the main content.
struct ActionBar: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var isLocked: Bool
    @Environment(\.undoManager) var undoManager
    @State private var showingAbout = false

    /// Registers a change with the undo manager to mark document as edited
    private func registerChange() {
        undoManager?.registerUndo(withTarget: document) { doc in
            doc.objectWillChange.send()
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Add In mapping with command menu
            AddCommandMenuButton(
                icon: "arrow.down",
                label: "Add In",
                isDisabled: isLocked
            ) { commandName in
                addMapping(ioType: .input, commandName: commandName)
            }

            // Add Out mapping with command menu
            AddCommandMenuButton(
                icon: "arrow.up",
                label: "Add Out",
                isDisabled: isLocked
            ) { commandName in
                addMapping(ioType: .output, commandName: commandName)
            }

            // Add In/Out pair with command menu
            AddCommandMenuButton(
                icon: "arrow.up.arrow.down",
                label: "In/Out",
                isDisabled: isLocked
            ) { commandName in
                addInOutPair(commandName: commandName)
            }

            Divider()
                .frame(height: 24)
                .background(AppTheme.dividerColor.opacity(0.5))

            ActionButton(
                icon: "wand.and.stars",
                label: "Wizard",
                action: { showWizard() },
                isDisabled: true,
                isPlaceholder: true
            )

            ActionButton(
                icon: "slider.horizontal.3",
                label: "Controller",
                action: { showControllerSetup() },
                isDisabled: true,
                isPlaceholder: true
            )

            Spacer()

            // Lock toggle on the right
            ActionButton(
                icon: isLocked ? "lock.fill" : "lock.open",
                label: isLocked ? "Locked" : "Lock",
                action: { isLocked.toggle() },
                isDisabled: false,
                isActive: isLocked,
                activeColor: AppTheme.dangerColor
            )

            // About button
            ActionButton(
                icon: "info.circle",
                label: "About",
                action: { showingAbout = true },
                isDisabled: false
            )
        }
        .padding(.horizontal, AppTheme.contentPadding)
        .padding(.vertical, 8)
        .background(AppTheme.backgroundColor)
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
        }
    }

    // MARK: - Actions

    private func addMapping(ioType: IODirection, commandName: String) {
        registerChange()

        let newEntry = MappingEntry(
            commandName: commandName,
            ioType: ioType,
            assignment: .global,
            interactionMode: ioType == .input ? .hold : .output,
            midiChannel: 1
        )

        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: [newEntry])
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(newEntry)
        }
    }

    private func addInOutPair(commandName: String) {
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
    }

    private func showWizard() {
        // TODO: Implement wizard sheet
    }

    private func showControllerSetup() {
        // TODO: Implement controller setup sheet
    }
}

// MARK: - Action Button

/// A styled button for the action bar
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var isDisabled: Bool = false
    var isActive: Bool = false
    var activeColor: Color = AppTheme.accentColor
    var isPlaceholder: Bool = false
    var warningText: String? = nil

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 3) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(buttonColor)

                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(buttonColor)
                }
                .frame(width: 52, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 1)
                )

                // Beta badge if warning text is present
                if warningText != nil {
                    Text("BETA")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.orange)
                        .cornerRadius(3)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(warningText ?? label)
    }

    private var buttonColor: Color {
        if isDisabled || isPlaceholder {
            return AppTheme.mutedTextColor
        } else if isActive {
            return activeColor
        } else if isHovered {
            return AppTheme.accentColor
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isPlaceholder {
            return Color.clear
        } else if isHovered && !isDisabled {
            return AppTheme.hoverColor
        } else if isActive {
            return activeColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isPlaceholder {
            return AppTheme.dividerColor.opacity(0.3)
        } else if isActive {
            return activeColor.opacity(0.5)
        } else if isHovered && !isDisabled {
            return AppTheme.accentColor.opacity(0.3)
        } else {
            return AppTheme.dividerColor.opacity(0.3)
        }
    }
}

// MARK: - Add Command Menu Button

/// A button that shows a hierarchical menu of Traktor commands when clicked.
struct AddCommandMenuButton: View {
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
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .medium))
            }
            .foregroundColor(buttonColor)
            .frame(height: 36)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(backgroundColor)
                    )
            )
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isDisabled)
        .help(label)
    }

    @ViewBuilder
    private func categoryMenu(_ category: CommandCategory2) -> some View {
        if let subcategories = category.subcategories {
            // Category with subcategories
            Menu(category.name) {
                ForEach(subcategories) { subcategory in
                    subcategoryMenu(subcategory)
                }
            }
        } else if let commands = category.commands {
            // Category with direct commands
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

    private var buttonColor: Color {
        if isDisabled {
            return AppTheme.mutedTextColor
        } else if isHovered {
            return AppTheme.accentColor
        } else {
            return .primary
        }
    }

    private var backgroundColor: Color {
        if isHovered && !isDisabled {
            return AppTheme.hoverColor
        } else {
            return Color.clear
        }
    }

    private var borderColor: Color {
        if isHovered && !isDisabled {
            return AppTheme.accentColor.opacity(0.3)
        } else {
            return AppTheme.dividerColor.opacity(0.3)
        }
    }
}

// MARK: - About Sheet

/// A styled sheet showing about information, credits, and feedback
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.mutedTextColor)
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

                    Text("XXtreme Mapping")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("A revived TSI Editor for Traktor,\nin the spirit of Xtreme Mapping (RIP)")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.mutedTextColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Version 0.1")
                        .font(.caption)
                        .foregroundColor(AppTheme.accentColor)
                }

                Divider()
                    .background(AppTheme.dividerColor)

                // Credits section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Credits & Acknowledgments")
                        .font(.subheadline)
                        .fontWeight(.semibold)
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
                    .background(AppTheme.dividerColor)

                // Feedback button
                Button(action: sendFeedback) {
                    HStack {
                        Image(systemName: "envelope")
                        Text("Bug Report / Feedback")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accentColor)

                Text("XXtremeMapper@protonmail.com")
                    .font(.caption)
                    .foregroundColor(AppTheme.mutedTextColor)

                Divider()
                    .background(AppTheme.dividerColor)

                // Trademark disclaimer
                Text("Traktor is a registered trademark of Native Instruments GmbH. Its use does not imply affiliation with or endorsement by the trademark owner.")
                    .font(.caption2)
                    .foregroundColor(AppTheme.mutedTextColor)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 400)
        .background(AppTheme.surfaceColor)
    }

    @ViewBuilder
    private func creditRow(title: String, name: String, description: String, link: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)

                if let link = link {
                    Button(action: { openURL(URL(string: link)!) }) {
                        Image(systemName: "link")
                            .font(.system(size: 9))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppTheme.accentColor)
                }
            }

            Text(name)
                .font(.caption2)
                .foregroundColor(AppTheme.mutedTextColor)

            Text(description)
                .font(.caption2)
                .foregroundColor(AppTheme.mutedTextColor)
                .italic()
        }
        .padding(.vertical, 3)
    }

    private func sendFeedback() {
        let subject = "XXtreme Mapper Feedback"
        let email = "XXtremeMapper@protonmail.com"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject)") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ActionBar(
        document: TraktorMappingDocument(),
        isLocked: .constant(false)
    )
    .frame(width: 600)
}

#Preview("About Sheet") {
    AboutSheet()
}
