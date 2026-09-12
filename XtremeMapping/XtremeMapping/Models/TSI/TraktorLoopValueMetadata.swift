import Foundation

/// CMDR LoopSize enum for Loop Size Selector (2196). See diagnostics evidence.
nonisolated enum TraktorLoopValueMetadata {
    struct Choice: Identifiable, Equatable {
        let value: Float
        let label: String
        var id: Float { value }
    }

    static let commandID = 2196
    static let choices: [Choice] = ["1/32", "1/16", "1/8", "1/4", "1/2", "1", "2", "4", "8", "16", "32"]
        .enumerated().map { Choice(value: Float($0.offset), label: $0.element) }

    static func choices(including value: Float) -> [Choice] {
        if choices.contains(where: { $0.value == value }) { return choices }
        return [Choice(value: value, label: "Unknown (\(value.formatted()))")] + choices
    }

    static func decode(_ raw: UInt32) -> Float {
        Float(Int32(bitPattern: raw))
    }

    static func encode(_ mapping: MappingEntry) -> UInt32 {
        // Preserve unfamiliar imported selectors even beyond Float's precision.
        if let imported = mapping.importedCMAD,
           imported.semanticAtImport.commandID == commandID,
           imported.semanticAtImport.setToValueBits == mapping.setToValue.bitPattern {
            return imported.setToValueBits
        }
        guard mapping.setToValue.isFinite else { return 0 }
        let value = min(Double(Int32.max), max(Double(Int32.min), Double(mapping.setToValue.rounded())))
        return UInt32(bitPattern: Int32(value))
    }
}
