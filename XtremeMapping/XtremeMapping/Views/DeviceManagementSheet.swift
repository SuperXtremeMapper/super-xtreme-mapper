import SwiftUI
import AppKit

struct DeviceManagementSheet: View {
    @ObservedObject var document: TraktorMappingDocument
    @Binding var selectedIDs: Set<UUID>
    let isLocked: Bool
    let undoManager: UndoManager?
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var midiManager = MIDIInputManager.shared
    @State private var showController = false
    @State private var sourceID: Int32?
    @State private var comment = ""
    @State private var inPort = ""
    @State private var outPort = ""
    @State private var loadedDevice: Device?
    @State private var transferDestination: UUID?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var confirmDeletion = false
    @State private var pendingDeletion: Device?

    private var device: Device? {
        document.mappingFile.devices.first { $0.id == document.activeDeviceID }
    }
    private var sourceSelection: Set<UUID> {
        guard let device else { return [] }
        let live = Set(device.mappings.map(\.id))
        return selectedIDs.isSubset(of: live) ? selectedIDs : []
    }
    private var draftIsStale: Bool { loadedDevice != device }
    private var hasChanges: Bool {
        guard let device else { return false }
        return sourceID != document.midiSourceIDs[device.id] || comment != device.comment || inPort != device.inPort || outPort != device.outPort
    }
    private var transferOverlapCount: Int {
        guard let device,
              let target = document.mappingFile.devices.first(where: { $0.id == transferDestination }) else { return 0 }
        return device.mappings.filter { row in
            sourceSelection.contains(row.id) && row.midiAssignment.kind != .unassigned && target.mappings.contains {
                $0.ioType == row.ioType && $0.midiAssignment == row.midiAssignment
            }
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                V2SectionHeader(title: "DEVICE SETTINGS")
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            V2FormRow(label: "Device") {
                V2Dropdown(options: [UUID?.none] + document.mappingFile.devices.map { Optional($0.id) }, selection: $document.activeDeviceID) { id in
                    document.mappingFile.devices.first { $0.id == id }?.displayName ?? "Choose device…"
                }.buttonStyle(.plain)
            }
            HStack {
                Button("Add device") { add() }.disabled(isLocked)
                Button("Duplicate device") { duplicate() }.disabled(isLocked || device == nil)
                Button("Delete device…", role: .destructive) { pendingDeletion = device; confirmDeletion = true }
                    .disabled(isLocked || device == nil)
            }
            if let device {
                VStack(spacing: 8) {
                    V2FormRow(label: "Controller") {
                        Text(controllerName).font(AppThemeV2.Typography.body).lineLimit(1)
                        Button(controllerName == "Generic MIDI" ? "Choose…" : "Change…") { showController = true }
                            .accessibilityLabel("Choose or change controller")
                    }
                    V2FormRow(label: "Label") { V2TextField(placeholder: "Device label", text: $comment) }
                    V2FormRow(label: "Device type") { Text(device.name) }
                    V2FormRow(label: "Live input") {
                        V2Dropdown(options: sourceOptions, selection: $sourceID) { id in
                            guard let id else { return "Use saved port name" }
                            return midiManager.availableSources.first { $0.uniqueID == id }.map { "\($0.displayName) (\(id))" } ?? "Disconnected (\(id))"
                        }.buttonStyle(.plain)
                    }
                    .onChange(of: sourceID) { _, id in
                        if let id, let source = midiManager.availableSources.first(where: { $0.uniqueID == id }) {
                            inPort = source.name
                        }
                    }
                    V2FormRow(label: "Input port") { V2TextField(placeholder: "MIDI input port", text: $inPort) }
                        .onChange(of: inPort) { _, port in
                            if let sourceID,
                               let source = midiManager.availableSources.first(where: { $0.uniqueID == sourceID }),
                               source.name != port {
                                self.sourceID = nil
                            }
                        }
                    V2FormRow(label: "Output port") { V2TextField(placeholder: "MIDI output port", text: $outPort) }
                }.disabled(isLocked)
                Text("Choose a connected input for this session, or enter port names to prepare mappings offline. The saved TSI uses port names; identical names need routing checked in Traktor.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Save device settings") { save() }
                        .disabled(isLocked || draftIsStale || !hasChanges)
                    if draftIsStale {
                        Button("Reload changed device") { load() }
                        Text("This device changed. Reload before saving.").font(.caption)
                    }
                    Spacer()
                    Button("Export this device…") { exportDevice(device.id) }
                }
                V2Divider()
                Text("Transfer selected mappings").font(.subheadline.bold())
                Text("\(sourceSelection.count) mappings from \(device.displayName)").font(.caption)
                V2FormRow(label: "Destination") {
                    V2Dropdown(options: [UUID?.none] + document.mappingFile.devices.filter { $0.id != device.id }.map { Optional($0.id) }, selection: $transferDestination) { id in
                        document.mappingFile.devices.first { $0.id == id }?.displayName ?? "Choose device…"
                    }.buttonStyle(.plain)
                }
                if transferOverlapCount > 0 {
                    Text("\(transferOverlapCount) selected mappings share MIDI addresses with destination mappings. Both will be kept.")
                        .font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Button("Copy mappings") { transfer(.copy) }
                    Button("Move mappings") { transfer(.move) }
                }.disabled(isLocked || sourceSelection.isEmpty || transferDestination == nil)
            } else {
                Text("Add a device to give a controller its own mappings, ports, and profile.")
                    .foregroundStyle(.secondary)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).textSelection(.enabled) }
            if let statusMessage { Text(statusMessage).font(.caption).foregroundStyle(.secondary) }
        }
        .font(AppThemeV2.Typography.body)
        .foregroundStyle(AppThemeV2.Colors.stone200)
        .buttonStyle(AssistantButtonStyle())
        .tint(AppThemeV2.Colors.amber)
        .padding(24).frame(width: 600)
        .sheet(isPresented: $showController) {
            if let device {
                ControllerProfileSheet(document: document, deviceID: device.id, isLocked: isLocked, undoManager: undoManager)
            }
        }
        .background(AppThemeV2.Colors.stone800).preferredColorScheme(.dark)
        .onAppear {
            if document.activeDeviceID == nil {
                document.activeDeviceID = try? document.mappingDestination(selectedIDs: selectedIDs)
            }
            load()
        }
        .onChange(of: document.activeDeviceID) { _, _ in load() }
        .confirmationDialog("Delete \(pendingDeletion?.displayName ?? "this device") and its \(pendingDeletion?.mappings.count ?? 0) mappings?", isPresented: $confirmDeletion) {
            Button("Delete device", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) { }
        } message: { Text("You can restore the device with Undo.") }
    }

    private var sourceOptions: [Int32?] {
        var ids = midiManager.availableSources.compactMap(\.uniqueID).map(Optional.some)
        if let sourceID, !ids.contains(sourceID) { ids.append(sourceID) }
        return [nil] + ids
    }

    private static let profileLibrary = try? ControllerProfileLibrary()

    private var controllerName: String {
        guard let device,
              let saved = document.mappingFile.interchangeMetadata?.deviceProfiles?.first(where: { $0.deviceID == device.id }) else { return "Generic MIDI" }
        return (try? Self.profileLibrary?.profile(id: saved.configuration.profileID, version: saved.configuration.version))?.model ?? "Saved controller profile"
    }

    private func load() {
        loadedDevice = device
        sourceID = device.flatMap { document.midiSourceIDs[$0.id] }
        comment = device?.comment ?? ""
        inPort = device?.inPort ?? ""; outPort = device?.outPort ?? ""
        transferDestination = nil; errorMessage = nil
    }
    private func perform(_ action: String, mutation: (inout MappingFile) throws -> Void) {
        guard !isLocked else { return }
        do {
            try document.performUndoableMutation(actionName: action, undoManager: undoManager, mutation)
            errorMessage = nil
            load()
        } catch { errorMessage = error.localizedDescription }
    }
    private func add() {
        var created: UUID?
        perform("Add Device") { file in
            created = try DeviceManagementService.addDevice(name: "Generic MIDI", comment: "MIDI Device \(file.devices.count + 1)", to: &file)
        }
        if let created { document.activeDeviceID = created; load() }
    }
    private func save() {
        guard let device, !draftIsStale else { return }
        let selectedSourceID = sourceID
        perform("Edit Device") { file in
            try DeviceManagementService.updateDevice(device.id, name: device.name, comment: comment, inPort: inPort, outPort: outPort, in: &file)
        }
        if errorMessage == nil {
            document.midiSourceIDs[device.id] = selectedSourceID
            load()
        }
    }
    private func duplicate() {
        guard let device else { return }
        var created: UUID?
        perform("Duplicate Device") { file in
            created = try DeviceManagementService.duplicateDevice(device.id, in: &file).deviceID
        }
        if let created { document.activeDeviceID = created; load() }
    }
    private func delete() {
        guard let pending = pendingDeletion else { return }
        pendingDeletion = nil
        guard document.mappingFile.devices.first(where: { $0.id == pending.id }) == pending else {
            errorMessage = "The device changed while confirmation was open. Review it and try again."
            return
        }
        perform("Delete Device") { file in try DeviceManagementService.deleteDevice(pending.id, in: &file) }
    }
    private func transfer(_ mode: DeviceMappingTransferMode) {
        guard let device, let destination = transferDestination, !sourceSelection.isEmpty else { return }
        let ids = sourceSelection
        var result: DeviceManagementResult?
        perform(mode == .copy ? "Copy Mappings to Device" : "Move Mappings to Device") { file in
            result = try DeviceManagementService.transferMappings(ids, from: device.id, to: destination, mode: mode, in: &file)
        }
        if let result {
            statusMessage = "\(result.mappingIDs.count) mappings \(mode == .copy ? "copied" : "moved")."
            selectedIDs = mode == .copy ? ids : []
        }
    }
    private func exportDevice(_ id: UUID) {
        do {
            let file = try DeviceManagementService.selectedDeviceExport(id, from: document.mappingFile)
            let revision = document.explanationRevision
            let writer = TSIWriter()
            let plan = try writer.makeConvertedWritePlan(for: file)
            var risks = writer.preservationReport(for: document.mappingFile).risks
            risks.append(contentsOf: plan.report.risks.filter { !risks.contains($0) })
            if !risks.isEmpty {
                let warning = NSAlert()
                warning.alertStyle = .warning
                warning.messageText = "Export a converted device copy?"
                warning.informativeText = TSIExportRiskPresenter.warningText(for: risks)
                warning.addButton(withTitle: "Choose Destination…")
                warning.addButton(withTitle: "Cancel")
                guard warning.runModal() == .alertFirstButtonReturn else { return }
            }
            let panel = NSSavePanel()
            panel.title = "Export Mapping Device"
            panel.allowedContentTypes = [.tsi]
            panel.nameFieldStringValue = "\(device?.displayName ?? "Device").tsi"
            panel.message = "Export this device as a separate TSI file."
            guard panel.runModal() == .OK, let url = panel.url else { return }
            guard document.explanationRevision == revision else {
                errorMessage = "The mapping changed. Review the device and export again."
                return
            }
            try TSIExportDestinationValidator.validateNewDestination(source: document.fileURL, destination: url)
            try TSIExclusiveAtomicWriter.publish(plan.output, to: url)
            statusMessage = "Exported \(url.lastPathComponent)."
        } catch { errorMessage = error.localizedDescription }
    }
}
