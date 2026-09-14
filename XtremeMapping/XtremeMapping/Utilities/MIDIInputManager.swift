//
//  MIDIInputManager.swift
//  SuperXtremeMapping
//
//  Handles MIDI input for the Learn functionality
//

import Foundation
import CoreMIDI
import Combine

private final class MIDIConnectionContext: @unchecked Sendable {
    let identity: MIDIEndpointIdentity
    let token: UUID

    init(identity: MIDIEndpointIdentity, token: UUID = UUID()) {
        self.identity = identity
        self.token = token
    }
}

/// Represents a received MIDI message
struct MIDIMessage: Equatable {
    let channel: Int      // 1-16
    let note: Int?        // 0-127 for note messages
    let cc: Int?          // 0-127 for CC messages
    let value: Int        // Velocity or CC value
    let source: MIDIEndpointIdentity?

    init(
        channel: Int,
        note: Int?,
        cc: Int?,
        value: Int,
        source: MIDIEndpointIdentity? = nil
    ) {
        self.channel = channel
        self.note = note
        self.cc = cc
        self.value = value
        self.source = source
    }

    var isNoteOn: Bool { note != nil && value > 0 }
    var isCC: Bool { cc != nil }
}

/// Manages MIDI input listening for the Learn feature
@MainActor
final class MIDIInputManager: ObservableObject {
    struct ListeningLease: Hashable, Sendable {
        fileprivate let id: UUID

        fileprivate init() {
            id = UUID()
        }
    }

    /// Pure ownership state shared by the CoreMIDI manager and its tests.
    /// A new legacy callback intentionally displaces a leased owner, while stale
    /// legacy cleanup cannot clear or stop a newer leased owner.
    struct ListenerOwnership {
        typealias Callback = (MIDIMessage) -> Void

        private(set) var isListening = false
        private(set) var activeLease: ListeningLease?
        private(set) var callback: Callback?
        private(set) var setupChangedCallback: (() -> Void)?
        private(set) var route: MIDIInputRoute?

        var hasCallback: Bool {
            callback != nil
        }

        mutating func acquire(
            route: MIDIInputRoute = .allSources,
            _ callback: @escaping Callback
        ) -> ListeningLease? {
            guard !isListening, self.callback == nil else { return nil }

            let lease = ListeningLease()
            activeLease = lease
            self.callback = callback
            self.route = route
            return lease
        }

        mutating func startLeasedListening(using lease: ListeningLease) -> Bool {
            guard activeLease == lease, !isListening else { return false }
            isListening = true
            return true
        }

        mutating func failLeasedListening(using lease: ListeningLease) {
            guard activeLease == lease else { return }
            activeLease = nil
            callback = nil
            route = nil
            setupChangedCallback = nil
            isListening = false
        }

        mutating func replaceCallback(_ callback: Callback?) {
            guard callback != nil || activeLease == nil else { return }
            activeLease = nil
            self.callback = callback
            setupChangedCallback = nil
            if callback == nil {
                route = nil
            }
        }

        mutating func invalidateLease() {
            activeLease = nil
            setupChangedCallback = nil
        }

        mutating func startLegacyListening(route: MIDIInputRoute = .allSources) {
            activeLease = nil
            self.route = route
            isListening = true
        }

        @discardableResult
        mutating func stopLegacyListening() -> Bool {
            guard activeLease == nil else { return false }
            isListening = false
            route = nil
            setupChangedCallback = nil
            return true
        }

        mutating func failCurrentListening() {
            if activeLease != nil {
                callback = nil
            }
            activeLease = nil
            isListening = false
            route = nil
            setupChangedCallback = nil
        }

        @discardableResult
        mutating func release(_ lease: ListeningLease) -> Bool {
            guard activeLease == lease else { return false }
            activeLease = nil
            callback = nil
            isListening = false
            route = nil
            setupChangedCallback = nil
            return true
        }

        func owns(_ lease: ListeningLease) -> Bool {
            activeLease == lease && isListening
        }

