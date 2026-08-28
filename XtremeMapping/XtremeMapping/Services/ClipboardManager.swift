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

    /// Copied MIDI assignment data, including opaque native pass-through state.
    @Published var mappedToClipboard: MappedToData?

    /// Copied modifier conditions
    @Published var modifiersClipboard: ModifiersData?

    /// Ordered mapping snapshots copied between document windows.
    @Published private(set) var mappingsClipboard: [MappingEntry] = []

    private init() {}

    /// Data for copied MIDI assignment
    struct MappedToData {
        let midiAssignment: MIDIAssignment
        let rawMidiControlName: String?
        let rawMidiBindingID: UInt32?
        let rawDCDTEncoderMode: UInt32?
        let rawDCDTControlType: UInt32?
        let rawDCDTMinValueBits: UInt32?
        let rawDCDTMaxValueBits: UInt32?
        let rawDCDTControlID: UInt32?
    }

    /// Data for copied modifier conditions
    struct ModifiersData {
        let modifier1: ModifierCondition?
        let modifier2: ModifierCondition?
    }

    /// Copy MIDI assignment from a mapping entry
    func copyMappedTo(from entry: MappingEntry) {
        mappedToClipboard = MappedToData(
            midiAssignment: entry.midiAssignment,
            rawMidiControlName: entry.rawMidiControlName,
            rawMidiBindingID: entry.rawMidiBindingID,
            rawDCDTEncoderMode: entry.rawDCDTEncoderMode,
            rawDCDTControlType: entry.rawDCDTControlType,
            rawDCDTMinValueBits: entry.rawDCDTMinValueBits,
            rawDCDTMaxValueBits: entry.rawDCDTMaxValueBits,
            rawDCDTControlID: entry.rawDCDTControlID
        )
    }

    /// Paste MIDI assignment to a mapping entry
    func pasteMappedTo(to entry: inout MappingEntry) {
        guard let data = mappedToClipboard else { return }
        // Assigning modeled MIDI intentionally clears compatibility state;
        // restore the copied native state immediately afterward.
        entry.midiAssignment = data.midiAssignment
        entry.rawMidiControlName = data.rawMidiControlName
        entry.rawMidiBindingID = data.rawMidiControlName == nil ? data.rawMidiBindingID : nil
        entry.rawDCDTEncoderMode = data.rawDCDTEncoderMode
        entry.rawDCDTControlType = data.rawDCDTControlType
        entry.rawDCDTMinValueBits = data.rawDCDTMinValueBits
        entry.rawDCDTMaxValueBits = data.rawDCDTMaxValueBits
        entry.rawDCDTControlID = data.rawDCDTControlID
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

    /// Replaces the app-wide mapping group without changing source identities.
    func copyMappings(_ mappings: [MappingEntry]) {
        mappingsClipboard = mappings
    }

    /// Check if MIDI clipboard has data
    var hasMappedToData: Bool {
        mappedToClipboard != nil
    }

    /// Check if modifiers clipboard has data
    var hasModifiersData: Bool {
        modifiersClipboard != nil
    }

    /// Whether the app-wide mapping group contains at least one source snapshot.
    var hasMappingsData: Bool {
        !mappingsClipboard.isEmpty
    }
}
