//
//  MappingBatchEditor.swift
//  XtremeMapping
//

import Foundation

/// Pure, selection-scoped mutations for mapping groups.
enum MappingBatchEditor {
    static func apply(
        _ assignment: MIDIAssignment,
        to selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    ) {
        guard !selectedIDs.isEmpty else { return }

        for deviceIndex in mappingFile.devices.indices {
            for mappingIndex in mappingFile.devices[deviceIndex].mappings.indices {
                guard selectedIDs.contains(
                    mappingFile.devices[deviceIndex].mappings[mappingIndex].id
                ) else { continue }

                mappingFile.devices[deviceIndex].mappings[mappingIndex].midiAssignment = assignment
            }
        }
    }

    static func applyComment(
        _ comment: String,
        to selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    ) {
        guard !selectedIDs.isEmpty else { return }

        for deviceIndex in mappingFile.devices.indices {
            for mappingIndex in mappingFile.devices[deviceIndex].mappings.indices {
                guard selectedIDs.contains(
                    mappingFile.devices[deviceIndex].mappings[mappingIndex].id
                ) else { continue }

                mappingFile.devices[deviceIndex].mappings[mappingIndex].comment = comment
            }
        }
    }

    static func applyChannel(
        _ channel: Int,
        to selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    ) throws {
        guard !selectedIDs.isEmpty else { return }

        _ = try MIDIAssignment.unassigned(channel: channel)

        var replacements: [MappingEntry.ID: MIDIAssignment] = [:]
        for device in mappingFile.devices {
            for mapping in device.mappings where selectedIDs.contains(mapping.id) {
                replacements[mapping.id] = try mapping.midiAssignment.replacingChannel(
                    with: channel
                )
            }
        }

        for deviceIndex in mappingFile.devices.indices {
            for mappingIndex in mappingFile.devices[deviceIndex].mappings.indices {
                let mappingID = mappingFile.devices[deviceIndex].mappings[mappingIndex].id
                guard let replacement = replacements[mappingID] else { continue }
                mappingFile.devices[deviceIndex].mappings[mappingIndex].midiAssignment = replacement
            }
        }
    }
}
