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

    /// Legacy generic remix target 1 (non-slot-command target value 8)
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

    /// Legacy generic remix target 8 (non-slot-command target value 15)
    case remixSlot8 = 16

    /// Remix Deck A, Slot 1 (slot-command target value 0)
    case remixDeckASlot1 = 17
    case remixDeckASlot2 = 18
    case remixDeckASlot3 = 19
    case remixDeckASlot4 = 20

    /// Remix Deck B, Slot 1 (slot-command target value 4)
    case remixDeckBSlot1 = 21
    case remixDeckBSlot2 = 22
    case remixDeckBSlot3 = 23
    case remixDeckBSlot4 = 24

    /// Remix Deck C, Slot 1 (slot-command target value 8)
    case remixDeckCSlot1 = 25
    case remixDeckCSlot2 = 26
    case remixDeckCSlot3 = 27
    case remixDeckCSlot4 = 28

    /// Remix Deck D, Slot 1 (slot-command target value 12)
    case remixDeckDSlot1 = 29
    case remixDeckDSlot2 = 30
    case remixDeckDSlot3 = 31
    case remixDeckDSlot4 = 32

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
        case .remixDeckASlot1:
            return "Deck A Slot 1"
        case .remixDeckASlot2:
            return "Deck A Slot 2"
        case .remixDeckASlot3:
            return "Deck A Slot 3"
        case .remixDeckASlot4:
            return "Deck A Slot 4"
        case .remixDeckBSlot1:
            return "Deck B Slot 1"
        case .remixDeckBSlot2:
            return "Deck B Slot 2"
        case .remixDeckBSlot3:
            return "Deck B Slot 3"
        case .remixDeckBSlot4:
            return "Deck B Slot 4"
        case .remixDeckCSlot1:
            return "Deck C Slot 1"
        case .remixDeckCSlot2:
            return "Deck C Slot 2"
        case .remixDeckCSlot3:
            return "Deck C Slot 3"
        case .remixDeckCSlot4:
            return "Deck C Slot 4"
        case .remixDeckDSlot1:
            return "Deck D Slot 1"
        case .remixDeckDSlot2:
            return "Deck D Slot 2"
        case .remixDeckDSlot3:
            return "Deck D Slot 3"
        case .remixDeckDSlot4:
            return "Deck D Slot 4"
        }
    }

    /// Traktor overloads the CMAD target field for remix-slot commands:
    /// target = deckIndex * 4 + slotIndex, with Deck A/Slot 1 encoded as 0.
    var remixSlotCommandTargetValue: Int32? {
        switch self {
        case .remixSlot1, .remixDeckASlot1: return 0
        case .remixSlot2, .remixDeckASlot2: return 1
        case .remixSlot3, .remixDeckASlot3: return 2
        case .remixSlot4, .remixDeckASlot4: return 3
        case .remixSlot5, .remixDeckBSlot1: return 4
        case .remixSlot6, .remixDeckBSlot2: return 5
        case .remixSlot7, .remixDeckBSlot3: return 6
        case .remixSlot8, .remixDeckBSlot4: return 7
        case .remixDeckCSlot1: return 8
        case .remixDeckCSlot2: return 9
        case .remixDeckCSlot3: return 10
        case .remixDeckCSlot4: return 11
        case .remixDeckDSlot1: return 12
        case .remixDeckDSlot2: return 13
        case .remixDeckDSlot3: return 14
        case .remixDeckDSlot4: return 15
        case .deckA: return 0
        case .deckB: return 4
        case .deckC: return 8
        case .deckD: return 12
        default: return nil
        }
    }

    var deckTargetValueForNonSlotCommand: Int32? {
        switch self {
        case .remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4:
            return 0
        case .remixDeckBSlot1, .remixDeckBSlot2, .remixDeckBSlot3, .remixDeckBSlot4:
            return 1
        case .remixDeckCSlot1, .remixDeckCSlot2, .remixDeckCSlot3, .remixDeckCSlot4:
            return 2
        case .remixDeckDSlot1, .remixDeckDSlot2, .remixDeckDSlot3, .remixDeckDSlot4:
            return 3
        default:
            return nil
        }
    }

    static func remixSlotAssignment(forDeck deck: TargetAssignment, slot: Int) -> TargetAssignment? {
        switch (deck, slot) {
        case (.deckA, 1): return .remixDeckASlot1
        case (.deckA, 2): return .remixDeckASlot2
        case (.deckA, 3): return .remixDeckASlot3
        case (.deckA, 4): return .remixDeckASlot4
        case (.deckB, 1): return .remixDeckBSlot1
        case (.deckB, 2): return .remixDeckBSlot2
        case (.deckB, 3): return .remixDeckBSlot3
        case (.deckB, 4): return .remixDeckBSlot4
        case (.deckC, 1): return .remixDeckCSlot1
        case (.deckC, 2): return .remixDeckCSlot2
        case (.deckC, 3): return .remixDeckCSlot3
        case (.deckC, 4): return .remixDeckCSlot4
        case (.deckD, 1): return .remixDeckDSlot1
        case (.deckD, 2): return .remixDeckDSlot2
        case (.deckD, 3): return .remixDeckDSlot3
        case (.deckD, 4): return .remixDeckDSlot4
        default: return nil
        }
    }

    static func remixSlotAssignment(forTargetValue target: Int) -> TargetAssignment {
        switch target {
        case 0: return .remixDeckASlot1
        case 1: return .remixDeckASlot2
        case 2: return .remixDeckASlot3
        case 3: return .remixDeckASlot4
        case 4: return .remixDeckBSlot1
        case 5: return .remixDeckBSlot2
        case 6: return .remixDeckBSlot3
        case 7: return .remixDeckBSlot4
        case 8: return .remixDeckCSlot1
        case 9: return .remixDeckCSlot2
        case 10: return .remixDeckCSlot3
        case 11: return .remixDeckCSlot4
        case 12: return .remixDeckDSlot1
        case 13: return .remixDeckDSlot2
        case 14: return .remixDeckDSlot3
        case 15: return .remixDeckDSlot4
        default: return .global
        }
    }
}
