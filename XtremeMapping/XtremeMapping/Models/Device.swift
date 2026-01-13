//
//  Device.swift
//  XXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a MIDI device configuration in a TSI file.
///
/// A device groups related mappings together and specifies the MIDI ports
/// used for communication with the physical controller.
struct Device: Identifiable, Codable, Sendable {
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
        mappings: [MappingEntry] = []
    ) {
        self.id = id
        self.name = name
        self.comment = comment
        self.inPort = inPort
        self.outPort = outPort
        self.mappings = mappings
    }
}
