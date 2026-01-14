//
//  ControllerTemplate.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Protocol for controller templates that can create pre-configured documents
protocol ControllerTemplate {
    /// The display name of the template
    static var name: String { get }

    /// A description of the controller
    static var description: String { get }

    /// Creates a new document with pre-configured mappings for this controller
    static func createDocument() -> TraktorMappingDocument
}

// MARK: - Generic MIDI Template

/// Template for a generic MIDI controller with no pre-configured mappings
struct GenericMIDITemplate: ControllerTemplate {
    static var name = "Generic MIDI"
    static var description = "A blank template for any MIDI controller"

    static func createDocument() -> TraktorMappingDocument {
        let device = Device(
            name: "Generic MIDI",
            comment: "Custom MIDI Controller"
        )
        return TraktorMappingDocument(
            mappingFile: MappingFile(devices: [device])
        )
    }
}

// MARK: - Kontrol X1 Template

/// Template for Native Instruments Kontrol X1
struct KontrolX1Template: ControllerTemplate {
    static var name = "Kontrol X1"
    static var description = "Native Instruments Kontrol X1 MK1/MK2"

    static func createDocument() -> TraktorMappingDocument {
        var mappings: [MappingEntry] = []

        // FX Unit 1 controls (left side)
        mappings.append(contentsOf: createFXMappings(unit: 1, channelOffset: 0))

        // FX Unit 2 controls (right side)
        mappings.append(contentsOf: createFXMappings(unit: 2, channelOffset: 0))

        // Transport controls
        mappings.append(MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .toggle,
            midiChannel: 1,
            midiNote: 12
        ))

        mappings.append(MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckB,
            interactionMode: .toggle,
            midiChannel: 1,
            midiNote: 13
        ))

        // Cue buttons
        mappings.append(MappingEntry(
            commandName: "Cue",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiNote: 14
        ))

        mappings.append(MappingEntry(
            commandName: "Cue",
            ioType: .input,
            assignment: .deckB,
            interactionMode: .hold,
            midiChannel: 1,
            midiNote: 15
        ))

        let device = Device(
            name: "Kontrol X1",
            comment: "Native Instruments Kontrol X1",
            inPort: "Traktor Kontrol X1",
            outPort: "Traktor Kontrol X1",
            mappings: mappings
        )

        return TraktorMappingDocument(
            mappingFile: MappingFile(devices: [device])
        )
    }

    private static func createFXMappings(unit: Int, channelOffset: Int) -> [MappingEntry] {
        let assignment: TargetAssignment = unit == 1 ? .fxUnit1 : .fxUnit2
        let baseCC = unit == 1 ? 0 : 4

        return [
            MappingEntry(
                commandName: "Dry/Wet",
                ioType: .input,
                assignment: assignment,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: baseCC
            ),
            MappingEntry(
                commandName: "FX Knob 1",
                ioType: .input,
                assignment: assignment,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: baseCC + 1
            ),
            MappingEntry(
                commandName: "FX Knob 2",
                ioType: .input,
                assignment: assignment,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: baseCC + 2
            ),
            MappingEntry(
                commandName: "FX Knob 3",
                ioType: .input,
                assignment: assignment,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: baseCC + 3
            )
        ]
    }
}

// MARK: - Kontrol S2 Template

/// Template for Native Instruments Kontrol S2
struct KontrolS2Template: ControllerTemplate {
    static var name = "Kontrol S2"
    static var description = "Native Instruments Kontrol S2 MK1/MK2/MK3"

    static func createDocument() -> TraktorMappingDocument {
        var mappings: [MappingEntry] = []

        // Deck A controls
        mappings.append(contentsOf: createDeckMappings(deck: .deckA, midiChannel: 1))

        // Deck B controls
        mappings.append(contentsOf: createDeckMappings(deck: .deckB, midiChannel: 2))

        // Mixer controls
        mappings.append(contentsOf: createMixerMappings())

        let device = Device(
            name: "Kontrol S2",
            comment: "Native Instruments Kontrol S2",
            inPort: "Traktor Kontrol S2",
            outPort: "Traktor Kontrol S2",
            mappings: mappings
        )

        return TraktorMappingDocument(
            mappingFile: MappingFile(devices: [device])
        )
    }

