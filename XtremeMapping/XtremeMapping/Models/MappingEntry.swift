//
//  MappingEntry.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation
import os

/// Represents a single MIDI mapping in a TSI file.
///
/// A mapping entry connects a MIDI control (note or CC) to a Traktor command,
/// with optional modifier conditions and assignment targets.
struct MappingEntry: Identifiable, Hashable, Sendable, Equatable {

    nonisolated fileprivate static let logger = Logger(subsystem: "com.sxm.app", category: "MappingEntry")

    /// Unique identifier for this mapping entry
    let id: UUID

    /// The authoritative Traktor command ID being mapped.
    var commandID: Int

    /// The catalog metadata for the authoritative command ID.
    var commandDescriptor: TraktorCommandDescriptor {
        TraktorCommands.descriptor(for: commandID)
    }

    /// The display name derived from the authoritative command ID.
    var commandName: String {
        commandID == 0 ? "" : commandDescriptor.name
    }

    /// Whether this is an input (controller to Traktor) or output (Traktor to controller)
    var ioType: IODirection

    /// The target deck, FX unit, or global assignment
    var assignment: TargetAssignment

    /// How the control interacts with the command (toggle, hold, direct, etc.)
    var interactionMode: InteractionMode

    /// The mapping's exclusive, validated MIDI state.
    var midiAssignment: MIDIAssignment {
        didSet {
            // An explicit edit replaces any opaque import-only assignment and
            // its definition metadata. Property observers do not run during
            // initialization/decoding, so imported state can still be loaded.
            rawMidiControlName = nil
            rawMidiBindingID = nil
            rawDCDTControlType = nil
            rawDCDTMinValueBits = nil
            rawDCDTMaxValueBits = nil
            rawDCDTEncoderMode = nil
            rawDCDTControlID = nil
        }
    }

    /// A native/proprietary MIDI control name not modeled as Note or CC.
    /// The writer emits this value verbatim until the user reassigns MIDI.
    var rawMidiControlName: String?

    /// A CMAI binding ID absent from DCBM. Kept verbatim so opening and saving
    /// cannot silently turn the mapping into a different or unassigned control.
    var rawMidiBindingID: UInt32?

    /// MIDI channel (1-16). Retained as a source-compatible accessor.
    var midiChannel: Int {
        get { midiAssignment.channel }
        set {
            do {
                midiAssignment = try midiAssignment.replacingChannel(with: newValue)
            } catch {
                preconditionFailure("Invalid MIDI channel: \(newValue)")
            }
        }
    }

    /// MIDI note number (0-127), nil if using CC. Setting a note clears CC.
    var midiNote: Int? {
        get { midiAssignment.note }
        set {
            do {
                if let newValue {
                    midiAssignment = try .note(channel: midiAssignment.channel, number: newValue)
                } else if midiAssignment.kind == .note {
                    midiAssignment = try .unassigned(channel: midiAssignment.channel)
                }
            } catch {
                preconditionFailure("Invalid MIDI note: \(String(describing: newValue))")
            }
        }
    }

    /// MIDI CC number (0-127), nil if using Note. Setting a CC clears Note.
    var midiCC: Int? {
        get { midiAssignment.cc }
        set {
            do {
                if let newValue {
                    midiAssignment = try .controlChange(
                        channel: midiAssignment.channel,
                        number: newValue
                    )
                } else if midiAssignment.kind == .controlChange {
                    midiAssignment = try .unassigned(channel: midiAssignment.channel)
                }
            } catch {
                preconditionFailure("Invalid MIDI CC: \(String(describing: newValue))")
            }
        }
    }

    /// First modifier condition (M1-M8 = 0-7), nil if no condition
    var modifier1Condition: ModifierCondition?

    /// Second modifier condition (M1-M8 = 0-7), nil if no condition
    var modifier2Condition: ModifierCondition?

    /// User comment for this mapping
    var comment: String

    /// The type of physical controller (button, fader, encoder, LED)
    var controllerType: ControllerType

