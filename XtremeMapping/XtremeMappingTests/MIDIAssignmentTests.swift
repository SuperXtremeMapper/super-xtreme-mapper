//
//  MIDIAssignmentTests.swift
//  XtremeMappingTests
//

import Foundation
import Testing
@testable import XtremeMapping

struct MIDIAssignmentTests {

    @Test func validationAcceptsBoundaryValues() throws {
        let lowest = try MIDIAssignment(validatingChannel: 1, note: 0, cc: nil)
        let highest = try MIDIAssignment(validatingChannel: 16, note: nil, cc: 127)
        let unassigned = try MIDIAssignment(validatingChannel: 16, note: nil, cc: nil)
        let expectedLowest = try MIDIAssignment.note(channel: 1, number: 0)
        let expectedHighest = try MIDIAssignment.controlChange(channel: 16, number: 127)
        let expectedUnassigned = try MIDIAssignment.unassigned(channel: 16)

        #expect(lowest == expectedLowest)
        #expect(highest == expectedHighest)
        #expect(unassigned == expectedUnassigned)
    }

    @Test(arguments: [0, 17])
    func validationRejectsChannelsOutsideUserRange(_ channel: Int) {
        #expect(throws: MIDIAssignment.ValidationError.channelOutOfRange(channel)) {
            try MIDIAssignment.controlChange(channel: channel, number: 1)
        }
    }

    @Test(arguments: [-1, 128])
    func validationRejectsControlNumbersOutsideMIDIByteRange(_ number: Int) {
        #expect(throws: MIDIAssignment.ValidationError.controlOutOfRange(number)) {
            try MIDIAssignment.note(channel: 1, number: number)
        }
        #expect(throws: MIDIAssignment.ValidationError.controlOutOfRange(number)) {
            try MIDIAssignment.controlChange(channel: 1, number: number)
        }
    }

    @Test func validationRejectsSimultaneousNoteAndControlChange() {
        #expect(throws: MIDIAssignment.ValidationError.ambiguousNoteAndCC) {
            try MIDIAssignment(validatingChannel: 1, note: 60, cc: 7)
        }
    }

    @Test func replacingChannelPreservesKindAndNumber() throws {
        let note = try MIDIAssignment.note(channel: 1, number: 60)
        let cc = try MIDIAssignment.controlChange(channel: 2, number: 7)
        let unassigned = try MIDIAssignment.unassigned(channel: 3)

        let replacedNote = try note.replacingChannel(with: 16)
        let replacedCC = try cc.replacingChannel(with: 15)
        let replacedUnassigned = try unassigned.replacingChannel(with: 14)
        let expectedNote = try MIDIAssignment.note(channel: 16, number: 60)
        let expectedCC = try MIDIAssignment.controlChange(channel: 15, number: 7)
        let expectedUnassigned = try MIDIAssignment.unassigned(channel: 14)

        #expect(replacedNote == expectedNote)
        #expect(replacedCC == expectedCC)
        #expect(replacedUnassigned == expectedUnassigned)
    }

    @Test func noteOffDoesNotProduceLearnAssignment() {
        let message = MIDIMessage(channel: 1, note: 60, cc: nil, value: 0)
        #expect(MIDIAssignment(learnMessage: message) == nil)
    }

    @Test func zeroValueControlChangeIsStillLearnable() throws {
        let message = MIDIMessage(channel: 1, note: nil, cc: 7, value: 0)
        let expected = try MIDIAssignment.controlChange(channel: 1, number: 7)
        #expect(
            MIDIAssignment(learnMessage: message) == expected
        )
    }

    @Test func learnRejectsAmbiguousOrInvalidMessages() {
        #expect(
            MIDIAssignment(
                learnMessage: MIDIMessage(channel: 1, note: 60, cc: 7, value: 100)
            ) == nil
        )
        #expect(
            MIDIAssignment(
                learnMessage: MIDIMessage(channel: 17, note: nil, cc: 7, value: 100)
            ) == nil
        )
    }

    @Test func accessorsAndDisplayUseTheSameExclusiveState() throws {
        let note = try MIDIAssignment.note(channel: 2, number: 60)
        #expect(note.kind == .note)
        #expect(note.note == 60)
        #expect(note.cc == nil)
        #expect(note.displayName == "Ch02 Note C4")

        let cc = try MIDIAssignment.controlChange(channel: 16, number: 0)
        #expect(cc.kind == .controlChange)
        #expect(cc.note == nil)
        #expect(cc.cc == 0)
        #expect(cc.displayName == "Ch16 CC 000")

        let unassigned = try MIDIAssignment.unassigned(channel: 1)
        #expect(unassigned.kind == .unassigned)
        #expect(unassigned.note == nil)
        #expect(unassigned.cc == nil)
        #expect(unassigned.displayName == "Ch01 --")
    }

    @Test func codableRejectsUncheckedPrivateState() throws {
        let valid = try MIDIAssignment.note(channel: 1, number: 60)
        var json = try #require(
            try JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any]
        )
        json["channel"] = 17
        let data = try JSONSerialization.data(withJSONObject: json)

        do {
            _ = try JSONDecoder().decode(MIDIAssignment.self, from: data)
            Issue.record("Expected invalid private state to be rejected")
        } catch DecodingError.dataCorrupted {
            // Expected: Codable is an external boundary and must revalidate.
        }
    }
}
