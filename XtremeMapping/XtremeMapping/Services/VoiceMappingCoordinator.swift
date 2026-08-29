//
//  VoiceMappingCoordinator.swift
//  XtremeMapping
//
//  Orchestrates MIDI input, voice input, and Claude API to create mappings.
//

import Foundation
import Combine
import AppKit

/// Coordinates the voice mapping workflow: MIDI capture + voice command + AI interpretation.
///
/// This class manages the full flow of:
/// 1. Listening for MIDI input from the user's controller
/// 2. Listening for voice commands describing the desired Traktor function
/// 3. Sending the voice transcript to Claude API for interpretation
/// 4. Either creating a mapping directly (high confidence) or showing disambiguation options
///
/// Usage:
/// ```swift
/// let coordinator = VoiceMappingCoordinator(
///     midiManager: midiManager,
///     voiceManager: voiceManager,
///     claudeService: claudeService
/// )
/// coordinator.activate()
/// ```
@MainActor
final class VoiceMappingCoordinator: ObservableObject {

    // MARK: - Published State

    /// Whether the coordinator is actively listening for MIDI and voice input
    @Published private(set) var isActive = false

    /// The most recently received MIDI message, waiting for a voice command
    @Published private(set) var pendingMIDI: MIDIMessage?

    /// The most recently transcribed voice command, waiting for MIDI
    @Published private(set) var pendingVoice: String?

    /// Options shown when Claude's confidence is below threshold
    @Published private(set) var disambiguationOptions: [CommandAlternative]?

    /// Whether we're currently processing a mapping request
    @Published private(set) var isProcessing = false

    /// Human-readable status message for UI display
    @Published var statusMessage: String = ""

    /// The interpreted command result (available after voice processing).
    /// Setter is internal so tests can seed state; production code sets it
    /// only inside this class.
    @Published var currentResult: VoiceCommandResult?

    /// Show overwrite confirmation alert
    @Published var showOverwriteAlert = false

    /// Commands that conflict with existing mappings
    @Published var conflictingCommands: [String] = []

    /// Reference to current document for saving
    private weak var document: TraktorMappingDocument?
    private var destinationDeviceID: Device.ID?

    /// Complete entries accumulated in memory. The document is untouched until
    /// Finish commits this array as one validated Undo transaction.
    @Published private(set) var stagedMappings: [MappingEntry] = []

    /// Finish is unavailable while any visible/in-flight row has not yet been
    /// explicitly added to the session.
    var canFinishSession: Bool {
        !stagedMappings.isEmpty && !hasUnstagedMapping
    }

    // MARK: - Dependencies

    private let midiManager: MIDIInputManager
    private let voiceManager: VoiceInputManager
    private let claudeService: CommandInterpreting

    /// Owns activation/restart work so session teardown can invalidate it.
    private var voiceListeningTask: Task<Void, Never>?
    /// Invalidates every continuation belonging to an earlier session.
    private var lifecycleGeneration: UInt = 0

    // MARK: - Private State

    /// Stored pending result for disambiguation flow
    private var pendingResult: VoiceCommandResult?

    /// Stored MIDI for disambiguation flow (since pendingMIDI gets cleared)
    private var disambiguationMIDI: MIDIMessage?

    /// Stored MIDI for the current result (for saveAndContinue).
    /// Setter is internal so tests can seed state.
    @Published var currentMIDI: MIDIMessage?

    // MARK: - Initialization

    /// Initialize with required dependencies.
    ///
    /// - Parameters:
    ///   - midiManager: Manager for MIDI input capture
    ///   - voiceManager: Manager for voice input and transcription
    ///   - claudeService: Service for AI command interpretation
    init(
        midiManager: MIDIInputManager,
        voiceManager: VoiceInputManager,
        claudeService: CommandInterpreting
    ) {
        self.midiManager = midiManager
        self.voiceManager = voiceManager
        self.claudeService = claudeService
    }

    // MARK: - Public Methods

