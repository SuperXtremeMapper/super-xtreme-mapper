//
//  ModifierConditionTargetTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

final class ModifierConditionTargetTests: XCTestCase {
    func testInterpreterModelsKnownAndUnknownConditionTargets() throws {
        let knownRaw: UInt32 = 3
        let unknownRaw: UInt32 = 0xAABB_CCDD
        let imported = try interpretCMAD(
            makeCMAD(
                conditionOne: (modifier: 2, target: knownRaw, value: 4),
                conditionTwo: (modifier: 5, target: unknownRaw, value: 6)
            )
        )

        let mapping = try XCTUnwrap(imported.devices.first?.mappings.first)
        let first = try XCTUnwrap(mapping.modifier1Condition)
        let second = try XCTUnwrap(mapping.modifier2Condition)

        XCTAssertEqual(first.modifier, 2)
        XCTAssertEqual(first.value, 4)
        XCTAssertEqual(first.target, .deckD)
        XCTAssertEqual(try encodedTargetRaw(first), knownRaw)
        XCTAssertEqual(second.modifier, 5)
        XCTAssertEqual(second.value, 6)
        XCTAssertEqual(second.target, .unknown(unknownRaw))
        XCTAssertEqual(try encodedTargetRaw(second), unknownRaw)
        XCTAssertEqual(
            try encodedTargetRaw(
                XCTUnwrap(mapping.importedCMAD?.semanticAtImport.modifier1Condition)
            ),
            knownRaw,
            "the import fingerprint must include the modeled target"
        )
    }

    func testWriterRoundTripsEveryKnownConditionTarget() throws {
        let knownTargets: [(raw: UInt32, modeled: ModifierConditionTarget)] = [
            (0, .deckA),
            (1, .deckB),
            (2, .deckC),
            (3, .deckD),
        ]
        for (rawTarget, modeledTarget) in knownTargets {
            let entry = MappingEntry(
                commandID: 100,
                ioType: .input,
                assignment: .deckA,
                interactionMode: .hold,
                midiChannel: 1,
                midiCC: Int(rawTarget) + 20,
                modifier1Condition: try condition(modifier: 2, targetRaw: rawTarget, value: 4),
                controllerType: .button
            )

            let roundTripped = try XCTUnwrap(roundTrip(entry))
            let condition = try XCTUnwrap(roundTripped.modifier1Condition)

            XCTAssertEqual(condition.target, modeledTarget)
            XCTAssertEqual(
                try encodedTargetRaw(condition),
                rawTarget,
                "wire target \(rawTarget) must survive a TSIWriter round trip"
            )
        }
    }

    func testWriterPreservesUnknownTargetAndUnrelatedOptionalBytesWhenConditionChanges() throws {
        let unknownRaw: UInt32 = 0xDEAD_BEEF
        let original = makeCMAD(
            conditionOne: (modifier: 2, target: unknownRaw, value: 3),
            conditionTwo: (modifier: 4, target: 1, value: 5),
            optionalTailSeed: 0x40,
            trailingBytes: Data([0xFA, 0xCE, 0xB0, 0x0C])
        )
        var mapping = try XCTUnwrap(
            try interpretCMAD(original).devices.first?.mappings.first
        )
        mapping.modifier1Condition?.value = 7

        let rewritten = try TSIWriter().preservingCMADPayload(for: mapping)
        var expected = original
        replaceUInt32(7, in: &expected, at: 60)

        XCTAssertEqual(rewritten, expected)
        XCTAssertEqual(readUInt32(rewritten, at: 56), unknownRaw)
    }

    func testEditingActiveConditionPreservesUnchangedInactiveConditionWireTuple() throws {
        let original = makeCMAD(
            conditionOne: (modifier: 0, target: 0xDEAD_BEEF, value: 0x1234_5678),
            conditionTwo: (modifier: 4, target: 1, value: 5),
            optionalTailSeed: 0x20,
            trailingBytes: Data([0xAA, 0x55])
        )
        var mapping = try XCTUnwrap(
            try interpretCMAD(original).devices.first?.mappings.first
        )
        XCTAssertNil(mapping.modifier1Condition)
        mapping.modifier2Condition?.value = 7

        let rewritten = try TSIWriter().preservingCMADPayload(for: mapping)
        var expected = original
        replaceUInt32(7, in: &expected, at: 72)

        XCTAssertEqual(rewritten, expected)
    }

