# Critical & High Review Fixes — Implementation Plan

> **For Claude:** REQUIRED: Execute via Agency (`agency_create_project` → `agency_assign` per task → evaluator per task), per user CLAUDE.md. Two-stage review at each chunk boundary. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all 5 CRITICAL and 12 HIGH findings from the 2026-06-11 four-subsystem review so TSI files round-trip losslessly, voice/wizard capture state is sound, MIDI parsing is memory-safe, and document dirty-state never cross-wires.

**Architecture:** Four independent chunks ordered by blast radius: (1) TSI serialization engine, (2) voice coordinator state machine, (3) wizard/MIDI capture, (4) document wiring. Each chunk compiles, tests green, and commits on its own. Spec: `docs/superpowers/specs/2026-06-11-critical-high-review-fixes-design.md`.

**Tech Stack:** Swift 5 / SwiftUI / AppKit hybrid, CoreMIDI, XCTest. Build root: `XtremeMapping/` (project `SuperXtremeMapping.xcodeproj`, scheme `XtremeMapping`).

**Verification commands (used throughout):**
```bash
cd XtremeMapping && set -o pipefail && xcodebuild -project SuperXtremeMapping.xcodeproj -scheme XtremeMapping build 2>&1 | tail -5
cd XtremeMapping && set -o pipefail && xcodebuild -project SuperXtremeMapping.xcodeproj -scheme XtremeMapping test -destination 'platform=macOS' -only-testing:XtremeMappingTests DEVELOPMENT_TEAM=9WJSZG8WF7 2>&1 | tail -20
```
(`set -o pipefail` is mandatory — without it the pipe reports `tail`'s exit status and a failed build reads as success. Alternatively redirect to a log file and grep "TEST SUCCEEDED".)
`DEVELOPMENT_TEAM=9WJSZG8WF7` is REQUIRED — the test target has no team configured and ad-hoc signing breaks test-bundle injection (Team ID mismatch). UI tests (`XtremeMappingUITests`) fail at baseline in this headless environment and are excluded from the gate.

**Baseline (2026-06-11, pre-chunk, after three test-only hygiene fixes):** 133 pass / 0 fail — GREEN. The hygiene fixes (committed before Chunk 1 as a standalone commit): (1) argument-order error in `testRoundTripPreservesControllerTypes`, (2) stale default-init expectations in `MappingEntryTests`, (3) five round-trip tests used category-prefixed command names ("Deck Common.Play/Pause") that nothing in the app produces — `id(for:)` correctly resolves only the unprefixed "Play/Pause". All chunks must keep this baseline green; each chunk's own acceptance is its NEW tests passing plus zero regressions.

---

## Chunk 1: TSI Round-Trip Integrity

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TraktorCommands.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/Enums/TargetAssignment.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/MappingEntry.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/Device.swift` (verify fields exist: comment, inPort, outPort)
- Test: `XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift`, `XtremeMapping/XtremeMappingTests/TraktorCommandsTests.swift`

### Task 1.1: Fix modifier-condition read layout (CRITICAL)

`TSIWriter.buildCMAD` writes per spec: ConditionOneId(4), ConditionOneTarget(4), ConditionOneValue(4), ConditionTwoId(4), ConditionTwoTarget(4), ConditionTwoValue(4) — 24 bytes after the comment. `TSIInterpreter.parseCMAD` (both branches: comment present at `modifierOffset`, no-comment at byte 52) reads only 16 bytes with a 4-field layout, so Value1 actually reads Target1, etc.

- [ ] Write failing tests in `TSIInterpreterTests` using the existing `roundTrip(_:)` helper: entries with (a) modifier1 only (e.g. M2=3), (b) modifier2 only, (c) both set, (d) none. Assert `modifier1Condition`/`modifier2Condition` survive exactly. Run; expect FAIL (values land in wrong fields).
- [ ] Fix both read branches in `parseCMAD`: Id1 at +0, skip Target at +4, Value1 at +8, Id2 at +12, skip Target2 at +16, Value2 at +20 (guard `offset + 24 <= data.count`).
- [ ] Run tests; expect PASS. Run full TSI test suite for regressions.

### Task 1.2: Close the command name↔ID round-trip (CRITICAL)

`TraktorCommands.name(for:)` produces dynamic names with no reverse path in `id(for:)`: "Slot N Cell M State" (IDs 665–728), "Duplicate Track Deck A–D" (2401–2404), "Deck X Pre-Fader Level (L)/(R)" (2688–2695), "Deck X Post-Fader Level (L)/(R)" (2696–2703). `id(for:)` returns 0 → writer emits TraktorControlId 0 → interpreter drops the mapping on next load.

- [ ] Write failing test in `TraktorCommandsTests`: for every ID in 601...728, 2401...2404, 2548...2555, 2688...2703, 2900...2923, assert `TraktorCommands.id(for: TraktorCommands.name(for: id)) == id`. Run; expect FAIL on the State/Duplicate/meter ranges.
- [ ] Add reverse parsing to `id(for:)`: "Slot N Cell M State" → base 664/680/696/712 + cell; "Duplicate Track Deck X" → 2401 + deck index; "Deck X Pre-Fader Level (L)" → 2688 + deck, "(R)" → 2692 + deck; "Post-Fader" → 2696/2700 + deck. Mirror the exact arithmetic in `name(for:)`.
- [ ] Safety net with ONE filter used by ALL frame builders: compute `let writableMappings = mappings.filter { TraktorCommands.id(for: $0.commandName) >= 1 }` ONCE at the top of `buildDevice` (excludes unresolvable names, "Command #0" — interpreter drops TraktorControlId 0 — and negative "Command #N") and pass it to `buildDDCI`, `buildDDCB`/`buildDCBM`, and `buildCMAS` alike. Filtering only inside `buildCMAS` would skew binding IDs: DCBM assigns IDs from the unfiltered list while CMAS indexes the filtered one, so a valid mapping after a skipped one would point at the wrong MIDI control after reload. Log each skip.
- [ ] Test: device with [invalid "Totally Unknown" mapping on CC 5, valid "Play/Pause" on CC 10] — round-trip keeps exactly the valid mapping AND its MIDI control is still CC 10 (binding-ID alignment), with no crash for "Command #-1" and "Command #0" variants.
- [ ] Run tests; expect PASS.

### Task 1.3: Preserve remix-slot targets 8–15 (HIGH)

- [ ] Add cases to `TargetAssignment`: `remixSlot1 = 9` … `remixSlot8 = 16` (continuing the +1 offset convention: TSI deck value = rawValue − 1 for non-negative cases). `displayName`: "Remix Slot N".
- [ ] Write failing round-trip test driven by TSI values, not enum cases: for each TSI deck value v in −1…15, build an entry whose assignment is the case that ENCODES to v (`.deviceTarget` for −1, `.deckA` for 0, …, `.remixSlot8` for 15) and assert it decodes back to that same case. Explicitly EXCLUDE `.none` and `.global` from survival assertions — both encode to 0 and decode as `.deckA` by documented design (add one assertion documenting that collapse instead). A test asserting `.global` survives would fail permanently.
- [ ] `TSIInterpreter` (~line 303 switch): map 8…15 → `.remixSlot1`…`.remixSlot8`. `TSIWriter` target encoding (~line 347): write remix cases back as 8…15. Keep `.global`/`.none` → 0 and document the Global/DeckA=0 ambiguity as-is.
- [ ] Run tests; expect PASS. Verify UI: assignment pickers that iterate `TargetAssignment.allCases` now show Remix Slots (no code change expected; confirm it compiles).

### Task 1.4: Non-BMP-safe UTF-16 encode AND decode (HIGH)

- [ ] Write failing round-trip test: entry with comment "Fire 🔥 emoji" and device name containing "🎛". Expect FAIL (crash or mangled text — wrap in XCTAssertNoThrow + equality).
- [ ] The round-trip test cannot exercise the DCBM control-name decode path (generated MIDI control names are ASCII). Make the shared UTF-16BE decode helper internal and unit-test it directly with a crafted big-endian byte sequence containing a surrogate pair (e.g. 🔥 = D83D DD25): assert exact decode. Then assert (by code inspection in review + a crafted DCBM frame test through `buildControlLookup` if practical) that all three former decode loops call the helper.
- [ ] `TSIWriter.encodeUTF16BEString` (line 501): length = `string.utf16.count`; emit each `string.utf16` code unit big-endian. Same fix for the inline DCDT string encode in `buildDDCI` (~line 160) — extract to use `encodeUTF16BEString` minus length prefix or duplicate the utf16 iteration.
- [ ] `TSIInterpreter`: replace per-code-unit `UnicodeScalar` decoding in ALL THREE paths — (1) comment parse (~line 415), (2) `readUTF16BEString` (device names), (3) the separate manual DCBM control-name loop at lines 131–147 — with one shared decode helper: collect `[UInt16]` big-endian code units, then `String(decoding: units, as: UTF16.self)`.
- [ ] Run tests; expect PASS.

### Task 1.5: Round-trip device metadata and per-mapping CMAD fields (HIGH)

Read side is the gap: `parseDevice` only reads name+mappings; writer already emits `device.comment`/`inPort`/`outPort` (with "All Ports" fallback). Per-mapping: AutoRepeat (CMAD bytes 16–19) and post-condition LED block are parsed never, written as constants.

- [ ] Verify `Device` has `comment`, `inPort`, `outPort` stored properties (it does — writer references them). Add `tsiVersion: String = "3.11.0"` and `mappingFileRevision: Int = 2`. **`Device` uses synthesized Codable (Device.swift:14), which fails on missing keys regardless of property defaults** — add an explicit `init(from:)` using `decodeIfPresent` + defaults for the two new keys (and keep synthesized `encode`), so previously-encoded Device data (e.g. drag/drop transferables, any persisted state) still decodes. Test: decode a JSON fixture lacking the new keys.
- [ ] `parseDevice`: after the device name, parse DDIV (version string + revision int), DDIC (comment), and DDPT (in/out port) frames into the Device. `TSIWriter` (~lines 97–111) writes these from the model instead of constants.
- [ ] Add `MappingEntry` fields with defaults matching today's written constants: `autoRepeat: Bool = false`, `ledMinRangeType: Int = 0`, `ledMinRangeData: Int = 0`, `ledMaxRangeType: Int = 0`, `ledMaxRangeData: Int = 1`, `ledMinMidi: Int = 0`, `ledMaxMidi: Int = 127`, `ledInvert: Bool = false`, `ledBlend: Bool = false`, `resolution: Int = 0`. CodingKeys are explicit — extend them; decode with `decodeIfPresent` + defaults so old saved app-state still loads.
- [ ] `parseCMAD`: read AutoRepeat at bytes 16–19; after the 24-byte condition block read LedMinControllerRange type+data (8), LedMaxControllerRange type+data (8), LedMinMidiRange(4), LedMaxMidiRange(4), LedInvert(4), LedBlend(4), skip unknownValueUIType(4), Resolution(4) — guard lengths, default when absent.
- [ ] `TSIWriter.buildCMAD` (lines ~423–463): replace the hardcoded AutoRepeat/LED-range/LED-midi/Invert/Blend/Resolution constants with the mapping's fields (UseFactoryMap stays 0).
- [ ] Write round-trip test: entry with autoRepeat=true, ledMinMidi=10, ledMaxMidi=100, ledInvert=true, ledMaxRangeData=5, resolution=2 plus device with comment "My controller", inPort "Port A", outPort "Port B", tsiVersion "3.10.0", mappingFileRevision 3. Run; expect PASS.

### Task 1.6: Direction-aware DCDT entries (HIGH)

- [ ] Write failing test: device with an IN mapping (button CC 20) and an OUT/LED mapping (controllerType .led or ioType .output) on the same CC 20. Parse the written bytes' DCDT frames; assert two entries exist with MidiControlType 7 (in) and 8 (out).
- [ ] `TSIWriter.buildDDCI`: derive direction per mapping (`ioType == .output` or LED controller type → out). Dedup key becomes `"\(controlName)|\(direction)"`. Emit MidiControlType 8 for out, 7 for in. Count prefix uses the new unique count.
- [ ] Confirm `TSIInterpreter.buildControlLookup` still resolves both entries (it keys DCDT by index; verify IN/OUT pair doesn't shift binding indices — adjust test fixture if DCBM ids are affected).
- [ ] Run tests; expect PASS. Full suite green.

### Task 1.7: Chunk 1 commit

- [ ] `xcodebuild build` + full `test` green.
- [ ] Commit: `fix(tsi): repair round-trip corruption — modifier conditions, dynamic command IDs, remix targets, non-BMP text, device metadata, direction-aware DCDT`

---

## Chunk 2: Voice Coordinator State

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Services/VoiceMappingCoordinator.swift`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift` (only if validation requires surfacing)
- Test: new `XtremeMapping/XtremeMappingTests/VoiceMappingCoordinatorTests.swift` (add to test target)

### Task 2.1: Consume pending state in processMapping (CRITICAL) + fix re-trigger (HIGH)

`processMapping()` (line ~324) never clears `pendingMIDI`/`pendingVoice` after the guard-let; `handleMIDIReceived` re-fires with a stale transcript. The post-processing re-trigger `if succeeded, pendingMIDI != nil, pendingVoice != nil, currentResult == nil` is unreachable (`currentResult` was just set when `succeeded`).

- [ ] Make `pendingMIDI`/`pendingVoice`/`isProcessing` (and the state-inspection surface needed for tests) `internal` rather than `private` if needed for the test target (`@testable import` covers internal).
- [ ] Write failing tests in new `VoiceMappingCoordinatorTests`: (a) after `processMapping` completes, `pendingMIDI == nil && pendingVoice == nil`; (b) simulate: process completes with result shown → `handleMIDIReceived(midi2)` → assert no second processing fires with the old transcript (inject a mock `ClaudeAPIService` — if the service isn't protocol-backed, add a minimal `CommandInterpreting` protocol that `ClaudeAPIService` conforms to and the coordinator stores; default argument keeps production wiring unchanged).
- [ ] Fix: at the top of `processMapping()`, after `guard let midi…, let voice…`, set `pendingMIDI = nil; pendingVoice = nil` AND clear the previous result pair: `currentResult = nil` (currentMIDI is then set to the new midi as today). Without this, a still-visible previous result + the overlay's Next-enable condition (`currentResult != nil && (currentMIDI != nil || pendingMIDI != nil)`, VoiceLearnOverlay.swift:290-292) lets the user save the OLD command against the NEW MIDI mid-processing. Additionally gate saving on `!isProcessing`: `saveAndContinue` returns early (status message) when `isProcessing`, and the overlay disables Next while processing. Test: seed a completed result, start processing a new pair, assert `saveAndContinue` refuses and `currentResult` is nil until the new result lands.
- [ ] Fix re-trigger: replace the condition with `if pendingMIDI != nil, pendingVoice != nil` (drop `succeeded`-gating for re-trigger of *new* inputs; keep not-retrying the same inputs on error — they were consumed, so an API error no longer loops).
- [ ] On API error, also clear `currentMIDI` and set a user-visible failed state (statusMessage already set) — the overlay must not show "Ready".
- [ ] Run tests; expect PASS.

### Task 2.2: Clear session state on deactivate (HIGH)

- [ ] Failing test: activate (or directly seed) → append to `sessionMappings`/`sessionMappingIds` → `deactivate()` → assert both empty.
- [ ] Fix: in `deactivate()` (line ~170), after `clearAllState()`, add `sessionMappings = []; sessionMappingIds = []`. Do NOT put them in `clearAllState()` — `saveAndContinue` calls it between captures and must keep the session.
- [ ] Run tests; expect PASS.

### Task 2.3: Validate Claude's command name (HIGH)

- [ ] Failing test: mock service returns high-confidence result with command "Totally Made Up Knob" → assert coordinator does not present "Press Next to save" (instead enters disambiguation or error state) and `saveAndContinue` refuses to create a mapping with an unknown command.
- [ ] Add `TraktorCommands.isKnownCommand(_ name: String) -> Bool`: true only when `allNames.contains(name)` (or, equivalently, `id(for:)` resolves via the lookup table / dynamic-range reverse parsing). It must REJECT "Command #N" fallback strings — `id(for:)` deliberately parses any "Command #N" (TraktorCommands.swift:24), so `id != 0` is NOT a valid known-ness test; "Command #99999" must be unknown. Unit-test both directions, including "Command #-1".
- [ ] Fix in `processMapping()` success path using `isKnownCommand(result.command)`. If unknown: filter `result.alternatives` to known commands; if any remain, route to disambiguation; else set error status and clear `currentResult`.
- [ ] Hardening (same root): covered by Chunk 1 Task 1.2's filtered `buildCMAS` — verify with a unit test that a mapping named "Command #-1" is skipped without crashing and the written frame count matches the emitted frames.
- [ ] Also filter unknown commands out of `buildDisambiguationOptions(from:)`, and add a final guard in `saveAndContinue`/`createMapping`: refuse (status message, no insertion) when the command name is unknown — `selectOption()` must never save an invalid alternative. Test: mock result with unknown primary + one known alternative → disambiguation shows only the known option; selecting it saves; a hand-seeded unknown `currentResult` is refused by `saveAndContinue`.
- [ ] Run tests; expect PASS. Full suite green.

### Task 2.4: Chunk 2 commit

- [ ] Build + test green.
- [ ] Commit: `fix(voice): consume pending inputs on process, reachable re-trigger, session reset on deactivate, validate command names`

---

## Chunk 3: Wizard & MIDI Input

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Utilities/MIDIInputManager.swift:130-157`
- Modify: `XtremeMapping/XtremeMapping/Services/WizardCoordinator.swift`
- Test: new `XtremeMapping/XtremeMappingTests/WizardCoordinatorTests.swift`

### Task 3.1: Safe MIDIEventList traversal (CRITICAL)

`handleMIDIEvents` copies `eventList.pointee` (header only) and walks `MIDIEventPacketNext` over a stack copy — undefined behavior past packet 1.

- [x] Replace the loop with CoreMIDI's safe iterator: `for packet in eventList.unsafeSequence() { for word in packet.words() { … } }` — `unsafeSequence()` iterates the original buffer; `words()` yields each UMP word, fixing both the stack-copy UB and the only-`words.0` truncation. Keep a `(word >> 28) == 2` MIDI-1.0-channel-voice check before extracting status/data bytes (skip other UMP message types).
- [x] This is pure pointer plumbing — no unit test can exercise CoreMIDI buffers meaningfully; verification is compile + existing manual smoke path. Build green.

### Task 3.2: Note-off never creates a capture (HIGH)

- [x] Failing tests in new `WizardCoordinatorTests` (coordinator is plain ObservableObject; drive `handleMIDIReceived` directly): (a) learning tab: note-on captures, subsequent note-off (value 0) does not add/replace a capture or restart auto-advance; (b) setup tab: a note-off does not become the shift assignment; (c) CC with value 0 still captures.
- [x] Fix order inside `handleMIDIReceived` per spec: shift-button state update first (must see note-offs for release), then `if message.note != nil && message.value == 0 { return }`, then setup-tab branch, then capture. (Move the `isShiftButton` check above the setup branch — guarded by `currentTab != .setup` so the shift button can still be assigned on the setup tab.)
- [x] Run tests; expect PASS.

### Task 3.3: nil/M1=0 dedup equivalence (HIGH)

- [x] Failing test: capture function F with `modifierCondition == nil` (no shift assigned), then assign shift and recapture F unshifted (M1=0) → assert exactly one capture for F remains.
- [x] Fix the removal predicate (line ~224): compare `($0.modifierCondition?.value ?? 0) == (modifier?.value ?? 0)`.
- [x] Run tests; expect PASS.

### Task 3.4: Shift state reset (HIGH)

- [x] Failing tests: (a) set `shiftMIDI` + `isShiftHeld = true`, call `beginLearning()` → both reset (shiftMIDI nil, isShiftHeld false); (b) simulate MIDI setup change → `isShiftHeld == false`.
- [x] Fix: reset `shiftMIDI = nil; isShiftHeld = false` in `beginLearning()`; subscribe the coordinator to the MIDI manager's setup-change path (add an `onSetupChanged` callback on `MIDIInputManager` fired from `handleSetupChange`, wired in `startMIDIListening`) → handler forces `isShiftHeld = false`.
- [x] Run tests; expect PASS. Full suite green.

### Task 3.5: Chunk 3 commit

- [ ] Build + test green.
- [ ] Commit: `fix(wizard,midi): safe event-list traversal, note-off capture guard, modifier dedup, shift state reset`

---

## Chunk 4: Document Wiring & Window Management

**Files:**
- Modify: `XtremeMapping/XtremeMapping/XtremeMappingDocument.swift:78-101`
- Modify: `XtremeMapping/XtremeMapping/XtremeMappingApp.swift` (DocumentGroup onAppear ~100-135; welcome-window sites ~495, ~525, ~561; DocumentWindowDelegateProxy ~642)
- Create: `XtremeMapping/XtremeMapping/Views/DocumentWindowAccessor.swift`
- Test: `XtremeMapping/XtremeMappingTests/DocumentTests.swift`

### Task 4.1: Window-backed document resolution + pending-dirty (CRITICAL)

- [ ] Failing tests in `DocumentTests`: (a) `noteChange()` with `backingDocument == nil` sets `hasPendingDirty` and does NOT touch any NSDocumentController fallback (assert no crash, flag set); (b) assigning `backingDocument` flushes the pending dirty via `updateChangeCount(.changeDone)` (use an NSDocument test double recording calls and assert count).
- [ ] `TraktorMappingDocument`: add `private(set) var hasPendingDirty = false`; `backingDocument` gets a `didSet` that flushes (`if hasPendingDirty { backingDocument?.updateChangeCount(.changeDone); hasPendingDirty = false }`).
- [ ] Rewrite `noteChange()`: keep `isDirty = true` + `objectWillChange.send()`; if `backingDocument` set → `updateChangeCount(.changeDone)`; else if `fileURL`-keyed `controller.document(for: fileURL)` resolves → cache + update; else `hasPendingDirty = true`. DELETE the `currentDocument` and `documents.first` fallbacks.
- [ ] Create `DocumentWindowAccessor: NSViewRepresentable` — zero-size NSView; on `didMoveToWindow`/async after attach, walks `view.window?.windowController?.document as? NSDocument` and calls a `(NSDocument) -> Void` callback.
- [ ] In the DocumentGroup closure, attach `.background(DocumentWindowAccessor { nsDoc in file.document.backingDocument = nsDoc })` to `ContentView` and DELETE the `documents.first(where:)` fallback in `onAppear` (keep the fileURL-keyed branch as fast path).
- [ ] Run tests; expect PASS. Manual check note for reviewer: two untitled docs, edit second, close it → save prompt appears on the edited one only.

### Task 4.2: Delegate proxy forwarding (HIGH)

- [ ] `DocumentWindowDelegateProxy`: hold `originalDelegate` strongly (`private let originalDelegate: NSWindowDelegate?`), add `override func responds(to:)` (self's selectors OR original's) and `override func forwardingTarget(for:)` returning the original delegate — mirror `AmberSelectionDelegateProxy` in `MappingsTableView.swift:474-486`.
- [ ] Unit test: proxy with a stub delegate implementing `windowWillClose` → `proxy.responds(to: #selector(NSWindowDelegate.windowWillClose(_:)))` is true and forwarding target resolves; `windowShouldClose` still intercepted by proxy.
- [ ] Build + tests green.

### Task 4.3: Welcome window by identifier (HIGH)

- [ ] In the welcome window's content (`WelcomeWindowContent`), embed a window accessor (`NSViewRepresentable`, reuse `DocumentWindowAccessor` generalized or a sibling `WindowIdentifierSetter`) that sets `window.identifier = NSUserInterfaceItemIdentifier("sxm-welcome")` on attach — do NOT assume SwiftUI propagates the scene id.
- [ ] Extract `static func isWelcomeWindow(_ window: NSWindow) -> Bool`: true when `identifier?.rawValue == "sxm-welcome"` or rawValue has prefix "welcome" (SwiftUI fallback). Never match titles.
- [ ] Replace all three `title.contains("Welcome")` sites (windowWillClose ~495, windowDidBecomeMain ~525, openWelcomeWindow ~561) with the helper. In `windowDidBecomeMain`, find the welcome window via `NSApplication.shared.windows.first(where: isWelcomeWindow)`.
- [ ] Unit test: offscreen `NSWindow` with identifier "sxm-welcome" and title "Anything" → true; window titled "Welcome Mix.tsi" with nil identifier → false.
- [ ] Build + tests green.

### Task 4.4: Chunk 4 commit

- [ ] Build + full test suite green.
- [ ] Commit: `fix(document): window-backed dirty tracking, delegate forwarding, welcome window by identifier`

---

## Acceptance (whole plan)

- [ ] All four chunks committed individually; `xcodebuild test` green at each commit.
- [ ] Round-trip fixture covers: modifiers, all 17 target values (−1…15), emoji, dynamic commands, device metadata, LED fields, IN/OUT DCDT.
- [ ] Two-stage review (requesting-code-review + fresheyes) clean per chunk.
- [ ] Pushed to origin/main (user-authorized this session).

## Rollback

Each chunk is one commit; `git revert <sha>` per chunk. No data-format migrations: writer output remains Traktor-spec-compatible; new MappingEntry fields decode with defaults.
