//
//  TSIParseLimits.swift
//  SuperXtremeMapping
//

import Foundation

/// Resource limits applied to untrusted TSI XML and binary controller data.
public struct TSIParseLimits: Equatable, Sendable {
    public var maximumXMLBytes: Int
    public var maximumBase64AttributeCharacters: Int
    public var maximumDecodedControllerBytes: Int
    public var maximumIndividualFramePayload: Int
    public var maximumFramesPerContainer: Int
    public var maximumUTF16StringBytes: Int
    public var maximumXMLElements: Int
    public var maximumXMLNestingDepth: Int
    public var maximumControllerEntries: Int
    public var maximumBinaryContainerDepth: Int
    public var maximumCumulativeFrames: Int

    public init(
        maximumXMLBytes: Int = 96 * 1024 * 1024,
        maximumBase64AttributeCharacters: Int = 64 * 1024 * 1024,
        maximumDecodedControllerBytes: Int = 48 * 1024 * 1024,
        maximumIndividualFramePayload: Int = 32 * 1024 * 1024,
        maximumFramesPerContainer: Int = 250_000,
        maximumUTF16StringBytes: Int = 1024 * 1024,
        maximumXMLElements: Int = 100_000,
        maximumXMLNestingDepth: Int = 128,
        maximumControllerEntries: Int = 64,
        maximumBinaryContainerDepth: Int = 16,
        maximumCumulativeFrames: Int = 500_000
    ) {
        self.maximumXMLBytes = maximumXMLBytes
        self.maximumBase64AttributeCharacters = maximumBase64AttributeCharacters
        self.maximumDecodedControllerBytes = maximumDecodedControllerBytes
        self.maximumIndividualFramePayload = maximumIndividualFramePayload
        self.maximumFramesPerContainer = maximumFramesPerContainer
        self.maximumUTF16StringBytes = maximumUTF16StringBytes
        self.maximumXMLElements = maximumXMLElements
        self.maximumXMLNestingDepth = maximumXMLNestingDepth
        self.maximumControllerEntries = maximumControllerEntries
        self.maximumBinaryContainerDepth = maximumBinaryContainerDepth
        self.maximumCumulativeFrames = maximumCumulativeFrames
    }

    public static let `default` = TSIParseLimits()
}

/// Exact parser work counters used by the scaling regression.
public final class TSIParseInstrumentation: @unchecked Sendable {
    public struct Snapshot: Equatable, Sendable {
        public let parsedFrameCount: Int
        public let frameHeaderBytesRead: Int
        public let retainedPayloadCopyCount: Int
        public let retainedPayloadBytesCopied: Int
        public let maximumRetainedPayloadCopyBytes: Int
        public let cursorBytesAdvanced: Int
    }

    private let lock = NSLock()
    private var parsedFrameCount = 0
    private var frameHeaderBytesRead = 0
    private var retainedPayloadCopyCount = 0
    private var retainedPayloadBytesCopied = 0
    private var maximumRetainedPayloadCopyBytes = 0
    private var cursorBytesAdvanced = 0

    public init() {}

    public var snapshot: Snapshot {
        lock.withLock {
            Snapshot(
                parsedFrameCount: parsedFrameCount,
                frameHeaderBytesRead: frameHeaderBytesRead,
                retainedPayloadCopyCount: retainedPayloadCopyCount,
                retainedPayloadBytesCopied: retainedPayloadBytesCopied,
                maximumRetainedPayloadCopyBytes: maximumRetainedPayloadCopyBytes,
                cursorBytesAdvanced: cursorBytesAdvanced
            )
        }
    }

    func recordFrameAdvance(byteCount: Int) {
        lock.withLock {
            parsedFrameCount += 1
            frameHeaderBytesRead += TSIFrame.headerSize
            cursorBytesAdvanced += byteCount
        }
    }

    func recordRetainedPayloadCopy(byteCount: Int) {
        lock.withLock {
            retainedPayloadCopyCount += 1
            retainedPayloadBytesCopied += byteCount
            maximumRetainedPayloadCopyBytes = max(
                maximumRetainedPayloadCopyBytes,
                byteCount
            )
        }
    }
}

/// Mutable document-wide frame budget shared by every nested container walk.
final class TSIParseBudget {
    let limits: TSIParseLimits
    let instrumentation: TSIParseInstrumentation?
    private(set) var cumulativeFrameCount: Int

    init(
        limits: TSIParseLimits,
        instrumentation: TSIParseInstrumentation? = nil,
        initialFrameCount: Int = 0
    ) throws {
        self.limits = limits
        self.instrumentation = instrumentation
        self.cumulativeFrameCount = 0
        guard initialFrameCount >= 0 else { throw TSIParserError.integerOverflow }
        guard initialFrameCount <= limits.maximumFramesPerContainer else {
            throw TSIParserError.frameCountLimitExceeded
        }
        guard initialFrameCount <= limits.maximumCumulativeFrames else {
            throw TSIParserError.cumulativeFrameLimitExceeded
        }
        cumulativeFrameCount = initialFrameCount
    }

    func enterContainer(atDepth depth: Int) throws {
        guard depth >= 0 else { throw TSIParserError.integerOverflow }
        guard depth <= limits.maximumBinaryContainerDepth else {
            throw TSIParserError.binaryDepthLimitExceeded
        }
    }

    func validateDeclaredFrameCount(_ count: Int) throws {
        guard count >= 0 else { throw TSIParserError.integerOverflow }
        guard count <= limits.maximumFramesPerContainer else {
            throw TSIParserError.frameCountLimitExceeded
        }
    }

    func consumeFrame(containerCount: inout Int) throws {
        let (nextContainerCount, containerOverflow) = containerCount.addingReportingOverflow(1)
        guard !containerOverflow else { throw TSIParserError.integerOverflow }
        guard nextContainerCount <= limits.maximumFramesPerContainer else {
            throw TSIParserError.frameCountLimitExceeded
        }

        let (nextCumulativeCount, cumulativeOverflow) = cumulativeFrameCount.addingReportingOverflow(1)
        guard !cumulativeOverflow else { throw TSIParserError.integerOverflow }
        guard nextCumulativeCount <= limits.maximumCumulativeFrames else {
            throw TSIParserError.cumulativeFrameLimitExceeded
        }

        containerCount = nextContainerCount
        cumulativeFrameCount = nextCumulativeCount
    }
}