    func testSemanticBindingKeyIgnoresInactiveConditionRawTarget() throws {
        let mapping = try XCTUnwrap(
            try interpretCMAD(
                makeCMAD(
                    conditionOne: (modifier: 0, target: 0xCAFE_BABE, value: 0x1122_3344),
                    conditionTwo: (modifier: 4, target: 1, value: 5)
                )
            ).devices.first?.mappings.first
        )

        let key = try XCTUnwrap(SemanticBindingKey(entry: mapping))

        XCTAssertNil(key.conditionOne)
        XCTAssertEqual(key.conditionTwo?.target, 1)
        XCTAssertEqual(key.conditionTwo?.modifier, 4)
        XCTAssertEqual(key.conditionTwo?.value, 5)
    }

    func testLegacyCodableModifierDefaultsToDeckATarget() throws {
        let legacy = Data(#"{"modifier":2,"value":3}"#.utf8)

        let condition = try JSONDecoder().decode(ModifierCondition.self, from: legacy)

        XCTAssertEqual(try encodedTargetRaw(condition), 0)
    }

    func testLegacyMappingCodablePromotesImportedRawTargetsIntoModelAndFingerprint() throws {
        let unknownRaw: UInt32 = 0xFEED_FACE
        let imported = try XCTUnwrap(
            try interpretCMAD(
                makeCMAD(conditionOne: (modifier: 2, target: unknownRaw, value: 3))
            ).devices.first?.mappings.first
        )
        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(imported)) as? [String: Any]
        )
        var currentCondition = try XCTUnwrap(
            legacyObject["modifier1Condition"] as? [String: Any]
        )
        currentCondition.removeValue(forKey: "target")
        legacyObject["modifier1Condition"] = currentCondition
        var importedState = try XCTUnwrap(legacyObject["importedCMAD"] as? [String: Any])
        var fingerprint = try XCTUnwrap(importedState["semanticAtImport"] as? [String: Any])
        var baselineCondition = try XCTUnwrap(
            fingerprint["modifier1Condition"] as? [String: Any]
        )
        baselineCondition.removeValue(forKey: "target")
        fingerprint["modifier1Condition"] = baselineCondition
        importedState["semanticAtImport"] = fingerprint
        legacyObject["importedCMAD"] = importedState

