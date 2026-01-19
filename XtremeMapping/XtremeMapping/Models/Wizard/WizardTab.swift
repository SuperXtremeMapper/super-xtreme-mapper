//
//  WizardTab.swift
//  XtremeMapping
//

import Foundation

/// Wizard tab sections with their associated functions
enum WizardTab: String, CaseIterable, Identifiable {
    case mixer = "Mixer"
    case decks = "Decks"
    case cueLoop = "Cue/Loop"
    case eqFilter = "EQ/Filter"
    case fx = "FX"
    case sampleDecks = "Sample Decks"
    case loopRecorder = "Loop Recorder"
    case browser = "Browser"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mixer: return "slider.horizontal.3"
        case .decks: return "play.circle"
        case .cueLoop: return "arrow.triangle.2.circlepath"
        case .eqFilter: return "dial.low"
        case .fx: return "wand.and.stars"
        case .sampleDecks: return "square.grid.2x2"
        case .loopRecorder: return "record.circle"
        case .browser: return "list.bullet"
        }
    }

    /// All functions for this tab
    var functions: [WizardFunction] {
        switch self {
        case .mixer: return Self.mixerFunctions
        case .decks: return Self.decksFunctions
        case .cueLoop: return Self.cueLoopFunctions
        case .eqFilter: return Self.eqFilterFunctions
        case .fx: return Self.fxFunctions
        case .sampleDecks: return Self.sampleDecksFunctions
        case .loopRecorder: return Self.loopRecorderFunctions
        case .browser: return Self.browserFunctions
        }
    }

    /// Filtered functions based on Basic/Advanced mode
    func functions(isBasic: Bool) -> [WizardFunction] {
        if isBasic {
            return functions.filter { $0.isBasic }
        }
        return functions
    }

    // MARK: - Mixer Functions
    private static let mixerFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Master Volume", commandName: "Master Volume", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Crossfader", commandName: "X-Fader Position", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Monitor Volume", commandName: "Monitor Volume", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Monitor Mix", commandName: "Monitor Mix", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: false, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Crossfader Curve", commandName: "Crossfader Curve", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: false, perDeck: false, fixedAssignment: .global),
    ]

    // MARK: - Decks Functions
    private static let decksFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Play/Pause", commandName: "Play/Pause", controllerType: .button, interactionMode: .toggle, isBasic: true),
        WizardFunction(displayName: "Volume", commandName: "Volume", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "Cue", commandName: "Cue", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Sync", commandName: "Sync On", controllerType: .button, interactionMode: .toggle, isBasic: true),
        WizardFunction(displayName: "Tempo", commandName: "Tempo Adjust", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "Tempo Bend +", commandName: "Tempo Bend Up", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Tempo Bend -", commandName: "Tempo Bend Down", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Jog Turn", commandName: "Jog Turn", controllerType: .encoder, interactionMode: .relative, isBasic: true),
        WizardFunction(displayName: "Jog Scratch", commandName: "Jog Scratch", controllerType: .encoder, interactionMode: .relative, isBasic: false),
        WizardFunction(displayName: "Monitor Cue", commandName: "Monitor Cue On", controllerType: .button, interactionMode: .toggle, isBasic: true),
        WizardFunction(displayName: "Gain", commandName: "Mixer Gain", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: false),
        WizardFunction(displayName: "Load", commandName: "Load Selected", controllerType: .button, interactionMode: .trigger, isBasic: false),
    ]

    // MARK: - Cue/Loop Functions
    private static let cueLoopFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Hotcue 1", commandName: "Hotcue 1", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Hotcue 2", commandName: "Hotcue 2", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Hotcue 3", commandName: "Hotcue 3", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Hotcue 4", commandName: "Hotcue 4", controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Hotcue 5", commandName: "Hotcue 5", controllerType: .button, interactionMode: .hold, isBasic: false),
        WizardFunction(displayName: "Hotcue 6", commandName: "Hotcue 6", controllerType: .button, interactionMode: .hold, isBasic: false),
        WizardFunction(displayName: "Hotcue 7", commandName: "Hotcue 7", controllerType: .button, interactionMode: .hold, isBasic: false),
        WizardFunction(displayName: "Hotcue 8", commandName: "Hotcue 8", controllerType: .button, interactionMode: .hold, isBasic: false),
        WizardFunction(displayName: "Loop In", commandName: "Loop In", controllerType: .button, interactionMode: .trigger, isBasic: true),
        WizardFunction(displayName: "Loop Out", commandName: "Loop Out", controllerType: .button, interactionMode: .trigger, isBasic: true),
        WizardFunction(displayName: "Loop Active", commandName: "Loop Active On", controllerType: .button, interactionMode: .toggle, isBasic: true),
        WizardFunction(displayName: "Loop Size", commandName: "Loop Size", controllerType: .encoder, interactionMode: .relative, isBasic: true),
        WizardFunction(displayName: "Reloop", commandName: "Reloop", controllerType: .button, interactionMode: .trigger, isBasic: false),
    ]

    // MARK: - EQ/Filter Functions
    private static let eqFilterFunctions: [WizardFunction] = [
        WizardFunction(displayName: "EQ Low", commandName: "EQ Low", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "EQ Mid", commandName: "EQ Mid", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "EQ High", commandName: "EQ High", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "Filter", commandName: "Filter", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "Filter On", commandName: "Filter On", controllerType: .button, interactionMode: .toggle, isBasic: false),
        WizardFunction(displayName: "EQ Low Kill", commandName: "EQ Low Kill", controllerType: .button, interactionMode: .hold, isBasic: false),
        WizardFunction(displayName: "EQ Mid Kill", commandName: "EQ Mid Kill", controllerType: .button, interactionMode: .hold, isBasic: false),
        WizardFunction(displayName: "EQ High Kill", commandName: "EQ High Kill", controllerType: .button, interactionMode: .hold, isBasic: false),
    ]

    // MARK: - FX Functions
    private static let fxFunctions: [WizardFunction] = [
        WizardFunction(displayName: "FX Dry/Wet", commandName: "FX Dry/Wet", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "FX Knob 1", commandName: "FX Knob 1", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "FX Knob 2", commandName: "FX Knob 2", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "FX Knob 3", commandName: "FX Knob 3", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "FX Unit On", commandName: "FX Unit On", controllerType: .button, interactionMode: .toggle, isBasic: true, perDeck: false),
        WizardFunction(displayName: "FX Button 1", commandName: "FX Button 1", controllerType: .button, interactionMode: .toggle, isBasic: false, perDeck: false),
        WizardFunction(displayName: "FX Button 2", commandName: "FX Button 2", controllerType: .button, interactionMode: .toggle, isBasic: false, perDeck: false),
        WizardFunction(displayName: "FX Button 3", commandName: "FX Button 3", controllerType: .button, interactionMode: .toggle, isBasic: false, perDeck: false),
    ]

    // MARK: - Sample Decks Functions
    private static let sampleDecksFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Slot Volume", commandName: "Slot Volume", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "Slot Trigger", commandName: "Slot Trigger", controllerType: .button, interactionMode: .trigger, isBasic: true, perDeck: false),
        WizardFunction(displayName: "Slot Filter", commandName: "Slot Filter Adjust", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: false, perDeck: false),
        WizardFunction(displayName: "Slot Mute", commandName: "Slot Mute On", controllerType: .button, interactionMode: .toggle, isBasic: false, perDeck: false),
    ]

    // MARK: - Loop Recorder Functions
    private static let loopRecorderFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Record", commandName: "Loop Recorder Record", controllerType: .button, interactionMode: .toggle, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Dry/Wet", commandName: "Loop Recorder Dry/Wet", controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Delete", commandName: "Loop Recorder Delete", controllerType: .button, interactionMode: .trigger, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Play/Pause", commandName: "Loop Recorder Play/Pause", controllerType: .button, interactionMode: .toggle, isBasic: false, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Size", commandName: "Loop Recorder Size", controllerType: .encoder, interactionMode: .relative, isBasic: false, perDeck: false, fixedAssignment: .global),
    ]

    // MARK: - Browser Functions
    private static let browserFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Select Up/Down", commandName: "Browser Select Up/Down", controllerType: .encoder, interactionMode: .relative, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Load Selected", commandName: "Browser Open", controllerType: .button, interactionMode: .trigger, isBasic: true, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Tree Navigate", commandName: "Browser Tree Select Up/Down", controllerType: .encoder, interactionMode: .relative, isBasic: false, perDeck: false, fixedAssignment: .global),
        WizardFunction(displayName: "Tree Expand/Collapse", commandName: "Browser Tree Expand/Collapse", controllerType: .button, interactionMode: .trigger, isBasic: false, perDeck: false, fixedAssignment: .global),
    ]
}