        func deliver(_ message: MIDIMessage) {
            guard route?.accepts(message.source) == true else { return }
            callback?(message)
        }

        @discardableResult
        mutating func setSetupChangedCallback(
            _ callback: (() -> Void)?,
            for lease: ListeningLease
        ) -> Bool {
            guard activeLease == lease else { return false }
            setupChangedCallback = callback
            return true
        }

        mutating func replaceLegacySetupChangedCallback(_ callback: (() -> Void)?) {
            guard activeLease == nil else { return }
            setupChangedCallback = callback
        }

        func deliverSetupChange() {
            setupChangedCallback?()
        }
    }

    static let shared = MIDIInputManager()

    @Published private(set) var isListening = false
    @Published private(set) var lastMessage: MIDIMessage?
    @Published private(set) var activeListeningLease: ListeningLease?
    @Published private(set) var hasMIDIReceiver = false
    @Published private(set) var availableSources: [MIDIEndpointIdentity] = []

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedSources: [MIDIEndpointRef] = []
    // CoreMIDI owns only an unretained pointer to each connection context. Keep
    // contexts alive for the manager lifetime so an in-flight callback remains
    // safe while sources are being disconnected during a setup change.
    private var connectionContexts: [MIDIConnectionContext] = []
    private var deliveryGate = MIDIConnectionDeliveryGate()
    private var listenerOwnership = ListenerOwnership()

    // Callback for when a MIDI message is received during learn mode
    var onMIDIReceived: ((MIDIMessage) -> Void)? {
        get { listenerOwnership.callback }
        set {
            listenerOwnership.replaceCallback(newValue)
            publishListenerOwnership()
        }
    }

    // Callback for when the MIDI setup changes (devices connected/disconnected)
    var onSetupChanged: (() -> Void)? {
        get { listenerOwnership.setupChangedCallback }
        set { listenerOwnership.replaceLegacySetupChangedCallback(newValue) }
    }

    private init() {
        setupMIDI()
    }

    private func setupMIDI() {
        // Create MIDI client
        let clientName = "SuperXtremeMapping" as CFString
        let status = MIDIClientCreateWithBlock(clientName, &midiClient) { [weak self] notification in
            // Handle MIDI setup changes (devices connected/disconnected)
            Task { @MainActor in
                self?.handleSetupChange()
            }
        }

        guard status == noErr else {
            print("Failed to create MIDI client: \(status)")
            return
        }

        createInputPort()
        refreshAvailableSources()
    }

    private func createInputPort() {
        guard inputPort == 0 else { return }

        let portName = "Learn Input" as CFString
        let status = MIDIInputPortCreateWithProtocol(
            midiClient,
            portName,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            let source = srcConnRefCon.map {
                Unmanaged<MIDIConnectionContext>
                    .fromOpaque($0)
                    .takeUnretainedValue()
            }
            self?.handleMIDIEvents(
                eventList,
                source: source?.identity,
                connectionToken: source?.token
            )
        }

        if status != noErr {
            print("Failed to create MIDI input port: \(status)")
            inputPort = 0
        }
    }

    private struct AvailableSource {
        let endpoint: MIDIEndpointRef
        let identity: MIDIEndpointIdentity
    }

    private func enumerateMIDISources() -> [AvailableSource] {
        (0..<MIDIGetNumberOfSources()).compactMap { index in
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else { return nil }

            var name: Unmanaged<CFString>?
            let nameStatus = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
            let endpointName = nameStatus == noErr
                ? (name?.takeRetainedValue() as String?) ?? ""
                : ""

            var displayName: Unmanaged<CFString>?
            let displayNameStatus = MIDIObjectGetStringProperty(
                endpoint,
                kMIDIPropertyDisplayName,
                &displayName
            )
            let endpointDisplayName = displayNameStatus == noErr
                ? (displayName?.takeRetainedValue() as String?) ?? endpointName
                : endpointName

            var uniqueID: Int32 = 0
            let idStatus = MIDIObjectGetIntegerProperty(endpoint, kMIDIPropertyUniqueID, &uniqueID)
            let stableID = idStatus == noErr && uniqueID != 0 ? uniqueID : nil

            return AvailableSource(
                endpoint: endpoint,
                identity: MIDIEndpointIdentity(
                    uniqueID: stableID,
                    name: endpointName,
                    displayName: endpointDisplayName
                )
            )
        }
    }

