//
//  ImportedCMAD.swift
//  SuperXtremeMapping
//

import Foundation

/// Exact mapping-data wire state retained by an imported row.
///
/// The payload is authoritative. Decoded scalars make ownership decisions
/// explicit, while `semanticAtImport` records the model projection that was
/// produced from those bytes. Float-like values are stored as bit patterns so
/// negative zero and NaN payloads never collapse during change detection.
/// Modifier fingerprints include their modeled native targets, including
/// opaque raw values, so target-only edits are detected without inference.
struct ImportedCMAD: Codable, Hashable, Sendable {
    struct SemanticFingerprint: Codable, Hashable, Sendable {
        let commandID: Int
        let ioType: IODirection
        let assignment: TargetAssignment
        let interactionMode: InteractionMode
        let midiAssignment: MIDIAssignment
        let rawMidiControlName: String?
        let rawMidiBindingID: UInt32?
        var modifier1Condition: ModifierCondition?
        var modifier2Condition: ModifierCondition?
        let comment: String
        let controllerType: ControllerType
        let invert: Bool
        let softTakeover: Bool
        let setToValueBits: UInt32
        let rotarySensitivityBits: UInt32
        let rotaryAccelerationBits: UInt32
        let encoderMode: EncoderMode
        let rawDCDTEncoderMode: UInt32?
        let rawDCDTControlType: UInt32?
        let rawDCDTMinValueBits: UInt32?
        let rawDCDTMaxValueBits: UInt32?
        let rawDCDTControlID: UInt32?
        let autoRepeat: Bool
        let ledMinRangeType: Int
        let ledMinRangeData: Int
        let ledMaxRangeType: Int
        let ledMaxRangeData: Int
        let ledMinMidi: Int
        let ledMaxMidi: Int
        let ledInvert: Bool
        let ledBlend: Bool
        let resolution: Int

        init(_ mapping: MappingEntry) {
            commandID = mapping.commandID
            ioType = mapping.ioType
            assignment = mapping.assignment
            interactionMode = mapping.interactionMode
            midiAssignment = mapping.midiAssignment
            rawMidiControlName = mapping.rawMidiControlName
            rawMidiBindingID = mapping.rawMidiBindingID
            modifier1Condition = mapping.modifier1Condition
            modifier2Condition = mapping.modifier2Condition
            comment = mapping.comment
            controllerType = mapping.controllerType
            invert = mapping.invert
            softTakeover = mapping.softTakeover
            setToValueBits = mapping.setToValue.bitPattern
            rotarySensitivityBits = mapping.rotarySensitivity.bitPattern
            rotaryAccelerationBits = mapping.rotaryAcceleration.bitPattern
            encoderMode = mapping.encoderMode
            rawDCDTEncoderMode = mapping.rawDCDTEncoderMode
            rawDCDTControlType = mapping.rawDCDTControlType
            rawDCDTMinValueBits = mapping.rawDCDTMinValueBits
            rawDCDTMaxValueBits = mapping.rawDCDTMaxValueBits
            rawDCDTControlID = mapping.rawDCDTControlID
            autoRepeat = mapping.autoRepeat
            ledMinRangeType = mapping.ledMinRangeType
            ledMinRangeData = mapping.ledMinRangeData
            ledMaxRangeType = mapping.ledMaxRangeType
            ledMaxRangeData = mapping.ledMaxRangeData
            ledMinMidi = mapping.ledMinMidi
            ledMaxMidi = mapping.ledMaxMidi
            ledInvert = mapping.ledInvert
            ledBlend = mapping.ledBlend
            resolution = mapping.resolution
        }
    }

    let payload: Data

    let deviceType: UInt32
    let controllerType: UInt32
    let interactionMode: UInt32
    let assignment: UInt32
    let autoRepeat: UInt32
    let invert: UInt32
    let softTakeover: UInt32
    let rotarySensitivityBits: UInt32
    let rotaryAccelerationBits: UInt32
    let hasValueUI: UInt32
    let valueUIType: UInt32
    let setToValueBits: UInt32
    let commentLength: UInt32
    let commentWasLossy: Bool

    let conditionOneID: UInt32?
    let conditionOneTarget: UInt32?
    let conditionOneValue: UInt32?
    let conditionTwoID: UInt32?
    let conditionTwoTarget: UInt32?
    let conditionTwoValue: UInt32?

    let ledMinRangeType: UInt32?
    let ledMinRangeData: UInt32?
    let ledMaxRangeType: UInt32?
    let ledMaxRangeData: UInt32?
    let ledMinMidi: UInt32?
    let ledMaxMidi: UInt32?
    let ledInvert: UInt32?
    let ledBlend: UInt32?
    let unknownVUI: UInt32?
    let resolutionBits: UInt32?
    let useFactoryMap: UInt32?

