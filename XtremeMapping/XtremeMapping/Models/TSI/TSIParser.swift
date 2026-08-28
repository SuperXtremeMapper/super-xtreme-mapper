//
//  TSIParser.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Errors that can occur during TSI file parsing
public enum TSIParserError: Error, Equatable, Sendable, LocalizedError {
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

    /// The XML bytes or declaration specify an encoding other than UTF-8.
    case unsupportedXMLEncoding

    /// The XML contains a prohibited DTD or entity declaration.
    case prohibitedXMLDeclaration

    /// The XML document exceeds `maximumXMLBytes`.
    case xmlByteLimitExceeded

    /// A controller attribute exceeds `maximumBase64AttributeCharacters`.
    case base64CharacterLimitExceeded

    /// A controller payload exceeds `maximumDecodedControllerBytes`.
    case decodedControllerByteLimitExceeded

    /// A frame declaration exceeds `maximumIndividualFramePayload`.
    case framePayloadLimitExceeded

    /// A frame container exceeds `maximumFramesPerContainer`.
    case frameCountLimitExceeded

    /// A length-prefixed string exceeds `maximumUTF16StringBytes`.
    case utf16StringByteLimitExceeded

    /// The XML exceeds `maximumXMLElements`.
    case xmlElementLimitExceeded

    /// The XML exceeds `maximumXMLNestingDepth`.
    case xmlDepthLimitExceeded

    /// The XML exceeds `maximumControllerEntries`.
    case controllerEntryLimitExceeded

    /// The binary frame tree exceeds `maximumBinaryContainerDepth`.
    case binaryDepthLimitExceeded

    /// The controller payload exceeds `maximumCumulativeFrames`.
    case cumulativeFrameLimitExceeded

    /// Length, index, or decoded-size arithmetic cannot be represented safely.
    case integerOverflow

    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfData: "The TSI binary data ended unexpectedly."
        case .invalidXML: "The TSI XML is malformed."
        case .missingControllerEntry: "The TSI XML has no controller entry."
        case .invalidBase64: "The TSI controller value is not strict RFC 4648 Base64."
        case .decompressionFailed: "The TSI controller data could not be decompressed."
        case .unsupportedXMLEncoding: "TSI XML must be encoded as UTF-8."
        case .prohibitedXMLDeclaration: "TSI XML may not contain DTD or entity declarations."
        case .xmlByteLimitExceeded: "The TSI XML exceeds the configured byte limit."
        case .base64CharacterLimitExceeded: "A TSI controller value exceeds the configured Base64 character limit."
        case .decodedControllerByteLimitExceeded: "Decoded TSI controller data exceeds the configured byte limit."
        case .framePayloadLimitExceeded: "A TSI frame payload exceeds the configured byte limit."
        case .frameCountLimitExceeded: "A TSI container exceeds the configured frame limit."
        case .utf16StringByteLimitExceeded: "A TSI string exceeds the configured UTF-16 byte limit."
        case .xmlElementLimitExceeded: "The TSI XML exceeds the configured element limit."
        case .xmlDepthLimitExceeded: "The TSI XML exceeds the configured nesting-depth limit."
        case .controllerEntryLimitExceeded: "The TSI XML exceeds the configured controller-entry limit."
        case .binaryDepthLimitExceeded: "The TSI binary data exceeds the configured container-depth limit."
        case .cumulativeFrameLimitExceeded: "The TSI document exceeds the configured cumulative frame limit."
        case .integerOverflow: "A TSI length or offset cannot be represented safely."
        }
    }

    var isResourceLimitFailure: Bool {
        switch self {
        case .xmlByteLimitExceeded, .base64CharacterLimitExceeded,
             .decodedControllerByteLimitExceeded, .framePayloadLimitExceeded,
             .frameCountLimitExceeded, .utf16StringByteLimitExceeded,
             .xmlElementLimitExceeded, .xmlDepthLimitExceeded,
             .controllerEntryLimitExceeded, .binaryDepthLimitExceeded,
             .cumulativeFrameLimitExceeded, .integerOverflow:
            true
        default:
            false
        }
    }
}

/// Parser for TSI (Traktor Settings Interface) files.
///
/// TSI files are XML documents containing Base64-encoded binary data.
/// The binary data uses an ID3v2-like frame format for storing controller mappings.
public struct TSIParser: Sendable {
    public let limits: TSIParseLimits
    public let instrumentation: TSIParseInstrumentation?

    public init(
        limits: TSIParseLimits = .default,
        instrumentation: TSIParseInstrumentation? = nil
    ) {
        self.limits = limits
        self.instrumentation = instrumentation
    }

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
    /// - Throws: `TSIParserError.invalidXML` for malformed XML,
    ///   `unsupportedXMLEncoding` for non-UTF-8 input or declarations,
    ///   `prohibitedXMLDeclaration` for DTD/entity declarations, a distinct
    ///   XML resource-limit error when a configured bound is exceeded, or
    ///   `missingControllerEntry` if no nonempty controller value is found.
    public static func extractControllerData(
        from xmlData: Data,
        limits: TSIParseLimits = .default
    ) throws -> String {
        let result = try scanXML(xmlData, limits: limits)
        guard let value = result.controllerValues.first, !value.isEmpty else {
            throw TSIParserError.missingControllerEntry
        }
        return value
    }

