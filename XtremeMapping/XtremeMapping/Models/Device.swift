//
//  Device.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a MIDI device configuration in a TSI file.
///
/// A device groups related mappings together and specifies the MIDI ports
/// used for communication with the physical controller.
struct Device: Identifiable, Codable, Sendable, Equatable {
    /// Unique identifier for this device
    let id: UUID

    /// The display name of the device (e.g., "Kontrol S4 MK3")
    var name: String

    /// User comment describing the device or its purpose
    var comment: String

    /// The MIDI input port name for receiving from the controller
    var inPort: String

    /// The MIDI output port name for sending to the controller (LEDs, displays)
    var outPort: String

    /// Traktor version string stored in the device's DDIV frame (e.g. "3.11.0")
    var tsiVersion: String

    /// Mapping file revision stored in the device's DDIV frame (typically 2)
    var mappingFileRevision: Int

    /// The collection of mappings associated with this device
    var mappings: [MappingEntry]

    /// Creates a new device with the specified properties.
    ///
    /// All parameters have sensible defaults for creating empty devices.
    init(
        id: UUID = UUID(),
        name: String = "",
        comment: String = "",
        inPort: String = "",
        outPort: String = "",
        tsiVersion: String = "3.11.0",
        mappingFileRevision: Int = 2,
        mappings: [MappingEntry] = []
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.inPort = inPort
        self.outPort = outPort
        self.tsiVersion = tsiVersion
        self.mappingFileRevision = mappingFileRevision
        self.mappings = mappings
    }

    /// Explicit decode so previously-encoded Device data (drag/drop transferables,
    /// persisted state) lacking the new DDIV keys still loads. Encoding stays synthesized.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        comment = try container.decode(String.self, forKey: .comment)
        inPort = try container.decode(String.self, forKey: .inPort)
        outPort = try container.decode(String.self, forKey: .outPort)
        tsiVersion = try container.decodeIfPresent(String.self, forKey: .tsiVersion) ?? "3.11.0"
        mappingFileRevision = try container.decodeIfPresent(Int.self, forKey: .mappingFileRevision) ?? 2
        mappings = try container.decode([MappingEntry].self, forKey: .mappings)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, comment, inPort, outPort, tsiVersion, mappingFileRevision, mappings
    }
}
