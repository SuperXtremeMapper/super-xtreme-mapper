//
//  ToolbarView.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import SwiftUI

/// Toolbar content providing actions for adding mappings and managing the document.
///
/// Includes buttons for:
/// - Add In: Add a new MIDI input mapping
/// - Add Out: Add a new MIDI output mapping
/// - Add In/Out: Add paired input/output mappings
/// - Wizard: Open the mapping wizard (future feature)
/// - Controller: Open controller setup (future feature)
/// - Lock: Toggle editing lock to prevent accidental changes
struct ToolbarView: ToolbarContent {
    /// The document to modify when adding mappings
    @Binding var document: TraktorMappingDocument

    /// Whether editing is currently locked
    @Binding var isLocked: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Add Input Mapping
            Button {
                addMapping(ioType: .input)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: AppTheme.Icons.addIn)
                        .font(.system(size: 16))
                    Text("Add In")
                        .font(.caption2)
                }
            }
            .help("Add MIDI Input mapping")
            .disabled(isLocked)

            // Add Output Mapping
            Button {
                addMapping(ioType: .output)
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: AppTheme.Icons.addOut)
                        .font(.system(size: 16))
                    Text("Add Out")
                        .font(.caption2)
                }
            }
            .help("Add MIDI Output mapping")
            .disabled(isLocked)

            // Add Paired In/Out Mapping
            Button {
                addInOutPair()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: AppTheme.Icons.addInOut)
                        .font(.system(size: 16))
                    Text("Add In/Out")
                        .font(.caption2)
                }
            }
            .help("Add paired In/Out mapping")
            .disabled(isLocked)

            Divider()

            // Mapping Wizard
            Button {
                showWizard()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: AppTheme.Icons.wizard)
                        .font(.system(size: 16))
                    Text("Wizard")
                        .font(.caption2)
                }
            }
            .help("Open Mapping Wizard")
            .disabled(isLocked)

            // Controller Setup
            Button {
                showControllerSetup()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: AppTheme.Icons.controller)
                        .font(.system(size: 16))
                    Text("Controller")
                        .font(.caption2)
                }
            }
            .help("Controller Setup")
        }

        ToolbarItem(placement: .automatic) {
            Spacer()
        }

        // Lock Toggle (right side)
        ToolbarItem(placement: .primaryAction) {
            Button {
                isLocked.toggle()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: isLocked ? AppTheme.Icons.locked : AppTheme.Icons.unlocked)
                        .font(.system(size: 16))
                        .foregroundColor(isLocked ? AppTheme.dangerColor : AppTheme.accentColor)
                    Text(isLocked ? "Locked" : "Lock")
                        .font(.caption2)
                        .foregroundColor(isLocked ? AppTheme.dangerColor : .primary)
                }
            }
            .help(isLocked ? "Unlock editing" : "Lock to prevent changes")
        }
    }

    // MARK: - Actions

    /// Adds a new mapping entry with the specified I/O direction
    private func addMapping(ioType: IODirection) {
        let newEntry = MappingEntry(
            commandName: "New Command",
            ioType: ioType,
            assignment: .global,
            interactionMode: ioType == .input ? .hold : .output,
            midiChannel: 1
        )

        // Add to first device or create one if none exist
        if document.mappingFile.devices.isEmpty {
            let device = Device(name: "Generic MIDI", mappings: [newEntry])
            document.mappingFile.devices.append(device)
        } else {
            document.mappingFile.devices[0].mappings.append(newEntry)
        }
    }

    /// Adds a paired input and output mapping
    private func addInOutPair() {
        let inputEntry = MappingEntry(
            commandName: "New Command",
            ioType: .input,
            assignment: .global,
            interactionMode: .hold,
            midiChannel: 1
        )

        let outputEntry = MappingEntry(
            commandName: "New Command",
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

    /// Shows the mapping wizard sheet
    private func showWizard() {
        // TODO: Implement wizard sheet presentation
        // This will be a guided flow for creating common mappings
    }

    /// Shows the controller setup sheet
    private func showControllerSetup() {
        // TODO: Implement controller setup sheet
        // This will allow configuring MIDI ports and device settings
    }
}
