//
//  WizardCoordinator.swift
//  XtremeMapping
//
//  Coordinates the mapping wizard workflow: setup → MIDI learning → save.
//

import Foundation
import Combine
import AppKit

/// Phases of the wizard workflow
enum WizardPhase {
    case setup
    case learning
    case complete
}

/// Coordinates the mapping wizard workflow.
@MainActor
final class WizardCoordinator: ObservableObject {

    // MARK: - Published State

    @Published private(set) var phase: WizardPhase = .setup
    @Published var setupConfig = WizardSetupConfig()
    @Published var currentTab: WizardTab = .mixer
    @Published var isBasicMode: Bool = true
    @Published private(set) var currentFunctionIndex: Int = 0
    @Published private(set) var currentAssignmentIndex: Int = 0
    @Published private(set) var capturedMappings: [WizardCapturedMapping] = []
    @Published private(set) var pendingMIDI: MIDIMessage?
    @Published var statusMessage: String = ""
    @Published private(set) var isListening: Bool = false
    @Published var showOverwriteAlert: Bool = false
    @Published var conflictingCommands: [String] = []
    /// Set to true when wizard should close
    @Published var shouldDismiss = false

    /// Whether to auto-advance after MIDI capture
    @Published var autoAdvanceEnabled = true

    /// Countdown before auto-advance (for UI animation)
    @Published private(set) var autoAdvanceCountdown: Double = 0

    /// Timer for auto-advance
    private var autoAdvanceTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let midiManager: MIDIInputManager
    /// Strong reference required to prevent document from being released during wizard session.
    /// No retain cycle risk: TraktorMappingDocument does not reference WizardCoordinator.
    private var document: TraktorMappingDocument?

    // MARK: - Computed Properties

    var currentFunctions: [WizardFunction] {
        currentTab.functions(isBasic: isBasicMode)
    }

    var currentFunction: WizardFunction? {
        guard currentFunctionIndex < currentFunctions.count else { return nil }
        return currentFunctions[currentFunctionIndex]
    }

    var currentAssignments: [TargetAssignment] {
        guard let function = currentFunction else { return [] }
        if let fixed = function.fixedAssignment { return [fixed] }
        if function.perDeck { return setupConfig.deckAssignments }
        if currentTab == .fx { return setupConfig.fxAssignments(isBasic: isBasicMode) }
        if currentTab == .sampleDecks { return [.deckA, .deckB, .deckC, .deckD] }
        return [.global]
    }

    var currentAssignment: TargetAssignment? {
        guard currentAssignmentIndex < currentAssignments.count else { return nil }
        return currentAssignments[currentAssignmentIndex]
    }

    var currentStepDisplay: String {
        guard let function = currentFunction, let assignment = currentAssignment else { return "Complete" }
        if currentAssignments.count == 1 { return function.displayName }
        return "\(function.displayName) (\(assignment.displayName))"
    }

    var tabProgress: Double {
        let totalSteps = currentFunctions.reduce(0) { count, fn in
            if fn.fixedAssignment != nil { return count + 1 }
            if fn.perDeck { return count + setupConfig.deckAssignments.count }
            if currentTab == .fx { return count + setupConfig.fxAssignments(isBasic: isBasicMode).count }
            if currentTab == .sampleDecks { return count + 4 }
            return count + 1
        }
        var completedSteps = 0
        for i in 0..<currentFunctionIndex {
            let fn = currentFunctions[i]
            if fn.fixedAssignment != nil { completedSteps += 1 }
            else if fn.perDeck { completedSteps += setupConfig.deckAssignments.count }
            else if currentTab == .fx { completedSteps += setupConfig.fxAssignments(isBasic: isBasicMode).count }
            else if currentTab == .sampleDecks { completedSteps += 4 }
            else { completedSteps += 1 }
        }
        completedSteps += currentAssignmentIndex
        return totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
    }

    /// Whether we're at the last function of the last tab
    var isAtLastStep: Bool {
        let allTabs = WizardTab.allCases
        guard let currentTabIndex = allTabs.firstIndex(of: currentTab) else { return false }

        // Must be on last tab
        guard currentTabIndex == allTabs.count - 1 else { return false }

        // Must be on last function
        guard currentFunctionIndex >= currentFunctions.count - 1 else { return false }

        // Must be on last assignment
        return currentAssignmentIndex >= currentAssignments.count - 1
    }

    func isCaptured(function: WizardFunction, assignment: TargetAssignment) -> Bool {
        capturedMappings.contains { $0.function.id == function.id && $0.assignment == assignment }
    }

    // MARK: - Initialization

    init(midiManager: MIDIInputManager = .shared) {
        self.midiManager = midiManager
    }

    // MARK: - Public Methods

    func start(document: TraktorMappingDocument) {
        self.document = document
        phase = .setup
        statusMessage = "Configure your controller settings"
    }

    func beginLearning() {
        guard setupConfig.isValid else {
            statusMessage = "Please fill in all required fields"
            return
        }
        phase = .learning
        currentTab = .mixer
        currentFunctionIndex = 0
        currentAssignmentIndex = 0
        capturedMappings = []
        statusMessage = "Press a control on your MIDI device"
        startMIDIListening()
    }

    func handleMIDIReceived(_ message: MIDIMessage) {
        guard phase == .learning, let function = currentFunction, let assignment = currentAssignment else { return }
        pendingMIDI = message
        let captured = WizardCapturedMapping(function: function, assignment: assignment, midiMessage: message)
        capturedMappings.removeAll { $0.function.id == function.id && $0.assignment == assignment }
        capturedMappings.append(captured)
        statusMessage = "Captured!"

        // Auto-advance if enabled
        if autoAdvanceEnabled {
            startAutoAdvance()
        }
    }

