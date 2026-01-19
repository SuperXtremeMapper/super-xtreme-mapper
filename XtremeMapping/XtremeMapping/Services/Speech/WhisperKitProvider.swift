//
//  WhisperKitProvider.swift
//  XtremeMapping
//
//  Speech recognition using WhisperKit (OpenAI Whisper on Apple Silicon)
//

import Foundation
import AVFoundation
import Combine
import WhisperKit

/// Speech recognition provider using WhisperKit for on-device Whisper transcription
@MainActor
final class WhisperKitProvider: NSObject, ObservableObject, SpeechRecognitionProvider {

    // MARK: - Shared Model (prevents double download across document windows)

    /// Shared WhisperKit instance used by all providers
    private static var sharedWhisperKit: WhisperKit?

    /// Flag to prevent concurrent model loading
    private static var isLoadingModel = false

    /// Flag to track if shared model is ready
    private static var sharedModelLoaded = false

    // MARK: - SpeechRecognitionProvider Properties

    @Published private(set) var isListening = false
    @Published private(set) var transcript = ""

    var onTranscriptReady: ((String) -> Void)?
    var onPartialResult: ((String) -> Void)?
    var onModelLoadProgress: ((Double, String) -> Void)?

    // MARK: - Private Properties

    private let audioEngine = AVAudioEngine()
    private var audioFileURL: URL?

    /// Duration of silence before considering speech complete
    private let silenceThreshold: TimeInterval = 1.5
    private var silenceTimer: Timer?

    /// Thread-safe audio state (accessed from audio thread)
    /// Using nonisolated(unsafe) because we manually synchronize with audioLock
    private let audioLock = NSLock()
    private nonisolated(unsafe) var _lastAudioLevel: Float = 0
    private nonisolated(unsafe) var _hasDetectedSpeech = false
    private nonisolated(unsafe) var _audioFile: AVAudioFile?

    /// Dot animation state for download progress
    private var dotCount = 0

    // MARK: - Initialization

    override init() {
        super.init()
    }

    // MARK: - SpeechRecognitionProvider Methods

    func startListening() async throws {
        guard !isListening else { return }

        // Use shared WhisperKit model if already loaded
        if Self.sharedModelLoaded, Self.sharedWhisperKit != nil {
            onModelLoadProgress?(1.0, "WhisperKit ready")
            try startRecording()
            return
        }

        // Wait if another instance is loading the model
        if Self.isLoadingModel {
            onModelLoadProgress?(0.5, "Loading WhisperKit...")
            // Poll until model is ready
            while Self.isLoadingModel {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            if Self.sharedModelLoaded {
                onModelLoadProgress?(1.0, "WhisperKit ready")
                try startRecording()
                return
            }
        }

        // Load WhisperKit model
        Self.isLoadingModel = true
        onModelLoadProgress?(0.0, "Downloading WhisperKit")

        do {
            // Create WhisperKit with smaller model for faster loading
            // "base" is fast (~150MB) with good accuracy for voice commands
            let config = WhisperKitConfig(
                model: "base",
                verbose: true,
                prewarm: true
            )

            // Start progress monitoring task
            let progressTask = Task { @MainActor [weak self] in
                await self?.monitorDownloadProgress()
            }

            let kit = try await WhisperKit(config)

            // Cancel progress monitoring
            progressTask.cancel()

            // Set up model state callback for future state changes
            kit.modelStateCallback = { [weak self] _, newState in
                Task { @MainActor in
                    self?.handleModelStateChange(to: newState)
                }
            }

            // Store in shared static property
            Self.sharedWhisperKit = kit
            Self.sharedModelLoaded = true
            Self.isLoadingModel = false
            onModelLoadProgress?(1.0, "WhisperKit ready")
        } catch {
            Self.isLoadingModel = false
            onModelLoadProgress?(0.0, "Download failed")
            throw SpeechRecognitionError.recognitionFailed("Failed to load WhisperKit: \(error.localizedDescription)")
        }

        // Start recording
        try startRecording()
    }

    func stopListening() {
        guard isListening else { return }

        cancelSilenceTimer()
        stopRecordingAndTranscribe()
    }

    // MARK: - Private Methods

    private func startRecording() throws {
        // Reset state
        transcript = ""
        audioLock.lock()
        _hasDetectedSpeech = false
        _lastAudioLevel = 0
        audioLock.unlock()

        // Create temp file for recording
        let tempDir = FileManager.default.temporaryDirectory
        audioFileURL = tempDir.appendingPathComponent("whisper_recording_\(UUID().uuidString).wav")

        guard let audioFileURL = audioFileURL else {
            throw SpeechRecognitionError.recognitionFailed("Failed to create temp file")
        }

        // Get input node and format
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.sampleRate > 0 else {
            throw SpeechRecognitionError.recognitionFailed("Invalid audio format - no microphone available")
        }

        // Create audio file for recording
        // WhisperKit works best with 16kHz mono audio, but we'll record at native rate
        // and let WhisperKit handle conversion
        let newAudioFile = try AVAudioFile(
            forWriting: audioFileURL,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: recordingFormat.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false
            ]
        )

        // Store audio file under lock (accessed from audio thread)
        audioLock.lock()
        _audioFile = newAudioFile
        audioLock.unlock()

        // Install tap to record audio and detect silence
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        // Start silence detection
        resetSilenceTimer()
    }

