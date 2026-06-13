//
//  WizardSetupConfig.swift
//  XtremeMapping
//

import Foundation

/// Configuration captured during wizard setup phase.
struct WizardSetupConfig {
    var controllerName: String = ""
    var numberOfChannels: Int = 2  // 1, 2, or 4
    var deviceTarget: TargetAssignment = .deviceTarget
    var inputPort: String = ""
    var outputPort: String = ""

    var isValid: Bool {
        !controllerName.isEmpty && !inputPort.isEmpty
    }

    /// Returns deck assignments based on channel count
    var deckAssignments: [TargetAssignment] {
        switch numberOfChannels {
        case 1: return [.deckA]
        case 2: return [.deckA, .deckB]
        default: return [.deckA, .deckB, .deckC, .deckD]
        }
    }

    /// Returns Remix Deck slot assignments for the selected deck count.
    /// Traktor encodes remix-slot command targets as deckIndex * 4 + slotIndex,
    /// so a two-channel setup maps Deck A Slot 1-4 and Deck B Slot 1-4.
    var slotAssignments: [TargetAssignment] {
        deckAssignments.flatMap { deck in
            (1...4).compactMap { TargetAssignment.remixSlotAssignment(forDeck: deck, slot: $0) }
        }
    }

    /// Returns FX unit assignments (always 1-2 for basic, 1-4 for advanced)
    func fxAssignments(isBasic: Bool) -> [TargetAssignment] {
        if isBasic {
            return [.fxUnit1, .fxUnit2]
        } else {
            return [.fxUnit1, .fxUnit2, .fxUnit3, .fxUnit4]
        }
    }
}
