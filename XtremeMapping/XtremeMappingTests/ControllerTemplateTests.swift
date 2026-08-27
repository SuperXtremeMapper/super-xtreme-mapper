//
//  ControllerTemplateTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

@MainActor
final class ControllerTemplateTests: XCTestCase {

    func testEveryBuiltInTemplateUsesVerifiedCommandsAndValidMIDI() throws {
        for template in ControllerTemplates.all {
            let mappings = template.createDocument().mappingFile.allMappings

            for mapping in mappings {
                let descriptor = TraktorCommands.descriptor(for: mapping.commandID)
                XCTAssertGreaterThan(mapping.commandID, 0, "\(template.name): \(mapping.id)")
                XCTAssertEqual(
                    descriptor.verification,
                    .verifiedTraktor441,
                    "\(template.name): \(descriptor.name)"
                )
                XCTAssertTrue(
                    descriptor.supportedDirections.contains(mapping.ioType),
                    "\(template.name): \(descriptor.name) / \(mapping.ioType)"
                )
                XCTAssertTrue(mapping.hasMIDIAssignment, "\(template.name): \(descriptor.name)")
                XCTAssertEqual(
                    mapping.midiAssignment,
                    try MIDIAssignment(
                        validatingChannel: mapping.midiChannel,
                        note: mapping.midiNote,
                        cc: mapping.midiCC
                    )
                )
            }
        }
    }

    func testKontrolX1RemovesUnverifiedFXAndTransportAliases() {
        let mappings = KontrolX1Template.createDocument().mappingFile.allMappings

        XCTAssertEqual(mappings.map(\.commandID), [206, 206])
        XCTAssertEqual(mappings.map(\.assignment), [.deckA, .deckB])
    }

    func testKontrolS2UsesAuditedCueSyncTempoAndJogIDs() {
        let mappings = KontrolS2Template.createDocument().mappingFile.allMappings

        XCTAssertEqual(
            mappings.map(\.commandID),
            [206, 125, 123, 120, 206, 125, 123, 120]
        )
        XCTAssertEqual(
            mappings.map(\.assignment),
            [.deckA, .deckA, .deckA, .deckA, .deckB, .deckB, .deckB, .deckB]
        )
    }

    func testKontrolS4UsesCanonicalHotcueAndFXUnitCommands() {
        let mappings = KontrolS4Template.createDocument().mappingFile.allMappings
        let deckCommands = [206, 125, 2328, 2328, 2328, 2328, 120, 123]

        XCTAssertEqual(
            mappings.map(\.commandID),
            deckCommands + deckCommands + deckCommands + deckCommands + [321, 322]
        )
        XCTAssertEqual(
            mappings.filter { $0.commandID == 2328 }.map(\.setToValue),
            [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3]
        )
        XCTAssertEqual(
            Array(mappings.suffix(2)).map(\.assignment),
            [.fxUnit1, .fxUnit2]
        )
    }
}
