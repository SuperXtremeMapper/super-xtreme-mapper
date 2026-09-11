import Foundation

enum FXCloneUnit: Int, CaseIterable, Identifiable, Sendable {
    case unit1 = 1, unit2, unit3, unit4
    var id: Int { rawValue }
    var title: String { "FX Unit \(rawValue)" }
    var assignment: TargetAssignment {
        switch self {
        case .unit1: .fxUnit1
        case .unit2: .fxUnit2
        case .unit3: .fxUnit3
        case .unit4: .fxUnit4
        }
    }
}

struct FXClonePlan {
    struct Insert {
        let deviceID: Device.ID
        let mapping: MappingEntry
    }
    let source: FXCloneUnit
    let destination: FXCloneUnit
    let inserts: [Insert]
    let duplicateSkipCount: Int
    let ignoredCount: Int
    fileprivate let snapshot: MappingFile
}

enum FXCloneError: LocalizedError {
    case locked, stalePlan, sameUnit
    var errorDescription: String? {
        switch self {
        case .locked: "Unlock editing before cloning mappings."
        case .stalePlan: "The mappings changed after preview. Close this sheet and try again."
        case .sameUnit: "Choose a different destination FX unit."
        }
    }
}

/// FX units are independent of deck assignment. Only the explicit target changes;
/// conditions, MIDI, comments, settings and native preservation data remain intact.
enum FXCloneService {
    static func plan(
        selectedMappingIDs: Set<MappingEntry.ID>,
        source: FXCloneUnit,
        destination: FXCloneUnit,
        in file: MappingFile
    ) -> FXClonePlan {
        var inserts: [FXClonePlan.Insert] = []
        var duplicates = 0
        var ignored = 0
        if source != destination {
            for device in file.devices {
                var comparison = device.mappings
                for mapping in device.mappings where selectedMappingIDs.contains(mapping.id) {
                    guard mapping.assignment == source.assignment else {
                        ignored += 1
                        continue
                    }
                    var clone = mapping.copyWithNewID()
                    clone.assignment = destination.assignment
                    if comparison.contains(where: { equivalent($0, clone) }) {
                        duplicates += 1
                        continue
                    }
                    inserts.append(.init(deviceID: device.id, mapping: clone))
                    comparison.append(clone)
                }
            }
        }
        return FXClonePlan(source: source, destination: destination, inserts: inserts,
                           duplicateSkipCount: duplicates, ignoredCount: ignored, snapshot: file)
    }

    private static func equivalent(_ lhs: MappingEntry, _ rhs: MappingEntry) -> Bool {
        var left = lhs.copy(withID: rhs.id)
        var right = rhs
        // Imported bytes describe origin; all modeled writable fields determine duplication.
        left.importedCMAD = nil
        right.importedCMAD = nil
        return left == right
    }

    @MainActor
    static func execute(
        _ plan: FXClonePlan,
        in document: TraktorMappingDocument,
        isLocked: Bool,
        undoManager: UndoManager?
    ) throws -> MappingTransformExecutionResult {
        guard !isLocked else { throw FXCloneError.locked }
        guard plan.source != plan.destination else { throw FXCloneError.sameUnit }
        guard document.mappingFile == plan.snapshot else { throw FXCloneError.stalePlan }
        var candidate = document.mappingFile
        for insert in plan.inserts {
            guard let index = candidate.devices.firstIndex(where: { $0.id == insert.deviceID }),
                  !candidate.allMappings.contains(where: { $0.id == insert.mapping.id }) else {
                throw FXCloneError.stalePlan
            }
            candidate.devices[index].mappings.append(insert.mapping)
        }
        if !plan.inserts.isEmpty {
            _ = try TSIWriter().writeConverted(candidate)
            document.performUndoableMutation(actionName: "Clone FX Unit Mappings", undoManager: undoManager) {
                $0 = candidate
            }
        }
        return MappingTransformExecutionResult(createdIDs: Set(plan.inserts.map(\.mapping.id)),
                                               duplicateSkipCount: plan.duplicateSkipCount,
                                               ignoredCount: plan.ignoredCount)
    }
}
