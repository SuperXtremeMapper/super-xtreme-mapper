//
//  ClipboardManager.swift
//  SuperXtremeMapping
//
//  Manages app-wide clipboard for MIDI assignments and modifiers
//

import Foundation
import Combine

/// Singleton manager for mapping clipboard operations
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    /// Copied MIDI assignment data (channel, note, CC)
    @Published var mappedToClipboard: MappedToData?

    /// Copied modifier conditions
    @Published var modifiersClipboard: ModifiersData?

    private init() {}

    /// Data for copied MIDI assignment
    struct MappedToData {
        let midiChannel: Int
        let midiNote: Int?
        let midiCC: Int?
    }

    /// Data for copied modifier conditions
    struct ModifiersData {
        let modifier1: ModifierCondition?
        let modifier2: ModifierCondition?
    }

    /// Copy MIDI assignment from a mapping entry
    func copyMappedTo(from entry: MappingEntry) {
        mappedToClipboard = MappedToData(
            midiChannel: entry.midiChannel,
            midiNote: entry.midiNote,
            midiCC: entry.midiCC
        )
    }

    /// Paste MIDI assignment to a mapping entry
    func pasteMappedTo(to entry: inout MappingEntry) {
        guard let data = mappedToClipboard else { return }
        entry.midiChannel = data.midiChannel
        entry.midiNote = data.midiNote
        entry.midiCC = data.midiCC
    }

    /// Copy modifiers from a mapping entry
    func copyModifiers(from entry: MappingEntry) {
        modifiersClipboard = ModifiersData(
            modifier1: entry.modifier1Condition,
            modifier2: entry.modifier2Condition
        )
    }

    /// Paste modifiers to a mapping entry
    func pasteModifiers(to entry: inout MappingEntry) {
        guard let data = modifiersClipboard else { return }
        entry.modifier1Condition = data.modifier1
        entry.modifier2Condition = data.modifier2
    }

    /// Check if MIDI clipboard has data
    var hasMappedToData: Bool {
        mappedToClipboard != nil
    }

    /// Check if modifiers clipboard has data
    var hasModifiersData: Bool {
        modifiersClipboard != nil
    }
}
