import Foundation

/// Public v1 DTOs. Deliberately independent of clipboard/runtime Codable.
nonisolated struct SXMJSONDocument: Codable, Sendable {
    var format: String
    var schemaVersion: Int
    var tsiVersion: Int
    var devices: [SXMJSONDevice]
    var preservation: SXMJSONPreservation?
    var metadata: SXMJSONMetadata?
}

nonisolated struct SXMJSONMetadata: Codable, Equatable, Sendable {
    struct Profile: Codable, Equatable, Sendable {
        var profileID: String
        var version: String?
    }
    struct Control: Codable, Equatable, Sendable {
        var mappingID: UUID
        var profileID: String
        var controlID: String
    }
    struct Override: Codable, Equatable, Sendable {
        var mappingID: UUID
        var midi: SXMJSONMIDI
    }
    var profileReferences: [Profile]
    var physicalControls: [Control]
    var localOverrides: [Override]
}

nonisolated struct SXMJSONDevice: Codable, Sendable {
    var id: UUID
    var name: String
    var comment: String
    var inPort: String
    var outPort: String
    var tsiVersion: String
    var mappingFileRevision: Int
    var mappings: [SXMJSONMapping]
}

nonisolated struct SXMJSONMIDI: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable { case unassigned, note, controlChange }
    var kind: Kind
    var channel: Int
    var number: Int?

    init(_ midi: MIDIAssignment) {
        kind = midi.note != nil ? .note : midi.cc != nil ? .controlChange : .unassigned
        channel = midi.channel
        number = midi.note ?? midi.cc
    }

    func model() throws -> MIDIAssignment {
        switch kind {
        case .unassigned:
            guard number == nil else { throw SXMJSONIssue(code: "schema.midi", path: "$", message: "Unassigned MIDI must omit number.") }
            return try .unassigned(channel: channel)
        case .note: return try .note(channel: channel, number: number ?? -1)
        case .controlChange: return try .controlChange(channel: channel, number: number ?? -1)
        }
    }
}

/// Exceptional IEEE-754 values are explicit raw bits, never NaN/Infinity JSON numbers.
nonisolated struct SXMJSONFloat: Codable, Sendable {
    var value: Float
    init(_ value: Float) { self.value = value }
    enum CodingKeys: String, CodingKey { case sourceBits }
    init(from decoder: Decoder) throws {
        if let scalar = try? decoder.singleValueContainer().decode(Float.self) {
            guard scalar.isFinite else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Float is outside finite range."))
            }
            value = scalar
        } else {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            value = Float(bitPattern: try c.decode(UInt32.self, forKey: .sourceBits))
            guard !value.isFinite || value.bitPattern == 0x80000000 else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "sourceBits is reserved for exceptional floats and negative zero."))
            }
        }
    }
    func encode(to encoder: Encoder) throws {
        if value.isFinite && value.bitPattern != 0x80000000 {
            var c = encoder.singleValueContainer()
            try c.encode(value)
        } else {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(value.bitPattern, forKey: .sourceBits)
        }
    }
}

nonisolated struct SXMJSONCondition: Codable, Sendable {
    var modifier: Int
    var value: Int
    var target: String
    var rawTarget: UInt32?
    init(_ c: ModifierCondition) {
        modifier = c.modifier; value = c.value
        switch c.target {
        case .deckA: target = "deckA"
        case .deckB: target = "deckB"
        case .deckC: target = "deckC"
        case .deckD: target = "deckD"
        case .deviceTarget: target = "deviceTarget"
        case .unknown(let raw): target = "raw"; rawTarget = raw
        }
    }
    func model() throws -> ModifierCondition {
        let t: ModifierConditionTarget
        switch target {
        case "deckA": t = .deckA
        case "deckB": t = .deckB
        case "deckC": t = .deckC
        case "deckD": t = .deckD
        case "deviceTarget": t = .deviceTarget
        case "raw":
            guard let rawTarget else { throw SXMJSONIssue(code: "schema.condition", path: "$", message: "raw target requires rawTarget.") }
            t = .unknown(rawTarget)
        default: throw SXMJSONIssue(code: "schema.condition", path: "$", message: "Unknown condition target.")
        }
        guard target == "raw" || rawTarget == nil else { throw SXMJSONIssue(code: "schema.condition", path: "$", message: "rawTarget is only allowed with target raw.") }
        return ModifierCondition(modifier: modifier, value: value, target: t)
    }
}