    /// Validates and inventories the bounded TSI XML wrapper in one streaming pass.
    ///
    /// - Parameters:
    ///   - xmlData: UTF-8 XML, optionally prefixed by a UTF-8 BOM.
    ///   - limits: XML byte, element, depth, controller-entry, and Base64
    ///     attribute limits.
    /// - Returns: Controller values plus XML inventory information.
    /// - Throws: `TSIParserError.invalidXML` for malformed XML,
    ///   `unsupportedXMLEncoding` for non-UTF-8 input or declarations,
    ///   `prohibitedXMLDeclaration` for DTD/entity declarations, or the
    ///   corresponding distinct resource-limit error.
    public static func scanXML(
        _ xmlData: Data,
        limits: TSIParseLimits = .default
    ) throws -> TSIXMLScanResult {
        try TSIXMLScanner.scan(xmlData, limits: limits)
    }

    /// Scans XML using the resource limits configured on this parser.
    public func scanXML(_ xmlData: Data) throws -> TSIXMLScanResult {
        try Self.scanXML(xmlData, limits: limits)
    }

    /// Extracts the first nonempty controller value using this parser's limits.
    public func extractControllerData(from xmlData: Data) throws -> String {
        let result = try scanXML(xmlData)
        guard let value = result.controllerValues.first, !value.isEmpty else {
            throw TSIParserError.missingControllerEntry
        }
        return value
    }

    // MARK: - Base64 Decoding

    /// Decodes a Base64-encoded string to raw binary data.
    ///
    /// - Parameter string: The Base64-encoded string
    /// - Returns: The decoded binary data
    /// - Throws: `TSIParserError.invalidBase64` for noncanonical RFC 4648
    ///   input, `base64CharacterLimitExceeded` or
    ///   `decodedControllerByteLimitExceeded` for configured resource-limit
    ///   failures, or `integerOverflow` if decoded-size arithmetic cannot be
    ///   represented safely.
    public func decodeBase64(_ string: String) throws -> Data {
        let bytes = Array(string.utf8)
        guard bytes.count <= limits.maximumBase64AttributeCharacters else {
            throw TSIParserError.base64CharacterLimitExceeded
        }
        guard bytes.count.isMultiple(of: 4) else {
            throw TSIParserError.invalidBase64
        }

        var paddingCount = 0
        if bytes.last == 0x3D {
            paddingCount = 1
            if bytes.count >= 2, bytes[bytes.count - 2] == 0x3D { paddingCount = 2 }
        }
        let alphabetEnd = bytes.count - paddingCount
        for (index, byte) in bytes.enumerated() {
            let isAlphabet = (0x41...0x5A).contains(byte)
                || (0x61...0x7A).contains(byte)
                || (0x30...0x39).contains(byte)
                || byte == 0x2B || byte == 0x2F
            if index < alphabetEnd {
                guard isAlphabet else { throw TSIParserError.invalidBase64 }
            } else {
                guard byte == 0x3D else { throw TSIParserError.invalidBase64 }
            }
        }

        let (triples, multiplyOverflow) = (bytes.count / 4).multipliedReportingOverflow(by: 3)
        guard !multiplyOverflow else { throw TSIParserError.integerOverflow }
        let (decodedByteCount, subtractOverflow) = triples.subtractingReportingOverflow(paddingCount)
        guard !subtractOverflow else { throw TSIParserError.invalidBase64 }
        guard decodedByteCount <= limits.maximumDecodedControllerBytes else {
            throw TSIParserError.decodedControllerByteLimitExceeded
        }

        guard let data = Data(base64Encoded: string),
              data.count == decodedByteCount,
              data.base64EncodedString() == string else {
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
    /// - Throws: `TSIParserError.unexpectedEndOfData` for malformed or
    ///   truncated frame bytes, a distinct frame payload/count/cumulative
    ///   resource-limit error when configured bounds are exceeded, or
    ///   `integerOverflow` when frame bounds cannot be represented safely.
    public func parseFrames(from binaryData: Data) throws -> [TSIFrame] {
        let budget = try TSIParseBudget(limits: limits, instrumentation: instrumentation)
        try budget.enterContainer(atDepth: 0)
        var frames: [TSIFrame] = []
        frames.reserveCapacity(min(binaryData.count / TSIFrame.headerSize, max(limits.maximumFramesPerContainer, 0)))
        let frameCursor = TSIFrameCursor(
            data: binaryData,
            limits: limits,
            instrumentation: instrumentation
        )
        var offset = 0
        var containerFrameCount = 0

        while offset < binaryData.count {
            // Check if we have at least a header's worth of data remaining
            guard binaryData.count - offset >= TSIFrame.headerSize else {
                // Not enough data for another frame - this is an error
                throw TSIParserError.unexpectedEndOfData
            }

            try budget.consumeFrame(containerCount: &containerFrameCount)
            let parsed = try frameCursor.parse(at: offset)
            frames.append(parsed.frame)
            offset = parsed.nextOffset
        }

        return frames
    }
}
