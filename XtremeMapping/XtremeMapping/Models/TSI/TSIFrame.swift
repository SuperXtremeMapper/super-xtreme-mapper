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
    /// - Throws: `TSIParserError.unexpectedEndOfData` for a truncated or
    ///   malformed frame, `framePayloadLimitExceeded` when the declared
    ///   payload exceeds the default resource limit, or `integerOverflow`
    ///   when frame bounds cannot be represented safely.
    public static func parse(from data: Data) throws -> TSIFrame {
        try parse(from: data, at: 0, limits: .default).frame
    }

    /// Parses one frame from a shared byte buffer without copying the unparsed tail.
    ///
    /// `offset` and the returned `nextOffset` are relative to the supplied
    /// `Data`, including when it is a slice whose `startIndex` is nonzero.
    ///
    /// - Parameters:
    ///   - data: The complete frame container or a legitimate `Data` slice.
    ///   - offset: A relative byte offset into `data`.
    ///   - limits: Resource limits applied to the declared payload.
    /// - Returns: The retained frame and the next relative byte offset.
    /// - Throws: `TSIParserError.unexpectedEndOfData` for malformed or
    ///   truncated bytes, `framePayloadLimitExceeded` for an oversized
    ///   declared payload, or `integerOverflow` for an invalid or
    ///   unrepresentable offset calculation.
    public static func parse(
        from data: Data,
        at offset: Int,
        limits: TSIParseLimits
    ) throws -> (frame: TSIFrame, nextOffset: Int) {
        try TSIFrameCursor(data: data, limits: limits).parse(at: offset)
    }

    /// The total size of this frame in bytes (header + data)
    public var totalSize: Int {
        return TSIFrame.headerSize + Int(size)
    }
}

/// A shared, relative-offset data source for linear frame parsing.
///
/// Every retained payload copy passes through this type so optional
/// instrumentation observes the bytes actually copied rather than inferring
/// them from a parsed frame's declaration.
struct TSIFrameCursor {
    private let data: Data
    private let limits: TSIParseLimits
    private let instrumentation: TSIParseInstrumentation?

    init(
        data: Data,
        limits: TSIParseLimits,
        instrumentation: TSIParseInstrumentation? = nil
    ) {
        self.data = data
        self.limits = limits
        self.instrumentation = instrumentation
    }

    func parse(at offset: Int) throws -> (frame: TSIFrame, nextOffset: Int) {
        guard offset >= 0 else { throw TSIParserError.integerOverflow }
        let (headerEnd, headerOverflow) = offset.addingReportingOverflow(TSIFrame.headerSize)
        guard !headerOverflow else { throw TSIParserError.integerOverflow }
        guard headerEnd <= data.count else { throw TSIParserError.unexpectedEndOfData }

        let identifierStart = try absoluteIndex(relativeOffset: offset)
        let identifierEnd = try absoluteIndex(relativeOffset: offset + 4)
        guard let identifier = String(
            bytes: data[identifierStart..<identifierEnd],
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

        let payload = try copyRetainedPayload(
            from: headerEnd,
            to: nextOffset
        )
        instrumentation?.recordFrameAdvance(byteCount: nextOffset - offset)
        return (
            TSIFrame(identifier: identifier, size: size, data: payload),
            nextOffset
        )
    }

    private func absoluteIndex(
        relativeOffset: Int
    ) throws -> Data.Index {
        guard relativeOffset >= 0 else { throw TSIParserError.integerOverflow }
        let (index, overflow) = data.startIndex.addingReportingOverflow(relativeOffset)
        guard !overflow else { throw TSIParserError.integerOverflow }
        guard index <= data.endIndex else { throw TSIParserError.unexpectedEndOfData }
        return index
    }

    private func copyRetainedPayload(
        from startOffset: Int,
        to endOffset: Int
    ) throws -> Data {
        guard endOffset >= startOffset else { throw TSIParserError.integerOverflow }
        guard endOffset > startOffset else { return Data() }

        let start = try absoluteIndex(relativeOffset: startOffset)
        let end = try absoluteIndex(relativeOffset: endOffset)
        let payload = data.subdata(in: start..<end)
        instrumentation?.recordRetainedPayloadCopy(byteCount: payload.count)
        return payload
    }
}
