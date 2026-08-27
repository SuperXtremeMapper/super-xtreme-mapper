//
//  MIDIInputManager.swift
//  SuperXtremeMapping
//
//  Handles MIDI input for the Learn functionality
//

import Foundation
import CoreMIDI
import Combine

/// Represents a received MIDI message
struct MIDIMessage: Equatable {
    let channel: Int      // 1-16
    let note: Int?        // 0-127 for note messages
    let cc: Int?          // 0-127 for CC messages
    let value: Int        // Velocity or CC value

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

        var hasCallback: Bool {
            callback != nil
        }

        mutating func acquire(_ callback: @escaping Callback) -> ListeningLease? {
            guard !isListening, self.callback == nil else { return nil }

            let lease = ListeningLease()
            activeLease = lease
            self.callback = callback
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
            isListening = false
        }

        mutating func replaceCallback(_ callback: Callback?) {
            guard callback != nil || activeLease == nil else { return }
            activeLease = nil
            self.callback = callback
        }

        mutating func invalidateLease() {
            activeLease = nil
        }

        mutating func startLegacyListening() {
            activeLease = nil
            isListening = true
        }

        @discardableResult
        mutating func stopLegacyListening() -> Bool {
            guard activeLease == nil else { return false }
            isListening = false
            return true
        }

        mutating func failCurrentListening() {
            if activeLease != nil {
                callback = nil
            }
            activeLease = nil
            isListening = false
        }

        @discardableResult
        mutating func release(_ lease: ListeningLease) -> Bool {
            guard activeLease == lease else { return false }
            activeLease = nil
            callback = nil
            isListening = false
            return true
        }

        func owns(_ lease: ListeningLease) -> Bool {
            activeLease == lease && isListening
        }

        func deliver(_ message: MIDIMessage) {
            callback?(message)
        }
    }

    static let shared = MIDIInputManager()

    @Published private(set) var isListening = false
    @Published private(set) var lastMessage: MIDIMessage?
    @Published private(set) var activeListeningLease: ListeningLease?
    @Published private(set) var hasMIDIReceiver = false

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedSources: [MIDIEndpointRef] = []
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
    var onSetupChanged: (() -> Void)?

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
            self?.handleMIDIEvents(eventList)
        }

        if status != noErr {
            print("Failed to create MIDI input port: \(status)")
            inputPort = 0
        }
    }

    private func connectToMIDISources() -> Bool {
        // Recreate port if needed
        createInputPort()

        guard inputPort != 0 else {
            print("No MIDI input port available")
            return false
        }

        // Connect to all available MIDI sources
        let sourceCount = MIDIGetNumberOfSources()
        connectedSources.removeAll()

        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if source != 0 {
                let status = MIDIPortConnectSource(inputPort, source, nil)
                if status == noErr {
                    connectedSources.append(source)
                }
            }
        }

        lastMessage = nil
        return true
    }

    private func disconnectFromMIDISources() {
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
        guard let lease = listenerOwnership.acquire(onMIDIReceived) else {
            return nil
        }
        publishListenerOwnership()

        guard connectToMIDISources(),
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

    /// Start listening to all MIDI inputs for a legacy Wizard/Voice owner.
    func startListening() {
        listenerOwnership.invalidateLease()
        publishListenerOwnership()
        guard !listenerOwnership.isListening else { return }

        guard connectToMIDISources() else { return }
        listenerOwnership.startLegacyListening()
        publishListenerOwnership()
    }

    /// Stop listening for a legacy Wizard/Voice owner.
    func stopListening() {
        guard listenerOwnership.stopLegacyListening() else { return }
        disconnectFromMIDISources()
        publishListenerOwnership()
    }

    private func handleSetupChange() {
        // If we're listening, reconnect to any new sources
        if listenerOwnership.isListening {
            disconnectFromMIDISources()
            if !connectToMIDISources() {
                listenerOwnership.failCurrentListening()
                publishListenerOwnership()
            }
        }
        onSetupChanged?()
    }

    private nonisolated func handleMIDIEvents(_ eventList: UnsafePointer<MIDIEventList>) {
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

                if let message = parseMIDIBytes(status: status, data1: data1, data2: data2) {
                    Task { @MainActor in
                        self.lastMessage = message
                        self.listenerOwnership.deliver(message)
                    }
                }
            }
        }
    }

    private nonisolated func parseMIDIBytes(status: UInt8, data1: UInt8, data2: UInt8) -> MIDIMessage? {
        let messageType = status & 0xF0
        let channel = Int((status & 0x0F) + 1) // Convert 0-15 to 1-16

        switch messageType {
        case 0x90: // Note On (velocity 0 = Note Off equivalent)
            return MIDIMessage(channel: channel, note: Int(data1), cc: nil, value: Int(data2))
        case 0x80: // Note Off
            return MIDIMessage(channel: channel, note: Int(data1), cc: nil, value: 0)
        case 0xB0: // Control Change
            return MIDIMessage(channel: channel, note: nil, cc: Int(data1), value: Int(data2))
        default:
            return nil
        }
    }
}