    /// Whether to invert the control value
    var invert: Bool

    // MARK: - Type-specific options

    /// For Fader/Knob: enables soft takeover to prevent value jumps
    var softTakeover: Bool

    /// For Button (Direct mode): the value to set when pressed (0.0 - 1.0)
    var setToValue: Float

    /// For Encoder: rotary sensitivity (0.0 - 3.0, displayed as 0-300%)
    var rotarySensitivity: Float

    /// For Encoder: rotary acceleration (0.0 - 1.0, displayed as 0-100%)
    var rotaryAcceleration: Float

    /// For Encoder: the encoder communication mode
    var encoderMode: EncoderMode

    /// An unrecognized Traktor DCDT mode preserved opaquely from import.
    /// Known values are represented by `encoderMode` instead.
    var rawDCDTEncoderMode: UInt32?

    /// Remaining DCDT scalar metadata preserved bit-for-bit from native files.
    var rawDCDTControlType: UInt32?
    var rawDCDTMinValueBits: UInt32?
    var rawDCDTMaxValueBits: UInt32?
    var rawDCDTControlID: UInt32?

    /// The raw value emitted to Traktor, including opaque imported values.
    nonisolated var effectiveDCDTEncoderMode: UInt32 {
        rawDCDTEncoderMode ?? encoderMode.tsiDCDTValue
    }

    /// Applies an explicit user selection and ends opaque pass-through.
    mutating func setEncoderMode(_ mode: EncoderMode) {
        encoderMode = mode
        rawDCDTEncoderMode = nil
    }

    // MARK: - CMAD pass-through fields (round-tripped, not yet surfaced in UI)

    /// For Button: repeat the command while held
    var autoRepeat: Bool

    /// LED min controller range value type (CMAD ValueUIType enum)
    var ledMinRangeType: Int

    /// LED min controller range value
    var ledMinRangeData: Int

    /// LED max controller range value type (CMAD ValueUIType enum)
    var ledMaxRangeType: Int

    /// LED max controller range value
    var ledMaxRangeData: Int

    /// LED minimum MIDI output value (0-127)
    var ledMinMidi: Int

    /// LED maximum MIDI output value (0-127)
    var ledMaxMidi: Int

    /// Invert the LED output range
    var ledInvert: Bool

    /// Blend the LED output between min and max
    var ledBlend: Bool

    /// Encoder/fader resolution (CMAD Resolution enum)
    var resolution: Int

    /// Exact CMAD wire state and immutable semantic-at-import fingerprint.
    /// New rows have no imported state and continue to use command profiles.
    var importedCMAD: ImportedCMAD?

    // MARK: - Sort Keys (for table column sorting)

    /// Sort key for I/O column
    var ioTypeSortKey: String { ioType.rawValue }

    /// Sort key for Assignment column
    var assignmentSortKey: String { assignment.displayName }

    /// Sort key for Controller Type column
    var controllerTypeSortKey: String { controllerType.displayName }

    /// Sort key for Interaction column
    var interactionSortKey: String { interactionMode.displayName }

    /// Sort key for Modifier 1 column
    var modifier1SortKey: String { modifier1Condition?.displayString ?? "zzz" }

    /// Sort key for Modifier 2 column
    var modifier2SortKey: String { modifier2Condition?.displayString ?? "zzz" }

    /// Whether this mapping has a modeled or opaquely preserved MIDI assignment.
    var hasMIDIAssignment: Bool {
        midiAssignment.kind != .unassigned
            || rawMidiControlName != nil
            || rawMidiBindingID != nil
    }

    /// Display string showing the MIDI assignment (e.g., "Ch01 CC 008" or "Ch02 Note C4")
    var mappedToDisplay: String {
        if let rawMidiControlName {
            return rawMidiControlName
        }
        if let rawMidiBindingID {
            return "Unresolved MIDI #\(rawMidiBindingID)"
        }
        return midiAssignment.displayName
    }

