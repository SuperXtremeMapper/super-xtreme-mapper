import Foundation

/// Software-state conditions and ordinary M1–M8 modifiers. The persisted
/// identifier/value fields retain their native representation for compatibility.
/// Deck Play, Is In Active Loop and Hotcue states were captured in Traktor
/// 4.5.1 build 21; see the native condition fixtures and issue 1 diagnostic.
enum TraktorConditionMetadata {
    struct Value: Identifiable, Equatable {
        let rawValue: Int
        let label: String
        var id: Int { rawValue }
    }

    static func hotcueNumber(for identifier: Int) -> Int? {
        (2333...2340).contains(identifier) ? identifier - 2332 : nil
    }

    static let deckConditionIDs = [100, 203] + Array(2333...2340)
    static let targetedConditionIDs = [100, 203, 247] + Array(2333...2340)

    static func hasDeckTarget(for identifier: Int) -> Bool {
        deckConditionIDs.contains(identifier)
    }

    static func hasTarget(for identifier: Int) -> Bool {
        targetedConditionIDs.contains(identifier)
    }

    static func name(for identifier: Int) -> String {
        if (1...8).contains(identifier) { return "M\(identifier)" }
        if identifier == 100 { return "Deck Play" }
        if identifier == 203 { return "Is In Active Loop" }
        if identifier == 247 { return "Slot State" }
        if let number = hotcueNumber(for: identifier) { return "Hotcue \(number) State" }
        return "Condition \(identifier)"
    }

    static func values(for identifier: Int) -> [Value] {
        if (1...8).contains(identifier) { return (0...7).map { Value(rawValue: $0, label: String($0)) } }
        if identifier == 100 {
            return [Value(rawValue: 0, label: "Off"), Value(rawValue: 1, label: "On")]
        }
        if identifier == 203 {
            return (0...1).map { Value(rawValue: $0, label: String($0)) }
        }
        if identifier == 247 {
            return ["Empty", "Loaded", "Playing"].enumerated().map {
                Value(rawValue: $0.offset, label: $0.element)
            }
        }
        if hotcueNumber(for: identifier) != nil {
            return [Value(rawValue: Int(UInt32.max), label: "No Hotcue")]
                + ["Cue", "Fade-In", "Fade-Out", "Load", "Grid", "Loop"].enumerated().map {
                    Value(rawValue: $0.offset, label: $0.element)
                }
        }
        return []
    }

    static func valueLabel(for condition: ModifierCondition) -> String {
        values(for: condition.modifier).first { $0.rawValue == condition.value }?.label ?? String(condition.value)
    }

    static let targets: [ModifierConditionTarget] = [.deckA, .deckB, .deckC, .deckD, .deviceTarget]

    /// Raw target values have condition-specific meanings. Slot State uses
    /// sixteen deck/slot pairs and has no Device Target option (Traktor 4.5.1).
    static func targets(for identifier: Int) -> [ModifierConditionTarget] {
        if identifier == 247 { return (UInt32(0)..<16).map(ModifierConditionTarget.init(rawValue:)) }
        return hasDeckTarget(for: identifier) ? targets : []
    }

    static func targetLabel(_ target: ModifierConditionTarget, for identifier: Int) -> String {
        if identifier == 247 {
            let raw = target.rawValue
            guard raw < 16 else { return "Target \(raw)" }
            let deck = ["A", "B", "C", "D"][Int(raw / 4)]
            return "Remix Deck \(deck) · Slot \(raw % 4 + 1)"
        }
        return targetLabel(target)
    }

    static func targetLabel(_ target: ModifierConditionTarget) -> String {
        switch target {
        case .deckA: "Deck A"
        case .deckB: "Deck B"
        case .deckC: "Deck C"
        case .deckD: "Deck D"
        case .deviceTarget: "Device Target"
        case .unknown(let raw): "Target \(raw)"
        }
    }

    static func replacingValue(of condition: ModifierCondition, with value: Int) -> ModifierCondition? {
        guard values(for: condition.modifier).contains(where: { $0.rawValue == value }) else { return nil }
        var result = condition
        result.value = value
        return result
    }

    /// Changing only the target preserves even an unfamiliar imported value.
    /// Switching families starts at zero: a Hotcue's Fade-In (1), for example,
    /// must not silently become a software state's On (1).
    static func selectingDeckCondition(_ identifier: Int, target: ModifierConditionTarget,
                                       previous: ModifierCondition?) -> ModifierCondition {
        let sameKind = previous?.modifier == identifier
            || (previous.map { hotcueNumber(for: $0.modifier) != nil } == true
                && hotcueNumber(for: identifier) != nil)
        return ModifierCondition(modifier: identifier, value: sameKind ? previous?.value ?? 0 : 0, target: target)
    }
}
