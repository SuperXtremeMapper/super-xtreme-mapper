import Foundation

/// Flat, bounded data; no tools or executable model output.
nonisolated struct AssistantEditOperation: Codable, Sendable {
    enum Kind: String, Codable, Sendable { case add, update, delete, duplicate, reorder }
    let kind: Kind
    let deviceID: UUID
    var rowID: UUID? = nil
    var newRowID: UUID? = nil
    var patch: AssistantRowPatch? = nil
    var rowOrder: [UUID]? = nil
    enum CodingKeys: String, CodingKey, CaseIterable { case kind, deviceID, rowID, newRowID, patch, rowOrder }
    init(kind: Kind, deviceID: UUID, rowID: UUID? = nil, newRowID: UUID? = nil, patch: AssistantRowPatch? = nil, rowOrder: [UUID]? = nil) {
        self.kind = kind; self.deviceID = deviceID; self.rowID = rowID
        self.newRowID = newRowID; self.patch = patch; self.rowOrder = rowOrder
    }
    init(from decoder: Decoder) throws {
        try AssistantStrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(Kind.self, forKey: .kind)
        deviceID = try c.decode(UUID.self, forKey: .deviceID)
        rowID = try c.decodeIfPresent(UUID.self, forKey: .rowID)
        newRowID = try c.decodeIfPresent(UUID.self, forKey: .newRowID)
        patch = try c.decodeIfPresent(AssistantRowPatch.self, forKey: .patch)
        rowOrder = try c.decodeIfPresent([UUID].self, forKey: .rowOrder)
        try validateShape()
    }
    func validateShape() throws {
        let valid: Bool
        switch kind {
        case .add: valid = newRowID != nil && patch?.commandID != nil && rowID == nil && rowOrder == nil
        case .update: valid = rowID != nil && patch != nil && newRowID == nil && rowOrder == nil
        case .delete: valid = rowID != nil && patch == nil && newRowID == nil && rowOrder == nil
        case .duplicate: valid = rowID != nil && newRowID != nil && rowOrder == nil
        case .reorder: valid = rowOrder != nil && rowID == nil && newRowID == nil && patch == nil
        }
        guard valid else { throw AssistantEditError.invalid("The \(kind.rawValue) operation has missing or unsupported fields. Request a fresh proposal.") }
    }
}