    var tsiCompatibilityWarning: TSICompatibilityWarning? {
        if let rawMidiBindingID {
            return .unresolvedMIDIBinding(id: rawMidiBindingID)
        }
        if let rawMidiControlName {
            return .opaqueMIDIControl(name: rawMidiControlName)
        }
        return nil
    }


    /// Creates a new mapping entry with the specified properties.
    ///
    /// All parameters have sensible defaults for creating empty mappings.
    init(
        id: UUID = UUID(),
        commandID: Int? = nil,
        commandName: String = "",
        ioType: IODirection = .input,
        assignment: TargetAssignment = .none,
        interactionMode: InteractionMode = .none,
        midiAssignment: MIDIAssignment? = nil,
        midiChannel: Int = 1,
        midiNote: Int? = nil,
        midiCC: Int? = nil,
        rawMidiControlName: String? = nil,
        rawMidiBindingID: UInt32? = nil,
        modifier1Condition: ModifierCondition? = nil,
        modifier2Condition: ModifierCondition? = nil,
        comment: String = "",
        controllerType: ControllerType = .none,
        invert: Bool = false,
        softTakeover: Bool = false,
        setToValue: Float = 0.0,
        rotarySensitivity: Float = 5.0,
        rotaryAcceleration: Float = 0.0,
        encoderMode: EncoderMode = .mode7Fh01h,
        rawDCDTEncoderMode: UInt32? = nil,
        rawDCDTControlType: UInt32? = nil,
        rawDCDTMinValueBits: UInt32? = nil,
        rawDCDTMaxValueBits: UInt32? = nil,
        rawDCDTControlID: UInt32? = nil,
        autoRepeat: Bool = false,
        ledMinRangeType: Int = 1,
        ledMinRangeData: Int = 0,
        ledMaxRangeType: Int = 1,
        ledMaxRangeData: Int = 1,
        ledMinMidi: Int = 0,
        ledMaxMidi: Int = 127,
        ledInvert: Bool = false,
        ledBlend: Bool = false,
        resolution: Int = 1,
        importedCMAD: ImportedCMAD? = nil
    ) {
        self.id = id
        self.commandID = commandID ?? TraktorCommands.id(forLegacyName: commandName)
        self.ioType = ioType
        self.assignment = assignment
        self.interactionMode = interactionMode
        if let midiAssignment {
            self.midiAssignment = midiAssignment
        } else {
            do {
                self.midiAssignment = try MIDIAssignment(
                    validatingChannel: midiChannel,
                    note: midiNote,
                    cc: midiCC
                )
            } catch {
                preconditionFailure("Invalid direct MIDI assignment: \(error)")
            }
        }
        self.rawMidiControlName = rawMidiControlName
        self.rawMidiBindingID = rawMidiControlName == nil ? rawMidiBindingID : nil
        self.modifier1Condition = modifier1Condition
        self.modifier2Condition = modifier2Condition
        self.comment = comment
        self.controllerType = controllerType
        self.invert = invert
        self.softTakeover = softTakeover
        self.setToValue = setToValue
        self.rotarySensitivity = rotarySensitivity
        self.rotaryAcceleration = rotaryAcceleration
        self.encoderMode = encoderMode
        self.rawDCDTEncoderMode = rawDCDTEncoderMode.flatMap {
            EncoderMode(tsiDCDTValue: $0) == nil ? $0 : nil
        }
        self.rawDCDTControlType = rawDCDTControlType
        self.rawDCDTMinValueBits = rawDCDTMinValueBits
        self.rawDCDTMaxValueBits = rawDCDTMaxValueBits
        self.rawDCDTControlID = rawDCDTControlID
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
        self.importedCMAD = importedCMAD
    }

    /// Returns a value-identical mapping with a new identity for insertion.
    func copyWithNewID() -> MappingEntry {
        copy(withID: UUID())
    }

