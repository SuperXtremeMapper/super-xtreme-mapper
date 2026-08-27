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
        let mappings = [
            MappingEntry(
                commandID: 206,
                ioType: .input,
                assignment: .deckA,
                interactionMode: .hold,
                midiAssignment: try! .note(channel: 1, number: 14)
            ),
            MappingEntry(
                commandID: 206,
                ioType: .input,
                assignment: .deckB,
                interactionMode: .hold,
                midiAssignment: try! .note(channel: 1, number: 15)
            ),
        ]

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
        [
            MappingEntry(
                commandID: 206,
                ioType: .input,
                assignment: deck,
                interactionMode: .hold,
                midiAssignment: try! .note(channel: midiChannel, number: 1)
            ),
            MappingEntry(
                commandID: 125,
                ioType: .input,
                assignment: deck,
                interactionMode: .toggle,
                midiAssignment: try! .note(channel: midiChannel, number: 2)
            ),
            MappingEntry(
                commandID: 123,
                ioType: .input,
                assignment: deck,
                interactionMode: .direct,
                midiAssignment: try! .controlChange(channel: midiChannel, number: 0)
            ),
            MappingEntry(
                commandID: 120,
                ioType: .input,
                assignment: deck,
                interactionMode: .relative,
                midiAssignment: try! .controlChange(channel: midiChannel, number: 1)
            ),
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

        mappings.append(MappingEntry(
            commandID: 206,
            ioType: .input,
            assignment: deck,
            interactionMode: .hold,
            midiAssignment: try! .note(channel: midiChannel, number: 1)
        ))

        mappings.append(MappingEntry(
            commandID: 125,
            ioType: .input,
            assignment: deck,
            interactionMode: .toggle,
            midiAssignment: try! .note(channel: midiChannel, number: 2)
        ))

        // Hotcues 1-4
        for hotcueIndex in 0..<4 {
            mappings.append(MappingEntry(
                commandID: 2328,
                ioType: .input,
                assignment: deck,
                interactionMode: .hold,
                midiAssignment: try! .note(channel: midiChannel, number: 4 + hotcueIndex),
                setToValue: Float(hotcueIndex)
            ))
        }

        // Jog and tempo
        mappings.append(MappingEntry(
            commandID: 120,
            ioType: .input,
            assignment: deck,
            interactionMode: .relative,
            midiAssignment: try! .controlChange(channel: midiChannel, number: 0)
        ))

        mappings.append(MappingEntry(
            commandID: 123,
            ioType: .input,
            assignment: deck,
            interactionMode: .direct,
            midiAssignment: try! .controlChange(channel: midiChannel, number: 1)
        ))

        return mappings
    }

    private static func createFXMappings(unit: TargetAssignment, midiChannel: Int) -> [MappingEntry] {
        let commandID: Int
        switch unit {
        case .fxUnit1:
            commandID = 321
        case .fxUnit2:
            commandID = 322
        case .fxUnit3:
            commandID = 338
        case .fxUnit4:
            commandID = 339
        default:
            preconditionFailure("FX template mapping requires an FX unit target")
        }

        return [
            MappingEntry(
                commandID: commandID,
                ioType: .input,
                assignment: unit,
                interactionMode: .toggle,
                midiAssignment: try! .note(channel: midiChannel, number: 0)
            ),
        ]
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
