//
//  TSIParser.swift
//  XtremeMapping
//
//  Created by Noah Raford on 13/01/2026.
//

import Foundation

/// Errors that can occur during TSI file parsing
public enum TSIParserError: Error, Equatable, Sendable {
    /// The binary data ended unexpectedly while parsing
    case unexpectedEndOfData

    /// The XML document is invalid or malformed
    case invalidXML

    /// The DeviceIO.Config.Controller entry was not found in the XML
    case missingControllerEntry

    /// The Base64-encoded data is invalid
    case invalidBase64

    /// Decompression of the binary data failed
    case decompressionFailed
}

/// Parser for TSI (Traktor Settings Interface) files.
///
/// TSI files are XML documents containing Base64-encoded binary data.
/// The binary data uses an ID3v2-like frame format for storing controller mappings.
public struct TSIParser: Sendable {

    public init() {}

    // MARK: - XML Extraction

    /// Extracts the Base64-encoded controller data from TSI XML.
    ///
    /// TSI files have the following structure:
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <NIXML>
    ///   <TraktorSettings>
    ///     <Entry Name="DeviceIO.Config.Controller" Type="3" Value="[BASE64_BINARY]"/>
    ///   </TraktorSettings>
    /// </NIXML>
    /// ```
    ///
    /// - Parameter xmlData: The raw XML data
    /// - Returns: The Base64-encoded string from the Controller entry's Value attribute
    /// - Throws: `TSIParserError.invalidXML` if the XML is malformed,
    ///           `TSIParserError.missingControllerEntry` if the entry is not found
    public static func extractControllerData(from xmlData: Data) throws -> String {
        // Parse the XML document
        let document: XMLDocument
        do {
            document = try XMLDocument(data: xmlData)
        } catch {
            throw TSIParserError.invalidXML
        }

        // Use XPath to find the Entry with Name="DeviceIO.Config.Controller"
        let xpath = "//Entry[@Name='DeviceIO.Config.Controller']/@Value"
        let nodes: [XMLNode]
        do {
            nodes = try document.nodes(forXPath: xpath)
        } catch {
            throw TSIParserError.invalidXML
        }

        // Extract the Value attribute
        guard let valueNode = nodes.first,
              let value = valueNode.stringValue,
              !value.isEmpty else {
            throw TSIParserError.missingControllerEntry
        }

        return value
    }

    // MARK: - Base64 Decoding

    /// Decodes a Base64-encoded string to raw binary data.
    ///
    /// - Parameter string: The Base64-encoded string
    /// - Returns: The decoded binary data
    /// - Throws: `TSIParserError.invalidBase64` if the string is not valid Base64
    public func decodeBase64(_ string: String) throws -> Data {
        guard let data = Data(base64Encoded: string, options: .ignoreUnknownCharacters) else {
            throw TSIParserError.invalidBase64
        }
        return data
    }

    // MARK: - Frame Parsing

    /// Parses all frames from binary TSI data.
    ///
    /// The binary data consists of consecutive frames, each with:
    /// - 4 bytes: Frame identifier (ASCII)
    /// - 4 bytes: Frame size (big-endian UInt32)
    /// - N bytes: Frame data
    ///
    /// - Parameter binaryData: The raw binary data to parse
    /// - Returns: An array of parsed frames
    /// - Throws: `TSIParserError.unexpectedEndOfData` if the data is malformed
    public func parseFrames(from binaryData: Data) throws -> [TSIFrame] {
        var frames: [TSIFrame] = []
        var offset = 0

        while offset < binaryData.count {
            // Check if we have at least a header's worth of data remaining
            guard binaryData.count - offset >= TSIFrame.headerSize else {
                // Not enough data for another frame - this is an error
                throw TSIParserError.unexpectedEndOfData
            }

            // Extract the subdata starting at current offset
            let remainingData = binaryData.subdata(in: offset..<binaryData.count)

            // Parse the frame
            let frame = try TSIFrame.parse(from: remainingData)
            frames.append(frame)

            // Move offset past this frame
            offset += frame.totalSize
        }

        return frames
    }
}
