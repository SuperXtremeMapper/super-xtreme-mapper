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

    // MARK: - Shared State for Document Passing

    /// Temporarily holds document reference when opening wizard window.
    /// Set this before calling openWindow(id: "wizard"), then cleared after use.
    static var pendingDocument: TraktorMappingDocument?
    static var pendingDestinationDeviceID: Device.ID?

    /// Set by `ModeSelectionWindow.selectGuidedMode` to flag that the NEXT
    /// ContentView to mount should claim it, set itself as `pendingDocument`,
    /// and open the wizard. Replaces the older broadcast-notification scheme
    /// which had unreliable timing — the 0.5s delay between `newDocument()`
    /// and the notification post could miss the new ContentView's
    /// `.onReceive` subscriber, leaving the wizard with no document and
    /// the new document window with no mappings appearing on save.
    ///
    /// Main-actor isolated read/write is intentional — no atomic primitive
    /// needed because all SwiftUI view lifecycle callbacks run on the main
    /// actor, and the flag is only set before / read after a `newDocument()`
    /// call that itself runs on main.
    @MainActor static var pendingWizardForNextNewDocument: Bool = false

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

    /// The assigned shift button's MIDI identity (channel + note/CC)
    @Published var shiftMIDI: MIDIMessage?

    /// Whether the shift button is currently held
    @Published private(set) var isShiftHeld: Bool = false

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
    /// The only device this wizard session may inspect or mutate. A nil value
    /// is valid solely for a genuinely empty new document.
    private var destinationDeviceID: Device.ID?

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
        if currentTab == .sampleDecks { return setupConfig.slotAssignments }
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
            if currentTab == .sampleDecks { return count + setupConfig.slotAssignments.count }
            return count + 1
        }
        var completedSteps = 0
        for i in 0..<currentFunctionIndex {
            let fn = currentFunctions[i]
            if fn.fixedAssignment != nil { completedSteps += 1 }
            else if fn.perDeck { completedSteps += setupConfig.deckAssignments.count }
            else if currentTab == .fx { completedSteps += setupConfig.fxAssignments(isBasic: isBasicMode).count }
            else if currentTab == .sampleDecks { completedSteps += setupConfig.slotAssignments.count }
            else { completedSteps += 1 }
        }
        completedSteps += currentAssignmentIndex
        return totalSteps > 0 ? Double(completedSteps) / Double(totalSteps) : 0
    }

    /// Whether we're at the last function of the last tab
    var isAtLastStep: Bool {
        let availableTabs = WizardTab.allCases.filter {
            !$0.functions(isBasic: isBasicMode).isEmpty
        }

        // Must be on the last tab that has an audited function.
        guard currentTab == availableTabs.last else { return false }

        // Must be on last function
        guard currentFunctionIndex >= currentFunctions.count - 1 else { return false }

        // Must be on last assignment
        return currentAssignmentIndex >= currentAssignments.count - 1
    }

    func isCaptured(function: WizardFunction, assignment: TargetAssignment) -> Bool {
        capturedMappings.contains { $0.function.id == function.id && $0.assignment == assignment }
    }

    /// Check if a MIDI message matches the assigned shift button
    func isShiftButton(_ message: MIDIMessage) -> Bool {
        guard let shift = shiftMIDI else { return false }
        return message.channel == shift.channel &&
               message.note == shift.note &&
               message.cc == shift.cc
    }

    // MARK: - Initialization

    init(midiManager: MIDIInputManager? = nil) {
        self.midiManager = midiManager ?? .shared
    }

    // MARK: - Public Methods

    func start(
        document: TraktorMappingDocument,
        destinationDeviceID: Device.ID? = nil
    ) {
        self.document = document
        self.destinationDeviceID = destinationDeviceID
            ?? (document.mappingFile.devices.count == 1 ? document.mappingFile.devices[0].id : nil)
        phase = .setup
        statusMessage = "Configure your controller settings"
    }

    func beginLearning() {
        guard setupConfig.isValid else {
            statusMessage = "Please fill in all required fields"
            return
        }
        phase = .learning
        currentTab = .setup
        currentFunctionIndex = 0
        currentAssignmentIndex = 0
        capturedMappings = []
        shiftMIDI = nil
        isShiftHeld = false
        statusMessage = "Press a control on your MIDI device"
        startMIDIListening()
    }

    func handleMIDIReceived(_ message: MIDIMessage) {
        guard phase == .learning else { return }

        // Shift-button state tracking comes first: it must ALWAYS see
        // note-offs — including on the Setup tab, or a shift released there
        // would stay held forever. On Setup the message still falls through
        // so the shift button itself can be (re)assigned.
        if isShiftButton(message) {
            isShiftHeld = message.value > 0
            if currentTab != .setup {
                return  // Don't create a mapping for the shift button itself
            }
        }

        // Discard note-offs - they must never create or replace a capture.
        // CC value 0 is a valid position and falls through.
        if message.note != nil && message.value == 0 { return }

        // Special handling for Setup tab - assigning shift button
        if currentTab == .setup {
            guard let function = currentFunction, let assignment = currentAssignment else { return }

            // Store this as the shift button
            shiftMIDI = message
            isShiftHeld = false

            pendingMIDI = message
            let captured = WizardCapturedMapping(
                function: function,
                assignment: assignment,
                midiMessage: message,
                modifierCondition: nil  // Shift button itself has no modifier condition
            )
            capturedMappings.removeAll { $0.function.id == function.id && $0.assignment == assignment }
            capturedMappings.append(captured)
            statusMessage = "Shift button assigned!"

            if autoAdvanceEnabled {
                startAutoAdvance()
            }
            return
        }

        guard let function = currentFunction, let assignment = currentAssignment else { return }

        // Determine modifier condition based on shift state
        let modifier: ModifierCondition? = shiftMIDI != nil
            ? ModifierCondition(modifier: 1, value: isShiftHeld ? 1 : 0)
            : nil

        pendingMIDI = message
        let captured = WizardCapturedMapping(
            function: function,
            assignment: assignment,
            midiMessage: message,
            modifierCondition: modifier
        )
        // Remove existing mapping with same function/assignment/modifier value.
        // nil modifier and M1=0 are equivalent (both mean "unshifted").
        capturedMappings.removeAll {
            $0.function.id == function.id &&
            $0.assignment == assignment &&
            ($0.modifierCondition?.value ?? 0) == (modifier?.value ?? 0)
        }
        capturedMappings.append(captured)
        statusMessage = isShiftHeld ? "Captured! [SHIFT]" : "Captured!"

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
            // Auto-completion path: user walked through every function on
            // every tab. Pre-fix this transitioned to .complete without
            // saving — the completion view's "mappings saved" text was a
            // lie, and clicking Great! discarded everything. Now we run
            // the save explicitly (which itself sets phase=.complete via
            // performSave) so the wizard's final state matches what the
            // user expects: their captures are written to the document.
            stopMIDIListening()
            saveToDocument()
        }
    }

    func previous() {
        cancelAutoAdvance()
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
        cancelAutoAdvance()
        pendingMIDI = nil
        next()
    }

    /// Clears the mapping for the current function/assignment
    func clearCurrentMapping() {
        cancelAutoAdvance()
        guard let function = currentFunction, let assignment = currentAssignment else { return }
        capturedMappings.removeAll { $0.function.id == function.id && $0.assignment == assignment }
        pendingMIDI = nil
        statusMessage = "Cleared - press a control to re-map"
    }

    func switchToTab(_ tab: WizardTab) {
        cancelAutoAdvance()
        currentTab = tab
        currentFunctionIndex = 0
        currentAssignmentIndex = 0
        pendingMIDI = nil
        statusMessage = "Press a control for \(currentStepDisplay)"
    }

    func saveToDocument() {
        // Cancel before the conflict early-return below: a pending advance
        // must not fire while the overwrite alert is open.
        cancelAutoAdvance()
        guard let document = document else {
            statusMessage = "Error: No document open. Please close this wizard and reopen from a document."
            return
        }
        let newEntries = capturedMappings.map { $0.toMappingEntry() }
        let targetMappings: [MappingEntry]
        if let destinationDeviceID,
           let device = document.mappingFile.devices.first(where: { $0.id == destinationDeviceID }) {
            targetMappings = device.mappings
        } else if MappingTransferService.isTrulyEmpty(document.mappingFile) {
            targetMappings = []
        } else {
            statusMessage = "Cannot save: choose a valid destination device and reopen the wizard."
            return
        }

        let existing = Set(targetMappings.compactMap(SemanticBindingKey.init(entry:)))
        let newKeys = Set(newEntries.compactMap(SemanticBindingKey.init(entry:)))
        let conflicts = existing.intersection(newKeys)
        if !conflicts.isEmpty {
            // Human-readable list for the overwrite alert. Dedupe by display name
            // (a single Hotcue command covers all deck/slot variants in the
            // user-visible alert) so the alert isn't a wall of repeated names.
            conflictingCommands = Array(Set(conflicts.map {
                TraktorCommands.name(for: $0.commandID)
            })).sorted()
            showOverwriteAlert = true
            return
        }
        performSave(overwrite: false)
    }

    func performSave(overwrite: Bool) {
        cancelAutoAdvance()
        guard let document = document else {
            WizardTrace.write(" performSave: NO DOCUMENT attached — wizard save will be silently lost")
            return
        }
        let newMappings = capturedMappings.map { $0.toMappingEntry() }
        let keysToReplace = Set(newMappings.compactMap(SemanticBindingKey.init(entry:)))

        do {
            _ = try document.performUndoableMutation(
                actionName: "Save Wizard Mappings",
                undoManager: document.backingDocument?.undoManager
            ) { file in
                let destinationIndex: Int
                if let destinationDeviceID {
                    guard let index = file.devices.firstIndex(where: { $0.id == destinationDeviceID }) else {
                        throw MappingTransferError.destinationUnavailable
                    }
                    destinationIndex = index
                } else if MappingTransferService.isTrulyEmpty(file) {
                    file.devices.append(Device(name: "Generic MIDI"))
                    destinationIndex = file.devices.startIndex
                } else {
                    throw MappingTransferError.destinationRequired
                }

                if overwrite {
                    file.devices[destinationIndex].mappings.removeAll { mapping in
                        guard let key = SemanticBindingKey(entry: mapping) else { return false }
                        return keysToReplace.contains(key)
                    }
                }
                file.devices[destinationIndex].mappings.append(contentsOf: newMappings)
                file.devices[destinationIndex].comment = setupConfig.controllerName
                file.devices[destinationIndex].inPort = setupConfig.inputPort
                file.devices[destinationIndex].outPort = setupConfig.outputPort

                _ = try TSIWriter().writeConverted(file)
            }
        } catch {
            statusMessage = "Cannot save wizard mappings: \(error.localizedDescription)"
            return
        }

        statusMessage = "Saved \(newMappings.count) mappings!"
        phase = .complete
        stopMIDIListening()
    }

    func cancel() {
        cancelAutoAdvance()
        stopMIDIListening()
        // A window-close after a completed save also lands here (onDisappear).
        // The save is already in the document; keep the completed state so
        // cancel() never masquerades as a reset of a finished session.
        if phase != .complete {
            phase = .setup
            capturedMappings = []
            pendingMIDI = nil
        }
        shouldDismiss = true  // Signal window to close
    }

    func reset() {
        cancelAutoAdvance()
        phase = .setup
        setupConfig = WizardSetupConfig()
        currentTab = .mixer
        currentFunctionIndex = 0
        currentAssignmentIndex = 0
        capturedMappings = []
        pendingMIDI = nil
        shiftMIDI = nil
        isShiftHeld = false
        isBasicMode = true
        statusMessage = "Configure your controller settings"
    }

    /// A MIDI setup change (device connected/disconnected) means any held
    /// shift release may never arrive - force-release to avoid a stuck shift.
    func handleMIDISetupChanged() {
        isShiftHeld = false
    }

    // MARK: - Private Methods

    private func startMIDIListening() {
        midiManager.onMIDIReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleMIDIReceived(message)
            }
        }
        midiManager.onSetupChanged = { [weak self] in
            self?.handleMIDISetupChanged()
        }
        midiManager.startListening()
        isListening = true
    }

    private func stopMIDIListening() {
        midiManager.stopListening()
        midiManager.onMIDIReceived = nil
        midiManager.onSetupChanged = nil
        isListening = false
    }

    private func nextTab() -> WizardTab? {
        let allTabs = WizardTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab),
              currentIndex < allTabs.count - 1 else { return nil }
        return allTabs[(currentIndex + 1)...].first {
            !$0.functions(isBasic: isBasicMode).isEmpty
        }
    }

    private func previousTab() -> WizardTab? {
        let allTabs = WizardTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: currentTab), currentIndex > 0 else { return nil }
        return allTabs[..<currentIndex].reversed().first {
            !$0.functions(isBasic: isBasicMode).isEmpty
        }
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
                fireAutoAdvance()
            }
        }
    }

    /// Fires a pending auto-advance. Belt-and-braces phase guard: a stray
    /// task must never mutate a wizard that has left the learning phase
    /// (saved, cancelled, or completed).
    func fireAutoAdvance() {
        autoAdvanceCountdown = 0
        guard phase == .learning else { return }
        next()
    }

    func cancelAutoAdvance() {
        autoAdvanceTask?.cancel()
        autoAdvanceCountdown = 0
    }
}
