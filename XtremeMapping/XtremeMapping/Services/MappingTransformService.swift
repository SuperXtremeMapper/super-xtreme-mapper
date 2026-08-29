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
    let selectedMappingIDs: Set<MappingEntry.ID>
    let destinations: Set<DeckCloneDestination>

    init(
        selectedMappingIDs: Set<MappingEntry.ID>,
        destinations: Set<DeckCloneDestination>
    ) {
        self.selectedMappingIDs = selectedMappingIDs
        self.destinations = destinations
    }
}

/// One safe insertion proposed by the planner.
struct MappingTransformInsert: Equatable, Sendable {
    let sourceMappingID: MappingEntry.ID
    let deviceID: Device.ID
    let destination: DeckCloneDestination
    let mapping: MappingEntry
}

/// One clone omitted because an equivalent mapping already exists.
struct MappingTransformDuplicateSkip: Equatable, Sendable {
    let sourceMappingID: MappingEntry.ID
    let deviceID: Device.ID
    let destination: DeckCloneDestination
    let existingMappingID: MappingEntry.ID
}

enum MappingTransformReviewChoice: Equatable, CaseIterable, Sendable {
    case keepExisting
    case createAnother
    case replaceExisting
}

enum MappingTransformReviewReason: Equatable, Sendable {
    case functionalConflict(existingMappingID: MappingEntry.ID)
    case unknownConditionTarget(rawValue: UInt32)
}

/// A planner result that requires an explicit decision or cannot be cloned safely.
struct MappingTransformReviewItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceMappingID: MappingEntry.ID
    let deviceID: Device.ID
    let destination: DeckCloneDestination
    let proposedMapping: MappingEntry?
    let reason: MappingTransformReviewReason

    var availableChoices: [MappingTransformReviewChoice] {
        switch reason {
        case .functionalConflict:
            MappingTransformReviewChoice.allCases
        case .unknownConditionTarget:
            []
        }
    }

    init(
        id: UUID = UUID(),
        sourceMappingID: MappingEntry.ID,
        deviceID: Device.ID,
        destination: DeckCloneDestination,
        proposedMapping: MappingEntry?,
        reason: MappingTransformReviewReason
    ) {
        self.id = id
        self.sourceMappingID = sourceMappingID
        self.deviceID = deviceID
        self.destination = destination
        self.proposedMapping = proposedMapping
        self.reason = reason
    }
}

/// Complete, value-only result of planning a clone request.
struct MappingTransformPlan: Equatable, Sendable {
    let inserts: [MappingTransformInsert]
    let duplicateSkips: [MappingTransformDuplicateSkip]
    let ignoredMappingIDs: Set<MappingEntry.ID>
    let reviewItems: [MappingTransformReviewItem]
    let newSelectionIDs: Set<MappingEntry.ID>
    let statusText: String

    init(
        inserts: [MappingTransformInsert],
        duplicateSkips: [MappingTransformDuplicateSkip],
        ignoredMappingIDs: Set<MappingEntry.ID>,
        reviewItems: [MappingTransformReviewItem]
    ) {
        self.inserts = inserts
        self.duplicateSkips = duplicateSkips
        self.ignoredMappingIDs = ignoredMappingIDs
        self.reviewItems = reviewItems
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
    ) -> String {
        if reviews > 0 {
            return "\(reviews) \(reviews == 1 ? "mapping needs" : "mappings need") review."
        }

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
                reviewItems: []
            )
        }

        let selectedRows = mappingFile.devices.flatMap { device in
            device.mappings.compactMap { mapping in
                request.selectedMappingIDs.contains(mapping.id)
                    ? OwnedMapping(deviceID: device.id, mapping: mapping)
                    : nil
            }
        }
        let ignoredIDs = Set(
            selectedRows.lazy
                .filter { !isEligible($0.mapping.assignment) }
                .map { $0.mapping.id }
        )
        let eligibleRows = selectedRows.filter { isEligible($0.mapping.assignment) }

        var comparisonRows = Dictionary(
            uniqueKeysWithValues: mappingFile.devices.map { ($0.id, $0.mappings) }
        )
        var inserts: [MappingTransformInsert] = []
        var duplicateSkips: [MappingTransformDuplicateSkip] = []
        var reviewItems: [MappingTransformReviewItem] = []

        for destination in destinations {
            for owned in eligibleRows {
                if let rawTarget = unknownConditionTarget(in: owned.mapping) {
                    reviewItems.append(
                        MappingTransformReviewItem(
                            sourceMappingID: owned.mapping.id,
                            deviceID: owned.deviceID,
                            destination: destination,
                            proposedMapping: nil,
                            reason: .unknownConditionTarget(rawValue: rawTarget)
                        )
                    )
                    continue
                }

                let clone = translatedCopy(of: owned.mapping, to: destination)
                let candidates = comparisonRows[owned.deviceID] ?? []
                if let duplicate = candidates.first(where: {
                    exactSemanticDataMatches($0, clone)
                }) {
                    duplicateSkips.append(
                        MappingTransformDuplicateSkip(
                            sourceMappingID: owned.mapping.id,
                            deviceID: owned.deviceID,
                            destination: destination,
                            existingMappingID: duplicate.id
                        )
                    )
                    continue
                }

                let conflicts = candidates.filter {
                    functionalIdentityMatches($0, clone)
                }
                if !conflicts.isEmpty {
                    reviewItems.append(contentsOf: conflicts.map { existing in
                        MappingTransformReviewItem(
                            sourceMappingID: owned.mapping.id,
                            deviceID: owned.deviceID,
                            destination: destination,
                            proposedMapping: clone,
                            reason: .functionalConflict(existingMappingID: existing.id)
                        )
                    })
                    continue
                }

                inserts.append(
                    MappingTransformInsert(
                        sourceMappingID: owned.mapping.id,
                        deviceID: owned.deviceID,
                        destination: destination,
                        mapping: clone
                    )
                )
                comparisonRows[owned.deviceID, default: []].append(clone)
            }
        }

        return MappingTransformPlan(
            inserts: inserts,
            duplicateSkips: duplicateSkips,
            ignoredMappingIDs: ignoredIDs,
            reviewItems: reviewItems
        )
    }

    private struct OwnedMapping {
        let deviceID: Device.ID
        let mapping: MappingEntry
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
        to destination: DeckCloneDestination
    ) -> MappingEntry {
        var clone = source.copyWithNewID()
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