nonisolated enum SXMJSONDirection: String, Codable, Sendable {
    case all, input, output
    init(_ model: IODirection) {
        switch model {
        case .all: self = .all
        case .input: self = .input
        case .output: self = .output
        }
    }
    var model: IODirection {
        switch self {
        case .all: return .all
        case .input: return .input
        case .output: return .output
        }
    }
}

nonisolated enum SXMJSONAssignment: String, Codable, Sendable {
    case none, deviceTarget, global, deckA, deckB, deckC, deckD, fxUnit1, fxUnit2, fxUnit3, fxUnit4, remixSlot1, remixSlot2, remixSlot3, remixSlot4, remixSlot5, remixSlot6, remixSlot7, remixSlot8, remixDeckASlot1, remixDeckASlot2, remixDeckASlot3, remixDeckASlot4, remixDeckBSlot1, remixDeckBSlot2, remixDeckBSlot3, remixDeckBSlot4, remixDeckCSlot1, remixDeckCSlot2, remixDeckCSlot3, remixDeckCSlot4, remixDeckDSlot1, remixDeckDSlot2, remixDeckDSlot3, remixDeckDSlot4
    init(_ model: TargetAssignment) {
        switch model {
        case .none: self = .none
        case .deviceTarget: self = .deviceTarget
        case .global: self = .global
        case .deckA: self = .deckA
        case .deckB: self = .deckB
        case .deckC: self = .deckC
        case .deckD: self = .deckD
        case .fxUnit1: self = .fxUnit1
        case .fxUnit2: self = .fxUnit2
        case .fxUnit3: self = .fxUnit3
        case .fxUnit4: self = .fxUnit4
        case .remixSlot1: self = .remixSlot1
        case .remixSlot2: self = .remixSlot2
        case .remixSlot3: self = .remixSlot3
        case .remixSlot4: self = .remixSlot4
        case .remixSlot5: self = .remixSlot5
        case .remixSlot6: self = .remixSlot6
        case .remixSlot7: self = .remixSlot7
        case .remixSlot8: self = .remixSlot8
        case .remixDeckASlot1: self = .remixDeckASlot1
        case .remixDeckASlot2: self = .remixDeckASlot2
        case .remixDeckASlot3: self = .remixDeckASlot3
        case .remixDeckASlot4: self = .remixDeckASlot4
        case .remixDeckBSlot1: self = .remixDeckBSlot1
        case .remixDeckBSlot2: self = .remixDeckBSlot2
        case .remixDeckBSlot3: self = .remixDeckBSlot3
        case .remixDeckBSlot4: self = .remixDeckBSlot4
        case .remixDeckCSlot1: self = .remixDeckCSlot1
        case .remixDeckCSlot2: self = .remixDeckCSlot2
        case .remixDeckCSlot3: self = .remixDeckCSlot3
        case .remixDeckCSlot4: self = .remixDeckCSlot4
        case .remixDeckDSlot1: self = .remixDeckDSlot1
        case .remixDeckDSlot2: self = .remixDeckDSlot2
        case .remixDeckDSlot3: self = .remixDeckDSlot3
        case .remixDeckDSlot4: self = .remixDeckDSlot4
        }
    }
    var model: TargetAssignment {
        switch self {
        case .none: return .none
        case .deviceTarget: return .deviceTarget
        case .global: return .global
        case .deckA: return .deckA
        case .deckB: return .deckB
        case .deckC: return .deckC
        case .deckD: return .deckD
        case .fxUnit1: return .fxUnit1
        case .fxUnit2: return .fxUnit2
        case .fxUnit3: return .fxUnit3
        case .fxUnit4: return .fxUnit4
        case .remixSlot1: return .remixSlot1
        case .remixSlot2: return .remixSlot2
        case .remixSlot3: return .remixSlot3
        case .remixSlot4: return .remixSlot4
        case .remixSlot5: return .remixSlot5
        case .remixSlot6: return .remixSlot6
        case .remixSlot7: return .remixSlot7
        case .remixSlot8: return .remixSlot8
        case .remixDeckASlot1: return .remixDeckASlot1
        case .remixDeckASlot2: return .remixDeckASlot2
        case .remixDeckASlot3: return .remixDeckASlot3
        case .remixDeckASlot4: return .remixDeckASlot4
        case .remixDeckBSlot1: return .remixDeckBSlot1
        case .remixDeckBSlot2: return .remixDeckBSlot2
        case .remixDeckBSlot3: return .remixDeckBSlot3
        case .remixDeckBSlot4: return .remixDeckBSlot4
        case .remixDeckCSlot1: return .remixDeckCSlot1
        case .remixDeckCSlot2: return .remixDeckCSlot2
        case .remixDeckCSlot3: return .remixDeckCSlot3
        case .remixDeckCSlot4: return .remixDeckCSlot4
        case .remixDeckDSlot1: return .remixDeckDSlot1
        case .remixDeckDSlot2: return .remixDeckDSlot2
        case .remixDeckDSlot3: return .remixDeckDSlot3
        case .remixDeckDSlot4: return .remixDeckDSlot4
        }
    }
}

