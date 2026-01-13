//
//  ControllerType.swift
//  XtremeMapping
//
//  Created by Noah Raford on 13/01/2026.
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
}
