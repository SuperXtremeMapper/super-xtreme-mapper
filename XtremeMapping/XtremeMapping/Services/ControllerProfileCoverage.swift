import Foundation

/// Coverage describes documented address lookup, never a promise to generate device behavior.
nonisolated enum ControllerProfileCoverage {
    enum Availability: String {
        case addressLookup = "Address lookup"
        case documentedOnly = "Documented only"
    }

    static func availability(of binding: ControllerProfile.Binding) -> Availability {
        guard binding.support != .documentedOnly,
              binding.kind == .note || binding.kind == .controlChange,
              let number = binding.number, (0...127).contains(number) else { return .documentedOnly }
        return .addressLookup
    }

    /// Legacy K routing can keep a control on base while another group changes layer.
    /// Match the resolver's manufacturer results, including feedback color, rather
    /// than treating the requested layer as a literal binding filter.
    static func resolvedManufacturerBindings(in control: ControllerProfile.Control,
                                             resolution: ControlResolution) -> [ControllerProfile.Binding] {
        guard case .resolved(let resolved) = resolution else { return [] }
        return control.bindings.filter { binding in
            resolved.contains { result in
                result.provenance == "manufacturer-documented"
                    && result.direction == binding.direction && result.color == binding.color
                    && result.midi.number == binding.number
                    && ((result.midi.kind == .note && binding.kind == .note)
                        || (result.midi.kind == .controlChange && binding.kind == .controlChange))
            }
        }
    }

    static func label(of profile: ControllerProfile) -> String {
        switch profile.coverageState {
        case .partial: return "Partial MIDI coverage"
        case .documentationOnly: return "Documentation only"
        case nil: return "Manufacturer documented"
        }
    }

    static func summary(of profile: ControllerProfile) -> String {
        if profile.coverageState == .documentationOnly {
            return "No control addresses established. Manuals and setup information are available."
        }
        let bindings = profile.controls.flatMap(\.bindings)
        let available = bindings.filter { availability(of: $0) == .addressLookup }.count
        return "\(available) documented addresses for lookup · \(bindings.count - available) documented messages unavailable for lookup"
    }

    static func channelDescription(of binding: ControllerProfile.Binding) -> String {
        binding.channel.map { "Fixed MIDI channel \($0)" } ?? "Uses configured MIDI channel"
    }

    static func messageDescription(of binding: ControllerProfile.Binding) -> String {
        switch binding.kind {
        case .note: return binding.number.map { "Note \($0)" } ?? "Note address not specified"
        case .controlChange: return binding.number.map { "CC \($0)" } ?? "CC address not specified"
        case .compound: return "Paired or compound MIDI message"
        case .other: return "Other documented message"
        }
    }
}
