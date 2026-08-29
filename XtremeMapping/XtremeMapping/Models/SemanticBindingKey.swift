//
//  SemanticBindingKey.swift
//  SuperXtremeMapping
//

import Foundation

/// Exact semantic identity used when wizard and voice sessions replace rows.
///
/// MIDI assignment, comments and display names are deliberately excluded.
/// Callers scope comparisons to one explicit destination device before using
/// this key.
struct SemanticBindingKey: Hashable, Sendable {
    struct Condition: Hashable, Sendable {
        let target: UInt32
        let modifier: UInt32
        let value: UInt32
    }

    let commandID: Int
    let direction: IODirection
    let canonicalTarget: UInt32
    let setToWireValue: UInt32
    let conditionOne: Condition?
    let conditionTwo: Condition?

    init?(entry: MappingEntry) {
        guard Self.importedConditionTargetsMatchFingerprint(entry) else {
            // Hand-built or corrupted state that disagrees about whether a
            // raw target was modeled is still unsafe to replace. Real parser
            // output and migrated legacy Codable state satisfy this check.
            return nil
        }
        commandID = entry.commandID
        direction = entry.ioType
        canonicalTarget = TSIWriter.targetRaw(for: entry)
        setToWireValue = TSIWriter.setValueRaw(for: entry, commandId: entry.commandID)
        conditionOne = Self.condition(entry.modifier1Condition)
        conditionTwo = Self.condition(entry.modifier2Condition)
    }

    private static func importedConditionTargetsMatchFingerprint(
        _ entry: MappingEntry
    ) -> Bool {
        guard let imported = entry.importedCMAD else { return true }
        return targetMatches(
            wireID: imported.conditionOneID,
            wireTarget: imported.conditionOneTarget,
            modeled: imported.semanticAtImport.modifier1Condition
        ) && targetMatches(
            wireID: imported.conditionTwoID,
            wireTarget: imported.conditionTwoTarget,
            modeled: imported.semanticAtImport.modifier2Condition
        )
    }

    private static func targetMatches(
        wireID: UInt32?,
        wireTarget: UInt32?,
        modeled condition: ModifierCondition?
    ) -> Bool {
        guard wireID != 0, let wireTarget else { return true }
        return wireTarget == (condition?.target.rawValue ?? 0)
    }

    private static func condition(_ condition: ModifierCondition?) -> Condition? {
        let target = condition?.target.rawValue ?? 0
        let modifier = UInt32(clamping: condition?.modifier ?? 0)
        let value = UInt32(clamping: condition?.value ?? 0)
        guard target != 0 || modifier != 0 || value != 0 else { return nil }
        return Condition(target: target, modifier: modifier, value: value)
    }
}
