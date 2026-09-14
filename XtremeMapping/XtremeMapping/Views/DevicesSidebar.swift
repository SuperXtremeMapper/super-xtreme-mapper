import SwiftUI

/// Navigation and controller identity share one entry point; editing remains device-scoped.
struct DevicesSidebar: View {
    private enum Selection: Hashable {
        case all
        case device(UUID)
    }

    @ObservedObject var document: TraktorMappingDocument
    @ObservedObject private var midiManager = MIDIInputManager.shared
    let profileNames: [UUID: String]
    let isLocked: Bool
    let onClose: () -> Void
    let onAdd: () -> Void
    let onChooseController: (UUID) -> Void
    let onSettings: (UUID) -> Void

    private var selection: Binding<Selection?> {
        Binding(get: { document.activeDeviceID.map(Selection.device) ?? .all }, set: { value in
            switch value {
            case .all: DeviceSidebarActions.selectDevice(nil, in: document)
            case .device(let id): DeviceSidebarActions.selectDevice(id, in: document)
            case nil: break
            }
        })
    }

    private var selectedDevice: Device? {
        document.mappingFile.devices.first { $0.id == document.activeDeviceID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppThemeV2.Spacing.sm) {
                V2SectionHeader(title: "DEVICES")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("XXDEVICES")
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppThemeV2.Colors.stone400)
                .help("Hide devices")
                .accessibilityLabel("Hide devices")
            }
            .padding(.horizontal, AppThemeV2.Spacing.md)
            .frame(height: AppThemeV2.Components.sectionHeaderHeight)
            V2Divider()

            List(selection: selection) {
                HStack(spacing: AppThemeV2.Spacing.sm) {
                    Image(systemName: "square.stack.3d.up")
                        .foregroundStyle(AppThemeV2.Colors.stone400)
                    Text("All devices")
                    Spacer(minLength: 4)
                    Text("\(document.mappingFile.allMappings.count)")
                        .monospacedDigit().foregroundStyle(AppThemeV2.Colors.stone400)
                }
                .padding(.vertical, AppThemeV2.Spacing.xs)
                .tag(Selection.all)
                .accessibilityLabel("All devices, \(document.mappingFile.allMappings.count) mappings")

                ForEach(document.mappingFile.devices) { device in
                    deviceRow(device)
                        .tag(Selection.device(device.id))
                        .contextMenu {
                            Button(profileNames[device.id] == nil ? "Choose controller…" : "Change controller…") {
                                onChooseController(device.id)
                            }
                            Button("Device settings…") { onSettings(device.id) }
                        }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .tint(AppThemeV2.Colors.amber)
            .font(AppThemeV2.Typography.body)
            .accessibilityLabel("Mapping devices")
            // Device deletion is reviewed in settings. Delete must not reach
            // selected mapping rows while this navigation list has focus.
            .onDeleteCommand { }

            if document.mappingFile.devices.isEmpty {
                Text("Add a device, then choose its controller or keep a generic MIDI setup.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                    .padding(AppThemeV2.Spacing.md)
            }

            if let device = selectedDevice {
                selectedDeviceActions(device)
            } else if !document.mappingFile.devices.isEmpty {
                Text("Select a device to set up its controller and MIDI ports.")
                    .font(AppThemeV2.Typography.caption)
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                    .padding(AppThemeV2.Spacing.md)
            }

            V2Divider()
            Button(action: onAdd) {
                Label("Add device", systemImage: "plus")
                    .font(AppThemeV2.Typography.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(isLocked ? AppThemeV2.Colors.stone500 : AppThemeV2.Colors.amber)
            .padding(.horizontal, AppThemeV2.Spacing.md)
            .disabled(isLocked)
            .help("Create a device and choose its controller")
        }
        .background(AppThemeV2.Colors.stone900)
        .accessibilityIdentifier("devices-sidebar")
    }

    private func deviceRow(_ device: Device) -> some View {
        let profileName = profileNames[device.id]
        let status = DeviceSidebarPresentation.inputStatus(device: device,
            sourceID: document.midiSourceIDs[device.id], sources: midiManager.availableSources)
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(device.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 0)
                Text("\(device.mappings.count)")
                    .monospacedDigit().foregroundStyle(AppThemeV2.Colors.stone400)
            }
            Text(profileName ?? "No controller selected")
                .font(AppThemeV2.Typography.caption)
                .foregroundStyle(AppThemeV2.Colors.stone400)
                .lineLimit(1)
            Text(status)
                .font(AppThemeV2.Typography.micro)
                .foregroundStyle(AppThemeV2.Colors.stone500)
        }
        .padding(.vertical, 5)
        .help("\(device.displayName)\n\(profileName ?? "Choose a controller")\n\(device.inPort.isEmpty ? "Input not set" : device.inPort)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(device.displayName), \(device.mappings.count) mappings, \(profileName ?? "No controller selected"), \(status)")
    }

    private func selectedDeviceActions(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: AppThemeV2.Spacing.sm) {
            V2Divider()
            Text(device.displayName)
                .font(AppThemeV2.Typography.caption).fontWeight(.medium)
                .lineLimit(1).truncationMode(.middle)
                .foregroundStyle(AppThemeV2.Colors.stone200)
            Button(profileNames[device.id] == nil ? "Choose controller…" : "Change controller…") {
                onChooseController(device.id)
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppThemeV2.Colors.amber)
            Button("Device settings…") { onSettings(device.id) }
                .buttonStyle(.plain)
                .foregroundStyle(AppThemeV2.Colors.stone300)
                .help("Edit the label and ports, duplicate, delete, transfer, or export")
        }
        .font(AppThemeV2.Typography.body)
        .padding(AppThemeV2.Spacing.md)
    }
}
