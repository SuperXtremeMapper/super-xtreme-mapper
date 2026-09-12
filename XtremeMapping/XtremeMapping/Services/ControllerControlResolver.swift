import Foundation

nonisolated struct ResolvedControllerBinding: Equatable, Sendable {
    let midi: MIDIAssignment
    let direction: ControllerProfile.Direction
    let color: ControllerProfile.Color?
    let provenance: String
    let evidence: [String]
}

nonisolated enum ControlResolution: Equatable, Sendable {
    case resolved([ResolvedControllerBinding])
    case unresolved(String)
}

/// Deterministic lookup of hardware facts. No port-name inference or deck assumptions.
nonisolated struct ControllerControlResolver: Sendable {
    let library: ControllerProfileLibrary

    func resolve(controlID: String, configuration: ControllerConfiguration?,
                 layer: ControllerProfile.Layer, direction: ControllerProfile.Direction) -> ControlResolution {
        guard let configuration else {
            return .unresolved("Select a controller profile and explicitly confirm its channel, layer mode and unit map.")
        }
        let profile: ControllerProfile
        do { profile = try library.profile(id: configuration.profileID, version: configuration.version) }
        catch { return .unresolved(error.localizedDescription) }
        guard (1...16).contains(configuration.globalChannel) else {
            return .unresolved("Global MIDI channel must be between 1 and 16.")
        }
        guard let mode = profile.modes.first(where: { $0.id == configuration.layerMode }) else {
            return .unresolved("Layer mode \(configuration.layerMode) is not supported by \(profile.model).")
        }
        guard let unitMap = profile.unitMaps.first(where: { $0.id == configuration.unitMap }) else {
            return .unresolved("Unit map \(configuration.unitMap) is not supported by \(profile.model).")
        }
        guard let control = profile.controls.first(where: { $0.id == controlID }) else {
            return .unresolved("Physical control \(controlID) is absent from the pinned profile.")
        }
        guard !control.reservedInModes.contains(mode.id) else {
            return .unresolved("The LAYER button is reserved for hardware layer switching in this mode.")
        }
        let isK3 = profile.id == "allen-heath.xone-k3"
        if direction == .receive && isK3 {
            guard configuration.feedbackMode == "remote" else {
                return .unresolved(configuration.feedbackMode == "linked"
                    ? "Linked LEDs follow their physical switch; host feedback is unavailable."
                    : "Confirm Remote LED mode on the hardware before resolving host feedback.")
            }
        }

        let overrides = configuration.overrides.filter {
            $0.controlID == controlID && $0.layerMode == mode.id && $0.unitMap == unitMap.id
                && $0.layer == layer && $0.direction == direction
        }
        guard overrides.count <= 1 else {
            return .unresolved("Multiple local overrides match this control and context. Keep one explicit address.")
        }
        if let override = overrides.first {
            guard let midi = try? override.midi.model(), midi.kind != .unassigned else {
                return .unresolved("The local override needs a valid Note or CC address and a channel between 1 and 16.")
            }
            return .resolved([ResolvedControllerBinding(midi: midi, direction: direction, color: nil,
                                                        provenance: override.provenance.rawValue, evidence: [])])
        }
        guard unitMap.usesFactoryBindings else {
            return .unresolved("Custom unit map addresses are unknown. Supply an explicit override or learn this control in the selected layer.")
        }

        let layeredControl = mode.layeredGroups.contains(control.group)
        let effectiveLayer: ControllerProfile.Layer = layeredControl ? layer : .base
        let restrictColor = direction == .receive && (isK3 ? mode.id != "off" : layeredControl)
        let color: ControllerProfile.Color = layer == .base ? .red : layer == .amber ? .amber : .green
        let applicable = control.bindings.filter {
            $0.direction == direction && (direction == .send
                ? $0.layer == effectiveLayer
                : !restrictColor || $0.color == color)
        }
        guard !applicable.isEmpty else {
            return .unresolved("No manufacturer-documented \(direction.rawValue) binding exists for this control in the selected context.")
        }
        var resolved: [ResolvedControllerBinding] = []
        for binding in applicable {
            let midi: MIDIAssignment
            do {
                midi = try MIDIAssignment(validatingChannel: configuration.globalChannel,
                                          note: binding.kind == .note ? binding.number : nil,
                                          cc: binding.kind == .controlChange ? binding.number : nil)
            } catch { return .unresolved("The documented binding is not a valid MIDI assignment.") }
            resolved.append(ResolvedControllerBinding(midi: midi, direction: direction, color: binding.color,
                                                       provenance: "manufacturer-documented", evidence: binding.evidence))
        }
        return .resolved(resolved)
    }

    /// Return every compatible row once in document order, including independent deck/modifier rows.
    func matchingRows(bindings: [ResolvedControllerBinding], device: Device) -> [UUID] {
        var seen = Set<UUID>()
        return device.mappings.compactMap { row in
            guard row.rawMidiControlName == nil, row.rawMidiBindingID == nil,
                  bindings.contains(where: { binding in
                      binding.midi.kind != .unassigned && row.midiAssignment == binding.midi
                          && (row.ioType == .all || (binding.direction == .send ? row.ioType == .input : row.ioType == .output))
                  }), seen.insert(row.id).inserted else { return nil }
            return row.id
        }
    }
}
