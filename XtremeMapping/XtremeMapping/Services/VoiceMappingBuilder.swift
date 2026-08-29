//
//  VoiceMappingBuilder.swift
//  SuperXtremeMapping
//

import Foundation

enum VoiceMappingBuilderError: Error, Equatable, LocalizedError {
    case unsupportedCommand(String)
    case unsupportedMIDI

    var errorDescription: String? {
        switch self {
        case .unsupportedCommand(let command):
            "\"\(command)\" isn't a verified Traktor input command."
        case .unsupportedMIDI:
            "The captured MIDI message is not a supported Note or CC assignment."
        }
    }
}

/// Side-effect-free conversion from one interpreted voice pair to a mapping.
enum VoiceMappingBuilder {
    static func makeEntry(
        midi: MIDIMessage,
        result: VoiceCommandResult
    ) throws -> MappingEntry {
        guard let command = TraktorCommands.verifiedDescriptor(
            named: result.command,
            supporting: .input
        ) else {
            throw VoiceMappingBuilderError.unsupportedCommand(result.command)
        }
        guard let midiAssignment = MIDIAssignment(learnMessage: midi) else {
            throw VoiceMappingBuilderError.unsupportedMIDI
        }

        let controllerType = parseControllerType(result.controllerType)
        return MappingEntry(
            commandID: command.id,
            ioType: .input,
            assignment: parseAssignment(result.assignment),
            interactionMode: controllerType.defaultInteractionMode,
            midiAssignment: midiAssignment,
            controllerType: controllerType
        )
    }

    private static func parseAssignment(_ assignmentString: String?) -> TargetAssignment {
        guard let value = assignmentString?.lowercased() else { return .global }
        if value.contains("deck a") { return .deckA }
        if value.contains("deck b") { return .deckB }
        if value.contains("deck c") { return .deckC }
        if value.contains("deck d") { return .deckD }
        if value.contains("fx") || value.contains("effect") {
            if value.contains("1") { return .fxUnit1 }
            if value.contains("2") { return .fxUnit2 }
            if value.contains("3") { return .fxUnit3 }
            if value.contains("4") { return .fxUnit4 }
            return .fxUnit1
        }
        return .global
    }

    private static func parseControllerType(_ controllerTypeString: String?) -> ControllerType {
        guard let value = controllerTypeString?.lowercased() else { return .faderOrKnob }
        if value.contains("button") || value.contains("pad") || value.contains("trigger") {
            return .button
        }
        if value.contains("encoder") || value.contains("rotary") || value.contains("jog") {
            return .encoder
        }
        return .faderOrKnob
    }
}
