//
//  MappingTransformService.swift
//  XtremeMapping
//

import Foundation

/// One supported destination for cloning Deck A mappings.
enum DeckCloneDestination: Int, CaseIterable, Hashable, Sendable {
    case deckB = 2
    case deckC = 3
    case deckD = 4

    fileprivate var assignment: TargetAssignment {
        switch self {
        case .deckB: .deckB
        case .deckC: .deckC
        case .deckD: .deckD
        }
    }

    fileprivate var conditionTarget: ModifierConditionTarget {
        switch self {
        case .deckB: .deckB
        case .deckC: .deckC
        case .deckD: .deckD
        }
    }

    fileprivate var commentLetter: Character {
        switch self {
        case .deckB: "B"
        case .deckC: "C"
        case .deckD: "D"
        }
    }
}

/// Pure input to a mapping transformation.
struct MappingTransformRequest: Equatable, Sendable {
    private struct Candidate: Hashable, Sendable {
        let sourceMappingID: MappingEntry.ID
        let destination: DeckCloneDestination
    }

    let selectedMappingIDs: Set<MappingEntry.ID>
    let destinations: Set<DeckCloneDestination>
    private let preferredMappingIDs: [Candidate: MappingEntry.ID]

    init(
        selectedMappingIDs: Set<MappingEntry.ID>,
        destinations: Set<DeckCloneDestination>,
        makeMappingID: () -> MappingEntry.ID = UUID.init
    ) {
        self.selectedMappingIDs = selectedMappingIDs
        self.destinations = destinations

        let candidates = destinations
            .sorted { $0.rawValue < $1.rawValue }
            .flatMap { destination in
                selectedMappingIDs
                    .sorted { $0.uuidString < $1.uuidString }
                    .map { Candidate(sourceMappingID: $0, destination: destination) }
            }
        preferredMappingIDs = Dictionary(
            uniqueKeysWithValues: candidates.map { ($0, makeMappingID()) }
        )
    }

    fileprivate func preferredMappingID(
        for sourceMappingID: MappingEntry.ID,
        destination: DeckCloneDestination
    ) -> MappingEntry.ID {
        preferredMappingIDs[
            Candidate(sourceMappingID: sourceMappingID, destination: destination)
        ]!
    }
}

/// One safe insertion proposed by the planner.
struct MappingTransformInsert: Equatable, Sendable {
    let sourceMappingID: MappingEntry.ID
    let sourceMapping: MappingEntry
    let deviceID: Device.ID
    let destination: DeckCloneDestination
    let mapping: MappingEntry
}

/// One clone omitted because an equivalent mapping already exists.
struct MappingTransformDuplicateSkip: Equatable, Sendable {
    let sourceMappingID: MappingEntry.ID
    let sourceMapping: MappingEntry
    let deviceID: Device.ID
    let destination: DeckCloneDestination
    let existingMappingID: MappingEntry.ID
    let existingMapping: MappingEntry
}

fileprivate struct MappingTransformIgnoredReference: Equatable, Sendable {
    let deviceID: Device.ID
    let mapping: MappingEntry
}

enum MappingTransformReviewChoice: Equatable, CaseIterable, Sendable {
    case keepExisting
    case createAnother
    case replaceExisting
}

enum MappingTransformReviewReason: Hashable, Sendable {
    case functionalConflict(existingMappingID: MappingEntry.ID)
    case unknownConditionTarget(rawValue: UInt32)
}

/// A planner result that requires an explicit decision or cannot be cloned safely.
struct MappingTransformReviewItem: Identifiable, Equatable, Sendable {
    struct ID: Hashable, Sendable {
        let sourceMappingID: MappingEntry.ID
        let deviceID: Device.ID
        let destination: DeckCloneDestination
        let reason: MappingTransformReviewReason
    }

    let id: ID
    let sourceMappingID: MappingEntry.ID
    let sourceMapping: MappingEntry
    let deviceID: Device.ID
    let destination: DeckCloneDestination
    let proposedMapping: MappingEntry?
    let reason: MappingTransformReviewReason
    let existingMapping: MappingEntry?

