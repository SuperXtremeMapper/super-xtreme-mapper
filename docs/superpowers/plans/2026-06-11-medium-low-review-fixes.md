# Medium & Low Review Fixes — Implementation Plan

> **For Claude:** REQUIRED: Execute via Agency, two-stage review per chunk, per user CLAUDE.md. Checkbox steps.

**Goal:** Land the deferred MEDIUM/LOW robustness fixes (TSI corruption surfacing, voice/API error quality, wizard listening/timer hygiene, updater safety) with zero regressions on the 184-test baseline.

**Architecture:** Four chunks mirroring subsystem boundaries, executed sequentially, one commit each. Spec: `docs/superpowers/specs/2026-06-11-medium-low-review-fixes-design.md`.

**Tech Stack / verification:** same as the CRITICAL/HIGH plan —
```bash
cd XtremeMapping && set -o pipefail && xcodebuild -project SuperXtremeMapping.xcodeproj -scheme XtremeMapping test -destination 'platform=macOS' -only-testing:XtremeMappingTests DEVELOPMENT_TEAM=9WJSZG8WF7 2>&1 | tail -20
```
**Baseline:** 184 pass / 0 fail at HEAD 6c7f176.

---

## Chunk 1: TSI Robustness

**Files:** Modify `Models/TSI/TSIInterpreter.swift`, `Models/TSI/TSIWriter.swift`, `Models/TSI/TraktorCommands.swift`, `Models/TSI/CommandHierarchy.swift` (UI command source — duplicates the "Loop Out" name at lines 208 and 222), `XtremeMapping/docs/TSI-File-Format.md`. Tests: `TSIInterpreterTests.swift`, `TraktorCommandsTests.swift`, new `TSIParserTests` additions if parser-level.

### Task 1.1: Surface malformed-DEVS instead of silent empty/partial documents (M10)
- [x] Failing tests: (a) DEVS declaring 2 devices where the second DEVI frame is truncated → `interpret` throws (build bytes by writing a valid 2-device file via TSIWriter then truncating); (b) zero-device file still opens as valid empty MappingFile.
- [x] `parseNestedFrames` (TSIInterpreter.swift:652-668): propagate nested parse errors instead of `break`-swallowing mid-stream (tolerate only clean end-of-data after all declared frames).
- [x] `interpret`: read the DEVS 4-byte count, compare against parsed DEVI device count, throw descriptive error on mismatch.
- [x] Same contract one layer down: `parseMappings` (~TSIInterpreter.swift:213-249) validates the CMAS 4-byte mapping count vs parsed CMAI frames and propagates malformed-CMAI failures (no skip-and-return-partial). Failing test: valid device, CMAS declaring 2 mappings with the second truncated → throws. NOTE: the writableMappings filter from the C/H pass intentionally writes FEWER CMAI than mappings exist in the model — the count it writes is already the filtered count, so no conflict; assert that in a test.
- [x] Run; PASS. Confirm document layer surfaces the throw (existing read path).

