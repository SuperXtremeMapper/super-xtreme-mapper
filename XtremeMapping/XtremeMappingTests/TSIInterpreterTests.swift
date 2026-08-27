//
//  TSIInterpreterTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import XCTest
@testable import XtremeMapping

final class TSIInterpreterTests: XCTestCase {

    private enum BoundedFrameScanError: Error {
        case malformedHierarchy
    }

    // MARK: - MIDI Control Name Parsing Tests

    func testParseCCControlName() {
        // Test parsing "Ch01.CC.100"
        let result = parseMidiControlName("Ch01.CC.100")
        XCTAssertEqual(result?.channel, 1)
        XCTAssertEqual(result?.number, 100)
        XCTAssertEqual(result?.isCC, true)
    }

    func testParseCCControlNameChannel9() {
        let result = parseMidiControlName("Ch09.CC.016")
        XCTAssertEqual(result?.channel, 9)
        XCTAssertEqual(result?.number, 16)
        XCTAssertEqual(result?.isCC, true)
    }

    func testParseCCControlNameChannel16() {
        let result = parseMidiControlName("Ch16.CC.127")
        XCTAssertEqual(result?.channel, 16)
        XCTAssertEqual(result?.number, 127)
        XCTAssertEqual(result?.isCC, true)
    }

    func testParseNoteControlName() {
        let result = parseMidiControlName("Ch09.Note.C2")
        XCTAssertEqual(result?.channel, 9)
        XCTAssertEqual(result?.isCC, false)
        // C2 = MIDI note 36 (C-1=0, C0=12, C1=24, C2=36)
        XCTAssertEqual(result?.number, 36)
    }

    func testParseNoteControlNameSharp() {
        let result = parseMidiControlName("Ch01.Note.A#2")
        XCTAssertEqual(result?.channel, 1)
        XCTAssertEqual(result?.isCC, false)
        // A#2 = MIDI note 46
        XCTAssertEqual(result?.number, 46)
    }

    func testParseNoteControlNameHighOctave() {
        let result = parseMidiControlName("Ch05.Note.G8")
        XCTAssertEqual(result?.channel, 5)
        XCTAssertEqual(result?.isCC, false)
        // G8 = MIDI note 115
        XCTAssertEqual(result?.number, 115)
    }

    func testParseInvalidControlName() {
        // Unrecognized control names are rejected (the interpreter throws) —
        // defaulting them would strip the user's MIDI assignment on save.
        XCTAssertNil(parseMidiControlName("InvalidName"))
    }

    // MARK: - MIDI Note Number Conversion Tests

    func testMidiNoteNumberC0() {
        XCTAssertEqual(midiNoteNumber(from: "C0"), 12)
    }

    func testMidiNoteNumberC4() {
        // Middle C
        XCTAssertEqual(midiNoteNumber(from: "C4"), 60)
    }

    func testMidiNoteNumberA4() {
        // A440
        XCTAssertEqual(midiNoteNumber(from: "A4"), 69)
    }

    func testMidiNoteNumberCSharp2() {
        XCTAssertEqual(midiNoteNumber(from: "C#2"), 37)
    }

    func testMidiNoteNumberFSharp5() {
        XCTAssertEqual(midiNoteNumber(from: "F#5"), 78)
    }

    func testMidiNoteNumberB7() {
        XCTAssertEqual(midiNoteNumber(from: "B7"), 107)
    }

    func testMidiNoteNumberInvalidNote() {
        XCTAssertNil(midiNoteNumber(from: "X5"))
    }

    // MARK: - Interaction Mode Mapping Tests

    func testInteractionModeToggle() {
        XCTAssertEqual(interactionMode(from: 1), .toggle)
    }

    func testInteractionModeHold() {
        XCTAssertEqual(interactionMode(from: 2), .hold)
    }

    func testInteractionModeDirect() {
        XCTAssertEqual(interactionMode(from: 3), .direct)
    }

    func testInteractionModeRelative() {
        XCTAssertEqual(interactionMode(from: 4), .relative)
    }

    func testInteractionModeOutput() {
        XCTAssertEqual(interactionMode(from: 8), .output)
    }

    func testInteractionModeTrigger() {
        XCTAssertEqual(interactionMode(from: 0), .trigger)
    }

    func testInteractionModeIncrement() {
        XCTAssertEqual(interactionMode(from: 5), .increment)
    }

    func testInteractionModeDecrement() {
        XCTAssertEqual(interactionMode(from: 6), .decrement)
    }

    func testInteractionModeReset() {
        XCTAssertEqual(interactionMode(from: 7), .reset)
    }

    func testInteractionModeUnknownDefaultsToHold() {
        // Real Traktor writes interaction modes this app doesn't model —
        // unknown values coerce to the direction default instead of
        // rejecting the file.
        XCTAssertEqual(interactionMode(from: 99, isOutput: false), .hold)
    }

    func testInteractionModeUnknownDefaultsToOutputForOutput() {
        XCTAssertEqual(interactionMode(from: 99, isOutput: true), .output)
    }

    func testControllerTypeUnknownDefaultsToButton() {
        XCTAssertEqual(controllerType(from: 7), .button)
    }

    // MARK: - Controller Type Mapping Tests

    func testControllerTypeButton() {
        XCTAssertEqual(controllerType(from: 0), .button)
    }

    func testControllerTypeFader() {
        XCTAssertEqual(controllerType(from: 1), .faderOrKnob)
    }

    func testControllerTypeEncoder() {
        XCTAssertEqual(controllerType(from: 2), .encoder)
    }

    func testControllerTypeLED() {
        XCTAssertEqual(controllerType(from: 65535), .led)
    }

    // MARK: - Target Deck Mapping Tests

    func testTargetDeckDeviceTarget() {
        XCTAssertEqual(targetAssignment(from: -1), .deviceTarget)
    }

    func testTargetDeckGlobal() {
        // Spec value 0 decodes as deckA (writer encodes both global and deckA as 0)
        XCTAssertEqual(targetAssignment(from: 0), .deckA)
    }

    func testTargetDeckB() {
        XCTAssertEqual(targetAssignment(from: 1), .deckB)
    }

    func testTargetDeckC() {
        XCTAssertEqual(targetAssignment(from: 2), .deckC)
    }

    func testTargetDeckD() {
        XCTAssertEqual(targetAssignment(from: 3), .deckD)
    }

    func testTargetFXUnit1() {
        XCTAssertEqual(targetAssignment(from: 4), .fxUnit1)
    }

    func testTargetFXUnit2() {
        XCTAssertEqual(targetAssignment(from: 5), .fxUnit2)
    }

    func testTargetFXUnit3() {
        XCTAssertEqual(targetAssignment(from: 6), .fxUnit3)
    }

    func testTargetFXUnit4() {
        XCTAssertEqual(targetAssignment(from: 7), .fxUnit4)
    }

    func testTargetUnknownDefaultsToGlobal() {
        XCTAssertEqual(targetAssignment(from: 99), .global)
    }

    // MARK: - Round-Trip Tests

