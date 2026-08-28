//
//  TSIParserTests.swift
//  XtremeMappingTests
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import XCTest
@testable import XtremeMapping

final class TSIParserTests: XCTestCase {

    // MARK: - TSIFrame Tests

    func testParseFrameIdentifier() throws {
        // "DEVI" + size 0 (big-endian)
        let data = Data([0x44, 0x45, 0x56, 0x49, 0x00, 0x00, 0x00, 0x00])
        let frame = try TSIFrame.parse(from: data)
        XCTAssertEqual(frame.identifier, "DEVI")
    }

    func testParseFrameSize() throws {
        // "CMAS" + size 0 (big-endian: 0x00000000)
        let data = Data([0x43, 0x4D, 0x41, 0x53, 0x00, 0x00, 0x00, 0x00])
        let frame = try TSIFrame.parse(from: data)
        XCTAssertEqual(frame.identifier, "CMAS")
        XCTAssertEqual(frame.size, 0)
    }

    func testParseFrameSizeWithLargePayload() throws {
        // "TEST" + size 256 (big-endian: 0x00000100) + 256 bytes of data
        var data = Data([0x54, 0x45, 0x53, 0x54, 0x00, 0x00, 0x01, 0x00])
        // Append 256 bytes of data (all 0xFF)
        data.append(contentsOf: [UInt8](repeating: 0xFF, count: 256))
        let frame = try TSIFrame.parse(from: data)
        XCTAssertEqual(frame.identifier, "TEST")
        XCTAssertEqual(frame.size, 256)
        XCTAssertEqual(frame.data.count, 256)
    }

    func testParseFrameWithData() throws {
        // "CMAI" + size 4 + 4 bytes of data
        let data = Data([0x43, 0x4D, 0x41, 0x49, 0x00, 0x00, 0x00, 0x04, 0x01, 0x02, 0x03, 0x04])
        let frame = try TSIFrame.parse(from: data)
        XCTAssertEqual(frame.identifier, "CMAI")
        XCTAssertEqual(frame.size, 4)
        XCTAssertEqual(frame.data, Data([0x01, 0x02, 0x03, 0x04]))
    }

    func testParseFrameUnexpectedEndOfData() throws {
        // Only 6 bytes - not enough for header (8 bytes minimum)
        let data = Data([0x44, 0x45, 0x56, 0x49, 0x00, 0x00])
        XCTAssertThrowsError(try TSIFrame.parse(from: data)) { error in
            XCTAssertEqual(error as? TSIParserError, TSIParserError.unexpectedEndOfData)
        }
    }

    func testParseFrameDataTruncated() throws {
        // "DEVI" + size 10 but only 2 bytes of data provided
        let data = Data([0x44, 0x45, 0x56, 0x49, 0x00, 0x00, 0x00, 0x0A, 0x01, 0x02])
        XCTAssertThrowsError(try TSIFrame.parse(from: data)) { error in
            XCTAssertEqual(error as? TSIParserError, TSIParserError.unexpectedEndOfData)
        }
    }

    // MARK: - TSIParser Frame Parsing Tests