    func next() {
        pendingMIDI = nil
        if currentAssignmentIndex < currentAssignments.count - 1 {
            currentAssignmentIndex += 1
            statusMessage = "Press a control for \(currentStepDisplay)"
            return
        }
        if currentFunctionIndex < currentFunctions.count - 1 {
            currentFunctionIndex += 1
            currentAssignmentIndex = 0
            statusMessage = "Press a control for \(currentStepDisplay)"
            return
        }
        if let nextTab = nextTab() {
            switchToTab(nextTab)
            statusMessage = "Press a control for \(currentStepDisplay)"
        } else {
            phase = .complete
            stopMIDIListening()
            statusMessage = "All functions mapped! Click Save & Finish."
        }
    }

    func previous() {
        pendingMIDI = nil
        if currentAssignmentIndex > 0 {
            currentAssignmentIndex -= 1
            statusMessage = "Press a control for \(currentStepDisplay)"
            return
        }
        if currentFunctionIndex > 0 {
            currentFunctionIndex -= 1
            currentAssignmentIndex = currentAssignments.count - 1
            statusMessage = "Press a control for \(currentStepDisplay)"
            return
        }
        if let prevTab = previousTab() {
            switchToTab(prevTab)
            currentFunctionIndex = currentFunctions.count - 1
            currentAssignmentIndex = currentAssignments.count - 1
            statusMessage = "Press a control for \(currentStepDisplay)"
        }
    }

    func skip() {
        pendingMIDI = nil
        next()
    }

    func switchToTab(_ tab: WizardTab) {
        currentTab = tab
        currentFunctionIndex = 0
        currentAssignmentIndex = 0
        pendingMIDI = nil
        statusMessage = "Press a control for \(currentStepDisplay)"
    }

    func saveToDocument() {
        // Try to recover document reference if lost
        if document == nil {
            if let doc = NSDocumentController.shared.documents.first as? TraktorMappingDocument {
                self.document = doc
            }
        }

        guard let document = document else {
            statusMessage = "Error: No document reference. Please save your work and reopen the wizard."
            return
        }
        let existingCommands = Set(document.mappingFile.allMappings.map { $0.commandName })
        let newCommands = Set(capturedMappings.map { $0.function.commandName })
        let conflicts = existingCommands.intersection(newCommands)
        if !conflicts.isEmpty {
            conflictingCommands = Array(conflicts).sorted()
            showOverwriteAlert = true
            return
        }
        performSave(overwrite: false)
    }

    func performSave(overwrite: Bool) {
        guard let document = document else { return }
        let newMappings = capturedMappings.map { $0.toMappingEntry(channel: 1) }
        if overwrite {
            let commandsToReplace = Set(capturedMappings.map { $0.function.commandName })
            if !document.mappingFile.devices.isEmpty {
                document.mappingFile.devices[0].mappings.removeAll { commandsToReplace.contains($0.commandName) }
            }
        }
        if document.mappingFile.devices.isEmpty {
            let newDevice = Device(
                name: setupConfig.controllerName,
                comment: "Created by Mapping Wizard",
                inPort: setupConfig.inputPort,
                outPort: setupConfig.outputPort,
                mappings: newMappings
            )
            document.mappingFile.devices.append(newDevice)
        } else {
            document.mappingFile.devices[0].mappings.append(contentsOf: newMappings)
            document.mappingFile.devices[0].name = setupConfig.controllerName
            document.mappingFile.devices[0].inPort = setupConfig.inputPort
            document.mappingFile.devices[0].outPort = setupConfig.outputPort
        }
        document.noteChange()
        statusMessage = "Saved \(newMappings.count) mappings!"
        phase = .complete
    }

    func cancel() {
        stopMIDIListening()
        phase = .setup
        capturedMappings = []
        pendingMIDI = nil
        shouldDismiss = true  // Signal window to close
    }

    func reset() {
        phase = .setup
        setupConfig = WizardSetupConfig()
        currentTab = .mixer
        currentFunctionIndex = 0
        currentAssignmentIndex = 0
        capturedMappings = []
        pendingMIDI = nil
        isBasicMode = true
        statusMessage = "Configure your controller settings"
    }

    // MARK: - Private Methods

    private func startMIDIListening() {
        midiManager.onMIDIReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleMIDIReceived(message)
            }
        }
        midiManager.startListening()
        isListening = true
    }

    private func stopMIDIListening() {
        midiManager.stopListening()
        midiManager.onMIDIReceived = nil
        isListening = false
    }

    private func nextTab() -> WizardTab? {
        let allTabs = WizardTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab), currentIndex < allTabs.count - 1 else { return nil }
        return allTabs[currentIndex + 1]
    }

    private func previousTab() -> WizardTab? {
        let allTabs = WizardTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab), currentIndex > 0 else { return nil }
        return allTabs[currentIndex - 1]
    }

    private func startAutoAdvance() {
        // Cancel any existing auto-advance
        autoAdvanceTask?.cancel()

        // Start countdown
        autoAdvanceCountdown = 1.0

        autoAdvanceTask = Task { @MainActor in
            // Animate countdown
            for _ in 0..<10 {
                try? await Task.sleep(nanoseconds: 70_000_000) // 0.07 seconds (30% faster)
                if Task.isCancelled { return }
                autoAdvanceCountdown -= 0.1
            }

            // Auto-advance
            if !Task.isCancelled {
                autoAdvanceCountdown = 0
                next()
            }
        }
    }

    func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceCountdown = 0
    }
}