    /// Returns a value-identical mapping using an identity allocated by the caller.
    func copy(withID id: UUID) -> MappingEntry {
        MappingEntry(
            id: id,
            commandID: commandID,
            ioType: ioType,
            assignment: assignment,
            interactionMode: interactionMode,
            midiAssignment: midiAssignment,
            rawMidiControlName: rawMidiControlName,
            rawMidiBindingID: rawMidiBindingID,
            modifier1Condition: modifier1Condition,
            modifier2Condition: modifier2Condition,
            comment: comment,
            controllerType: controllerType,
            invert: invert,
            softTakeover: softTakeover,
            setToValue: setToValue,
            rotarySensitivity: rotarySensitivity,
            rotaryAcceleration: rotaryAcceleration,
            encoderMode: encoderMode,
            rawDCDTEncoderMode: rawDCDTEncoderMode,
            rawDCDTControlType: rawDCDTControlType,
            rawDCDTMinValueBits: rawDCDTMinValueBits,
            rawDCDTMaxValueBits: rawDCDTMaxValueBits,
            rawDCDTControlID: rawDCDTControlID,
            autoRepeat: autoRepeat,
            ledMinRangeType: ledMinRangeType,
            ledMinRangeData: ledMinRangeData,
            ledMaxRangeType: ledMaxRangeType,
            ledMaxRangeData: ledMaxRangeData,
            ledMinMidi: ledMinMidi,
            ledMaxMidi: ledMaxMidi,
            ledInvert: ledInvert,
            ledBlend: ledBlend,
            resolution: resolution,
            importedCMAD: importedCMAD
        )
    }

    /// Value equality is also document-semantic equality, so Float wire
    /// distinctions must survive it. IDs remain part of equality: copying a
    /// row for insertion still creates a distinct model identity.
    nonisolated static func == (lhs: MappingEntry, rhs: MappingEntry) -> Bool {
        lhs.id == rhs.id
            && lhs.commandID == rhs.commandID
            && lhs.ioType == rhs.ioType
            && lhs.assignment == rhs.assignment
            && lhs.interactionMode == rhs.interactionMode
            && lhs.midiAssignment == rhs.midiAssignment
            && lhs.rawMidiControlName == rhs.rawMidiControlName
            && lhs.rawMidiBindingID == rhs.rawMidiBindingID
            && lhs.modifier1Condition == rhs.modifier1Condition
            && lhs.modifier2Condition == rhs.modifier2Condition
            && lhs.comment == rhs.comment
            && lhs.controllerType == rhs.controllerType
            && lhs.invert == rhs.invert
            && lhs.softTakeover == rhs.softTakeover
            && lhs.setToValue.bitPattern == rhs.setToValue.bitPattern
            && lhs.rotarySensitivity.bitPattern == rhs.rotarySensitivity.bitPattern
            && lhs.rotaryAcceleration.bitPattern == rhs.rotaryAcceleration.bitPattern
            && lhs.encoderMode == rhs.encoderMode
            && lhs.rawDCDTEncoderMode == rhs.rawDCDTEncoderMode
            && lhs.rawDCDTControlType == rhs.rawDCDTControlType
            && lhs.rawDCDTMinValueBits == rhs.rawDCDTMinValueBits
            && lhs.rawDCDTMaxValueBits == rhs.rawDCDTMaxValueBits
            && lhs.rawDCDTControlID == rhs.rawDCDTControlID
            && lhs.autoRepeat == rhs.autoRepeat
            && lhs.ledMinRangeType == rhs.ledMinRangeType
            && lhs.ledMinRangeData == rhs.ledMinRangeData
            && lhs.ledMaxRangeType == rhs.ledMaxRangeType
            && lhs.ledMaxRangeData == rhs.ledMaxRangeData
            && lhs.ledMinMidi == rhs.ledMinMidi
            && lhs.ledMaxMidi == rhs.ledMaxMidi
            && lhs.ledInvert == rhs.ledInvert
            && lhs.ledBlend == rhs.ledBlend
            && lhs.resolution == rhs.resolution
            && lhs.importedCMAD == rhs.importedCMAD
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(commandID)
        hasher.combine(ioType)
        hasher.combine(assignment)
        hasher.combine(interactionMode)
        hasher.combine(midiAssignment)
        hasher.combine(rawMidiControlName)
        hasher.combine(rawMidiBindingID)
        hasher.combine(modifier1Condition)
        hasher.combine(modifier2Condition)
        hasher.combine(comment)
        hasher.combine(controllerType)
        hasher.combine(invert)
        hasher.combine(softTakeover)
        hasher.combine(setToValue.bitPattern)
        hasher.combine(rotarySensitivity.bitPattern)
        hasher.combine(rotaryAcceleration.bitPattern)
        hasher.combine(encoderMode)
        hasher.combine(rawDCDTEncoderMode)
        hasher.combine(rawDCDTControlType)
        hasher.combine(rawDCDTMinValueBits)
        hasher.combine(rawDCDTMaxValueBits)
        hasher.combine(rawDCDTControlID)
        hasher.combine(autoRepeat)
        hasher.combine(ledMinRangeType)
        hasher.combine(ledMinRangeData)
        hasher.combine(ledMaxRangeType)
        hasher.combine(ledMaxRangeData)
        hasher.combine(ledMinMidi)
        hasher.combine(ledMaxMidi)
        hasher.combine(ledInvert)
        hasher.combine(ledBlend)
        hasher.combine(resolution)
        hasher.combine(importedCMAD)
    }
}

