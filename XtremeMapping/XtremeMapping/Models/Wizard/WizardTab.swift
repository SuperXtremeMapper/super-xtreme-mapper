//
//  WizardTab.swift
//  XtremeMapping
//

import Foundation

/// Wizard tab sections with their associated functions
enum WizardTab: String, CaseIterable, Identifiable {
    case setup = "Setup"
    case mixer = "Mixer"
    case decks = "Decks"
    case cueLoop = "Cue/Loop"
    case eqFilter = "EQ/Filter"
    case fx = "FX"
    case sampleDecks = "Stems / Remix Decks"
    case loopRecorder = "Loop Recorder"
    case browser = "Browser"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .setup: return "gearshape"
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
        case .setup: return Self.setupFunctions
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

    // MARK: - Setup Functions
    private static let setupFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Shift Button", commandID: 2548, controllerType: .button, interactionMode: .hold, isBasic: true, perDeck: false, fixedAssignment: .global),
    ]

    // MARK: - Mixer Functions
    private static let mixerFunctions: [WizardFunction] = []

    // MARK: - Decks Functions
    private static let decksFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Cue", commandID: 206, controllerType: .button, interactionMode: .hold, isBasic: true),
        WizardFunction(displayName: "Sync", commandID: 125, controllerType: .button, interactionMode: .toggle, isBasic: true),
        WizardFunction(displayName: "Tempo", commandID: 123, controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true),
        WizardFunction(displayName: "Jog Turn", commandID: 120, controllerType: .encoder, interactionMode: .relative, isBasic: true),
        WizardFunction(displayName: "Monitor Cue", commandID: 119, controllerType: .button, interactionMode: .toggle, isBasic: true),
    ]

    // MARK: - Cue/Loop Functions
    private static let cueLoopFunctions: [WizardFunction] = [
        // Hotcues 1-8 use canonical Traktor 4.4 id 2328 ("Select/Set+Store Hotcue")
        // with setToValue selecting the hotcue index (0-based). The legacy
        // per-cue ids 214-221 don't exist in Traktor 4.4.
        WizardFunction(displayName: "Hotcue 1", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 0),
        WizardFunction(displayName: "Hotcue 2", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 1),
        WizardFunction(displayName: "Hotcue 3", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 2),
        WizardFunction(displayName: "Hotcue 4", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 3),
        WizardFunction(displayName: "Hotcue 5", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 4),
        WizardFunction(displayName: "Hotcue 6", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 5),
        WizardFunction(displayName: "Hotcue 7", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 6),
        WizardFunction(displayName: "Hotcue 8", commandID: 2328, controllerType: .button, interactionMode: .hold, isBasic: true, setToValue: 7),
    ]

    // MARK: - EQ/Filter Functions
    private static let eqFilterFunctions: [WizardFunction] = []

    // MARK: - FX Functions
    private static let fxFunctions: [WizardFunction] = []

    // MARK: - Sample Decks Functions
    //
    // Each function row is unnumbered: the wizard expands it across the
    // selected channel count as Deck A/B/C/D Slot 1-4. Traktor encodes remix
    // slot command targets as deckIndex * 4 + slotIndex on one canonical
    // commandId.
    //
    // `perDeck: false` is REQUIRED on every row. `WizardFunction.perDeck`
    // defaults to true, and `currentAssignments` returns deck assignments
    // ([.deckA..D]) for any perDeck function — so without this flag the
    // wizard would emit plain deck assignments instead of deck+slot assignments
    // and the canonical commandId would point at the wrong target.
    //
    // FX Amount (Submix) remains intentionally absent: the real 4.5.1 fixture
    // proves that it is an input command, but not that its target field uses
    // the same full Deck A-D / Part 1-4 encoding as these canonical commands.
    private static let sampleDecksFunctions: [WizardFunction] = [
        WizardFunction(displayName: "Volume", commandID: 251, controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "Filter", commandID: 249, controllerType: .faderOrKnob, interactionMode: .direct, isBasic: true, perDeck: false),
        WizardFunction(displayName: "Filter On", commandID: 250, controllerType: .button, interactionMode: .toggle, isBasic: true, perDeck: false),
        WizardFunction(displayName: "FX On", commandID: 239, controllerType: .button, interactionMode: .toggle, isBasic: true, perDeck: false),
        WizardFunction(displayName: "Mute", commandID: 259, controllerType: .button, interactionMode: .toggle, isBasic: true, perDeck: false),
    ]

    // MARK: - Loop Recorder Functions
    private static let loopRecorderFunctions: [WizardFunction] = []

    // MARK: - Browser Functions
    private static let browserFunctions: [WizardFunction] = []
}
