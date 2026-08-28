//
//  TSICompatibilityWarning.swift
//  SuperXtremeMapping
//

import Foundation

/// A native Traktor MIDI detail that the editor preserves opaquely.
nonisolated enum TSICompatibilityWarning: Hashable, Sendable {
    case opaqueMIDIControl(name: String)
    case unresolvedMIDIBinding(id: UInt32)

    var message: String {
        switch self {
        case .opaqueMIDIControl(let name):
            return "The MIDI control \"\(name)\" is preserved exactly but cannot be edited directly. Assigning a new MIDI control will replace it."
        case .unresolvedMIDIBinding(let id):
            return "MIDI binding #\(id) is not listed in this TSI file. Its original reference is preserved until you assign a new MIDI control."
        }
    }
}
