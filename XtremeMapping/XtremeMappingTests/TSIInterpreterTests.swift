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
        let mappingComment = "Macro layer 🧪\n𐐷 second line"
        let deviceComment = "X1 port notes 🎛\n𐐷 device line"
        let row = MappingEntry(
            commandID: 100,
            midiChannel: 1,
            midiCC: 7,
            comment: mappingComment
        )
        let device = Device(
            name: "Generic MIDI",
            comment: deviceComment,
            mappings: [row]
        )

        let decoded = try XCTUnwrap(try roundTripDevice(device))
        XCTAssertEqual(decoded.name, "Generic MIDI")
        XCTAssertEqual(decoded.comment, deviceComment)
        XCTAssertEqual(decoded.mappings.first?.comment, mappingComment)
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

    // MARK: - Direction-Aware DCDT Tests

    private struct ScannedDCDT: Equatable {
        let container: String
        let name: String
        let controlType: UInt32
        let min: Float32
        let max: Float32
        let encoderMode: UInt32
        let controlID: UInt32
    }

    /// Decodes the TSI and walks only declared frame boundaries. This helper
    /// deliberately does not search arbitrary bytes for frame markers.
    private func scanDCDTEntries(inTSI data: Data) throws -> [ScannedDCDT] {
        let parser = TSIParser()
        let base64 = try TSIParser.extractControllerData(from: data)
        let binary = try parser.decodeBase64(base64)
        let roots = try parser.parseFrames(from: binary)
        guard roots.count == 1, let diom = roots.first, diom.identifier == "DIOM" else {
            throw BoundedFrameScanError.malformedHierarchy
        }

        let diomChildren = try parser.parseFrames(from: diom.data)
        let devsFrames = diomChildren.filter { $0.identifier == "DEVS" }
        guard devsFrames.count == 1, let devs = devsFrames.first, devs.data.count >= 4 else {
            throw BoundedFrameScanError.malformedHierarchy
        }

        let declaredDeviceCount = Int(readUInt32BE(devs.data, at: 0))
        let devices = try parser.parseFrames(from: devs.data.subdata(in: 4..<devs.data.count))
        guard devices.count == declaredDeviceCount,
              devices.allSatisfy({ $0.identifier == "DEVI" }) else {
            throw BoundedFrameScanError.malformedHierarchy
        }

        var entries: [ScannedDCDT] = []
        for device in devices {
            guard device.data.count >= 4 else {
                throw BoundedFrameScanError.malformedHierarchy
            }
            let nameByteCount = Int(readUInt32BE(device.data, at: 0)) * 2
            let deviceChildrenOffset = 4 + nameByteCount
            guard deviceChildrenOffset <= device.data.count else {
                throw BoundedFrameScanError.malformedHierarchy
            }

            let deviceChildren = try parser.parseFrames(
                from: device.data.subdata(in: deviceChildrenOffset..<device.data.count)
            )
            let ddatFrames = deviceChildren.filter { $0.identifier == "DDAT" }
            guard ddatFrames.count == 1, let ddat = ddatFrames.first else {
                throw BoundedFrameScanError.malformedHierarchy
            }
            let ddatChildren = try parser.parseFrames(from: ddat.data)
            let definitionContainers = ddatChildren.filter { $0.identifier == "DDDC" }
            guard definitionContainers.count == 1, let dddc = definitionContainers.first else {
                throw BoundedFrameScanError.malformedHierarchy
            }

            for container in try parser.parseFrames(from: dddc.data) {
                guard container.identifier == "DDCI" || container.identifier == "DDCO",
                      container.data.count >= 4 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                let declaredCount = Int(readUInt32BE(container.data, at: 0))
                let frames = try parser.parseFrames(
                    from: container.data.subdata(in: 4..<container.data.count)
                )
                guard frames.count == declaredCount,
                      frames.allSatisfy({ $0.identifier == "DCDT" }) else {
                    throw BoundedFrameScanError.malformedHierarchy
                }

                for frame in frames {
                    guard frame.data.count >= 4 else {
                        throw BoundedFrameScanError.malformedHierarchy
                    }
                    let codeUnitCount = Int(readUInt32BE(frame.data, at: 0))
                    let scalarOffset = 4 + codeUnitCount * 2
                    guard scalarOffset >= 4, scalarOffset + 20 == frame.data.count else {
                        throw BoundedFrameScanError.malformedHierarchy
                    }
                    entries.append(ScannedDCDT(
                        container: container.identifier,
                        name: TSIInterpreter.decodeUTF16BE(
                            from: frame.data,
                            at: 4,
                            codeUnitCount: codeUnitCount
                        ),
                        controlType: readUInt32BE(frame.data, at: scalarOffset),
                        min: Float32(bitPattern: readUInt32BE(frame.data, at: scalarOffset + 4)),
                        max: Float32(bitPattern: readUInt32BE(frame.data, at: scalarOffset + 8)),
                        encoderMode: readUInt32BE(frame.data, at: scalarOffset + 12),
                        controlID: readUInt32BE(frame.data, at: scalarOffset + 16)
                    ))
                }
            }
        }
        return entries
    }

    private func dcdtPayload(
        name: String,
        controlType: UInt32,
        encoderMode: UInt32,
        min: Float32 = 0,
        max: Float32 = 127,
        controlID: UInt32 = .max
    ) -> Data {
        tsiString(name)
            + be32(controlType)
            + be32(min.bitPattern)
            + be32(max.bitPattern)
            + be32(encoderMode)
            + be32(controlID)
    }

    private func data(hex: String) throws -> Data {
        guard hex.count.isMultiple(of: 2) else {
            throw BoundedFrameScanError.malformedHierarchy
        }
        var result = Data()
        result.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw BoundedFrameScanError.malformedHierarchy
            }
            result.append(byte)
            index = next
        }
        return result
    }

    /// Builds a complete, structurally valid TSI with caller-supplied DDDC
    /// children and matching DCBM/CMAI bindings for every requested direction.
    private func definitionFixtureTSI(
        definitionFrames: Data,
        controlName: String = "Ch01.CC.022",
        mappingDirections: [IODirection] = [],
        tsiVersion: String? = nil
    ) -> Data {
        var mappingFrames = Data()
        for direction in mappingDirections {
            var cmad = validCMAD()
            cmad.replaceSubrange(4..<8, with: be32(2))
            cmad.replaceSubrange(8..<12, with: be32(direction == .output ? 8 : 4))
            mappingFrames.append(rawFrame(
                "CMAI",
                cmaiPayload(
                    bindingId: 0,
                    ioType: direction == .output ? 1 : 0,
                    commandId: 123,
                    cmadBytes: rawFrame("CMAD", cmad)
                )
            ))
        }

        let cmas = rawFrame("CMAS", be32(UInt32(mappingDirections.count)) + mappingFrames)
        let bindingEntries: Data
        if mappingDirections.isEmpty {
            bindingEntries = Data()
        } else {
            bindingEntries = rawFrame("DCBM", be32(0) + tsiString(controlName))
        }
        let dcbm = rawFrame(
            "DCBM",
            be32(mappingDirections.isEmpty ? 0 : 1) + bindingEntries
        )
        let ddcb = rawFrame("DDCB", cmas + dcbm)
        let versionFrame = tsiVersion.map {
            rawFrame("DDIV", tsiString($0) + be32(2))
        } ?? Data()
        let ddat = rawFrame(
            "DDAT",
            versionFrame + rawFrame("DDDC", definitionFrames) + ddcb
        )
        let devi = rawFrame("DEVI", tsiString("Generic MIDI") + ddat)
        let devs = rawFrame("DEVS", be32(1) + devi)
        let binary = rawFrame("DIOM", rawFrame("DIOI", be32(1)) + devs)
        return TSIWriter().createXML(withControllerData: binary.base64EncodedString())
    }

    func testEncoderModeUsesTraktorRawValuesWithoutChangingCodableRawValues() {
        XCTAssertEqual(EncoderMode.mode7Fh01h.rawValue, 0)
        XCTAssertEqual(EncoderMode.mode3Fh41h.rawValue, 1)
        XCTAssertEqual(EncoderMode.mode3Fh41h.tsiDCDTValue, 0)
        XCTAssertEqual(EncoderMode.mode7Fh01h.tsiDCDTValue, 1)
        XCTAssertEqual(EncoderMode(tsiDCDTValue: 0), .mode3Fh41h)
        XCTAssertEqual(EncoderMode(tsiDCDTValue: 1), .mode7Fh01h)
        XCTAssertNil(EncoderMode(tsiDCDTValue: 3))
    }

    func testInputAndOutputDefinitionsUseSeparateSiblingContainers() throws {
        let rows = [
            MappingEntry(
                commandID: 123,
                ioType: .input,
                midiChannel: 1,
                midiCC: 20,
                controllerType: .encoder,
                encoderMode: .mode3Fh41h
            ),
            MappingEntry(
                commandID: 2591,
                ioType: .output,
                midiChannel: 1,
                midiCC: 20,
                controllerType: .led,
                encoderMode: .mode7Fh01h
            ),
        ]
        let tsi = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)])
        )

        XCTAssertEqual(try scanDCDTEntries(inTSI: tsi), [
            ScannedDCDT(
                container: "DDCI",
                name: "Ch01.CC.020",
                controlType: 7,
                min: 0,
                max: 127,
                encoderMode: 0,
                controlID: .max
            ),
            ScannedDCDT(
                container: "DDCO",
                name: "Ch01.CC.020",
                controlType: 8,
                min: 0,
                max: 127,
                encoderMode: 1,
                controlID: .max
            ),
        ])
    }

    func testBothGenericEncoderModesRoundTrip() throws {
        for mode in EncoderMode.allCases {
            let source = MappingEntry(
                commandID: 123,
                interactionMode: .relative,
                midiChannel: 4,
                midiCC: 22,
                controllerType: .encoder,
                encoderMode: mode
            )
            let decoded = try XCTUnwrap(try roundTripEntries([source]).first)
            XCTAssertEqual(decoded.encoderMode, mode)
            XCTAssertNil(decoded.rawDCDTEncoderMode)
        }
    }

    func testConflictingModesForSameControlAndDirectionThrow() {
        let rows = EncoderMode.allCases.map {
            MappingEntry(
                commandID: 123,
                ioType: .input,
                midiChannel: 1,
                midiCC: 10,
                controllerType: .encoder,
                encoderMode: $0
            )
        }

        XCTAssertThrowsError(
            try TSIWriter().write(
                MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)])
            )
        ) { error in
            XCTAssertEqual(
                error as? TSIWriterError,
                .conflictingEncoderModes(controlName: "Ch01.CC.010", direction: .input)
            )
        }
    }

    func testConflictingNativeDefinitionMetadataForSameControlAndDirectionThrows() {
        let rows = [
            MappingEntry(
                commandID: 123,
                midiChannel: 1,
                midiCC: 10,
                rawDCDTControlType: 1
            ),
            MappingEntry(
                commandID: 124,
                midiChannel: 1,
                midiCC: 10,
                rawDCDTControlType: 2
            ),
        ]

        XCTAssertThrowsError(
            try TSIWriter().write(
                MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)])
            )
        ) { error in
            XCTAssertEqual(
                error as? TSIWriterError,
                .conflictingMIDIControlDefinitions(
                    controlName: "Ch01.CC.010",
                    direction: .input
                )
            )
        }
    }

    func testLiteralTraktor441DCDTPayloadsParseAndDriveInterpreterMetadata() throws {
        let cases: [(hex: String, name: String, rawMode: UInt32, expected: EncoderMode)] = [
            (
                "0000000b0043006800300031002e00430043002e003000320032000000070000000042fe000000000000ffffffff",
                "Ch01.CC.022",
                0,
                .mode3Fh41h
            ),
            (
                "0000000b0043006800300031002e00430043002e003000300030000000070000000042fe000000000001ffffffff",
                "Ch01.CC.000",
                1,
                .mode7Fh01h
            ),
        ]

        for testCase in cases {
            let payload = try data(hex: testCase.hex)
            let tsi = definitionFixtureTSI(
                definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", payload)),
                controlName: testCase.name,
                mappingDirections: [.input]
            )
            XCTAssertEqual(try scanDCDTEntries(inTSI: tsi), [
                ScannedDCDT(
                    container: "DDCI",
                    name: testCase.name,
                    controlType: 7,
                    min: 0,
                    max: 127,
                    encoderMode: testCase.rawMode,
                    controlID: .max
                )
            ])
            let mapping = try XCTUnwrap(
                try interpretTSIData(tsi).devices.first?.mappings.first
            )
            XCTAssertEqual(mapping.encoderMode, testCase.expected)
            XCTAssertNil(mapping.rawDCDTEncoderMode)
        }
    }

    func testLiteralTraktor441NativeInputControlTypesOpenAndRoundTripMetadata() throws {
        // Literal DCDT payloads captured from Traktor 4.4.1 exports and reduced
        // to one mapping each. The strings and scalar bytes are unmodified.
        let cases: [(hex: String, name: String, controlType: UInt32)] = [
            (
                "0000000d004400650063006b002000410073007300690067006e002e004100000001000000003f80000000000003ffffffff",
                "Deck Assign.A",
                1
            ),
            (
                "0000001200460058002e004b006e006f006200200031002e0050006f0073006900740069006f006e00000002000000003f80000000000003ffffffff",
                "FX.Knob 1.Position",
                2
            ),
            (
                "0000001300420072006f007700730065002e0045006e0063006f006400650072002e005400750072006e00000004000000003f80000000000003ffffffff",
                "Browse.Encoder.Turn",
                4
            ),
            (
                "000000070045006e0063006f00640065007200000005000000003f800000000000030000000d",
                "Encoder",
                5
            ),
            (
                "0000000e004c006500660074002e004a006f0067002e0053007000650065006400000010c1800000418000000000000300000012",
                "Left.Jog.Speed",
                16
            ),
        ]

        for testCase in cases {
            let payload = try data(hex: testCase.hex)
            let tsi = definitionFixtureTSI(
                definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", payload)),
                controlName: testCase.name,
                mappingDirections: [.input]
            )
            let originalDefinitions = try scanDCDTEntries(inTSI: tsi)
            let imported = try XCTUnwrap(
                try interpretTSIData(tsi).devices.first?.mappings.first
            )
            XCTAssertEqual(imported.ioType, .input)
            XCTAssertEqual(imported.rawMidiControlName, testCase.name)
            XCTAssertEqual(imported.rawDCDTControlType, testCase.controlType)

            let rewritten = try TSIWriter().write(
                MappingFile(devices: [Device(name: "Generic MIDI", mappings: [imported])])
            )
            XCTAssertEqual(try scanDCDTEntries(inTSI: rewritten), originalDefinitions)
            XCTAssertEqual(
                try interpretTSIData(rewritten).devices.first?.mappings.first?.rawMidiControlName,
                testCase.name
            )
        }
    }

    func testTraktor452OpaqueMidiNamesOpenWarnAndRoundTripVerbatim() throws {
        let names = [
            "Ch02.PitchBend",
            "Ch05.CC.034+Ch05.CC.002",
        ]

        for name in names {
            let payload = dcdtPayload(name: name, controlType: 7, encoderMode: 0)
            let tsi = definitionFixtureTSI(
                definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", payload)),
                controlName: name,
                mappingDirections: [.input],
                tsiVersion: "4.5.2"
            )
            let importedFile = try interpretTSIData(tsi)
            let imported = try XCTUnwrap(importedFile.devices.first?.mappings.first)

            XCTAssertEqual(importedFile.devices.first?.tsiVersion, "4.5.2")
            XCTAssertEqual(imported.rawMidiControlName, name)
            XCTAssertEqual(imported.mappedToDisplay, name)
            XCTAssertEqual(
                imported.tsiCompatibilityWarning,
                .opaqueMIDIControl(name: name)
            )

            let rewritten = try TSIWriter().write(importedFile)
            let reimported = try XCTUnwrap(
                try interpretTSIData(rewritten).devices.first?.mappings.first
            )
            XCTAssertEqual(reimported.rawMidiControlName, name)
            XCTAssertEqual(reimported.mappedToDisplay, name)
        }
    }

    func testDefinitionContainersRequireCountPrefix() {
        for container in ["DDCI", "DDCO"] {
            let tsi = definitionFixtureTSI(
                definitionFrames: rawFrame(container, Data([0, 0, 0]))
            )
            XCTAssertThrowsError(try interpretTSIData(tsi), container) { error in
                XCTAssertEqual(
                    error as? TSIInterpreterError,
                    .malformedMidiDefinitions(container: container)
                )
            }
        }
    }

    func testMidiDefinitionDeclaredCountMismatchThrows() {
        let payload = dcdtPayload(name: "Ch01.CC.022", controlType: 7, encoderMode: 0)
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", be32(2) + rawFrame("DCDT", payload))
        )
        XCTAssertThrowsError(try interpretTSIData(tsi)) { error in
            XCTAssertEqual(
                error as? TSIInterpreterError,
                .midiDefinitionCountMismatch(container: "DDCI", declared: 2, parsed: 1)
            )
        }
    }

    func testMidiDefinitionContainerTrailingBytesThrow() {
        let payload = dcdtPayload(name: "Ch01.CC.022", controlType: 7, encoderMode: 0)
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame(
                "DDCI",
                be32(1) + rawFrame("DCDT", payload) + Data([0xDE, 0xAD])
            )
        )
        XCTAssertThrowsError(try interpretTSIData(tsi)) { error in
            XCTAssertEqual(
                error as? TSIInterpreterError,
                .malformedMidiDefinitions(container: "DDCI")
            )
        }
    }

    func testTruncatedDCDTStringThrows() {
        let payload = be32(11) + Data([0x00, 0x43])
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", payload))
        )
        XCTAssertThrowsError(try interpretTSIData(tsi)) { error in
            XCTAssertEqual(
                error as? TSIInterpreterError,
                .malformedMidiDefinition(container: "DDCI")
            )
        }
    }

    func testTruncatedDCDTFixedScalarBlockThrows() {
        let payload = tsiString("Ch01.CC.022") + Data(count: 16)
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", payload))
        )
        XCTAssertThrowsError(try interpretTSIData(tsi)) { error in
            XCTAssertEqual(
                error as? TSIInterpreterError,
                .malformedMidiDefinition(container: "DDCI")
            )
        }
    }

    func testDuplicateDefinitionContainerForDirectionUsesFirstDocumentOrderContainer() throws {
        let emptyDefinitions = be32(0)
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", emptyDefinitions)
                + rawFrame("DDCI", emptyDefinitions)
        )
        XCTAssertNoThrow(try interpretTSIData(tsi))
    }

    func testIdenticalDuplicateControlNameAndDirectionDefinitionIsTolerated() throws {
        let payload = dcdtPayload(name: "Ch01.CC.022", controlType: 7, encoderMode: 0)
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame(
                "DDCI",
                be32(2) + rawFrame("DCDT", payload) + rawFrame("DCDT", payload)
            )
        )

        XCTAssertNoThrow(try interpretTSIData(tsi))
    }

    func testConflictingDuplicateControlNameAndDirectionDefinitionUsesLastNativeRow() throws {
        let first = dcdtPayload(name: "Ch01.CC.022", controlType: 7, encoderMode: 0)
        let second = dcdtPayload(name: "Ch01.CC.022", controlType: 2, encoderMode: 0)
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame(
                "DDCI",
                be32(2) + rawFrame("DCDT", first) + rawFrame("DCDT", second)
            ),
            mappingDirections: [.input]
        )

        let mapping = try XCTUnwrap(try interpretTSIData(tsi).devices.first?.mappings.first)
        XCTAssertEqual(mapping.rawDCDTControlType, 2)
    }

    func testDefinitionContainerDeterminesDirectionRegardlessOfControlType() throws {
        let cases: [(container: String, controlType: UInt32, direction: IODirection)] = [
            ("DDCI", 8, .input),
            ("DDCO", 7, .output),
        ]
        for testCase in cases {
            let payload = dcdtPayload(
                name: "Ch01.CC.022",
                controlType: testCase.controlType,
                encoderMode: 0
            )
            let tsi = definitionFixtureTSI(
                definitionFrames: rawFrame(
                    testCase.container,
                    be32(1) + rawFrame("DCDT", payload)
                ),
                mappingDirections: [testCase.direction]
            )
            let imported = try XCTUnwrap(
                try interpretTSIData(tsi).devices.first?.mappings.first
            )
            XCTAssertEqual(imported.ioType, testCase.direction)
            XCTAssertEqual(imported.rawDCDTControlType, testCase.controlType)
        }
    }

    func testMissingMatchingDefinitionRetainsGenericDefault() throws {
        let unrelated = dcdtPayload(
            name: "Ch01.CC.021",
            controlType: 7,
            encoderMode: 0
        )
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", unrelated)),
            controlName: "Ch01.CC.022",
            mappingDirections: [.input]
        )
        let mapping = try XCTUnwrap(
            try interpretTSIData(tsi).devices.first?.mappings.first
        )
        XCTAssertEqual(mapping.encoderMode, .mode7Fh01h)
        XCTAssertNil(mapping.rawDCDTEncoderMode)
    }

    func testUnknownRawModeRoundTripsOpaqueUntilExplicitEdit() throws {
        let unknown = dcdtPayload(
            name: "Ch01.CC.022",
            controlType: 7,
            encoderMode: 3
        )
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", unknown)),
            mappingDirections: [.input]
        )
        let imported = try XCTUnwrap(
            try interpretTSIData(tsi).devices.first?.mappings.first
        )
        XCTAssertEqual(imported.encoderMode, .mode7Fh01h)
        XCTAssertEqual(imported.rawDCDTEncoderMode, 3)
        XCTAssertEqual(imported.effectiveDCDTEncoderMode, 3)

        let codableCopy = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONEncoder().encode(imported)
        )
        XCTAssertEqual(codableCopy.rawDCDTEncoderMode, 3)

        let rewrittenTSI = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Generic MIDI", mappings: [codableCopy])])
        )
        XCTAssertEqual(try scanDCDTEntries(inTSI: rewrittenTSI).map(\.encoderMode), [3])
        let reimported = try XCTUnwrap(
            try interpretTSIData(rewrittenTSI).devices.first?.mappings.first
        )
        XCTAssertEqual(reimported.rawDCDTEncoderMode, 3)

        var edited = reimported
        edited.setEncoderMode(.mode3Fh41h)
        XCTAssertEqual(edited.encoderMode, .mode3Fh41h)
        XCTAssertNil(edited.rawDCDTEncoderMode)
        XCTAssertEqual(edited.effectiveDCDTEncoderMode, 0)
    }

    func testEncoderModeDraftOnlyWritesBackExplicitUserSelection() {
        var mapping = MappingEntry(
            commandID: 123,
            midiChannel: 1,
            midiCC: 22,
            controllerType: .encoder,
            rawDCDTEncoderMode: 3
        )
        var draft = EncoderModeDraft()

        let loadWriteback = draft.apply(.selectionLoad(mapping.encoderMode))
        if let loadWriteback {
            mapping.setEncoderMode(loadWriteback)
        }

        XCTAssertEqual(draft.value, .mode7Fh01h)
        XCTAssertNil(loadWriteback)
        XCTAssertEqual(mapping.rawDCDTEncoderMode, 3)

        // Selecting the visible fallback again is still an explicit edit. A
        // SwiftUI onChange observer would miss this same-value interaction.
        let userWriteback = draft.apply(.userSelection(.mode7Fh01h))
        if let userWriteback {
            mapping.setEncoderMode(userWriteback)
        }

        XCTAssertEqual(draft.value, .mode7Fh01h)
        XCTAssertEqual(userWriteback, .mode7Fh01h)
        XCTAssertNil(mapping.rawDCDTEncoderMode)
        XCTAssertEqual(mapping.effectiveDCDTEncoderMode, 1)
    }

    func testMIDIChannelDraftOnlyWritesBackExplicitUserSelection() {
        var mapping = MappingEntry(
            commandID: 123,
            midiChannel: 2,
            rawMidiControlName: "Ch02.PitchBend",
            rawDCDTControlType: 5
        )
        var draft = MIDIChannelDraft()

        let loadWriteback = draft.apply(.selectionLoad(mapping.midiChannel))
        if let loadWriteback {
            mapping.midiChannel = loadWriteback
        }

        XCTAssertEqual(draft.value, 2)
        XCTAssertNil(loadWriteback)
        XCTAssertEqual(mapping.rawMidiControlName, "Ch02.PitchBend")
        XCTAssertEqual(mapping.rawDCDTControlType, 5)

        let userWriteback = draft.apply(.userSelection(3))
        if let userWriteback {
            mapping.midiChannel = userWriteback
        }

        XCTAssertEqual(draft.value, 3)
        XCTAssertEqual(userWriteback, 3)
        XCTAssertNil(mapping.rawMidiControlName)
        XCTAssertNil(mapping.rawDCDTControlType)
    }

    func testLegacyCodableWithoutRawDCDTModeDefaultsToNil() throws {
        let entry = MappingEntry(commandID: 123, midiChannel: 1, midiCC: 22)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
        )
        object.removeValue(forKey: "rawDCDTEncoderMode")
        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(decoded.rawDCDTEncoderMode)
    }

    func testSameControlUsesDirectionSpecificDefinitionMetadata() throws {
        let input = dcdtPayload(
            name: "Ch01.CC.022",
            controlType: 7,
            encoderMode: 0
        )
        let output = dcdtPayload(
            name: "Ch01.CC.022",
            controlType: 8,
            encoderMode: 1
        )
        let tsi = definitionFixtureTSI(
            definitionFrames: rawFrame("DDCI", be32(1) + rawFrame("DCDT", input))
                + rawFrame("DDCO", be32(1) + rawFrame("DCDT", output)),
            mappingDirections: [.input, .output]
        )

        let mappings = try XCTUnwrap(try interpretTSIData(tsi).devices.first?.mappings)
        XCTAssertEqual(mappings.map(\.ioType), [.input, .output])
        XCTAssertEqual(mappings.map(\.encoderMode), [.mode3Fh41h, .mode7Fh01h])
        XCTAssertEqual(mappings.map(\.rawDCDTEncoderMode), [nil, nil])
        XCTAssertTrue(mappings.allSatisfy { $0.midiCC == 22 && $0.midiChannel == 1 })
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

    func testImportedNoncanonicalCMADPayloadRegeneratesByteForByte() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        let cmai = cmaiPayload(
            bindingId: TSIBindingID.unassigned,
            ioType: 0,
            commandId: 100,
            cmadBytes: rawFrame("CMAD", rawCMAD)
        )
        let imported = try interpretCMAS(be32(1) + rawFrame("CMAI", cmai))

        let rewritten = try TSIWriter().write(imported)

        XCTAssertEqual(try firstCMADPayload(in: rewritten), rawCMAD)
    }

    func testImportedNativeDeviceNameAndEmptyPortsRegenerateVerbatim() throws {
        let name = "Kontrol S8 MK2 — Native"
        let devicePayload = tsiString(name)
            + rawFrame("DDPT", tsiString("") + tsiString(""))
            + rawFrame("CMAS", be32(0))
        let imported = try interpretDEVI(devicePayload)

        let rewritten = try TSIWriter().write(imported)
        let reimported = try XCTUnwrap(try interpretTSIData(rewritten).devices.first)

        XCTAssertEqual(reimported.name, name)
        XCTAssertEqual(reimported.inPort, "")
        XCTAssertEqual(reimported.outPort, "")
    }

    func testImportedCMADSurvivesCodableAndCopyWithWireFingerprint() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        let imported = try importedMappingFile(cmad: rawCMAD)
        let mapping = try XCTUnwrap(imported.devices.first?.mappings.first)
        let state = try XCTUnwrap(mapping.importedCMAD)

        XCTAssertEqual(state.payload, rawCMAD)
        XCTAssertEqual(state.deviceType, 4)
        XCTAssertEqual(state.hasValueUI, 9)
        XCTAssertEqual(state.conditionOneTarget, 0xAABB_CCDD)
        XCTAssertEqual(state.conditionTwoTarget, 0x0102_0304)
        XCTAssertEqual(state.ledMinRangeData, 0x7FC0_1234)
        XCTAssertEqual(state.unknownVUI, 0x1122_3344)
        XCTAssertEqual(state.resolutionBits, 0x7FC0_ABCD)
        XCTAssertEqual(state.useFactoryMap, 0xA5A5_A5A5)
        XCTAssertEqual(state.semanticAtImport.rotarySensitivityBits, 0x8000_0000)
        XCTAssertEqual(state.semanticAtImport.setToValueBits, 0x8000_0000)

        let copied = mapping.copyWithNewID()
        XCTAssertNotEqual(copied.id, mapping.id)
        XCTAssertEqual(copied.importedCMAD, state)

        let encoded = try JSONEncoder().encode(mapping)
        let decoded = try JSONDecoder().decode(MappingEntry.self, from: encoded)
        XCTAssertEqual(decoded.importedCMAD, state)

        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        legacyObject.removeValue(forKey: "importedCMAD")
        let legacy = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )
        XCTAssertNil(legacy.importedCMAD)
    }

    func testImportedCommentEditReplacesOnlyCommentBytes() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].comment = "edited"

        let rewritten = try TSIWriter().write(imported)

        XCTAssertEqual(
            try firstCMADPayload(in: rewritten),
            replacingComment(in: rawCMAD, with: "edited")
        )
    }

    func testImportedAssignmentEditReplacesOnlyTargetScalar() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].assignment = .deckD

        let rewritten = try TSIWriter().write(imported)

        XCTAssertEqual(
            try firstCMADPayload(in: rewritten),
            replacingUInt32(in: rawCMAD, at: 12, with: 3)
        )
    }

    func testImportedIOEditLeavesCMADPayloadUntouched() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].ioType = .output

        let rewritten = try TSIWriter().write(imported)
        let reimported = try XCTUnwrap(try interpretTSIData(rewritten).devices.first?.mappings.first)

        XCTAssertEqual(try firstCMADPayload(in: rewritten), rawCMAD)
        XCTAssertEqual(reimported.ioType, .output)
    }

    func testImportedModifierEditReplacesCompleteConditionBlockOnly() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].modifier1Condition = .init(modifier: 7, value: 6)
        imported.devices[0].mappings[0].modifier2Condition = nil

        let tail = cmadTailOffset(in: rawCMAD)
        var expected = rawCMAD
        let replacement = [UInt32(7), 0, 6, 0, 0, 0].reduce(into: Data()) {
            $0.append(be32($1))
        }
        expected.replaceSubrange(tail..<(tail + 24), with: replacement)

        XCTAssertEqual(
            try firstCMADPayload(in: TSIWriter().write(imported)),
            expected
        )
    }

    func testImportedInputOptionEditsReplaceEachOwningScalarIndividually() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        let cases: [(String, (inout MappingEntry) -> Void, Int, UInt32)] = [
            ("auto repeat", { $0.autoRepeat = false }, 16, 0),
            ("invert", { $0.invert = false }, 20, 0),
            ("soft takeover", { $0.softTakeover = false }, 24, 0),
            ("rotary sensitivity", { $0.rotarySensitivity = 1.5 }, 28, Float32(1.5).bitPattern),
            ("rotary acceleration", { $0.rotaryAcceleration = 0.75 }, 32, Float32(0.75).bitPattern),
        ]

        for (label, mutate, offset, value) in cases {
            var imported = try importedMappingFile(cmad: rawCMAD)
            mutate(&imported.devices[0].mappings[0])
            XCTAssertEqual(
                try firstCMADPayload(in: TSIWriter().write(imported)),
                replacingUInt32(in: rawCMAD, at: offset, with: value),
                label
            )
        }
    }

    func testImportedSetToEditReplacesOnlySetToBits() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].setToValue = 0.5

        XCTAssertEqual(
            try firstCMADPayload(in: TSIWriter().write(imported)),
            replacingUInt32(in: rawCMAD, at: 44, with: 0x3F00_0000)
        )
    }

    func testImportedMIDIEditLeavesCMADPayloadUntouched() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].midiAssignment = try .controlChange(
            channel: 2,
            number: 77
        )

        let rewritten = try TSIWriter().write(imported)
        let reimported = try XCTUnwrap(try interpretTSIData(rewritten).devices.first?.mappings.first)

        XCTAssertEqual(try firstCMADPayload(in: rewritten), rawCMAD)
        XCTAssertEqual(reimported.midiChannel, 2)
        XCTAssertEqual(reimported.midiCC, 77)
    }

    func testImportedLEDEditsReplaceEachOwningScalarIndividually() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        let led = cmadTailOffset(in: rawCMAD) + 24
        let cases: [(String, (inout MappingEntry) -> Void, Int, UInt32)] = [
            ("min type", { $0.ledMinRangeType = 7 }, led, 7),
            ("min data", { $0.ledMinRangeData = 42 }, led + 4, 42),
            ("max type", { $0.ledMaxRangeType = 8 }, led + 8, 8),
            ("max data", { $0.ledMaxRangeData = 43 }, led + 12, 43),
            ("min MIDI", { $0.ledMinMidi = 12 }, led + 16, 12),
            ("max MIDI", { $0.ledMaxMidi = 118 }, led + 20, 118),
            ("invert", { $0.ledInvert = false }, led + 24, 0),
            ("blend", { $0.ledBlend = false }, led + 28, 0),
            ("resolution", { $0.resolution = 3 }, led + 36, 3),
        ]

        for (label, mutate, offset, value) in cases {
            var imported = try importedMappingFile(cmad: rawCMAD)
            mutate(&imported.devices[0].mappings[0])
            XCTAssertEqual(
                try firstCMADPayload(in: TSIWriter().write(imported)),
                replacingUInt32(in: rawCMAD, at: offset, with: value),
                label
            )
        }
    }

    func testImportedControllerTypeEditReplacesCoordinatedProfileOnly() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].controllerType = .button

        var expected = replacingUInt32(in: rawCMAD, at: 4, with: 0)
        expected = replacingCoordinatedProfile(
            in: expected,
            hasValueUI: 0,
            valueUIType: 1,
            setTo: 0x8000_0000,
            ledMinType: 1,
            ledMinData: 0,
            ledMaxType: 1,
            ledMaxData: 1,
            blend: 0,
            unknownVUI: 1,
            resolution: 1
        )

        XCTAssertEqual(
            try firstCMADPayload(in: TSIWriter().write(imported)),
            expected
        )
    }

    func testImportedCommandIDEditReplacesCoordinatedProfileOnly() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].commandID = 125

        let expected = replacingCoordinatedProfile(
            in: rawCMAD,
            hasValueUI: 0,
            valueUIType: 2,
            setTo: 0x8000_0000,
            ledMinType: 2,
            ledMinData: 0,
            ledMaxType: 2,
            ledMaxData: 0x3F80_0000,
            blend: 1,
            unknownVUI: 2,
            resolution: 0x3D80_0000
        )

        XCTAssertEqual(
            try firstCMADPayload(in: TSIWriter().write(imported)),
            expected
        )
    }

    func testImportedInteractionEditReplacesOnlyInteractionWhenValid() throws {
        let rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        var imported = try importedMappingFile(cmad: rawCMAD)
        imported.devices[0].mappings[0].interactionMode = .relative

        XCTAssertEqual(
            try firstCMADPayload(in: TSIWriter().write(imported)),
            replacingUInt32(in: rawCMAD, at: 8, with: 4)
        )
    }

    func testImportedInteractionEditToIncompatibleModeIsUnwritable() throws {
        var imported = try importedMappingFile(
            cmad: noncanonicalCMAD(comment: "wire fidelity")
        )
        imported.devices[0].mappings[0].interactionMode = .output

        let report = TSIWriter().preservationReport(for: imported)

        XCTAssertEqual(report.disposition, .unwritable)
        XCTAssertNotNil(report.validationError)
    }

    func testImportedTruncatedTailRefusesBeforeTouchingMissingOwnedBytes() throws {
        let fullCMAD = noncanonicalCMAD(comment: "wire fidelity")
        let truncatedCMAD = Data(fullCMAD.prefix(cmadTailOffset(in: fullCMAD)))
        let cases: [(String, (inout MappingEntry) -> Void)] = [
            ("modifier", { $0.modifier1Condition = .init(modifier: 1, value: 1) }),
            ("LED", { $0.ledMaxMidi = 12 }),
            ("controller profile", { $0.controllerType = .button }),
            ("command profile", { $0.commandID = 125 }),
        ]

        for (label, mutate) in cases {
            var imported = try importedMappingFile(cmad: truncatedCMAD)
            mutate(&imported.devices[0].mappings[0])
            let report = TSIWriter().preservationReport(for: imported)
            XCTAssertEqual(report.disposition, .lossyConvertible, label)
            XCTAssertTrue(report.risks.contains { $0.code == .partialCMAD }, label)
            XCTAssertThrowsError(try TSIWriter().write(imported), label) { error in
                XCTAssertEqual(
                    error as? TSIPreservationError,
                    .unsafeOverwrite(risks: report.risks),
                    label
                )
            }
        }
    }

    func testConvertedOutputDeliberatelyNormalizesImportedNativeWireValues() throws {
        var rawCMAD = noncanonicalCMAD(comment: "wire fidelity")
        rawCMAD = replacingUInt32(in: rawCMAD, at: 0, with: 3)
        let cmai = cmaiPayload(commandId: 100, cmadBytes: rawFrame("CMAD", rawCMAD))
        let payload = tsiString("Kontrol S8 MK2 — Native")
            + rawFrame("DDPT", tsiString("") + tsiString(""))
            + rawFrame("CMAS", be32(1) + rawFrame("CMAI", cmai))
        let imported = try interpretDEVI(payload)

        let converted = try TSIWriter().writeConverted(imported)
        let convertedDevice = try XCTUnwrap(try interpretTSIData(converted).devices.first)

        XCTAssertEqual(readUInt32BE(try firstCMADPayload(in: converted), at: 0), 4)
        XCTAssertEqual(convertedDevice.name, "Generic MIDI")
        XCTAssertEqual(convertedDevice.inPort, "All Ports")
        XCTAssertEqual(convertedDevice.outPort, "All Ports")
    }

    func testNewEmptyDeviceNameIsUnwritable() {
        let report = TSIWriter().preservationReport(
            for: MappingFile(devices: [Device()])
        )

        XCTAssertEqual(report.disposition, .unwritable)
        XCTAssertNotNil(report.validationError)
    }

    // MARK: - Corrupt-Frame Surfacing Tests (M10)

    /// Writes a MappingFile through TSIWriter and returns the decoded binary frame data.
    private func binaryData(for file: MappingFile) throws -> Data {
        let writer = TSIWriter()
        let tsiData = try writer.write(file)
        let base64 = try TSIParser.extractControllerData(from: tsiData)
        return try TSIParser().decodeBase64(base64)
    }

    private func firstCMADPayload(in tsi: Data) throws -> Data {
        let base64 = try TSIParser.extractControllerData(from: tsi)
        let binary = try TSIParser().decodeBase64(base64)
        let cmadOffset = try XCTUnwrap(frameOffsets(of: "CMAD", in: binary).first)
        let size = Int(readUInt32BE(binary, at: cmadOffset + 4))
        return binary.subdata(in: (cmadOffset + 8)..<(cmadOffset + 8 + size))
    }

    /// Parses binary frame data and interprets it into a MappingFile.
    private func interpretBinary(_ binary: Data) throws -> MappingFile {
        let frames = try TSIParser().parseFrames(from: binary)
        return try TSIInterpreter.interpret(frames: frames)
    }

    /// Returns frame-header offsets by walking only declared container bounds.
    /// Unknown frame payloads are skipped whole, so embedded marker bytes can
    /// never be mistaken for a real frame.
    private func frameOffsets(of identifier: String, in data: Data) throws -> [Int] {
        var result: [Int] = []
        _ = try collectBoundedFrames(
            in: data,
            range: 0..<data.count,
            parentIdentifier: nil,
            matching: identifier,
            offsets: &result
        )
        return result
    }

    /// Walks one exact frame stream and returns its direct child identifiers.
    @discardableResult
    private func collectBoundedFrames(
        in data: Data,
        range: Range<Int>,
        parentIdentifier: String?,
        matching targetIdentifier: String,
        offsets: inout [Int]
    ) throws -> [String] {
        var offset = range.lowerBound
        var directIdentifiers: [String] = []

        while offset < range.upperBound {
            guard offset + 8 <= range.upperBound,
                  let identifier = String(
                      data: data.subdata(in: offset..<(offset + 4)),
                      encoding: .ascii
                  ) else {
                throw BoundedFrameScanError.malformedHierarchy
            }
            let payloadSize = Int(readUInt32BE(data, at: offset + 4))
            let payloadStart = offset + 8
            let payloadEnd = payloadStart + payloadSize
            guard payloadEnd <= range.upperBound else {
                throw BoundedFrameScanError.malformedHierarchy
            }

            directIdentifiers.append(identifier)
            if identifier == targetIdentifier {
                offsets.append(offset)
            }

            let payloadRange = payloadStart..<payloadEnd
            switch identifier {
            case "DIOM", "DDAT", "DDDC", "DDCB":
                _ = try collectBoundedFrames(
                    in: data,
                    range: payloadRange,
                    parentIdentifier: identifier,
                    matching: targetIdentifier,
                    offsets: &offsets
                )

            case "DEVS", "DDCI", "DDCO", "CMAS":
                guard payloadSize >= 4 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                let declaredCount = Int(readUInt32BE(data, at: payloadStart))
                let children = try collectBoundedFrames(
                    in: data,
                    range: (payloadStart + 4)..<payloadEnd,
                    parentIdentifier: identifier,
                    matching: targetIdentifier,
                    offsets: &offsets
                )
                let expectedChild = switch identifier {
                case "DEVS": "DEVI"
                case "CMAS": "CMAI"
                default: "DCDT"
                }
                guard children.count == declaredCount,
                      children.allSatisfy({ $0 == expectedChild }) else {
                    throw BoundedFrameScanError.malformedHierarchy
                }

            case "DEVI":
                guard payloadSize >= 4 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                let codeUnitCount = Int(readUInt32BE(data, at: payloadStart))
                guard codeUnitCount <= (payloadSize - 4) / 2 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                let childrenStart = payloadStart + 4 + codeUnitCount * 2
                _ = try collectBoundedFrames(
                    in: data,
                    range: childrenStart..<payloadEnd,
                    parentIdentifier: identifier,
                    matching: targetIdentifier,
                    offsets: &offsets
                )

            case "CMAI":
                guard payloadSize >= 12 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                let children = try collectBoundedFrames(
                    in: data,
                    range: (payloadStart + 12)..<payloadEnd,
                    parentIdentifier: identifier,
                    matching: targetIdentifier,
                    offsets: &offsets
                )
                guard children == ["CMAD"] else {
                    throw BoundedFrameScanError.malformedHierarchy
                }

            case "DCBM" where parentIdentifier == "DDCB":
                guard payloadSize >= 4 else {
                    throw BoundedFrameScanError.malformedHierarchy
                }
                let declaredCount = Int(readUInt32BE(data, at: payloadStart))
                let children = try collectBoundedFrames(
                    in: data,
                    range: (payloadStart + 4)..<payloadEnd,
                    parentIdentifier: identifier,
                    matching: targetIdentifier,
                    offsets: &offsets
                )
                guard children.count == declaredCount,
                      children.allSatisfy({ $0 == "DCBM" }) else {
                    throw BoundedFrameScanError.malformedHierarchy
                }

            default:
                break
            }

            offset = payloadEnd
        }

        guard offset == range.upperBound else {
            throw BoundedFrameScanError.malformedHierarchy
        }
        return directIdentifiers
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

        let deviOffsets = try frameOffsets(of: "DEVI", in: binary)
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

        let devsOffsets = try frameOffsets(of: "DEVS", in: binary)
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

        let cmaiOffsets = try frameOffsets(of: "CMAI", in: binary)
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

        let cmasOffsets = try frameOffsets(of: "CMAS", in: binary)
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
        let file = MappingFile(devices: [Device(name: "Test", mappings: [unassigned, assigned])])
        let tsi = try TSIWriter().write(file)
        let binary = try binaryData(for: file)

        // Only the assigned control gets a DCDT definition
        let dcdtEntries = try scanDCDTEntries(inTSI: tsi)
        XCTAssertEqual(dcdtEntries.count, 1, "Unassigned mappings must not get DCDT entries")
        XCTAssertEqual(dcdtEntries.first?.name, "Ch01.CC.020")

        // DCBM: one outer list frame + exactly one nested binding frame
        XCTAssertEqual(try frameOffsets(of: "DCBM", in: binary).count, 2,
                       "Unassigned mappings must not get DCBM binding entries")

        // The unassigned mapping's CMAI carries the 0xFFFFFFFF sentinel
        let cmaiOffsets = try frameOffsets(of: "CMAI", in: binary)
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

    func testStrippedDCBMWithIntactDCDTOpensWithPreservedBindingWarning() throws {
        // M9: with the DCBM binding list gone, a non-sentinel CMAI id must NOT
        // quietly resolve through the DCDT control table — that fallback let
        // corrupt files open and rebind controls. The unresolved numeric ID
        // must be preserved explicitly instead.
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let dcbmOffsets = try frameOffsets(of: "DCBM", in: binary)
        XCTAssertEqual(dcbmOffsets.count, 2, "Fixture must contain the outer list + one nested binding")
        XCTAssertEqual(try frameOffsets(of: "DCDT", in: binary).count, 1, "DCDT must remain intact")

        // Rename every DCBM identifier — all frame sizes stay valid, the
        // binding list simply no longer exists.
        for offset in dcbmOffsets {
            binary.replaceSubrange(offset..<(offset + 4), with: "XXXX".data(using: .ascii)!)
        }

        let imported = try interpretBinary(binary)
        let mapping = try XCTUnwrap(imported.devices.first?.mappings.first)
        XCTAssertEqual(mapping.rawMidiBindingID, 0)
        XCTAssertEqual(mapping.mappedToDisplay, "Unresolved MIDI #0")
        XCTAssertEqual(
            mapping.tsiCompatibilityWarning,
            .unresolvedMIDIBinding(id: 0)
        )
    }

    func testCorruptDCBMBindingEntryThrows() throws {
        // Under the structural-parse contract a malformed binding entry is
        // corruption and throws — it is never silently skipped (the heuristic
        // skip converted into a fatal dangling-binding error downstream anyway).
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let dcbmOffsets = try frameOffsets(of: "DCBM", in: binary)
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

        let dcbmOffsets = try frameOffsets(of: "DCBM", in: binary)
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

    func testDanglingBindingIdOpensAndRoundTripsWithoutColliding() throws {
        let device = Device(name: "Test", mappings: [simpleEntry(cc: 10)])
        var binary = try binaryData(for: MappingFile(devices: [device]))

        let cmaiOffsets = try frameOffsets(of: "CMAI", in: binary)
        XCTAssertEqual(cmaiOffsets.count, 1)

        // Point the CMAI's MidiNoteBindingId at a binding that isn't in DCBM —
        // corruption, NOT "unassigned"; silently nil-ing it would erase the
        // user's MIDI assignment on the next save.
        writeUInt32BE(999, at: cmaiOffsets[0] + 8, in: &binary)

        var imported = try interpretBinary(binary)
        let unresolved = try XCTUnwrap(imported.devices.first?.mappings.first)
        XCTAssertEqual(unresolved.rawMidiBindingID, 999)
        XCTAssertEqual(
            unresolved.tsiCompatibilityWarning,
            .unresolvedMIDIBinding(id: 999)
        )

        imported.devices[0].mappings.append(simpleEntry(cc: 11))
        let rewrittenBinary = try binaryData(for: imported)
        let cmaiOffsetsAfterRewrite = try frameOffsets(of: "CMAI", in: rewrittenBinary)
        XCTAssertEqual(cmaiOffsetsAfterRewrite.count, 2)
        XCTAssertEqual(readUInt32BE(rewrittenBinary, at: cmaiOffsetsAfterRewrite[0] + 8), 999)
        XCTAssertNotEqual(readUInt32BE(rewrittenBinary, at: cmaiOffsetsAfterRewrite[1] + 8), 999)

        let reimported = try interpretBinary(rewrittenBinary)
        XCTAssertEqual(reimported.devices.first?.mappings.first?.rawMidiBindingID, 999)
        XCTAssertEqual(reimported.devices.first?.mappings.last?.midiCC, 11)
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

    /// Complete CMAD carrying intentionally non-profile wire values. The
    /// literals are independent of the writer so this catches any canonical
    /// rebuild of fields that the user did not edit.
    private func noncanonicalCMAD(comment: String) -> Data {
        let fixedScalars: [UInt32] = [
            4,              // DeviceType: Generic MIDI
            1,              // ControllerType: fader
            3,              // InteractionMode: direct
            2,              // Assignment: Deck C
            2,              // AutoRepeat: true, noncanonical bool wire value
            3,              // Invert: true, noncanonical bool wire value
            4,              // SoftTakeover: true, noncanonical bool wire value
            0x8000_0000,    // RotarySensitivity: negative zero
            0x3E80_0000,    // RotaryAcceleration: 0.25
            9,              // HasValueUI
            7,              // ValueUIType
            0x8000_0000,    // SetValueTo: negative zero
        ]
        let conditionScalars: [UInt32] = [
            2, 0xAABB_CCDD, 3,
            4, 0x0102_0304, 5,
        ]
        let ledScalars: [UInt32] = [
            2, 0x7FC0_1234, // min type/data: NaN payload
            2, 0x3F80_0000, // max type/data: 1.0
            11, 119,
            5, 6,
            0x1122_3344,    // UnknownVUI
            0x7FC0_ABCD,    // Resolution raw NaN payload
            0xA5A5_A5A5,   // UseFactoryMap
        ]

        var result = fixedScalars.reduce(into: Data()) { $0.append(be32($1)) }
        result.append(be32(UInt32(comment.utf16.count)))
        result.append(utf16BE(comment))
        for scalar in conditionScalars + ledScalars {
            result.append(be32(scalar))
        }
        return result
    }

    private func importedMappingFile(
        cmad: Data,
        commandID: UInt32 = 100,
        ioType: UInt32 = 0
    ) throws -> MappingFile {
        let cmai = cmaiPayload(
            bindingId: TSIBindingID.unassigned,
            ioType: ioType,
            commandId: commandID,
            cmadBytes: rawFrame("CMAD", cmad)
        )
        return try interpretCMAS(be32(1) + rawFrame("CMAI", cmai))
    }

    private func replacingUInt32(in data: Data, at offset: Int, with value: UInt32) -> Data {
        var result = data
        result.replaceSubrange(offset..<(offset + 4), with: be32(value))
        return result
    }

    private func cmadTailOffset(in data: Data) -> Int {
        52 + Int(readUInt32BE(data, at: 48)) * 2
    }

    private func replacingComment(in data: Data, with comment: String) -> Data {
        let oldTail = cmadTailOffset(in: data)
        return data.prefix(48)
            + be32(UInt32(comment.utf16.count))
            + utf16BE(comment)
            + data.suffix(from: oldTail)
    }

    private func replacingCoordinatedProfile(
        in data: Data,
        hasValueUI: UInt32,
        valueUIType: UInt32,
        setTo: UInt32,
        ledMinType: UInt32,
        ledMinData: UInt32,
        ledMaxType: UInt32,
        ledMaxData: UInt32,
        blend: UInt32,
        unknownVUI: UInt32,
        resolution: UInt32
    ) -> Data {
        var result = data
        for (offset, value) in [
            (36, hasValueUI), (40, valueUIType), (44, setTo),
        ] {
            result = replacingUInt32(in: result, at: offset, with: value)
        }
        let led = cmadTailOffset(in: result) + 24
        for (offset, value) in [
            (led, ledMinType), (led + 4, ledMinData),
            (led + 8, ledMaxType), (led + 12, ledMaxData),
            (led + 28, blend), (led + 32, unknownVUI),
            (led + 36, resolution),
        ] {
            result = replacingUInt32(in: result, at: offset, with: value)
        }
        return result
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

        let dcbmOffsets = try frameOffsets(of: "DCBM", in: binary)
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

        let ddcbOffsets = try frameOffsets(of: "DDCB", in: binary)
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

    func testDuplicateDCBMBindingIdsUseFirstDocumentOrderValue() throws {
        // Structurally valid duplicates remain openable for exact no-op saves.
        // The interpreter selects the first value; the source inventory blocks
        // any edited ordinary overwrite that would collapse the duplicate.
        let entry1 = rawFrame("DCBM", be32(0) + tsiString("Ch01.CC.010"))
        let entry2 = rawFrame("DCBM", be32(0) + tsiString("Ch01.CC.020"))
        let cmai = cmaiPayload(bindingId: 0, cmadBytes: rawFrame("CMAD", validCMAD()))
        let deviPayload = tsiString("Test")
            + rawFrame("CMAS", be32(1) + rawFrame("CMAI", cmai))
            + rawFrame("DCBM", be32(2) + entry1 + entry2)

        let result = try interpretDEVI(deviPayload)
        XCTAssertEqual(result.devices.first?.mappings.first?.midiCC, 10)
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

    func testUnknownDCBMControlNameIsPreservedOpaque() throws {
        // Native/proprietary Traktor mappings use names outside the generic
        // CC/Note grammar. They must remain visible and byte-for-byte stable.
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

        let imported = try interpretBinary(binary)
        let mapping = try XCTUnwrap(imported.devices.first?.mappings.first)
        XCTAssertEqual(mapping.rawMidiControlName, "Ch01.XX.010")
        XCTAssertEqual(mapping.mappedToDisplay, "Ch01.XX.010")

        let rewritten = try binaryData(for: imported)
        let reimported = try interpretBinary(rewritten)
        XCTAssertEqual(
            reimported.devices.first?.mappings.first?.rawMidiControlName,
            "Ch01.XX.010"
        )
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

    // MARK: - Shared Binary Resource Budgets

    func testUTF16StringByteLimitAtMinusOneLimitAndPlusOne() throws {
        let deviPayload = tsiString("AB") + rawFrame("CMAS", be32(0))
        let binary = rawFrame("DIOM", rawFrame("DEVS", be32(1) + rawFrame("DEVI", deviPayload)))
        let frames = try TSIParser().parseFrames(from: binary)

        for maximum in [3, 4, 5] {
            let limits = TSIParseLimits(maximumUTF16StringBytes: maximum)
            if maximum == 3 {
                XCTAssertThrowsError(try TSIInterpreter.interpret(frames: frames, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .utf16StringByteLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIInterpreter.interpret(frames: frames, limits: limits).devices.first?.name, "AB")
            }
        }
    }

    func testNestedDCBMStringsUseTheSameUTF16ByteBudget() throws {
        let binding = rawFrame("DCBM", be32(0) + tsiString("AB"))
        let deviPayload = tsiString("T")
            + rawFrame("DCBM", be32(1) + binding)
            + rawFrame("CMAS", be32(0))
        let binary = rawFrame("DIOM", rawFrame("DEVS", be32(1) + rawFrame("DEVI", deviPayload)))
        let frames = try TSIParser().parseFrames(from: binary)

        XCTAssertThrowsError(try TSIInterpreter.interpret(
            frames: frames,
            limits: TSIParseLimits(maximumUTF16StringBytes: 3)
        )) {
            XCTAssertEqual($0 as? TSIParserError, .utf16StringByteLimitExceeded)
        }
    }

    func testBinaryDepthLimitAtMinusOneLimitAndPlusOne() throws {
        var child = rawFrame("CMAS", be32(0))
        child = rawFrame("DDAT", rawFrame("DDAT", child))
        let deviPayload = tsiString("T") + child
        let binary = rawFrame("DIOM", rawFrame("DEVS", be32(1) + rawFrame("DEVI", deviPayload)))
        let frames = try TSIParser().parseFrames(from: binary)

        for maximum in [5, 6, 7] {
            let limits = TSIParseLimits(maximumBinaryContainerDepth: maximum)
            if maximum == 5 {
                XCTAssertThrowsError(try TSIInterpreter.interpret(frames: frames, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .binaryDepthLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIInterpreter.interpret(frames: frames, limits: limits).devices.count, 1)
            }
        }
    }

    func testCMASPerContainerFrameLimitAtMinusOneLimitAndPlusOne() throws {
        let placeholder = rawFrame(
            "CMAI",
            cmaiPayload(commandId: 0, cmadBytes: rawFrame("CMAD", validCMAD()))
        )
        let cmas = rawFrame("CMAS", be32(3) + placeholder + placeholder + placeholder)
        let binary = rawFrame(
            "DIOM",
            rawFrame("DEVS", be32(1) + rawFrame("DEVI", tsiString("T") + cmas))
        )
        let frames = try TSIParser().parseFrames(from: binary)

        for maximum in [2, 3, 4] {
            let limits = TSIParseLimits(maximumFramesPerContainer: maximum)
            if maximum == 2 {
                XCTAssertThrowsError(try TSIInterpreter.interpret(frames: frames, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .frameCountLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIInterpreter.interpret(frames: frames, limits: limits).devices.first?.mappings.count, 0)
            }
        }
    }

    func testDCBMPerContainerFrameLimitAtMinusOneLimitAndPlusOne() throws {
        let entries = (0..<3).reduce(into: Data()) { data, index in
            data.append(rawFrame("DCBM", be32(UInt32(index)) + tsiString("Ch01.CC.00\(index)")))
        }
        let deviPayload = tsiString("T")
            + rawFrame("DCBM", be32(3) + entries)
            + rawFrame("CMAS", be32(0))
        let binary = rawFrame("DIOM", rawFrame("DEVS", be32(1) + rawFrame("DEVI", deviPayload)))
        let frames = try TSIParser().parseFrames(from: binary)

        for maximum in [2, 3, 4] {
            let limits = TSIParseLimits(maximumFramesPerContainer: maximum)
            if maximum == 2 {
                XCTAssertThrowsError(try TSIInterpreter.interpret(frames: frames, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .frameCountLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIInterpreter.interpret(frames: frames, limits: limits).devices.count, 1)
            }
        }
    }

    func testCumulativeFrameBudgetIsSharedAcrossNestedContainers() throws {
        let placeholder = rawFrame(
            "CMAI",
            cmaiPayload(commandId: 0, cmadBytes: rawFrame("CMAD", validCMAD()))
        )
        let binary = rawFrame(
            "DIOM",
            rawFrame("DEVS", be32(1) + rawFrame(
                "DEVI",
                tsiString("T") + rawFrame("CMAS", be32(3) + placeholder + placeholder + placeholder)
            ))
        )
        let frames = try TSIParser().parseFrames(from: binary)

        for maximum in [9, 10, 11] {
            let limits = TSIParseLimits(maximumCumulativeFrames: maximum)
            if maximum == 9 {
                XCTAssertThrowsError(try TSIInterpreter.interpret(frames: frames, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .cumulativeFrameLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIInterpreter.interpret(frames: frames, limits: limits).devices.count, 1)
            }
        }
    }

    // MARK: - Helper Functions (Expose internal logic for testing)

    /// Parse MIDI control name - mirrors TSIInterpreter logic
    /// (nil means the name is outside the modeled CC/Note grammar)
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