nonisolated enum SXMJSONInteraction: String, Codable, Sendable {
    case none, toggle, hold, direct, relative, increment, decrement, reset, output, trigger
    init(_ model: InteractionMode) {
        switch model {
        case .none: self = .none
        case .toggle: self = .toggle
        case .hold: self = .hold
        case .direct: self = .direct
        case .relative: self = .relative
        case .increment: self = .increment
        case .decrement: self = .decrement
        case .reset: self = .reset
        case .output: self = .output
        case .trigger: self = .trigger
        }
    }
    var model: InteractionMode {
        switch self {
        case .none: return .none
        case .toggle: return .toggle
        case .hold: return .hold
        case .direct: return .direct
        case .relative: return .relative
        case .increment: return .increment
        case .decrement: return .decrement
        case .reset: return .reset
        case .output: return .output
        case .trigger: return .trigger
        }
    }
}

nonisolated enum SXMJSONController: String, Codable, Sendable {
    case none, button, faderOrKnob, encoder, led
    init(_ model: ControllerType) {
        switch model {
        case .none: self = .none
        case .button: self = .button
        case .faderOrKnob: self = .faderOrKnob
        case .encoder: self = .encoder
        case .led: self = .led
        }
    }
    var model: ControllerType {
        switch self {
        case .none: return .none
        case .button: return .button
        case .faderOrKnob: return .faderOrKnob
        case .encoder: return .encoder
        case .led: return .led
        }
    }
}

nonisolated enum SXMJSONEncoder: String, Codable, Sendable {
    case mode7Fh01h, mode3Fh41h
    init(_ model: EncoderMode) {
        switch model {
        case .mode7Fh01h: self = .mode7Fh01h
        case .mode3Fh41h: self = .mode3Fh41h
        }
    }
    var model: EncoderMode {
        switch self {
        case .mode7Fh01h: return .mode7Fh01h
        case .mode3Fh41h: return .mode3Fh41h
        }
    }
}

