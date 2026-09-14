import SwiftUI
import AppKit

private enum DeviceSidebarLayout {
    static let iconSize: CGFloat = 24
    static let trailingInset: CGFloat = 12
    static let symbolSize: CGFloat = 14
    static let headerHeight: CGFloat = 28
}

/// Navigation and controller identity share one entry point; editing remains device-scoped.
struct DevicesSidebar: View {
    @ObservedObject var document: TraktorMappingDocument
    @ObservedObject private var midiManager = MIDIInputManager.shared
    let profileNames: [UUID: String]
    let isLocked: Bool
    let onClose: () -> Void
    let onAdd: () -> Void
    let onSettings: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppThemeV2.Spacing.sm) {
                V2SectionHeader(title: "DEVICES")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("XXDEVICES")
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: DeviceSidebarLayout.symbolSize))
                        .frame(width: DeviceSidebarLayout.iconSize, height: DeviceSidebarLayout.iconSize)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppThemeV2.Colors.stone400)
                .help("Hide devices")
                .accessibilityLabel("Hide devices")
            }
            .padding(.horizontal, DeviceSidebarLayout.trailingInset)
            .frame(height: AppThemeV2.Components.sectionHeaderHeight)
            V2Divider()

            NativeDevicesTable(devices: document.mappingFile.devices,
                selectedID: document.activeDeviceID,
                toolTips: Dictionary(uniqueKeysWithValues: document.mappingFile.devices.map { device in
                    (device.id, "\(profileNames[device.id] ?? "No controller selected")\n\(DeviceSidebarPresentation.inputStatus(device: device, sourceID: document.midiSourceIDs[device.id], sources: midiManager.availableSources))")
                }),
                onSelect: { DeviceSidebarActions.selectDevice($0, in: document) },
                onSettings: onSettings)
            // The native column header aligns with the mappings table header.
            // Its action restores the combined view rather than sorting devices.
            .overlay(alignment: .top) {
                HStack(spacing: 0) {
                    Button { DeviceSidebarActions.selectDevice(nil, in: document) } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("All devices")
                    .help("Show mappings from all devices")
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: DeviceSidebarLayout.symbolSize))
                            .frame(width: DeviceSidebarLayout.iconSize, height: DeviceSidebarLayout.iconSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isLocked ? AppThemeV2.Colors.stone600 : AppThemeV2.Colors.stone400)
                    .disabled(isLocked)
                    .help("Add device")
                    .accessibilityLabel("Add device")
                }
                .padding(.trailing, DeviceSidebarLayout.trailingInset)
                .frame(height: DeviceSidebarLayout.headerHeight)
            }
            // Device deletion is reviewed in settings. Delete must not reach
            // selected mapping rows while this navigation list has focus.
            .onDeleteCommand { }

        }
        .background(AppThemeV2.Colors.stone800)
        .accessibilityIdentifier("devices-sidebar")
    }

}

/// Own the native table so SwiftUI cannot reapply its list sizing after selection.
private struct NativeDevicesTable: NSViewRepresentable {
    let devices: [Device]
    let selectedID: UUID?
    let toolTips: [UUID: String]
    let onSelect: (UUID?) -> Void
    let onSettings: (UUID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        let table = NSTableView()
        table.setAccessibilityLabel("Mapping devices")
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("device"))
        column.title = "All devices"
        column.headerCell.font = .systemFont(ofSize: 11, weight: .medium)
        table.addTableColumn(column)
        table.headerView = NSTableHeaderView(frame: NSRect(x: 0, y: 0, width: 220, height: DeviceSidebarLayout.headerHeight))
        table.style = .fullWidth
        table.intercellSpacing = NSSize(width: 17, height: 0)
        // Measured from the live mappings table: 27-point rows, 5-point top inset.
        table.rowHeight = 27
        table.usesAutomaticRowHeights = false
        table.backgroundColor = NSColor(AppThemeV2.Colors.stone800)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.allowsMultipleSelection = false
        table.allowsEmptySelection = true
        table.delegate = context.coordinator
        table.dataSource = context.coordinator
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false
        // Keep the header flush with the mapping column header. The delegate
        // supplies the measured 5-point gap inside the table body instead.
        scroll.contentInsets.top = 0
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let table = scroll.documentView as? NSTableView else { return }
        context.coordinator.parent = self
        context.coordinator.updating = true
        table.reloadData()
        if let index = devices.firstIndex(where: { $0.id == selectedID }) {
            table.selectRowIndexes(IndexSet(integer: index + 1), byExtendingSelection: false)
        } else { table.deselectAll(nil) }
        context.coordinator.updating = false
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeDevicesTable
        var updating = false
        init(_ parent: NativeDevicesTable) { self.parent = parent }
        func numberOfRows(in tableView: NSTableView) -> Int { parent.devices.count + 1 }
        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { row == 0 ? 5 : 27 }
        func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { row > 0 }
        func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
            if row == 0 {
                let spacer = NSTableRowView()
                spacer.setAccessibilityElement(false)
                return spacer
            }
            return AmberTableRowView()
        }
        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row > 0 else { return nil }
            let device = parent.devices[row - 1]
            let cell = DeviceSidebarCell()
            cell.toolTip = parent.toolTips[device.id]
            let label = NSTextField(labelWithString: device.displayName)
            label.font = .systemFont(ofSize: 12)
            label.textColor = NSColor(AppThemeV2.Colors.stone200)
            label.lineBreakMode = .byTruncatingMiddle
            let gear = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Device settings for \(device.displayName)")!, target: self, action: #selector(settings(_:)))
            gear.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: DeviceSidebarLayout.symbolSize, weight: .regular)
            gear.tag = row - 1
            gear.isBordered = false
            gear.contentTintColor = NSColor(AppThemeV2.Colors.stone400)
            gear.toolTip = "Device settings for \(device.displayName)"
            cell.addSubview(label)
            cell.addSubview(gear)
            cell.textField = label
            cell.gear = gear
            return cell
        }
        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !updating, let table = notification.object as? NSTableView else { return }
            let index = table.selectedRow - 1
            parent.onSelect(parent.devices.indices.contains(index) ? parent.devices[index].id : nil)
        }
        @objc private func settings(_ sender: NSButton) {
            guard parent.devices.indices.contains(sender.tag) else { return }
            parent.onSettings(parent.devices[sender.tag].id)
        }
    }
}

/// Align against the table edge, independent of AppKit's cell text insets.
private final class DeviceSidebarCell: NSTableCellView {
    var gear: NSButton?

    override func layout() {
        super.layout()
        guard let gear, let textField else { return }
        var ancestor = superview
        while ancestor != nil && !(ancestor is NSTableView) { ancestor = ancestor?.superview }
        guard let table = ancestor as? NSTableView else { return }
        let rightEdge = convert(table.bounds, from: table).maxX
        let size = DeviceSidebarLayout.iconSize
        gear.frame = NSRect(x: rightEdge - DeviceSidebarLayout.trailingInset - size,
                            y: (bounds.height - size) / 2, width: size, height: size)
        let textHeight = textField.intrinsicContentSize.height
        textField.frame = NSRect(x: 0, y: (bounds.height - textHeight) / 2,
                                width: max(0, gear.frame.minX - 6), height: textHeight)
    }
}
