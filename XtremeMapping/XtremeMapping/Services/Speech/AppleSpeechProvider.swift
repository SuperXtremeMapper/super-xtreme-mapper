//
//  AppleSpeechProvider.swift
//  XtremeMapping
//
//  Speech recognition using Apple's Speech framework
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Errors that can occur during speech recognition
enum SpeechRecognitionError: LocalizedError {
    case notAvailable
    case notAuthorized
    case microphoneAccessDenied
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Speech recognition is not available on this device."
        case .notAuthorized:
            return "Speech recognition permission was denied."
        case .microphoneAccessDenied:
            return "Microphone access was denied."
        case .recognitionFailed(let reason):
            return "Speech recognition failed: \(reason)"
        }
    }
}

/// Speech recognition provider using Apple's Speech framework
@MainActor
final class AppleSpeechProvider: NSObject, ObservableObject, SpeechRecognitionProvider {

    // MARK: - SpeechRecognitionProvider Properties

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""

    var onTranscriptReady: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onModelLoadProgress: ((Double, String) -> Void)?  // Not used by Apple Speech

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Duration of silence before considering speech complete
    private let silenceThreshold: TimeInterval = 1.5
    private var silenceTimer: Timer?
    private var lastTranscript = ""

    /// Prevents concurrent restart attempts
    private var isRestarting = false

    /// Prevents double finalization from delegate callbacks
    private var hasFinalizedCurrent = false

    // MARK: - Initialization

    override init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        super.init()
        speechRecognizer?.delegate = self
    }

    // MARK: - SpeechRecognitionProvider Methods

    func startListening() async throws {
        // Check if already listening
        guard !isListening else { return }

        // Verify speech recognizer is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechRecognitionError.notAvailable
        }

        // Request speech recognition authorization
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            throw SpeechRecognitionError.notAuthorized
        }

        // Start recognition
        try startRecognition()
    }

    func stopListening() {
        guard isListening else { return }

        cancelSilenceTimer()

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil

        isListening = false
    }

    // MARK: - Private Methods

    private func startRecognition() throws {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Reset state
        transcript = ""
        lastTranscript = ""
        hasFinalizedCurrent = false

        // Get input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Check if format is valid
        guard recordingFormat.sampleRate > 0 else {
            throw SpeechRecognitionError.recognitionFailed("Invalid audio format - no microphone available")
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionFailed("Unable to create recognition request")
        }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .unspecified

        // Force server-based recognition (on-device can be unreliable)
        if #available(macOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Prepare and start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        // Small delay to let audio stabilize before starting recognition
        // This helps avoid "no speech detected" errors
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isListening else { return }
            // Start recognition task using delegate pattern
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: recognitionRequest, delegate: self)
        }
    }

    private func resetSilenceTimer() {
        cancelSilenceTimer()

        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleSilenceTimeout()
            }
        }
    }

    private func cancelSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    private func handleSilenceTimeout() {
        // User stopped speaking - finalize current transcript
        guard isListening, !transcript.isEmpty else { return }
        finalizeTranscript()
    }

    private func finalizeTranscript() {
        // Prevent double finalization from multiple delegate callbacks
        guard !hasFinalizedCurrent else { return }

        let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { return }

        hasFinalizedCurrent = true
        onTranscriptReady?(finalText)

        // Reset for next utterance (continuous mode)
        transcript = ""
        lastTranscript = ""

        // Restart recognition for continuous listening
        if isListening {
            restartRecognition()
        }
    }

    private func restartRecognition() {
        // Prevent concurrent restart attempts
        guard !isRestarting else { return }
        isRestarting = true

        // Stop current recognition
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Remove tap safely (check if it exists first)
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        recognitionRequest = nil
        recognitionTask = nil

        // Small delay before restarting
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            if isListening {
                do {
                    try startRecognition()
                } catch {
                    isListening = false
                }
            }
            isRestarting = false
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension AppleSpeechProvider: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available && self.isListening {
                self.stopListening()
            }
        }
    }
}

// MARK: - SFSpeechRecognitionTaskDelegate

extension AppleSpeechProvider: SFSpeechRecognitionTaskDelegate {
    nonisolated func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didHypothesizeTranscription transcription: SFTranscription) {
        Task { @MainActor in
            let newTranscript = transcription.formattedString
            self.transcript = newTranscript
            self.onPartialResult?(newTranscript)

            // Reset silence timer on new speech
            if newTranscript != self.lastTranscript {
                self.lastTranscript = newTranscript
                self.resetSilenceTimer()
            }
        }
    }

    nonisolated func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishRecognition recognitionResult: SFSpeechRecognitionResult) {
        Task { @MainActor in
            let finalTranscript = recognitionResult.bestTranscription.formattedString
            self.transcript = finalTranscript
            self.cancelSilenceTimer()
            self.finalizeTranscript()
        }
    }

    nonisolated func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        // Task was cancelled, no action needed
    }

    nonisolated func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        Task { @MainActor in
            if !successfully {
                // If it failed, try to use whatever transcript we have
                if !self.transcript.isEmpty {
                    self.finalizeTranscript()
                }
            }
        }
    }
}
