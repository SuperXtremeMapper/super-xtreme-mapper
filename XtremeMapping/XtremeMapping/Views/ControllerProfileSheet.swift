import SwiftUI

/// A device-scoped draft. Selection, lookup and MIDI capture never mutate the open document.
struct ControllerProfileSheet: View {
    @ObservedObject var document: TraktorMappingDocument
    let deviceID: UUID
    let isLocked: Bool
    let undoManager: UndoManager?
    let onShowMappings: (Set<UUID>) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var midiManager = MIDIInputManager.shared
    @State private var initialMetadata: SXMJSONMetadata?
    @State private var draft: ControllerConfiguration?
    @State private var controlID: String? = "fader.1"
    @State private var query = ""
    @State private var layer: ControllerProfile.Layer = .base
    @State private var direction: ControllerProfile.Direction = .send
    @State private var manualKind = "controlChange"
    @State private var manualChannel = 15
    @State private var manualNumber = 16
    @State private var pendingMIDI: MIDIAssignment?
    @State private var lease: MIDIInputManager.ListeningLease?
    @State private var errorMessage: String?
    private let library: ControllerProfileLibrary?
    private let libraryError: String?

    init(document: TraktorMappingDocument, deviceID: UUID, isLocked: Bool,
         undoManager: UndoManager?, onShowMappings: @escaping (Set<UUID>) -> Void) {
        self.document = document
        self.deviceID = deviceID
        self.isLocked = isLocked
        self.undoManager = undoManager
        self.onShowMappings = onShowMappings
        _initialMetadata = State(initialValue: document.mappingFile.interchangeMetadata)
        _draft = State(initialValue: document.mappingFile.interchangeMetadata?.deviceProfiles?.first { $0.deviceID == deviceID }?.configuration)
        do { library = try ControllerProfileLibrary(); libraryError = nil }
        catch { library = nil; libraryError = error.localizedDescription }
    }