    var availableChoices: [MappingTransformReviewChoice] {
        switch reason {
        case .functionalConflict:
            MappingTransformReviewChoice.allCases
        case .unknownConditionTarget:
            []
        }
    }

    init(
        sourceMappingID: MappingEntry.ID,
        sourceMapping: MappingEntry,
        deviceID: Device.ID,
        destination: DeckCloneDestination,
        proposedMapping: MappingEntry?,
        reason: MappingTransformReviewReason,
        existingMapping: MappingEntry? = nil
    ) {
        id = ID(
            sourceMappingID: sourceMappingID,
            deviceID: deviceID,
            destination: destination,
            reason: reason
        )
        self.sourceMappingID = sourceMappingID
        self.sourceMapping = sourceMapping
        self.deviceID = deviceID
        self.destination = destination
        self.proposedMapping = proposedMapping
        self.reason = reason
        self.existingMapping = existingMapping
    }
}

/// Complete, value-only result of planning a clone request.
struct MappingTransformPlan: Equatable, Sendable {
    let inserts: [MappingTransformInsert]
    let duplicateSkips: [MappingTransformDuplicateSkip]
    let ignoredMappingIDs: Set<MappingEntry.ID>
    let reviewItems: [MappingTransformReviewItem]
    let newSelectionIDs: Set<MappingEntry.ID>
    let statusText: String?
    fileprivate let ignoredReferences: [MappingTransformIgnoredReference]

    fileprivate init(
        inserts: [MappingTransformInsert],
        duplicateSkips: [MappingTransformDuplicateSkip],
        ignoredMappingIDs: Set<MappingEntry.ID>,
        reviewItems: [MappingTransformReviewItem],
        ignoredReferences: [MappingTransformIgnoredReference]
    ) {
        self.inserts = inserts
        self.duplicateSkips = duplicateSkips
        self.ignoredMappingIDs = ignoredMappingIDs
        self.reviewItems = reviewItems
        self.ignoredReferences = ignoredReferences
        newSelectionIDs = Set(inserts.map(\.mapping.id))
        statusText = Self.makeStatusText(
            created: inserts.count,
            duplicates: duplicateSkips.count,
            ignored: ignoredMappingIDs.count,
            reviews: reviewItems.count
        )
    }

    private static func makeStatusText(
        created: Int,
        duplicates: Int,
        ignored: Int,
        reviews: Int
    ) -> String? {
        if reviews > 0 {
            return "\(reviews) \(reviews == 1 ? "mapping needs" : "mappings need") review."
        }

        guard created > 0 || duplicates > 0 || ignored > 0 else { return nil }

        var sentences = ["\(created) \(created == 1 ? "mapping" : "mappings") created."]
        if duplicates > 0 {
            sentences.append(
                "\(duplicates) \(duplicates == 1 ? "duplicate" : "duplicates") skipped."
            )
        }
        if ignored > 0 {
            sentences.append(
                "\(ignored) other \(ignored == 1 ? "mapping" : "mappings") ignored."
            )
        }
        return sentences.joined(separator: " ")
    }
}