/// Missing fields retain the exact native value. Clear flags explicitly remove conditions.
nonisolated struct AssistantRowPatch: Codable, Sendable {
    var commandID: Int? = nil
    var ioType: SXMJSONDirection? = nil
    var assignment: SXMJSONAssignment? = nil
    var interactionMode: SXMJSONInteraction? = nil
    var midi: SXMJSONMIDI? = nil
    var modifier1Condition: SXMJSONCondition? = nil
    var modifier2Condition: SXMJSONCondition? = nil
    var clearModifier1Condition: Bool? = nil
    var clearModifier2Condition: Bool? = nil
    var comment: String? = nil
    var controllerType: SXMJSONController? = nil
    var invert: Bool? = nil
    var softTakeover: Bool? = nil
    var setToValue: Float? = nil
    var rotarySensitivity: Float? = nil
    var rotaryAcceleration: Float? = nil
    var encoderMode: SXMJSONEncoder? = nil
    var autoRepeat: Bool? = nil
    var ledMinRangeType: Int? = nil
    var ledMinRangeData: Int? = nil
    var ledMaxRangeType: Int? = nil
    var ledMaxRangeData: Int? = nil
    var ledMinMidi: Int? = nil
    var ledMaxMidi: Int? = nil
    var ledInvert: Bool? = nil
    var ledBlend: Bool? = nil
    var resolution: Int? = nil
    enum CodingKeys: String, CodingKey, CaseIterable { case commandID, ioType, assignment, interactionMode, midi, modifier1Condition, modifier2Condition, clearModifier1Condition, clearModifier2Condition, comment, controllerType, invert, softTakeover, setToValue, rotarySensitivity, rotaryAcceleration, encoderMode, autoRepeat, ledMinRangeType, ledMinRangeData, ledMaxRangeType, ledMaxRangeData, ledMinMidi, ledMaxMidi, ledInvert, ledBlend, resolution }
    init(commandID: Int? = nil, ioType: SXMJSONDirection? = nil, assignment: SXMJSONAssignment? = nil, interactionMode: SXMJSONInteraction? = nil, midi: SXMJSONMIDI? = nil, modifier1Condition: SXMJSONCondition? = nil, modifier2Condition: SXMJSONCondition? = nil, clearModifier1Condition: Bool? = nil, clearModifier2Condition: Bool? = nil, comment: String? = nil, controllerType: SXMJSONController? = nil, invert: Bool? = nil, softTakeover: Bool? = nil, setToValue: Float? = nil, rotarySensitivity: Float? = nil, rotaryAcceleration: Float? = nil, encoderMode: SXMJSONEncoder? = nil, autoRepeat: Bool? = nil, ledMinRangeType: Int? = nil, ledMinRangeData: Int? = nil, ledMaxRangeType: Int? = nil, ledMaxRangeData: Int? = nil, ledMinMidi: Int? = nil, ledMaxMidi: Int? = nil, ledInvert: Bool? = nil, ledBlend: Bool? = nil, resolution: Int? = nil) {
        self.commandID = commandID
        self.ioType = ioType
        self.assignment = assignment
        self.interactionMode = interactionMode
        self.midi = midi
        self.modifier1Condition = modifier1Condition
        self.modifier2Condition = modifier2Condition
        self.clearModifier1Condition = clearModifier1Condition
        self.clearModifier2Condition = clearModifier2Condition
        self.comment = comment
        self.controllerType = controllerType
        self.invert = invert
        self.softTakeover = softTakeover
        self.setToValue = setToValue
        self.rotarySensitivity = rotarySensitivity
        self.rotaryAcceleration = rotaryAcceleration
        self.encoderMode = encoderMode
        self.autoRepeat = autoRepeat
        self.ledMinRangeType = ledMinRangeType
        self.ledMinRangeData = ledMinRangeData
        self.ledMaxRangeType = ledMaxRangeType
        self.ledMaxRangeData = ledMaxRangeData
        self.ledMinMidi = ledMinMidi
        self.ledMaxMidi = ledMaxMidi
        self.ledInvert = ledInvert
        self.ledBlend = ledBlend
        self.resolution = resolution
    }
    init(from decoder: Decoder) throws {
        try AssistantStrictKeys.check(decoder, allowed: CodingKeys.allCases.map(\.rawValue))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.midi) { try AssistantStrictKeys.check(c.superDecoder(forKey: .midi), allowed: ["kind", "channel", "number"]) }
        for key in [CodingKeys.modifier1Condition, .modifier2Condition] where c.contains(key) {
            try AssistantStrictKeys.check(c.superDecoder(forKey: key), allowed: ["modifier", "value", "target", "rawTarget"])
        }
        commandID = try c.decodeIfPresent(Int.self, forKey: .commandID)
        ioType = try c.decodeIfPresent(SXMJSONDirection.self, forKey: .ioType)
        assignment = try c.decodeIfPresent(SXMJSONAssignment.self, forKey: .assignment)
        interactionMode = try c.decodeIfPresent(SXMJSONInteraction.self, forKey: .interactionMode)
        midi = try c.decodeIfPresent(SXMJSONMIDI.self, forKey: .midi)
        modifier1Condition = try c.decodeIfPresent(SXMJSONCondition.self, forKey: .modifier1Condition)
        modifier2Condition = try c.decodeIfPresent(SXMJSONCondition.self, forKey: .modifier2Condition)
        clearModifier1Condition = try c.decodeIfPresent(Bool.self, forKey: .clearModifier1Condition)
        clearModifier2Condition = try c.decodeIfPresent(Bool.self, forKey: .clearModifier2Condition)
        comment = try c.decodeIfPresent(String.self, forKey: .comment)
        controllerType = try c.decodeIfPresent(SXMJSONController.self, forKey: .controllerType)
        invert = try c.decodeIfPresent(Bool.self, forKey: .invert)
        softTakeover = try c.decodeIfPresent(Bool.self, forKey: .softTakeover)
        setToValue = try c.decodeIfPresent(Float.self, forKey: .setToValue)
        rotarySensitivity = try c.decodeIfPresent(Float.self, forKey: .rotarySensitivity)
        rotaryAcceleration = try c.decodeIfPresent(Float.self, forKey: .rotaryAcceleration)
        encoderMode = try c.decodeIfPresent(SXMJSONEncoder.self, forKey: .encoderMode)
        autoRepeat = try c.decodeIfPresent(Bool.self, forKey: .autoRepeat)
        ledMinRangeType = try c.decodeIfPresent(Int.self, forKey: .ledMinRangeType)
        ledMinRangeData = try c.decodeIfPresent(Int.self, forKey: .ledMinRangeData)
        ledMaxRangeType = try c.decodeIfPresent(Int.self, forKey: .ledMaxRangeType)
        ledMaxRangeData = try c.decodeIfPresent(Int.self, forKey: .ledMaxRangeData)
        ledMinMidi = try c.decodeIfPresent(Int.self, forKey: .ledMinMidi)
        ledMaxMidi = try c.decodeIfPresent(Int.self, forKey: .ledMaxMidi)
        ledInvert = try c.decodeIfPresent(Bool.self, forKey: .ledInvert)
        ledBlend = try c.decodeIfPresent(Bool.self, forKey: .ledBlend)
        resolution = try c.decodeIfPresent(Int.self, forKey: .resolution)
    }
    func applying(to original: MappingEntry) throws -> MappingEntry {
        var row = original
        if clearModifier1Condition == true && modifier1Condition != nil || clearModifier2Condition == true && modifier2Condition != nil {
            throw AssistantEditError.invalid("A condition cannot be set and cleared in the same operation.")
        }
        for (name, value, range) in [("rotarySensitivity", rotarySensitivity, Float(0)...Float(3)), ("rotaryAcceleration", rotaryAcceleration, Float(0)...Float(1))] {
            if let value, !value.isFinite || !range.contains(value) { throw AssistantEditError.invalid("\(name) must be finite and within \(range).") }
        }
        if let setToValue, !setToValue.isFinite { throw AssistantEditError.invalid("Set value must be finite.") }
        if let comment, comment.utf8.count > 4096 { throw AssistantEditError.invalid("Comments must be at most 4096 UTF-8 bytes.") }
        if let commandID { row.commandID = commandID }
        if let ioType { row.ioType = ioType.model }
        if let assignment { row.assignment = assignment.model }
        if let interactionMode { row.interactionMode = interactionMode.model }
        if let midi { row.midiAssignment = try midi.model() }
        if let modifier1Condition { row.modifier1Condition = try modifier1Condition.model() }
        if let modifier2Condition { row.modifier2Condition = try modifier2Condition.model() }
        if let comment { row.comment = comment }
        if let controllerType { row.controllerType = controllerType.model }
        if let invert { row.invert = invert }
        if let softTakeover { row.softTakeover = softTakeover }
        if let setToValue { row.setToValue = setToValue }
        if let rotarySensitivity { row.rotarySensitivity = rotarySensitivity }
        if let rotaryAcceleration { row.rotaryAcceleration = rotaryAcceleration }
        if let encoderMode { row.setEncoderMode(encoderMode.model) }
        if let autoRepeat { row.autoRepeat = autoRepeat }
        if let ledMinRangeType { row.ledMinRangeType = ledMinRangeType }
        if let ledMinRangeData { row.ledMinRangeData = ledMinRangeData }
        if let ledMaxRangeType { row.ledMaxRangeType = ledMaxRangeType }
        if let ledMaxRangeData { row.ledMaxRangeData = ledMaxRangeData }
        if let ledMinMidi { row.ledMinMidi = ledMinMidi }
        if let ledMaxMidi { row.ledMaxMidi = ledMaxMidi }
        if let ledInvert { row.ledInvert = ledInvert }
        if let ledBlend { row.ledBlend = ledBlend }
        if let resolution { row.resolution = resolution }
        if clearModifier1Condition == true { row.modifier1Condition = nil }
        if clearModifier2Condition == true { row.modifier2Condition = nil }
        return row
    }
}

nonisolated enum AssistantEditError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { switch self { case .invalid(let message): message } }
}

private nonisolated enum AssistantStrictKeys {
    struct Key: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    static func check(_ decoder: Decoder, allowed: [String]) throws {
        let c = try decoder.container(keyedBy: Key.self)
        for key in c.allKeys {
            guard allowed.contains(key.stringValue) else { throw AssistantEditError.invalid("Unsupported field: \(key.stringValue).") }
            guard try !c.decodeNil(forKey: key) else { throw AssistantEditError.invalid("Omit \(key.stringValue) instead of null; use explicit clear flags for conditions.") }
        }
    }
}
