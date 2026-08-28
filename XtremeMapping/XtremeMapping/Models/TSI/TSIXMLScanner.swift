//
//  TSIXMLScanner.swift
//  SuperXtremeMapping
//

import Foundation

/// Bounded information retained from the TSI XML wrapper.
public struct TSIXMLScanResult: Equatable, Sendable {
    public let controllerValues: [String]
    public let hasNonControllerEntries: Bool
    public let elementCount: Int
}

enum TSIXMLScanner {
    private static let controllerEntryName = "DeviceIO.Config.Controller"

    static func scan(_ data: Data, limits: TSIParseLimits) throws -> TSIXMLScanResult {
        guard data.count <= limits.maximumXMLBytes else {
            throw TSIParserError.xmlByteLimitExceeded
        }
        try validateUTF8Encoding(data)

        guard let text = String(data: data, encoding: .utf8) else {
            throw TSIParserError.unsupportedXMLEncoding
        }
        try validateEncodingDeclaration(in: text)
        if text.range(of: "<!DOCTYPE", options: .caseInsensitive) != nil
            || text.range(of: "<!ENTITY", options: .caseInsensitive) != nil {
            throw TSIParserError.prohibitedXMLDeclaration
        }

        let delegate = Delegate(limits: limits)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            if let failure = delegate.failure { throw failure }
            throw TSIParserError.invalidXML
        }
        if let failure = delegate.failure { throw failure }

        return TSIXMLScanResult(
            controllerValues: delegate.controllerValues,
            hasNonControllerEntries: delegate.hasNonControllerEntries,
            elementCount: delegate.elementCount
        )
    }

    private static func validateUTF8Encoding(_ data: Data) throws {
        let bytes = Array(data.prefix(4))
        let isUTF16Or32BOM = bytes.starts(with: [0xFF, 0xFE])
            || bytes.starts(with: [0xFE, 0xFF])
            || bytes.starts(with: [0x00, 0x00, 0xFE, 0xFF])
        let isUTF16BESignature = bytes.count == 4
            && bytes[0] == 0x00 && bytes[1] == 0x3C && bytes[2] == 0x00
        let isUTF16LESignature = bytes.count == 4
            && bytes[0] == 0x3C && bytes[1] == 0x00 && bytes[3] == 0x00
        let isUTF32Signature = bytes.starts(with: [0x00, 0x00, 0x00, 0x3C])
            || bytes.starts(with: [0x3C, 0x00, 0x00, 0x00])

        guard !isUTF16Or32BOM, !isUTF16BESignature, !isUTF16LESignature,
              !isUTF32Signature,
              String(data: data, encoding: .utf8) != nil else {
            throw TSIParserError.unsupportedXMLEncoding
        }
    }

    private static func validateEncodingDeclaration(in text: String) throws {
        let withoutBOM = text.first == "\u{FEFF}" ? String(text.dropFirst()) : text
        guard withoutBOM.hasPrefix("<?xml") || withoutBOM.hasPrefix("<?XML") else { return }
        guard let declarationEnd = withoutBOM.range(of: "?>") else { return }
        let declaration = String(withoutBOM[..<declarationEnd.upperBound])
        let pattern = #"encoding\s*=\s*['\"]([^'\"]+)['\"]"#
        let expression = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        let range = NSRange(declaration.startIndex..<declaration.endIndex, in: declaration)
        guard let match = expression.firstMatch(in: declaration, range: range),
              let valueRange = Range(match.range(at: 1), in: declaration) else { return }
        guard declaration[valueRange].caseInsensitiveCompare("UTF-8") == .orderedSame else {
            throw TSIParserError.unsupportedXMLEncoding
        }
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        let limits: TSIParseLimits
        var controllerValues: [String] = []
        var hasNonControllerEntries = false
        var elementCount = 0
        var depth = 0
        var controllerEntryCount = 0
        var failure: TSIParserError?

        init(limits: TSIParseLimits) {
            self.limits = limits
            controllerValues.reserveCapacity(min(max(limits.maximumControllerEntries, 0), 64))
        }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            guard failure == nil else { return }

            let (nextElementCount, elementOverflow) = elementCount.addingReportingOverflow(1)
            guard !elementOverflow, nextElementCount <= limits.maximumXMLElements else {
                return fail(.xmlElementLimitExceeded, parser: parser)
            }
            elementCount = nextElementCount

            let (nextDepth, depthOverflow) = depth.addingReportingOverflow(1)
            guard !depthOverflow, nextDepth <= limits.maximumXMLNestingDepth else {
                return fail(.xmlDepthLimitExceeded, parser: parser)
            }
            depth = nextDepth

            guard elementName == "Entry" else { return }
            guard attributeDict["Name"] == controllerEntryName else {
                hasNonControllerEntries = true
                return
            }

            let (nextControllerCount, controllerOverflow) = controllerEntryCount.addingReportingOverflow(1)
            guard !controllerOverflow, nextControllerCount <= limits.maximumControllerEntries else {
                return fail(.controllerEntryLimitExceeded, parser: parser)
            }
            controllerEntryCount = nextControllerCount

            guard let value = attributeDict["Value"] else { return }
            guard value.utf8.count <= limits.maximumBase64AttributeCharacters else {
                return fail(.base64CharacterLimitExceeded, parser: parser)
            }
            controllerValues.append(value)
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            if depth > 0 { depth -= 1 }
        }

        func parser(
            _ parser: XMLParser,
            foundNotationDeclarationWithName name: String,
            publicID: String?,
            systemID: String?
        ) {
            fail(.prohibitedXMLDeclaration, parser: parser)
        }

        func parser(
            _ parser: XMLParser,
            foundUnparsedEntityDeclarationWithName name: String,
            publicID: String?,
            systemID: String?,
            notationName: String?
        ) {
            fail(.prohibitedXMLDeclaration, parser: parser)
        }

        func parser(
            _ parser: XMLParser,
            foundAttributeDeclarationWithName attributeName: String,
            forElement elementName: String,
            type: String?,
            defaultValue: String?
        ) {
            fail(.prohibitedXMLDeclaration, parser: parser)
        }

        func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
            fail(.prohibitedXMLDeclaration, parser: parser)
        }

        func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
            fail(.prohibitedXMLDeclaration, parser: parser)
        }

        func parser(
            _ parser: XMLParser,
            foundExternalEntityDeclarationWithName name: String,
            publicID: String?,
            systemID: String?
        ) {
            fail(.prohibitedXMLDeclaration, parser: parser)
        }

        func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? {
            fail(.prohibitedXMLDeclaration, parser: parser)
            return nil
        }

        private func fail(_ error: TSIParserError, parser: XMLParser) {
            guard failure == nil else { return }
            failure = error
            parser.abortParsing()
        }
    }
}
