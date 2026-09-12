import Foundation

/// User-declared hardware settings, pinned to immutable manufacturer evidence.
/// Changing these settings annotates the document; it does not configure hardware.
nonisolated struct ControllerConfiguration: Codable, Equatable, Sendable {
    var profileID: String
    var version: String
    var globalChannel: Int
    var layerMode: String
    var unitMap: String
    var feedbackMode: String = "unknown"
    var overrides: [ControllerControlOverride] = []
}

/// An observed or explicitly supplied address applies only to this control/context.
/// Its channel is explicit: custom maps may use channels other than the global channel.
nonisolated struct ControllerControlOverride: Codable, Equatable, Sendable {
    var controlID: String
    var layerMode: String
    var unitMap: String
    var layer: ControllerProfile.Layer
    var direction: ControllerProfile.Direction
    var midi: SXMJSONMIDI
    var provenance: Provenance

    enum Provenance: String, Codable, Sendable {
        case userSupplied = "user-supplied"
        case midiLearn = "midi-learn"
    }
}
