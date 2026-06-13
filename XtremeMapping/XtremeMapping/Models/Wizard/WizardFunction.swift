//
//  WizardFunction.swift
//  XtremeMapping
//

import Foundation

/// Represents a single function to be mapped in the wizard.
struct WizardFunction: Identifiable {
    let id = UUID()

    /// Display name shown to user (e.g., "Volume", "Play/Pause")
    let displayName: String

    /// The Traktor command name (must match TraktorCommands)
    let commandName: String

    /// Physical controller type
    let controllerType: ControllerType

    /// How the control interacts
    let interactionMode: InteractionMode

    /// Whether this appears in Basic mode (vs Advanced only)
    let isBasic: Bool

    /// Whether this function applies per-deck (Volume) or globally (Master Volume)
    let perDeck: Bool

    /// For non-perDeck functions, the fixed assignment
    let fixedAssignment: TargetAssignment?

    /// Optional fixed SetToValue (e.g., hotcue index for "Select/Set+Store Hotcue" id 2328).
    /// nil means the writer uses the MappingEntry default (0.0).
    let setToValue: Float?

    init(
        displayName: String,
        commandName: String,
        controllerType: ControllerType,
        interactionMode: InteractionMode,
        isBasic: Bool = true,
        perDeck: Bool = true,
        fixedAssignment: TargetAssignment? = nil,
        setToValue: Float? = nil
    ) {
        self.displayName = displayName
        self.commandName = commandName
        self.controllerType = controllerType
        self.interactionMode = interactionMode
        self.isBasic = isBasic
        self.perDeck = perDeck
        self.fixedAssignment = fixedAssignment
        self.setToValue = setToValue
    }
}

/// A captured MIDI mapping for a function+deck combination
struct WizardCapturedMapping: Identifiable {
    let id = UUID()
    let function: WizardFunction
    let assignment: TargetAssignment
    let midiMessage: MIDIMessage
    let modifierCondition: ModifierCondition?

    /// Generate the MappingEntry for saving. The MIDI channel comes from
    /// the captured message itself.
    func toMappingEntry() -> MappingEntry {
        MappingEntry(
            commandName: function.commandName,
            ioType: .input,
            assignment: assignment,
            interactionMode: function.interactionMode,
            midiChannel: midiMessage.channel,
            midiNote: midiMessage.note,
            midiCC: midiMessage.cc,
            modifier1Condition: modifierCondition,
            controllerType: function.controllerType,
            setToValue: function.setToValue ?? 0
        )
    }
}
