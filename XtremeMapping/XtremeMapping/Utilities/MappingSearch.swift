//
//  MappingSearch.swift
//  XtremeMapping
//

import Foundation

enum MappingSearch {
    static func matches(
        _ mapping: MappingEntry,
        in device: Device,
        query: String
    ) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        return [
            mapping.commandName,
            mapping.comment,
            device.name,
            device.comment,
        ].contains { value in
            value.range(
                of: trimmedQuery,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }
}

extension MappingBatchEditor {
    static func applyDeviceComment(
        _ comment: String,
        to deviceID: Device.ID,
        in mappingFile: inout MappingFile
    ) {
        guard let deviceIndex = mappingFile.devices.firstIndex(where: {
            $0.id == deviceID
        }) else { return }

        mappingFile.devices[deviceIndex].comment = comment
    }
}