/// Plans Deck A clones without mutating the supplied mapping file.
enum MappingTransformPlanner {
    static func plan(
        _ request: MappingTransformRequest,
        in mappingFile: MappingFile
    ) -> MappingTransformPlan {
        let destinations = request.destinations.sorted { $0.rawValue < $1.rawValue }
        guard !destinations.isEmpty, !request.selectedMappingIDs.isEmpty else {
            return MappingTransformPlan(
                inserts: [],
                duplicateSkips: [],
                ignoredMappingIDs: [],
                reviewItems: [],
                ignoredReferences: []
            )
        }

        let selectedRows = mappingFile.devices.flatMap { device in
            device.mappings.compactMap { mapping in
                request.selectedMappingIDs.contains(mapping.id)
                    ? OwnedMapping(deviceID: device.id, mapping: mapping)
                    : nil
            }
        }
        let ignoredRows = selectedRows.filter { !isEligible($0.mapping.assignment) }
        let ignoredIDs = Set(ignoredRows.map { $0.mapping.id })
        let eligibleRows = selectedRows.filter { isEligible($0.mapping.assignment) }

        var comparisonRows = Dictionary(
            uniqueKeysWithValues: mappingFile.devices.map { ($0.id, $0.mappings) }
        )
        var occupiedMappingIDs = Set(mappingFile.allMappings.map(\.id))
        var inserts: [MappingTransformInsert] = []
        var duplicateSkips: [MappingTransformDuplicateSkip] = []
        var reviewItems: [MappingTransformReviewItem] = []

        for destination in destinations {
            for owned in eligibleRows {
                if let rawTarget = unknownConditionTarget(in: owned.mapping) {
                    reviewItems.append(
                        MappingTransformReviewItem(
                            sourceMappingID: owned.mapping.id,
                            sourceMapping: owned.mapping,
                            deviceID: owned.deviceID,
                            destination: destination,
                            proposedMapping: nil,
                            reason: .unknownConditionTarget(rawValue: rawTarget)
                        )
                    )
                    continue
                }

                let clone = translatedCopy(
                    of: owned.mapping,
                    to: destination,
                    id: request.preferredMappingID(
                        for: owned.mapping.id,
                        destination: destination
                    )
                )
                let candidates = comparisonRows[owned.deviceID] ?? []
                if let duplicate = candidates.first(where: {
                    exactSemanticDataMatches($0, clone)
                }) {
                    duplicateSkips.append(
                        MappingTransformDuplicateSkip(
                            sourceMappingID: owned.mapping.id,
                            sourceMapping: owned.mapping,
                            deviceID: owned.deviceID,
                            destination: destination,
                            existingMappingID: duplicate.id,
                            existingMapping: duplicate
                        )
                    )
                    continue
                }

                let conflicts = candidates.filter {
                    functionalIdentityMatches($0, clone)
                }
                if !conflicts.isEmpty {
                    let proposedClone = clone.copy(
                        withID: availableMappingID(
                            preferred: clone.id,
                            excluding: occupiedMappingIDs
                        )
                    )
                    occupiedMappingIDs.insert(proposedClone.id)
                    reviewItems.append(contentsOf: conflicts.map { existing in
                        MappingTransformReviewItem(
                            sourceMappingID: owned.mapping.id,
                            sourceMapping: owned.mapping,
                            deviceID: owned.deviceID,
                            destination: destination,
                            proposedMapping: proposedClone,
                            reason: .functionalConflict(existingMappingID: existing.id),
                            existingMapping: existing
                        )
                    })
                    continue
                }

                let insertClone = clone.copy(
                    withID: availableMappingID(
                        preferred: clone.id,
                        excluding: occupiedMappingIDs
                    )
                )
                occupiedMappingIDs.insert(insertClone.id)
                inserts.append(
                    MappingTransformInsert(
                        sourceMappingID: owned.mapping.id,
                        sourceMapping: owned.mapping,
                        deviceID: owned.deviceID,
                        destination: destination,
                        mapping: insertClone
                    )
                )
                comparisonRows[owned.deviceID, default: []].append(insertClone)
            }
        }

        return MappingTransformPlan(
            inserts: inserts,
            duplicateSkips: duplicateSkips,
            ignoredMappingIDs: ignoredIDs,
            reviewItems: reviewItems,
            ignoredReferences: ignoredRows.map {
                MappingTransformIgnoredReference(deviceID: $0.deviceID, mapping: $0.mapping)
            }
        )
    }

    private struct OwnedMapping {
        let deviceID: Device.ID
        let mapping: MappingEntry
    }

    /// Finds a free UUID in at most N+1 probes for N occupied UUIDs. Successive
    /// 128-bit values are distinct across this finite range, so one must be free.
    private static func availableMappingID(
        preferred: MappingEntry.ID,
        excluding occupied: Set<MappingEntry.ID>
    ) -> MappingEntry.ID {
        guard occupied.contains(preferred) else { return preferred }

        for offset in 1...(occupied.count + 1) {
            let candidate = incrementedUUID(preferred, by: UInt64(offset))
            if !occupied.contains(candidate) {
                return candidate
            }
        }
        preconditionFailure("Finite UUID collision resolution exhausted unexpectedly")
    }

