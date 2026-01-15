//
//  MappingEntry.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Represents a single MIDI mapping in a TSI file.
///
/// A mapping entry connects a MIDI control (note or CC) to a Traktor command,
/// with optional modifier conditions and assignment targets.
struct MappingEntry: Identifiable, Codable, Hashable, Sendable, Equatable {
    /// Unique identifier for this mapping entry
    let id: UUID

    /// The name of the Traktor command being mapped
    var commandName: String

    /// Whether this is an input (controller to Traktor) or output (Traktor to controller)
    var ioType: IODirection

    /// The target deck, FX unit, or global assignment
    var assignment: TargetAssignment

    /// How the control interacts with the command (toggle, hold, direct, etc.)
    var interactionMode: InteractionMode

    /// MIDI channel (1-16)
    var midiChannel: Int

    /// MIDI note number (0-127), nil if using CC
    var midiNote: Int?

    /// MIDI CC number (0-127), nil if using Note
    var midiCC: Int?

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

    /// Whether this mapping has a MIDI note or CC assigned
    var hasMIDIAssignment: Bool {
        midiNote != nil || midiCC != nil
    }

    /// Display string showing the MIDI assignment (e.g., "Ch01 CC 008" or "Ch02 Note C4")
    var mappedToDisplay: String {
        let channelStr = String(format: "Ch%02d", midiChannel)

        if let note = midiNote {
            return "\(channelStr) Note \(midiNoteToName(note))"
        } else if let cc = midiCC {
            return "\(channelStr) CC \(String(format: "%03d", cc))"
        } else {
            return "\(channelStr) --"
        }
    }

    /// Converts a MIDI note number (0-127) to a note name with octave.
    ///
    /// Uses the standard MIDI convention where middle C (note 60) is C4.
    /// - Parameter note: MIDI note number (0-127)
    /// - Returns: Note name string (e.g., "C4", "D#5", "G9")
    private func midiNoteToName(_ note: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteName = noteNames[note % 12]
        let octave = (note / 12) - 1  // MIDI note 0 = C-1, note 60 = C4
        return "\(noteName)\(octave)"
    }

    /// Creates a new mapping entry with the specified properties.
    ///
    /// All parameters have sensible defaults for creating empty mappings.
    init(
        id: UUID = UUID(),
        commandName: String = "",
        ioType: IODirection = .input,
        assignment: TargetAssignment = .none,
        interactionMode: InteractionMode = .none,
        midiChannel: Int = 1,
        midiNote: Int? = nil,
        midiCC: Int? = nil,
        modifier1Condition: ModifierCondition? = nil,
        modifier2Condition: ModifierCondition? = nil,
        comment: String = "",
        controllerType: ControllerType = .none,
        invert: Bool = false,
        softTakeover: Bool = false,
        setToValue: Float = 0.0,
        rotarySensitivity: Float = 1.0,
        rotaryAcceleration: Float = 0.0,
        encoderMode: EncoderMode = .mode7Fh01h
    ) {
        self.id = id
        self.commandName = commandName
        self.ioType = ioType
        self.assignment = assignment
        self.interactionMode = interactionMode
        self.midiChannel = midiChannel
        self.midiNote = midiNote
        self.midiCC = midiCC
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
    }
}

/// A modifier condition that must be met for a mapping to be active.
///
/// Traktor supports 8 modifiers (M1-M8), each with values 0-7.
/// A mapping can require specific modifier values to be active.
struct ModifierCondition: Codable, Hashable, Sendable, Equatable {
    /// The modifier number (1-8 for M1-M8)
    var modifier: Int

    /// The required value (0-7)
    var value: Int

    /// Display string for the condition (e.g., "M4 = 2")
    var displayString: String {
        "M\(modifier) = \(value)"
    }
}
