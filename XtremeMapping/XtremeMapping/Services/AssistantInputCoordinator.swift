import Foundation
import Combine

@MainActor
protocol AssistantMIDIListening: AnyObject {
    func start(_ callback: @escaping (MIDIMessage) -> Void) -> Bool
    func stop()
}

@MainActor
final class AssistantMIDIListener: AssistantMIDIListening {
    private let manager: MIDIInputManager
    private var lease: MIDIInputManager.ListeningLease?
    init(manager: MIDIInputManager = .shared) { self.manager = manager }
    func start(_ callback: @escaping (MIDIMessage) -> Void) -> Bool {
        stop()
        lease = manager.acquireListeningLease(onMIDIReceived: callback)
        return lease != nil
    }
    func stop() {
        if let lease { manager.releaseListeningLease(lease) }
        lease = nil
    }
}

/// Input only: neither speech nor MIDI can send a request or mutate a mapping.
@MainActor
final class AssistantInputCoordinator: ObservableObject {
    @Published private(set) var voiceEnabled = false
    @Published private(set) var isStartingVoice = false
    @Published private(set) var isLearning = false
    @Published private(set) var capturedMIDI: SXMJSONMIDI?
    @Published private(set) var errorMessage: String?
    var onTranscript: ((String) -> Void)?
    private let speech: SpeechRecognitionProvider
    private let midi: any AssistantMIDIListening
    private var voiceGeneration = 0
    private var midiGeneration = 0
    private var voiceTask: Task<Void, Never>?

    convenience init() { self.init(speech: AppleSpeechProvider(), midi: AssistantMIDIListener()) }

    init(speech: SpeechRecognitionProvider, midi: any AssistantMIDIListening) {
        self.speech = speech
        self.midi = midi
    }

    @discardableResult
    func setVoiceEnabled(_ enabled: Bool) -> Task<Void, Never>? {
        voiceGeneration += 1
        let generation = voiceGeneration
        voiceEnabled = enabled
        errorMessage = nil
        let previous = voiceTask
        previous?.cancel()
        speech.onTranscriptReady = nil
        speech.stopListening()
        guard enabled else { isStartingVoice = false; return previous }
        isStartingVoice = true
        // Serialize starts: a cancelled permission request may finish late.
        let task = Task { [weak self] in
            await previous?.value
            guard let self, generation == self.voiceGeneration, !Task.isCancelled else { return }
            self.speech.onTranscriptReady = { [weak self] text in
                guard let self, self.voiceEnabled, self.voiceGeneration == generation else { return }
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { self.onTranscript?(value) }
            }
            do {
                try await self.speech.startListening()
                guard generation == self.voiceGeneration, !Task.isCancelled else {
                    self.speech.stopListening(); return
                }
                self.isStartingVoice = false
            } catch {
                self.speech.stopListening()
                guard generation == self.voiceGeneration, !Task.isCancelled else { return }
                self.voiceEnabled = false
                self.isStartingVoice = false
                self.errorMessage = "Voice input could not start. Check microphone and speech permissions in System Settings, then try again."
            }
        }
        voiceTask = task
        return task
    }

    func learnControl() {
        stopMIDI()
        errorMessage = nil
        capturedMIDI = nil
        let generation = midiGeneration
        isLearning = true
        let started = midi.start { [weak self] message in
            guard let self, self.isLearning, generation == self.midiGeneration,
                  message.isCC || message.isNoteOn,
                  let assignment = MIDIAssignment(learnMessage: message) else { return }
            self.capturedMIDI = SXMJSONMIDI(assignment)
            self.stopMIDI()
        }
        if !started {
            isLearning = false
            errorMessage = "MIDI capture is unavailable. Connect a controller and finish any other MIDI Learn session, then try again."
        }
    }

    func clearCapture() { stopMIDI(); capturedMIDI = nil }
    func stopMIDI() { midiGeneration += 1; midi.stop(); isLearning = false }
    func stopAll() {
        setVoiceEnabled(false)
        clearCapture()
        onTranscript = nil
    }
}