    /// Start listening for both MIDI and voice input.
    ///
    /// Sets up callbacks on both managers and begins the capture process.
    /// The coordinator will wait for both a MIDI message and a voice command
    /// before processing the mapping.
    func activate() {
        guard !isActive else { return }
        guard hasLiveDestination else {
            statusMessage = "Cannot start: choose a valid destination device."
            return
        }

        lifecycleGeneration &+= 1
        let generation = lifecycleGeneration

        // Setup MIDI callback
        midiManager.onMIDIReceived = { [weak self] message in
            Task { @MainActor in
                guard let self,
                      self.isActive,
                      self.lifecycleGeneration == generation else { return }
                self.handleMIDIReceived(message)
            }
        }

        // Setup voice callback
        voiceManager.onTranscriptReady = { [weak self] transcript in
            Task { @MainActor in
                guard let self,
                      self.isActive,
                      self.lifecycleGeneration == generation else { return }
                self.handleTranscriptReady(transcript)
            }
        }

        // Setup model load progress callback
        voiceManager.onModelLoadProgress = { [weak self] progress, message in
            Task { @MainActor in
                guard let self,
                      self.isActive,
                      self.lifecycleGeneration == generation else { return }
                let percentage = Int(progress * 100)
                self.statusMessage = "\(message) (\(percentage)%)"
            }
        }

        // Start listening
        midiManager.startListening()

        isActive = true
        statusMessage = "Activating..."
        startVoiceListening(
            generation: generation,
            successStatus: "Ready. Press a MIDI control and say your command."
        )
    }

    /// Stop all listening and reset state.
    func deactivate() {
        invalidateLifecycle()
        midiManager.stopListening()
        voiceManager.stopListening()

        // Clear callbacks
        midiManager.onMIDIReceived = nil
        voiceManager.onTranscriptReady = nil
        voiceManager.onModelLoadProgress = nil
        clearAllState()
        stagedMappings = []
        showOverwriteAlert = false
        conflictingCommands = []
        isProcessing = false

        isActive = false
        statusMessage = ""
    }

    /// User selected an option from the disambiguation UI.
    ///
    /// - Parameter index: Index of the selected option in `disambiguationOptions`
    func selectOption(_ index: Int) {
        guard let options = disambiguationOptions,
              index >= 0 && index < options.count,
              let midi = disambiguationMIDI else {
            return
        }

        let selected = options[index]

        // Create a VoiceCommandResult from the selected alternative
        let result = VoiceCommandResult(
            command: selected.command,
            assignment: selected.assignment,
            controllerType: nil,
            confidence: selected.confidence,
            alternatives: nil
        )

        // Update current state so saveAndContinue uses the correct result
        currentResult = result
        currentMIDI = midi

        // Clear disambiguation state
        disambiguationOptions = nil
        disambiguationMIDI = nil
        pendingResult = nil
        pendingMIDI = nil
        pendingVoice = nil
        statusMessage = "Selected: \(selected.command). Press Next to save."
    }

    /// User cancelled the disambiguation UI.
    func dismissOptions() {
        clearAllState()
        statusMessage = "Cancelled. Ready for next."
    }

    /// Set the document reference for saving
    @discardableResult
    func setDocument(
        _ doc: TraktorMappingDocument,
        destinationDeviceID: Device.ID? = nil
    ) -> Bool {
        let resolvedDestinationID: Device.ID?
        if let destinationDeviceID,
           doc.mappingFile.devices.contains(where: { $0.id == destinationDeviceID }) {
            resolvedDestinationID = destinationDeviceID
        } else if MappingTransferService.isTrulyEmpty(doc.mappingFile) {
            resolvedDestinationID = nil
        } else if destinationDeviceID == nil, doc.mappingFile.devices.count == 1 {
            resolvedDestinationID = doc.mappingFile.devices[0].id
        } else {
            document = nil
            self.destinationDeviceID = nil
            statusMessage = "Cannot start: choose a valid destination device."
            return false
        }

        self.document = doc
        self.destinationDeviceID = resolvedDestinationID
        return true
    }

    /// Called when user clicks "Finish & Save" - checks for conflicts
    func finishAndSave() {
        guard let document = document else {
            statusMessage = "Error: No document reference"
            return
        }

        guard !stagedMappings.isEmpty else {
            statusMessage = "Nothing has been added to this session"
            return
        }

        guard canFinishSession else {
            statusMessage = "Add the current mapping to the session before finishing."
            return
        }

        let targetMappings: [MappingEntry]
        if let destinationDeviceID,
           let device = document.mappingFile.devices.first(where: { $0.id == destinationDeviceID }) {
            targetMappings = device.mappings
        } else if MappingTransferService.isTrulyEmpty(document.mappingFile) {
            targetMappings = []
        } else {
            statusMessage = "Cannot save: the destination device is unavailable."
            return
        }

        let stagedKeys = Set(stagedMappings.compactMap(SemanticBindingKey.init(entry:)))
        let conflicts = targetMappings.compactMap { mapping -> MappingEntry? in
            guard let key = SemanticBindingKey(entry: mapping), stagedKeys.contains(key) else {
                return nil
            }
            return mapping
        }

        if !conflicts.isEmpty {
            conflictingCommands = Array(Set(conflicts.map(\.commandName))).sorted()
            showOverwriteAlert = true
            return
        }

        performVoiceSave(overwrite: false)
    }