    private static func incrementedUUID(_ id: UUID, by amount: UInt64) -> UUID {
        let value = id.uuid
        var bytes = [
            value.0, value.1, value.2, value.3,
            value.4, value.5, value.6, value.7,
            value.8, value.9, value.10, value.11,
            value.12, value.13, value.14, value.15
        ]
        var carry = amount
        for index in stride(from: bytes.count - 1, through: 0, by: -1) {
            let sum = UInt16(bytes[index]) + UInt16(carry & 0xFF)
            bytes[index] = UInt8(sum & 0xFF)
            carry = (carry >> 8) + UInt64(sum >> 8)
        }
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func isEligible(_ assignment: TargetAssignment) -> Bool {
        switch assignment {
        case .deckA,
             .remixDeckASlot1, .remixDeckASlot2,
             .remixDeckASlot3, .remixDeckASlot4:
            true
        default:
            false
        }
    }

    private static func translatedCopy(
        of source: MappingEntry,
        to destination: DeckCloneDestination,
        id: MappingEntry.ID
    ) -> MappingEntry {
        var clone = source.copy(withID: id)
        clone.assignment = translatedAssignment(source.assignment, to: destination)
        clone.modifier1Condition = translatedCondition(
            source.modifier1Condition,
            to: destination
        )
        clone.modifier2Condition = translatedCondition(
            source.modifier2Condition,
            to: destination
        )
        clone.comment = translatedComment(source.comment, to: destination)
        return clone
    }

    private static func translatedAssignment(
        _ assignment: TargetAssignment,
        to destination: DeckCloneDestination
    ) -> TargetAssignment {
        switch assignment {
        case .deckA:
            destination.assignment
        case .remixDeckASlot1:
            TargetAssignment.remixSlotAssignment(forDeck: destination.assignment, slot: 1)!
        case .remixDeckASlot2:
            TargetAssignment.remixSlotAssignment(forDeck: destination.assignment, slot: 2)!
        case .remixDeckASlot3:
            TargetAssignment.remixSlotAssignment(forDeck: destination.assignment, slot: 3)!
        case .remixDeckASlot4:
            TargetAssignment.remixSlotAssignment(forDeck: destination.assignment, slot: 4)!
        default:
            assignment
        }
    }

    private static func translatedCondition(
        _ condition: ModifierCondition?,
        to destination: DeckCloneDestination
    ) -> ModifierCondition? {
        guard var condition else { return nil }
        if condition.target == .deckA {
            condition.target = destination.conditionTarget
        }
        return condition
    }

    private static func unknownConditionTarget(in mapping: MappingEntry) -> UInt32? {
        for condition in [mapping.modifier1Condition, mapping.modifier2Condition] {
            if case .unknown(let rawValue) = condition?.target {
                return rawValue
            }
        }
        return nil
    }

    private static func translatedComment(
        _ comment: String,
        to destination: DeckCloneDestination
    ) -> String {
        var result = comment
        for pattern in [#"(?i)\bdeck[ \t]+a\b"#, #"(?i)\[a\]"#, #"(?i)\ba:"#] {
            result = replacingSourceLetters(
                in: result,
                matching: pattern,
                with: destination.commentLetter
            )
        }
        return result
    }

    private static func replacingSourceLetters(
        in string: String,
        matching pattern: String,
        with destination: Character
    ) -> String {
        let expression = try! NSRegularExpression(pattern: pattern)
        let result = NSMutableString(string: string)
        let matches = expression.matches(
            in: string,
            range: NSRange(location: 0, length: (string as NSString).length)
        )

        for match in matches.reversed() {
            let matched = result.substring(with: match.range) as NSString
            for offset in stride(from: matched.length - 1, through: 0, by: -1) {
                let scalar = matched.character(at: offset)
                guard scalar == 65 || scalar == 97 else { continue }
                let replacement = scalar == 97
                    ? String(destination).lowercased()
                    : String(destination)
                result.replaceCharacters(
                    in: NSRange(location: match.range.location + offset, length: 1),
                    with: replacement
                )
                break
            }
        }
        return result as String
    }

    /// Exact duplicate identity is every modeled writable field except UUID.
    /// Imported CMAD is preservation provenance, not independently writable state.
    private static func exactSemanticDataMatches(
        _ lhs: MappingEntry,
        _ rhs: MappingEntry
    ) -> Bool {
        commonSemanticDataMatches(lhs, rhs)
            && lhs.midiAssignment == rhs.midiAssignment
            && lhs.rawMidiControlName == rhs.rawMidiControlName
            && lhs.rawMidiBindingID == rhs.rawMidiBindingID
            && lhs.comment == rhs.comment
    }

    /// Functional conflicts deliberately omit MIDI and comments. A shared MIDI
    /// control with a different command therefore remains a legitimate macro.
    private static func functionalIdentityMatches(
        _ lhs: MappingEntry,
        _ rhs: MappingEntry
    ) -> Bool {
        commonSemanticDataMatches(lhs, rhs)
    }

    private static func commonSemanticDataMatches(
        _ lhs: MappingEntry,
        _ rhs: MappingEntry
    ) -> Bool {
        lhs.commandID == rhs.commandID
            && lhs.ioType == rhs.ioType
            && lhs.assignment == rhs.assignment
            && lhs.interactionMode == rhs.interactionMode
            && lhs.modifier1Condition == rhs.modifier1Condition
            && lhs.modifier2Condition == rhs.modifier2Condition
            && lhs.controllerType == rhs.controllerType
            && lhs.invert == rhs.invert
            && lhs.softTakeover == rhs.softTakeover
            && lhs.setToValue.bitPattern == rhs.setToValue.bitPattern
            && lhs.rotarySensitivity.bitPattern == rhs.rotarySensitivity.bitPattern
            && lhs.rotaryAcceleration.bitPattern == rhs.rotaryAcceleration.bitPattern
            && lhs.encoderMode == rhs.encoderMode
            && lhs.rawDCDTEncoderMode == rhs.rawDCDTEncoderMode
            && lhs.rawDCDTControlType == rhs.rawDCDTControlType
            && lhs.rawDCDTMinValueBits == rhs.rawDCDTMinValueBits
            && lhs.rawDCDTMaxValueBits == rhs.rawDCDTMaxValueBits
            && lhs.rawDCDTControlID == rhs.rawDCDTControlID
            && lhs.autoRepeat == rhs.autoRepeat
            && lhs.ledMinRangeType == rhs.ledMinRangeType
            && lhs.ledMinRangeData == rhs.ledMinRangeData
            && lhs.ledMaxRangeType == rhs.ledMaxRangeType
            && lhs.ledMaxRangeData == rhs.ledMaxRangeData
            && lhs.ledMinMidi == rhs.ledMinMidi
            && lhs.ledMaxMidi == rhs.ledMaxMidi
            && lhs.ledInvert == rhs.ledInvert
            && lhs.ledBlend == rhs.ledBlend
            && lhs.resolution == rhs.resolution
    }
}

struct MappingTransformExecutionResult: Equatable, Sendable {
    let createdIDs: Set<MappingEntry.ID>
    let createdCount: Int
    let duplicateSkipCount: Int
    let ignoredCount: Int
    let statusText: String

