//
//  TSIPreservation.swift
//  SuperXtremeMapping
//

import Foundation

/// A semantic import snapshot that cannot recursively retain another source envelope.
struct TSISemanticBaseline: Equatable, Sendable {
    let devices: [Device]
    let version: Int

    init(devices: [Device], version: Int) {
        self.devices = devices
        self.version = version
    }

    func matches(_ mappingFile: MappingFile) -> Bool {
        devices == mappingFile.devices && version == mappingFile.version
    }
}

/// Exact document-boundary source state retained for loss-aware writes.
struct TSIRawEnvelope: Equatable, Sendable {
    let originalXML: Data
    let controllerValues: [String]
    let primaryFrames: [TSIFrame]
    let baseline: TSISemanticBaseline
    let risks: [TSIPreservationRisk]

    init(
        originalXML: Data,
        controllerValues: [String],
        primaryFrames: [TSIFrame],
        baseline: TSISemanticBaseline,
        risks: [TSIPreservationRisk]
    ) {
        self.originalXML = originalXML
        self.controllerValues = controllerValues
        self.primaryFrames = primaryFrames
        self.baseline = baseline
        self.risks = risks.sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.code.rawValue != $1.code.rawValue {
                return $0.code.rawValue < $1.code.rawValue
            }
            return $0.detail < $1.detail
        }
    }
}

/// One stable, actionable reason why canonical regeneration would omit or normalize source data.
nonisolated struct TSIPreservationRisk: Codable, Equatable, Hashable, Sendable {
    nonisolated enum Code: String, Codable, CaseIterable, Sendable {
        case extraControllerEntry
        case extraXMLEntry
        case nonstandardXMLStructure
        case unknownFrame
        case duplicateSingletonFrame
        case missingSingletonFrame
        case noncanonicalFramePlacement
        case noncanonicalDIOI
        case noncanonicalDDIF
        case unreproducibleDeviceIdentity
        case lossyString
        case duplicateMIDIDefinition
        case unusedMIDIDefinition
        case missingMIDIDefinition
        case duplicateMIDIBinding
        case unusedMIDIBinding
        case danglingMIDIBinding
        case nativeMIDIControl
        case commandZeroMapping
        case proprietaryDeviceType
        case coercedControllerType
        case coercedInteractionMode
        case coercedTargetAssignment
        case partialCMAD
        case extendedCMAD
        case unreproducibleCMAD
        case unclassifiedSourceData
    }

    let code: Code
    let path: String
    let detail: String

    init(code: Code, path: String, detail: String = "") {
        self.code = code
        self.path = path
        self.detail = detail
    }
}

nonisolated enum TSIPreservationDisposition: String, Codable, Equatable, Sendable {
    case ordinarySaveSafe
    case lossyConvertible
    case unwritable
}

/// A Sendable, stable description of the converted writer's validation failure.
nonisolated struct TSIWriterValidationFailure: Codable, Equatable, Sendable {
    let errorType: String
    let message: String

    init(_ error: Error) {
        errorType = String(reflecting: type(of: error))
        message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}

nonisolated struct TSIPreservationReport: Codable, Equatable, Sendable {
    let risks: [TSIPreservationRisk]
    let disposition: TSIPreservationDisposition
    let validationError: TSIWriterValidationFailure?
}

nonisolated enum TSIPreservationError: Error, Equatable, Sendable, LocalizedError {
    case unsafeOverwrite(risks: [TSIPreservationRisk])

    var errorDescription: String? {
        switch self {
        case .unsafeOverwrite(let risks):
            let codes = risks.map(\.code.rawValue).joined(separator: ", ")
            return "This imported TSI contains source data that a normal save cannot preserve (\(codes)). The original was not changed; export a converted copy deliberately instead."
        }
    }
}
