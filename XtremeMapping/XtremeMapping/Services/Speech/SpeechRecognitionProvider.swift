//
//  SpeechRecognitionProvider.swift
//  XtremeMapping
//
//  Protocol for swappable speech recognition providers
//

import Foundation

/// Protocol for swappable speech recognition providers
///
/// Implementations can use Apple Speech, WhisperKit, or other speech-to-text engines.
/// The abstraction allows switching providers without changing consuming code.
protocol SpeechRecognitionProvider: AnyObject {
    /// Whether the provider is currently listening for speech
    var isListening: Bool { get }

    /// The current transcript (may be partial during recognition)
    var transcript: String { get }

    /// Start listening for speech input
    /// - Throws: If permissions are denied or recognition cannot be started
    func startListening() async throws

    /// Stop listening for speech input
    func stopListening()

    /// Called when a complete transcript is ready (after silence detection)
    var onTranscriptReady: ((String) -> Void)? { get set }

    /// Called with partial results during recognition
    var onPartialResult: ((String) -> Void)? { get set }

    /// Called during model download/loading with progress (0.0 to 1.0) and status message
    var onModelLoadProgress: ((Double, String) -> Void)? { get set }
}