    /// Perform the actual save operation
    func performVoiceSave(overwrite: Bool) {
        guard let document = document else { return }
        guard canFinishSession else {
            showOverwriteAlert = false
            statusMessage = "Add the current mapping to the session before finishing."
            return
        }
        let entries = stagedMappings
        let keysToReplace = Set(entries.compactMap(SemanticBindingKey.init(entry:)))

        do {
            _ = try document.performUndoableMutation(
                actionName: "Save Voice Mappings",
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
                file.devices[destinationIndex].mappings.append(contentsOf: entries)
                _ = try TSIWriter().writeConverted(file)
            }
        } catch {
            statusMessage = "Cannot save voice mappings: \(error.localizedDescription)"
            return
        }

        let savedCount = entries.count
        stagedMappings = []
        clearAllState()
        invalidateLifecycle()
        midiManager.stopListening()
        voiceManager.stopListening()
        midiManager.onMIDIReceived = nil
        voiceManager.onTranscriptReady = nil
        voiceManager.onModelLoadProgress = nil
        isProcessing = false
        isActive = false
        statusMessage = "Saved \(savedCount) mappings!"
    }

    /// Cancel discards only in-memory session work; it never touches the file.
    func cancelSession() {
        deactivate()
    }

    // MARK: - Input Handling (internal for tests)

    /// Handle incoming MIDI message.
    func handleMIDIReceived(_ message: MIDIMessage) {
        pendingMIDI = message
        statusMessage = "MIDI captured: \(describeMIDI(message))"

        if pendingVoice != nil && !isProcessing {
            Task {
                await processMapping()
            }
        }
    }

    /// Handle completed voice transcript.
    func handleTranscriptReady(_ transcript: String) {
        pendingVoice = transcript
        statusMessage = "Voice: \"\(transcript)\""

        if pendingMIDI != nil && !isProcessing {
            Task {
                await processMapping()
            }
        }
    }

    /// Process the mapping with both MIDI and voice captured.
    func processMapping() async {
        guard let midi = pendingMIDI, let voice = pendingVoice else { return }
        let generation = lifecycleGeneration

        // Consume the pending inputs so a later MIDI press can't re-pair with
        // this (now stale) transcript, and clear the previous result so the
        // overlay can't save an old command against the new MIDI mid-processing.
        pendingMIDI = nil
        pendingVoice = nil
        currentResult = nil
        disambiguationOptions = nil
        disambiguationMIDI = nil
        pendingResult = nil

        isProcessing = true
        statusMessage = "Understanding command..."
        currentMIDI = midi

        do {
            let result = try await claudeService.interpretCommand(
                transcript: voice,
                availableCommands: TraktorCommands.allNames
            )
            guard generation == lifecycleGeneration else { return }
            handleInterpretation(result, midi: midi)
        } catch {
            guard generation == lifecycleGeneration else { return }
            // Failed state: no half-paired MIDI left behind, status shows the failure.
            currentMIDI = nil
            statusMessage = "API error: \(error.localizedDescription)"
        }

        isProcessing = false

        // Re-process if NEW inputs arrived during the API call. The inputs we
        // just consumed were cleared above, so an API error cannot retry-loop.
        if pendingMIDI != nil, pendingVoice != nil {
            Task {
                await processMapping()
            }
        }
    }