    /// Write a Device through TSIWriter, parse it back through TSIInterpreter,
    /// and return the first device from the result.
    private func roundTripDevice(_ device: Device) throws -> Device? {
        let writer = TSIWriter()
        let tsiData = try writer.write(MappingFile(devices: [device]))

        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)
        return result.devices.first
    }

    private func interpretTSIData(_ data: Data) throws -> MappingFile {
        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: data)
        let binary = try parser.decodeBase64(base64)
        return try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
    }

    private func roundTripEntries(_ entries: [MappingEntry]) throws -> [MappingEntry] {
        try XCTUnwrap(roundTripDevice(Device(name: "Generic MIDI", mappings: entries))).mappings
    }

    /// Structurally walks the emitted hierarchy and reads only fields within
    /// their declared frame boundaries. Any malformed or ambiguous container
    /// fails the scan instead of falling back to marker-string byte searching.
    private func scanCMAICommandTargets(in tsi: Data) throws -> [(commandID: UInt32, target: Int32)] {
        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsi)
        let binary = try parser.decodeBase64(base64)
        let roots = try parser.parseFrames(from: binary)

        guard roots.count == 1, let diom = roots.first, diom.identifier == "DIOM" else {
            throw BoundedFrameScanError.malformedHierarchy
        }
        let diomFrames = try parser.parseFrames(from: diom.data)
        guard let devs = diomFrames.first(where: { $0.identifier == "DEVS" }),
              devs.data.count >= 4 else {
            throw BoundedFrameScanError.malformedHierarchy
        }

        let declaredDeviceCount = Int(readUInt32BE(devs.data, at: 0))
        let deviceFrames = try parser.parseFrames(from: devs.data.subdata(in: 4..<devs.data.count))
            .filter { $0.identifier == "DEVI" }
        guard deviceFrames.count == declaredDeviceCount else {
            throw BoundedFrameScanError.malformedHierarchy
        }

        var result: [(commandID: UInt32, target: Int32)] = []
        for device in deviceFrames {
            guard device.data.count >= 4 else { throw BoundedFrameScanError.malformedHierarchy }
            let nameBytes = Int(readUInt32BE(device.data, at: 0)) * 2
            let nestedOffset = 4 + nameBytes
            guard nestedOffset <= device.data.count else { throw BoundedFrameScanError.malformedHierarchy }

            let deviceChildren = try parser.parseFrames(
                from: device.data.subdata(in: nestedOffset..<device.data.count)
            )
            guard let ddat = deviceChildren.first(where: { $0.identifier == "DDAT" }) else {
                throw BoundedFrameScanError.malformedHierarchy
            }
            let dataChildren = try parser.parseFrames(from: ddat.data)
            guard let ddcb = dataChildren.first(where: { $0.identifier == "DDCB" }) else {
                throw BoundedFrameScanError.malformedHierarchy
            }
            let bindingChildren = try parser.parseFrames(from: ddcb.data)
            guard let cmas = bindingChildren.first(where: { $0.identifier == "CMAS" }),
                  cmas.data.count >= 4 else {
                throw BoundedFrameScanError.malformedHierarchy
            }

            let declaredMappingCount = Int(readUInt32BE(cmas.data, at: 0))
            let mappingFrames = try parser.parseFrames(from: cmas.data.subdata(in: 4..<cmas.data.count))
            guard mappingFrames.count == declaredMappingCount,
                  mappingFrames.allSatisfy({ $0.identifier == "CMAI" }) else {
                throw BoundedFrameScanError.malformedHierarchy
            }

            for cmai in mappingFrames {
                guard cmai.data.count >= 20 else { throw BoundedFrameScanError.malformedHierarchy }
                let cmadFrames = try parser.parseFrames(from: cmai.data.subdata(in: 12..<cmai.data.count))
                guard cmadFrames.count == 1, let cmad = cmadFrames.first,
                      cmad.identifier == "CMAD", cmad.data.count >= 16 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                result.append((
                    commandID: readUInt32BE(cmai.data, at: 8),
                    target: Int32(bitPattern: readUInt32BE(cmad.data, at: 12))
                ))
            }
        }
        return result
    }

    private func readUInt32BE(_ data: Data, at offset: Int) -> UInt32 {
        data.subdata(in: offset..<(offset + 4)).reduce(UInt32(0)) {
            ($0 << 8) | UInt32($1)
        }
    }

    /// Write a MappingEntry through TSIWriter, parse it back through TSIInterpreter,
    /// and return the first mapping from the result.
    private func roundTrip(_ entry: MappingEntry) throws -> MappingEntry? {
        try roundTripDevice(Device(name: "Test", mappings: [entry]))?.mappings.first
    }

    func testUnknownPositiveCommandIDRoundTripsWithComment() throws {
        let source = MappingEntry(
            commandID: 4242,
            ioType: .input,
            assignment: .deckC,
            interactionMode: .hold,
            midiChannel: 3,
            midiCC: 17,
            comment: "Keep this legacy macro"
        )
        let tsi = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: [source])])
        )
        let result = try interpretTSIData(tsi)
        let decoded = try XCTUnwrap(result.devices.first?.mappings.first)

        XCTAssertEqual(decoded.commandID, 4242)
        XCTAssertEqual(decoded.comment, "Keep this legacy macro")
        XCTAssertEqual(decoded.assignment, .deckC)
        XCTAssertEqual(try scanCMAICommandTargets(in: tsi).map(\.commandID), [4242])
    }

    func testWriterUsesStoredIDNotDisplayNameReverseLookup() throws {
        let source = MappingEntry(commandID: 201, midiChannel: 1, midiCC: 12)
        let tsi = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: [source])])
        )
        let decoded = try XCTUnwrap(try interpretTSIData(tsi).devices.first?.mappings.first)
        XCTAssertEqual(decoded.commandID, 201)
        XCTAssertEqual(decoded.commandName, "Reverse Playback On")
    }

    func testWriterDoesNotUseAmbiguousLegacyNameLookup() throws {
        // "Beat Phase" is the catalog's one audited duplicate label. Legacy
        // name migration intentionally resolves it to 2251, while a raw TSI
        // row with authoritative ID 513 must remain 513 at the binary boundary.
        let source = MappingEntry(commandID: 513, ioType: .output, midiChannel: 1, midiCC: 13)
        let tsi = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: [source])])
        )
        let raw = try scanCMAICommandTargets(in: tsi)
        XCTAssertEqual(raw.map(\.commandID), [513])
        XCTAssertEqual(try interpretTSIData(tsi).devices.first?.mappings.first?.commandID, 513)
    }

    func testMeterIDAndDeckTargetRemainIndependent() throws {
        let decks: [TargetAssignment] = [.deckA, .deckB, .deckC, .deckD]
        let rows = decks.map {
            MappingEntry(
                commandID: 2688,
                ioType: .output,
                assignment: $0,
                midiChannel: 1,
                midiCC: 20
            )
        }
        let tsi = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)])
        )
        let result = try roundTripEntries(rows)
        XCTAssertEqual(result.map(\.commandID), [2688, 2688, 2688, 2688])
        XCTAssertEqual(result.map(\.assignment), decks)
        let rawPairs = try scanCMAICommandTargets(in: tsi)
        XCTAssertEqual(rawPairs.map(\.commandID), [2688, 2688, 2688, 2688])
        XCTAssertEqual(rawPairs.map(\.target), [0, 1, 2, 3])
    }

    func testCommandIDOutsideTSIUInt32RangeThrows() {
        let invalidID = Int(UInt32.max) + 1
        let row = MappingEntry(commandID: invalidID, midiChannel: 1, midiCC: 1)
        XCTAssertThrowsError(
            try TSIWriter().write(MappingFile(devices: [Device(mappings: [row])]))
        ) {
            XCTAssertEqual($0 as? TSIWriterError, .invalidCommandID(invalidID))
        }
    }

    func testRawLegacySlotIDIsPreservedInsteadOfRewritten() throws {
        var cmad = validCMAD()
        cmad.replaceSubrange(12..<16, with: be32(0))
        let cmai = cmaiPayload(commandId: 2900, cmadBytes: rawFrame("CMAD", cmad))
        let file = try interpretCMAS(be32(1) + rawFrame("CMAI", cmai))
        let mapping = try XCTUnwrap(file.devices.first?.mappings.first)

        XCTAssertEqual(mapping.commandID, 2900)
        XCTAssertEqual(mapping.commandName, "Unknown command #2900")
        XCTAssertEqual(mapping.assignment, .deckA)
    }

    func testAddMenusExposeOnlyDirectionVerifiedDescriptorsAndPassIDs() throws {
        var selectedIDs: [Int] = []
        let inputMenu = V2AddCommandMenuButton(
            icon: "arrow.down",
            label: "IN",
            tooltip: "Input",
            isDisabled: false,
            direction: .input
        ) { selectedIDs.append($0.id) }
        let outputMenu = V2AddCommandMenuButton(
            icon: "arrow.up",
            label: "OUT",
            tooltip: "Output",
            isDisabled: false,
            direction: .output
        ) { selectedIDs.append($0.id) }
        let pairMenu = V2AddCommandMenuIconButton(
            icon: "arrow.up.arrow.down",
            tooltip: "Pair",
            isDisabled: false,
            direction: .all
        ) { selectedIDs.append($0.id) }

        let input = CommandHierarchy.flatten(inputMenu.commandCategories)
        let output = CommandHierarchy.flatten(outputMenu.commandCategories)
        let paired = CommandHierarchy.flatten(pairMenu.commandCategories)
        XCTAssertTrue(input.allSatisfy {
            $0.verification == .verifiedTraktor441 && $0.supports(.input)
        })
        XCTAssertTrue(output.allSatisfy {
            $0.verification == .verifiedTraktor441 && $0.supports(.output)
        })
        XCTAssertTrue(paired.allSatisfy {
            $0.verification == .verifiedTraktor441 && $0.supports(.all)
        })
        XCTAssertFalse(input.contains { $0.id == 247 })
        XCTAssertFalse(output.contains { $0.id == 232 })

        inputMenu.onCommandSelected(try XCTUnwrap(input.first { $0.id == 232 }))
        outputMenu.onCommandSelected(try XCTUnwrap(output.first { $0.id == 247 }))
        pairMenu.onCommandSelected(try XCTUnwrap(paired.first { $0.id == 206 }))
        XCTAssertEqual(selectedIDs, [232, 247, 206])
    }

    func testRoundTripPreservesInteractionModes() throws {
        let modes: [InteractionMode] = [.trigger, .toggle, .hold, .direct, .relative, .increment, .decrement, .reset, .output]
        for mode in modes {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: mode == .output ? .output : .input,
                assignment: .deckA,
                interactionMode: mode,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.interactionMode, mode, "InteractionMode \(mode) did not survive round-trip")
        }
    }

    func testRoundTripPreservesControllerTypes() throws {
        let types: [ControllerType] = [.button, .faderOrKnob, .encoder, .led]
        for ctrlType in types {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: ctrlType == .led ? .output : .input,
                assignment: .deckA,
                interactionMode: ctrlType.defaultInteractionMode,
                midiChannel: 1,
                midiCC: 10,
                controllerType: ctrlType
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.controllerType, ctrlType, "ControllerType \(ctrlType) did not survive round-trip")
        }
    }

    func testRoundTripPreservesAssignments() throws {
        // .global and .deckA both encode as 0 — that's a TSI spec limitation, not a bug.
        // FX units encode as 4-7.
        let assignments: [TargetAssignment] = [.deviceTarget, .deckA, .deckB, .deckC, .deckD, .fxUnit1, .fxUnit2, .fxUnit3, .fxUnit4]
        for assign in assignments {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input, assignment: assign,
                interactionMode: .hold,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, assign, "TargetAssignment \(assign) did not survive round-trip")
        }
    }

    func testRoundTripFXUnitAssignments() throws {
        let fxAssignments: [TargetAssignment] = [.fxUnit1, .fxUnit2, .fxUnit3, .fxUnit4]

        for assignment in fxAssignments {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input,
                assignment: assignment,
                interactionMode: .toggle,
                midiChannel: 1,
                midiCC: 1,
                controllerType: .button
            )

            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, assignment,
                           "\(assignment.displayName) did not round-trip correctly")
        }
    }

    // MARK: - Modifier Condition Round-Trip Tests (Task 1.1)

    func testRoundTripPreservesModifier1Only() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            modifier1Condition: ModifierCondition(modifier: 2, value: 3)
        )
        let result = try roundTrip(entry)
        XCTAssertEqual(result?.modifier1Condition, ModifierCondition(modifier: 2, value: 3))
        XCTAssertNil(result?.modifier2Condition)
    }

    func testRoundTripPreservesModifier2Only() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            modifier2Condition: ModifierCondition(modifier: 4, value: 5)
        )
        let result = try roundTrip(entry)
        XCTAssertNil(result?.modifier1Condition)
        XCTAssertEqual(result?.modifier2Condition, ModifierCondition(modifier: 4, value: 5))
    }

    func testRoundTripPreservesBothModifiersWithComment() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10,
            modifier1Condition: ModifierCondition(modifier: 1, value: 7),
            modifier2Condition: ModifierCondition(modifier: 8, value: 2),
            comment: "shifted action"
        )
        let result = try roundTrip(entry)
        XCTAssertEqual(result?.modifier1Condition, ModifierCondition(modifier: 1, value: 7))
        XCTAssertEqual(result?.modifier2Condition, ModifierCondition(modifier: 8, value: 2))
        XCTAssertEqual(result?.comment, "shifted action")
    }

    func testRoundTripPreservesNoModifiers() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .hold,
            midiChannel: 1,
            midiCC: 10
        )
        let result = try roundTrip(entry)
        XCTAssertNil(result?.modifier1Condition)
        XCTAssertNil(result?.modifier2Condition)
    }

    // MARK: - Unresolvable Command Filtering Tests (Task 1.2)

    func testRoundTripDropsUnresolvableMappingsAndKeepsBindingAlignment() throws {
        let invalid = MappingEntry(
            commandName: "Totally Unknown",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 5
        )
        let negative = MappingEntry(
            commandName: "Command #-1",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 6
        )
        let zero = MappingEntry(
            commandName: "Command #0",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 7
        )
        let valid = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10
        )

        let writer = TSIWriter()
        let device = Device(name: "Test", mappings: [invalid, negative, zero, valid])
        let tsiData = try writer.write(MappingFile(devices: [device]))

        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)

        let mappings = result.devices.first?.mappings ?? []
        XCTAssertEqual(mappings.count, 1, "Only the resolvable mapping should survive")
        XCTAssertEqual(mappings.first?.commandName, "Play/Pause")
        XCTAssertEqual(mappings.first?.midiCC, 10, "Binding IDs must stay aligned after filtering")
        XCTAssertEqual(mappings.first?.midiChannel, 1)
    }

    // MARK: - Full TSI Target Value Round-Trip Tests (Task 1.3)

    func testRoundTripPreservesAllTSITargetValues() throws {
        // For each TSI deck value -1...15, use the case that ENCODES to that value
        // and assert it decodes back to the same case. .none/.global excluded —
        // both encode to 0 and decode as .deckA (documented collapse, below).
        let casesByTSIValue: [(tsiValue: Int, assignment: TargetAssignment)] = [
            (-1, .deviceTarget),
            (0, .deckA), (1, .deckB), (2, .deckC), (3, .deckD),
            (4, .fxUnit1), (5, .fxUnit2), (6, .fxUnit3), (7, .fxUnit4),
            (8, .remixSlot1), (9, .remixSlot2), (10, .remixSlot3), (11, .remixSlot4),
            (12, .remixSlot5), (13, .remixSlot6), (14, .remixSlot7), (15, .remixSlot8)
        ]
        for (tsiValue, assignment) in casesByTSIValue {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input, assignment: assignment, interactionMode: .hold,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, assignment,
                           "TSI deck value \(tsiValue) (\(assignment.displayName)) did not survive round-trip")
        }
    }

    func testRoundTripPreservesRemixSlotCommandDeckAndSlotTargets() throws {
        let cases: [(command: String, assignment: TargetAssignment)] = [
            ("Slot Volume", .remixDeckASlot1),
            ("Slot Volume", .remixDeckBSlot4),
            ("Slot Mute On", .remixDeckCSlot3),
            ("Slot FX On", .remixDeckDSlot4)
        ]

        for (command, assignment) in cases {
            let entry = MappingEntry(
                commandName: command,
                ioType: .input,
                assignment: assignment,
                interactionMode: .direct,
                midiChannel: 1,
                midiCC: 10,
                controllerType: command == "Slot Volume" ? .faderOrKnob : .button
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.commandName, command)
            XCTAssertEqual(result?.assignment, assignment,
                           "\(command) \(assignment.displayName) did not survive round-trip")
        }
    }

    func testRoundTripUsesCommandSpecificSetToValueEncoding() throws {
        let cases: [(entry: MappingEntry, expected: Float)] = [
            (MappingEntry(commandName: "Slot Volume", assignment: .remixDeckASlot1,
                          interactionMode: .direct, midiChannel: 1, midiCC: 10,
                          controllerType: .faderOrKnob), 1.0),
            (MappingEntry(commandName: "Slot Filter Adjust", assignment: .remixDeckASlot1,
                          interactionMode: .direct, midiChannel: 1, midiCC: 11,
                          controllerType: .faderOrKnob), 0.5),
            (MappingEntry(commandName: "FX Knob 1", assignment: .fxUnit1,
                          interactionMode: .direct, midiChannel: 1, midiCC: 12,
                          controllerType: .faderOrKnob), 0.0),
            (MappingEntry(commandName: "Select/Set+Store Hotcue", assignment: .deckA,
                          interactionMode: .hold, midiChannel: 1, midiCC: 13,
                          controllerType: .button, setToValue: 3), 3.0)
        ]

        for (entry, expected) in cases {
            let result = try roundTrip(entry)
            XCTAssertNotNil(result?.setToValue)
            XCTAssertEqual(result?.setToValue ?? -1, expected, accuracy: 0.0001,
                           "\(entry.commandName) setToValue did not round-trip via the command-specific encoding")
        }
    }

    func testGlobalAndNoneTargetsCollapseToDeckA() throws {
        // Documented TSI ambiguity: .global and .none both encode as deck value 0,
        // which decodes as .deckA.
        for assignment in [TargetAssignment.global, TargetAssignment.none] {
            let entry = MappingEntry(
                commandName: "Play/Pause",
                ioType: .input, assignment: assignment, interactionMode: .hold,
                midiChannel: 1, midiCC: 10
            )
            let result = try roundTrip(entry)
            XCTAssertEqual(result?.assignment, .deckA,
                           "\(assignment.displayName) should collapse to Deck A by design")
        }
    }

    // MARK: - Non-BMP Text Tests (Task 1.4)

    func testRoundTripPreservesNonBMPCommentAndDeviceName() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10,
            comment: "Fire 🔥 emoji"
        )
        let device = Device(name: "Mixer 🎛 Pro", mappings: [entry])

        var parsed: Device?
        XCTAssertNoThrow(parsed = try roundTripDevice(device))
        XCTAssertEqual(parsed?.name, "Mixer 🎛 Pro")
        XCTAssertEqual(parsed?.mappings.first?.comment, "Fire 🔥 emoji")
    }

    func testDecodeUTF16BESurrogatePair() {
        // 🔥 = U+1F525 = surrogate pair D83D DD25
        let bytes = Data([0xD8, 0x3D, 0xDD, 0x25])
        XCTAssertEqual(TSIInterpreter.decodeUTF16BE(from: bytes, at: 0, codeUnitCount: 2), "🔥")
    }

    func testDecodeUTF16BEMixedBMPAndSurrogates() {
        // "A🔥B" = 0041 D83D DD25 0042
        let bytes = Data([0x00, 0x41, 0xD8, 0x3D, 0xDD, 0x25, 0x00, 0x42])
        XCTAssertEqual(TSIInterpreter.decodeUTF16BE(from: bytes, at: 0, codeUnitCount: 4), "A🔥B")
    }

    func testDecodeUTF16BEOutOfBoundsReturnsEmpty() {
        let bytes = Data([0x00, 0x41])
        XCTAssertEqual(TSIInterpreter.decodeUTF16BE(from: bytes, at: 0, codeUnitCount: 5), "")
    }

    // MARK: - Device Metadata & CMAD Field Round-Trip Tests (Task 1.5)

    func testRoundTripPreservesDeviceMetadataAndCMADFields() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10,
            autoRepeat: true,
            ledMaxRangeData: 5,
            ledMinMidi: 10,
            ledMaxMidi: 100,
            ledInvert: true,
            resolution: 2
        )
        let device = Device(
            name: "Test",
            comment: "My controller",
            inPort: "Port A",
            outPort: "Port B",
            tsiVersion: "3.10.0",
            mappingFileRevision: 3,
            mappings: [entry]
        )

        let parsed = try roundTripDevice(device)
        XCTAssertEqual(parsed?.comment, "My controller")
        XCTAssertEqual(parsed?.inPort, "Port A")
        XCTAssertEqual(parsed?.outPort, "Port B")
        XCTAssertEqual(parsed?.tsiVersion, "3.10.0")
        XCTAssertEqual(parsed?.mappingFileRevision, 3)

        let mapping = parsed?.mappings.first
        XCTAssertEqual(mapping?.autoRepeat, true)
        XCTAssertEqual(mapping?.ledMaxRangeData, 5)
        XCTAssertEqual(mapping?.ledMinMidi, 10)
        XCTAssertEqual(mapping?.ledMaxMidi, 100)
        XCTAssertEqual(mapping?.ledInvert, true)
        XCTAssertEqual(mapping?.resolution, 2)
        // Untouched fields keep their defaults
        XCTAssertEqual(mapping?.ledMinRangeType, 1)
        XCTAssertEqual(mapping?.ledMinRangeData, 0)
        XCTAssertEqual(mapping?.ledMaxRangeType, 1)
        XCTAssertEqual(mapping?.ledBlend, false)
    }

    // MARK: - Direction-Aware DCDT Tests (Task 1.6)

    /// Scans raw TSI binary for DCDT frames, returning (controlName, midiControlType) pairs.
    private func scanDCDTEntries(in data: Data) -> [(name: String, controlType: Int)] {
        var entries: [(String, Int)] = []
        var offset = 0
        while offset < data.count - 8 {
            let marker = data.subdata(in: offset..<(offset + 4))
            guard String(data: marker, encoding: .ascii) == "DCDT" else {
                offset += 1
                continue
            }
            let size = Int(data.subdata(in: (offset + 4)..<(offset + 8)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            guard size > 8, offset + 8 + size <= data.count else {
                offset += 1
                continue
            }
            let frameData = data.subdata(in: (offset + 8)..<(offset + 8 + size))
            let strLen = Int(frameData.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            if strLen > 0, 4 + strLen * 2 + 4 <= frameData.count {
                let name = TSIInterpreter.decodeUTF16BE(from: frameData, at: 4, codeUnitCount: strLen)
                let typeOffset = 4 + strLen * 2
                let controlType = Int(frameData.subdata(in: typeOffset..<(typeOffset + 4)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
                entries.append((name, controlType))
            }
            offset += 8 + size
        }
        return entries
    }

    func testDCDTEmitsDirectionAwareEntriesForSharedControl() throws {
        let inMapping = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 20, controllerType: .button
        )
        let outMapping = MappingEntry(
            commandName: "Is Playing",
            ioType: .output, assignment: .deckA, interactionMode: .output,
            midiChannel: 1, midiCC: 20, controllerType: .led
        )
        let device = Device(name: "Test", mappings: [inMapping, outMapping])

        let writer = TSIWriter()
        let tsiData = try writer.write(MappingFile(devices: [device]))
        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        let binaryData = try parser.decodeBase64(base64)

        let dcdtEntries = scanDCDTEntries(in: binaryData)
        XCTAssertEqual(dcdtEntries.count, 2, "Expected one DCDT per (control, direction) pair")
        XCTAssertTrue(dcdtEntries.contains { $0.name == "Ch01.CC.020" && $0.controlType == 7 },
                      "Missing IN entry (MidiControlType 7) for Ch01.CC.020")
        XCTAssertTrue(dcdtEntries.contains { $0.name == "Ch01.CC.020" && $0.controlType == 8 },
                      "Missing OUT entry (MidiControlType 8) for Ch01.CC.020")

        // Both mappings must still resolve through the interpreter
        let frames = try parser.parseFrames(from: binaryData)
        let result = try TSIInterpreter.interpret(frames: frames)
        let mappings = result.devices.first?.mappings ?? []
        XCTAssertEqual(mappings.count, 2)
        XCTAssertTrue(mappings.allSatisfy { $0.midiCC == 20 && $0.midiChannel == 1 },
                      "IN/OUT pair must not shift binding indices")
    }

    func testRoundTripSetToValueZero() throws {
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input,
            assignment: .deckA,
            interactionMode: .direct,
            midiChannel: 1,
            midiCC: 7,
            controllerType: .faderOrKnob,
            setToValue: 0.0
        )

        let result = try roundTrip(entry)
        XCTAssertEqual(result?.setToValue, 0.0,
                       "setToValue of 0.0 should survive round-trip")
    }

    // MARK: - Corrupt-Frame Surfacing Tests (M10)

    /// Writes a MappingFile through TSIWriter and returns the decoded binary frame data.
    private func binaryData(for file: MappingFile) throws -> Data {
        let writer = TSIWriter()
        let tsiData = try writer.write(file)
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        return try TSIParser().decodeBase64(base64)
    }

    /// Parses binary frame data and interprets it into a MappingFile.
    private func interpretBinary(_ binary: Data) throws -> MappingFile {
        let frames = try TSIParser().parseFrames(from: binary)
        return try TSIInterpreter.interpret(frames: frames)
    }

    /// Returns every byte offset where the 4-byte ASCII marker appears.
    private func offsets(of marker: String, in data: Data) -> [Int] {
        let markerData = marker.data(using: .ascii)!
        var result: [Int] = []
        var i = 0
        while i <= data.count - 4 {
            if data.subdata(in: i..<(i + 4)) == markerData {
                result.append(i)
            }
            i += 1
        }
        return result
    }

    /// Overwrites 4 bytes at the given offset with a big-endian UInt32.
    private func writeUInt32BE(_ value: UInt32, at offset: Int, in data: inout Data) {
        var be = value.bigEndian
        data.replaceSubrange(offset..<(offset + 4), with: Data(bytes: &be, count: 4))
    }

    private func simpleEntry(cc: Int) -> MappingEntry {
        MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: cc
        )
    }

    func testTruncatedSecondDeviceThrows() throws {
        let file = MappingFile(devices: [
            Device(name: "One", mappings: [simpleEntry(cc: 1)]),
            Device(name: "Two", mappings: [simpleEntry(cc: 2)])
        ])
        var binary = try binaryData(for: file)

        let deviOffsets = offsets(of: "DEVI", in: binary)
        XCTAssertEqual(deviOffsets.count, 2, "Fixture must contain exactly two DEVI frames")

        // Inflate the second DEVI's declared size past the end of its container —
        // the equivalent of a truncated frame from the parser's perspective.
        writeUInt32BE(0x00FF_FFFF, at: deviOffsets[1] + 4, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary),
                             "A truncated DEVI frame must surface as an error, not a partial document")
    }

    func testDeviceCountMismatchThrows() throws {
        let file = MappingFile(devices: [Device(name: "One", mappings: [simpleEntry(cc: 1)])])
        var binary = try binaryData(for: file)

        let devsOffsets = offsets(of: "DEVS", in: binary)
        XCTAssertEqual(devsOffsets.count, 1)

        // DEVS data starts with a 4-byte device count — declare 2 with only 1 DEVI present.
        writeUInt32BE(2, at: devsOffsets[0] + 8, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError,
                           .deviceCountMismatch(declared: 2, parsed: 1))
        }
    }

    func testZeroDeviceFileOpensAsValidEmptyMappingFile() throws {
        let binary = try binaryData(for: MappingFile(devices: []))
        let result = try interpretBinary(binary)
        XCTAssertTrue(result.devices.isEmpty, "A zero-device file is valid and opens empty")
    }

    func testZeroMappingDeviceOpensAsValid() throws {
        let binary = try binaryData(for: MappingFile(devices: [Device(name: "Empty", mappings: [])]))
        let result = try interpretBinary(binary)
        XCTAssertEqual(result.devices.count, 1)
        XCTAssertEqual(result.devices.first?.mappings.count, 0)
    }

    func testTruncatedSecondMappingThrows() throws {
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 1), simpleEntry(cc: 2)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let cmaiOffsets = offsets(of: "CMAI", in: binary)
        XCTAssertEqual(cmaiOffsets.count, 2, "Fixture must contain exactly two CMAI frames")

        // Inflate the second CMAI's declared size beyond the CMAS payload.
        writeUInt32BE(0x00FF_FFFF, at: cmaiOffsets[1] + 4, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingItem)
        }
    }

    func testMappingCountMismatchThrows() throws {
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 1), simpleEntry(cc: 2)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let cmasOffsets = offsets(of: "CMAS", in: binary)
        XCTAssertEqual(cmasOffsets.count, 1)

        // CMAS data starts with a 4-byte mapping count — declare 3 with only 2 CMAI present.
        writeUInt32BE(3, at: cmasOffsets[0] + 8, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError,
                           .mappingCountMismatch(declared: 3, parsed: 2))
        }
    }

    func testWriterFilteredMappingsStillPassCountValidation() throws {
        // The writableMappings filter writes FEWER CMAI frames than the model
        // holds — but the CMAS count it writes is the filtered count, so the
        // new declared-vs-parsed validation must hold for written files.
        let unresolvable = MappingEntry(
            commandName: "Totally Unknown Command",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 5
        )
        let device = Device(name: "Test", mappings: [unresolvable, simpleEntry(cc: 1), simpleEntry(cc: 2)])
        let binary = try binaryData(for: MappingFile(devices: [device]))

        let result = try interpretBinary(binary)
        XCTAssertEqual(result.devices.first?.mappings.count, 2,
                       "Filtered file must round-trip cleanly under count validation")
    }

    // MARK: - Unassigned-Mapping Sentinel Tests (M9)

    /// Encodes a string as UTF-16BE bytes (how TSI stores all strings).
    private func utf16BE(_ string: String) -> Data {
        var data = Data()
        for unit in string.utf16 {
            var be = unit.bigEndian
            data.append(Data(bytes: &be, count: 2))
        }
        return data
    }

    func testUnassignedMappingRoundTripsUnassigned() throws {
        let unassigned = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1
        )
        let binary = try binaryData(for: MappingFile(devices: [Device(name: "Test", mappings: [unassigned])]))

        // No fabricated CC 0 binding or placeholder control name anywhere in the bytes
        XCTAssertNil(binary.range(of: utf16BE("Ch01.CC.000")),
                     "Writer must not fabricate a Ch01.CC.000 binding for an unassigned mapping")
        XCTAssertNil(binary.range(of: utf16BE("Ctrl_")),
                     "No fabricated Ctrl_ placeholder names may appear in written bytes")

        let result = try interpretBinary(binary)
        let mapping = result.devices.first?.mappings.first
        XCTAssertNotNil(mapping, "The unassigned mapping row must survive the round-trip")
        XCTAssertNil(mapping?.midiNote, "Unassigned must round-trip unassigned")
        XCTAssertNil(mapping?.midiCC, "Unassigned must round-trip unassigned")
        XCTAssertEqual(mapping?.commandName, "Play/Pause")
    }

    func testUnassignedMappingEmitsNoDCDTOrDCBMEntryAndSentinelBindingId() throws {
        let unassigned = MappingEntry(
            commandName: "Loop In",
            ioType: .input, assignment: .deckA, interactionMode: .trigger,
            midiChannel: 1
        )
        let assigned = simpleEntry(cc: 20)
        let binary = try binaryData(for: MappingFile(devices: [Device(name: "Test", mappings: [unassigned, assigned])]))

        // Only the assigned control gets a DCDT definition
        let dcdtEntries = scanDCDTEntries(in: binary)
        XCTAssertEqual(dcdtEntries.count, 1, "Unassigned mappings must not get DCDT entries")
        XCTAssertEqual(dcdtEntries.first?.name, "Ch01.CC.020")

        // DCBM: one outer list frame + exactly one nested binding frame
        XCTAssertEqual(offsets(of: "DCBM", in: binary).count, 2,
                       "Unassigned mappings must not get DCBM binding entries")

        // The unassigned mapping's CMAI carries the 0xFFFFFFFF sentinel
        let cmaiOffsets = offsets(of: "CMAI", in: binary)
        XCTAssertEqual(cmaiOffsets.count, 2)
        let bindingIds = cmaiOffsets.map { offset in
            binary.subdata(in: (offset + 8)..<(offset + 12)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        }
        XCTAssertTrue(bindingIds.contains(TSIBindingID.unassigned),
                      "Unassigned mapping must write the 0xFFFFFFFF sentinel binding ID")

        // Both rows survive: assigned keeps its CC, unassigned stays unassigned
        let result = try interpretBinary(binary)
        let mappings = result.devices.first?.mappings ?? []
        XCTAssertEqual(mappings.count, 2)
        XCTAssertEqual(mappings.first { $0.commandName == "Play/Pause" }?.midiCC, 20)
        XCTAssertNil(mappings.first { $0.commandName == "Loop In" }?.midiCC)
        XCTAssertNil(mappings.first { $0.commandName == "Loop In" }?.midiNote)
    }

    // MARK: - Structural DCBM Parsing Tests

    func testInvalidDCBMControlRangesReportExactOffendingName() throws {
        let invalidNames = [
            "Ch00.CC.001",
            "Ch17.CC.001",
            "Ch01.CC.128",
            "Ch01.Note.C10",
            "Ch01.Note.C-9223372036854775808",
            "Ch01.Note.C9223372036854775807",
        ]

        for name in invalidNames {
            XCTAssertThrowsError(try interpretSingleDCBMControl(named: name), name) { error in
                XCTAssertEqual(
                    error as? TSIInterpreterError,
                    .unrecognizedMidiControl(name: name)
                )
            }
        }
    }

    func testValidDCBMControlBoundariesProduceValidatedAssignments() throws {
        let cases: [(name: String, expected: MIDIAssignment)] = [
            ("Ch01.Note.C-1", try .note(channel: 1, number: 0)),
            ("Ch16.Note.G9", try .note(channel: 16, number: 127)),
            ("Ch01.CC.000", try .controlChange(channel: 1, number: 0)),
            ("Ch16.CC.127", try .controlChange(channel: 16, number: 127)),
        ]

        for testCase in cases {
            let result = try interpretSingleDCBMControl(named: testCase.name)
            XCTAssertEqual(
                result.devices.first?.mappings.first?.midiAssignment,
                testCase.expected,
                testCase.name
            )
        }
    }

    private func interpretSingleDCBMControl(named name: String) throws -> MappingFile {
        let cmai = cmaiPayload(
            bindingId: 0,
            commandId: 100,
            cmadBytes: rawFrame("CMAD", validCMAD())
        )
        let binding = rawFrame("DCBM", be32(0) + tsiString(name))
        let deviPayload = tsiString("Test")
            + rawFrame("CMAS", be32(1) + rawFrame("CMAI", cmai))
            + rawFrame("DCBM", be32(1) + binding)
        return try interpretDEVI(deviPayload)
    }

    func testSharedControlBindingIdsResolveThroughDCBMNotDCDT() throws {
        // Regression: mappings [IN CC20, OUT CC20, IN CC30] write DCBM ids
        // {CC20: 0, CC30: 1}, but the direction-aware DCDT rows are
        // [CC20|in, CC20|out, CC30|in]. Resolving binding id 1 through DCDT
        // order returns CC20-out — the third mapping silently reloads as CC20.
        // DCBM must be the sole authority for binding-id resolution.
        let inCC20 = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 20, controllerType: .button
        )
        let outCC20 = MappingEntry(
            commandName: "Is Playing",
            ioType: .output, assignment: .deckA, interactionMode: .output,
            midiChannel: 1, midiCC: 20, controllerType: .led
        )
        let inCC30 = MappingEntry(
            commandName: "Loop In",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 30, controllerType: .button
        )

        let parsed = try roundTripDevice(Device(name: "Test", mappings: [inCC20, outCC20, inCC30]))
        let mappings = parsed?.mappings ?? []
        XCTAssertEqual(mappings.count, 3)
        XCTAssertEqual(mappings.first { $0.commandName == "Loop In" }?.midiCC, 30,
                       "Third mapping must reload as CC30 — DCDT-order fallback returns CC20")
        XCTAssertEqual(mappings.filter { $0.midiCC == 20 }.count, 2)
    }

    func testLargeDCBMListParsesStructurally() throws {
        // 40 distinct controls push the outer DCBM list well past the old
        // 500-byte heuristic cap; the structural parse must resolve every binding.
        let mappings = (1...40).map { simpleEntry(cc: $0) }
        let parsed = try roundTripDevice(Device(name: "Test", mappings: mappings))
        let ccs = Set((parsed?.mappings ?? []).compactMap(\.midiCC))
        XCTAssertEqual(ccs, Set(1...40), "Every binding must resolve to its own CC")
    }

    func testStrippedDCBMWithIntactDCDTThrows() throws {
        // M9: with the DCBM binding list gone, a non-sentinel CMAI id must NOT
        // quietly resolve through the DCDT control table — that fallback let
        // corrupt files open (and rebind controls). It must throw.
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let dcbmOffsets = offsets(of: "DCBM", in: binary)
        XCTAssertEqual(dcbmOffsets.count, 2, "Fixture must contain the outer list + one nested binding")
        XCTAssertEqual(offsets(of: "DCDT", in: binary).count, 1, "DCDT must remain intact")

        // Rename every DCBM identifier — all frame sizes stay valid, the
        // binding list simply no longer exists.
        for offset in dcbmOffsets {
            binary.replaceSubrange(offset..<(offset + 4), with: "XXXX".data(using: .ascii)!)
        }

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .danglingMidiBinding(bindingId: 0))
        }
    }

    func testCorruptDCBMBindingEntryThrows() throws {
        // Under the structural-parse contract a malformed binding entry is
        // corruption and throws — it is never silently skipped (the heuristic
        // skip converted into a fatal dangling-binding error downstream anyway).
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let dcbmOffsets = offsets(of: "DCBM", in: binary)
        XCTAssertEqual(dcbmOffsets.count, 2)

        // Nested binding payload is BindingId (4) then the string length
        // prefix (4) — blow out the string length so the entry can't be read.
        writeUInt32BE(0x00FF_FFFF, at: dcbmOffsets[1] + 12, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMidiBindingList)
        }
    }

    func testDCBMCountMismatchThrows() throws {
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let dcbmOffsets = offsets(of: "DCBM", in: binary)
        XCTAssertEqual(dcbmOffsets.count, 2)

        // Outer DCBM payload starts with the binding count — declare 9 with
        // only 1 nested binding present.
        writeUInt32BE(9, at: dcbmOffsets[0] + 8, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMidiBindingList)
        }
    }

    func testTruncatedDeviceFrameThrowsInsteadOfCrashing() throws {
        // A syntactically valid DEVI frame whose payload can't hold the 4-byte
        // device-name length prefix must throw — the old byte-scan crashed
        // here building the 0..<(count - 4) scan range before it was guarded.
        let writer = TSIWriter()
        let deviPayload = Data([0x00, 0x01])
        let devi = TSIFrame(identifier: "DEVI", size: UInt32(deviPayload.count), data: deviPayload)

        var devsPayload = Data([0x00, 0x00, 0x00, 0x01]) // declared device count: 1
        devsPayload.append(writer.encodeFrames([devi]))
        let devs = TSIFrame(identifier: "DEVS", size: UInt32(devsPayload.count), data: devsPayload)

        let diomPayload = writer.encodeFrames([devs])
        let diom = TSIFrame(identifier: "DIOM", size: UInt32(diomPayload.count), data: diomPayload)

        XCTAssertThrowsError(try TSIInterpreter.interpret(frames: [diom])) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedDevice)
        }
    }

    func testDanglingBindingIdThrows() throws {
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let cmaiOffsets = offsets(of: "CMAI", in: binary)
        XCTAssertEqual(cmaiOffsets.count, 1)

        // Point the CMAI's MidiNoteBindingId at a binding that isn't in DCBM —
        // corruption, NOT "unassigned"; silently nil-ing it would erase the
        // user's MIDI assignment on the next save.
        writeUInt32BE(999, at: cmaiOffsets[0] + 8, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .danglingMidiBinding(bindingId: 999))
        }
    }

    // MARK: - Manual Fixture Builders (Chunk 1: TSI Robustness)

    /// Big-endian UInt32 as 4 bytes.
    private func be32(_ value: UInt32) -> Data {
        var be = value.bigEndian
        return Data(bytes: &be, count: 4)
    }

    /// Raw TSI frame bytes: 4-byte ASCII identifier + 4-byte size + payload.
    private func rawFrame(_ identifier: String, _ payload: Data) -> Data {
        identifier.data(using: .ascii)! + be32(UInt32(payload.count)) + payload
    }

    /// Length-prefixed UTF-16BE string (TSI wide string).
    private func tsiString(_ string: String) -> Data {
        be32(UInt32(string.utf16.count)) + utf16BE(string)
    }

    /// A structurally valid 120-byte CMAD payload (DeviceType 4 = GenericMidi,
    /// then zeros = Button, Trigger, Deck A, no comment, no modifiers,
    /// zeroed LED block).
    private func validCMAD() -> Data {
        var cmad = Data(count: 120)
        cmad.replaceSubrange(0..<4, with: be32(4))
        return cmad
    }

    /// CMAI payload: 12-byte header (bindingId, ioType, commandId) + CMAD bytes.
    private func cmaiPayload(bindingId: UInt32 = TSIBindingID.unassigned,
                             ioType: UInt32 = 0,
                             commandId: UInt32 = 2,
                             cmadBytes: Data) -> Data {
        be32(bindingId) + be32(ioType) + be32(commandId) + cmadBytes
    }

    /// Wraps a CMAS payload in a minimal DEVI("Test")/DEVS/DIOM hierarchy
    /// and runs the interpreter on it.
    private func interpretCMAS(_ cmasPayload: Data) throws -> MappingFile {
        try interpretDEVI(tsiString("Test") + rawFrame("CMAS", cmasPayload))
    }

    /// Wraps a DEVI payload in a DEVS/DIOM hierarchy and interprets it.
    private func interpretDEVI(_ deviPayload: Data) throws -> MappingFile {
        let devsPayload = be32(1) + rawFrame("DEVI", deviPayload)
        return try interpretDIOM(rawFrame("DEVS", devsPayload))
    }

    /// Wraps a DIOM payload and interprets it via the real frame parser.
    private func interpretDIOM(_ diomPayload: Data) throws -> MappingFile {
        let frames = try TSIParser().parseFrames(from: rawFrame("DIOM", diomPayload))
        return try TSIInterpreter.interpret(frames: frames)
    }

    // MARK: - CMAD Structural Corruption Tests (Chunk 1, Finding 1)

    func testMissingCMADThrows() {
        // 12-byte header followed by a non-CMAD frame — the old code fell
        // through to a mapping with DEFAULT settings and saved over the user's.
        let cmai = cmaiPayload(cmadBytes: rawFrame("XMAD", validCMAD()))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingData)
        }
    }

    func testHeaderOnlyCMADThrows() {
        // CMAD payload of 8 bytes can't hold the 52-byte fixed header.
        let cmai = cmaiPayload(cmadBytes: rawFrame("CMAD", Data(count: 8)))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingData)
        }
    }

    func testZeroSizeCMADThrows() {
        let cmai = cmaiPayload(cmadBytes: rawFrame("CMAD", Data()))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingData)
        }
    }

    func testOversizedCMADThrows() {
        // Declared CMAD size overruns the CMAI container.
        let cmai = cmaiPayload(cmadBytes: "CMAD".data(using: .ascii)! + be32(0xFFFF) + validCMAD())
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingData)
        }
    }

    func testTrailingBytesAfterCMADInsideCMAIThrow() {
        // CMAD must fill the CMAI payload exactly — stray bytes after it are
        // corruption that a save would silently drop.
        let cmai = cmaiPayload(cmadBytes: rawFrame("CMAD", validCMAD()) + Data([0xDE, 0xAD, 0xBE, 0xEF]))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingData)
        }
    }

    func testTruncatedCMADCommentThrows() {
        // CommentLength (bytes 48-51) declares 100 chars but only 8 bytes follow.
        var cmad = Data(count: 60)
        cmad.replaceSubrange(0..<4, with: be32(4)) // valid DeviceType
        cmad.replaceSubrange(48..<52, with: be32(100))
        let cmai = cmaiPayload(cmadBytes: rawFrame("CMAD", cmad))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingData)
        }
    }

    func testLongCommentRoundTrips() throws {
        // The old `< 1000` comment-length cap silently DROPPED comments of
        // 1000+ characters on load. The byte-bound check replaced it.
        let longComment = String(repeating: "x", count: 1200)
        let entry = MappingEntry(
            commandName: "Play/Pause",
            ioType: .input, assignment: .deckA, interactionMode: .hold,
            midiChannel: 1, midiCC: 10,
            comment: longComment
        )
        let result = try roundTrip(entry)
        XCTAssertEqual(result?.comment, longComment, "1200-char comment must survive the round-trip")
    }

    func testCommandZeroPlaceholderRowWithValidCMADIsSkippedNotFatal() throws {
        // Command ID 0 marks a placeholder row (no command assigned) — a
        // documented skip, not corruption. Its CMAD is still validated.
        let cmai = cmaiPayload(commandId: 0, cmadBytes: rawFrame("CMAD", validCMAD()))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        let result = try interpretCMAS(cmas)
        XCTAssertEqual(result.devices.first?.mappings.count, 0)
    }

    // MARK: - Trailing-Garbage Tests (Chunk 1, Finding 2)

    func testTrailingGarbageAfterCMAIFramesThrows() {
        let cmai = cmaiPayload(cmadBytes: rawFrame("CMAD", validCMAD()))
        let cmas = be32(1) + rawFrame("CMAI", cmai) + Data([0xDE, 0xAD, 0xBE])
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingsList)
        }
    }

    func testNonCMAIFrameInsideCMASThrows() {
        let cmas = be32(1) + rawFrame("XXXX", cmaiPayload(cmadBytes: rawFrame("CMAD", validCMAD())))
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMappingsList)
        }
    }

    func testTrailingGarbageAfterDEVIFramesThrows() {
        // 1-7 stray bytes after the last DEVI used to pass silently and
        // vanish on save.
        let deviPayload = tsiString("Test") + rawFrame("CMAS", be32(0))
        let devsPayload = be32(1) + rawFrame("DEVI", deviPayload) + Data([0x01, 0x02, 0x03, 0x04, 0x05])
        XCTAssertThrowsError(try interpretDIOM(rawFrame("DEVS", devsPayload))) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .unexpectedTrailingBytes(context: "DEVS"))
        }
    }

    func testTrailingGarbageInsideDIOMThrows() {
        let diomPayload = rawFrame("DEVS", be32(0)) + Data([0xAB, 0xCD, 0xEF])
        XCTAssertThrowsError(try interpretDIOM(diomPayload)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .unexpectedTrailingBytes(context: "DIOM"))
        }
    }

    func testUnknownWellformedFrameInsideDEVSIsSkipped() throws {
        // Real Traktor writes frame types this app doesn't model — an
        // unknown frame with a parseable header+size is skipped (and does
        // not count toward the declared DEVI device count).
        let devsPayload = be32(1)
            + rawFrame("ZZZZ", Data([0x01, 0x02]))
            + rawFrame("DEVI", tsiString("Test") + rawFrame("CMAS", be32(0)))
        let result = try interpretDIOM(rawFrame("DEVS", devsPayload))
        XCTAssertEqual(result.devices.count, 1)
        XCTAssertEqual(result.devices.first?.name, "Test")
    }

    func testTruncatedUnknownFrameInsideDEVSThrows() {
        // Tolerance is gated on structural wellformedness — an unknown frame
        // whose declared size overruns the container is still corruption.
        let devsPayload = be32(0) + "ZZZZ".data(using: .ascii)! + be32(100)
        XCTAssertThrowsError(try interpretDIOM(rawFrame("DEVS", devsPayload)))
    }

    // MARK: - DCBM Full-Consumption Test (Chunk 1, Finding 3)

    func testDCBMUndercountWithTrailingBindingBytesThrows() throws {
        // Lower the outer DCBM count from 1 to 0 — the nested binding bytes
        // are then trailing garbage the old parse silently accepted (and a
        // save dropped).
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let dcbmOffsets = offsets(of: "DCBM", in: binary)
        XCTAssertEqual(dcbmOffsets.count, 2)
        writeUInt32BE(0, at: dcbmOffsets[0] + 8, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMidiBindingList)
        }
    }

    // MARK: - DEVI Frame-Walk Tests (no byte-scan)

    func testCorruptDDCBDeclaredSizeThrows() throws {
        // Inflate the DDCB wrapper's declared size. The old byte-scan never
        // read it — it found the inner CMAS/DCBM markers anyway, so this
        // structural corruption opened fine. The frame walk must throw.
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let ddcbOffsets = offsets(of: "DDCB", in: binary)
        XCTAssertEqual(ddcbOffsets.count, 1, "Fixture must contain exactly one DDCB frame")
        writeUInt32BE(0x00FF_FFFF, at: ddcbOffsets[0] + 4, in: &binary)

        XCTAssertThrowsError(try interpretBinary(binary),
                             "A DDCB whose declared size overruns its container must surface as corruption")
    }

    func testUnknownFrameEmbeddingCMASBytesDoesNotMisparse() throws {
        // An unknown-but-wellformed frame whose payload coincidentally
        // contains the ASCII bytes "CMAS" — the old byte-scan latched onto
        // the embedded marker and misparsed. The walk skips the unknown
        // frame whole and the REAL CMAS (and DCBM) must parse.
        let decoy = "CMAS".data(using: .ascii)! + be32(0xFFFF_FFFF)
        let cmai = cmaiPayload(bindingId: 0, cmadBytes: rawFrame("CMAD", validCMAD()))
        let dcbmEntry = rawFrame("DCBM", be32(0) + tsiString("Ch01.CC.042"))
        let deviPayload = tsiString("Test")
            + rawFrame("ZZZZ", decoy)
            + rawFrame("CMAS", be32(1) + rawFrame("CMAI", cmai))
            + rawFrame("DCBM", be32(1) + dcbmEntry)

        let result = try interpretDEVI(deviPayload)
        let mappings = result.devices.first?.mappings ?? []
        XCTAssertEqual(mappings.count, 1, "The real CMAS must parse despite the decoy bytes")
        XCTAssertEqual(mappings.first?.midiCC, 42, "Binding must resolve through the real DCBM")
        XCTAssertEqual(mappings.first?.midiChannel, 1)
    }

    func testDuplicateDCBMBindingIdsThrow() throws {
        // Two nested DCBM entries carrying the SAME BindingId — a last-wins
        // overwrite would silently rebind every CMAI referencing the id and
        // persist the wrong MIDI control on the next save.
        let entry1 = rawFrame("DCBM", be32(0) + tsiString("Ch01.CC.010"))
        let entry2 = rawFrame("DCBM", be32(0) + tsiString("Ch01.CC.020"))
        let cmai = cmaiPayload(bindingId: 0, cmadBytes: rawFrame("CMAD", validCMAD()))
        let deviPayload = tsiString("Test")
            + rawFrame("CMAS", be32(1) + rawFrame("CMAI", cmai))
            + rawFrame("DCBM", be32(2) + entry1 + entry2)

        XCTAssertThrowsError(try interpretDEVI(deviPayload)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedMidiBindingList)
        }
    }

    // MARK: - Structural Audit Tests (Chunk 1, systematic pass)

    func testEmptyFrameStreamThrowsMissingDIOM() {
        // No DIOM means no document — returning an empty MappingFile let a
        // later save wipe the user's file.
        XCTAssertThrowsError(try TSIInterpreter.interpret(frames: [])) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .missingDeviceIOMappings)
        }
    }

    func testUnknownTopLevelFrameAloneStillThrowsMissingDIOM() {
        // Skipping unknown frames must not turn a DIOM-less stream into an
        // empty document.
        let junk = TSIFrame(identifier: "XXXX", size: 0, data: Data())
        XCTAssertThrowsError(try TSIInterpreter.interpret(frames: [junk])) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .missingDeviceIOMappings)
        }
    }

    func testUnknownTopLevelFrameAlongsideDIOMIsSkipped() throws {
        // An unknown-but-wellformed frame next to a valid DIOM is tolerated.
        let junk = TSIFrame(identifier: "XXXX", size: 0, data: Data())
        let diomPayload = rawFrame("DEVS", be32(0))
        let diom = TSIFrame(identifier: "DIOM", size: UInt32(diomPayload.count), data: diomPayload)
        let result = try TSIInterpreter.interpret(frames: [junk, diom])
        XCTAssertEqual(result.devices.count, 0)
    }

    func testDIOMWithoutDEVSThrows() {
        // DIOI alone — the devices container is required.
        XCTAssertThrowsError(try interpretDIOM(rawFrame("DIOI", be32(1)))) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .missingDevicesContainer)
        }
    }

    func testUnknownWellformedFrameInsideDIOMIsSkipped() throws {
        // Unknown-but-wellformed frames inside DIOM are tolerated as long
        // as the required DEVS parses. (Truncation/trailing garbage inside
        // DIOM still throws — see testTrailingGarbageInsideDIOMThrows.)
        let diomPayload = rawFrame("DEVS", be32(0)) + rawFrame("QQQQ", Data([0xAA]))
        let result = try interpretDIOM(diomPayload)
        XCTAssertEqual(result.devices.count, 0)
    }

    func testDeviceWithoutCMASThrows() {
        // The writer (and Traktor) always emit a CMAS, even with zero
        // mappings — a DEVI without one lost its mappings to corruption, and
        // opening it as "empty" would let the next save wipe them for good.
        XCTAssertThrowsError(try interpretDEVI(tsiString("Test"))) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .missingMappingsList)
        }
    }

    func testUnrecognizedDCBMControlNameThrows() throws {
        // Corrupt the bound control's name so it is neither CC nor Note —
        // the old fallback quietly produced an UNASSIGNED mapping, erasing
        // the user's MIDI assignment on the next save.
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let original = utf16BE("Ch01.CC.010")
        let corrupted = utf16BE("Ch01.XX.010")
        var replaced = 0
        while let range = binary.range(of: original) {
            binary.replaceSubrange(range, with: corrupted)
            replaced += 1
        }
        XCTAssertGreaterThan(replaced, 0, "Fixture must contain the control name")

        XCTAssertThrowsError(try interpretBinary(binary)) { error in
            XCTAssertEqual(error as? TSIInterpreterError,
                           .unrecognizedMidiControl(name: "Ch01.XX.010"))
        }
    }

    /// Builds a CMAS whose single CMAI carries a 120-byte CMAD with one
    /// 4-byte field overridden at the given offset.
    private func cmasWithCMADField(at offset: Int, value: UInt32) -> Data {
        var cmad = validCMAD()
        cmad.replaceSubrange(offset..<(offset + 4), with: be32(value))
        let cmai = cmaiPayload(cmadBytes: rawFrame("CMAD", cmad))
        return be32(1) + rawFrame("CMAI", cmai)
    }

    func testUnknownInteractionModeCoercesToHoldForInput() throws {
        // InteractionMode lives at CMAD bytes 8-11; 99 is outside the 0-8
        // spec range. Real Traktor writes modes this app doesn't model —
        // the file must open, with the input default (.hold).
        let result = try interpretCMAS(cmasWithCMADField(at: 8, value: 99))
        XCTAssertEqual(result.devices.first?.mappings.first?.interactionMode, .hold)
    }

    func testUnknownInteractionModeCoercesToOutputForOutput() throws {
        var cmad = validCMAD()
        cmad.replaceSubrange(8..<12, with: be32(99))
        let cmai = cmaiPayload(ioType: 1, cmadBytes: rawFrame("CMAD", cmad))
        let result = try interpretCMAS(be32(1) + rawFrame("CMAI", cmai))
        XCTAssertEqual(result.devices.first?.mappings.first?.interactionMode, .output)
    }

    func testUnknownControllerTypeCoercesToButton() throws {
        // ControllerType lives at CMAD bytes 4-7; 7 is not Button/Fader/Encoder/LED.
        let result = try interpretCMAS(cmasWithCMADField(at: 4, value: 7))
        XCTAssertEqual(result.devices.first?.mappings.first?.controllerType, .button)
    }

    func testUnknownTargetDeckCoercesToGlobal() throws {
        // Target lives at CMAD bytes 12-15; 99 is outside -1...15 and
        // collapses to .global by prior design.
        let result = try interpretCMAS(cmasWithCMADField(at: 12, value: 99))
        XCTAssertEqual(result.devices.first?.mappings.first?.assignment, .global)
    }

    func testProprietaryDeviceTypeIsTolerated() throws {
        // DeviceType lives at CMAD bytes 0-3. 1-3 are real proprietary
        // Traktor values (TSI-File-Format.md) — the file must open, read
        // with the GenericMidi field layout (a documented limitation).
        let result = try interpretCMAS(cmasWithCMADField(at: 0, value: 3))
        XCTAssertEqual(result.devices.first?.mappings.count, 1)
    }

    func testUnknownCMAIMappingTypeThrows() {
        // CMAI Type field: 0 = In, 1 = Out. 5 must not coerce to .input.
        let cmai = cmaiPayload(ioType: 5, cmadBytes: rawFrame("CMAD", validCMAD()))
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        XCTAssertThrowsError(try interpretCMAS(cmas)) { error in
            XCTAssertEqual(error as? TSIInterpreterError,
                           .unsupportedFieldValue(field: "MappingType", value: 5))
        }
    }

    // MARK: - Device Metadata Corruption Tests (Chunk 1, systematic pass)

    func testTruncatedDDIVRevisionThrows() {
        // DDIV holds the version string + required MappingFileRevision int.
        // Version present, revision missing → truncation, not "default to 2".
        let deviPayload = tsiString("Test") + rawFrame("DDIV", tsiString("3.11.0"))
        XCTAssertThrowsError(try interpretDEVI(deviPayload)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedDeviceMetadata(frame: "DDIV"))
        }
    }

    func testUnderDeclaredDDIVDoesNotBorrowBytesFromNextFrame() {
        // DDIV declares a payload that holds the version string but NOT the
        // required 4-byte MappingFileRevision. An unbounded read would
        // "borrow" the next frame's header bytes ("CMAS") as the revision
        // and parse garbage — the read must stay inside the declared payload
        // and throw.
        let deviPayload = tsiString("Test")
            + rawFrame("DDIV", tsiString("3.11.0"))
            + rawFrame("CMAS", be32(0))
        XCTAssertThrowsError(try interpretDEVI(deviPayload)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedDeviceMetadata(frame: "DDIV"))
        }
    }

    func testCorruptDDICCommentThrows() {
        // DDIC present but its string length prefix overruns the data —
        // the old code silently defaulted the comment to "" (lost on save).
        let deviPayload = tsiString("Test") + rawFrame("DDIC", be32(0x000F_FFFF))
        XCTAssertThrowsError(try interpretDEVI(deviPayload)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedDeviceMetadata(frame: "DDIC"))
        }
    }

    func testTruncatedDDPTOutPortThrows() {
        // DDPT must hold BOTH port strings — a missing out port used to
        // silently default to "" and save as "All Ports".
        let deviPayload = tsiString("Test") + rawFrame("DDPT", tsiString("In Port"))
        XCTAssertThrowsError(try interpretDEVI(deviPayload)) { error in
            XCTAssertEqual(error as? TSIInterpreterError, .malformedDeviceMetadata(frame: "DDPT"))
        }
    }

    // MARK: - Helper Functions (Expose internal logic for testing)

    /// Parse MIDI control name - mirrors TSIInterpreter logic
    /// (nil mirrors the interpreter's `unrecognizedMidiControl` throw)
    private func parseMidiControlName(_ name: String) -> (channel: Int, number: Int, isCC: Bool)? {
        guard let chRange = name.range(of: "Ch"),
              let dotRange = name.range(of: ".", range: chRange.upperBound..<name.endIndex),
              let channel = Int(name[chRange.upperBound..<dotRange.lowerBound]) else {
            return nil
        }

        if let ccRange = name.range(of: ".CC.") {
            guard let cc = Int(name[ccRange.upperBound...]) else { return nil }
            return (channel, cc, true)
        }
        if let noteRange = name.range(of: ".Note.") {
            guard let note = midiNoteNumber(from: String(name[noteRange.upperBound...])) else { return nil }
            return (channel, note, false)
        }
        return nil
    }

    /// Convert note name to MIDI number - mirrors TSIInterpreter logic
    private func midiNoteNumber(from noteName: String) -> Int? {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        var note = noteName
        var octave = 0

        while let lastChar = note.last, lastChar.isNumber {
            octave = Int(String(lastChar))! + octave * 10
            note.removeLast()
        }

        if note.last == "-" {
            octave = -octave
            note.removeLast()
        }

        guard let noteIndex = noteNames.firstIndex(of: note) else { return nil }

        return (octave + 1) * 12 + noteIndex
    }

    /// Map interaction mode value - mirrors TSIInterpreter logic
    /// (unknown values coerce to the direction default, not an error)
    private func interactionMode(from value: Int, isOutput: Bool = false) -> InteractionMode {
        switch value {
        case 0: return .trigger
        case 1: return .toggle
        case 2: return .hold
        case 3: return .direct
        case 4: return .relative
        case 5: return .increment
        case 6: return .decrement
        case 7: return .reset
        case 8: return .output
        default: return isOutput ? .output : .hold
        }
    }

    /// Map controller type value - mirrors TSIInterpreter logic
    /// (unknown values coerce to .button, not an error)
    private func controllerType(from value: Int) -> ControllerType {
        switch value {
        case 0: return .button
        case 1: return .faderOrKnob
        case 2: return .encoder
        case 65535: return .led
        default: return .button
        }
    }

    /// Map target deck value - mirrors TSIInterpreter logic
    /// (unknown values collapse to .global, not an error)
    private func targetAssignment(from value: Int) -> TargetAssignment {
        switch value {
        case -1: return .deviceTarget
        case 0: return .deckA
        case 1: return .deckB
        case 2: return .deckC
        case 3: return .deckD
        case 4: return .fxUnit1
        case 5: return .fxUnit2
        case 6: return .fxUnit3
        case 7: return .fxUnit4
        case 8: return .remixSlot1
        case 9: return .remixSlot2
        case 10: return .remixSlot3
        case 11: return .remixSlot4
        case 12: return .remixSlot5
        case 13: return .remixSlot6
        case 14: return .remixSlot7
        case 15: return .remixSlot8
        default: return .global
        }
    }
}