    private static func createDeckMappings(deck: TargetAssignment, midiChannel: Int) -> [MappingEntry] {
        return [
            MappingEntry(
                commandName: "Play/Pause",
                ioType: .input,
                assignment: deck,
                interactionMode: .toggle,
                midiChannel: midiChannel,
                midiNote: 0
            ),
            MappingEntry(
                commandName: "Cue",
                ioType: .input,
                assignment: deck,
                interactionMode: .hold,
                midiChannel: midiChannel,
                midiNote: 1
            ),
            MappingEntry(
                commandName: "Sync",
                ioType: .input,
                assignment: deck,
                interactionMode: .toggle,
                midiChannel: midiChannel,
                midiNote: 2
            ),
            MappingEntry(
                commandName: "Tempo",
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiChannel: midiChannel,
                midiCC: 0
            ),
            MappingEntry(
                commandName: "Jog Turn",
                ioType: .input,
                assignment: deck,
                interactionMode: .relative,
                midiChannel: midiChannel,
                midiCC: 1
            )
        ]
    }

    private static func createMixerMappings() -> [MappingEntry] {
        return [
            MappingEntry(
                commandName: "Crossfader",
                ioType: .input,
                assignment: .global,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: 64
            ),
            MappingEntry(
                commandName: "Channel Fader",
                ioType: .input,
                assignment: .deckA,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: 65
            ),
            MappingEntry(
                commandName: "Channel Fader",
                ioType: .input,
                assignment: .deckB,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: 66
            )
        ]
    }
}

// MARK: - Kontrol S4 Template

/// Template for Native Instruments Kontrol S4
struct KontrolS4Template: ControllerTemplate {
    static var name = "Kontrol S4"
    static var description = "Native Instruments Kontrol S4 MK1/MK2/MK3"

    static func createDocument() -> TraktorMappingDocument {
        var mappings: [MappingEntry] = []

        // All four decks
        mappings.append(contentsOf: createDeckMappings(deck: .deckA, midiChannel: 1))
        mappings.append(contentsOf: createDeckMappings(deck: .deckB, midiChannel: 2))
        mappings.append(contentsOf: createDeckMappings(deck: .deckC, midiChannel: 3))
        mappings.append(contentsOf: createDeckMappings(deck: .deckD, midiChannel: 4))

        // FX Units
        mappings.append(contentsOf: createFXMappings(unit: .fxUnit1, midiChannel: 5))
        mappings.append(contentsOf: createFXMappings(unit: .fxUnit2, midiChannel: 6))

        // Mixer
        mappings.append(contentsOf: createMixerMappings())

        let device = Device(
            name: "Kontrol S4",
            comment: "Native Instruments Kontrol S4",
            inPort: "Traktor Kontrol S4",
            outPort: "Traktor Kontrol S4",
            mappings: mappings
        )

        return TraktorMappingDocument(
            mappingFile: MappingFile(devices: [device])
        )
    }

    private static func createDeckMappings(deck: TargetAssignment, midiChannel: Int) -> [MappingEntry] {
        var mappings: [MappingEntry] = []

        // Transport
        mappings.append(MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: deck,
            interactionMode: .toggle,
            midiChannel: midiChannel,
            midiNote: 0
        ))

        mappings.append(MappingEntry(
            commandName: "Cue",
            ioType: .input,
            assignment: deck,
            interactionMode: .hold,
            midiChannel: midiChannel,
            midiNote: 1
        ))

        mappings.append(MappingEntry(
            commandName: "Sync",
            ioType: .input,
            assignment: deck,
            interactionMode: .toggle,
            midiChannel: midiChannel,
            midiNote: 2
        ))