    /// Called on AUDIO THREAD - must be thread-safe
    nonisolated private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Write to file (under lock)
        audioLock.lock()
        let file = _audioFile
        audioLock.unlock()

        if let file = file {
            try? file.write(from: buffer)
        }

        // Calculate audio level for silence detection
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)

        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        let avgLevel = sum / Float(frameLength)

        // Detect if there's speech (level above threshold)
        let speechThreshold: Float = 0.01
        let detectedSpeech = avgLevel > speechThreshold

        // Update shared state under lock
        audioLock.lock()
        if detectedSpeech {
            _hasDetectedSpeech = true
        }
        _lastAudioLevel = avgLevel
        audioLock.unlock()

        // Reset silence timer on main thread if speech detected
        if detectedSpeech {
            Task { @MainActor [weak self] in
                self?.resetSilenceTimer()
            }
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
        guard isListening else { return }

        // Check if we detected speech (under lock since audio thread writes this)
        audioLock.lock()
        let detectedSpeech = _hasDetectedSpeech
        audioLock.unlock()

        // Only transcribe if we detected speech
        if detectedSpeech {
            stopRecordingAndTranscribe()
        } else {
            // No speech yet, keep listening
            resetSilenceTimer()
        }
    }

    private func stopRecordingAndTranscribe() {
        // Stop recording
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Clear audio file under lock (audio thread may still be accessing)
        audioLock.lock()
        _audioFile = nil
        audioLock.unlock()

        isListening = false

        // Transcribe the recorded audio
        guard let audioFileURL = audioFileURL else { return }

        Task {
            await transcribeAudio(at: audioFileURL)
        }
    }

    private func transcribeAudio(at url: URL) async {
        guard let whisperKit = Self.sharedWhisperKit else { return }

        do {
            let results = try await whisperKit.transcribe(audioPath: url.path)

            if let result = results.first {
                let text = result.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                // Filter out common Whisper artifacts
                let filteredText = filterWhisperArtifacts(text)

                if !filteredText.isEmpty {
                    await MainActor.run {
                        self.transcript = filteredText
                        self.onPartialResult?(filteredText)
                        self.onTranscriptReady?(filteredText)
                    }
                }
            }
        } catch {
            // Transcription failed silently - user can retry
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: url)
        audioFileURL = nil
    }

    /// Monitor download progress with animated dots
    /// Reports progress every 1 second until cancelled (avoids rate-limiting)
    private func monitorDownloadProgress() async {
        var elapsed: Double = 0
        let estimatedDuration: Double = 120.0  // Estimate 2 minutes for large model download

        while !Task.isCancelled && !Self.sharedModelLoaded {
            // Animate dots: . -> .. -> ... -> . (padded to fixed width)
            dotCount = (dotCount % 3) + 1
            let dots = String(repeating: ".", count: dotCount)
            let paddedDots = dots.padding(toLength: 3, withPad: " ", startingAt: 0)

            // Calculate estimated progress (caps at 95% until actually done)
            let estimatedProgress = min(0.95, elapsed / estimatedDuration)

            onModelLoadProgress?(estimatedProgress, "Downloading WhisperKit\(paddedDots)")

            // Wait 1 second before next update to avoid rate-limiting
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            elapsed += 1.0
        }
    }

    /// Handle WhisperKit model state changes for progress reporting
    private func handleModelStateChange(to newState: ModelState) {
        let progress: Double
        let message: String

        switch newState {
        case .unloaded:
            progress = 0.0
            message = "Model unloaded"
        case .unloading:
            progress = 0.1
            message = "Unloading model..."
        case .downloading:
            progress = 0.2
            message = "Downloading WhisperKit..."
        case .downloaded:
            progress = 0.3
            message = "Download complete"
        case .loading:
            progress = 0.5
            message = "Loading model..."
        case .loaded:
            progress = 0.7
            message = "Model loaded, warming up..."
        case .prewarming:
            progress = 0.9
            message = "Preparing model..."
        case .prewarmed:
            progress = 1.0
            message = "WhisperKit ready"
        @unknown default:
            progress = 0.5
            message = "Loading..."
        }

        onModelLoadProgress?(progress, message)
    }

    /// Filter out common Whisper hallucination artifacts
    private func filterWhisperArtifacts(_ text: String) -> String {
        let artifacts = [
            "[BLANK_AUDIO]",
            "[MUSIC]",
            "[SILENCE]",
            "(upbeat music)",
            "(music)",
            "Thank you.",
            "Thanks for watching!",
            "Subscribe",
            "♪"
        ]

        var filtered = text
        for artifact in artifacts {
            filtered = filtered.replacingOccurrences(of: artifact, with: "", options: .caseInsensitive)
        }

        return filtered.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
