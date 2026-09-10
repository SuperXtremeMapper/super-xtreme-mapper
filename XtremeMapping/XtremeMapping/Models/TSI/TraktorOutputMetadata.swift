import Foundation

/// Command value domains, independent of the receiving controller's colours.
/// Hotcue and continuous representations are evidenced by NI's bundled
/// Maschine templates; Boolean outputs by the native Traktor 4.5.1 fixture.
enum TraktorOutputMetadata {
    enum Domain: Equatable, Sendable {
        case boolean, hotcue, modifier, continuous

        var rangeType: Int { self == .continuous ? 2 : 1 }
        var bounds: ClosedRange<Double> {
            switch self {
            case .boolean, .continuous: 0...1
            case .hotcue: -1...5
            case .modifier: 0...7
            }
        }
        var help: String {
            switch self {
            case .boolean: "0 = Off, 1 = On"
            case .hotcue: "−1 = No Hotcue, 0 = Cue, 1 = Fade-In, 2 = Fade-Out, 3 = Load, 4 = Grid, 5 = Loop"
            case .modifier: "Modifier values: 0–7"
            case .continuous: "Continuous value: 0–1"
            }
        }
    }

    static func domain(for commandID: Int) -> Domain? {
        switch commandID {
        case 100, 125, 202, 2350: .boolean
        case 2333...2340: .hotcue
        case 2548...2555: .modifier
        case 117, 365...368: .continuous
        default: nil
        }
    }
}

extension MappingEntry {
    static func input(commandID: Int) -> MappingEntry {
        if commandID == 3482 {
            return MappingEntry(commandID: commandID, ioType: .input, assignment: .global,
                                interactionMode: .trigger, controllerType: .button)
        }
        return MappingEntry(commandID: commandID, ioType: .input)
    }

    /// Creation policy only. Imported mappings never pass through this factory.
    /// Hotcue uses the observed native -1...5 domain; users can narrow it to
    /// 0...5 for any populated cue or equal endpoints for an individual state.
    static func output(commandID: Int) -> MappingEntry {
        var entry = MappingEntry(commandID: commandID, ioType: .output,
                                 interactionMode: .output, controllerType: .led)
        if TraktorCommands.usesGlobalTargetZero(commandID, direction: .output) {
            entry.assignment = .global
        }
        if let domain = TraktorOutputMetadata.domain(for: commandID) {
            entry.ledMinRangeType = domain.rangeType
            entry.ledMaxRangeType = domain.rangeType
            if domain.rangeType == 2 {
                entry.ledMinRangeData = Int(Float(domain.bounds.lowerBound).bitPattern)
                entry.ledMaxRangeData = Int(Float(domain.bounds.upperBound).bitPattern)
                entry.ledBlend = true
                entry.resolution = Int(Float(0.0625).bitPattern)
            } else {
                entry.ledMinRangeData = Int(UInt32(bitPattern: Int32(domain.bounds.lowerBound)))
                entry.ledMaxRangeData = Int(UInt32(bitPattern: Int32(domain.bounds.upperBound)))
            }
        }
        return entry
    }
}
