# Voice Mapping Feature Design

**Date:** 2026-01-15
**Status:** Ready for Implementation

## Overview

A "Voice Learn" mode that lets users speak natural commands while interacting with their MIDI controller. The app captures both inputs (in any order), uses Claude API to interpret the voice command, and creates the mapping automatically.

## User Flow

1. User clicks "Voice Learn" button (or presses shortcut) → mode activates
2. App starts listening for MIDI input AND voice simultaneously
3. User moves a fader → MIDI captured (e.g., Ch2 CC 14)
4. User says "I want this to control the volume on Deck B"
5. App sends transcription to Claude with the list of Traktor commands
6. Claude returns: `{"command": "Deck Volume", "assignment": "Deck B", "confidence": 0.95}`
7. If confidence is high → mapping created, row appears highlighted in table
8. If confidence is low or ambiguous → show top 3-5 options with descriptions
9. User selects via voice ("one"), keyboard (1), or click
10. Mapping created, highlighted briefly in table
11. App continues listening for next MIDI+voice pair until user toggles off

## Architecture

### New Components

```
XtremeMapping/
├── Services/
│   ├── Speech/
│   │   ├── SpeechRecognitionProvider.swift  # Protocol for swappable providers
│   │   ├── AppleSpeechProvider.swift        # Apple Speech framework (default)
│   │   └── WhisperKitProvider.swift         # WhisperKit (future)
│   ├── VoiceInputManager.swift              # Delegates to speech provider
│   ├── ClaudeAPIService.swift               # Claude API for intent understanding
│   └── VoiceMappingCoordinator.swift        # Orchestrates MIDI + voice + API
├── Views/
│   └── VoiceLearnOverlay.swift              # UI overlay for voice mode
└── Models/
    └── VoiceCommandResult.swift             # Response model from Claude
```

### Speech Provider Abstraction

To allow swapping speech recognition backends (Apple Speech now, WhisperKit later), we use a protocol-based abstraction:

```swift
/// Protocol for swappable speech recognition providers
protocol SpeechRecognitionProvider: AnyObject {
    var isListening: Bool { get }
    var transcript: String { get }

    /// Start listening for speech input
    func startListening() async throws

    /// Stop listening
    func stopListening()

    /// Called when a complete transcript is ready (after silence detection)
    var onTranscriptReady: ((String) -> Void)? { get set }

    /// Called with partial results during recognition (optional)
    var onPartialResult: ((String) -> Void)? { get set }
}
```

**Implementations:**

1. **AppleSpeechProvider** (Phase 1) - Uses `SFSpeechRecognizer`, real-time streaming, zero cost
2. **WhisperKitProvider** (Future) - Uses WhisperKit, better accuracy, ~1-2s latency

The `VoiceInputManager` delegates to the active provider:

```swift
class VoiceInputManager: ObservableObject {
    @Published var isListening = false
    @Published var transcript: String = ""

    private var provider: SpeechRecognitionProvider

    init(provider: SpeechRecognitionProvider = AppleSpeechProvider()) {
        self.provider = provider
        setupProviderCallbacks()
    }

    /// Swap provider at runtime (e.g., from settings)
    func setProvider(_ provider: SpeechRecognitionProvider) {
        self.provider.stopListening()
        self.provider = provider
        setupProviderCallbacks()
    }
}
```

**Benefits:**
- Swap implementations without touching coordinator or UI code
- A/B test providers easily
- Future settings toggle: "Use enhanced recognition (WhisperKit)"

### State Management

The coordinator holds two "pending" slots:

```swift
class VoiceMappingCoordinator: ObservableObject {
    @Published var isActive = false
    @Published var pendingMIDI: MIDIMessage?
    @Published var pendingVoice: String?
    @Published var disambiguationOptions: [CommandOption]?
    @Published var isProcessing = false

    // When both slots filled → process → clear
}
```

### Component Details

#### 1. VoiceInputManager

Uses Apple's Speech framework for on-device speech-to-text.

