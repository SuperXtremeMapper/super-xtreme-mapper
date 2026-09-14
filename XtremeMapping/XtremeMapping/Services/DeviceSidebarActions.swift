import Foundation

/// Device navigation changes session context; only explicit creation edits the file.
@MainActor
enum DeviceSidebarActions {
    @discardableResult
    static func selectDevice(_ id: Device.ID?, in document: TraktorMappingDocument) -> Bool {
        if let id, !document.mappingFile.devices.contains(where: { $0.id == id }) { return false }
        document.activeDeviceID = id
        return true
    }

    static func addDevice(to document: TraktorMappingDocument, undoManager: UndoManager?) throws -> Device.ID? {
        let labels = Set(document.mappingFile.devices.map(\.displayName))
        var number = 1
        while labels.contains("MIDI Device \(number)") { number += 1 }
        let id = try document.performUndoableMutation(actionName: "Add Device", undoManager: undoManager) { file in
            try DeviceManagementService.addDevice(name: "Generic MIDI", comment: "MIDI Device \(number)", to: &file)
        }
        if let id { document.activeDeviceID = id }
        return id
    }
}

enum DeviceSidebarPresentation {
    static func inputStatus(device: Device, sourceID: Int32?, sources: [MIDIEndpointIdentity]) -> String {
        if sourceID == nil, device.inPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Input not set"
        }
        switch MIDIInputRouteResolver.resolve(desiredInputPort: device.inPort, requireSpecificSource: false,
                                            desiredSourceID: sourceID, availableSources: sources) {
        case .ambiguous: return "Choose an input"
        case .unavailable: return "Offline"
        case .resolved(.allSources): return sources.isEmpty ? "Offline" : "All inputs"
        case .resolved(.specificSource): return "Connected"
        }
    }
}