### Task 1.2: Unassigned mappings — explicit sentinel, no fabricated CC 0 (M9)
- [x] Failing round-trip test: MappingEntry with `midiNote = nil, midiCC = nil` round-trips with both still nil and no "Ch01.CC.000" string anywhere in the written bytes.
- [x] `TSIWriter`: when a mapping has no MIDI assignment — `midiControlName(for:)` callers at lines ~159 (DDCI/DCDT), ~230 (DCBM), ~271 (CMAS binding id) — skip DCDT/DCBM entries for it and emit CMAI `MidiNoteBindingId = 0xFFFFFFFF` (DCDT's −1 unassigned convention, TSI-File-Format.md:120).
- [x] `TSIInterpreter` mapping parse (~line 265-279): ONLY binding id 0xFFFFFFFF decodes to nil note/cc; a non-sentinel id missing from the DCBM lookup THROWS (corruption — folds into Task 1.1's validation). Tests for both: sentinel round-trips unassigned; crafted file with a dangling binding id throws.
- [x] Run; PASS.

### Task 1.3: Distinct names for distinct commands + deterministic resolution (M8)
- [x] Failing test: every value in `commandLookup` is unique (exhaustive duplicate scan), and IDs 201 and 2393 BOTH survive `id(for: name(for: id)) == id`.
- [x] Rename 2393 (advanced-deck block, paired with 2392 "Loop In / Set Cue") to a distinct name following the section's convention — "Loop Out / Set" unless the CMDR reference table (https://cmdr-editor.github.io/cmdr/) names it otherwise; 201 ("Loop Out", CUE/LOOP) keeps its name. These are two different Traktor commands — canonicalizing to one ID would silently change user mappings.
- [x] `id(for:)`: replace dictionary iteration with a lazily-precomputed `[String: Int]` name→lowest-id map as a deterministic backstop for any future duplicate.
- [x] REQUIRED (highest-risk area per spec review): `CommandHierarchy.swift` carries the same duplicate — `CommandItem(id: 2393, name: "Loop Out")` at ~line 222 (and 201 at ~208). ContentView creates mappings from CommandHierarchy NAMES (ContentView.swift:803/918), so an un-renamed hierarchy entry would still produce a "Loop Out" mapping that resolves to 201. Rename the 2393 hierarchy entry identically to the TraktorCommands rename.
- [x] Cross-consistency test: for every `CommandItem` in `CommandHierarchy.allCategories` (or equivalent), assert `TraktorCommands.id(for: item.name) == item.id` — pins hierarchy↔lookup consistency for ALL commands, not just this pair.
- [x] Run; PASS.

### Task 1.4: Doc + cosmetic hardening
- [x] TSI-File-Format.md FX-target table: FX1–4 = 4–7 (matches verified code), note Global/DeckA = 0 collapse.
- [x] `TSIWriter`: `UInt32(clamping:)` for ledMin/MaxMidi, range data, resolution writes; replace skip-log `print` with `Logger(subsystem:category:)`.
- [x] Build + suite green.

### Task 1.5: Chunk commit
- [ ] Commit: `fix(tsi): surface corrupt frames, real unassigned sentinel, deterministic duplicate command IDs`

---

## Chunk 2: Voice/API Robustness

**Files:** Modify `Services/ClaudeAPIService.swift`, `Services/APIKeyManager.swift` (the pure `KeySnapshotStore` may live in this file or a new `Services/KeySnapshotStore.swift` — implementer's call), `Services/Speech/AppleSpeechProvider.swift`, `Services/VoiceMappingCoordinator.swift`, `ContentView.swift` (insertMapping injection + onChange relay removal; check VoiceLearnOverlay for any `savedMappingCount` references and update if present). Tests: `VoiceMappingCoordinatorTests.swift`, new `ClaudeAPIServiceTests`/`APIKeyManagerTests` for pure parts.

### Task 2.1: API error quality, timeout, current model (M7)
- [x] Failing test (pure): error-body parsing — given Anthropic error JSON `{"type":"error","error":{"type":"rate_limit_error","message":"..."}}` and status 429, the thrown error's description contains the message (extract parsing into a testable internal func).
- [x] `ClaudeAPIService`: `request.timeoutInterval = 30`; on non-2xx parse the error body and throw an error carrying status + message (429 wording: rate limit); replace `claude-3-haiku-20240307` with `claude-haiku-4-5`.
- [x] Request-construction tests (buildRequest at ~line 187 made internal if not already): assert `timeoutInterval == 30` and the JSON body's `model == "claude-haiku-4-5"` — both spec-required and unit-testable, not review-only.
- [x] Run; PASS. Coordinator surfaces `error.localizedDescription` already.

### Task 2.2: Keychain hygiene (M8 + L)
- [x] `APIKeyManager`: search-only delete query (`kSecClass`, `kSecAttrService`, `kSecAttrAccount` only); log non-success OSStatus from add/delete/load via `Logger`. Threading: two-tier store — lock-backed nonisolated snapshot (NSLock or OSAllocatedUnfairLock) that `activeKey` reads synchronously from any context; `saveAPIKey`/`deleteAPIKey` write the snapshot synchronously (immediately visible to callers — NOT a bare main-async write) then mirror to the main-actor `@Published` property for UI. The sync `activeKey` provider closure in ClaudeAPIService/ContentView keeps compiling unchanged.
- [x] Extract the lock-backed snapshot into a small internal type (e.g. `KeySnapshotStore`: `write(_:)`/`read()` under NSLock) with NO Keychain dependency — `APIKeyManager` composes it; Keychain calls stay in the manager and are review-verified per the spec's OS-bound constraint.
- [x] Test (pure, no Keychain): `KeySnapshotStore.write` followed immediately by `read` on the same thread returns the new value; concurrent reads/writes under `DispatchQueue.concurrentPerform` don't crash or tear. Plus `isValidKeyFormat` boundary tests.
- [x] Unit tests: `isValidKeyFormat` boundaries (the Keychain calls themselves are environment-bound; review covers them).
- [x] Run; PASS.

### Task 2.3: Stale speech-task guard (M5)
- [x] `AppleSpeechProvider`: in every `SFSpeechRecognitionTaskDelegate` callback, guard `task === recognitionTask` (store the current task; stale callbacks return early). Remove/guard the 0.3s `asyncAfter` start (~line 164): capture the request it was created for and bail if `recognitionRequest !== capturedRequest`.
- [x] Tests (spec requires attempting a seam): the delegate methods take the task parameter — drive them directly with two distinct `SFSpeechRecognitionTask`-typed tokens if constructible, else extract the identity check into an internal `isCurrent(_ task:)` and unit-test that with object-identity doubles; the delayed-start guard: call the extracted start-block with a swapped request and assert no task starts. If neither seam is practicable after inspection, document explicitly in the completion notes and the guard is review-verified. *(Implemented: `isCurrent(_:)` delegates to static AnyObject-identity `isCurrentToken`; delayed start extracted into `startDelayedRecognitionTask(for:)` behind static `shouldStartDelayedTask`. SFSpeechRecognitionTask is not directly constructible, so the identity logic is tested via the static seams + the instance-level delayed-start no-op with a real SFSpeechAudioBufferRecognitionRequest.)*

### Task 2.4: Locked-document save divergence (M6)
- [x] Failing test: coordinator with an injected `insertMapping` closure returning nil (locked) → `saveAndContinue` does NOT grow `sessionMappings` and sets an explanatory status (not "Saved!"); closure returning a UUID → appended + id registered.
- [x] Replace the `.onChange(of: savedMappingCount)` relay (ContentView.swift:232): ContentView injects `insertMapping: (MIDIMessage, VoiceCommandResult) -> UUID?` (calling `addVoiceMapping`) into the coordinator at activation; `saveAndContinue` calls it synchronously, appends/registers only on non-nil, else "Document is locked — mapping not saved". DELETE the `savedMappingCount`/`savedMapping` published members and the onChange — single path only. *(On a refused save the coordinator keeps `currentResult`/`currentMIDI` so the user can unlock and press Next again without re-capturing.)*
- [x] Run; PASS (existing coordinator tests that relied on the relay get updated to the closure seam).

### Task 2.5: Chunk commit
- [ ] Commit: `fix(voice,api): error-body surfacing + timeout + current model, keychain hygiene, stale-task guard, locked-doc save honesty`

---

## Chunk 3: Wizard UX Correctness

**Files:** Modify `Services/WizardCoordinator.swift`, `Models/Wizard/WizardFunction.swift` (dead `channel:` param on `toMappingEntry` at line 61; call site WizardCoordinator.swift:332), wizard window/view for close hook. Tests: `WizardCoordinatorTests.swift`.

### Task 3.1: Auto-advance cancellation on navigation (M6)
- [x] Failing tests (autoAdvanceEnabled = true): pending advance then (a) `previous()`, (b) `clearCurrentMapping()`, (c) `switchToTab(_:)`, (d) `cancel()`, (e) `performSave()` → after >0.8s, position/phase unchanged by any stray advance.
- [x] Add `cancelAutoAdvance()` at the top of all five (plus `reset()` if distinct from cancel) AND `saveToDocument()` — it returns early to show the overwrite-conflict alert before `performSave` ever runs, so a pending advance would otherwise fire while the alert is open (test: pending advance + saveToDocument-with-conflict → no advance). Belt-and-braces: the auto-advance firing closure (or `next()`) guards `phase == .learning` so a stray task can never mutate a completed/cancelled wizard. Test the guard directly: force-fire with phase == .complete → no-op.
- [x] Run; PASS.

### Task 3.2: Stop listening on save/close (M7)
- [x] Failing test: drive to `performSave`/`.complete` → midiManager listening stopped (assert via the coordinator's listening flag or manager callback nil — pick the observable seam).
- [x] `performSave` completion → `stopMIDIListening()`. Wizard window content: `onDisappear { coordinator.cancel() }` (verify cancel() is idempotent and doesn't clobber a completed save's state — guard on phase).
- [x] Run; PASS.

### Task 3.3: Conflict/overwrite scope + dead param (L10, L9)
- [x] Align conflict detection and overwrite removal to the same scope (`devices[0]`, where the wizard inserts). Test: conflicting mapping in devices[1] no longer counts.
- [x] Remove dead `channel:` param from `toMappingEntry` and fix the call site.
- [x] Run; PASS.

### Task 3.4: Chunk commit
- [ ] Commit: `fix(wizard): cancel auto-advance on navigation, stop MIDI listening on save/close, align overwrite scope`

---

## Chunk 4: Updater & App-Shell Hygiene

**Files:** Modify `Services/UpdateService.swift`, `Views/UpdateAvailableSheet.swift` (call site `try updateService.mountDMG(at:)` at line ~129 — becomes `try await` when mount goes async), `XtremeMappingApp.swift`, `XtremeMappingDocument.swift`, `Commands/EditCommands.swift`, `Views/MappingsTableView.swift`. Tests: `DocumentTests.swift`, new `UpdateServiceTests` for version logic.

### Task 4.1: Version compare with pre-release awareness (L10)
- [x] Failing tests: current "0.5-beta" vs remote "v0.5" → update offered; "0.5" vs "v0.5-beta" → NOT offered; "0.9" vs "0.10" still correct; equal versions → not offered.
- [x] Rework `parseVersion`/`isNewerVersion`: parse into (numerics, isPrerelease); numeric compare first; if equal, release > pre-release. *(New `parseVersionInfo` returns `(numerics, isPrerelease)`; `isNewerVersion` is now a nonisolated static taking RAW strings — `checkForUpdate` passes `release.tagName` and `currentVersion` unstripped so both sides keep their suffix. `parseVersion(from:)` kept for display/ignore in the sheet.)*
- [x] Run; PASS.

### Task 4.2: Download/mount safety (M6, L8)
- [x] Move BOTH blocking paths off the main actor (`UpdateService` is @MainActor): the byte-streaming `FileHandle.write` loop in `downloadUpdate` (lines ~176, 216-223) and `mountDMG`'s `waitUntilExit` run in a nonisolated/`Task.detached` worker; progress published back to main batched per chunk. `mountDMG`: `Process.terminationHandler` + continuation; non-zero exit throws (best-effort detach if partially attached). *(`Task.detached` wrappers chosen because the target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + approachable concurrency, where a bare nonisolated async func would inherit the main actor. Best-effort detach is moot: a failed `hdiutil attach` leaves nothing mounted to detach.)*
- [x] `downloadUpdate`: delete the partial DMG in the catch path; verify byte count vs `asset.size` when size > 0 (mismatch → throw + delete, new `UpdateError.sizeMismatch`); progress: when both expectedContentLength and asset.size are ≤ 0, report indeterminate (no division — new `isDownloadProgressIndeterminate` published flag, sheet shows an indeterminate bar). Call site `UpdateAvailableSheet` updated to `try await mountDMG`.
- [x] Unit-test the pure decision bits if extracted (size check); process plumbing is review-verified. Build green. *(Extracted `resolveExpectedLength`/`progressFraction`/`isDownloadSizeValid`, all unit-tested in new `UpdateServiceTests.swift`.)*

### Task 4.3: Dirty-clear on save via NSDocument association (M5)
- [x] Failing test: registry association — assigning `backingDocument` registers NSDocument→TraktorMappingDocument in a static weak/weak `NSMapTable`; `markClean(nsDocument:)` clears `isDirty` for the associated doc even when fileURL is nil (untitled).
- [x] Implement registry maintenance at `backingDocument` assignment; `SaveCallbackStore.document(_:didSave:contextInfo:)` calls the instance-level markClean (NSDocument identity first, URL fallback). Keep the notification observer.
- [x] Run; PASS.

### Task 4.4: Stale-table pruning + clipboard observation (M7-rest, L9)
- [x] `AmberSelectionDelegateProxy.installedTables`: replace the grow-forever `Set<ObjectIdentifier>` with `NSHashTable<NSTableView>.weakObjects()` membership (dead tables vanish; recycled addresses re-install cleanly).
- [x] `ClipboardManager` is ALREADY ObservableObject with @Published state — the fix is only `EditCommands` observing it (`@ObservedObject var clipboard = ClipboardManager.shared`) so `.disabled(...)` re-evaluates on copy. Verify the Commands scene compiles; behavior check is manual (note for reviewer: confirm Paste Mapped to / Paste Modifiers enable immediately after a copy with a row selected).
- [x] Test: ClipboardManager publishes objectWillChange on copyMappedTo/copyModifiers (subscribe, assert emission) — keeps the observation contract pinned.
- [x] Run; PASS. *(Suite: 301 pass / 0 fail — 279 baseline + 22 new.)*

### Task 4.5: Chunk commit
- [ ] Commit: `fix(updater,shell): prerelease-aware updates, safe download/mount, instance-keyed dirty clearing, observed clipboard state`

---

## Acceptance (whole plan)
- [ ] Four commits, suite green at each (184 baseline + new tests, zero regressions).
- [ ] Two-stage review clean per chunk; pushed to origin/main (user-authorized).

## Known limitations recorded (not silently dropped)
14-bit CC pairing; per-word Task delivery ordering; DMG cryptographic verification; Keychain/SFSpeech/hdiutil paths verified by review rather than unit tests (OS-bound).

## Rollback
One commit per chunk; `git revert` per chunk. M10 makes previously-"openable" corrupt files error out — intended behavior change, called out in the commit message.
