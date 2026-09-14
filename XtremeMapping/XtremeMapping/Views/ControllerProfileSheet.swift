import SwiftUI

/// A device-scoped draft. Selection, lookup and MIDI capture never mutate the open document.
struct ControllerProfileSheet: View {
    /// The sheet leads with a clean "which controller?" step; the dense inspector
    /// (modes, unit map, port, control list, overrides, MIDI Learn, export) lives
    /// behind Advanced.
    enum Mode { case identify, advanced }

    @ObservedObject var document: TraktorMappingDocument
    /// The device is selected in XXDEVICES before this chooser opens.
    let deviceID: UUID
    let isLocked: Bool
    let undoManager: UndoManager?
    let onShowMappings: (Set<UUID>) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var midiManager = MIDIInputManager.shared
    @State private var mode: Mode = .identify
    @State private var initialMetadata: SXMJSONMetadata?
    @State private var draft: ControllerConfiguration?
    @State private var controlID: String?
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
    private var lookupLayer: ControllerProfile.Layer { profile?.schemaVersion == 2 || draft?.layerMode == "off" ? .base : layer }
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
         draft?.unitMap ?? "", draft?.portID ?? "", draft?.feedbackMode ?? "", controlID ?? "", lookupLayer.rawValue, direction.rawValue].joined(separator: "|")
    }
    private var visibleControls: [ControllerProfile.Control] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return (profile?.controls ?? []).filter { c in
            let matchesConfiguration = profile?.schemaVersion != 2 || c.bindings.contains { binding in
                binding.direction == direction
                    && (binding.modeID == nil || binding.modeID == draft?.layerMode)
                    && (binding.portID == nil || draft?.portID == nil || binding.portID == draft?.portID)
            }
            return matchesConfiguration && (needle.isEmpty || ([c.name, c.id, c.group] + c.aliases).contains { $0.localizedCaseInsensitiveContains(needle) })
        }
    }
    /// Library profiles grouped and sorted by manufacturer, models sorted
    /// within each group, so the selector is ordered and disambiguated.
    private var groupedProfiles: [(manufacturer: String, profiles: [ControllerProfile])] {
        let all = library?.profiles ?? []
        return Dictionary(grouping: all, by: { $0.manufacturer })
            .map { (manufacturer: $0.key, profiles: $0.value.sorted { $0.model < $1.model }) }
            .sorted { $0.manufacturer < $1.manufacturer }
    }
    private func setting<T>(_ keyPath: WritableKeyPath<ControllerConfiguration, T>, fallback: T) -> Binding<T> {
        Binding(get: { draft?[keyPath: keyPath] ?? fallback }, set: { draft?[keyPath: keyPath] = $0 })
    }

    var body: some View {
        Group {
            if mode == .identify { identifyStep } else { advancedContent }
        }
        .font(AppThemeV2.Typography.body)
        .padding(AppThemeV2.Spacing.lg)
        .frame(width: 760)
        .background(AppThemeV2.Colors.stone800)
        .foregroundStyle(AppThemeV2.Colors.stone200)
        .tint(AppThemeV2.Colors.amber)
        .onAppear { document.activeDeviceID = deviceID }
        .onChange(of: contextKey) { _, _ in resetCapture() }
        .onChange(of: draft?.layerMode) { _, _ in selectFirstVisibleControlIfNeeded() }
        .onChange(of: draft?.portID) { _, _ in selectFirstVisibleControlIfNeeded() }
        .onChange(of: direction) { _, _ in selectFirstVisibleControlIfNeeded() }
        .onChange(of: document.midiSourceIDs) { _, _ in resetCapture() }
        .onChange(of: document.mappingFile.devices.map { "\($0.id):\($0.inPort)" }) { _, _ in resetCapture() }
        .onChange(of: midiManager.activeListeningLease) { _, current in
            if let lease, current != lease { self.lease = nil; pendingMIDI = nil }
        }
        .onDisappear { stopLearning() }
        .onAppear {
            if controlID == nil { controlID = profile?.controls.first?.id }
            selectFirstVisibleControlIfNeeded()
            resetCapture()
        }
    }

    // MARK: - Identify step

    /// The clean "which controller is this?" front. V2 components only — no
    /// native Picker/TextField.
    private var identifyStep: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            identifyHeader
            V2Divider()
            V2SearchField(text: $query, placeholder: "Search brand or model…")
            identifyResults
            V2Divider()
            confirmStrip
            Text("Settings describe your hardware; they never change your mapping.")
                .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone500)
            if let message = errorMessage ?? libraryError {
                Text(message).foregroundStyle(AppThemeV2.Colors.danger).fixedSize(horizontal: false, vertical: true)
            }
            if stale { Text("The document changed. Close this sheet and reopen it before applying settings.").foregroundStyle(AppThemeV2.Colors.amber) }
            if isLocked { Text("Editing is locked. Saved profiles can still be inspected.").foregroundStyle(AppThemeV2.Colors.amber) }
            identifyFooter
        }
    }

    private var identifyHeader: some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("WHICH CONTROLLER IS THIS?")
                    .font(AppThemeV2.Typography.sectionHeader).tracking(0.5)
                    .foregroundStyle(AppThemeV2.Colors.stone100)
                Spacer()
                Text(device?.displayName ?? "Device no longer available")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                    .lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: 240, alignment: .trailing)
            }
            Text("Name your hardware so SXM can show each mapping's physical control. This never changes your mapping.")
                .font(AppThemeV2.Typography.caption)
                .foregroundStyle(AppThemeV2.Colors.stone400)
        }
    }

    private var identifyResults: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppThemeV2.Spacing.md) {
                ForEach(filteredIdentifyGroups, id: \.manufacturer) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        AssistantSectionLabel(group.manufacturer)
                        ForEach(group.profiles, id: \.id) { p in
                            IdentifyControllerRow(profile: p, selected: draft?.profileID == p.id,
                                                  disabled: isLocked, action: { chooseProfile(p.id) })
                        }
                    }
                }
                if filteredIdentifyGroups.isEmpty {
                    Text(library == nil ? "The controller library could not be loaded."
                         : "No controllers match “\(query)”.")
                        .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone500)
                        .padding(.vertical, 8)
                }
            }
            .padding(AppThemeV2.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 300)
        .background(AppThemeV2.Colors.stone800)
        .clipShape(RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppThemeV2.Radius.lg)
            .stroke(AppThemeV2.Colors.stone700, lineWidth: 1))
    }


    private var confirmStrip: some View {
        HStack(spacing: AppThemeV2.Spacing.md) {
            if let profile {
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.model).font(AppThemeV2.Typography.body).foregroundStyle(AppThemeV2.Colors.stone100)
                    Text(ControllerProfileCoverage.label(of: profile))
                        .font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
                Spacer()
                if profile.coverageState != .documentationOnly {
                    HStack(spacing: AppThemeV2.Spacing.xs) {
                        Text("MIDI channel").font(AppThemeV2.Typography.caption).foregroundStyle(AppThemeV2.Colors.stone500)
                        V2Dropdown(options: Array(1...16), selection: setting(\.globalChannel, fallback: 15), labelFor: { String($0) })
                            .frame(width: 90)
                            .disabled(isLocked)
                    }
                }
            } else {
                Text("Choose a controller above to confirm it.")
                    .foregroundStyle(AppThemeV2.Colors.stone500)
                Spacer()
            }
        }
    }

    private var confirmDisabled: Bool { draft == nil || !changed || isLocked || stale || library == nil }

    private var identifyFooter: some View {
        HStack(spacing: AppThemeV2.Spacing.sm) {
            V2ToolbarButton(label: "Advanced…", action: { mode = .advanced })
            Spacer()
            V2ToolbarButton(label: draft == nil ? "Keep generic MIDI" : "Cancel", action: { stopLearning(); dismiss() })
            V2ToolbarButton(label: "Confirm controller", action: { apply(showMappings: false) }, isPrimary: true)
                .disabled(confirmDisabled)
                .opacity(confirmDisabled ? 0.45 : 1)
        }
    }

    /// Grouped library filtered by the search query (matches manufacturer or model).
    private var filteredIdentifyGroups: [(manufacturer: String, profiles: [ControllerProfile])] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return groupedProfiles }
        return groupedProfiles.compactMap { group in
            let matches = group.profiles.filter {
                $0.model.localizedCaseInsensitiveContains(needle)
                    || group.manufacturer.localizedCaseInsensitiveContains(needle)
            }
            return matches.isEmpty ? nil : (manufacturer: group.manufacturer, profiles: matches)
        }
    }

    // MARK: - Advanced (existing dense inspector, unchanged)

    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Button("‹ Identify") { mode = .identify }
                    .buttonStyle(AssistantButtonStyle())
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
                    if profile?.coverageState == .documentationOnly {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Control addresses are not established yet.").font(.headline)
                            Text("You can save this device's documentation reference, but SXM cannot identify its physical controls from these sources.")
                            Text("To map it now, close this panel, select a mapping row and use Learn in its MIDI settings. Add a comment naming the control. No controller profile is required for MIDI Learn.")
                            Text("Open Profile coverage and limitations above for documented setup instructions and the information still needed.")
                            ForEach(Array((profile?.sources ?? []).enumerated()), id: \.offset) { index, source in
                                if let url = URL(string: source.url) {
                                    Link("Manufacturer document \(index + 1)", destination: url)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        controlList.frame(width: 235)
                        Divider()
                        ScrollView { controlDetails.frame(maxWidth: .infinity, alignment: .leading) }
                    }
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
    }

    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Controller", selection: Binding(get: { draft?.profileID ?? "" }, set: chooseProfile)) {
                    Text("No profile").tag("")
                    // Grouped by manufacturer so 47 models read as an ordered,
                    // disambiguated list rather than one undifferentiated menu.
                    ForEach(groupedProfiles, id: \.manufacturer) { group in
                        Section(group.manufacturer) {
                            ForEach(group.profiles, id: \.id) { p in
                                Text(p.model + (p.coverageState == nil ? "" : " — " + ControllerProfileCoverage.label(of: p))).tag(p.id)
                            }
                        }
                    }
                    if let draft, !(library?.profiles.contains { $0.id == draft.profileID } ?? false) {
                        Text("Unavailable: \(draft.profileID)").tag(draft.profileID)
                    }
                }.frame(width: 265)
                if draft != nil {
                    if profile?.coverageState != .documentationOnly {
                    Picker("MIDI channel", selection: setting(\.globalChannel, fallback: 15)) {
                        ForEach(1...16, id: \.self) { Text(String($0)).tag($0) }
                    }.frame(width: 170)
                    }
                    Spacer()
                    Label(profile.map { ControllerProfileCoverage.label(of: $0) } ?? "Manufacturer documented", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
            }.disabled(isLocked)
            if let profile {
                if profile.coverageState != .documentationOnly {
                HStack {
                    Picker(profile.schemaVersion == 2 ? "Operating mode" : "Layer mode", selection: setting(\.layerMode, fallback: "off")) {
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
                if let ports = profile.ports, !ports.isEmpty {
                    Picker("Confirm MIDI port", selection: setting(\.portID, fallback: nil)) {
                        Text("Select the port used by this device").tag(String?.none)
                        ForEach(ports, id: \.id) { port in Text(port.name).tag(Optional(port.id)) }
                        if let port = draft?.portID, !ports.contains(where: { $0.id == port }) {
                            Text("Unavailable: \(port)").tag(Optional(port))
                        }
                    }.disabled(isLocked)
                }
                if profile.schemaVersion == 2 && profile.coverageState != .documentationOnly {
                    Text("The configured channel applies only to addresses without a fixed channel. Confirm the starting channel, port and operating mode against your hardware.")
                        .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
                Text(ControllerProfileCoverage.summary(of: profile))
                    .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                DisclosureGroup("Profile coverage and limitations") {
                    ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Address lookup finds existing mappings. It does not generate lighting, encoder behavior, or device initialization.")
                        ForEach(Array((profile.coverageNotes ?? []).enumerated()), id: \.offset) { _, note in Text(note) }
                        ForEach(Array(profile.limitations.enumerated()), id: \.offset) { _, limitation in Text(limitation.message) }
                    }.font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(maxHeight: 130)
                }
            }
        }
    }

    private var controlList: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Find a control", text: $query).textFieldStyle(.roundedBorder)
            List(selection: $controlID) {
                ForEach(visibleControls, id: \.id) { control in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(control.name)
                        Text(control.group).font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                    }.tag(control.id).help(control.id)
                }
            }.listStyle(.plain).scrollContentBackground(.hidden)
            Text("\(visibleControls.count) of \(profile?.controls.count ?? 0) control variants").font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
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
                if profile?.schemaVersion != 2 {
                Picker("Layer", selection: $layer) {
                    Text("Red / base").tag(ControllerProfile.Layer.base)
                    Text("Amber").tag(ControllerProfile.Layer.amber)
                    Text("Green").tag(ControllerProfile.Layer.green)
                }.disabled(draft?.layerMode == "off")
                }
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
            documentedBindingDetails
            overrideSection
            if let profile {
                let evidenceIDs = Set(bindings.flatMap(\.evidence) + selectedDocumentedBindings.flatMap(\.evidence))
                let sourceRecords = profile.evidence.filter { evidenceIDs.contains($0.id) }
                ForEach(sourceRecords, id: \.id) { evidence in
                    if let source = profile.sources.first(where: { $0.id == evidence.sourceID }), let url = URL(string: source.url) {
                        Link(evidence.locator, destination: url).font(.caption)
                    }
                }
                if direction == .receive && profile.schemaVersion == 1 {
                    Text("LED addresses identify colors; exact on/off velocity thresholds are not documented. Overrides specify an address, not a complete LED behavior.")
                        .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
                }
            }
        }
    }

    private var selectedDocumentedBindings: [ControllerProfile.Binding] {
        guard let profile, let control = profile.controls.first(where: { $0.id == controlID }) else { return [] }
        if profile.schemaVersion == 1 {
            return ControllerProfileCoverage.resolvedManufacturerBindings(in: control, resolution: resolution)
        }
        return control.bindings.filter {
            $0.direction == direction && ($0.modeID == nil || $0.modeID == draft?.layerMode)
                && ($0.portID == nil || draft?.portID == nil || $0.portID == draft?.portID)
        }
    }

    private var documentedBindingDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(selectedDocumentedBindings.enumerated()), id: \.offset) { _, binding in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(ControllerProfileCoverage.availability(of: binding).rawValue): \(ControllerProfileCoverage.messageDescription(of: binding))")
                        .fontWeight(.medium)
                    Text(ControllerProfileCoverage.channelDescription(of: binding)).font(.caption)
                    if let context = binding.context { Text(context).font(.caption) }
                    if let mode = binding.modeID { Text("Operating mode: \(profile?.modes.first { $0.id == mode }?.name ?? mode)").font(.caption) }
                    if let port = binding.portID { Text("Port: \(profile?.ports?.first { $0.id == port }?.name ?? port)").font(.caption) }
                    if ControllerProfileCoverage.availability(of: binding) == .documentedOnly {
                        Text("This message cannot be used for generic Note/CC address lookup. A local override records a separate single address; it does not implement this message.")
                            .font(.caption).foregroundStyle(AppThemeV2.Colors.amber)
                    }
                    if !binding.notes.isEmpty || binding.semantics != nil || binding.components != nil {
                        DisclosureGroup("Documented values and message details") {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(binding.notes.enumerated()), id: \.offset) { _, note in Text(note) }
                                if let components = binding.components {
                                    ForEach(Array(components.enumerated()), id: \.offset) { _, component in
                                        Text("\(component.role): \(component.kind.rawValue) \(component.number)")
                                    }
                                }
                                if let semantics = binding.semantics { Text(semantics).textSelection(.enabled) }
                            }.font(.caption)
                        }
                    }
                }.foregroundStyle(AppThemeV2.Colors.stone400)
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
            Text(lease != nil ? "Move only this control on the input assigned to this device."
                 : "Overrides apply only to this control, port, map, mode, layer and direction. Mapping rows stay unchanged.")
                .font(.caption).foregroundStyle(AppThemeV2.Colors.stone400)
        }.disabled(isLocked || controlID == nil || draft == nil)
    }

    private var hasContextOverride: Bool { draft?.overrides.contains(where: matchesContext) ?? false }
    private func matchesContext(_ value: ControllerControlOverride) -> Bool {
        value.controlID == controlID && value.unitMap == draft?.unitMap && value.layerMode == draft?.layerMode
            && value.layer == lookupLayer && value.direction == direction && value.portID == draft?.portID
    }
    private func chooseProfile(_ id: String) {
        if id.isEmpty { draft = nil; return }
        guard let p = library?.profiles.first(where: { $0.id == id }) else { return }
        guard draft?.profileID != p.id || draft?.version != p.version else { return }
        // Default the channel to the one THIS mapping's rows actually use so the
        // physical names resolve; fall back to the profile's documented default
        // when there are no addressable rows to learn from.
        let channels = (device?.mappings ?? []).compactMap {
            $0.midiAssignment.kind == .unassigned ? nil : $0.midiAssignment.channel
        }
        let detectedChannel = channels.isEmpty ? p.defaultChannel
            : Dictionary(grouping: channels, by: { $0 }).max { $0.value.count < $1.value.count }!.key
        draft = ControllerConfiguration(profileID: p.id, version: p.version, globalChannel: detectedChannel,
                                        layerMode: p.modes.first?.id ?? "off", unitMap: p.unitMaps.first?.id ?? "factory")
        // Many profiles are fully port-scoped; resolve() drops port-scoped bindings when
        // portID is nil. Default to the first documented port so the confirmed
        // configuration resolves. The Advanced panel still lets the user change the port.
        if let firstPort = p.ports?.first, draft?.portID == nil {
            draft?.portID = firstPort.id
        }
        controlID = p.controls.first?.id
        query = ""
        layer = .base
        direction = p.controls.first?.bindings.first?.direction ?? .send
    }
    private func selectFirstVisibleControlIfNeeded() {
        guard profile?.schemaVersion == 2 else { return }
        if !visibleControls.contains(where: { $0.id == controlID }) { controlID = visibleControls.first?.id }
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
        guard let acquired = midiManager.acquireListeningLease(desiredInputPort: device?.inPort, requireSpecificSource: document.mappingFile.devices.count > 1, desiredSourceID: document.midiSourceIDs[deviceID], onMIDIReceived: { message in
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

/// A selectable model row using the app's selection idiom — amber fill + left
/// accent bar + amber text + checkmark when chosen, a stone hover otherwise.
/// Never a native radio control.
private struct IdentifyControllerRow: View {
    let profile: ControllerProfile
    let selected: Bool
    let disabled: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: AppThemeV2.Spacing.sm) {
                Text(profile.model).font(AppThemeV2.Typography.body)
                    .foregroundStyle(selected ? AppThemeV2.Colors.amberLight : AppThemeV2.Colors.stone200)
                Spacer(minLength: 8)
                coverageChip
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppThemeV2.Colors.amber)
                    .opacity(selected ? 1 : 0)
                    .frame(width: 12)
            }
            .padding(.horizontal, AppThemeV2.Spacing.sm)
            .frame(height: 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? AppThemeV2.Colors.amberSubtle
                        : (hovered ? AppThemeV2.Colors.stone700 : Color.clear))
            .overlay(alignment: .leading) {
                Rectangle().fill(AppThemeV2.Colors.amber)
                    .frame(width: 2.5).opacity(selected ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppThemeV2.Radius.sm))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.12)) { hovered = hovering } }
    }

    private var coveragePair: (label: String, color: Color) {
        switch profile.coverageState {
        case .partial: return ("PARTIAL", AppThemeV2.Colors.warning)
        case .documentationOnly: return ("DOCS ONLY", AppThemeV2.Colors.stone500)
        case nil: return ("FULL MIDI", AppThemeV2.Colors.success)
        }
    }

    private var coverageChip: some View {
        Text(coveragePair.label).font(AppThemeV2.Typography.micro).tracking(0.4)
            .foregroundStyle(coveragePair.color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(coveragePair.color.opacity(0.12)))
    }
}
