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
        let conditionTargets = Self.conditionTargets(for: entry)
        guard conditionTargets.one == 0, conditionTargets.two == 0 else {
            // The model cannot express nonzero native condition targets, so
            // replacing such a row would erase part of its activation logic.
            return nil
        }

        commandID = entry.commandID
        direction = entry.ioType
        canonicalTarget = TSIWriter.targetRaw(for: entry)
        setToWireValue = TSIWriter.setValueRaw(for: entry, commandId: entry.commandID)
        conditionOne = Self.condition(
            entry.modifier1Condition,
            target: conditionTargets.one
        )
        conditionTwo = Self.condition(
            entry.modifier2Condition,
            target: conditionTargets.two
        )
    }

    private static func conditionTargets(for entry: MappingEntry) -> (one: UInt32, two: UInt32) {
        guard let imported = entry.importedCMAD else {
            return (0, 0)
        }
        let baseline = imported.semanticAtImport
        return (
            entry.modifier1Condition == baseline.modifier1Condition
                ? imported.conditionOneTarget ?? 0
                : 0,
            entry.modifier2Condition == baseline.modifier2Condition
                ? imported.conditionTwoTarget ?? 0
                : 0
        )
    }

    private static func condition(
        _ condition: ModifierCondition?,
        target: UInt32
    ) -> Condition? {
        let modifier = UInt32(clamping: condition?.modifier ?? 0)
        let value = UInt32(clamping: condition?.value ?? 0)
        guard target != 0 || modifier != 0 || value != 0 else { return nil }
        return Condition(target: target, modifier: modifier, value: value)
    }
}
