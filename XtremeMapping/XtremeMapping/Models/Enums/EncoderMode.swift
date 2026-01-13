//
//  EncoderMode.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents the encoder communication mode for relative encoders.
///
/// Different encoder hardware uses different protocols to communicate
/// relative movement. This setting must match the physical encoder's output.
enum EncoderMode: Int, Codable, CaseIterable, Sendable {
    /// 7Fh/01h mode: 127 for decrement, 1 for increment
    /// Most common mode for DJ controllers
    case mode7Fh01h = 0

    /// 3Fh/41h mode: 63 for decrement, 65 for increment
    /// Used by some Native Instruments controllers
    case mode3Fh41h = 1

    /// Human-readable name for display in the UI
    var displayName: String {
        switch self {
        case .mode7Fh01h:
            return "7Fh/01h"
        case .mode3Fh41h:
            return "3Fh/41h"
        }
    }
}