    func testParseMultipleFrames() throws {
        // Two frames: "DEVI" (size 0) + "CMAS" (size 2) with data [0xAB, 0xCD]
        var data = Data()
        // Frame 1: DEVI, size 0
        data.append(contentsOf: [0x44, 0x45, 0x56, 0x49, 0x00, 0x00, 0x00, 0x00])
        // Frame 2: CMAS, size 2, data [0xAB, 0xCD]
        data.append(contentsOf: [0x43, 0x4D, 0x41, 0x53, 0x00, 0x00, 0x00, 0x02, 0xAB, 0xCD])

        let parser = TSIParser()
        let frames = try parser.parseFrames(from: data)

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].identifier, "DEVI")
        XCTAssertEqual(frames[0].size, 0)
        XCTAssertEqual(frames[1].identifier, "CMAS")
        XCTAssertEqual(frames[1].size, 2)
        XCTAssertEqual(frames[1].data, Data([0xAB, 0xCD]))
    }

    func testParseEmptyData() throws {
        let parser = TSIParser()
        let frames = try parser.parseFrames(from: Data())
        XCTAssertEqual(frames.count, 0)
    }

    // MARK: - XML Extraction Tests

    func testExtractBase64FromXML() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NIXML>
          <TraktorSettings>
            <Entry Name="DeviceIO.Config.Controller" Type="3" Value="SEVMTE8="/>
          </TraktorSettings>
        </NIXML>
        """
        let base64 = try TSIParser.extractControllerData(from: xml.data(using: .utf8)!)
        XCTAssertEqual(base64, "SEVMTE8=")
    }

    func testExtractBase64FromXMLWithNestedElements() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NIXML>
          <TraktorSettings>
            <Entry Name="SomeOther.Config" Type="1" Value="ignored"/>
            <Entry Name="DeviceIO.Config.Controller" Type="3" Value="QkFTRTY0"/>
            <Entry Name="Another.Entry" Type="2" Value="also_ignored"/>
          </TraktorSettings>
        </NIXML>
        """
        let base64 = try TSIParser.extractControllerData(from: xml.data(using: .utf8)!)
        XCTAssertEqual(base64, "QkFTRTY0")
    }

    func testExtractBase64ThrowsOnMissingEntry() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <NIXML>
          <TraktorSettings>
            <Entry Name="SomeOther.Config" Type="1" Value="ignored"/>
          </TraktorSettings>
        </NIXML>
        """
        XCTAssertThrowsError(try TSIParser.extractControllerData(from: xml.data(using: .utf8)!)) { error in
            XCTAssertEqual(error as? TSIParserError, TSIParserError.missingControllerEntry)
        }
    }

    func testExtractBase64ThrowsOnInvalidXML() throws {
        let invalidXML = "This is not XML at all"
        XCTAssertThrowsError(try TSIParser.extractControllerData(from: invalidXML.data(using: .utf8)!)) { error in
            XCTAssertEqual(error as? TSIParserError, TSIParserError.invalidXML)
        }
    }

    // MARK: - Base64 Decoding Tests

    func testDecodeBase64() throws {
        let parser = TSIParser()
        // "HELLO" in Base64
        let decoded = try parser.decodeBase64("SEVMTE8=")
        XCTAssertEqual(String(data: decoded, encoding: .utf8), "HELLO")
    }

    func testDecodeBase64ThrowsOnInvalid() throws {
        let parser = TSIParser()
        // Invalid Base64 string
        XCTAssertThrowsError(try parser.decodeBase64("!!!INVALID!!!")) { error in
            XCTAssertEqual(error as? TSIParserError, TSIParserError.invalidBase64)
        }
    }

    // MARK: - Bounded Streaming XML

    func testRejectsUTF16AndUTF32BeforeXMLParsing() {
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-16\"?><NIXML/>"
        for encoding in [String.Encoding.utf16, .utf16BigEndian, .utf16LittleEndian,
                         .utf32, .utf32BigEndian, .utf32LittleEndian] {
            let data = xml.data(using: encoding)!
            XCTAssertThrowsError(try TSIParser.scanXML(data), "encoding \(encoding.rawValue)") {
                XCTAssertEqual($0 as? TSIParserError, .unsupportedXMLEncoding)
            }
        }
    }

    func testAcceptsUTF8BOMAndCountsStartElementsExactlyOnce() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append("<NIXML><!-- comment --><A>text</A><Entry Name=\"DeviceIO.Config.Controller\" Value=\"QQ==\"/></NIXML>".data(using: .utf8)!)

        let result = try TSIParser.scanXML(data)

        XCTAssertEqual(result.controllerValues, ["QQ=="])
        XCTAssertEqual(result.elementCount, 3)
        XCTAssertFalse(result.hasNonControllerEntries)
    }

    func testRejectsFalseXMLEncodingDeclarations() {
        for declaredEncoding in ["UTF-16", "UTF-32", "ISO-8859-1", "US-ASCII"] {
            let xml = "<?xml version='1.0' encoding='\(declaredEncoding)'?><NIXML/>"
            XCTAssertThrowsError(try TSIParser.scanXML(xml.data(using: .utf8)!)) {
                XCTAssertEqual($0 as? TSIParserError, .unsupportedXMLEncoding)
            }
        }
    }

    func testRejectsInvalidUTF8() {
        XCTAssertThrowsError(try TSIParser.scanXML(Data([0x3C, 0xFF, 0x3E]))) {
            XCTAssertEqual($0 as? TSIParserError, .unsupportedXMLEncoding)
        }
    }

    func testRejectsDTDInternalEntityAmplificationAndExternalEntities() {
        let documents = [
            "<!DOCTYPE NIXML [<!ENTITY a '1234567890'>]><NIXML>&a;</NIXML>",
            "<!DOCTYPE NIXML SYSTEM 'file:///etc/passwd'><NIXML/>",
            "<!DOCTYPE NIXML [<!ENTITY xxe SYSTEM 'file:///etc/passwd'>]><NIXML>&xxe;</NIXML>",
            "<!doctype NIXML [<!entity a 'x'>]><NIXML>&a;</NIXML>"
        ]

        for xml in documents {
            XCTAssertThrowsError(try TSIParser.scanXML(xml.data(using: .utf8)!), xml) {
                XCTAssertEqual($0 as? TSIParserError, .prohibitedXMLDeclaration)
            }
        }
    }

    func testXMLByteLimitAtMinusOneLimitAndPlusOne() throws {
        let data = "<NIXML/>".data(using: .utf8)!
        for maximum in [data.count - 1, data.count, data.count + 1] {
            let limits = TSIParseLimits(maximumXMLBytes: maximum)
            if maximum < data.count {
                XCTAssertThrowsError(try TSIParser.scanXML(data, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .xmlByteLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIParser.scanXML(data, limits: limits).elementCount, 1)
            }
        }
    }

    func testXMLElementLimitAtMinusOneLimitAndPlusOne() throws {
        let data = "<NIXML><A/><Entry Name=\"DeviceIO.Config.Controller\" Value=\"QQ==\"/></NIXML>".data(using: .utf8)!
        for maximum in [2, 3, 4] {
            let limits = TSIParseLimits(maximumXMLElements: maximum)
            if maximum == 2 {
                XCTAssertThrowsError(try TSIParser.scanXML(data, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .xmlElementLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIParser.scanXML(data, limits: limits).elementCount, 3)
            }
        }
    }

    func testXMLDepthLimitAtMinusOneLimitAndPlusOne() throws {
        let data = "<A><B><C/></B></A>".data(using: .utf8)!
        for maximum in [2, 3, 4] {
            let limits = TSIParseLimits(maximumXMLNestingDepth: maximum)
            if maximum == 2 {
                XCTAssertThrowsError(try TSIParser.scanXML(data, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .xmlDepthLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIParser.scanXML(data, limits: limits).elementCount, 3)
            }
        }
    }

    func testControllerEntryLimitAndNonControllerInventory() throws {
        let data = "<NIXML><Entry Name=\"Other\" Value=\"x\"/><Entry Name=\"DeviceIO.Config.Controller\" Value=\"QQ==\"/><Entry Name=\"DeviceIO.Config.Controller\" Value=\"Qg==\"/></NIXML>".data(using: .utf8)!
        for maximum in [1, 2, 3] {
            let limits = TSIParseLimits(maximumControllerEntries: maximum)
            if maximum == 1 {
                XCTAssertThrowsError(try TSIParser.scanXML(data, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .controllerEntryLimitExceeded)
                }
            } else {
                let result = try TSIParser.scanXML(data, limits: limits)
                XCTAssertEqual(result.controllerValues, ["QQ==", "Qg=="])
                XCTAssertTrue(result.hasNonControllerEntries)
            }
        }
    }

    func testBase64AttributeCharacterLimitAtMinusOneLimitAndPlusOne() throws {
        let data = "<NIXML><Entry Name=\"DeviceIO.Config.Controller\" Value=\"SEVMTE8=\"/></NIXML>".data(using: .utf8)!
        for maximum in [7, 8, 9] {
            let limits = TSIParseLimits(maximumBase64AttributeCharacters: maximum)
            if maximum == 7 {
                XCTAssertThrowsError(try TSIParser.scanXML(data, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .base64CharacterLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIParser.scanXML(data, limits: limits).controllerValues, ["SEVMTE8="])
            }
        }
    }

    // MARK: - Strict Base64 and Binary Cursor

    func testStrictBase64RejectsWhitespaceAlphabetAndPaddingViolations() {
        let invalidValues = [
            "SEVM TE8=", "SEVM\nTE8=", "SEVM_TE8=", "SEVM-TE8=",
            "=EVLTE8=", "SE=LTE8=", "SEVMTE8===", "SEVMTE8", "Zh==", "Zm9="
        ]
        for value in invalidValues {
            XCTAssertThrowsError(try TSIParser().decodeBase64(value), value) {
                XCTAssertEqual($0 as? TSIParserError, .invalidBase64)
            }
        }
    }

    func testStrictBase64AcceptsCanonicalAlphabetAndPadding() throws {
        XCTAssertEqual(try TSIParser().decodeBase64(""), Data())
        XCTAssertEqual(try TSIParser().decodeBase64("Zg=="), Data([0x66]))
        XCTAssertEqual(try TSIParser().decodeBase64("Zm8="), Data([0x66, 0x6F]))
        XCTAssertEqual(try TSIParser().decodeBase64("+/8A"), Data([0xFB, 0xFF, 0x00]))
    }

    func testDecodedControllerByteLimitAtMinusOneLimitAndPlusOne() throws {
        for maximum in [4, 5, 6] {
            let parser = TSIParser(limits: TSIParseLimits(maximumDecodedControllerBytes: maximum))
            if maximum == 4 {
                XCTAssertThrowsError(try parser.decodeBase64("SEVMTE8=")) {
                    XCTAssertEqual($0 as? TSIParserError, .decodedControllerByteLimitExceeded)
                }
            } else {
                XCTAssertEqual(try parser.decodeBase64("SEVMTE8="), "HELLO".data(using: .utf8)!)
            }
        }
    }

    func testOffsetFrameCursorHandlesUnalignedStartAndReturnsNextOffset() throws {
        let data = Data([0xFF]) + Data([0x54, 0x45, 0x53, 0x54, 0, 0, 0, 3, 1, 2, 3, 0xEE])

        let parsed = try TSIFrame.parse(from: data, at: 1, limits: .default)

        XCTAssertEqual(parsed.frame.identifier, "TEST")
        XCTAssertEqual(parsed.frame.size, 3)
        XCTAssertEqual(parsed.frame.data, Data([1, 2, 3]))
        XCTAssertEqual(parsed.nextOffset, 12)
    }

    func testOffsetFrameCursorTreatsOffsetsAsRelativeToSlicedData() throws {
        let firstFrame = Data("TEST".utf8) + Data([0, 0, 0, 3, 1, 2, 3])
        let secondFrame = Data("NEXT".utf8) + Data([0, 0, 0, 0])
        let backing = Data([0xAA]) + firstFrame + secondFrame + Data([0xEE])
        let slicedData = backing[1..<(backing.count - 1)]
        XCTAssertEqual(slicedData.startIndex, 1)

        let parsed = try TSIFrame.parse(from: slicedData, at: 0, limits: .default)
        XCTAssertEqual(parsed.frame.identifier, "TEST")
        XCTAssertEqual(parsed.frame.data, Data([1, 2, 3]))
        XCTAssertEqual(parsed.nextOffset, 11)

        let frames = try TSIParser().parseFrames(from: slicedData)
        XCTAssertEqual(frames.map(\.identifier), ["TEST", "NEXT"])
    }

    func testFramePayloadLimitAtMinusOneLimitAndPlusOne() throws {
        let data = Data("TEST".utf8) + Data([0, 0, 0, 3, 1, 2, 3])
        for maximum in [2, 3, 4] {
            let limits = TSIParseLimits(maximumIndividualFramePayload: maximum)
            if maximum == 2 {
                XCTAssertThrowsError(try TSIFrame.parse(from: data, at: 0, limits: limits)) {
                    XCTAssertEqual($0 as? TSIParserError, .framePayloadLimitExceeded)
                }
            } else {
                XCTAssertEqual(try TSIFrame.parse(from: data, at: 0, limits: limits).frame.data, Data([1, 2, 3]))
            }
        }
    }

    func testOffsetFrameCursorRejectsOverflowAndTruncation() {
        XCTAssertThrowsError(try TSIFrame.parse(from: Data(), at: Int.max, limits: .default)) {
            XCTAssertEqual($0 as? TSIParserError, .integerOverflow)
        }
        let truncated = Data("TEST".utf8) + Data([0xFF, 0xFF, 0xFF, 0xFF])
        XCTAssertThrowsError(try TSIFrame.parse(from: truncated, at: 0, limits: .default)) {
            XCTAssertEqual($0 as? TSIParserError, .framePayloadLimitExceeded)
        }
        let shortPayload = Data("TEST".utf8) + Data([0, 0, 0, 2, 0x01])
        XCTAssertThrowsError(try TSIFrame.parse(from: shortPayload, at: 0, limits: .default)) {
            XCTAssertEqual($0 as? TSIParserError, .unexpectedEndOfData)
        }
    }

    func testPerContainerAndCumulativeFrameLimitsAtBoundaries() throws {
        let frame = Data("TEST".utf8) + Data([0, 0, 0, 0])
        let threeFrames = frame + frame + frame

        for maximum in [2, 3, 4] {
            let parser = TSIParser(limits: TSIParseLimits(maximumFramesPerContainer: maximum))
            if maximum == 2 {
                XCTAssertThrowsError(try parser.parseFrames(from: threeFrames)) {
                    XCTAssertEqual($0 as? TSIParserError, .frameCountLimitExceeded)
                }
            } else {
                XCTAssertEqual(try parser.parseFrames(from: threeFrames).count, 3)
            }
        }

        for maximum in [2, 3, 4] {
            let parser = TSIParser(limits: TSIParseLimits(maximumCumulativeFrames: maximum))
            if maximum == 2 {
                XCTAssertThrowsError(try parser.parseFrames(from: threeFrames)) {
                    XCTAssertEqual($0 as? TSIParserError, .cumulativeFrameLimitExceeded)
                }
            } else {
                XCTAssertEqual(try parser.parseFrames(from: threeFrames).count, 3)
            }
        }
    }

    func testInstrumentationMeasuresOnlyRetainedPayloadCopies() throws {
        let firstFrame = Data("ONE!".utf8) + Data([0, 0, 0, 1, 0x11])
        let secondFrame = Data("TWO!".utf8)
            + Data([0, 0, 0, 3, 0x21, 0x22, 0x23])
        let instrumentation = TSIParseInstrumentation()

        let frames = try TSIParser(instrumentation: instrumentation)
            .parseFrames(from: firstFrame + secondFrame)

        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(instrumentation.snapshot.retainedPayloadCopyCount, 2)
        XCTAssertEqual(instrumentation.snapshot.retainedPayloadBytesCopied, 4)
        XCTAssertEqual(instrumentation.snapshot.maximumRetainedPayloadCopyBytes, 3)
    }

    func testLinearFrameParsingCopiesOnlyRetainedPayloads() throws {
        let frame = Data("TEST".utf8) + Data([0, 0, 0, 8]) + Data(repeating: 0xA5, count: 8)
        let smallData = (0..<2_000).reduce(into: Data()) { data, _ in data.append(frame) }
        let largeData = (0..<8_000).reduce(into: Data()) { data, _ in data.append(frame) }

        _ = try TSIParser().parseFrames(from: smallData)
        _ = try TSIParser().parseFrames(from: largeData)

        let smallInstrumentation = TSIParseInstrumentation()
        let smallStart = Date.timeIntervalSinceReferenceDate
        XCTAssertEqual(try TSIParser(instrumentation: smallInstrumentation).parseFrames(from: smallData).count, 2_000)
        let smallDuration = Date.timeIntervalSinceReferenceDate - smallStart

        let largeInstrumentation = TSIParseInstrumentation()
        let largeStart = Date.timeIntervalSinceReferenceDate
        XCTAssertEqual(try TSIParser(instrumentation: largeInstrumentation).parseFrames(from: largeData).count, 8_000)
        let largeDuration = Date.timeIntervalSinceReferenceDate - largeStart

        XCTAssertEqual(smallInstrumentation.snapshot.parsedFrameCount, 2_000)
        XCTAssertEqual(largeInstrumentation.snapshot.parsedFrameCount, 8_000)
        XCTAssertEqual(smallInstrumentation.snapshot.frameHeaderBytesRead, 16_000)
        XCTAssertEqual(largeInstrumentation.snapshot.frameHeaderBytesRead, 64_000)
        XCTAssertEqual(smallInstrumentation.snapshot.retainedPayloadCopyCount, 2_000)
        XCTAssertEqual(largeInstrumentation.snapshot.retainedPayloadCopyCount, 8_000)
        XCTAssertEqual(smallInstrumentation.snapshot.retainedPayloadBytesCopied, 16_000)
        XCTAssertEqual(largeInstrumentation.snapshot.retainedPayloadBytesCopied, 64_000)
        XCTAssertEqual(smallInstrumentation.snapshot.maximumRetainedPayloadCopyBytes, 8)
        XCTAssertEqual(largeInstrumentation.snapshot.maximumRetainedPayloadCopyBytes, 8)
        XCTAssertEqual(smallInstrumentation.snapshot.cursorBytesAdvanced, smallData.count)
        XCTAssertEqual(largeInstrumentation.snapshot.cursorBytesAdvanced, largeData.count)
        XCTAssertLessThan(largeDuration / max(smallDuration, 0.000_001), 8.0)
    }
}