        // Hotcues 1-4
        for i in 1...4 {
            mappings.append(MappingEntry(
                commandName: "Hotcue \(i)",
                ioType: .input,
                assignment: deck,
                interactionMode: .hold,
                midiChannel: midiChannel,
                midiNote: 3 + i
            ))
        }

        // Jog and tempo
        mappings.append(MappingEntry(
            commandName: "Jog Turn",
            ioType: .input,
            assignment: deck,
            interactionMode: .relative,
            midiChannel: midiChannel,
            midiCC: 0
        ))

        mappings.append(MappingEntry(
            commandName: "Tempo",
            ioType: .input,
            assignment: deck,
            interactionMode: .direct,
            midiChannel: midiChannel,
            midiCC: 1
        ))

        return mappings
    }

    private static func createFXMappings(unit: TargetAssignment, midiChannel: Int) -> [MappingEntry] {
        return [
            MappingEntry(
                commandName: "Dry/Wet",
                ioType: .input,
                assignment: unit,
                interactionMode: .direct,
                midiChannel: midiChannel,
                midiCC: 0
            ),
            MappingEntry(
                commandName: "FX Knob 1",
                ioType: .input,
                assignment: unit,
                interactionMode: .direct,
                midiChannel: midiChannel,
                midiCC: 1
            ),
            MappingEntry(
                commandName: "FX Knob 2",
                ioType: .input,
                assignment: unit,
                interactionMode: .direct,
                midiChannel: midiChannel,
                midiCC: 2
            ),
            MappingEntry(
                commandName: "FX Knob 3",
                ioType: .input,
                assignment: unit,
                interactionMode: .direct,
                midiChannel: midiChannel,
                midiCC: 3
            ),
            MappingEntry(
                commandName: "FX On",
                ioType: .input,
                assignment: unit,
                interactionMode: .toggle,
                midiChannel: midiChannel,
                midiNote: 0
            )
        ]
    }

    private static func createMixerMappings() -> [MappingEntry] {
        var mappings: [MappingEntry] = []

        // Crossfader
        mappings.append(MappingEntry(
            commandName: "Crossfader",
            ioType: .input,
            assignment: .global,
            interactionMode: .direct,
            midiChannel: 7,
            midiCC: 0
        ))

        // Channel faders and EQ for all 4 channels
        let decks: [TargetAssignment] = [.deckA, .deckB, .deckC, .deckD]
        for (index, deck) in decks.enumerated() {
            mappings.append(MappingEntry(
                commandName: "Channel Fader",
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiChannel: 7,
                midiCC: 1 + index
            ))

            mappings.append(MappingEntry(
                commandName: "EQ Hi",
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiChannel: 7,
                midiCC: 10 + index
            ))

            mappings.append(MappingEntry(
                commandName: "EQ Mid",
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiChannel: 7,
                midiCC: 20 + index
            ))

            mappings.append(MappingEntry(
                commandName: "EQ Lo",
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiChannel: 7,
                midiCC: 30 + index
            ))

            mappings.append(MappingEntry(
                commandName: "Filter",
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiChannel: 7,
                midiCC: 40 + index
            ))
        }

        return mappings
    }
}

// MARK: - Template Registry

/// Registry of all available controller templates
enum ControllerTemplates {
    static let all: [any ControllerTemplate.Type] = [
        GenericMIDITemplate.self,
        KontrolX1Template.self,
        KontrolS2Template.self,
        KontrolS4Template.self
    ]

    /// Creates a document from a template by name
    static func createDocument(named name: String) -> TraktorMappingDocument? {
        switch name {
        case GenericMIDITemplate.name:
            return GenericMIDITemplate.createDocument()
        case KontrolX1Template.name:
            return KontrolX1Template.createDocument()
        case KontrolS2Template.name:
            return KontrolS2Template.createDocument()
        case KontrolS4Template.name:
            return KontrolS4Template.createDocument()
        default:
            return nil
        }
    }
}