```swift
class VoiceInputManager: ObservableObject {
    @Published var isListening = false
    @Published var transcript: String = ""
    @Published var isFinal = false

    func startListening()   // Begin speech recognition
    func stopListening()    // End speech recognition

    var onTranscriptReady: ((String) -> Void)?  // Callback when speech ends
}
```

**Key behaviors:**
- Uses `SFSpeechRecognizer` for recognition
- Detects end of speech via silence (1.5 second pause)
- Handles microphone permissions gracefully
- Works continuously in toggle mode

#### 2. ClaudeAPIService

Sends transcribed text + command list to Claude for interpretation.

```swift
class ClaudeAPIService {
    func interpretCommand(
        transcript: String,
        availableCommands: [String]
    ) async throws -> VoiceCommandResult
}

struct VoiceCommandResult: Codable {
    let command: String           // e.g., "Deck Volume"
    let assignment: String?       // e.g., "Deck B"
    let controllerType: String?   // e.g., "Fader"
    let confidence: Double        // 0.0 - 1.0
    let alternatives: [CommandAlternative]?  // Top 3-5 other guesses
}

struct CommandAlternative: Codable {
    let command: String
    let assignment: String?
    let description: String      // Brief explanation for disambiguation UI
    let confidence: Double
}
```

**Prompt design:**
```
You are a Traktor DJ mapping assistant. Given a voice command, identify:
1. The Traktor command name (from the provided list)
2. The target assignment (Deck A/B/C/D, FX Unit 1-4, Global, etc.)
3. The controller type (Button, Fader, Encoder) if inferrable
4. Your confidence level

Available commands: [list of 500+ commands]

User said: "{transcript}"

Respond in JSON format with your best match and up to 5 alternatives.
```

#### 3. VoiceMappingCoordinator

Orchestrates the entire flow.

```swift
@MainActor
class VoiceMappingCoordinator: ObservableObject {
    @Published var isActive = false
    @Published var pendingMIDI: MIDIMessage?
    @Published var pendingVoice: String?
    @Published var disambiguationOptions: [CommandAlternative]?
    @Published var isProcessing = false
    @Published var statusMessage: String = ""

    private let midiManager: MIDIInputManager
    private let voiceManager: VoiceInputManager
    private let claudeService: ClaudeAPIService

    func activate()     // Start listening to both MIDI and voice
    func deactivate()   // Stop all listening

    func selectOption(_ index: Int)  // User picked from disambiguation
    func dismissOptions()            // User cancelled disambiguation

    // Internal: called when both MIDI and voice are captured
    private func processMapping() async
}
```

**Processing logic:**
```swift
private func processMapping() async {
    guard let midi = pendingMIDI, let voice = pendingVoice else { return }

    isProcessing = true
    statusMessage = "Understanding command..."

    do {
        let result = try await claudeService.interpretCommand(
            transcript: voice,
            availableCommands: TraktorCommands.allNames
        )

        if result.confidence > 0.85 {
            // High confidence - create mapping directly
            createMapping(midi: midi, result: result)
        } else {
            // Low confidence - show options
            disambiguationOptions = [result.asAlternative] + (result.alternatives ?? [])
        }
    } catch {
        // API failed - show top fuzzy matches as fallback
        disambiguationOptions = fuzzyMatch(voice, limit: 5)
    }

    isProcessing = false
    pendingMIDI = nil
    pendingVoice = nil
}
```

#### 4. VoiceLearnOverlay

Minimal UI overlay shown when voice mode is active.

```swift
struct VoiceLearnOverlay: View {
    @ObservedObject var coordinator: VoiceMappingCoordinator

    var body: some View {
        VStack {
            // Status indicator (listening, processing, etc.)
            // Pending MIDI indicator (if captured)
            // Pending voice indicator (if captured)
            // Disambiguation options (if showing)
        }
    }
}
```