    private func refreshAvailableSources() {
        availableSources = enumerateMIDISources().map(\.identity)
    }

    private func resolveRoute(
        desiredInputPort: String?,
        requireSpecificSource: Bool,
        desiredSourceID: Int32?
    ) -> MIDIInputRouteResolution {
        let sources = enumerateMIDISources()
        availableSources = sources.map(\.identity)
        return MIDIInputRouteResolver.resolve(
            desiredInputPort: desiredInputPort,
            requireSpecificSource: requireSpecificSource,
            desiredSourceID: desiredSourceID,
            availableSources: sources.map(\.identity)
        )
    }

    private func connectToMIDISources(route: MIDIInputRoute) -> Bool {
        // Recreate port if needed
        createInputPort()

        guard inputPort != 0 else {
            print("No MIDI input port available")
            return false
        }

        let availableSources = enumerateMIDISources()
        let selectedSources: [AvailableSource]
        switch MIDIInputRouteResolver.reconnect(
            pinnedRoute: route,
            availableSources: availableSources.map(\.identity)
        ) {
        case .resolved(.allSources):
            selectedSources = availableSources
        case .resolved(.specificSource(let selectedIdentity)):
            selectedSources = availableSources.filter {
                $0.identity.uniqueID == selectedIdentity.uniqueID
            }
        case .unavailable, .ambiguous:
            return false
        }

        connectedSources.removeAll()

        for source in selectedSources {
            let context = MIDIConnectionContext(identity: source.identity)
            connectionContexts.append(context)
            let status = MIDIPortConnectSource(
                inputPort,
                source.endpoint,
                Unmanaged.passUnretained(context).toOpaque()
            )
            if status == noErr {
                connectedSources.append(source.endpoint)
                deliveryGate.activate(context.token)
            } else if case .specificSource = route {
                disconnectFromMIDISources()
                return false
            }
        }

        lastMessage = nil
        return true
    }

    private func disconnectFromMIDISources() {
        deliveryGate.disconnectAll()
        for source in connectedSources {
            MIDIPortDisconnectSource(inputPort, source)
        }
        connectedSources.removeAll()
    }

    private func publishListenerOwnership() {
        isListening = listenerOwnership.isListening
        activeListeningLease = listenerOwnership.activeLease
        hasMIDIReceiver = listenerOwnership.hasCallback
    }

    var isListenerIdle: Bool {
        !listenerOwnership.isListening && !listenerOwnership.hasCallback
    }

    func acquireListeningLease(
        onMIDIReceived: @escaping (MIDIMessage) -> Void
    ) -> ListeningLease? {
        acquireListeningLease(
            desiredInputPort: nil,
            requireSpecificSource: false,
            desiredSourceID: nil,
            onMIDIReceived: onMIDIReceived
        )
    }

    func acquireListeningLease(
        desiredInputPort: String?,
        requireSpecificSource: Bool,
        desiredSourceID: Int32? = nil,
        onMIDIReceived: @escaping (MIDIMessage) -> Void
    ) -> ListeningLease? {
        guard let route = resolveRoute(
            desiredInputPort: desiredInputPort,
            requireSpecificSource: requireSpecificSource,
            desiredSourceID: desiredSourceID
        ).route,
              let lease = listenerOwnership.acquire(
                route: route,
                onMIDIReceived
              ) else {
            return nil
        }
        publishListenerOwnership()

        guard connectToMIDISources(route: route),
              listenerOwnership.startLeasedListening(using: lease) else {
            listenerOwnership.failLeasedListening(using: lease)
            disconnectFromMIDISources()
            publishListenerOwnership()
            return nil
        }

        publishListenerOwnership()
        return lease
    }

