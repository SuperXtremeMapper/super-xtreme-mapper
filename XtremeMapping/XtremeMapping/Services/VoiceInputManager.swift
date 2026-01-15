//
//  VoiceInputManager.swift
//  XtremeMapping
//
//  Thin wrapper that delegates to a SpeechRecognitionProvider.
//  Exposes speech recognition to the rest of the app.
//

import Foundation
import Combine

/// Manages voice input by delegating to a swappable SpeechRecognitionProvider
///
/// This class acts as the app's interface to speech recognition, allowing
/// the underlying provider to be swapped at runtime (e.g., Apple Speech vs WhisperKit).
@MainActor
final class VoiceInputManager: ObservableObject {

    // MARK: - Published Properties

    /// Whether the manager is currently listening for speech
    @Published private(set) var isListening = false

    /// The current transcript (may be partial during recognition)
    @Published private(set) var transcript: String = ""

    // MARK: - Callbacks

    /// Called when a complete transcript is ready (after silence detection)
    var onTranscriptReady: ((String) -> Void)?

    /// Called during model download/loading with progress (0.0 to 1.0) and status message
    var onModelLoadProgress: ((Double, String) -> Void)?

    // MARK: - Private Properties

    private var provider: SpeechRecognitionProvider

    // MARK: - Initialization

    /// Initialize with a specific provider
    init(provider: SpeechRecognitionProvider) {
        self.provider = provider
        setupProviderCallbacks()
    }

    /// Convenience initializer using AppleSpeechProvider (default)
    /// Note: WhisperKitProvider caused EXC_BAD_ACCESS crashes - needs investigation
    convenience init() {
        self.init(provider: AppleSpeechProvider())
    }

    // MARK: - Public Methods

    /// Start listening for speech input
    /// - Throws: If permissions are denied or recognition cannot be started
    func startListening() async throws {
        try await provider.startListening()
        syncStateFromProvider()
    }

    /// Stop listening for speech input
    func stopListening() {
        provider.stopListening()
        syncStateFromProvider()
    }

    /// Swap the speech recognition provider at runtime
    ///
    /// Useful for switching between providers from settings (e.g., Apple Speech vs WhisperKit)
    /// - Parameter provider: The new provider to use
    func setProvider(_ provider: SpeechRecognitionProvider) {
        // Stop the current provider first
        self.provider.stopListening()

        // Clear callbacks from old provider
        self.provider.onTranscriptReady = nil
        self.provider.onPartialResult = nil

        // Switch to new provider
        self.provider = provider
        setupProviderCallbacks()
        syncStateFromProvider()
    }

    // MARK: - Private Methods

    /// Setup callbacks on the provider to forward state changes
    private func setupProviderCallbacks() {
        // Forward partial results to update transcript
        provider.onPartialResult = { [weak self] partialText in
            Task { @MainActor in
                self?.transcript = partialText
            }
        }

        // Forward complete transcripts to our callback
        provider.onTranscriptReady = { [weak self] finalText in
            Task { @MainActor in
                guard let self = self else { return }
                self.transcript = finalText
                self.onTranscriptReady?(finalText)
            }
        }

        // Forward model load progress
        provider.onModelLoadProgress = { [weak self] progress, message in
            Task { @MainActor in
                self?.onModelLoadProgress?(progress, message)
            }
        }
    }

    /// Sync state from provider to our @Published properties
    private func syncStateFromProvider() {
        isListening = provider.isListening
        transcript = provider.transcript
    }
}
