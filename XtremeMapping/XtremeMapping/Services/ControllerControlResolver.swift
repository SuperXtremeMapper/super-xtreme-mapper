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
        if let portID = configuration.portID, !((profile.ports ?? []).contains { $0.id == portID }) {
            return .unresolved("The selected port is unavailable in this exact profile. Select a documented port.")
        }
        guard let control = library.control(id: controlID, profileID: profile.id, version: profile.version) else {
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
                && $0.layer == layer && $0.direction == direction && $0.portID == configuration.portID
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

        let layeredControl = profile.schemaVersion == 1 && mode.layeredGroups.contains(control.group)
        let effectiveLayer: ControllerProfile.Layer = layeredControl ? layer : .base
        let restrictColor = profile.schemaVersion == 1 && direction == .receive && (isK3 ? mode.id != "off" : layeredControl)
        let color: ControllerProfile.Color = layer == .base ? .red : layer == .amber ? .amber : .green
        let applicable = control.bindings.filter {
            ($0.modeID == nil || $0.modeID == mode.id) && ($0.portID == nil || $0.portID == configuration.portID) &&
            $0.direction == direction && (direction == .send
                ? $0.layer == effectiveLayer
                : !restrictColor || $0.color == color)
        }
        guard !applicable.isEmpty else {
            return .unresolved("No manufacturer-documented \(direction.rawValue) binding exists for this control in the selected context.")
        }
        var resolved: [ResolvedControllerBinding] = []
        for binding in applicable {
            guard binding.support != .documentedOnly,
                  binding.kind == .note || binding.kind == .controlChange,
                  binding.number != nil else {
                return .unresolved("This documented control cannot be represented by a generic Note or CC assignment. Review its documented message components and use a compatible controller-specific workflow.")
            }
            let midi: MIDIAssignment
            do {
                midi = try MIDIAssignment(validatingChannel: binding.channel ?? configuration.globalChannel,
                                          note: binding.kind == .note ? binding.number : nil,
                                          cc: binding.kind == .controlChange ? binding.number : nil)
            } catch { return .unresolved("The documented binding is not a valid MIDI assignment.") }
            resolved.append(ResolvedControllerBinding(midi: midi, direction: direction, color: binding.color,
                                                       provenance: "manufacturer-documented", evidence: binding.evidence))
        }
        return .resolved(resolved)
    }

    /// A single MIDI address may resolve for both input (send) and LED (receive).
    /// Key the reverse index by address + direction so rows match on the same rule
    /// `matchingRows` uses (send→input, receive→output, all→either).
    nonisolated struct ReverseNameKey: Hashable, Sendable {
        let midi: MIDIAssignment
        let direction: ControllerProfile.Direction
    }

    /// Cacheable reverse index: address+direction → the single physical control name.
    /// Ambiguous addresses (two differently named controls sharing the same
    /// address+direction) are absent, so they resolve to no name (blank column).
    /// Depends only on (profile + configuration); NOT on any device's rows.
    nonisolated struct ReverseNameIndex: Equatable, Sendable {
        fileprivate let names: [ReverseNameKey: String]
        static let empty = ReverseNameIndex(names: [:])
    }

    /// Build the expensive reverse index once per configuration. This resolves every
    /// control in the profile; it does not touch any device's rows, so callers can
    /// cache it keyed by the configuration and only re-run the cheap `physicalNames`
    /// remap when rows change.
    func reverseNameIndex(configuration: ControllerConfiguration?) -> ReverseNameIndex {
        guard let configuration else { return .empty }
        let profile: ControllerProfile
        do { profile = try library.profile(id: configuration.profileID, version: configuration.version) }
        catch { return .empty }

        var names: [ReverseNameKey: String] = [:]
        // Keys proven ambiguous stay out of `names` permanently.
        var ambiguous: Set<ReverseNameKey> = []

        for control in profile.controls {
            for direction in [ControllerProfile.Direction.send, .receive] {
                for layer in [ControllerProfile.Layer.base, .amber, .green] {
                    let lookupLayer: ControllerProfile.Layer =
                        profile.schemaVersion == 2 || configuration.layerMode == "off" ? .base : layer
                    guard case .resolved(let bindings) = resolve(controlID: control.id, configuration: configuration,
                                                                 layer: lookupLayer, direction: direction) else { continue }
                    for binding in bindings where binding.midi.kind != .unassigned {
                        let key = ReverseNameKey(midi: binding.midi, direction: direction)
                        if ambiguous.contains(key) { continue }
                        if let existing = names[key] {
                            // A differently named control claims the same address:
                            // the address is ambiguous. Drop it and never re-add.
                            if existing != control.name {
                                names[key] = nil
                                ambiguous.insert(key)
                            }
                        } else {
                            names[key] = control.name
                        }
                    }
                    // Schema v2 has no per-layer variation; one pass suffices.
                    if profile.schemaVersion == 2 || configuration.layerMode == "off" { break }
                }
            }
        }
        return ReverseNameIndex(names: names)
    }

    /// Cheap remap: map each device row to its physical control name using a prebuilt
    /// index. Rows with a raw/opaque MIDI assignment, unassigned MIDI, or whose address
    /// is absent/ambiguous in the index are omitted (blank column).
    func physicalNames(index: ReverseNameIndex, device: Device) -> [UUID: String] {
        var result: [UUID: String] = [:]
        for row in device.mappings where row.rawMidiControlName == nil && row.rawMidiBindingID == nil {
            let midi = row.midiAssignment
            guard midi.kind != .unassigned else { continue }
            let direction: ControllerProfile.Direction = row.ioType == .output ? .receive : .send
            if let name = index.names[ReverseNameKey(midi: midi, direction: direction)] {
                result[row.id] = name
            } else if row.ioType == .all {
                if let name = index.names[ReverseNameKey(midi: midi, direction: .send)]
                    ?? index.names[ReverseNameKey(midi: midi, direction: .receive)] {
                    result[row.id] = name
                }
            }
        }
        return result
    }

    /// Reverse lookup convenience: build the index and remap in one shot.
    /// Rows with a raw/opaque MIDI assignment, or with no unambiguous matching control,
    /// are omitted.
    func physicalNames(configuration: ControllerConfiguration?, device: Device) -> [UUID: String] {
        physicalNames(index: reverseNameIndex(configuration: configuration), device: device)
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
