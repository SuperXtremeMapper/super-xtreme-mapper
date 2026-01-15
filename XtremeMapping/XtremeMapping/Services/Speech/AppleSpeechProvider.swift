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
final class AppleSpeechProvider: ObservableObject, SpeechRecognitionProvider {

    // MARK: - SpeechRecognitionProvider Properties

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""

    var onTranscriptReady: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?

    // MARK: - Private Properties

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Duration of silence before considering speech complete
    private let silenceThreshold: TimeInterval = 1.5
    private var silenceTimer: Timer?
    private var lastTranscript = ""

    // MARK: - Initialization

    init(locale: Locale = .current) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
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

        // Request microphone permission
        let micPermission = await AVCaptureDevice.requestAccess(for: .audio)
        guard micPermission else {
            throw SpeechRecognitionError.microphoneAccessDenied
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

        // Configure audio session for macOS
        let inputNode = audioEngine.inputNode

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechRecognitionError.recognitionFailed("Unable to create recognition request")
        }

        recognitionRequest.shouldReportPartialResults = true

        // For on-device recognition when available (privacy + speed)
        if #available(macOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
        }

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }

        // Install audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // Log error but don't stop - some errors are recoverable
            print("Speech recognition error: \(error.localizedDescription)")

            // If the task has finished with an error, we might need to restart
            if recognitionTask?.state == .completed || recognitionTask?.state == .canceling {
                stopListening()
            }
            return
        }

        guard let result = result else { return }

        let newTranscript = result.bestTranscription.formattedString
        transcript = newTranscript
        onPartialResult?(newTranscript)

        // Reset silence timer on new speech
        if newTranscript != lastTranscript {
            lastTranscript = newTranscript
            resetSilenceTimer()
        }

        // If final result from recognizer, trigger ready callback
        if result.isFinal {
            cancelSilenceTimer()
            finalizeTranscript()
        }
    }

    private func resetSilenceTimer() {
        cancelSilenceTimer()

        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceThreshold, repeats: false) { [weak self] _ in
            guard let self = self else { return }
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
        let finalText = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { return }

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
        // Stop current recognition
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        // Small delay before restarting
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if isListening {
                do {
                    try startRecognition()
                } catch {
                    print("Failed to restart recognition: \(error.localizedDescription)")
                    isListening = false
                }
            }
        }
    }
}