nonisolated struct SXMJSONMapping: Codable, Sendable {
    var id: UUID
    var commandID: Int
    var commandName: String?
    var ioType: SXMJSONDirection
    var assignment: SXMJSONAssignment
    var interactionMode: SXMJSONInteraction
    var midi: SXMJSONMIDI
    var modifier1Condition: SXMJSONCondition?
    var modifier2Condition: SXMJSONCondition?
    var comment: String
    var controllerType: SXMJSONController
    var invert: Bool
    var softTakeover: Bool
    var setToValue: SXMJSONFloat
    var rotarySensitivity: SXMJSONFloat
    var rotaryAcceleration: SXMJSONFloat
    var encoderMode: SXMJSONEncoder
    var autoRepeat: Bool
    var ledMinRangeType: Int
    var ledMinRangeData: Int
    var ledMaxRangeType: Int
    var ledMaxRangeData: Int
    var ledMinMidi: Int
    var ledMaxMidi: Int
    var ledInvert: Bool
    var ledBlend: Bool
    var resolution: Int

    init(_ row: MappingEntry) {
        id = row.id
        commandID = row.commandID
        commandName = row.commandName
        ioType = SXMJSONDirection(row.ioType)
        assignment = SXMJSONAssignment(row.assignment)
        interactionMode = SXMJSONInteraction(row.interactionMode)
        midi = SXMJSONMIDI(row.midiAssignment)
        modifier1Condition = row.modifier1Condition.map(SXMJSONCondition.init)
        modifier2Condition = row.modifier2Condition.map(SXMJSONCondition.init)
        comment = row.comment
        controllerType = SXMJSONController(row.controllerType)
        invert = row.invert
        softTakeover = row.softTakeover
        setToValue = SXMJSONFloat(row.setToValue)
        rotarySensitivity = SXMJSONFloat(row.rotarySensitivity)
        rotaryAcceleration = SXMJSONFloat(row.rotaryAcceleration)
        encoderMode = SXMJSONEncoder(row.encoderMode)
        autoRepeat = row.autoRepeat
        ledMinRangeType = row.ledMinRangeType
        ledMinRangeData = row.ledMinRangeData
        ledMaxRangeType = row.ledMaxRangeType
        ledMaxRangeData = row.ledMaxRangeData
        ledMinMidi = row.ledMinMidi
        ledMaxMidi = row.ledMaxMidi
        ledInvert = row.ledInvert
        ledBlend = row.ledBlend
        resolution = row.resolution
    }

    /// Adopt saved wire defaults only for fields unchanged since that save.
    /// Later unsaved edits remain in the editable projection.
    init(_ current: MappingEntry, saved: MappingEntry?, source: MappingEntry?) {
        self.init(current)
        guard let saved, let source else { return }
        let parsed = SXMJSONMapping(source)
        if current.commandID == saved.commandID { commandID = parsed.commandID }
        if current.ioType == saved.ioType { ioType = parsed.ioType }
        if current.assignment == saved.assignment { assignment = parsed.assignment }
        if current.interactionMode == saved.interactionMode { interactionMode = parsed.interactionMode }
        if current.midiAssignment == saved.midiAssignment { midi = parsed.midi }
        if current.modifier1Condition == saved.modifier1Condition { modifier1Condition = parsed.modifier1Condition }
        if current.modifier2Condition == saved.modifier2Condition { modifier2Condition = parsed.modifier2Condition }
        if current.comment == saved.comment { comment = parsed.comment }
        if current.controllerType == saved.controllerType { controllerType = parsed.controllerType }
        if current.invert == saved.invert { invert = parsed.invert }
        if current.softTakeover == saved.softTakeover { softTakeover = parsed.softTakeover }
        if current.setToValue.bitPattern == saved.setToValue.bitPattern { setToValue = parsed.setToValue }
        if current.rotarySensitivity.bitPattern == saved.rotarySensitivity.bitPattern { rotarySensitivity = parsed.rotarySensitivity }
        if current.rotaryAcceleration.bitPattern == saved.rotaryAcceleration.bitPattern { rotaryAcceleration = parsed.rotaryAcceleration }
        if current.encoderMode == saved.encoderMode { encoderMode = parsed.encoderMode }
        if current.autoRepeat == saved.autoRepeat { autoRepeat = parsed.autoRepeat }
        if current.ledMinRangeType == saved.ledMinRangeType { ledMinRangeType = parsed.ledMinRangeType }
        if current.ledMinRangeData == saved.ledMinRangeData { ledMinRangeData = parsed.ledMinRangeData }
        if current.ledMaxRangeType == saved.ledMaxRangeType { ledMaxRangeType = parsed.ledMaxRangeType }
        if current.ledMaxRangeData == saved.ledMaxRangeData { ledMaxRangeData = parsed.ledMaxRangeData }
        if current.ledMinMidi == saved.ledMinMidi { ledMinMidi = parsed.ledMinMidi }
        if current.ledMaxMidi == saved.ledMaxMidi { ledMaxMidi = parsed.ledMaxMidi }
        if current.ledInvert == saved.ledInvert { ledInvert = parsed.ledInvert }
        if current.ledBlend == saved.ledBlend { ledBlend = parsed.ledBlend }
        if current.resolution == saved.resolution { resolution = parsed.resolution }
        commandName = commandID == 0 ? "" : TraktorCommands.descriptor(for: commandID).name
    }

    func model(source: MappingEntry?) throws -> MappingEntry {
        var row = source?.copy(withID: id) ?? MappingEntry(id: id)
        row.commandID = commandID
        row.ioType = ioType.model
        row.assignment = assignment.model
        row.interactionMode = interactionMode.model
        let assignment = try midi.model()
        if row.midiAssignment != assignment { row.midiAssignment = assignment }
        row.modifier1Condition = try modifier1Condition?.model()
        row.modifier2Condition = try modifier2Condition?.model()
        row.comment = comment
        row.controllerType = controllerType.model
        row.invert = invert
        row.softTakeover = softTakeover
        row.setToValue = setToValue.value
        row.rotarySensitivity = rotarySensitivity.value
        row.rotaryAcceleration = rotaryAcceleration.value
        if row.encoderMode != encoderMode.model { row.setEncoderMode(encoderMode.model) }
        row.autoRepeat = autoRepeat
        row.ledMinRangeType = ledMinRangeType
        row.ledMinRangeData = ledMinRangeData
        row.ledMaxRangeType = ledMaxRangeType
        row.ledMaxRangeData = ledMaxRangeData
        row.ledMinMidi = ledMinMidi
        row.ledMaxMidi = ledMaxMidi
        row.ledInvert = ledInvert
        row.ledBlend = ledBlend
        row.resolution = resolution
        return row
    }
}
