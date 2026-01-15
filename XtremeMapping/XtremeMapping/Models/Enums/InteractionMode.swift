//
//  InteractionMode.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Defines how a MIDI control interacts with Traktor commands.
///
/// The interaction mode determines the behavior when a control is activated:
/// - For buttons: toggle, hold, or trigger behaviors
/// - For faders/knobs: direct mapping or relative adjustment
/// - For outputs: how values are sent to controller LEDs
enum InteractionMode: Int, Codable, CaseIterable, Sendable {
    /// Not yet assigned
    case none = -1

    /// Button toggles between on/off states with each press
    case toggle = 0

    /// Button activates while held, deactivates on release
    case hold = 1

    /// Fader/knob value maps directly to parameter (absolute)
    case direct = 2

    /// Encoder sends relative +/- values
    case relative = 3

    /// Button increments the parameter value
    case increment = 4

    /// Button decrements the parameter value
    case decrement = 5

    /// Button resets parameter to default value
    case reset = 6

    /// Output mode for sending values to controller LEDs
    case output = 7

    /// Button triggers a one-shot action
    case trigger = 8

    /// Short display name for the UI
    var displayName: String {
        switch self {
        case .none:
            return "-"
        case .toggle:
            return "Toggle"
        case .hold:
            return "Hold"
        case .direct:
            return "Direct"
        case .relative:
            return "Relative"
        case .increment:
            return "Inc"
        case .decrement:
            return "Dec"
        case .reset:
            return "Reset"
        case .output:
            return "Output"
        case .trigger:
            return "Trigger"
        }
    }
}
