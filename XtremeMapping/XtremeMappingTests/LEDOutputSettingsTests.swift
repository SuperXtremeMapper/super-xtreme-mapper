import XCTest
@testable import XtremeMapping

@MainActor
final class LEDOutputSettingsTests: XCTestCase {
    func testSignedCueRangeAndEqualEndpoints() throws {
        let output = MappingEntry(commandID: 2333, ioType: .output)
        let edited = try LEDOutputSettings.Patch(controllerMinimum: "-1", controllerMaximum: "-1").applying(to: output)
        XCTAssertEqual(edited.ledMinRangeData, Int(UInt32.max))
        XCTAssertEqual(edited.ledMaxRangeData, Int(UInt32.max))
        XCTAssertEqual(LEDOutputSettings.text(for: .controllerMinimum, in: edited), "-1")
    }

    func testFloatRangeUsesBitPatterns() throws {
        let output = MappingEntry(commandID: 365, ioType: .output,
                                  ledMinRangeType: 2, ledMaxRangeType: 2,
                                  ledMaxRangeData: Int(Float(1).bitPattern))
        let edited = try LEDOutputSettings.Patch(controllerMinimum: "0.125", controllerMaximum: "0.75").applying(to: output)
        XCTAssertEqual(edited.ledMinRangeData, Int(Float(0.125).bitPattern))
        XCTAssertEqual(edited.ledMaxRangeData, Int(Float(0.75).bitPattern))
        XCTAssertEqual(LEDOutputSettings.text(for: .controllerMaximum, in: edited), "0.75")
    }

    func testInvalidDraftsRejectWithoutChangingOriginal() throws {
        let output = MappingEntry(commandID: 2333, ioType: .output)
        for value in ["-", "0.5", "nan", "inf", "2147483648", "6"] {
            XCTAssertThrowsError(try LEDOutputSettings.Patch(controllerMinimum: value).applying(to: output), value)
        }
        for value in ["-1", "128", "0.5", ""] {
            XCTAssertThrowsError(try LEDOutputSettings.Patch(midiMaximum: value).applying(to: output), value)
        }
        XCTAssertEqual(output.ledMinRangeData, 0)
    }

    func testUnknownRangeSurvivesIndependentMIDIAndFlagEdits() throws {
        let output = MappingEntry(commandID: 2333, ioType: .output,
                                  ledMinRangeType: 77, ledMinRangeData: 123456,
                                  ledMaxRangeType: 78, ledMaxRangeData: 654321)
        let edited = try LEDOutputSettings.Patch(midiMaximum: "1", blend: true, invert: true).applying(to: output)
        XCTAssertEqual(edited.ledMinRangeType, 77)
        XCTAssertEqual(edited.ledMinRangeData, 123456)
        XCTAssertEqual(edited.ledMaxRangeData, 654321)
        XCTAssertEqual(edited.ledMaxMidi, 1)
        XCTAssertTrue(edited.ledBlend)
        XCTAssertTrue(edited.ledInvert)
        XCTAssertFalse(edited.invert)
        XCTAssertNil(LEDOutputSettings.text(for: .controllerMinimum, in: edited))
        XCTAssertThrowsError(try LEDOutputSettings.Patch(controllerMinimum: "0").applying(to: output))
    }

    func testMissingImportedLEDTailIsReadOnlyEvenWhenModelHasDefaults() throws {
        var output = MappingEntry.output(commandID: 2333)
        let fullPayload = try TSIWriter().preservingCMADPayload(for: output)
        output.importedCMAD = try XCTUnwrap(ImportedCMAD(payload: Data(fullPayload.prefix(52)), semanticAtImport: output))
        XCTAssertFalse(LEDOutputSettings.canEditControllerRange(in: [output]))
        XCTAssertThrowsError(try LEDOutputSettings.Patch(midiMaximum: "1").applying(to: output))
        XCTAssertThrowsError(try LEDOutputSettings.Patch(invert: true).applying(to: output))
        XCTAssertThrowsError(try LEDOutputSettings.Patch(controllerMinimum: "0").applying(to: output))
    }

    func testNonfiniteFloatAndInputEditsReject() {
        let output = MappingEntry(commandID: 365, ioType: .output, ledMinRangeType: 2, ledMaxRangeType: 2)
        for value in ["nan", "inf", "-inf", "1e100"] {
            XCTAssertThrowsError(try LEDOutputSettings.Patch(controllerMinimum: value).applying(to: output))
        }
        XCTAssertThrowsError(try LEDOutputSettings.Patch(invert: true).applying(to: MappingEntry()))
    }

