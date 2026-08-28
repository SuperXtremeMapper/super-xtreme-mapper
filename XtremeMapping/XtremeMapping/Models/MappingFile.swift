//
//  MappingFile.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a complete TSI mapping file.
///
/// A mapping file contains one or more devices, each with their own
/// collection of MIDI mappings. The version number indicates the
/// TSI format version.
struct MappingFile: Codable, Sendable, Equatable {
    /// The devices defined in this mapping file
    var devices: [Device]

    /// The TSI format version number
    var version: Int

    /// Exact import-only source state. It is intentionally excluded from
    /// clipboard Codable payloads and semantic model equality.
    var sourceEnvelope: TSIRawEnvelope?

    /// All mappings from all devices, flattened into a single array.
    ///
    /// Useful for displaying a combined view of all mappings or
    /// performing searches across the entire file.
    var allMappings: [MappingEntry] {
        devices.flatMap { $0.mappings }
    }

    /// Native MIDI details currently preserved opaquely by the editor.
    var tsiCompatibilityWarnings: [TSICompatibilityWarning] {
        allMappings.compactMap(\.tsiCompatibilityWarning)
    }

    /// Creates a new mapping file with the specified properties.
    ///
    /// Defaults to an empty file with version 0.
    init(
        devices: [Device] = [],
        version: Int = 0,
        sourceEnvelope: TSIRawEnvelope? = nil
    ) {
        self.devices = devices
        self.version = version
        self.sourceEnvelope = sourceEnvelope
    }

    private enum CodingKeys: String, CodingKey {
        case devices
        case version
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        devices = try container.decode([Device].self, forKey: .devices)
        version = try container.decode(Int.self, forKey: .version)
        sourceEnvelope = nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(devices, forKey: .devices)
        try container.encode(version, forKey: .version)
    }

    static func == (lhs: MappingFile, rhs: MappingFile) -> Bool {
        lhs.devices == rhs.devices && lhs.version == rhs.version
    }
}
