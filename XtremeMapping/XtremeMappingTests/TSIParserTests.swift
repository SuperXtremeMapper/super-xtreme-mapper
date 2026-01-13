//
//  TSIParserTests.swift
//  XtremeMappingTests
//
//  Created by Noah Raford on 13/01/2026.
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
}
