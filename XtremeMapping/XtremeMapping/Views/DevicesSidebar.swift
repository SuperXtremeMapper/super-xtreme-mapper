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
                Text("All devices")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: AppThemeV2.Components.tableRowHeight)
                    .tag(Selection.all)
                    .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))

                ForEach(document.mappingFile.devices) { device in
                    deviceRow(device)
                        .tag(Selection.device(device.id))
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                }
            }
            .listStyle(.inset)
            .environment(\.defaultMinListRowHeight, AppThemeV2.Components.tableRowHeight)
            .introspectTableView { table in
                AmberSelectionDelegateProxy.configure(table, highlightedRows: [])
                table.intercellSpacing.height = 0
            }
            .scrollContentBackground(.hidden)
            .tint(AppThemeV2.Colors.amber)
            .font(AppThemeV2.Typography.body)
            .accessibilityLabel("Mapping devices")
            // Device deletion is reviewed in settings. Delete must not reach
            // selected mapping rows while this navigation list has focus.
            .onDeleteCommand { }

            V2Divider()
            V2ToolbarButton(icon: "plus", label: "Add device", action: onAdd)
                .disabled(isLocked)
                .padding(AppThemeV2.Spacing.sm)
        }
        .background(AppThemeV2.Colors.stone800)
        .accessibilityIdentifier("devices-sidebar")
    }

    private func deviceRow(_ device: Device) -> some View {
        let status = DeviceSidebarPresentation.inputStatus(device: device,
            sourceID: document.midiSourceIDs[device.id], sources: midiManager.availableSources)
        return HStack(spacing: 6) {
            Text(device.displayName)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button { onSettings(device.id) } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundStyle(AppThemeV2.Colors.stone400)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Device settings for \(device.displayName)")
            .accessibilityLabel("Device settings for \(device.displayName)")
        }
        .frame(height: AppThemeV2.Components.tableRowHeight)
        .accessibilityElement(children: .contain)
        .help("\(device.displayName)\n\(profileNames[device.id] ?? "No controller selected")\n\(status)")
    }
}
