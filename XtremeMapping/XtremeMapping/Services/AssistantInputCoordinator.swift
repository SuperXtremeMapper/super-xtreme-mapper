import Foundation
import Combine

@MainActor
protocol AssistantMIDIListening: AnyObject {
    func start(_ callback: @escaping (MIDIMessage) -> Void) -> Bool
    func start(desiredInputPort: String?, requireSpecificSource: Bool, desiredSourceID: Int32?, _ callback: @escaping (MIDIMessage) -> Void) -> Bool
    func stop()
}

extension AssistantMIDIListening {
    func start(desiredInputPort: String?, requireSpecificSource: Bool, desiredSourceID: Int32?, _ callback: @escaping (MIDIMessage) -> Void) -> Bool {
        // Legacy adapters cannot promise device isolation.
        guard desiredSourceID == nil, !requireSpecificSource, desiredInputPort == nil || desiredInputPort == "" || desiredInputPort == "All Ports" else { return false }
        return start(callback)
    }
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
    func start(desiredInputPort: String?, requireSpecificSource: Bool, desiredSourceID: Int32?, _ callback: @escaping (MIDIMessage) -> Void) -> Bool {
        stop()
        lease = manager.acquireListeningLease(desiredInputPort: desiredInputPort,
            requireSpecificSource: requireSpecificSource, desiredSourceID: desiredSourceID, onMIDIReceived: callback)
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
    /// Live interim transcript while dictating — the words heard so far, before
    /// silence finalizes them. Empty when nothing is being heard right now. The
    /// composer uses this to pulse the mic and preview what is being captured.
    @Published private(set) var partialTranscript = ""
    /// Final, committed chunks land here (appended to the message box).
    var onTranscript: ((String) -> Void)?
    private let speech: SpeechRecognitionProvider
    private let midi: any AssistantMIDIListening
    private var desiredInputPort: String?
    private var requireSpecificSource = false
    private var desiredSourceID: Int32?

    /// Changing destinations discards capture so a control cannot be reused on a different device accidentally.
    func configureMIDI(desiredInputPort: String?, requireSpecificSource: Bool, desiredSourceID: Int32? = nil) {
        guard self.desiredInputPort != desiredInputPort || self.requireSpecificSource != requireSpecificSource || self.desiredSourceID != desiredSourceID else { return }
        clearCapture()
        self.desiredInputPort = desiredInputPort
        self.requireSpecificSource = requireSpecificSource
        self.desiredSourceID = desiredSourceID
    }

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
        speech.onPartialResult = nil
        speech.stopListening()
        partialTranscript = ""
        guard enabled else { isStartingVoice = false; return previous }
        isStartingVoice = true
        // Serialize starts: a cancelled permission request may finish late.
        let task = Task { [weak self] in
            await previous?.value
            guard let self, generation == self.voiceGeneration, !Task.isCancelled else { return }
            self.speech.onTranscriptReady = { [weak self] text in
                guard let self, self.voiceEnabled, self.voiceGeneration == generation else { return }
                self.partialTranscript = ""
                let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { self.onTranscript?(value) }
            }
            // Interim words heard so far — surfaced live so the user sees speech
            // is being captured. They are not sent; the finalized chunk above is
            // what appends to the message box.
            self.speech.onPartialResult = { [weak self] text in
                guard let self, self.voiceEnabled, self.voiceGeneration == generation else { return }
                self.partialTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        let started = midi.start(desiredInputPort: desiredInputPort, requireSpecificSource: requireSpecificSource, desiredSourceID: desiredSourceID) { [weak self] message in
            guard let self, self.isLearning, generation == self.midiGeneration,
                  message.isCC || message.isNoteOn,
                  let assignment = MIDIAssignment(learnMessage: message) else { return }
            self.capturedMIDI = SXMJSONMIDI(assignment)
            self.stopMIDI()
        }
        if !started {
            isLearning = false
            errorMessage = "MIDI capture is unavailable. Set a unique input port for this device, connect its controller, and finish other MIDI Learn sessions, then retry."
        }
    }

    func clearCapture() { stopMIDI(); capturedMIDI = nil }
    func stopMIDI() { midiGeneration += 1; midi.stop(); isLearning = false }
    func stopAll() {
        setVoiceEnabled(false)
        clearCapture()
        partialTranscript = ""
        onTranscript = nil
    }
}
