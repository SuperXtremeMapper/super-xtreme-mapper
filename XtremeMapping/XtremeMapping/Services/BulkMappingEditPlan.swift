import Foundation

/// A preview and its exact selection snapshot. Applying never silently refreshes
/// the preview or overwrites edits made after it was prepared.
struct BulkMappingEditPlan {
    struct Change: Identifiable {
        var id: UUID { before.id }
        let before: MappingEntry
        let after: MappingEntry
    }

    enum EditError: LocalizedError {
        case staleSelection, incompatibleCommand
        var errorDescription: String? {
            switch self {
            case .staleSelection: "The selected mappings changed. Close this sheet and reopen it to review a fresh preview."
            case .incompatibleCommand: "Select only Hotcue 1–8 Type output mappings to change their command together."
            }
        }
    }

    let changes: [Change]
    let actionName: String
    private let selectedEntries: [UUID: MappingEntry]
    private let deviceIDs: [UUID: UUID]

    static let compatibleCommandIDs = Array(2333...2340)

    static func supportsCommandEdit(_ entries: [MappingEntry]) -> Bool {
        !entries.isEmpty && entries.allSatisfy {
            $0.ioType == .output && compatibleCommandIDs.contains($0.commandID)
        }
    }

    static func comments(in file: MappingFile, selectedIDs: Set<UUID>, find: String,
                         replacement: String, matchCase: Bool) throws -> Self {
        try make(in: file, selectedIDs: selectedIDs, actionName: "Replace Comments") { entry in
            var result = entry
            if !find.isEmpty {
                result.comment = entry.comment.replacingOccurrences(of: find, with: replacement,
                    options: matchCase ? [.literal] : [.literal, .caseInsensitive])
            }
            return result
        }
    }

    static func command(in file: MappingFile, selectedIDs: Set<UUID>, commandID: Int) throws -> Self {
        let entries = file.allMappings.filter { selectedIDs.contains($0.id) }
        guard compatibleCommandIDs.contains(commandID), supportsCommandEdit(entries) else {
            throw EditError.incompatibleCommand
        }
        return try make(in: file, selectedIDs: selectedIDs, actionName: "Change Hotcue Commands") { entry in
            var result = entry
            result.commandID = commandID
            return result
        }
    }

    private static func make(in file: MappingFile, selectedIDs: Set<UUID>, actionName: String,
                             transform: (MappingEntry) -> MappingEntry) throws -> Self {
        var entries: [UUID: MappingEntry] = [:]
        var devices: [UUID: UUID] = [:]
        var changes: [Change] = []
        for device in file.devices {
            for entry in device.mappings where selectedIDs.contains(entry.id) {
                guard entries[entry.id] == nil else { throw EditError.staleSelection }
                entries[entry.id] = entry
                devices[entry.id] = device.id
                let after = transform(entry)
                if after != entry { changes.append(Change(before: entry, after: after)) }
            }
        }
        guard Set(entries.keys) == selectedIDs else { throw EditError.staleSelection }
        return Self(changes: changes, actionName: actionName, selectedEntries: entries, deviceIDs: devices)
    }

    func validate(in file: MappingFile) throws {
        var seen = Set<UUID>()
        for device in file.devices {
            for entry in device.mappings where selectedEntries[entry.id] != nil {
                guard seen.insert(entry.id).inserted,
                      selectedEntries[entry.id] == entry, deviceIDs[entry.id] == device.id else {
                    throw EditError.staleSelection
                }
            }
        }
        guard seen == Set(selectedEntries.keys) else { throw EditError.staleSelection }
    }

    func apply(to file: inout MappingFile) throws {
        try validate(in: file)
        let replacements = Dictionary(uniqueKeysWithValues: changes.map { ($0.id, $0.after) })
        for deviceIndex in file.devices.indices {
            for index in file.devices[deviceIndex].mappings.indices {
                if let after = replacements[file.devices[deviceIndex].mappings[index].id] {
                    file.devices[deviceIndex].mappings[index] = after
                }
            }
        }
    }

    @MainActor
    @discardableResult
    func apply(document: TraktorMappingDocument, isLocked: Bool, undoManager: UndoManager?) throws -> Bool {
        guard !isLocked else { return false }
        try validate(in: document.mappingFile)
        guard !changes.isEmpty else { return false }
        try document.performUndoableMutation(actionName: actionName, undoManager: undoManager) {
            try apply(to: &$0)
        }
        return true
    }
}