// MARK: - Nonisolated Codable Conformance

extension MappingEntry: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)

        // Legacy migration: Traktor-3-era "Slot N <Op>" command names written
        // by older wizard versions resolved to fabricated commandIds 2900..2923,
        // which Traktor 4.4 silently drops. Rewrite to canonical
        // "Slot <Op>" + Assignment = Deck A Slot N. Mirrors the TSIInterpreter
        // post-parse fix-up for legacy v4 TSI files. Done in locals so the
        // migrated values land in the stored properties on first assignment
        // (avoiding closure capture before self.* is initialized).
        let decodedCommandID = try container.decodeIfPresent(Int.self, forKey: .commandID)
        var decodedCommandName = try container.decodeIfPresent(String.self, forKey: .commandName) ?? ""
        ioType = try container.decode(IODirection.self, forKey: .ioType)
        var decodedAssignment = try container.decode(TargetAssignment.self, forKey: .assignment)

        if decodedCommandID == nil {
            let slotPrefixes = ["Slot 1 ", "Slot 2 ", "Slot 3 ", "Slot 4 "]
            if let slotIdx = slotPrefixes.firstIndex(where: { decodedCommandName.hasPrefix($0) }) {
                let suffix = String(decodedCommandName.dropFirst(7)) // strip "Slot N "
                let remix: TargetAssignment = [.remixDeckASlot1, .remixDeckASlot2, .remixDeckASlot3, .remixDeckASlot4][slotIdx]
                switch suffix {
                case "Volume":    decodedCommandName = "Slot Volume";        decodedAssignment = remix
                case "Mute":      decodedCommandName = "Slot Mute On";       decodedAssignment = remix
                case "Filter":    decodedCommandName = "Slot Filter Adjust"; decodedAssignment = remix
                case "Filter On": decodedCommandName = "Slot Filter On";     decodedAssignment = remix
                case "FX On":     decodedCommandName = "Slot FX On";         decodedAssignment = remix
                case "FX Send":
                    Self.logger.warning("Loading legacy 'Slot N FX Send' commandName from JSON as invalid command ID 0")
                default: break
                }
            }
        }
        commandID = decodedCommandID ?? TraktorCommands.id(forLegacyName: decodedCommandName)
        assignment = decodedAssignment
        interactionMode = try container.decode(InteractionMode.self, forKey: .interactionMode)
        let decodedMIDIChannel = try container.decode(Int.self, forKey: .midiChannel)
        let decodedMIDINote = try container.decodeIfPresent(Int.self, forKey: .midiNote)
        let decodedMIDICC = try container.decodeIfPresent(Int.self, forKey: .midiCC)
        do {
            midiAssignment = try MIDIAssignment(
                validatingChannel: decodedMIDIChannel,
                note: decodedMIDINote,
                cc: decodedMIDICC
            )
        } catch {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: container.codingPath,
                    debugDescription: "Invalid legacy MIDI assignment.",
                    underlyingError: error
                )
            )
        }
        rawMidiControlName = try container.decodeIfPresent(String.self, forKey: .rawMidiControlName)
        rawMidiBindingID = try container.decodeIfPresent(UInt32.self, forKey: .rawMidiBindingID)
        if rawMidiControlName != nil {
            rawMidiBindingID = nil
        }
        let modifier1TargetWasEncoded = try container.decodeIfPresent(
            ModifierConditionTargetPresence.self,
            forKey: .modifier1Condition
        )?.target != nil
        let modifier2TargetWasEncoded = try container.decodeIfPresent(
            ModifierConditionTargetPresence.self,
            forKey: .modifier2Condition
        )?.target != nil
        modifier1Condition = try container.decodeIfPresent(
            ModifierCondition.self,
            forKey: .modifier1Condition
        )
        modifier2Condition = try container.decodeIfPresent(
            ModifierCondition.self,
            forKey: .modifier2Condition
        )
        comment = try container.decode(String.self, forKey: .comment)
        controllerType = try container.decode(ControllerType.self, forKey: .controllerType)
        invert = try container.decode(Bool.self, forKey: .invert)
        softTakeover = try container.decode(Bool.self, forKey: .softTakeover)
        if let bits = try container.decodeIfPresent(UInt32.self, forKey: .setToValueBits) {
            setToValue = Float(bitPattern: bits)
        } else {
            setToValue = try container.decode(Float.self, forKey: .setToValue)
        }
        if let bits = try container.decodeIfPresent(UInt32.self, forKey: .rotarySensitivityBits) {
            rotarySensitivity = Float(bitPattern: bits)
        } else {
            rotarySensitivity = try container.decodeIfPresent(
                Float.self,
                forKey: .rotarySensitivity
            ) ?? 5.0
        }
        if let bits = try container.decodeIfPresent(UInt32.self, forKey: .rotaryAccelerationBits) {
            rotaryAcceleration = Float(bitPattern: bits)
        } else {
            rotaryAcceleration = try container.decode(Float.self, forKey: .rotaryAcceleration)
        }
        encoderMode = try container.decode(EncoderMode.self, forKey: .encoderMode)
        rawDCDTEncoderMode = try container.decodeIfPresent(
            UInt32.self,
            forKey: .rawDCDTEncoderMode
        ).flatMap {
            EncoderMode(tsiDCDTValue: $0) == nil ? $0 : nil
        }
        rawDCDTControlType = try container.decodeIfPresent(UInt32.self, forKey: .rawDCDTControlType)
        rawDCDTMinValueBits = try container.decodeIfPresent(UInt32.self, forKey: .rawDCDTMinValueBits)
        rawDCDTMaxValueBits = try container.decodeIfPresent(UInt32.self, forKey: .rawDCDTMaxValueBits)
        rawDCDTControlID = try container.decodeIfPresent(UInt32.self, forKey: .rawDCDTControlID)
        // New CMAD pass-through fields: decode with defaults so old saved state still loads
        autoRepeat = try container.decodeIfPresent(Bool.self, forKey: .autoRepeat) ?? false
        ledMinRangeType = try container.decodeIfPresent(Int.self, forKey: .ledMinRangeType) ?? 1
        ledMinRangeData = try container.decodeIfPresent(Int.self, forKey: .ledMinRangeData) ?? 0
        ledMaxRangeType = try container.decodeIfPresent(Int.self, forKey: .ledMaxRangeType) ?? 1
        ledMaxRangeData = try container.decodeIfPresent(Int.self, forKey: .ledMaxRangeData) ?? 1
        ledMinMidi = try container.decodeIfPresent(Int.self, forKey: .ledMinMidi) ?? 0
        ledMaxMidi = try container.decodeIfPresent(Int.self, forKey: .ledMaxMidi) ?? 127
        ledInvert = try container.decodeIfPresent(Bool.self, forKey: .ledInvert) ?? false
        ledBlend = try container.decodeIfPresent(Bool.self, forKey: .ledBlend) ?? false
        resolution = try container.decodeIfPresent(Int.self, forKey: .resolution) ?? 1
        importedCMAD = try container.decodeIfPresent(ImportedCMAD.self, forKey: .importedCMAD)
        if var importedCMAD {
            if !modifier1TargetWasEncoded,
               let rawTarget = importedCMAD.conditionOneTarget,
               importedCMAD.semanticAtImport.modifier1Condition != nil,
               modifier1Condition != nil {
                let target = ModifierConditionTarget(rawValue: rawTarget)
                modifier1Condition?.target = target
                importedCMAD.semanticAtImport.modifier1Condition?.target = target
            }
            if !modifier2TargetWasEncoded,
               let rawTarget = importedCMAD.conditionTwoTarget,
               importedCMAD.semanticAtImport.modifier2Condition != nil,
               modifier2Condition != nil {
                let target = ModifierConditionTarget(rawValue: rawTarget)
                modifier2Condition?.target = target
                importedCMAD.semanticAtImport.modifier2Condition?.target = target
            }
            self.importedCMAD = importedCMAD
        }
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(commandID, forKey: .commandID)
        try container.encode(commandName, forKey: .commandName)
        try container.encode(ioType, forKey: .ioType)
        try container.encode(assignment, forKey: .assignment)
        try container.encode(interactionMode, forKey: .interactionMode)
        try container.encode(midiAssignment.channel, forKey: .midiChannel)
        try container.encodeIfPresent(midiAssignment.note, forKey: .midiNote)
        try container.encodeIfPresent(midiAssignment.cc, forKey: .midiCC)
        try container.encodeIfPresent(rawMidiControlName, forKey: .rawMidiControlName)
        try container.encodeIfPresent(rawMidiBindingID, forKey: .rawMidiBindingID)
        try container.encodeIfPresent(modifier1Condition, forKey: .modifier1Condition)
        try container.encodeIfPresent(modifier2Condition, forKey: .modifier2Condition)
        try container.encode(comment, forKey: .comment)
        try container.encode(controllerType, forKey: .controllerType)
        try container.encode(invert, forKey: .invert)
        try container.encode(softTakeover, forKey: .softTakeover)
        try container.encode(setToValue.bitPattern, forKey: .setToValueBits)
        try container.encode(rotarySensitivity.bitPattern, forKey: .rotarySensitivityBits)
        try container.encode(rotaryAcceleration.bitPattern, forKey: .rotaryAccelerationBits)
        if setToValue.isFinite {
            try container.encode(setToValue, forKey: .setToValue)
        }
        if rotarySensitivity.isFinite {
            try container.encode(rotarySensitivity, forKey: .rotarySensitivity)
        }
        if rotaryAcceleration.isFinite {
            try container.encode(rotaryAcceleration, forKey: .rotaryAcceleration)
        }
        try container.encode(encoderMode, forKey: .encoderMode)
        try container.encodeIfPresent(rawDCDTEncoderMode, forKey: .rawDCDTEncoderMode)
        try container.encodeIfPresent(rawDCDTControlType, forKey: .rawDCDTControlType)
        try container.encodeIfPresent(rawDCDTMinValueBits, forKey: .rawDCDTMinValueBits)
        try container.encodeIfPresent(rawDCDTMaxValueBits, forKey: .rawDCDTMaxValueBits)
        try container.encodeIfPresent(rawDCDTControlID, forKey: .rawDCDTControlID)
        try container.encode(autoRepeat, forKey: .autoRepeat)
        try container.encode(ledMinRangeType, forKey: .ledMinRangeType)
        try container.encode(ledMinRangeData, forKey: .ledMinRangeData)
        try container.encode(ledMaxRangeType, forKey: .ledMaxRangeType)
        try container.encode(ledMaxRangeData, forKey: .ledMaxRangeData)
        try container.encode(ledMinMidi, forKey: .ledMinMidi)
        try container.encode(ledMaxMidi, forKey: .ledMaxMidi)
        try container.encode(ledInvert, forKey: .ledInvert)
        try container.encode(ledBlend, forKey: .ledBlend)
        try container.encode(resolution, forKey: .resolution)
        try container.encodeIfPresent(importedCMAD, forKey: .importedCMAD)
    }

    private enum CodingKeys: String, CodingKey {
        case id, commandID, commandName, ioType, assignment, interactionMode
        case midiChannel, midiNote, midiCC, rawMidiControlName, rawMidiBindingID
        case modifier1Condition, modifier2Condition
        case comment, controllerType, invert
        case softTakeover, setToValue, setToValueBits
        case rotarySensitivity, rotarySensitivityBits
        case rotaryAcceleration, rotaryAccelerationBits, encoderMode, rawDCDTEncoderMode
        case rawDCDTControlType, rawDCDTMinValueBits, rawDCDTMaxValueBits, rawDCDTControlID
        case autoRepeat
        case ledMinRangeType, ledMinRangeData, ledMaxRangeType, ledMaxRangeData
        case ledMinMidi, ledMaxMidi, ledInvert, ledBlend
        case resolution, importedCMAD
    }

    private struct ModifierConditionTargetPresence: Decodable {
        let target: ModifierConditionTarget?
    }
}

