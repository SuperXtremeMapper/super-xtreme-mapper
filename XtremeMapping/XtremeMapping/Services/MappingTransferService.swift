//
//  MappingTransferService.swift
//  SuperXtremeMapping
//

import Foundation

struct MappingTransferResult: Equatable, Sendable {
    let insertedIDs: Set<MappingEntry.ID>
    let destinationDeviceID: Device.ID?
}

enum MappingTransferError: Error, Equatable, Sendable, LocalizedError {
    case destinationRequired
    case destinationUnavailable
    case preflightFailed(String)

    var errorDescription: String? {
        switch self {
        case .destinationRequired:
            String(
                localized: "mapping-transfer.destination-required",
                defaultValue: "Select a mapping in the destination device before pasting."
            )
        case .destinationUnavailable:
            String(
                localized: "mapping-transfer.destination-unavailable",
                defaultValue: "The selected destination device is no longer available. Select it again and retry."
            )
        case .preflightFailed(let detail):
            String(
                format: String(
                    localized: "mapping-transfer.preflight-failed",
                    defaultValue: "The mappings cannot be written as a valid TSI: %@"
                ),
                detail
            )
        }
    }
}

/// Inserts fresh mapping copies only after destination and TSI validation.
enum MappingTransferService {
    @discardableResult
    static func insertCopies(
        _ source: [MappingEntry],
        into mappingFile: inout MappingFile,
        targetDeviceID: Device.ID? = nil
    ) throws -> MappingTransferResult {
        guard !source.isEmpty else {
            return MappingTransferResult(insertedIDs: [], destinationDeviceID: nil)
        }

        var candidate = mappingFile

        let destinationIndex: Int
        if let targetDeviceID {
            guard let requestedIndex = candidate.devices.firstIndex(where: {
                $0.id == targetDeviceID
            }) else {
                throw MappingTransferError.destinationUnavailable
            }
            destinationIndex = requestedIndex
        } else if isTrulyEmpty(candidate) {
            candidate.devices.append(Device(name: "Generic MIDI"))
            destinationIndex = candidate.devices.startIndex
        } else {
            throw MappingTransferError.destinationRequired
        }

        let copies = source.map { $0.copyWithNewID() }
        candidate.devices[destinationIndex].mappings.append(contentsOf: copies)

        do {
            _ = try TSIWriter().writeConverted(candidate)
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            throw MappingTransferError.preflightFailed(detail)
        }

        mappingFile = candidate
        return MappingTransferResult(
            insertedIDs: Set(copies.map(\.id)),
            destinationDeviceID: candidate.devices[destinationIndex].id
        )
    }

    /// Preflights a complete candidate before committing one document/Undo
    /// transaction. A thrown error occurs before `performUndoableMutation`, so
    /// failure cannot dirty the document or register an Undo action.
    @MainActor
    @discardableResult
    static func insertCopies(
        _ source: [MappingEntry],
        into document: TraktorMappingDocument,
        targetDeviceID: Device.ID?,
        actionName: String,
        undoManager: UndoManager?
    ) throws -> MappingTransferResult? {
        var candidate = document.mappingFile
        let result = try insertCopies(
            source,
            into: &candidate,
            targetDeviceID: targetDeviceID
        )

        return document.performUndoableMutation(
            actionName: actionName,
            undoManager: undoManager
        ) { mappingFile in
            mappingFile = candidate
            return result
        }
    }

    /// A new untouched document is the only destination where creating the
    /// default Generic MIDI device is implicit. Imported/device-less files are
    /// existing documents and must not be silently reinterpreted.
    static func isTrulyEmpty(_ mappingFile: MappingFile) -> Bool {
        mappingFile.devices.isEmpty
            && mappingFile.version == 0
            && mappingFile.sourceEnvelope == nil
    }

    /// Returns a destination only when the current selection belongs to one
    /// live device. A nil result is never interpreted as a first-device guess.
    static func destinationDeviceID(
        for selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: MappingFile
    ) -> Device.ID? {
        let owners = mappingFile.devices.filter { device in
            device.mappings.contains { selectedIDs.contains($0.id) }
        }
        return owners.count == 1 ? owners[0].id : nil
    }

    /// Resolves a workflow destination without ever guessing in an existing
    /// multi-device document. A sole device is inherently unambiguous; a
    /// truly empty file may create its destination when the workflow commits.
    static func workflowDestinationDeviceID(
        for selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: MappingFile
    ) throws -> Device.ID? {
        if isTrulyEmpty(mappingFile) { return nil }
        if mappingFile.devices.count == 1 { return mappingFile.devices[0].id }

        let liveIDs = Set(mappingFile.allMappings.map(\.id))
        guard selectedIDs.isSubset(of: liveIDs) else {
            throw MappingTransferError.destinationUnavailable
        }
        guard let destination = destinationDeviceID(
            for: selectedIDs,
            in: mappingFile
        ) else {
            throw MappingTransferError.destinationRequired
        }
        return destination
    }

    /// Duplicates each selected source row at the end of its owning device.
    /// Duplication never needs destination guessing because every source row
    /// already has a live owning device.
    @discardableResult
    static func duplicateSelection(
        _ selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    ) -> Set<MappingEntry.ID> {
        let batches = mappingFile.devices.map { device in
            device.mappings.filter { selectedIDs.contains($0.id) }
        }

        var insertedIDs: Set<MappingEntry.ID> = []
        for deviceIndex in mappingFile.devices.indices {
            let copies = batches[deviceIndex].map { $0.copyWithNewID() }
            mappingFile.devices[deviceIndex].mappings.append(contentsOf: copies)
            insertedIDs.formUnion(copies.map(\.id))
        }
        return insertedIDs
    }
}
