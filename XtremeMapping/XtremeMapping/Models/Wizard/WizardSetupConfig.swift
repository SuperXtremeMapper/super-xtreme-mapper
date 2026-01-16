//
//  WizardSetupConfig.swift
//  XtremeMapping
//

import Foundation

/// Configuration captured during wizard setup phase.
struct WizardSetupConfig {
    var controllerName: String = ""
    var numberOfChannels: Int = 2  // 2 or 4
    var deviceTarget: TargetAssignment = .deviceTarget
    var inputPort: String = ""
    var outputPort: String = ""

    var isValid: Bool {
        !controllerName.isEmpty && !inputPort.isEmpty
    }

    /// Returns deck assignments based on channel count
    var deckAssignments: [TargetAssignment] {
        if numberOfChannels == 2 {
            return [.deckA, .deckB]
        } else {
            return [.deckA, .deckB, .deckC, .deckD]
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
