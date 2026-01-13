//
//  CommandCategoryMatcher.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Utility for categorizing Traktor commands based on their names.
///
/// Commands are categorized by analyzing keywords in their names to determine
/// which functional area they belong to (Decks, Mixer, Effects, etc.).
enum CommandCategoryMatcher {

    // MARK: - Keyword Sets

    /// Keywords that indicate deck-related commands
    private static let deckKeywords: Set<String> = [
        "deck", "play", "pause", "cue", "sync", "tempo", "keylock", "flux",
        "reverse", "jog", "scratch", "beatjump", "beatgrid", "load", "waveform"
    ]

    /// Keywords that indicate sample/remix deck commands
    private static let sampleDeckKeywords: Set<String> = [
        "sample", "remix", "slot", "trigger", "pattern", "step", "sequencer",
        "kit", "stem"
    ]

    /// Keywords that indicate effects unit commands
    private static let effectsKeywords: Set<String> = [
        "fx", "effect", "dry", "wet", "knob", "button"
    ]

    /// Keywords that indicate mixer commands
    private static let mixerKeywords: Set<String> = [
        "eq", "gain", "fader", "crossfader", "filter", "channel", "hi", "mid",
        "lo", "monitor", "headphone", "cue volume"
    ]

    /// Keywords that indicate cue/loop commands
    private static let cueLoopKeywords: Set<String> = [
        "hotcue", "loop", "loop in", "loop out", "loop size", "loop move",
        "active loop", "cue point"
    ]

    /// Keywords that indicate loop recorder commands
    private static let loopRecorderKeywords: Set<String> = [
        "loop recorder", "record", "overdub", "undo", "size", "dry/wet"
    ]

    /// Keywords that indicate browser commands
    private static let browserKeywords: Set<String> = [
        "browser", "tree", "list", "favorites", "playlist", "search",
        "scroll", "expand", "collapse", "load"
    ]

    /// Keywords that indicate global commands
    private static let globalKeywords: Set<String> = [
        "global", "master", "snap", "quantize", "clock", "midi clock",
        "recording", "broadcast", "layout", "fullscreen", "preferences"
    ]

    // MARK: - Category Detection

    /// Determines the category for a given command name.
    ///
    /// - Parameter commandName: The name of the Traktor command
    /// - Returns: The category that best matches the command
    static func category(for commandName: String) -> CommandCategory {
        let name = commandName.lowercased()

        // Check for loop recorder first (more specific than general loops)
        if containsKeyword(name, from: loopRecorderKeywords) &&
           name.contains("loop recorder") {
            return .loopRecorder
        }

        // Check for sample/remix decks before regular decks
        if containsKeyword(name, from: sampleDeckKeywords) {
            return .sampleDecks
        }

        // Check for effects
        if containsKeyword(name, from: effectsKeywords) &&
           !name.contains("deck") {
            return .effectsUnits
        }

        // Check for cue/loops (but not loop recorder)
        if containsKeyword(name, from: cueLoopKeywords) {
            return .cueLoops
        }

        // Check for mixer
        if containsKeyword(name, from: mixerKeywords) {
            return .mixer
        }

        // Check for browser
        if containsKeyword(name, from: browserKeywords) {
            return .browser
        }

        // Check for globals
        if containsKeyword(name, from: globalKeywords) {
            return .globals
        }

        // Check for deck commands last (catch-all for deck-related)
        if containsKeyword(name, from: deckKeywords) {
            return .decks
        }

        // Default to decks for unrecognized commands
        return .decks
    }

    /// Checks if a mapping entry matches the specified category.
    ///
    /// - Parameters:
    ///   - entry: The mapping entry to check
    ///   - category: The category to match against
    /// - Returns: `true` if the entry belongs to the category, `false` otherwise
    static func matches(_ entry: MappingEntry, category: CommandCategory) -> Bool {
        if category == .all {
            return true
        }
        return self.category(for: entry.commandName) == category
    }

    /// Checks if a command name matches the specified category.
    ///
    /// - Parameters:
    ///   - commandName: The command name to check
    ///   - category: The category to match against
    /// - Returns: `true` if the command belongs to the category, `false` otherwise
    static func matches(commandName: String, category: CommandCategory) -> Bool {
        if category == .all {
            return true
        }
        return self.category(for: commandName) == category
    }

    // MARK: - Private Helpers

    /// Checks if the name contains any keyword from the given set.
    private static func containsKeyword(_ name: String, from keywords: Set<String>) -> Bool {
        keywords.contains { keyword in
            name.contains(keyword)
        }
    }
}
