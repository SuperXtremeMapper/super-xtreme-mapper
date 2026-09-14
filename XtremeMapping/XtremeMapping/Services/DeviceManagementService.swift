import Foundation

enum DeviceMappingTransferMode: Equatable, Sendable {
    case copy
    case move
}

struct DeviceManagementResult: Equatable, Sendable {
    let deviceID: Device.ID
    let mappingIDs: Set<MappingEntry.ID>
}

enum DeviceManagementError: Error, Equatable, Sendable, LocalizedError {
    case deviceUnavailable(Device.ID)
    case mappingUnavailable(Set<MappingEntry.ID>)
    case sameDevice
    case preflightFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceUnavailable:
            "The selected device is no longer available. Select it again and retry."
        case .mappingUnavailable:
            "One or more selected mappings are no longer available in the source device. Select them again and retry."
        case .sameDevice:
            "Choose a different destination device."
        case .preflightFailed(let detail):
            "The change cannot be saved safely: \(detail)"
        }
    }
}

/// Pure, atomic mutations for device ownership and cross-device mapping work.
/// Callers wrap one successful mutation in their document Undo transaction.
enum DeviceManagementService {
    @discardableResult
    static func addDevice(
        name: String,
        comment: String = "",
        inPort: String = "",
        outPort: String = "",
        to file: inout MappingFile
    ) throws -> Device.ID {
        try commit(to: &file) { candidate in
            let device = Device(
                name: name,
                comment: comment,
                inPort: inPort,
                outPort: outPort
            )
            candidate.devices.append(device)
            return device.id
        }
    }

    static func updateDevice(
        _ deviceID: Device.ID,
        name: String,
        comment: String,
        inPort: String,
        outPort: String,
        in file: inout MappingFile
    ) throws {
        try commit(to: &file) { candidate in
            guard let index = candidate.devices.firstIndex(where: { $0.id == deviceID }) else {
                throw DeviceManagementError.deviceUnavailable(deviceID)
            }
            candidate.devices[index].name = name
            candidate.devices[index].comment = comment
            candidate.devices[index].inPort = inPort
            candidate.devices[index].outPort = outPort
        }
    }

    @discardableResult
    static func duplicateDevice(
        _ deviceID: Device.ID,
        in file: inout MappingFile
    ) throws -> DeviceManagementResult {
        try commit(to: &file) { candidate in
            guard let source = candidate.devices.first(where: { $0.id == deviceID }) else {
                throw DeviceManagementError.deviceUnavailable(deviceID)
            }

            let newDeviceID = UUID()
            let rowIDMap = Dictionary(uniqueKeysWithValues: source.mappings.map {
                ($0.id, UUID())
            })
            let duplicate = Device(
                id: newDeviceID,
                name: source.name,
                comment: duplicateComment(for: source),
                inPort: source.inPort,
                outPort: source.outPort,
                importedIdentity: source.importedIdentity,
                tsiVersion: source.tsiVersion,
                mappingFileRevision: source.mappingFileRevision,
                mappings: source.mappings.map { row in
                    row.copy(withID: rowIDMap[row.id]!)
                }
            )
            candidate.devices.append(duplicate)
            remapMetadataForDuplicate(
                sourceDeviceID: deviceID,
                destinationDeviceID: newDeviceID,
                rowIDMap: rowIDMap,
                in: &candidate
            )
            return DeviceManagementResult(
                deviceID: newDeviceID,
                mappingIDs: Set(rowIDMap.values)
            )
        }
    }

    static func deleteDevice(
        _ deviceID: Device.ID,
        in file: inout MappingFile
    ) throws {
        try commit(to: &file) { candidate in
            guard let index = candidate.devices.firstIndex(where: { $0.id == deviceID }) else {
                throw DeviceManagementError.deviceUnavailable(deviceID)
            }
            let removedRowIDs = Set(candidate.devices[index].mappings.map(\.id))
            candidate.devices.remove(at: index)
            candidate.interchangeMetadata?.deviceProfiles?.removeAll {
                $0.deviceID == deviceID
            }
            candidate.interchangeMetadata?.physicalControls.removeAll {
                removedRowIDs.contains($0.mappingID)
            }
            candidate.interchangeMetadata?.localOverrides.removeAll {
                removedRowIDs.contains($0.mappingID)
            }
        }
    }

