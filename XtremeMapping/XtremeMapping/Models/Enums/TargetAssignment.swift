//
//  TargetAssignment.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Specifies which Traktor component a mapping targets.
///
/// Mappings can be assigned to specific decks, FX units, or global functions.
/// Device Target (-1) uses the device's default assignment.
enum TargetAssignment: Int, Codable, CaseIterable, Sendable {
    /// Not yet assigned
    case none = -2

    /// Uses the device's default target assignment
    case deviceTarget = -1

    /// Global functions (browser, master output, etc.)
    case global = 0

    /// Deck A
    case deckA = 1

    /// Deck B
    case deckB = 2

    /// Deck C
    case deckC = 3

    /// Deck D
    case deckD = 4

    /// Effects Unit 1
    case fxUnit1 = 5

    /// Effects Unit 2
    case fxUnit2 = 6

    /// Effects Unit 3
    case fxUnit3 = 7

    /// Effects Unit 4
    case fxUnit4 = 8

    /// Remix Deck Slot 1 (TSI deck value 8; raw value continues the TSI+1 convention)
    case remixSlot1 = 9

    /// Remix Deck Slot 2
    case remixSlot2 = 10

    /// Remix Deck Slot 3
    case remixSlot3 = 11

    /// Remix Deck Slot 4
    case remixSlot4 = 12

    /// Remix Deck Slot 5
    case remixSlot5 = 13

    /// Remix Deck Slot 6
    case remixSlot6 = 14

    /// Remix Deck Slot 7
    case remixSlot7 = 15

    /// Remix Deck Slot 8 (TSI deck value 15)
    case remixSlot8 = 16

    /// Human-readable name for display in the UI
    var displayName: String {
        switch self {
        case .none:
            return "-"
        case .deviceTarget:
            return "Device Target"
        case .global:
            return "Global"
        case .deckA:
            return "Deck A"
        case .deckB:
            return "Deck B"
        case .deckC:
            return "Deck C"
        case .deckD:
            return "Deck D"
        case .fxUnit1:
            return "FX Unit 1"
        case .fxUnit2:
            return "FX Unit 2"
        case .fxUnit3:
            return "FX Unit 3"
        case .fxUnit4:
            return "FX Unit 4"
        case .remixSlot1:
            return "Remix Slot 1"
        case .remixSlot2:
            return "Remix Slot 2"
        case .remixSlot3:
            return "Remix Slot 3"
        case .remixSlot4:
            return "Remix Slot 4"
        case .remixSlot5:
            return "Remix Slot 5"
        case .remixSlot6:
            return "Remix Slot 6"
        case .remixSlot7:
            return "Remix Slot 7"
        case .remixSlot8:
            return "Remix Slot 8"
        }
    }
}
