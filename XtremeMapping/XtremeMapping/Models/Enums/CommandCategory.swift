//
//  CommandCategory.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Categories for filtering Traktor commands in the mapping editor.
///
/// Commands are organized by functional area to make it easier
/// to find and assign mappings.
enum CommandCategory: String, Codable, CaseIterable, Sendable {
    /// Show all commands
    case all = "All"

    /// Deck transport and playback controls
    case decks = "Decks"

    /// Sample deck and Remix Deck controls
    case sampleDecks = "Sample Decks"

    /// Effects unit controls (FX 1-4)
    case effectsUnits = "Effects Units"

    /// Channel faders, EQ, filters, crossfader
    case mixer = "Mixer"

    /// Cue points and loop controls
    case cueLoops = "Cue/Loops"

    /// Loop recorder controls
    case loopRecorder = "Loop Recorder"

    /// Browser navigation and loading
    case browser = "Browser"

    /// Master output, recording, preferences
    case globals = "Globals"
}

/// Filter for input/output direction in mapping lists.
enum IODirection: String, Codable, CaseIterable, Sendable {
    /// Show all mappings (input and output)
    case all = "All"

    /// Show only input mappings (controller to Traktor)
    case input = "In"

    /// Show only output mappings (Traktor to controller LEDs)
    case output = "Out"
}