    func ownsListeningLease(_ lease: ListeningLease) -> Bool {
        listenerOwnership.owns(lease)
    }

    func releaseListeningLease(_ lease: ListeningLease) {
        guard listenerOwnership.release(lease) else { return }
        disconnectFromMIDISources()
        publishListenerOwnership()
    }

    @discardableResult
    func setSetupChangedHandler(
        _ handler: (() -> Void)?,
        for lease: ListeningLease
    ) -> Bool {
        listenerOwnership.setSetupChangedCallback(handler, for: lease)
    }

    /// Start legacy callback listening. Passing no route deliberately preserves
    /// the historical all-source behavior for single-device contexts.
    @discardableResult
    func startListening(
        desiredInputPort: String? = nil,
        requireSpecificSource: Bool = false,
        desiredSourceID: Int32? = nil
    ) -> Bool {
        listenerOwnership.invalidateLease()
        publishListenerOwnership()
        guard !listenerOwnership.isListening else { return false }

        guard let route = resolveRoute(
            desiredInputPort: desiredInputPort,
            requireSpecificSource: requireSpecificSource,
            desiredSourceID: desiredSourceID
        ).route,
              connectToMIDISources(route: route) else { return false }
        listenerOwnership.startLegacyListening(route: route)
        publishListenerOwnership()
        return true
    }

    /// Stop listening for a legacy Wizard/Voice owner.
    func stopListening() {
        guard listenerOwnership.stopLegacyListening() else { return }
        disconnectFromMIDISources()
        publishListenerOwnership()
    }

    private func handleSetupChange() {
        refreshAvailableSources()
        // If we're listening, reconnect to any new sources
        if listenerOwnership.isListening {
            disconnectFromMIDISources()
            if let route = listenerOwnership.route {
                // A missing pinned source is expected during unplug/replug. The
                // listener keeps its lease but receives nothing until the same
                // stable endpoint identity returns.
                _ = connectToMIDISources(route: route)
            }
        }
        listenerOwnership.deliverSetupChange()
    }

    private nonisolated func handleMIDIEvents(
        _ eventList: UnsafePointer<MIDIEventList>,
        source: MIDIEndpointIdentity?,
        connectionToken: UUID?
    ) {
        // unsafeSequence() walks the original packet buffer; words() yields
        // every UMP word in each packet (not just the first).
        for packet in eventList.unsafeSequence() {
            for word in packet.words() {
                // Only MIDI 1.0 channel voice messages (UMP message type 2)
                guard (word >> 28) == 2 else { continue }

                // Extract bytes from the word
                let status = UInt8((word >> 16) & 0xFF)
                let data1 = UInt8((word >> 8) & 0xFF)
                let data2 = UInt8(word & 0xFF)

                if let message = parseMIDIBytes(
                    status: status,
                    data1: data1,
                    data2: data2,
                    source: source
                ) {
                    Task { @MainActor in
                        guard let connectionToken,
                              self.deliveryGate.accepts(connectionToken) else { return }
                        self.lastMessage = message
                        self.listenerOwnership.deliver(message)
                    }
                }
            }
        }
    }

    private nonisolated func parseMIDIBytes(
        status: UInt8,
        data1: UInt8,
        data2: UInt8,
        source: MIDIEndpointIdentity?
    ) -> MIDIMessage? {
        let messageType = status & 0xF0
        let channel = Int((status & 0x0F) + 1) // Convert 0-15 to 1-16

        switch messageType {
        case 0x90: // Note On (velocity 0 = Note Off equivalent)
            return MIDIMessage(channel: channel, note: Int(data1), cc: nil, value: Int(data2), source: source)
        case 0x80: // Note Off
            return MIDIMessage(channel: channel, note: Int(data1), cc: nil, value: 0, source: source)
        case 0xB0: // Control Change
            return MIDIMessage(channel: channel, note: nil, cc: Int(data1), value: Int(data2), source: source)
        default:
            return nil
        }
    }
}
