//
//  TSIPreservationTests.swift
//  XtremeMappingTests
//

import XCTest
@testable import XtremeMapping

final class TSIPreservationTests: XCTestCase {
    func testLiteralMinimalDocumentIsOrdinarySaveSafeAndUnchangedWriteIsExact() throws {
        let xml = completeXML(binary: emptyControllerBinary())

        let file = try TSIParser().parseDocument(xml)

        XCTAssertEqual(file.sourceEnvelope?.originalXML, xml)
        XCTAssertEqual(file.sourceEnvelope?.controllerValues.count, 1)
        XCTAssertEqual(file.sourceEnvelope?.primaryFrames.map(\.identifier), ["DIOM"])
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .ordinarySaveSafe)
        XCTAssertEqual(try TSIWriter().write(file), xml)
    }

    func testUnknownFrameImportsButBlocksEditedOrdinaryWrite() throws {
        let binary = rawFrame("JUNK", Data([0xCA, 0xFE])) + emptyControllerBinary()
        let file = try TSIParser().parseDocument(completeXML(binary: binary))

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.unknownFrame])
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .lossyConvertible)

        var edited = file
        edited.devices[0].comment = "edited"
        XCTAssertThrowsError(try TSIWriter().write(edited)) { error in
            XCTAssertEqual(
                error as? TSIPreservationError,
                .unsafeOverwrite(risks: edited.sourceEnvelope?.risks ?? [])
            )
        }
        XCTAssertNoThrow(try TSIParser().parseDocument(TSIWriter().writeConverted(edited)))
    }

    func testExtraXMLAndControllerEntriesHaveStableOrderedRisks() throws {
        let value = emptyControllerBinary().base64EncodedString()
        let xml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <NIXML><TraktorSettings>
        <Entry Name="Other.Setting" Type="1" Value="kept"/>
        <Entry Name="DeviceIO.Config.Controller" Type="3" Value="\(value)"/>
        <Entry Name="DeviceIO.Config.Controller" Type="3" Value="\(value)"/>
        </TraktorSettings></NIXML>
        """.utf8)

        let file = try TSIParser().parseDocument(xml)

        XCTAssertEqual(file.sourceEnvelope?.controllerValues, [value, value])
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .extraXMLEntry,
            .extraControllerEntry,
        ])
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .lossyConvertible)
    }

    func testCDATAContentIsRiskAndBlocksEditedOrdinarySave() throws {
        let value = emptyControllerBinary().base64EncodedString()
        let xml = Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <NIXML><TraktorSettings><Entry Name="DeviceIO.Config.Controller" Type="3" Value="\(value)"/><![CDATA[proprietary settings]]></TraktorSettings></NIXML>
        """.utf8)
        var file = try TSIParser().parseDocument(xml)

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.nonstandardXMLStructure])
        file.devices[0].comment = "edited"
        XCTAssertThrowsError(try TSIWriter().write(file)) {
            XCTAssertTrue($0 is TSIPreservationError)
        }
    }

    func testChangedOrdinarySaveSafeImportedMappingWritesAndReparses() throws {
        var file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary())
        )
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .ordinarySaveSafe)

        file.devices[0].comment = "edited safely"
        let written = try TSIWriter().write(file)
        let reparsed = try TSIParser().parseDocument(written)

        XCTAssertEqual(reparsed.devices[0].comment, "edited safely")
        XCTAssertEqual(reparsed.devices[0].mappings.count, 1)
    }

    func testNoncanonicalDIOIAndDDIFAreTypedRisks() throws {
        let binary = emptyControllerBinary(dioi: 7, ddif: 9)
        let file = try TSIParser().parseDocument(completeXML(binary: binary))

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .noncanonicalDDIF,
            .noncanonicalDIOI,
        ])
    }

    func testDuplicateSingletonImportsUsingFirstAndIsTypedRisk() throws {
        let binary = emptyControllerBinary(extraDIOMFrames: rawFrame("DIOI", be32(1)))
        let file = try TSIParser().parseDocument(completeXML(binary: binary))

        XCTAssertEqual(file.devices.count, 1)
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.duplicateSingletonFrame])
    }

    func testCorruptDuplicateTopLevelContainersThrow() {
        let corruptDuplicates: [(String, Data)] = [
            ("DIOM truncated", emptyControllerBinary() + rawFrame("DIOM", Data([0x00]))),
            ("DEVS count mismatch", emptyControllerBinary(
                extraDIOMFrames: rawFrame("DEVS", be32(1))
            )),
        ]

        for (name, binary) in corruptDuplicates {
            XCTAssertThrowsError(
                try TSIParser().parseDocument(completeXML(binary: binary)), name
            )
        }
    }

    func testCorruptDuplicateDeviceContainersThrow() {
        let corruptDocuments: [(String, Data)] = [
            ("DDAT truncated", emptyControllerBinary(
                extraDeviceFrames: rawFrame("DDAT", Data([0x00]))
            )),
            ("DDDC truncated", emptyControllerBinary(
                extraDDATFrames: rawFrame("DDDC", Data([0x00]))
            )),
            ("DDCB truncated", emptyControllerBinary(
                extraDDATFrames: rawFrame("DDCB", Data([0x00]))
            )),
            ("DDCI count mismatch", emptyControllerBinary(definitionFrames:
                rawFrame("DDCI", be32(0)) + rawFrame("DDCI", be32(1)))),
            ("DDCO count mismatch", emptyControllerBinary(definitionFrames:
                rawFrame("DDCO", be32(0)) + rawFrame("DDCO", be32(1)))),
            ("CMAS count mismatch", emptyControllerBinary(commandFrames:
                rawFrame("CMAS", be32(0)) + rawFrame("CMAS", be32(1))
                    + rawFrame("DCBM", be32(0)))),
            ("DCBM count mismatch", emptyControllerBinary(commandFrames:
                rawFrame("CMAS", be32(0)) + rawFrame("DCBM", be32(0))
                    + rawFrame("DCBM", be32(0) + rawFrame(
                        "DCBM", be32(7) + wide("Ch01.CC.007")
                    )))),
        ]

        for (name, binary) in corruptDocuments {
            XCTAssertThrowsError(
                try TSIParser().parseDocument(completeXML(binary: binary)), name
            )
        }
    }

    func testTruncatedDuplicateModeledScalarsThrow() {
        let corruptDocuments: [(String, Data)] = [
            ("DIOI truncated", emptyControllerBinary(
                extraDIOMFrames: rawFrame("DIOI", Data([0x00]))
            )),
            ("DDIF truncated", emptyControllerBinary(
                extraDDATFrames: rawFrame("DDIF", Data([0x00]))
            )),
            ("DDIV truncated", emptyControllerBinary(
                extraDDATFrames: rawFrame("DDIV", wide("3.11.0"))
            )),
            ("DDIC truncated", emptyControllerBinary(
                extraDDATFrames: rawFrame("DDIC", be32(1))
            )),
            ("DDPT truncated", emptyControllerBinary(
                extraDDATFrames: rawFrame("DDPT", wide("All Ports"))
            )),
        ]

        for (name, binary) in corruptDocuments {
            XCTAssertThrowsError(
                try TSIParser().parseDocument(completeXML(binary: binary)), name
            )
        }
    }

    func testStructurallyValidDuplicateContainersRemainImportableAndLossyConvertible() throws {
        let validSecondDevice = rawFrame(
            "DEVI",
            wide("Generic MIDI") + rawFrame("DDAT",
                rawFrame("DDIF", be32(0))
                    + rawFrame("DDIV", wide("3.11.0") + be32(2))
                    + rawFrame("DDIC", wide(""))
                    + rawFrame("DDPT", wide("All Ports") + wide("All Ports"))
                    + rawFrame("DDDC", Data())
                    + rawFrame("DDCB", rawFrame("CMAS", be32(0)) + rawFrame("DCBM", be32(0)))
            )
        )
        let duplicateDEVS = rawFrame("DEVS", be32(1) + validSecondDevice)
        let file = try TSIParser().parseDocument(completeXML(binary:
            emptyControllerBinary(extraDIOMFrames: duplicateDEVS)
        ))

        XCTAssertEqual(file.devices.count, 1)
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.duplicateSingletonFrame])
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .lossyConvertible)
    }

    func testUnusedAndDuplicateDCDTRowsAreTypedRisks() throws {
        let used = dcdt(name: "Ch01.CC.010")
        let unused = dcdt(name: "Ch01.CC.011")
        let definitions = rawFrame(
            "DDCI",
            be32(3) + rawFrame("DCDT", used) + rawFrame("DCDT", used) + rawFrame("DCDT", unused)
        )
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(definitions: definitions))
        )

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .duplicateMIDIDefinition,
            .unusedMIDIDefinition,
        ])
    }

    func testDuplicateDefinitionSingletonContainerImportsAndIsTypedRisk() throws {
        let definitions = rawFrame("DDCI", be32(0)) + rawFrame("DDCI", be32(0))
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(definitions: definitions))
        )

        XCTAssertEqual(file.devices[0].mappings.count, 1)
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .missingMIDIDefinition,
            .duplicateSingletonFrame,
        ])
    }

    func testUnusedAndDuplicateDCBMRowsImportAndAreTypedRisks() throws {
        let entries = rawFrame("DCBM", be32(0) + wide("Ch01.CC.010"))
            + rawFrame("DCBM", be32(0) + wide("Ch01.CC.020"))
            + rawFrame("DCBM", be32(1) + wide("Ch01.CC.011"))
        let bindings = rawFrame("DCBM", be32(3) + entries)
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(bindings: bindings))
        )

        XCTAssertEqual(file.devices[0].mappings[0].midiCC, 10)
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .duplicateMIDIBinding,
            .unusedMIDIBinding,
        ])
    }

    func testCommandZeroCMAIImportsAsTypedPlaceholderRisk() throws {
        let valid = rawFrame("CMAI", cmai(commandID: 100, cmad: completeCMAD()))
        let placeholder = rawFrame("CMAI", cmai(commandID: 0, cmad: completeCMAD()))
        let mappings = rawFrame("CMAS", be32(2) + valid + placeholder)
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(mappings: mappings))
        )

        XCTAssertEqual(file.devices[0].mappings.count, 1)
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.commandZeroMapping])
    }

    func testProprietaryDeviceTypeIsTypedAndNeverOrdinarySaveSafe() throws {
        var cmad = completeCMAD()
        replaceUInt32(in: &cmad, at: 0, with: 1)
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(cmad: cmad))
        )

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.proprietaryDeviceType])
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .lossyConvertible)
    }

    func testCoercedCMADEnumsHaveSpecificRisks() throws {
        var cmad = completeCMAD()
        replaceUInt32(in: &cmad, at: 4, with: 99)
        replaceUInt32(in: &cmad, at: 8, with: 99)
        replaceUInt32(in: &cmad, at: 12, with: 99)
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(cmad: cmad))
        )

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .coercedControllerType,
            .coercedInteractionMode,
            .coercedTargetAssignment,
        ])
    }

    func testPartialAndExtendedCMADLayoutsHaveSpecificRisks() throws {
        let partial = Data(completeCMAD().prefix(52))
        let partialFile = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(cmad: partial))
        )
        XCTAssertEqual(partialFile.sourceEnvelope?.risks.map(\.code), [.partialCMAD])

        let extended = completeCMAD() + Data([0xAA, 0xBB, 0xCC, 0xDD])
        let extendedFile = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(cmad: extended))
        )
        XCTAssertEqual(extendedFile.sourceEnvelope?.risks.map(\.code), [.extendedCMAD])
    }

    func testCompleteCMADScalarIsReproducibleThroughImportedWireState() throws {
        var cmad = completeCMAD()
        replaceUInt32(in: &cmad, at: 36, with: 7)
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(cmad: cmad))
        )

        XCTAssertEqual(file.sourceEnvelope?.risks, [])
        XCTAssertEqual(TSIWriter().preservationReport(for: file).disposition, .ordinarySaveSafe)
        XCTAssertEqual(file.devices[0].mappings[0].importedCMAD?.payload, cmad)
    }

    func testLossyCMADCommentHasSpecificStringRisk() throws {
        var cmad = completeCMAD()
        replaceUInt32(in: &cmad, at: 48, with: 1)
        cmad.insert(contentsOf: [0xD8, 0x00], at: 52) // Unpaired UTF-16 high surrogate.
        let file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary(cmad: cmad))
        )

        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [.lossyString])
    }

    func testDanglingBindingIsRetainedButTypedAsLossy() throws {
        let mapping = rawFrame("CMAS", be32(1) + rawFrame(
            "CMAI",
            cmai(bindingID: 99, commandID: 100, cmad: completeCMAD())
        ))
        let file = try TSIParser().parseDocument(completeXML(binary: mappedControllerBinary(
            mappings: mapping,
            bindings: rawFrame("DCBM", be32(0))
        )))

        XCTAssertEqual(file.devices[0].mappings[0].rawMidiBindingID, 99)
        XCTAssertEqual(file.sourceEnvelope?.risks.map(\.code), [
            .danglingMIDIBinding,
            .unusedMIDIDefinition,
        ])
    }

    func testWriterInvalidProjectionIsUnwritableForBothWritePaths() throws {
        var file = try TSIParser().parseDocument(
            completeXML(binary: mappedControllerBinary())
        )
        let invalidID = Int(UInt32.max) + 1
        file.devices[0].mappings[0].commandID = invalidID

        let report = TSIWriter().preservationReport(for: file)
        XCTAssertEqual(report.disposition, .unwritable)
        XCTAssertNotNil(report.validationError)
        XCTAssertThrowsError(try TSIWriter().write(file)) {
            XCTAssertEqual($0 as? TSIWriterError, .invalidCommandID(invalidID))
        }
        XCTAssertThrowsError(try TSIWriter().writeConverted(file)) {
            XCTAssertEqual($0 as? TSIWriterError, .invalidCommandID(invalidID))
        }
    }

    func testStructuralCorruptionStillThrowsAtDocumentBoundary() {
        let truncated = completeXML(binary: emptyControllerBinary() + Data([0x00]))
        XCTAssertThrowsError(try TSIParser().parseDocument(truncated)) {
            XCTAssertEqual($0 as? TSIParserError, .unexpectedEndOfData)
        }
    }

    // MARK: - Literal complete-document fixtures

    private func completeXML(binary: Data) -> Data {
        let value = binary.base64EncodedString()
        return Data("""
        <?xml version="1.0" encoding="UTF-8" standalone="no" ?>
        <NIXML><TraktorSettings><Entry Name="DeviceIO.Config.Controller" Type="3" Value="\(value)"/></TraktorSettings></NIXML>
        """.utf8)
    }

    private func emptyControllerBinary(
        dioi: UInt32 = 1,
        ddif: UInt32 = 0,
        extraDIOMFrames: Data = Data(),
        extraDeviceFrames: Data = Data(),
        extraDDATFrames: Data = Data(),
        definitionFrames: Data = Data(),
        commandFrames: Data = Data()
    ) -> Data {
        let actualCommandFrames = commandFrames.isEmpty
            ? rawFrame("CMAS", be32(0)) + rawFrame("DCBM", be32(0))
            : commandFrames
        let ddat = rawFrame("DDIF", be32(ddif))
            + rawFrame("DDIV", wide("3.11.0") + be32(2))
            + rawFrame("DDIC", wide(""))
            + rawFrame("DDPT", wide("All Ports") + wide("All Ports"))
            + rawFrame("DDDC", definitionFrames)
            + rawFrame("DDCB", actualCommandFrames)
            + extraDDATFrames
        let devi = rawFrame(
            "DEVI", wide("Generic MIDI") + rawFrame("DDAT", ddat) + extraDeviceFrames
        )
        let devs = rawFrame("DEVS", be32(1) + devi)
        return rawFrame("DIOM", rawFrame("DIOI", be32(dioi)) + extraDIOMFrames + devs)
    }

    private func mappedControllerBinary(
        cmad: Data = Data(),
        definitions: Data = Data(),
        mappings: Data = Data(),
        bindings: Data = Data()
    ) -> Data {
        let actualCMAD = cmad.isEmpty ? completeCMAD() : cmad
        let actualDefinitions = definitions.isEmpty
            ? rawFrame("DDCI", be32(1) + rawFrame("DCDT", dcdt(name: "Ch01.CC.010")))
            : definitions
        let actualMappings = mappings.isEmpty
            ? rawFrame("CMAS", be32(1) + rawFrame("CMAI", cmai(commandID: 100, cmad: actualCMAD)))
            : mappings
        let actualBindings = bindings.isEmpty
            ? rawFrame("DCBM", be32(1) + rawFrame("DCBM", be32(0) + wide("Ch01.CC.010")))
            : bindings
        let ddat = rawFrame("DDIF", be32(0))
            + rawFrame("DDIV", wide("3.11.0") + be32(2))
            + rawFrame("DDIC", wide(""))
            + rawFrame("DDPT", wide("All Ports") + wide("All Ports"))
            + rawFrame("DDDC", actualDefinitions)
            + rawFrame("DDCB", actualMappings + actualBindings)
        let devi = rawFrame("DEVI", wide("Generic MIDI") + rawFrame("DDAT", ddat))
        return rawFrame("DIOM", rawFrame("DIOI", be32(1)) + rawFrame("DEVS", be32(1) + devi))
    }

    private func cmai(bindingID: UInt32 = 0, commandID: UInt32, cmad: Data) -> Data {
        be32(bindingID) + be32(0) + be32(commandID) + rawFrame("CMAD", cmad)
    }

    private func completeCMAD() -> Data {
        var data = Data()
        let fields: [UInt32] = [
            4, 0, 2, 0, 0, 0, 0,
            Float32(5).bitPattern, Float32(0).bitPattern,
            0, 1, Float32(0).bitPattern,
        ]
        fields.forEach { data.append(be32($0)) }
        data.append(wide(""))
        [UInt32](repeating: 0, count: 6).forEach { data.append(be32($0)) }
        [1, 0, 1, 1, 0, 127, 0, 0, 1, 1, 0].forEach { data.append(be32(UInt32($0))) }
        XCTAssertEqual(data.count, 120)
        return data
    }

    private func dcdt(name: String) -> Data {
        wide(name)
            + be32(7)
            + be32(Float32(0).bitPattern)
            + be32(Float32(127).bitPattern)
            + be32(0)
            + be32(UInt32.max)
    }

    private func wide(_ value: String) -> Data {
        var data = be32(UInt32(value.utf16.count))
        for unit in value.utf16 {
            var bigEndian = unit.bigEndian
            data.append(Data(bytes: &bigEndian, count: 2))
        }
        return data
    }

    private func rawFrame(_ identifier: String, _ payload: Data) -> Data {
        Data(identifier.utf8) + be32(UInt32(payload.count)) + payload
    }

    private func be32(_ value: UInt32) -> Data {
        var bigEndian = value.bigEndian
        return Data(bytes: &bigEndian, count: 4)
    }

    private func replaceUInt32(in data: inout Data, at offset: Int, with value: UInt32) {
        data.replaceSubrange(offset..<(offset + 4), with: be32(value))
    }
}
