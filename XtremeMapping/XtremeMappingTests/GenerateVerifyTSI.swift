//
//  GenerateVerifyTSI.swift
//  XtremeMappingTests
//
//  Temporary test to generate a TSI file for verifying command IDs
//

import XCTest
@testable import XtremeMapping

final class GenerateVerifyTSI: XCTestCase {

    func testGenerateVerificationTSI() throws {
        // Create mappings for the commands we want to verify
        let mappings = [
            MappingEntry(
                commandName: "Command #403",
                ioType: .input,
                assignment: .global,
                interactionMode: .hold,
                midiChannel: 1,
                midiCC: 0,
                comment: "ID 403 - Key Match or Freeze On?",
                controllerType: .button
            ),
            MappingEntry(
                commandName: "Command #261",
                ioType: .input,
                assignment: .global,
                interactionMode: .hold,
                midiChannel: 1,
                midiCC: 1,
                comment: "ID 261 - Slot BPM Sync or Slot Pre-Fader Level (L)?",
                controllerType: .button
            )
        ]

        // Create device and mapping file
        let device = Device(
            name: "Verify Commands",
            mappings: mappings
        )
        let mappingFile = MappingFile(devices: [device])

        // Write TSI
        let writer = TSIWriter()
        let data = writer.write(mappingFile)

        // Save to Desktop
        let outputURL = URL(fileURLWithPath: "/Users/noahraford/Desktop/verify_commands.tsi")
        try data.write(to: outputURL)

        print("TSI file written to: \(outputURL.path)")
        print("Mappings included:")
        for mapping in mappings {
            print("  - \(mapping.comment)")
        }
    }
}