    private var device: Device? { document.mappingFile.devices.first { $0.id == deviceID } }
    private var profile: ControllerProfile? {
        guard let draft else { return nil }
        return try? library?.profile(id: draft.profileID, version: draft.version)
    }
    private var lookupLayer: ControllerProfile.Layer { draft?.layerMode == "off" ? .base : layer }
    private var resolution: ControlResolution {
        guard let library, let controlID else { return .unresolved("Select a physical control to inspect its MIDI address.") }
        return ControllerControlResolver(library: library).resolve(controlID: controlID, configuration: draft,
                                                                  layer: lookupLayer, direction: direction)
    }
    private var bindings: [ResolvedControllerBinding] {
        if case .resolved(let bindings) = resolution { return bindings }
        return []
    }
    private var matchingIDs: [UUID] {
        guard let library, let device else { return [] }
        return ControllerControlResolver(library: library).matchingRows(bindings: bindings, device: device)
    }
    private var changed: Bool {
        draft != initialMetadata?.deviceProfiles?.first { $0.deviceID == deviceID }?.configuration
    }
    private var stale: Bool { initialMetadata != document.mappingFile.interchangeMetadata || device == nil }
    private var contextKey: String {
        [draft?.profileID ?? "", draft?.version ?? "", String(draft?.globalChannel ?? 0), draft?.layerMode ?? "",
         draft?.unitMap ?? "", draft?.feedbackMode ?? "", controlID ?? "", lookupLayer.rawValue, direction.rawValue].joined(separator: "|")
    }
    private var visibleControls: [ControllerProfile.Control] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (profile?.controls ?? []).filter { c in
            needle.isEmpty || ([c.name, c.id] + c.aliases).contains { $0.localizedCaseInsensitiveContains(needle) }
        }
    }
    private func setting<T>(_ keyPath: WritableKeyPath<ControllerConfiguration, T>, fallback: T) -> Binding<T> {
        Binding(get: { draft?[keyPath: keyPath] ?? fallback }, set: { draft?[keyPath: keyPath] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Controller Profile").font(.title2.weight(.semibold))
                Spacer()
                Text(device?.name ?? "Device no longer available").foregroundStyle(AppThemeV2.Colors.stone400)
            }
            Text("Identify physical controls and find their mapped actions.")
                .foregroundStyle(AppThemeV2.Colors.stone400)
            configurationSection
            Divider()
            if profile != nil {
                HStack(alignment: .top, spacing: 16) {
                    controlList.frame(width: 235)
                    Divider()
                    ScrollView { controlDetails.frame(maxWidth: .infinity, alignment: .leading) }
                }.frame(height: 365)
            } else {
                Text(draft == nil ? "Choose a controller to browse its documented controls."
                     : "This exact profile version is unavailable. Its saved settings are retained; select another profile only if you intend to replace them.")
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                    .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
            }
            Divider()
            Text("Settings describe your hardware; they do not change it. Save profile settings and overrides with Export JSON. TSI alone does not retain them.")
                .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
            if let message = errorMessage ?? libraryError {
                Text(message).foregroundStyle(AppThemeV2.Colors.danger).fixedSize(horizontal: false, vertical: true)
            }
            if stale { Text("The document changed. Close this sheet and reopen it before applying settings.").foregroundStyle(AppThemeV2.Colors.amber) }
            if isLocked { Text("Editing is locked. Saved profiles can still be inspected.").foregroundStyle(AppThemeV2.Colors.amber) }
            HStack {
                Text(changed ? "Unsaved profile settings" : "Profile version \(draft?.version ?? "—")")
                    .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                Spacer()
                Button("Cancel") { stopLearning(); dismiss() }.keyboardShortcut(.cancelAction)
                Button("Apply Profile") { apply(showMappings: false) }
                    .disabled(!changed || isLocked || stale || library == nil)
                Button(changed ? "Apply & Show Mappings" : "Show Mappings") { apply(showMappings: true) }
                    .disabled(matchingIDs.isEmpty || stale || (changed && isLocked))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .font(AppThemeV2.Typography.body)
        .padding(24)
        .frame(width: 880)
        .background(AppThemeV2.Colors.stone900)
        .foregroundStyle(AppThemeV2.Colors.stone200)
        .tint(AppThemeV2.Colors.amber)
        .onChange(of: contextKey) { _, _ in resetCapture() }
        .onChange(of: midiManager.activeListeningLease) { _, current in
            if let lease, current != lease { self.lease = nil; pendingMIDI = nil }
        }
        .onDisappear { stopLearning() }
        .onAppear { resetCapture() }
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Controller", selection: Binding(get: { draft?.profileID ?? "" }, set: chooseProfile)) {
                    Text("No profile").tag("")
                    ForEach(library?.profiles ?? [], id: \.id) { p in Text(p.model).tag(p.id) }
                    if let draft, !(library?.profiles.contains { $0.id == draft.profileID } ?? false) {
                        Text("Unavailable: \(draft.profileID)").tag(draft.profileID)
                    }
                }.frame(width: 265)
                if draft != nil {
                    Picker("MIDI channel", selection: setting(\.globalChannel, fallback: 15)) {
                        ForEach(1...16, id: \.self) { Text(String($0)).tag($0) }
                    }.frame(width: 170)
                    Spacer()
                    Label("Manufacturer documented", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
            }.disabled(isLocked)
            if let profile {
                HStack {
                    Picker("Layer mode", selection: setting(\.layerMode, fallback: "off")) {
                        ForEach(profile.modes, id: \.id) { Text($0.name).tag($0.id) }
                        if let mode = draft?.layerMode, !profile.modes.contains(where: { $0.id == mode }) {
                            Text("Unavailable: \(mode)").tag(mode)
                        }
                    }
                    Picker("Unit map", selection: setting(\.unitMap, fallback: "factory")) {
                        ForEach(profile.unitMaps, id: \.id) { map in
                            Text(map.id == "factory" ? "Factory" : map.id.replacingOccurrences(of: "custom-", with: "Custom ")).tag(map.id)
                        }
                        if let map = draft?.unitMap, !profile.unitMaps.contains(where: { $0.id == map }) {
                            Text("Unavailable: \(map)").tag(map)
                        }
                    }.frame(width: 190)
                    if profile.id == "allen-heath.xone-k3" {
                        Picker("LED mode", selection: setting(\.feedbackMode, fallback: "unknown")) {
                            Text("Not specified").tag("unknown")
                            Text("Remote").tag("remote")
                            Text("Linked").tag("linked")
                            if let feedback = draft?.feedbackMode, !["unknown", "remote", "linked"].contains(feedback) {
                                Text("Unavailable: \(feedback)").tag(feedback)
                            }
                        }.frame(width: 200)
                    }
                }.disabled(isLocked)
            }
        }
    }

    private var controlList: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Find a control", text: $query).textFieldStyle(.roundedBorder)
            List(selection: $controlID) {
                ForEach(visibleControls, id: \.id) { control in
                    Text(control.name).tag(control.id).help(control.id)
                }
            }.listStyle(.plain).scrollContentBackground(.hidden)
            Text("\(visibleControls.count) control actions").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
        }
    }

    private var controlDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(profile?.controls.first { $0.id == controlID }?.name ?? "Choose a control").font(.headline)
            HStack {
                Picker("Direction", selection: $direction) {
                    Text("Input control").tag(ControllerProfile.Direction.send)
                    Text("LED feedback").tag(ControllerProfile.Direction.receive)
                }
                Picker("Layer", selection: $layer) {
                    Text("Red / base").tag(ControllerProfile.Layer.base)
                    Text("Amber").tag(ControllerProfile.Layer.amber)
                    Text("Green").tag(ControllerProfile.Layer.green)
                }.disabled(draft?.layerMode == "off")
            }
            switch resolution {
            case .unresolved(let message):
                Text(message).foregroundStyle(AppThemeV2.Colors.amber).fixedSize(horizontal: false, vertical: true)
            case .resolved(let results):
                ForEach(Array(results.enumerated()), id: \.offset) { _, binding in
                    HStack {
                        Text(binding.midi.displayName).font(.system(.body, design: .monospaced))
                        if let color = binding.color { Text(color.rawValue.capitalized) }
                        Spacer()
                        Text(binding.provenance == "manufacturer-documented" ? "Documented" : binding.provenance == "midi-learn" ? "MIDI Learn override" : "Local override")
                            .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                    }
                }
            }
            Text("\(matchingIDs.count) matching mappings").fontWeight(.semibold)
            if let device {
                let ids = Set(matchingIDs)
                ForEach(device.mappings.filter { ids.contains($0.id) }.prefix(6)) { row in
                    Text(rowSummary(row))
                        .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
                if matchingIDs.count > 6 { Text("Show Mappings opens all \(matchingIDs.count) matching rows.").font(.caption) }
            }
            overrideSection
            if let profile {
                let evidenceIDs = Set(bindings.flatMap(\.evidence))
                let sourceRecords = profile.evidence.filter { evidenceIDs.contains($0.id) }
                ForEach(sourceRecords, id: \.id) { evidence in
                    if let source = profile.sources.first(where: { $0.id == evidence.sourceID }), let url = URL(string: source.url) {
                        Link(evidence.locator, destination: url).font(.caption)
                    }
                }
                if direction == .receive {
                    Text("LED addresses identify colors; exact on/off velocity thresholds are not documented. Overrides specify an address, not a complete LED behavior.")
                        .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
            }
        }
    }

    private func rowSummary(_ row: MappingEntry) -> String {
        let conditions = [row.modifier1Condition?.displayString, row.modifier2Condition?.displayString]
            .compactMap { $0 }.joined(separator: ", ")
        return "\(row.commandName) · \(row.assignment.displayName) · \(row.ioType.rawValue) · \(conditions.isEmpty ? "No modifiers" : conditions)"
    }

    private var overrideSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Text("Local address override").fontWeight(.semibold)
            HStack {
                Picker("Message", selection: $manualKind) {
                    Text("CC").tag("controlChange"); Text("Note").tag("note")
                }.frame(width: 125)
                Picker("Channel", selection: $manualChannel) {
                    ForEach(1...16, id: \.self) { Text(String($0)).tag($0) }
                }.frame(width: 115)
                TextField("Number", value: $manualNumber, format: .number).frame(width: 55)
                    .accessibilityLabel("MIDI number")
                Button("Set") { storeManualOverride() }
                    .disabled(!(0...127).contains(manualNumber))
            }
            HStack {
                Button(lease == nil ? "MIDI Learn" : "Stop Learning") { lease == nil ? startLearning() : stopLearning() }
                    .disabled(direction == .receive)
                if let pendingMIDI {
                    Text(pendingMIDI.displayName).font(.system(.caption, design: .monospaced))
                    Button("Use Captured Address") { storeOverride(pendingMIDI, provenance: .midiLearn) }
                }
                Spacer()
                Button("Remove Override") { removeOverride() }
                    .disabled(!hasContextOverride)
            }
            Text(lease != nil ? "Move only this control. SXM listens to all connected MIDI inputs."
                 : "Overrides apply only to this control, map, mode, layer and direction. Mapping rows stay unchanged.")
                .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
        }.disabled(isLocked || controlID == nil || draft == nil)
    }

    private var hasContextOverride: Bool { draft?.overrides.contains(where: matchesContext) ?? false }
    private func matchesContext(_ value: ControllerControlOverride) -> Bool {
        value.controlID == controlID && value.unitMap == draft?.unitMap && value.layerMode == draft?.layerMode
            && value.layer == lookupLayer && value.direction == direction
    }
    private func chooseProfile(_ id: String) {
        if id.isEmpty { draft = nil; return }
        guard let p = library?.profiles.first(where: { $0.id == id }) else { return }
        guard draft?.profileID != p.id || draft?.version != p.version else { return }
        draft = ControllerConfiguration(profileID: p.id, version: p.version, globalChannel: p.defaultChannel,
                                        layerMode: "off", unitMap: "factory")
        controlID = "fader.1"
    }
    private func resetCapture() {
        stopLearning()
        pendingMIDI = nil
        errorMessage = nil
        if let midi = bindings.first?.midi {
            manualChannel = midi.channel; manualNumber = midi.number ?? 0
            manualKind = midi.kind == .note ? "note" : "controlChange"
        } else { manualChannel = draft?.globalChannel ?? 15 }
    }
    private func startLearning() {
        guard !isLocked, direction == .send, controlID != nil, draft != nil else { return }
        pendingMIDI = nil
        guard let acquired = midiManager.acquireListeningLease(onMIDIReceived: { message in
            guard let lease, midiManager.ownsListeningLease(lease), let assignment = MIDIAssignment(learnMessage: message) else { return }
            pendingMIDI = assignment
            stopLearning()
        }) else {
            errorMessage = "MIDI Learn could not start. Stop other learning sessions and check that a MIDI input is connected."
            return
        }
        lease = acquired
    }
    private func stopLearning() {
        let owned = lease
        lease = nil
        if let owned { midiManager.releaseListeningLease(owned) }
    }
    private func storeManualOverride() {
        do {
            let midi = try MIDIAssignment(validatingChannel: manualChannel,
                                          note: manualKind == "note" ? manualNumber : nil,
                                          cc: manualKind == "controlChange" ? manualNumber : nil)
            storeOverride(midi, provenance: .userSupplied)
        } catch { errorMessage = error.localizedDescription }
    }
    private func storeOverride(_ midi: MIDIAssignment, provenance: ControllerControlOverride.Provenance) {
        guard var configuration = draft, let controlID else { return }
        do {
            try ControllerProfileWorkflow.setOverride(controlID: controlID, layer: lookupLayer, direction: direction,
                                                       midi: midi, provenance: provenance, in: &configuration)
            draft = configuration
            pendingMIDI = nil
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    private func removeOverride() {
        guard var configuration = draft else { return }
        configuration.overrides = configuration.overrides.filter { !matchesContext($0) }
        draft = configuration
    }
    private func apply(showMappings: Bool) {
        do {
            if changed {
                try document.performUndoableMutation(actionName: "Controller Profile", undoManager: undoManager) { file in
                    try ControllerProfileWorkflow.apply(configuration: draft, deviceID: deviceID,
                        expectedMetadata: initialMetadata, isLocked: isLocked, to: &file)
                }
            }
            if showMappings { onShowMappings(Set(matchingIDs)) }
            stopLearning()
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
