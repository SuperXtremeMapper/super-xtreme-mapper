//
//  MappingFile.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a complete TSI mapping file.
///
/// A mapping file contains one or more devices, each with their own
/// collection of MIDI mappings. The version number indicates the
/// TSI format version.
struct MappingFile: Codable, Sendable {
    /// The devices defined in this mapping file
    var devices: [Device]

    /// The TSI format version number
    var version: Int

    /// All mappings from all devices, flattened into a single array.
    ///
    /// Useful for displaying a combined view of all mappings or
    /// performing searches across the entire file.
    var allMappings: [MappingEntry] {
        devices.flatMap { $0.mappings }
    }

    /// Creates a new mapping file with the specified properties.
    ///
    /// Defaults to an empty file with version 0.
    init(devices: [Device] = [], version: Int = 0) {
        self.devices = devices
        self.version = version
    }
}