    /// Route an interpretation result to save-ready, disambiguation, or error state.
    private func handleInterpretation(_ result: VoiceCommandResult, midi: MIDIMessage) {
        let isKnown = TraktorCommands.verifiedDescriptor(
            named: result.command,
            supporting: .input
        ) != nil

        if isKnown && result.isHighConfidence {
            currentResult = result
            statusMessage = "Press Next to save"
            return
        }

        // Low confidence, or Claude invented a command name — offer only known options.
        let options = buildDisambiguationOptions(from: result)
        guard !options.isEmpty else {
            currentResult = nil
            currentMIDI = nil
            statusMessage = "\"\(result.command)\" isn't a known Traktor command. Try again."
            return
        }

        // A known-but-low-confidence primary stays directly savable; an unknown
        // primary never does — the user must pick a known option.
        if isKnown {
            currentResult = result
        }
        disambiguationMIDI = midi
        pendingResult = result
        disambiguationOptions = options
        statusMessage = "Please select the correct command"
    }

    /// Save the current mapping and clear for new input
    func saveAndContinue() {
        guard !isProcessing else {
            statusMessage = "Still processing — wait for the result before saving"
            return
        }

        guard let midi = currentMIDI ?? disambiguationMIDI,
              let result = currentResult else {
            statusMessage = "Nothing to save"
            return
        }

        // Final guard at the insertion seam: Voice may create only commands
        // verified as input-capable in Traktor 4.4.1.
        guard TraktorCommands.verifiedDescriptor(
            named: result.command,
            supporting: .input
        ) != nil else {
            statusMessage = "\"\(result.command)\" isn't a known Traktor command — not saved"
            return
        }

        let entry: MappingEntry
        do {
            entry = try VoiceMappingBuilder.makeEntry(midi: midi, result: result)
        } catch {
            statusMessage = "Mapping not added: \(error.localizedDescription)"
            return
        }

        stagedMappings.append(entry)

        // Clear all state for next input
        clearAllState()

        // Restart listening
        statusMessage = "Added to Session. Ready for next input. (\(stagedMappings.count) total)"

        if isActive {
            startVoiceListening(
                generation: lifecycleGeneration,
                successStatus: nil
            )
        }
    }

    /// Clear all state for fresh input
    private func clearAllState() {
        pendingMIDI = nil
        pendingVoice = nil
        currentResult = nil
        currentMIDI = nil
        disambiguationOptions = nil
        disambiguationMIDI = nil
        pendingResult = nil
    }

    private var hasUnstagedMapping: Bool {
        currentResult != nil
            || currentMIDI != nil
            || disambiguationOptions != nil
            || isProcessing
            || pendingMIDI != nil
            || pendingVoice != nil
    }

    private var hasLiveDestination: Bool {
        guard let document else { return false }
        if let destinationDeviceID {
            return document.mappingFile.devices.contains { $0.id == destinationDeviceID }
        }
        return MappingTransferService.isTrulyEmpty(document.mappingFile)
    }

    private func invalidateLifecycle() {
        lifecycleGeneration &+= 1
        voiceListeningTask?.cancel()
        voiceListeningTask = nil
    }

    private func startVoiceListening(
        generation: UInt,
        successStatus: String?
    ) {
        voiceListeningTask?.cancel()
        voiceListeningTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.voiceManager.startListening()
                guard self.lifecycleGeneration == generation,
                      self.isActive,
                      !Task.isCancelled else {
                    if !self.isActive {
                        self.voiceManager.stopListening()
                    }
                    return
                }
                if let successStatus {
                    self.statusMessage = successStatus
                }
            } catch {
                guard self.lifecycleGeneration == generation,
                      self.isActive,
                      !Task.isCancelled else { return }
                self.statusMessage = "Voice error: \(error.localizedDescription)"
            }
        }
    }

    /// Build the list of disambiguation options from a result.
    /// Unknown command names (hallucinated by the API) are filtered out so
    /// `selectOption()` can never put an invalid command on the save path.
    private func buildDisambiguationOptions(from result: VoiceCommandResult) -> [CommandAlternative] {
        var options = [result.asAlternative]
        if let alternatives = result.alternatives {
            options.append(contentsOf: alternatives)
        }
        return options.filter {
            TraktorCommands.verifiedDescriptor(named: $0.command, supporting: .input) != nil
        }
    }

    /// Generate a human-readable description of a MIDI message.
    private func describeMIDI(_ message: MIDIMessage) -> String {
        if let cc = message.cc {
            return "Ch\(message.channel) CC \(cc)"
        } else if let note = message.note {
            return "Ch\(message.channel) Note \(note)"
        } else {
            return "Ch\(message.channel) Value \(message.value)"
        }
    }

}