    /// Every byte after the required fixed header and comment.
    let optionalBytes: Data

    /// Bytes after the complete 68-byte condition/LED tail, if present.
    let trailingBytes: Data

    var semanticAtImport: SemanticFingerprint

    var expectedCompleteLength: Int {
        120 + Int(commentLength) * 2
    }

    var isCompleteStandardLayout: Bool {
        payload.count == expectedCompleteLength && useFactoryMap != nil
    }

    init?(payload: Data, semanticAtImport mapping: MappingEntry) {
        guard payload.count >= 52 else { return nil }
        let commentLength = Self.readUInt32(payload, at: 48)
        let (commentByteCount, byteOverflow) = Int(commentLength)
            .multipliedReportingOverflow(by: 2)
        let (commentEnd, endOverflow) = 52.addingReportingOverflow(commentByteCount)
        guard !byteOverflow, !endOverflow, commentEnd <= payload.count else { return nil }

        self.payload = payload
        deviceType = Self.readUInt32(payload, at: 0)
        controllerType = Self.readUInt32(payload, at: 4)
        interactionMode = Self.readUInt32(payload, at: 8)
        assignment = Self.readUInt32(payload, at: 12)
        autoRepeat = Self.readUInt32(payload, at: 16)
        invert = Self.readUInt32(payload, at: 20)
        softTakeover = Self.readUInt32(payload, at: 24)
        rotarySensitivityBits = Self.readUInt32(payload, at: 28)
        rotaryAccelerationBits = Self.readUInt32(payload, at: 32)
        hasValueUI = Self.readUInt32(payload, at: 36)
        valueUIType = Self.readUInt32(payload, at: 40)
        setToValueBits = Self.readUInt32(payload, at: 44)
        self.commentLength = commentLength

        let rawComment = payload.subdata(in: 52..<commentEnd)
        var units: [UInt16] = []
        units.reserveCapacity(Int(commentLength))
        for offset in stride(from: 0, to: rawComment.count, by: 2) {
            units.append(UInt16(rawComment[offset]) << 8 | UInt16(rawComment[offset + 1]))
        }
        let decodedComment = String(decoding: units, as: UTF16.self)
        commentWasLossy = Array(decodedComment.utf16) != units

        optionalBytes = payload.subdata(in: commentEnd..<payload.count)
        let conditionEnd = commentEnd + 24
        if conditionEnd <= payload.count {
            conditionOneID = Self.readUInt32(payload, at: commentEnd)
            conditionOneTarget = Self.readUInt32(payload, at: commentEnd + 4)
            conditionOneValue = Self.readUInt32(payload, at: commentEnd + 8)
            conditionTwoID = Self.readUInt32(payload, at: commentEnd + 12)
            conditionTwoTarget = Self.readUInt32(payload, at: commentEnd + 16)
            conditionTwoValue = Self.readUInt32(payload, at: commentEnd + 20)
        } else {
            conditionOneID = nil
            conditionOneTarget = nil
            conditionOneValue = nil
            conditionTwoID = nil
            conditionTwoTarget = nil
            conditionTwoValue = nil
        }

        let ledOffset = conditionEnd
        if ledOffset + 32 <= payload.count {
            ledMinRangeType = Self.readUInt32(payload, at: ledOffset)
            ledMinRangeData = Self.readUInt32(payload, at: ledOffset + 4)
            ledMaxRangeType = Self.readUInt32(payload, at: ledOffset + 8)
            ledMaxRangeData = Self.readUInt32(payload, at: ledOffset + 12)
            ledMinMidi = Self.readUInt32(payload, at: ledOffset + 16)
            ledMaxMidi = Self.readUInt32(payload, at: ledOffset + 20)
            ledInvert = Self.readUInt32(payload, at: ledOffset + 24)
            ledBlend = Self.readUInt32(payload, at: ledOffset + 28)
        } else {
            ledMinRangeType = nil
            ledMinRangeData = nil
            ledMaxRangeType = nil
            ledMaxRangeData = nil
            ledMinMidi = nil
            ledMaxMidi = nil
            ledInvert = nil
            ledBlend = nil
        }
        if ledOffset + 40 <= payload.count {
            unknownVUI = Self.readUInt32(payload, at: ledOffset + 32)
            resolutionBits = Self.readUInt32(payload, at: ledOffset + 36)
        } else {
            unknownVUI = nil
            resolutionBits = nil
        }
        useFactoryMap = ledOffset + 44 <= payload.count
            ? Self.readUInt32(payload, at: ledOffset + 40)
            : nil

        let completeEnd = ledOffset + 44
        trailingBytes = completeEnd < payload.count
            ? payload.subdata(in: completeEnd..<payload.count)
            : Data()
        semanticAtImport = SemanticFingerprint(mapping)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }
}