        var decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )

        XCTAssertEqual(
            try encodedTargetRaw(XCTUnwrap(decoded.modifier1Condition)),
            unknownRaw
        )
        XCTAssertEqual(
            try encodedTargetRaw(
                XCTUnwrap(decoded.importedCMAD?.semanticAtImport.modifier1Condition)
            ),
            unknownRaw
        )
        decoded.modifier1Condition?.value = 7
        XCTAssertEqual(
            readUInt32(try TSIWriter().preservingCMADPayload(for: decoded), at: 56),
            unknownRaw
        )
    }

    func testLegacyCodableDoesNotPromoteStaleInactiveTargetIntoAddedCondition() throws {
        var mapping = try XCTUnwrap(
            try interpretCMAD(
                makeCMAD(conditionOne: (modifier: 0, target: 0xFEED_FACE, value: 0))
            ).devices.first?.mappings.first
        )
        XCTAssertNil(mapping.importedCMAD?.semanticAtImport.modifier1Condition)
        mapping.modifier1Condition = ModifierCondition(modifier: 2, value: 3)
        var legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(mapping)) as? [String: Any]
        )
        var currentCondition = try XCTUnwrap(
            legacyObject["modifier1Condition"] as? [String: Any]
        )
        currentCondition.removeValue(forKey: "target")
        legacyObject["modifier1Condition"] = currentCondition

        let decoded = try JSONDecoder().decode(
            MappingEntry.self,
            from: JSONSerialization.data(withJSONObject: legacyObject)
        )

        XCTAssertEqual(decoded.modifier1Condition?.target, .deckA)
        XCTAssertNil(decoded.importedCMAD?.semanticAtImport.modifier1Condition)
    }

    func testSemanticBindingKeyUsesModeledKnownAndUnknownTargets() throws {
        for rawTarget: UInt32 in [3, 0xCAFE_BABE] {
            let mapping = try XCTUnwrap(
                try interpretCMAD(
                    makeCMAD(
                        conditionOne: (modifier: 2, target: rawTarget, value: 3)
                    )
                ).devices.first?.mappings.first
            )

            let key = try XCTUnwrap(
                SemanticBindingKey(entry: mapping),
                "a losslessly modeled target must participate in semantic identity"
            )
            XCTAssertEqual(key.conditionOne?.target, rawTarget)
        }
    }

    // MARK: - Real wire helpers

    private func condition(
        modifier: Int,
        targetRaw: UInt32,
        value: Int
    ) throws -> ModifierCondition {
        let object: [String: Any] = [
            "modifier": modifier,
            "target": targetRaw,
            "value": value,
        ]
        return try JSONDecoder().decode(
            ModifierCondition.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
    }

    private func encodedTargetRaw(_ condition: ModifierCondition) throws -> UInt32? {
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(condition)) as? [String: Any]
        )
        return (object["target"] as? NSNumber)?.uint32Value
    }

    private func roundTrip(_ entry: MappingEntry) throws -> MappingEntry? {
        let tsi = try TSIWriter().write(
            MappingFile(devices: [Device(name: "Target Test", mappings: [entry])])
        )
        let base64 = try TSIParser.extractControllerData(from: tsi)
        let binary = try TSIParser().decodeBase64(base64)
        let frames = try TSIParser().parseFrames(from: binary)
        return try TSIInterpreter.interpret(frames: frames).devices.first?.mappings.first
    }

    private func interpretCMAD(_ cmad: Data) throws -> MappingFile {
        let cmai = be32(TSIBindingID.unassigned)
            + be32(0)
            + be32(100)
            + rawFrame("CMAD", cmad)
        let cmas = be32(1) + rawFrame("CMAI", cmai)
        let devi = tsiString("Target Test") + rawFrame("CMAS", cmas)
        let devs = be32(1) + rawFrame("DEVI", devi)
        let frames = try TSIParser().parseFrames(from: rawFrame("DIOM", rawFrame("DEVS", devs)))
        return try TSIInterpreter.interpret(frames: frames)
    }

    private func makeCMAD(
        conditionOne: (modifier: UInt32, target: UInt32, value: UInt32) = (0, 0, 0),
        conditionTwo: (modifier: UInt32, target: UInt32, value: UInt32) = (0, 0, 0),
        optionalTailSeed: UInt8 = 0,
        trailingBytes: Data = Data()
    ) -> Data {
        var data = Data(repeating: 0, count: 120)
        replaceUInt32(4, in: &data, at: 0)
        replaceUInt32(2, in: &data, at: 8)
        replaceUInt32(conditionOne.modifier, in: &data, at: 52)
        replaceUInt32(conditionOne.target, in: &data, at: 56)
        replaceUInt32(conditionOne.value, in: &data, at: 60)
        replaceUInt32(conditionTwo.modifier, in: &data, at: 64)
        replaceUInt32(conditionTwo.target, in: &data, at: 68)
        replaceUInt32(conditionTwo.value, in: &data, at: 72)
        if optionalTailSeed != 0 {
            for offset in 76..<120 {
                data[offset] = optionalTailSeed &+ UInt8(offset - 76)
            }
        }
        data.append(trailingBytes)
        return data
    }

    private func replaceUInt32(_ value: UInt32, in data: inout Data, at offset: Int) {
        data.replaceSubrange(offset..<(offset + 4), with: be32(value))
    }

    private func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }

    private func be32(_ value: UInt32) -> Data {
        var bigEndian = value.bigEndian
        return Data(bytes: &bigEndian, count: 4)
    }

    private func rawFrame(_ identifier: String, _ payload: Data) -> Data {
        identifier.data(using: .ascii)! + be32(UInt32(payload.count)) + payload
    }

    private func tsiString(_ string: String) -> Data {
        be32(UInt32(string.utf16.count)) + utf16BE(string)
    }

    private func utf16BE(_ string: String) -> Data {
        string.utf16.reduce(into: Data()) { data, codeUnit in
            var bigEndian = codeUnit.bigEndian
            data.append(Data(bytes: &bigEndian, count: 2))
        }
    }
}
