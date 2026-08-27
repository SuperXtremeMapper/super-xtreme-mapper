//
//  MappingTransferService.swift
//  SuperXtremeMapping
//

import Foundation

/// Inserts fresh mapping copies while preserving their source order and fields.
enum MappingTransferService {
    @discardableResult
    static func insertCopies(
        _ source: [MappingEntry],
        into mappingFile: inout MappingFile,
        targetDeviceID: Device.ID? = nil
    ) -> Set<MappingEntry.ID> {
        guard !source.isEmpty else { return [] }

        let destinationIndex: Int
        if let targetDeviceID,
           let requestedIndex = mappingFile.devices.firstIndex(where: { $0.id == targetDeviceID }) {
            destinationIndex = requestedIndex
        } else if !mappingFile.devices.isEmpty {
            destinationIndex = mappingFile.devices.startIndex
        } else {
            mappingFile.devices.append(Device(name: "Generic MIDI"))
            destinationIndex = mappingFile.devices.startIndex
        }

        let copies = source.map { $0.copyWithNewID() }
        mappingFile.devices[destinationIndex].mappings.append(contentsOf: copies)
        return Set(copies.map(\.id))
    }
}