    func testBatchRangeRequiresMatchingKnownDomainsAndEncodings() {
        let cue1 = MappingEntry(commandID: 2333, ioType: .output)
        let cue2 = MappingEntry(commandID: 2334, ioType: .output)
        let play = MappingEntry(commandID: 100, ioType: .output)
        XCTAssertTrue(LEDOutputSettings.canEditControllerRange(in: [cue1, cue2]))
        XCTAssertFalse(LEDOutputSettings.canEditControllerRange(in: [cue1, play]))
        XCTAssertFalse(LEDOutputSettings.canEditControllerRange(in: [cue1, MappingEntry()]))
        XCTAssertFalse(LEDOutputSettings.canEditControllerRange(in: []))
    }

    func testOutputFactoryUsesOutputModesAndVerifiedCueDefaults() {
        let cue = MappingEntry.output(commandID: 2333)
        XCTAssertEqual(cue.ioType, .output)
        XCTAssertEqual(cue.controllerType, .led)
        XCTAssertEqual(cue.interactionMode, .output)
        XCTAssertEqual(cue.ledMinRangeData, Int(UInt32.max))
        XCTAssertEqual(cue.ledMaxRangeData, 5)
    }

    func testModifierOutputExportHonoursExplicitRangesAndBlend() throws {
        var output = MappingEntry.output(commandID: 2548)
        output = try LEDOutputSettings.Patch(controllerMinimum: "3", controllerMaximum: "3", midiMaximum: "1", blend: false).applying(to: output)
        let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [output])])
        let decoded = try reimport(TSIWriter().write(file)).allMappings[0]
        XCTAssertEqual(decoded.ledMinRangeData, 3)
        XCTAssertEqual(decoded.ledMaxRangeData, 3)
        XCTAssertFalse(decoded.ledBlend)
        XCTAssertEqual(decoded.ledMaxMidi, 1)
    }

    func testImportedCommandChangeKeepsSimultaneousLEDSettings() throws {
        var output = MappingEntry.output(commandID: 100)
        output.midiAssignment = try .note(channel: 12, number: 36)
        var file = try reimport(TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: [output])])))
        file.devices[0].mappings[0].commandID = 2333
        file.devices[0].mappings[0] = try LEDOutputSettings.Patch(controllerMinimum: "0", controllerMaximum: "0", midiMinimum: "1", midiMaximum: "2", blend: true, invert: true).applying(to: file.devices[0].mappings[0])
        for data in [try TSIWriter().write(file), try TSIWriter().writeConverted(file)] {
            let decoded = try reimport(data).allMappings[0]
            XCTAssertEqual(decoded.ledMinRangeData, 0)
            XCTAssertEqual(decoded.ledMaxRangeData, 0)
            XCTAssertEqual(decoded.ledMinMidi, 1)
            XCTAssertEqual(decoded.ledMaxMidi, 2)
            XCTAssertTrue(decoded.ledBlend)
            XCTAssertTrue(decoded.ledInvert)
            XCTAssertFalse(decoded.invert)
        }
    }

    func testRequestedS7ConfigurationSurvivesBothExportPaths() throws {
        var output = MappingEntry.output(commandID: 2333)
        output.midiAssignment = try .note(channel: 1, number: 36)
        output = try LEDOutputSettings.Patch(controllerMinimum: "0", controllerMaximum: "0", midiMinimum: "0", midiMaximum: "1", blend: false, invert: false).applying(to: output)
        let file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [output])])
        for data in [try TSIWriter().write(file), try TSIWriter().writeConverted(file)] {
            let decoded = try reimport(data).allMappings[0]
            XCTAssertEqual(decoded.controllerType, .led)
            XCTAssertEqual(decoded.interactionMode, .output)
            XCTAssertEqual(decoded.ledMinRangeData, 0)
            XCTAssertEqual(decoded.ledMaxRangeData, 0)
            XCTAssertEqual(decoded.ledMinMidi, 0)
            XCTAssertEqual(decoded.ledMaxMidi, 1)
            XCTAssertEqual(decoded.midiAssignment, output.midiAssignment)
        }
    }

    private func reimport(_ data: Data) throws -> MappingFile {
        let parser = TSIParser()
        let binary = try parser.decodeBase64(TSIParser.extractControllerData(from: data))
        return try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
    }
}
