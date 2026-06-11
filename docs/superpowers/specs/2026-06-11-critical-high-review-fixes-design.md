# Critical & High Review Fixes — Design Spec

**Date:** 2026-06-11
**Source:** Four-subsystem parallel code review (TSI engine, voice pipeline, wizard/MIDI, document/app shell), all findings verified against source at review time.

## Problem Statement

The app's core promise — "your mappings survive editing" — is currently false. Five CRITICAL and twelve HIGH findings break round-trip data integrity, silently lose user work, or crash on save. Three of the five criticals share one root cause: read-side and write-side code disagreeing about the same bytes or the same state.

## Success Criteria (measurable)

1. A TSI file containing modifier conditions, remix-deck targets, slot-state commands, device ports, and LED settings survives load → save → load with zero field drift (verified by a round-trip unit test on a constructed fixture).
2. Saving a document whose comment contains an emoji (non-BMP scalar) does not crash and round-trips the text.
3. Voice flow: pressing a second MIDI control after a result is shown but before "Next" cannot pair the new control with the previous transcript (unit-testable via coordinator state).
4. Wizard: a note-off (or note-on velocity 0) never creates a capture; shift state is reset on session start and on MIDI setup change.
5. MIDI packet parsing iterates the real event list buffer (no stack-copy traversal).
6. With two documents open, editing one never marks the other dirty (noteChange resolves through the hosting window, never `currentDocument`/`documents.first`).
7. A document window titled "Welcome Mix.tsi" is never closed by welcome-window management.
8. All existing tests pass; new round-trip tests pass.

## Scope — Findings Addressed

### Chunk 1: TSI round-trip integrity (Models/TSI/TSIInterpreter.swift, Models/TSI/TSIWriter.swift, Models/TSI/TraktorCommands.swift, Models/Enums, Models/MappingEntry.swift, Models/Device.swift)
- **C1** Modifier-condition read layout: interpreter reads 4 fields where writer/spec use 6 (Id, Target, Value × 2). Read offsets must become Id@+0, skip Target@+4, Value@+8, Id2@+12, skip Target2@+16, Value2@+20.
- **C2** Asymmetric command name↔ID lookup: dynamic names ("Slot N Cell M State", "Duplicate Track Deck A–D", "Deck X Pre/Post-Fader Level") have no reverse mapping in `id(for:)` → TraktorControlId 0 → mapping dropped on next load. `id(for:)` must reverse every name `name(for:)` can produce.
- **H3** Target values 8–15 (remix slots) collapse to `.global` (0) on round-trip. **Model change required:** `TargetAssignment` gains eight explicit cases `remixSlot1…remixSlot8` (Swift raw values 9–16, continuing the existing +1 offset from TSI deck values; TSI 8–15 ↔ these cases on both read and write). Codable derives from Int raw value automatically; `displayName` gets "Remix Slot N"; existing UI pickers iterate `allCases` and pick the new cases up without layout changes. Round-trip test covers all seventeen TSI deck values −1…15 inclusive.
- **H4** `UInt16(char.value)` traps on non-BMP scalars in wide-string encode; length prefix must be UTF-16 code-unit count. Encode via `String.utf16`. **Decode side must change symmetrically in all three paths:** (1) the CMAD comment parse loop, (2) `readUTF16BEString` (device names), and (3) the separate manual per-code-unit DCBM control-name loop at TSIInterpreter.swift:131-147 — all decode one `UnicodeScalar` per 16-bit unit and drop surrogate pairs. Replace each with proper UTF-16BE decoding (collect big-endian `[UInt16]` code units, then `String(decoding:as: UTF16.self)`) so non-BMP text round-trips, not merely avoids crashing. Prefer one shared decode helper over three fixed copies.
- **H5** Device-level data loss: inPort/outPort/comment/version parsed never, written as constants; per-mapping AutoRepeat, LED fields, Resolution never parsed, written as constants. Parse and round-trip these fields:
  - `Device` gains `tsiVersion: String = "3.11.0"` and `mappingFileRevision: Int = 2` (DDIV frame: version string + revision int), parsed in `parseDevice` alongside DDIC comment and DDPT ports, written from the model instead of constants.
  - `MappingEntry` gains **flat stored fields only** (no tuples — `MappingEntry` relies on synthesized `Hashable`/`Equatable`, which tuples break): `autoRepeat: Bool`, `ledMinRangeType: Int`, `ledMinRangeData: Int`, `ledMaxRangeType: Int`, `ledMaxRangeData: Int` (writer currently hardcodes these at TSIWriter.swift:423-434; they round-trip opaquely), `ledMinMidi: Int`, `ledMaxMidi: Int`, `ledInvert: Bool`, `ledBlend: Bool`, `resolution: Int` — defaults matching today's written constants. **`MappingEntry` has a custom Codable implementation with required keys:** new fields must use `decodeIfPresent` + defaults in `init(from:)` and be added to `encode(to:)` and `CodingKeys`, so previously-encoded data decodes unchanged.
  - (DCDT-level encoderMode stays a documented limitation; UseFactoryMap stays constant 0.)
