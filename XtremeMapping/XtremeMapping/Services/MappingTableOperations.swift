import Foundation

/// Table relationships and ordering operate on document IDs, never visible row indexes.
enum MappingTableOperations {
    private struct MIDIKey: Hashable {
        let direction: IODirection
        let assignment: MIDIAssignment
    }

    static func sharedMIDIIDs(in file: MappingFile, selectedIDs: Set<UUID>) -> Set<UUID> {
        guard !selectedIDs.isEmpty else { return [] }
        var result = Set<UUID>()
        for device in file.devices {
            let assigned = device.mappings.filter {
                $0.midiAssignment.kind != .unassigned && $0.rawMidiControlName == nil && $0.rawMidiBindingID == nil
            }
            let groups = Dictionary(grouping: assigned) {
                MIDIKey(direction: $0.ioType, assignment: $0.midiAssignment)
            }
            for rows in groups.values where rows.count > 1 && rows.contains(where: { selectedIDs.contains($0.id) }) {
                result.formUnion(rows.map(\.id))
            }
        }
        return result
    }

    /// nil destination means the end of the selection's device, not the file.
    @discardableResult
    static func move(_ ids: Set<UUID>, before target: UUID?, in file: inout MappingFile) -> Bool {
        guard !ids.isEmpty, target.map({ !ids.contains($0) }) ?? true,
              let deviceIndex = file.devices.firstIndex(where: { device in
                  ids.isSubset(of: Set(device.mappings.map(\.id)))
              }) else { return false }
        let original = file.devices[deviceIndex].mappings
        if let target, !original.contains(where: { $0.id == target }) { return false }
        let moving = original.filter { ids.contains($0.id) }
        var remaining = original.filter { !ids.contains($0.id) }
        let index = target.flatMap { destination in remaining.firstIndex(where: { $0.id == destination }) } ?? remaining.count
        remaining.insert(contentsOf: moving, at: index)
        guard remaining != original else { return false }
        file.devices[deviceIndex].mappings = remaining
        return true
    }

    /// A drop immediately before the next device is the trailing edge of this device.
    @discardableResult
    static func moveAtBoundary(_ ids: Set<UUID>, before target: UUID?, in file: inout MappingFile) -> Bool {
        guard !ids.isEmpty, let sourceIndex = file.devices.firstIndex(where: {
            ids.isSubset(of: Set($0.mappings.map(\.id)))
        }) else { return false }
        if let target,
           let next = file.devices.indices.dropFirst(sourceIndex + 1).first(where: { !file.devices[$0].mappings.isEmpty }),
           file.devices[next].mappings.first?.id == target {
            return move(ids, before: nil, in: &file)
        }
        return move(ids, before: target, in: &file)
    }

    /// A discontiguous selection moves as one stable block past its nearest neighbor.
    @discardableResult
    static func step(_ ids: Set<UUID>, down: Bool, in file: inout MappingFile) -> Bool {
        guard !ids.isEmpty, let device = file.devices.first(where: {
            ids.isSubset(of: Set($0.mappings.map(\.id)))
        }) else { return false }
        let rows = device.mappings
        let indexes = rows.indices.filter { ids.contains(rows[$0].id) }
        guard let first = indexes.first, let last = indexes.last else { return false }
        if down {
            guard last + 1 < rows.count else { return false }
            let target = last + 2 < rows.count ? rows[last + 2].id : nil
            return move(ids, before: target, in: &file)
        }
        guard first > 0 else { return false }
        return move(ids, before: rows[first - 1].id, in: &file)
    }
}
