import Foundation

/// An immutable local review and complete document snapshot. Applying never recomputes a proposal.
nonisolated struct AssistantEditPlan: Sendable {
    struct Change: Identifiable, Sendable {
        var id: UUID { rowID }
        let deviceID: UUID
        let rowID: UUID
        let before: MappingEntry?
        let after: MappingEntry?
        let summaries: [String]
    }
    let operations: [AssistantEditOperation]
    let changes: [Change]
    let warnings: [String]
    var isEmpty: Bool { changes.isEmpty }
    private let original: MappingFile
    private let candidate: MappingFile
    private let revision: String

    static func prepare(operations: [AssistantEditOperation], file: MappingFile, revision: String) throws -> Self {
        guard operations.count <= 100 else { throw AssistantEditError.invalid("Review is limited to 100 operations. Split this request into smaller edits.") }
        var allIDs = Set<UUID>()
        for device in file.devices {
            guard allIDs.insert(device.id).inserted else { throw AssistantEditError.invalid("The document contains duplicate device identities. Reopen a valid document.") }
            for row in device.mappings {
                guard allIDs.insert(row.id).inserted else { throw AssistantEditError.invalid("The document contains duplicate row identities. Reopen a valid document.") }
            }
        }
        var result = file
        var targets = Set<UUID>()
        var reordered = Set<UUID>()
        var editedDevices = Set<UUID>()
        var warnings: [String] = []
        for op in operations {
            try op.validateShape()
            guard let di = result.devices.firstIndex(where: { $0.id == op.deviceID }) else { throw AssistantEditError.invalid("The destination device no longer exists. Request a fresh proposal.") }
            if op.kind == .reorder {
                guard !editedDevices.contains(op.deviceID), reordered.insert(op.deviceID).inserted else { throw AssistantEditError.invalid("Reorder must be reviewed separately from other edits to the same device.") }
                let order = op.rowOrder!
                let rows = result.devices[di].mappings
                guard order.count == rows.count, Set(order).count == order.count, Set(order) == Set(rows.map(\.id)) else { throw AssistantEditError.invalid("Reorder must list every row in the device exactly once.") }
                let lookup = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
                result.devices[di].mappings = order.map { lookup[$0]! }
                continue
            }
            guard !reordered.contains(op.deviceID) else { throw AssistantEditError.invalid("Reorder must be reviewed separately from other edits to the same device.") }
            editedDevices.insert(op.deviceID)
            var index: Int?
            if let id = op.rowID {
                guard targets.insert(id).inserted,
                      let found = file.devices[di].mappings.firstIndex(where: { $0.id == id }),
                      file.devices[di].mappings[found].id == id,
                      let current = result.devices[di].mappings.firstIndex(where: { $0.id == id }) else {
                    throw AssistantEditError.invalid("A row is missing or targeted more than once. Request a proposal with distinct row targets.")
                }
                index = current
            }
            if let id = op.newRowID {
                guard allIDs.insert(id).inserted, targets.insert(id).inserted else { throw AssistantEditError.invalid("New rows need unique identities that are not already in use.") }
            }
            switch op.kind {
            case .add:
                let row = try op.patch!.applying(to: MappingEntry(id: op.newRowID!, rotarySensitivity: 1))
                result.devices[di].mappings.append(row)
            case .update:
                let before = result.devices[di].mappings[index!]
                let after = try op.patch!.applying(to: before)
                warnings += opaqueWarnings(before: before, after: after)
                result.devices[di].mappings[index!] = after
            case .delete:
                result.devices[di].mappings.remove(at: index!)
                result.interchangeMetadata?.physicalControls.removeAll { $0.mappingID == op.rowID }
                result.interchangeMetadata?.localOverrides.removeAll { $0.mappingID == op.rowID }
            case .duplicate:
                let before = result.devices[di].mappings[index!]
                var copy = before.copy(withID: op.newRowID!)
                if let patch = op.patch { copy = try patch.applying(to: copy) }
                warnings += opaqueWarnings(before: before, after: copy)
                result.devices[di].mappings.insert(copy, at: index! + 1)
                // Native wire evidence is copied; profile annotations are deliberately not invented.
            case .reorder: break
            }
        }
        var changes: [Change] = []
        for (di, device) in file.devices.enumerated() {
            let afterRows = result.devices[di].mappings
            let beforeMap = Dictionary(uniqueKeysWithValues: device.mappings.map { ($0.id, $0) })
            let afterMap = Dictionary(uniqueKeysWithValues: afterRows.map { ($0.id, $0) })
            let oldPositions = Dictionary(uniqueKeysWithValues: device.mappings.enumerated().map { ($0.element.id, $0.offset) })
            let newPositions = Dictionary(uniqueKeysWithValues: afterRows.enumerated().map { ($0.element.id, $0.offset) })
            let orderedIDs = device.mappings.map(\.id) + afterRows.filter { beforeMap[$0.id] == nil }.map(\.id)
            for id in orderedIDs {
                let before = beforeMap[id], after = afterMap[id]
                let moved = reordered.contains(device.id) && oldPositions[id] != newPositions[id]
                guard before != after || moved else { continue }
                var summaries = try fieldSummaries(before: before, after: after)
                if moved { summaries.append("Position: \(oldPositions[id]! + 1) → \(newPositions[id]! + 1)") }
                changes.append(Change(deviceID: device.id, rowID: id, before: before, after: after, summaries: summaries))
            }
        }
        guard changes.count <= 100 else { throw AssistantEditError.invalid("Review is limited to 100 affected rows. Split this request into smaller edits.") }
        if !changes.isEmpty {
            let diagnostics = MappingValidationService.validate(projection(result), source: file)
            let errors = diagnostics.filter { $0.severity == .error }
            guard errors.isEmpty else { throw AssistantEditError.invalid(errors.map { "\($0.path): \($0.message)" }.joined(separator: "\n")) }
            warnings += diagnostics.filter { $0.severity == .warning }.map { diagnostic in
                let row = diagnostic.mappingID.map { " [Row \($0.uuidString)]" } ?? ""
                let device = diagnostic.deviceID.map { " [Device \($0.uuidString)]" } ?? ""
                return "\(diagnostic.path)\(device)\(row): \(diagnostic.message)"
            }
            let writePlan = try TSIWriter().makeWritePlan(for: result)
            if writePlan.disposition == .regenerated {
                let parsed = try TSIParser().parseDocument(writePlan.output)
                guard parsed.devices.count == result.devices.count,
                      zip(parsed.devices, result.devices).allSatisfy({ $0.mappings.count == $1.mappings.count }) else {
                    throw AssistantEditError.invalid("TSI serialization changed row counts. This proposal cannot be applied safely.")
                }
                for (device, saved) in zip(result.devices, parsed.devices) {
                    for (row, savedRow) in zip(device.mappings, saved.mappings) {
                        let normalized = try fieldSummaries(before: row, after: savedRow.copy(withID: row.id))
                        if !normalized.isEmpty {
                            warnings.append("TSI writing normalizes row \(row.id): \(normalized.joined(separator: "; "))")
                        }
                    }
                }
            }
        }
        return Self(operations: operations, changes: changes, warnings: Array(Set(warnings)).sorted(), original: file, candidate: result, revision: revision)
    }

    @MainActor
    @discardableResult
    func apply(document: TraktorMappingDocument, isLocked: Bool, undoManager: UndoManager?) throws -> Bool {
        guard !isLocked else { throw AssistantEditError.invalid("Unlock the document before applying this review.") }
        guard document.explanationRevision == revision, document.mappingFile == original,
              document.mappingFile.sourceEnvelope == original.sourceEnvelope,
              document.mappingFile.interchangeMetadata == original.interchangeMetadata else {
            throw AssistantEditError.invalid("The document changed after this review. Request a fresh proposal before applying.")
        }
        guard !isEmpty else { return false }
        // Prepared and validated together; the synchronous MainActor mutation publishes exactly once.
        document.performUndoableMutation(actionName: "Apply Assistant Changes", undoManager: undoManager) { $0 = candidate }
        return true
    }

    private static func projection(_ file: MappingFile) -> SXMJSONDocument {
        SXMJSONDocument(format: "sxm-mapping", schemaVersion: file.interchangeMetadata?.deviceProfiles == nil ? 1 : 2,
            tsiVersion: file.version, devices: file.devices.map {
                SXMJSONDevice(id: $0.id, name: $0.name, comment: $0.comment, inPort: $0.inPort, outPort: $0.outPort,
                    tsiVersion: $0.tsiVersion, mappingFileRevision: $0.mappingFileRevision, mappings: $0.mappings.map(SXMJSONMapping.init))
            }, preservation: nil, metadata: file.interchangeMetadata)
    }

    private static func opaqueWarnings(before: MappingEntry, after: MappingEntry) -> [String] {
        let changes = [("native MIDI name", before.rawMidiControlName != after.rawMidiControlName),
            ("native MIDI binding", before.rawMidiBindingID != after.rawMidiBindingID),
            ("native control type", before.rawDCDTControlType != after.rawDCDTControlType),
            ("native minimum", before.rawDCDTMinValueBits != after.rawDCDTMinValueBits),
            ("native maximum", before.rawDCDTMaxValueBits != after.rawDCDTMaxValueBits),
            ("native encoder mode", before.rawDCDTEncoderMode != after.rawDCDTEncoderMode),
            ("native control identity", before.rawDCDTControlID != after.rawDCDTControlID)]
        return changes.filter(\.1).map { "Row \(after.id): explicit MIDI/encoder editing replaces preserved \($0.0) details." }
    }

    private static func fieldSummaries(before: MappingEntry?, after: MappingEntry?) throws -> [String] {
        func fields(_ row: MappingEntry?) throws -> [String: Any] {
            guard let row else { return [:] }
            var result = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SXMJSONMapping(row))) as! [String: Any]
            result.removeValue(forKey: "id")
            result["rawMidiControlName"] = row.rawMidiControlName
            result["rawMidiBindingID"] = row.rawMidiBindingID
            result["rawDCDTControlType"] = row.rawDCDTControlType
            result["rawDCDTMinValueBits"] = row.rawDCDTMinValueBits
            result["rawDCDTMaxValueBits"] = row.rawDCDTMaxValueBits
            result["rawDCDTEncoderMode"] = row.rawDCDTEncoderMode
            result["rawDCDTControlID"] = row.rawDCDTControlID
            return result
        }
        func display(_ value: Any?) -> String {
            guard let value else { return "—" }
            if let text = value as? String { return text }
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys]) else { return String(describing: value) }
            return String(decoding: data, as: UTF8.self)
        }
        let a = try fields(before), b = try fields(after)
        var summaries: [String] = before == nil ? ["Add row"] : after == nil ? ["Delete row"] : []
        for key in Set(a.keys).union(b.keys).sorted() {
            if !NSDictionary(dictionary: ["value": a[key] ?? NSNull()]).isEqual(to: ["value": b[key] ?? NSNull()]) {
                summaries.append("\(key): \(display(a[key])) → \(display(b[key]))")
            }
        }
        return summaries
    }
}
