import AppKit

/// Adds local row moves to SwiftUI's native table without replacing its data model.
@MainActor
final class MappingOrderDataSource: NSObject, NSTableViewDataSource, NSOutlineViewDataSource {
    private static var associationKey: UInt8 = 0
    private static let type = NSPasteboard.PasteboardType("com.sxm.mapping-row-order")
    private weak var original: NSTableViewDataSource?
    private var rowIDs: [UUID] = []
    private var canReorder = false
    private var onMove: ((Set<UUID>, UUID?) -> Bool)?

    static func configure(_ table: NSTableView, rowIDs: [UUID], canReorder: Bool,
                          onMove: ((Set<UUID>, UUID?) -> Bool)?) {
        let proxy: MappingOrderDataSource
        if let existing = objc_getAssociatedObject(table, &associationKey) as? MappingOrderDataSource {
            proxy = existing
            if table.dataSource !== proxy { proxy.original = table.dataSource; table.dataSource = proxy }
        } else {
            proxy = MappingOrderDataSource()
            proxy.original = table.dataSource
            table.dataSource = proxy
            objc_setAssociatedObject(table, &associationKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            table.registerForDraggedTypes(table.registeredDraggedTypes + [type])
            table.setDraggingSourceOperationMask(.move, forLocal: true)
        }
        proxy.rowIDs = rowIDs
        proxy.canReorder = canReorder
        proxy.onMove = onMove
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        original?.numberOfRows?(in: tableView) ?? rowIDs.count
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        guard canReorder, rowIDs.indices.contains(row) else { return nil }
        let item = NSPasteboardItem()
        item.setString(rowIDs[row].uuidString, forType: Self.type)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        guard canReorder, info.draggingSource as? NSTableView === tableView,
              !draggedIDs(info).isEmpty else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard canReorder, info.draggingSource as? NSTableView === tableView,
              row >= 0, row <= rowIDs.count else { return false }
        let ids = draggedIDs(info)
        guard !ids.isEmpty else { return false }
        return onMove?(ids, row < rowIDs.count ? rowIDs[row] : nil) ?? false
    }

    func tableView(_ tableView: NSTableView, writeRowsWith rowIndexes: IndexSet, to pasteboard: NSPasteboard) -> Bool {
        guard canReorder else { return false }
        let items = rowIndexes.compactMap { self.tableView(tableView, pasteboardWriterForRow: $0) }
        guard !items.isEmpty else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects(items)
    }

    func outlineView(_ outlineView: NSOutlineView, writeItems items: [Any], to pasteboard: NSPasteboard) -> Bool {
        tableView(outlineView, writeRowsWith: IndexSet(items.map { outlineView.row(forItem: $0) }.filter { $0 >= 0 }), to: pasteboard)
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        tableView(outlineView, pasteboardWriterForRow: outlineView.row(forItem: item))
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo,
                     proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard canReorder, info.draggingSource as? NSOutlineView === outlineView,
              !draggedIDs(info).isEmpty else { return [] }
        let row = insertionRow(for: info, in: outlineView)
        guard row >= 0, row <= rowIDs.count else { return [] }
        outlineView.setDropItem(nil, dropChildIndex: row)
        return .move
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo,
                     item: Any?, childIndex index: Int) -> Bool {
        let row = insertionRow(for: info, in: outlineView)
        return tableView(outlineView, acceptDrop: info, row: row, dropOperation: .above)
    }

    private func insertionRow(for info: NSDraggingInfo, in table: NSTableView) -> Int {
        let point = table.convert(info.draggingLocation, from: nil)
        let row = table.row(at: point)
        guard row >= 0 else { return point.y < 0 ? 0 : rowIDs.count }
        return point.y < table.rect(ofRow: row).midY ? row : row + 1
    }

    private func draggedIDs(_ info: NSDraggingInfo) -> Set<UUID> {
        Set((info.draggingPasteboard.pasteboardItems ?? []).compactMap {
            $0.string(forType: Self.type).flatMap(UUID.init(uuidString:))
        })
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if original?.responds(to: selector) == true { return original }
        return super.forwardingTarget(for: selector)
    }
}
