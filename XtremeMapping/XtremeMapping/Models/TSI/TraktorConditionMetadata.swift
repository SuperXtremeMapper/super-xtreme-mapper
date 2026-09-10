import Foundation

/// Hotcue conditions captured from Traktor 4.5.1 build 21. The persisted
/// modifier/value fields retain their original representation for compatibility.
enum TraktorConditionMetadata {
    struct Value: Identifiable, Equatable {
        let rawValue: Int
        let label: String
        var id: Int { rawValue }
    }

    static func hotcueNumber(for identifier: Int) -> Int? {
        (2333...2340).contains(identifier) ? identifier - 2332 : nil
    }

    static func name(for identifier: Int) -> String {
        if (1...8).contains(identifier) { return "M\(identifier)" }
        if let number = hotcueNumber(for: identifier) { return "Hotcue \(number) State" }
        return "Condition \(identifier)"
    }

    static func values(for identifier: Int) -> [Value] {
        if (1...8).contains(identifier) { return (0...7).map { Value(rawValue: $0, label: String($0)) } }
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
}
