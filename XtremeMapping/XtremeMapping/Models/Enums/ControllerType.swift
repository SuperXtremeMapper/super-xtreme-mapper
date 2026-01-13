//
//  ControllerType.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents the type of MIDI controller hardware.
///
/// TSI files categorize controller inputs by their physical type,
/// which affects how interaction modes and values are interpreted.
enum ControllerType: Int, Codable, CaseIterable, Sendable {
    /// A momentary or latching button
    case button = 0

    /// A linear fader or rotary potentiometer (absolute position)
    case faderOrKnob = 1

    /// A rotary encoder (relative movement, no end stops)
    case encoder = 2

    /// An LED output indicator
    case led = 65535

    /// Human-readable name for display in the UI
    var displayName: String {
        switch self {
        case .button:
            return "Button"
        case .faderOrKnob:
            return "Fader/Knob"
        case .encoder:
            return "Encoder"
        case .led:
            return "LED"
        }
    }

    /// Returns the valid interaction modes for this controller type
    var validInteractionModes: [InteractionMode] {
        switch self {
        case .button:
            // Button modes: Direct, Inc, Dec, Reset (plus Hold, Toggle, Trigger for non-direct)
            return [.hold, .toggle, .trigger, .direct, .increment, .decrement, .reset]
        case .faderOrKnob:
            // Fader/Knob modes: Direct, Relative
            return [.direct, .relative]
        case .encoder:
            // Encoder modes: Direct, Relative
            return [.direct, .relative]
        case .led:
            // LED is output only
            return [.output]
        }
    }

    /// Returns the default interaction mode for this controller type
    var defaultInteractionMode: InteractionMode {
        switch self {
        case .button:
            return .hold
        case .faderOrKnob:
            return .direct
        case .encoder:
            return .relative
        case .led:
            return .output
        }
    }
}