/// The native target associated with a modifier condition.
///
/// Traktor uses the same 0...3 deck numbering as ordinary deck assignments.
/// Values outside that known range remain lossless but intentionally opaque.
enum ModifierConditionTarget: Hashable, Sendable, Equatable {
    case deckA
    case deckB
    case deckC
    case deckD
    case unknown(UInt32)

    init(rawValue: UInt32) {
        switch rawValue {
        case 0: self = .deckA
        case 1: self = .deckB
        case 2: self = .deckC
        case 3: self = .deckD
        default: self = .unknown(rawValue)
        }
    }

    var rawValue: UInt32 {
        switch self {
        case .deckA: 0
        case .deckB: 1
        case .deckC: 2
        case .deckD: 3
        case .unknown(let rawValue): rawValue
        }
    }
}

extension ModifierConditionTarget: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UInt32.self))
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A modifier condition that must be met for a mapping to be active.
///
/// Traktor supports 8 modifiers (M1-M8), each with values 0-7.
/// A mapping can require specific modifier values to be active.
struct ModifierCondition: Hashable, Sendable, Equatable {
    /// The modifier number (1-8 for M1-M8)
    var modifier: Int

    /// The required value (0-7)
    var value: Int

    /// Native deck target for this condition. Older saved documents and new
    /// app-created conditions default to Deck A, whose wire value is zero.
    var target: ModifierConditionTarget = .deckA

    /// Display string for the condition (e.g., "M4 = 2")
    var displayString: String {
        "M\(modifier) = \(value)"
    }
}

// MARK: - Nonisolated Codable Conformance for ModifierCondition

extension ModifierCondition: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modifier = try container.decode(Int.self, forKey: .modifier)
        value = try container.decode(Int.self, forKey: .value)
        target = try container.decodeIfPresent(
            ModifierConditionTarget.self,
            forKey: .target
        ) ?? .deckA
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(modifier, forKey: .modifier)
        try container.encode(value, forKey: .value)
        try container.encode(target, forKey: .target)
    }

    private enum CodingKeys: String, CodingKey {
        case modifier, value, target
    }
}
