import Foundation

/// Semantic editing over the losslessly persisted CMAD words. Never changes
/// endpoint types implicitly and never interprets an unknown encoding.
enum LEDOutputSettings {
    enum Field: CaseIterable, Hashable, Sendable {
        case controllerMinimum, controllerMaximum, midiMinimum, midiMaximum
    }

    enum EditError: LocalizedError {
        case inputSelection, incompleteRecord, unsupportedRange, invalidInteger, invalidFloat, invalidMIDI, outsideDomain, incompatibleSelection

        var errorDescription: String? {
            switch self {
            case .inputSelection: "Select only OUT mappings to edit LED settings."
            case .incompleteRecord: "This imported mapping has an incomplete LED record. Original data is preserved."
            case .unsupportedRange: "This controller range uses an unsupported encoding. Its original values will be preserved."
            case .invalidInteger: "Enter a whole number within the supported controller range."
            case .invalidFloat: "Enter a finite number within the supported controller range."
            case .invalidMIDI: "MIDI values must be whole numbers from 0 to 127."
            case .outsideDomain: "The value is outside this command’s controller range."
            case .incompatibleSelection: "Select outputs with matching value domains to edit their controller ranges together."
            }
        }
    }

    struct Patch: Equatable, Sendable {
        var controllerMinimum: String? = nil
        var controllerMaximum: String? = nil
        var midiMinimum: String? = nil
        var midiMaximum: String? = nil
        var blend: Bool? = nil
        var invert: Bool? = nil

        var isEmpty: Bool { self == Patch() }
        var changesControllerRange: Bool { controllerMinimum != nil || controllerMaximum != nil }

        func applying(to mapping: MappingEntry) throws -> MappingEntry {
            guard mapping.ioType == .output else { throw EditError.inputSelection }
            guard isEmpty || hasEditableLEDFields(in: mapping) else { throw EditError.incompleteRecord }
            var result = mapping
            if let controllerMinimum {
                result.ledMinRangeData = try encode(controllerMinimum, type: mapping.ledMinRangeType, commandID: mapping.commandID)
            }
            if let controllerMaximum {
                result.ledMaxRangeData = try encode(controllerMaximum, type: mapping.ledMaxRangeType, commandID: mapping.commandID)
            }
            if let midiMinimum { result.ledMinMidi = try midiValue(midiMinimum) }
            if let midiMaximum { result.ledMaxMidi = try midiValue(midiMaximum) }
            if let blend { result.ledBlend = blend }
            if let invert { result.ledInvert = invert }
            return result
        }
    }

    static func hasEditableLEDFields(in mapping: MappingEntry) -> Bool {
        guard let imported = mapping.importedCMAD else { return true }
        // A shorter native layout is intentionally openable with projected
        // defaults, but ordinary save cannot safely invent its missing tail.
        return imported.useFactoryMap != nil && imported.ledBlend != nil
    }

    static func text(for field: Field, in mapping: MappingEntry) -> String? {
        switch field {
        case .midiMinimum: return String(mapping.ledMinMidi)
        case .midiMaximum: return String(mapping.ledMaxMidi)
        case .controllerMinimum: return rangeText(type: mapping.ledMinRangeType, data: mapping.ledMinRangeData)
        case .controllerMaximum: return rangeText(type: mapping.ledMaxRangeType, data: mapping.ledMaxRangeData)
        }
    }

    static func canEditControllerRange(in mappings: [MappingEntry]) -> Bool {
        guard let first = mappings.first,
              mappings.allSatisfy({ $0.ioType == .output
                  && hasEditableLEDFields(in: $0)
                  && text(for: .controllerMinimum, in: $0) != nil
                  && text(for: .controllerMaximum, in: $0) != nil }) else { return false }
        if mappings.count == 1 { return true }
        guard let domain = TraktorOutputMetadata.domain(for: first.commandID),
              first.ledMinRangeType == domain.rangeType,
              first.ledMaxRangeType == domain.rangeType else { return false }
        return mappings.allSatisfy {
            TraktorOutputMetadata.domain(for: $0.commandID) == domain
                && $0.ledMinRangeType == first.ledMinRangeType
                && $0.ledMaxRangeType == first.ledMaxRangeType
        }
    }

    /// Validates every replacement before returning a new file. Call within
    /// the document's undo transaction so batch edits are all-or-nothing.
    static func applying(_ patch: Patch, to selectedIDs: Set<MappingEntry.ID>, in file: MappingFile) throws -> MappingFile {
        let selected = file.allMappings.filter { selectedIDs.contains($0.id) }
        guard !selected.isEmpty, selected.allSatisfy({ $0.ioType == .output }) else { throw EditError.inputSelection }
        if patch.changesControllerRange && !canEditControllerRange(in: selected) {
            throw EditError.incompatibleSelection
        }
        let replacements = try Dictionary(uniqueKeysWithValues: selected.map { ($0.id, try patch.applying(to: $0)) })
        var result = file
        for deviceIndex in result.devices.indices {
            for mappingIndex in result.devices[deviceIndex].mappings.indices {
                let id = result.devices[deviceIndex].mappings[mappingIndex].id
                if let replacement = replacements[id] { result.devices[deviceIndex].mappings[mappingIndex] = replacement }
            }
        }
        return result
    }

    private static func rangeText(type: Int, data: Int) -> String? {
        guard let bits = UInt32(exactly: data) else { return nil }
        switch type {
        case 1: return String(Int32(bitPattern: bits))
        case 2:
            let value = Float(bitPattern: bits)
            return value.isFinite ? String(value) : nil
        default: return nil
        }
    }

    private static func encode(_ text: String, type: Int, commandID: Int) throws -> Int {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let bits: UInt32
        let value: Double
        switch type {
        case 1:
            guard let integer = Int32(text) else { throw EditError.invalidInteger }
            bits = UInt32(bitPattern: integer)
            value = Double(integer)
        case 2:
            guard let number = Float(text), number.isFinite else { throw EditError.invalidFloat }
            bits = number.bitPattern
            value = Double(number)
        default: throw EditError.unsupportedRange
        }
        // Mismatched imported types remain explicit raw-preserving edits;
        // do not apply an unrelated interpretation from command metadata.
        if let domain = TraktorOutputMetadata.domain(for: commandID), domain.rangeType == type,
           !domain.bounds.contains(value) { throw EditError.outsideDomain }
        return Int(bits)
    }

    private static func midiValue(_ text: String) throws -> Int {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), (0...127).contains(value) else {
            throw EditError.invalidMIDI
        }
        return value
    }
}