    init(
        createdIDs: Set<MappingEntry.ID>,
        duplicateSkipCount: Int,
        ignoredCount: Int
    ) {
        self.createdIDs = createdIDs
        createdCount = createdIDs.count
        self.duplicateSkipCount = duplicateSkipCount
        self.ignoredCount = ignoredCount

        var sentences = [
            "\(createdCount) \(createdCount == 1 ? "mapping" : "mappings") created."
        ]
        if duplicateSkipCount > 0 {
            sentences.append(
                "\(duplicateSkipCount) "
                    + "\(duplicateSkipCount == 1 ? "duplicate" : "duplicates") skipped."
            )
        }
        if ignoredCount > 0 {
            sentences.append(
                "\(ignoredCount) other "
                    + "\(ignoredCount == 1 ? "mapping" : "mappings") ignored."
            )
        }
        statusText = sentences.joined(separator: " ")
    }
}

enum MappingTransformExecutionError: Error, Equatable, Sendable, LocalizedError {
    case stalePlan
    case incompleteReviewChoices
    case blockedReviewItem
    case invalidReviewChoice
    case preflightFailed(String)

    var errorDescription: String? {
        switch self {
        case .stalePlan:
            "The mappings changed after review. Try cloning them again."
        case .incompleteReviewChoices:
            "Choose what to do with every mapping that needs review."
        case .blockedReviewItem:
            "A mapping has an unsupported condition target and cannot be cloned safely."
        case .invalidReviewChoice:
            "A review choice is no longer available. Try cloning the mappings again."
        case .preflightFailed(let detail):
            "The cloned mappings cannot be written as a valid TSI: \(detail)"
        }
    }
}

/// Applies only the identities and mappings already resolved by a plan. It
/// validates every referenced snapshot and the complete candidate before one
/// undoable document replacement; it never replans or allocates new IDs.
enum MappingTransformExecutor {
    @MainActor
    static func execute(
        _ plan: MappingTransformPlan,
        choices: [MappingTransformReviewItem.ID: MappingTransformReviewChoice],
        in document: TraktorMappingDocument,
        undoManager: UndoManager?
    ) throws -> MappingTransformExecutionResult {
        try validateChoices(choices, for: plan)
        try validateReferences(in: plan, against: document.mappingFile)

        var candidate = document.mappingFile
        var createdIDs: Set<MappingEntry.ID> = []

        for insert in plan.inserts {
            try append(insert.mapping, to: insert.deviceID, in: &candidate)
            createdIDs.insert(insert.mapping.id)
        }

        for item in plan.reviewItems {
            guard let choice = choices[item.id] else { continue }
            switch choice {
            case .keepExisting:
                continue
            case .createAnother:
                try insertProposedMapping(from: item, into: &candidate, createdIDs: &createdIDs)
            case .replaceExisting:
                guard case .functionalConflict(let existingMappingID) = item.reason else {
                    throw MappingTransformExecutionError.invalidReviewChoice
                }
                try remove(
                    mappingID: existingMappingID,
                    from: item.deviceID,
                    in: &candidate
                )
                try insertProposedMapping(from: item, into: &candidate, createdIDs: &createdIDs)
            }
        }

        do {
            _ = try TSIWriter().writeConverted(candidate)
        } catch {
            let detail = (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
            throw MappingTransformExecutionError.preflightFailed(detail)
        }

        _ = document.performUndoableMutation(
            actionName: "Clone Deck A Mappings",
            undoManager: undoManager
        ) { mappingFile in
            mappingFile = candidate
        }

        return MappingTransformExecutionResult(
            createdIDs: createdIDs,
            duplicateSkipCount: plan.duplicateSkips.count,
            ignoredCount: plan.ignoredMappingIDs.count
        )
    }

    private static func validateChoices(
        _ choices: [MappingTransformReviewItem.ID: MappingTransformReviewChoice],
        for plan: MappingTransformPlan
    ) throws {
        let reviewIDs = Set(plan.reviewItems.map(\.id))
        guard Set(choices.keys).isSubset(of: reviewIDs) else {
            throw MappingTransformExecutionError.invalidReviewChoice
        }

        for item in plan.reviewItems {
            guard !item.availableChoices.isEmpty else {
                throw MappingTransformExecutionError.blockedReviewItem
            }
            guard let choice = choices[item.id] else {
                throw MappingTransformExecutionError.incompleteReviewChoices
            }
            guard item.availableChoices.contains(choice) else {
                throw MappingTransformExecutionError.invalidReviewChoice
            }
        }
    }

    private static func validateReferences(
        in plan: MappingTransformPlan,
        against mappingFile: MappingFile
    ) throws {
        var proposedByID: [MappingEntry.ID: MappingEntry] = [:]

        for ignored in plan.ignoredReferences {
            guard mapping(
                id: ignored.mapping.id,
                deviceID: ignored.deviceID,
                in: mappingFile
            ) == ignored.mapping else {
                throw MappingTransformExecutionError.stalePlan
            }
        }

        for insert in plan.inserts {
            try validateSource(
                insert.sourceMapping,
                id: insert.sourceMappingID,
                deviceID: insert.deviceID,
                in: mappingFile
            )
            try validateProposed(insert.mapping, in: mappingFile, proposedByID: &proposedByID)
        }

        for duplicate in plan.duplicateSkips {
            try validateSource(
                duplicate.sourceMapping,
                id: duplicate.sourceMappingID,
                deviceID: duplicate.deviceID,
                in: mappingFile
            )
            guard mapping(
                id: duplicate.existingMappingID,
                deviceID: duplicate.deviceID,
                in: mappingFile
            ) == duplicate.existingMapping else {
                throw MappingTransformExecutionError.stalePlan
            }
        }

        for item in plan.reviewItems {
            try validateSource(
                item.sourceMapping,
                id: item.sourceMappingID,
                deviceID: item.deviceID,
                in: mappingFile
            )
            if case .functionalConflict(let existingMappingID) = item.reason {
                guard let expected = item.existingMapping,
                      mapping(
                        id: existingMappingID,
                        deviceID: item.deviceID,
                        in: mappingFile
                      ) == expected else {
                    throw MappingTransformExecutionError.stalePlan
                }
            }
            if let proposed = item.proposedMapping {
                try validateProposed(proposed, in: mappingFile, proposedByID: &proposedByID)
            }
        }
    }

    private static func validateSource(
        _ expected: MappingEntry,
        id: MappingEntry.ID,
        deviceID: Device.ID,
        in mappingFile: MappingFile
    ) throws {
        guard expected.id == id,
              mapping(id: id, deviceID: deviceID, in: mappingFile) == expected else {
            throw MappingTransformExecutionError.stalePlan
        }
    }

    private static func validateProposed(
        _ proposed: MappingEntry,
        in mappingFile: MappingFile,
        proposedByID: inout [MappingEntry.ID: MappingEntry]
    ) throws {
        guard !mappingFile.allMappings.contains(where: { $0.id == proposed.id }) else {
            throw MappingTransformExecutionError.stalePlan
        }
        if let previous = proposedByID[proposed.id], previous != proposed {
            throw MappingTransformExecutionError.stalePlan
        }
        proposedByID[proposed.id] = proposed
    }

    private static func mapping(
        id: MappingEntry.ID,
        deviceID: Device.ID,
        in mappingFile: MappingFile
    ) -> MappingEntry? {
        guard let device = mappingFile.devices.first(where: { $0.id == deviceID }) else {
            return nil
        }
        let matches = device.mappings.filter { $0.id == id }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func append(
        _ mapping: MappingEntry,
        to deviceID: Device.ID,
        in mappingFile: inout MappingFile
    ) throws {
        guard let deviceIndex = mappingFile.devices.firstIndex(where: { $0.id == deviceID }) else {
            throw MappingTransformExecutionError.stalePlan
        }
        mappingFile.devices[deviceIndex].mappings.append(mapping)
    }

    private static func remove(
        mappingID: MappingEntry.ID,
        from deviceID: Device.ID,
        in mappingFile: inout MappingFile
    ) throws {
        guard let deviceIndex = mappingFile.devices.firstIndex(where: { $0.id == deviceID }),
              let mappingIndex = mappingFile.devices[deviceIndex].mappings.firstIndex(where: {
                $0.id == mappingID
              }) else {
            throw MappingTransformExecutionError.stalePlan
        }
        mappingFile.devices[deviceIndex].mappings.remove(at: mappingIndex)
    }

    private static func insertProposedMapping(
        from item: MappingTransformReviewItem,
        into mappingFile: inout MappingFile,
        createdIDs: inout Set<MappingEntry.ID>
    ) throws {
        guard let proposed = item.proposedMapping else {
            throw MappingTransformExecutionError.blockedReviewItem
        }
        guard createdIDs.insert(proposed.id).inserted else { return }
        try append(proposed, to: item.deviceID, in: &mappingFile)
    }
}
