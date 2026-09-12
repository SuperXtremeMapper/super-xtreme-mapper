import Foundation

/// Immutable manufacturer facts. The library validates all resources before exposing them.
/// MIDI channel is human-facing (1...16); MIDI numbers and values are zero-based.
nonisolated struct ControllerProfile: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let version: String
    let manufacturer: String
    let model: String
    let defaultChannel: Int
    let sources: [Source]
    let evidence: [Evidence]
    let modes: [Mode]
    let unitMaps: [UnitMap]
    let controls: [Control]
    let limitations: [Limitation]
    let configurationEvidence: [String]

    struct Source: Codable, Equatable, Sendable {
        let id: String
        let url: String
        let revision: String
        let sha256: String
    }

    struct Evidence: Codable, Equatable, Sendable {
        let id: String
        let sourceID: String
        let locator: String
        let verification: Verification
    }

    enum Verification: String, Codable, Sendable {
        case manufacturerDocumented = "manufacturer-documented"
        case hardwareTested = "hardware-tested"
    }

    struct Mode: Codable, Equatable, Sendable {
        let id: String
        let name: String
        let layeredGroups: [String]
        let softPickup: Bool
        let evidence: [String]
    }

    struct UnitMap: Codable, Equatable, Sendable {
        let id: String
        let usesFactoryBindings: Bool
        let evidence: [String]
    }

    struct Control: Codable, Equatable, Sendable {
        let id: String
        let physicalID: String
        let name: String
        let aliases: [String]
        let group: String
        let reservedInModes: [String]
        let bindings: [Binding]
        let evidence: [String]
    }

    struct Binding: Codable, Equatable, Sendable {
        let direction: Direction
        let layer: Layer
        let kind: Kind
        let number: Int
        let encoding: Encoding
        /// Both bounds are absent when the source does not document values.
        let valueMin: Int?
        let valueMax: Int?
        let color: Color?
        let evidence: [String]
        let notes: [String]
    }

    enum Direction: String, Codable, Sendable { case send, receive }
    enum Layer: String, Codable, Sendable { case base, amber, green }
    enum Kind: String, Codable, Sendable { case note, controlChange }
    enum Encoding: String, Codable, Sendable { case absolute7Bit, relativeTwosComplement, noteGate }
    enum Color: String, Codable, Sendable { case red, amber, green }

    struct Limitation: Codable, Equatable, Sendable {
        let message: String
        let evidence: [String]
    }
}