    @discardableResult
    static func transferMappings(
        _ mappingIDs: Set<MappingEntry.ID>,
        from sourceDeviceID: Device.ID,
        to destinationDeviceID: Device.ID,
        mode: DeviceMappingTransferMode,
        in file: inout MappingFile
    ) throws -> DeviceManagementResult {
        try commit(to: &file) { candidate in
            guard let sourceIndex = candidate.devices.firstIndex(where: {
                $0.id == sourceDeviceID
            }) else {
                throw DeviceManagementError.deviceUnavailable(sourceDeviceID)
            }
            guard let destinationIndex = candidate.devices.firstIndex(where: {
                $0.id == destinationDeviceID
            }) else {
                throw DeviceManagementError.deviceUnavailable(destinationDeviceID)
            }
            guard sourceIndex != destinationIndex else {
                throw DeviceManagementError.sameDevice
            }

            let selectedRows = candidate.devices[sourceIndex].mappings.filter {
                mappingIDs.contains($0.id)
            }
            let foundIDs = Set(selectedRows.map(\.id))
            guard foundIDs == mappingIDs else {
                throw DeviceManagementError.mappingUnavailable(mappingIDs.subtracting(foundIDs))
            }

            let rowIDMap: [MappingEntry.ID: MappingEntry.ID]
            switch mode {
            case .copy:
                rowIDMap = Dictionary(uniqueKeysWithValues: selectedRows.map {
                    ($0.id, UUID())
                })
                candidate.devices[destinationIndex].mappings.append(contentsOf:
                    selectedRows.map { $0.copy(withID: rowIDMap[$0.id]!) }
                )
            case .move:
                rowIDMap = Dictionary(uniqueKeysWithValues: selectedRows.map {
                    ($0.id, $0.id)
                })
                candidate.devices[sourceIndex].mappings.removeAll {
                    mappingIDs.contains($0.id)
                }
                candidate.devices[destinationIndex].mappings.append(contentsOf: selectedRows)
            }

            remapMetadataForTransfer(
                rowIDMap: rowIDMap,
                sourceDeviceID: sourceDeviceID,
                destinationDeviceID: destinationDeviceID,
                mode: mode,
                in: &candidate
            )
            return DeviceManagementResult(
                deviceID: destinationDeviceID,
                mappingIDs: Set(rowIDMap.values)
            )
        }
    }

    /// Builds a deliberate one-device conversion. The detached model retains
    /// modeled fields and relevant annotations, while omitting the full
    /// document's raw source envelope. Converted writing may normalize opaque
    /// imported details under the existing explicit-export policy.
    static func selectedDeviceExport(
        _ deviceID: Device.ID,
        from file: MappingFile
    ) throws -> MappingFile {
        guard let device = file.devices.first(where: { $0.id == deviceID }) else {
            throw DeviceManagementError.deviceUnavailable(deviceID)
        }

        var export = MappingFile(
            devices: [device],
            version: file.version,
            sourceEnvelope: nil
        )
        export.interchangeMetadata = metadataForExport(
            device: device,
            metadata: file.interchangeMetadata
        )
        try preflightConvertedExport(export)
        return export
    }

    private static func commit<Result>(
        to file: inout MappingFile,
        mutation: (inout MappingFile) throws -> Result
    ) throws -> Result {
        var candidate = file
        let result = try mutation(&candidate)
        try preflightOrdinarySave(candidate)
        file = candidate
        return result
    }

    private static func preflightOrdinarySave(_ file: MappingFile) throws {
        do {
            _ = try TSIWriter().makeWritePlan(for: file)
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            throw DeviceManagementError.preflightFailed(detail)
        }
    }

    private static func preflightConvertedExport(_ file: MappingFile) throws {
        do {
            _ = try TSIWriter().makeConvertedWritePlan(for: file)
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            throw DeviceManagementError.preflightFailed(detail)
        }
    }

