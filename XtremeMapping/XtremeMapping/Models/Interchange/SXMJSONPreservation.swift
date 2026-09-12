import Foundation

/// Ordered original positions map to stable public identities; current arrays may reorder/remove.
nonisolated struct SXMJSONPreservation: Codable, Sendable {
    struct SourceDevice: Codable, Sendable {
        var id: UUID
        var mappingIDs: [UUID]
    }
    var originalXML: String
    var devices: [SourceDevice]

    init(_ source: TSIRawEnvelope) {
        originalXML = source.originalXML.base64EncodedString()
        devices = source.baseline.devices.map { SourceDevice(id: $0.id, mappingIDs: $0.mappings.map(\.id)) }
    }

    func reconstruct() throws -> MappingFile {
        func invalid(_ message: String) -> SXMJSONIssue {
            SXMJSONIssue(code: "preservation.invalid", path: "$.preservation", message: message)
        }
        guard let bytes = Data(base64Encoded: originalXML), bytes.base64EncodedString() == originalXML else {
            throw invalid("Original XML is not canonical base64. Export again from the original TSI.")
        }
        let parsed: MappingFile
        do { parsed = try TSIParser().parseDocument(bytes) }
        catch { throw invalid("Embedded TSI cannot be parsed: \(error.localizedDescription)") }
        guard let envelope = parsed.sourceEnvelope, devices.count == parsed.devices.count else {
            throw invalid("Source device correspondence does not match the embedded TSI.")
        }
        var ids = Set<UUID>()
        var restored: [Device] = []
        for (index, source) in devices.enumerated() {
            let device = parsed.devices[index]
            guard ids.insert(source.id).inserted,
                  source.mappingIDs.count == device.mappings.count else {
                throw invalid("Source identities must be unique and cover every original record.")
            }
            var rows: [MappingEntry] = []
            for (rowIndex, id) in source.mappingIDs.enumerated() {
                guard ids.insert(id).inserted else { throw invalid("Duplicate source identity: \(id).") }
                rows.append(device.mappings[rowIndex].copy(withID: id))
            }
            restored.append(Device(id: source.id, name: device.name, comment: device.comment,
                inPort: device.inPort, outPort: device.outPort, importedIdentity: device.importedIdentity,
                tsiVersion: device.tsiVersion, mappingFileRevision: device.mappingFileRevision, mappings: rows))
        }
        return MappingFile(devices: restored, version: parsed.version, sourceEnvelope: TSIRawEnvelope(
            originalXML: bytes, controllerValues: envelope.controllerValues, primaryFrames: envelope.primaryFrames,
            baseline: TSISemanticBaseline(devices: restored, version: parsed.version), risks: envelope.risks))
    }
}
