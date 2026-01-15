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

    // MARK: - Callbacks

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

        // Reset state
        clearPendingState()
        disambiguationOptions = nil
        disambiguationMIDI = nil
        pendingResult = nil

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
            controllerType: nil, // Alternatives don't carry controller type
            confidence: selected.confidence,
            alternatives: nil
        )

        createMapping(midi: midi, result: result)

        // Clear disambiguation state
        disambiguationOptions = nil
        disambiguationMIDI = nil
        pendingResult = nil
        statusMessage = "Mapping created! Ready for next."
    }

    /// User cancelled the disambiguation UI.
    func dismissOptions() {
        disambiguationOptions = nil
        disambiguationMIDI = nil
        pendingResult = nil
        statusMessage = "Cancelled. Ready for next."
    }

    // MARK: - Private Methods

    /// Handle incoming MIDI message.
    private func handleMIDIReceived(_ message: MIDIMessage) {
        pendingMIDI = message

        // Update status with MIDI info
        let midiDesc = describeMIDI(message)
        statusMessage = "MIDI captured: \(midiDesc)"

        // If we also have voice, process the mapping
        if pendingVoice != nil {
            Task {
                await processMapping()
            }
        }
    }

    /// Handle completed voice transcript.
    private func handleTranscriptReady(_ transcript: String) {
        pendingVoice = transcript

        // Update status with voice info
        statusMessage = "Voice: \"\(transcript)\""

        // If we also have MIDI, process the mapping
        if pendingMIDI != nil {
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

        do {
            let result = try await claudeService.interpretCommand(
                transcript: voice,
                availableCommands: TraktorCommands.allNames
            )

            if result.isHighConfidence {
                // High confidence - create mapping directly
                createMapping(midi: midi, result: result)
                statusMessage = "Mapping created: \(result.command)"
            } else {
                // Low confidence - show options for disambiguation
                disambiguationMIDI = midi
                pendingResult = result
                disambiguationOptions = buildDisambiguationOptions(from: result)
                statusMessage = "Please select the correct command"
            }
        } catch {
            // API failed - log error and let user retry
            statusMessage = "API error: \(error.localizedDescription)"
            print("[VoiceMappingCoordinator] Claude API error: \(error)")
        }

        isProcessing = false
        clearPendingState()
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
        // Log what would be created
        print("[VoiceMappingCoordinator] Creating mapping:")
        print("  MIDI: \(describeMIDI(midi))")
        print("  Command: \(result.command)")
        if let assignment = result.assignment {
            print("  Assignment: \(assignment)")
        }
        if let controllerType = result.controllerType {
            print("  Controller Type: \(controllerType)")
        }
        print("  Confidence: \(String(format: "%.1f%%", result.confidence * 100))")

        // Notify via callback
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

    /// Clear pending MIDI and voice state.
    private func clearPendingState() {
        pendingMIDI = nil
        pendingVoice = nil
    }
}