    private static func remapMetadataForDuplicate(
        sourceDeviceID: Device.ID,
        destinationDeviceID: Device.ID,
        rowIDMap: [MappingEntry.ID: MappingEntry.ID],
        in file: inout MappingFile
    ) {
        guard var metadata = file.interchangeMetadata else { return }

        let deviceProfiles = (metadata.deviceProfiles ?? []).filter {
            $0.deviceID == sourceDeviceID
        }.map {
            SXMJSONMetadata.DeviceProfile(
                deviceID: destinationDeviceID,
                configuration: $0.configuration
            )
        }
        if metadata.deviceProfiles != nil {
            metadata.deviceProfiles?.append(contentsOf: deviceProfiles)
        }

        let duplicatedControls = metadata.physicalControls.compactMap { annotation in
                rowIDMap[annotation.mappingID].map {
                    SXMJSONMetadata.Control(
                        mappingID: $0,
                        profileID: annotation.profileID,
                        controlID: annotation.controlID
                    )
                }
            }
        let duplicatedOverrides = metadata.localOverrides.compactMap { annotation in
                rowIDMap[annotation.mappingID].map {
                    SXMJSONMetadata.Override(mappingID: $0, midi: annotation.midi)
                }
            }
        metadata.physicalControls.append(contentsOf: duplicatedControls)
        metadata.localOverrides.append(contentsOf: duplicatedOverrides)
        file.interchangeMetadata = metadata
    }

    private static func duplicateComment(for device: Device) -> String {
        if device.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(device.name) copy"
        }
        return "\(device.comment) copy"
    }

    private static func remapMetadataForTransfer(
        rowIDMap: [MappingEntry.ID: MappingEntry.ID],
        sourceDeviceID: Device.ID,
        destinationDeviceID: Device.ID,
        mode: DeviceMappingTransferMode,
        in file: inout MappingFile
    ) {
        guard var metadata = file.interchangeMetadata else { return }
        struct ProfilePin: Hashable {
            let id: String
            let version: String
        }
        func pins(for deviceID: Device.ID) -> Set<ProfilePin> {
            Set((metadata.deviceProfiles ?? []).filter {
                $0.deviceID == deviceID
            }.map {
                ProfilePin(
                    id: $0.configuration.profileID,
                    version: $0.configuration.version
                )
            })
        }
        let compatibleProfileIDs = Set(
            pins(for: sourceDeviceID).intersection(pins(for: destinationDeviceID)).map(\.id)
        )

        let selectedControls = metadata.physicalControls.filter {
            rowIDMap[$0.mappingID] != nil
        }
        let selectedOverrides = metadata.localOverrides.filter {
            rowIDMap[$0.mappingID] != nil
        }

        switch mode {
        case .copy:
            metadata.physicalControls.append(contentsOf:
                selectedControls.compactMap { annotation in
                    guard compatibleProfileIDs.contains(annotation.profileID),
                          let newID = rowIDMap[annotation.mappingID] else {
                        return nil
                    }
                    return SXMJSONMetadata.Control(
                        mappingID: newID,
                        profileID: annotation.profileID,
                        controlID: annotation.controlID
                    )
                }
            )
            metadata.localOverrides.append(contentsOf:
                selectedOverrides.compactMap { annotation in
                    rowIDMap[annotation.mappingID].map {
                        SXMJSONMetadata.Override(mappingID: $0, midi: annotation.midi)
                    }
                }
            )
        case .move:
            metadata.physicalControls.removeAll { annotation in
                rowIDMap[annotation.mappingID] != nil
                    && !compatibleProfileIDs.contains(annotation.profileID)
            }
        }
        file.interchangeMetadata = metadata
    }

    private static func metadataForExport(
        device: Device,
        metadata: SXMJSONMetadata?
    ) -> SXMJSONMetadata? {
        guard let metadata else { return nil }
        let rowIDs = Set(device.mappings.map(\.id))
        let controls = metadata.physicalControls.filter {
            rowIDs.contains($0.mappingID)
        }
        let overrides = metadata.localOverrides.filter {
            rowIDs.contains($0.mappingID)
        }
        let deviceProfiles = metadata.deviceProfiles?.filter {
            $0.deviceID == device.id
        }
        let relevantProfileIDs = Set(controls.map(\.profileID)).union(
            (deviceProfiles ?? []).map { $0.configuration.profileID }
        )
        return SXMJSONMetadata(
            profileReferences: metadata.profileReferences.filter {
                relevantProfileIDs.contains($0.profileID)
            },
            physicalControls: controls,
            localOverrides: overrides,
            deviceProfiles: deviceProfiles
        )
    }
}