- **H6** DCDT control type hardcoded 7 (GenericIn) for all controls including LED/Out mappings (spec: 8 = Out). **Dedup must become direction-aware:** `buildDDCI` currently dedups DCDT entries by control name only, so an IN/OUT pair on the same physical control would still collapse. Key the dedup on (control name, direction) and emit type 7 for input-direction entries, 8 for output-direction entries (direction from `ioType`/LED controller type), matching how Traktor exports list the same control once per direction.

### Chunk 2: Voice coordinator state (Services/VoiceMappingCoordinator.swift, Services/ClaudeAPIService.swift, ContentView.swift)
- **C1** `processMapping()` must clear `pendingMIDI`/`pendingVoice` once consumed, so a later MIDI press cannot re-pair with a stale transcript.
- **H2** Re-trigger condition `succeeded && currentResult == nil` is unreachable (regression from two interacting fixes). With pending state cleared on consume, re-trigger whenever both pendings are set after processing completes.
- **H3** `deactivate()` must also clear `sessionMappings`/`sessionMappingIds` so an abandoned session can't poison later conflict/overwrite logic.
- **H4** Validate Claude's returned command against `TraktorCommands` before insertion; unknown commands go to disambiguation/error, never into the document. **Validation covers every path into the document:** (a) the primary `result.command` after the API returns, (b) every `CommandAlternative` offered in disambiguation (filter unknowns out of `buildDisambiguationOptions`), and (c) a final guard at the insertion seam (`saveAndContinue`/`createMapping` refuses unknown command names) so `selectOption()` can never save an invalid alternative.
- **Testability seam (prerequisite for this chunk's tests):** `VoiceMappingCoordinator` currently hard-wires concrete `MIDIInputManager` (private init), `VoiceInputManager`, and final `ClaudeAPIService`, and `processMapping` is private — deterministic state tests are impossible as-is. Introduce a minimal `CommandInterpreting` protocol (`func interpretCommand(transcript:availableCommands:) async throws -> VoiceCommandResult`) that `ClaudeAPIService` conforms to, inject it via a defaulted initializer parameter, and widen the needed members from `private` to `internal` for `@testable import`. Input managers may stay concrete if tests drive the coordinator's internal handlers directly (`handleMIDIReceived`/`handleTranscriptReady` made internal); no protocol needed for them.

### Chunk 3: Wizard & MIDI input (Services/MIDIInputManager.swift, Services/WizardCoordinator.swift)
- **C1** Replace stack-copy MIDIEventList traversal with `unsafeSequence()` iteration over the original buffer.
- **H2** Ignore note-off (note != nil && value == 0) in the wizard capture path. **Placement: at the top of `handleMIDIReceived`, before the Setup-tab shift-assignment branch** — the setup tab currently captures any message (including a note-off) as the shift assignment. The only earlier check is the shift-button state handler, which must still see note-offs (that's how shift release works). Order: shift-state update → note-off discard → setup/capture logic. CC value 0 stays valid.
- **H3** Dedup must treat `modifierCondition == nil` and `M1=0` as the same bucket when replacing captures.
- **H4** Reset **both** `shiftMIDI = nil` and `isShiftHeld = false` in `beginLearning()` (a stale `shiftMIDI` from a prior session would otherwise swallow the new session's first press as a shift toggle before Setup reassigns it), and force `isShiftHeld = false` on MIDI setup change (device disconnect). **Wiring (currently absent):** `MIDIInputManager` gains an internal `onSetupChanged: (() -> Void)?` callback invoked from its private `handleSetupChange()`; `WizardCoordinator` assigns it in `startMIDIListening()` and clears shift-held state in the handler. Test drives the callback directly (no CoreMIDI needed).

### Chunk 4: Document wiring & window management (XtremeMappingDocument.swift, XtremeMappingApp.swift)
- **C1/C2** `noteChange()` and the onAppear backing-document resolution must never fall back to `currentDocument`/`documents.first`. Resolution becomes window-backed: an `NSViewRepresentable` window accessor inside `ContentView` resolves `view.window?.windowController?.document` as soon as the view attaches to its window and assigns `backingDocument` (replacing the guessing fallbacks in both `noteChange()` and the DocumentGroup `onAppear`). The `fileURL`-keyed `controller.document(for:)` lookup may remain as a safe secondary (fileURL is unique per document). **Dropped changes must not lose dirty state:** if `backingDocument` is still unresolved when `noteChange()` fires, set a `pendingChangeCount` (or bool `hasPendingDirty`) on the SwiftUI document; when the window accessor resolves the backing document, flush it via `updateChangeCount(.changeDone)`. The custom `isDirty` flag (already set unconditionally at the top of `noteChange()`) keeps the in-app UI honest in the gap. Never cache a guessed document.
- **H3** `DocumentWindowDelegateProxy` must forward unhandled selectors to the original delegate (`responds(to:)` + `forwardingTarget(for:)`, mirroring `AmberSelectionDelegateProxy`) and hold the original delegate strongly.
- **H4** Identify the welcome window by `NSWindow.identifier`, never by title `contains("Welcome")`. **The identifier must be assigned deterministically, not assumed:** SwiftUI's `Window(id: "welcome")` is not guaranteed to set `NSWindow.identifier`. The welcome window's content view embeds a window accessor (`NSViewRepresentable`) that sets `window.identifier = NSUserInterfaceItemIdentifier("sxm-welcome")` on attach. The matching helper `isWelcomeWindow(_:)` returns `window.identifier?.rawValue == "sxm-welcome"` (also accept a SwiftUI-provided rawValue with prefix "welcome" as fallback). All three title-matching sites switch to the helper.

## Out of Scope (deferred, from MEDIUM/LOW)

Duplicate "Loop Out" command ID, CC-0 fabrication for unassigned mappings, silent empty-document on malformed DEVS, Claude API error-body parsing/timeouts/model pinning, Keychain delete-query hygiene, 14-bit CC, auto-advance cancel on Prev/Clear, stopMIDIListening on save, DMG mount main-thread block, NSDocumentDidSaveNotification fragility, stale ObjectIdentifier sets. These are real but below the requested CRITICAL+HIGH bar.

## Approach

Four chunks, ordered by blast radius: TSI engine first (data corruption), then voice, then wizard/MIDI, then document wiring. Each chunk is independently buildable and testable. **Every chunk lands with tests:**
- Chunk 1: round-trip tests extending the existing `roundTrip(_:)` helper in `TSIInterpreterTests` — modifier conditions (both set, one set, none), all seventeen target values (−1…15), emoji comment, dynamic command names (Slot Cell State, Duplicate Track, Pre/Post-Fader meters), device ports/comment, LED fields, IN/OUT DCDT pair.
- Chunk 2: `VoiceMappingCoordinator` state-transition tests — pending state cleared after processing, no stale-transcript re-pairing, session collections cleared on `deactivate()`, unknown command rejected.
- Chunk 3: `WizardCoordinator` tests — note-off creates no capture (setup tab and learning tabs), nil vs M1=0 dedup replaces rather than duplicates, shift state reset on `beginLearning()`.
- Chunk 4: `DocumentTests` additions — pending-dirty flush ordering (noteChange before resolution → flushed on resolution); welcome-window identification extracted into a pure helper (`isWelcomeWindow(_:)` matching `identifier` "welcome", with unit test on identifier vs title matching).

## Alternatives Considered

- **Fix only the read side of the modifier-condition mismatch vs. both sides:** writer already matches the spec (6 fields); only the interpreter is wrong. Fixing the writer instead would corrupt compatibility with real Traktor files. Read-side fix is the only correct option.
- **Reject unknown dynamic commands at write time (C2) vs. building full reverse lookup:** rejection still loses user data. Reverse lookup is mandatory; the parser/writer pair must be closed under round-trip.
- **Keep `.global` collapse and warn (H3) vs. preserving raw target values:** preserving raw values is strictly safer and simpler (pass-through int), chosen.
- **Patch welcome-window title match with a stricter string:** still a heuristic; window identifier is the principled fix.

## Blast Radius / Rollback

All changes confined to the XtremeMapping app target (no backend, no website). The TSI chunk touches the central serialization path — the round-trip test is the guard. Rollback: each chunk lands as its own commit; revert the offending commit. No schema/persistent-format migrations: the writer's output format is already spec-correct except where noted (H5/H6 add fields Traktor expects).

## Open Questions

- H5 scope: which of the unparsed per-mapping fields (AutoRepeat, LED ranges, Invert/Blend, Resolution) already have MappingEntry model fields vs. need new ones — resolved during planning by reading the model. New fields are acceptable since they serialize to the existing TSI layout, not a new format.
