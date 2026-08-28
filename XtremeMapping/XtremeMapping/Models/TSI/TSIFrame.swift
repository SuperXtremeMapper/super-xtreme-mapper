//
//  TSIFrame.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a single frame in TSI binary data.
///
/// TSI files use an ID3v2-like frame format:
/// - 4 bytes: Frame identifier (ASCII string, e.g., "DEVI", "CMAS", "CMAI")
/// - 4 bytes: Frame size (big-endian UInt32)
/// - N bytes: Frame data (where N = size)
public struct TSIFrame: Equatable, Sendable {
    /// The 4-character ASCII identifier for this frame (e.g., "DEVI", "CMAS", "CMAI")
    public let identifier: String

    /// The size of the frame's data payload in bytes
    public let size: UInt32

    /// The raw binary data payload of the frame
    public let data: Data

    /// The minimum size of a frame header (4 bytes identifier + 4 bytes size)
    public static let headerSize = 8

    /// Creates a new TSIFrame with the specified properties.
    /// - Parameters:
    ///   - identifier: The 4-character frame identifier
    ///   - size: The size of the data payload
    ///   - data: The raw binary data payload
    public init(identifier: String, size: UInt32, data: Data) {
        self.identifier = identifier
        self.size = size
        self.data = data
    }

    /// Parses a single TSIFrame from the beginning of the provided data.
    /// - Parameter data: The binary data to parse from
    /// - Returns: The parsed TSIFrame
    /// - Throws: `TSIParserError.unexpectedEndOfData` if the data is too short
    public static func parse(from data: Data) throws -> TSIFrame {
        try parse(from: data, at: 0, limits: .default).frame
    }

    /// Parses one frame from a shared byte buffer without copying the unparsed tail.
    public static func parse(
        from data: Data,
        at offset: Int,
        limits: TSIParseLimits
    ) throws -> (frame: TSIFrame, nextOffset: Int) {
        guard offset >= 0 else { throw TSIParserError.integerOverflow }
        let (headerEnd, headerOverflow) = offset.addingReportingOverflow(headerSize)
        guard !headerOverflow else { throw TSIParserError.integerOverflow }
        guard headerEnd <= data.count else { throw TSIParserError.unexpectedEndOfData }

        guard let identifier = String(
            bytes: data[offset..<(offset + 4)],
            encoding: .ascii
        ) else {
            throw TSIParserError.unexpectedEndOfData
        }

        let size = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset + 4, as: UInt32.self).bigEndian
        }
        let payloadSize = Int(size)
        guard payloadSize <= limits.maximumIndividualFramePayload else {
            throw TSIParserError.framePayloadLimitExceeded
        }

        let (nextOffset, payloadOverflow) = headerEnd.addingReportingOverflow(payloadSize)
        guard !payloadOverflow else { throw TSIParserError.integerOverflow }
        guard nextOffset <= data.count else { throw TSIParserError.unexpectedEndOfData }

        let payload = payloadSize == 0
            ? Data()
            : data.subdata(in: headerEnd..<nextOffset)
        return (TSIFrame(identifier: identifier, size: size, data: payload), nextOffset)
    }

    /// The total size of this frame in bytes (header + data)
    public var totalSize: Int {
        return TSIFrame.headerSize + Int(size)
    }
}
