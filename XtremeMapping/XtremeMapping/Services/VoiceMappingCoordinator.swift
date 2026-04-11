//
//  VoiceMappingCoordinator.swift
//  XtremeMapping
//
//  Orchestrates MIDI input, voice input, and Claude API to create mappings.
//

import Foundation
import Combine

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
/// coordinator.onMappingCreated = { midi, result in
///     // Create the actual mapping
/// }
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

    /// The interpreted command result (available after voice processing)
    @Published private(set) var currentResult: VoiceCommandResult?

    /// Published when a mapping is saved - view observes this via .onChange
    /// Contains (MIDI message, Voice command result) tuple
    @Published private(set) var savedMapping: (midi: MIDIMessage, result: VoiceCommandResult)?

    /// Counter that increments each time a mapping is saved - used for .onChange observation
    @Published private(set) var savedMappingCount: Int = 0

    /// Show overwrite confirmation alert
    @Published var showOverwriteAlert = false

    /// Commands that conflict with existing mappings
    @Published var conflictingCommands: [String] = []

    /// Reference to current document for saving
    private weak var document: TraktorMappingDocument?

    /// Accumulated mappings from this voice session
    @Published private(set) var sessionMappings: [(midi: MIDIMessage, result: VoiceCommandResult)] = []

    /// UUIDs of MappingEntry objects created during this voice session
    private var sessionMappingIds: Set<UUID> = []

    // MARK: - Callbacks (deprecated - use savedMapping instead)

    /// Called when a mapping is successfully created.
    /// Parameters: (MIDI message, Voice command result)
    var onMappingCreated: ((MIDIMessage, VoiceCommandResult) -> Void)?

    // MARK: - Dependencies

    private let midiManager: MIDIInputManager
    private let voiceManager: VoiceInputManager
    private let claudeService: ClaudeAPIService

    // MARK: - Private State

    /// Stored pending result for disambiguation flow
    private var pendingResult: VoiceCommandResult?

    /// Stored MIDI for disambiguation flow (since pendingMIDI gets cleared)
    private var disambiguationMIDI: MIDIMessage?

    /// Stored MIDI for the current result (for saveAndContinue)
    @Published private(set) var currentMIDI: MIDIMessage?

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
        claudeService: ClaudeAPIService
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

        // Setup MIDI callback
        midiManager.onMIDIReceived = { [weak self] message in
            Task { @MainActor in
                self?.handleMIDIReceived(message)
            }
        }

        // Setup voice callback
        voiceManager.onTranscriptReady = { [weak self] transcript in
            Task { @MainActor in
                self?.handleTranscriptReady(transcript)
            }
        }

        // Setup model load progress callback
        voiceManager.onModelLoadProgress = { [weak self] progress, message in
            Task { @MainActor in
                let percentage = Int(progress * 100)
                self?.statusMessage = "\(message) (\(percentage)%)"
            }
        }

        // Start listening
        midiManager.startListening()

        // Start voice listening (async, may throw)
        Task {
            do {
                try await voiceManager.startListening()
                statusMessage = "Ready. Press a MIDI control and say your command."
            } catch {
                statusMessage = "Voice error: \(error.localizedDescription)"
            }
        }

        isActive = true
        statusMessage = "Activating..."
    }

    /// Stop all listening and reset state.
    func deactivate() {
        guard isActive else { return }

        // Stop listening
        midiManager.stopListening()
        voiceManager.stopListening()

        // Clear callbacks
        midiManager.onMIDIReceived = nil
        voiceManager.onTranscriptReady = nil
        voiceManager.onModelLoadProgress = nil

        // Reset state
        clearAllState()

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
    func setDocument(_ doc: TraktorMappingDocument) {
        self.document = doc
    }

    /// Called when user clicks "Finish & Save" - checks for conflicts
    func finishAndSave() {
        guard let document = document else {
            statusMessage = "Error: No document reference"
            return
        }

        let newCommands = Set(sessionMappings.map { $0.result.command })

        var sessionCommandCounts: [String: Int] = [:]
        for mapping in sessionMappings {
            sessionCommandCounts[mapping.result.command, default: 0] += 1
        }

        var existingCommandCounts: [String: Int] = [:]
        for mapping in document.mappingFile.allMappings {
            if newCommands.contains(mapping.commandName) {
                existingCommandCounts[mapping.commandName, default: 0] += 1
            }
        }

        let conflicts = newCommands.filter { cmd in
            let existing = existingCommandCounts[cmd, default: 0]
            let fromSession = sessionCommandCounts[cmd, default: 0]
            return existing > fromSession
        }

        if !conflicts.isEmpty {
            conflictingCommands = Array(conflicts).sorted()
            showOverwriteAlert = true
            return
        }

        performVoiceSave(overwrite: false)
    }

    /// Perform the actual save operation
    func performVoiceSave(overwrite: Bool) {
        guard let document = document else { return }

        if overwrite {
            let commandsToReplace = Set(sessionMappings.map { $0.result.command })
            if !document.mappingFile.devices.isEmpty {
                document.mappingFile.devices[0].mappings.removeAll {
                    commandsToReplace.contains($0.commandName) && !sessionMappingIds.contains($0.id)
                }
            }
        }

        document.noteChange()
        let savedCount = sessionMappings.count
        sessionMappings = []
        sessionMappingIds = []
        statusMessage = "Saved \(savedCount) mappings!"
        deactivate()
    }

    /// Register a mapping ID created during this voice session
    func registerSessionMappingId(_ id: UUID) {
        sessionMappingIds.insert(id)
    }

    // MARK: - Private Methods

    /// Handle incoming MIDI message.
    private func handleMIDIReceived(_ message: MIDIMessage) {
        pendingMIDI = message
        statusMessage = "MIDI captured: \(describeMIDI(message))"

        if pendingVoice != nil && !isProcessing {
            Task {
                await processMapping()
            }
        }
    }

    /// Handle completed voice transcript.
    private func handleTranscriptReady(_ transcript: String) {
        pendingVoice = transcript
        statusMessage = "Voice: \"\(transcript)\""

        if pendingMIDI != nil && !isProcessing {
            Task {
                await processMapping()
            }
        }
    }

    /// Process the mapping with both MIDI and voice captured.
    private func processMapping() async {
        guard let midi = pendingMIDI, let voice = pendingVoice else { return }

        isProcessing = true
        statusMessage = "Understanding command..."
        currentMIDI = midi
        var succeeded = false

        do {
            let result = try await claudeService.interpretCommand(
                transcript: voice,
                availableCommands: TraktorCommands.allNames
            )

            currentResult = result
            succeeded = true

            if result.isHighConfidence {
                statusMessage = "Press Next to save"
            } else {
                disambiguationMIDI = midi
                pendingResult = result
                disambiguationOptions = buildDisambiguationOptions(from: result)
                statusMessage = "Please select the correct command"
            }
        } catch {
            statusMessage = "API error: \(error.localizedDescription)"
        }

        isProcessing = false

        // Re-process if new inputs arrived during the API call (but not on error — avoid retry loop)
        if succeeded, pendingMIDI != nil, pendingVoice != nil, currentResult == nil {
            Task {
                await processMapping()
            }
        }
    }

    /// Save the current mapping and clear for new input
    func saveAndContinue() {
        guard let midi = currentMIDI ?? disambiguationMIDI,
              let result = currentResult else {
            statusMessage = "Nothing to save"
            return
        }

        // Add to session mappings
        sessionMappings.append((midi: midi, result: result))

        // Create the mapping (for immediate feedback)
        createMapping(midi: midi, result: result)

        // Clear all state for next input
        clearAllState()

        // Restart listening
        statusMessage = "Saved! Ready for next input. (\(sessionMappings.count) total)"

        // Restart voice listening
        Task {
            do {
                try await voiceManager.startListening()
            } catch {
                statusMessage = "Voice error: \(error.localizedDescription)"
            }
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

    /// Build the list of disambiguation options from a result.
    private func buildDisambiguationOptions(from result: VoiceCommandResult) -> [CommandAlternative] {
        var options = [result.asAlternative]
        if let alternatives = result.alternatives {
            options.append(contentsOf: alternatives)
        }
        return options
    }

    /// Create a mapping from MIDI and voice result.
    private func createMapping(midi: MIDIMessage, result: VoiceCommandResult) {
        // Publish the saved mapping for view observation
        savedMapping = (midi: midi, result: result)
        savedMappingCount += 1

        // Also notify via callback (legacy)
        onMappingCreated?(midi, result)
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
