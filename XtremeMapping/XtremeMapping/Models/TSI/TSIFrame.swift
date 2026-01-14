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
        // Check minimum header size
        guard data.count >= headerSize else {
            throw TSIParserError.unexpectedEndOfData
        }

        // Parse identifier (first 4 bytes as ASCII)
        let identifierData = data.prefix(4)
        guard let identifier = String(data: identifierData, encoding: .ascii) else {
            throw TSIParserError.unexpectedEndOfData
        }

        // Parse size (next 4 bytes as big-endian UInt32)
        let sizeBytes = data.subdata(in: 4..<8)
        let size = sizeBytes.withUnsafeBytes { bytes in
            bytes.load(as: UInt32.self).bigEndian
        }

        // Check if we have enough data for the payload
        let totalNeeded = headerSize + Int(size)
        guard data.count >= totalNeeded else {
            throw TSIParserError.unexpectedEndOfData
        }

        // Extract payload data
        let payloadData: Data
        if size > 0 {
            payloadData = data.subdata(in: headerSize..<totalNeeded)
        } else {
            payloadData = Data()
        }

        return TSIFrame(identifier: identifier, size: size, data: payloadData)
    }

    /// The total size of this frame in bytes (header + data)
    public var totalSize: Int {
        return TSIFrame.headerSize + Int(size)
    }
}
