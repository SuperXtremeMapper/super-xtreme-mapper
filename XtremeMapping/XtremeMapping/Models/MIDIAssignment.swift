//
//  MIDIAssignment.swift
//  XtremeMapping
//

import Foundation

/// One validated generic MIDI assignment.
nonisolated struct MIDIAssignment: Hashable, Codable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case unassigned
        case note
        case controlChange
    }

    enum ValidationError: Error, Equatable {
        case channelOutOfRange(Int)
        case controlOutOfRange(Int)
        case ambiguousNoteAndCC
    }

    private(set) var kind: Kind
    private(set) var channel: Int
    private(set) var number: Int?

    init(validatingChannel channel: Int, note: Int?, cc: Int?) throws {
        guard (1...16).contains(channel) else {
            throw ValidationError.channelOutOfRange(channel)
        }
        guard note == nil || cc == nil else {
            throw ValidationError.ambiguousNoteAndCC
        }

        let control = note ?? cc
        if let control, !(0...127).contains(control) {
            throw ValidationError.controlOutOfRange(control)
        }

        self.channel = channel
        if let note {
            kind = .note
            number = note
        } else if let cc {
            kind = .controlChange
            number = cc
        } else {
            kind = .unassigned
            number = nil
        }
    }

    init?(learnMessage: MIDIMessage) {
        if let note = learnMessage.note {
            guard learnMessage.cc == nil, learnMessage.value > 0 else { return nil }
            guard let assignment = try? Self.note(channel: learnMessage.channel, number: note) else {
                return nil
            }
            self = assignment
        } else if let cc = learnMessage.cc {
            guard let assignment = try? Self.controlChange(
                channel: learnMessage.channel,
                number: cc
            ) else {
                return nil
            }
            self = assignment
        } else {
            return nil
        }
    }

    static func unassigned(channel: Int) throws -> Self {
        try Self(validatingChannel: channel, note: nil, cc: nil)
    }

    static func note(channel: Int, number: Int) throws -> Self {
        try Self(validatingChannel: channel, note: number, cc: nil)
    }

    static func controlChange(channel: Int, number: Int) throws -> Self {
        try Self(validatingChannel: channel, note: nil, cc: number)
    }

    func replacingChannel(with channel: Int) throws -> Self {
        try Self(validatingChannel: channel, note: note, cc: cc)
    }

    var note: Int? {
        kind == .note ? number : nil
    }

    var cc: Int? {
        kind == .controlChange ? number : nil
    }

    var displayName: String {
        let channelName = String(format: "Ch%02d", channel)
        switch kind {
        case .unassigned:
            return "\(channelName) --"
        case .note:
            return "\(channelName) Note \(midiNoteToName(number!))"
        case .controlChange:
            return String(format: "%@ CC %03d", channelName, number!)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind
        case channel
        case number
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        let channel = try container.decode(Int.self, forKey: .channel)
        let number = try container.decodeIfPresent(Int.self, forKey: .number)

        do {
            switch kind {
            case .unassigned:
                guard number == nil else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .number,
                        in: container,
                        debugDescription: "An unassigned MIDI control cannot have a number."
                    )
                }
                self = try .unassigned(channel: channel)
            case .note:
                guard let number else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .number,
                        in: container,
                        debugDescription: "A MIDI Note assignment requires a number."
                    )
                }
                self = try .note(channel: channel, number: number)
            case .controlChange:
                guard let number else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .number,
                        in: container,
                        debugDescription: "A MIDI CC assignment requires a number."
                    )
                }
                self = try .controlChange(channel: channel, number: number)
            }
        } catch let error as DecodingError {
            throw error
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid MIDI assignment.",
                    underlyingError: error
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(channel, forKey: .channel)
        try container.encodeIfPresent(number, forKey: .number)
    }
}