**Disambiguation UI:**
```
┌─────────────────────────────────────────────┐
│  Which command did you mean?                │
│                                             │
│  [1] Deck Volume (Deck B)                   │
│      Controls the volume fader for Deck B   │
│                                             │
│  [2] Headphone Volume                       │
│      Controls headphone/cue volume          │
│                                             │
│  [3] Master Volume                          │
│      Controls main output volume            │
│                                             │
│  Say a number, press 1-3, or click          │
│  [Cancel]                                   │
└─────────────────────────────────────────────┘
```

## API Key Management

### Settings Storage

```swift
class APIKeyManager {
    // User's own key (stored in Keychain)
    var userAPIKey: String?

    // Built-in key with rate limiting (fetched from server or bundled)
    var sharedAPIKey: String?

    // Which key to use
    var activeKey: String? {
        userAPIKey ?? sharedAPIKey
    }

    // Track usage for shared key limits
    var dailyUsageCount: Int
    let dailyLimit = 50  // Requests per day for shared key
}
```

### Settings UI Addition

Add to Settings/Preferences:
- "Voice Mapping API Key" field
- "Use your own Anthropic API key for unlimited voice commands"
- Show current usage if using shared key: "12/50 commands today"

## Permissions

The app will need:
- **Microphone access** - For speech recognition
- **Speech recognition** - For Apple's Speech framework

Add to Info.plist:
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Super Xtreme Mapper uses speech recognition for voice-controlled mapping.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Super Xtreme Mapper needs microphone access for voice commands.</string>
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| No microphone permission | Show alert with link to System Settings |
| Speech recognition unavailable | Disable voice feature, show message |
| Claude API error | Fall back to fuzzy keyword matching |
| API rate limit hit | Show "Limit reached, add your own API key" |
| No MIDI input detected | Show "Move a control on your MIDI device" |
| Unrecognized command | Show top 5-10 fuzzy matches |

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Create `SpeechRecognitionProvider` protocol
- [ ] Create `AppleSpeechProvider` implementing the protocol
- [ ] Create `VoiceInputManager` that delegates to provider
- [ ] Create `ClaudeAPIService` with basic prompt
- [ ] Create `VoiceCommandResult` model
- [ ] Add microphone/speech permissions to Info.plist

### Phase 2: Coordination & State
- [ ] Create `VoiceMappingCoordinator`
- [ ] Integrate with existing `MIDIInputManager`
- [ ] Implement "both captured" → process flow
- [ ] Add pending state management

### Phase 3: UI
- [ ] Create `VoiceLearnOverlay` view
- [ ] Add toggle button to toolbar
- [ ] Implement disambiguation UI
- [ ] Add keyboard shortcuts (1-5 for selection)
- [ ] Add voice number recognition for selection

### Phase 4: API Key Management
- [ ] Create `APIKeyManager`
- [ ] Add Keychain storage for user key
- [ ] Add settings UI for API key
- [ ] Implement rate limiting for shared key

### Phase 5: Polish & Edge Cases
- [ ] Add row highlighting on mapping creation
- [ ] Handle permission denials gracefully
- [ ] Add fallback fuzzy matching
- [ ] Test with various phrasings
- [ ] Optimize Claude prompt for accuracy

## Testing Plan

### Unit Tests
- VoiceCommandResult parsing
- Fuzzy matching algorithm
- Rate limiting logic

### Integration Tests
- MIDI + Voice coordination timing
- Claude API response handling
- Disambiguation flow

### Manual Testing
- Various natural phrasings ("volume", "vol", "the volume knob", etc.)
- All 500+ commands coverage
- Different MIDI controller types
- Permission denial flows

## Future Enhancements (Out of Scope)

- Voice feedback/confirmation ("Volume assigned")
- Custom voice command aliases
- Batch voice mapping ("map all these to Deck A")
- Offline mode with local LLM
- Voice-activated modifier setup

## Dependencies

- **Apple Speech Framework** - Built into macOS, no external dependency (Phase 1)
- **WhisperKit** (Future) - Swift package for on-device Whisper, ~40-150MB model
- **Anthropic Claude API** - Requires API key, ~$0.003 per request (Haiku)
- **Existing MIDIInputManager** - Already implemented

## Open Questions

None - ready for implementation.
