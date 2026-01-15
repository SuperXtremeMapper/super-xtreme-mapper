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
    static let shared = MIDIInputManager()

    @Published private(set) var isListening = false
    @Published private(set) var lastMessage: MIDIMessage?

    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var connectedSources: [MIDIEndpointRef] = []

    // Callback for when a MIDI message is received during learn mode
    var onMIDIReceived: ((MIDIMessage) -> Void)?

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

    /// Start listening to all MIDI inputs
    func startListening() {
        guard !isListening else { return }

        // Recreate port if needed
        createInputPort()

        guard inputPort != 0 else {
            print("No MIDI input port available")
            return
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

        isListening = true
        lastMessage = nil
    }

    /// Stop listening to MIDI inputs
    func stopListening() {
        guard isListening else { return }

        // Disconnect all sources
        for source in connectedSources {
            MIDIPortDisconnectSource(inputPort, source)
        }
        connectedSources.removeAll()

        isListening = false
    }

    private func handleSetupChange() {
        // If we're listening, reconnect to any new sources
        if isListening {
            stopListening()
            startListening()
        }
    }

    private nonisolated func handleMIDIEvents(_ eventList: UnsafePointer<MIDIEventList>) {
        let events = eventList.pointee
        var packet = events.packet

        for _ in 0..<events.numPackets {
            // Parse MIDI 1.0 messages (most common)
            let words = packet.words
            let word = words.0

            // Extract bytes from the word
            let status = UInt8((word >> 16) & 0xFF)
            let data1 = UInt8((word >> 8) & 0xFF)
            let data2 = UInt8(word & 0xFF)

            if let message = parseMIDIBytes(status: status, data1: data1, data2: data2) {
                Task { @MainActor in
                    self.lastMessage = message
                    self.onMIDIReceived?(message)
                }
            }

            // Move to next packet
            let currentPacket = packet
            withUnsafePointer(to: currentPacket) { ptr in
                packet = MIDIEventPacketNext(ptr).pointee
            }
        }
    }

    private nonisolated func parseMIDIBytes(status: UInt8, data1: UInt8, data2: UInt8) -> MIDIMessage? {
        let messageType = status & 0xF0
        let channel = Int((status & 0x0F) + 1) // Convert 0-15 to 1-16

        switch messageType {
        case 0x90: // Note On
            if data2 > 0 {
                return MIDIMessage(channel: channel, note: Int(data1), cc: nil, value: Int(data2))
            } else {
                // Note On with velocity 0 is Note Off - ignore for learning
                return nil
            }
        case 0x80: // Note Off - ignore for learning
            return nil
        case 0xB0: // Control Change
            return MIDIMessage(channel: channel, note: nil, cc: Int(data1), value: Int(data2))
        default:
            return nil
        }
    }
}
