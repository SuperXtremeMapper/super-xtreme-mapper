# Plan — Traktor binding fix

**Date:** 2026-06-13
**Spec:** [`2026-06-13-traktor-binding-fix-design.md`](../specs/2026-06-13-traktor-binding-fix-design.md)
**Status:** APPROVED (3-pass plan review, judge STOP-VELOCITY at pass 3)

**Review log:**
- Pass 1: 10 findings (2B/6S/1C). Both BLOCKERs (perDeck routing; Int vs UInt32) fixed in pass-2 revision.
- Pass 2: 10 findings (0B/7S/3C). All 7 SUBSTANTIVEs addressed in pass-3 revision (let→var, return nil, init line-range, rotarySensitivity decoder, test-assertion enumeration, B12 objective acceptance, hasValueUI by commandId).
- Pass 3: 5 findings (0B/4S/1C). Judge STOP-VELOCITY (5 < 10, no escalation). Pass-3 SUBSTANTIVEs applied as final plan edits before execution (B8 commandName literals enumerated, C2 read-confirm only, C6 commandId-based, B7 explicit logging).

Four chunks, executed in dependency order. Each chunk is its own Agency project task with verification before moving on.

---


> **Post-plan correction (Codex RCA, 2026-06-13):** direct decoding of `/Users/noahraford/Documents/Native Instruments/Traktor 4.4.1/Traktor Settings.tsi` shows remix-slot commands do **not** use a flat `Assignment = 8..11` model. For command IDs 239/249/250/251/259, Traktor overloads the CMAD target as `deckIndex * 4 + slotIndex`: Deck A slots 1-4 = targets 0-3, Deck B = 4-7, Deck C = 8-11, Deck D = 12-15. The implementation must use explicit deck+slot assignments and keep parser/writer symmetric.

## Chunk A — Universal CMAD scalar repairs

Bring every emitted CMAD into byte-parity with Traktor on the five value-independent scalar fields (`HasValueUI` is deferred to Chunk C as it's hotcue-conditional). Touches the writer + `MappingEntry` defaults only. No wizard changes.

### Steps

- [ ] **A1.** Read `XtremeMapping/Models/MappingEntry.swift:160-189` (initializer). Confirm field declarations and default values for:
  - `resolution`
  - `ledMinRangeType`, `ledMaxRangeType`
  - `rotarySensitivity`
  - `ledMinRangeData`, `ledMaxRangeData` (referenced for context only)
- [ ] **A2.** Change defaults in `MappingEntry`. **Fields are `Int`, not `UInt32`** (verified at MappingEntry.swift:77,83,101). Two surfaces must change for each field — the init default AND the `decodeIfPresent` fallback in `init(from decoder:)`. Otherwise legacy-saved JSON re-decodes to 0 and re-broken on save:
  - `resolution: Int = 1` (was 0). Update `decodeIfPresent(...) ?? 0` → `?? 1` at the decoder.
  - `ledMinRangeType: Int = 1` (was 0). Update decoder fallback too.
  - `ledMaxRangeType: Int = 1` (was 0). Update decoder fallback too.
  - `rotarySensitivity: Float = 5.0` (was 1.0). Update decoder fallback too if present.
  - Decoder fallbacks live at `MappingEntry.swift:231,233,239` per pass-1 reviewer; verify exact line at edit time.
  - **`rotarySensitivity` is a special case**: `MappingEntry.swift:226` uses `try container.decode(Float.self, forKey: .rotarySensitivity)` (plain decode, no fallback). Legacy JSON predating the field would throw. Either: (a) change to `decodeIfPresent(...) ?? 5.0`, OR (b) document that the field has always been present in saved files (verify against git history). Default: **(a)** — safer.
  - Init body spans lines 145-203 (signature 145-173, body 174-203).
- [ ] **A3.** Read `TSIWriter.swift:500-515` (the CMAD scalar write region per spec Defect 2). Locate the `UnknownVUI` constant — change its hardcoded `0` → `1`. The variable in the writer is `unknownVUI` per the forensics report (line 504-505).
- [ ] **A4.** Audit tests and update **only the right ones**.
  - Run: `grep -rn "ledMinRangeType\|ledMaxRangeType\|rotarySensitivity" XtremeMappingTests/` (the bare `resolution` term is too noisy — search on the more specific siblings and let context narrow `resolution` hits).
  - For each hit, classify by intent:
    - **"init default" test** → update assertion to the new default (1 or 5.0).
    - **"legacy JSON decode fallback" test** (e.g. `MappingEntryTests.swift:35-58` per pass-1 reviewer) → these intentionally validate the no-key-present path. With A2's `?? 1` decode-fallback update, they should now expect 1. Update.
    - **"specific scenario expects 0"** (rare) → leave; the test asserts a specific overridden value.
  - **`MappingEntryTests.swift:35-58` specifically**: only lines **49, 51, 57** flip (these are the `ledMinRangeType==0`, `ledMaxRangeType==0`, `resolution==0` assertions — change all three to `==1`). Lines 50 (`ledMinRangeData==0`) and 52 (`ledMaxRangeData==1`) test the DATA fields, which don't change defaults — leave as-is.
  - Run the full test suite after; any new failure is a missed update.
- [ ] **A5.** Build Release: `xcodebuild -project /Users/noahraford/Projects/XtremeMapping/XtremeMapping/SuperXtremeMapping.xcodeproj -scheme XtremeMapping -configuration Release -derivedDataPath /Users/noahraford/Projects/XtremeMapping/XtremeMapping/build build 2>&1 | tail -5`
- [ ] **A6.** Verify via decode script. Run the app, do a quick wizard pass on any tab (Mixer is fastest), save to `/tmp/chunkA_test.tsi`, then run:
  ```python
  # Decode /tmp/chunkA_test.tsi; for each of the first 5 CMAI frames, confirm:
  # CMAD +28 == 0x40a00000 (5.0)
  # CMAD +76 (LedMin.Type) == 1
  # CMAD +84 (LedMax.Type) == 1
  # CMAD +108 (UnknownVUI) == 1
  # CMAD +112 (Resolution) == 1
  ```

### Verification & acceptance

- xcodebuild succeeds.
- All XtremeMappingTests pass.
- Decode script confirms the five fields match Traktor reference values across 5 sampled CMAI frames.

### Files touched

- `XtremeMapping/Models/MappingEntry.swift`
- `XtremeMapping/Models/TSI/TSIWriter.swift`
- `XtremeMappingTests/*` (test fixtures)

---

## Chunk B — Slot commands: real IDs + Assignment-based slot index

Replace fabricated 2900-2923 IDs with canonical Traktor command IDs + `target = deckIndex * 4 + slotIndex` slot encoding.

### Steps

- [ ] **B1.** Confirm-only (no code change): `TargetAssignment.swift:49-58` has `remixSlot1..4` cases. Confirm `TSIWriter.swift:394-401` already maps them to slot-command target values 0-15.
- [ ] **B2.** Delete fabricated 2900-2923 block in `TraktorCommands.swift:143-163` (forward-lookup `id(for:)`). Also delete the matching reverse-lookup at `TraktorCommands.swift:207-220` (the `name(for: 2900...2923)` ranges). Add a comment explaining the deletion.
- [ ] **B3.** Add new computed property `slotAssignments` to `WizardSetupConfig.swift` (mirror the `deckAssignments` pattern at lines 21-27):
  ```swift
  var slotAssignments: [TargetAssignment] {
      [.remixSlot1, .remixSlot2, .remixSlot3, .remixSlot4]
  }
  ```
- [ ] **B4.** Rewire `sampleDecksFunctions` in `WizardTab.swift:130-167`. Reduce 24 numbered rows to **5 unnumbered rows** (FX Send deleted, leaving 5 categories — Volume / Mute / FX On / Filter / Filter On), each with the slot expansion driven by `currentAssignments`:
  - Volume row: `commandName: "Slot Volume"` (id 251).
  - Mute row: `commandName: "Slot Mute On"` (id 259).
  - **FX Send (lines 144-148): DELETED.** Slot FX Send is not a real Traktor command. Remove all 4 numbered rows; do not replace.
  - FX On row: `commandName: "Slot FX On"` (id 239).
  - Filter row (faderOrKnob): `commandName: "Slot Filter Adjust"` (id 249).
  - Filter On row (button): `commandName: "Slot Filter On"` (id 250).
  - **Each retained row MUST set `perDeck: false` explicitly.** `WizardFunction.perDeck` defaults to true (verify against the struct), and `WizardCoordinator.currentAssignments` checks `perDeck` FIRST — if true, it returns `setupConfig.deckAssignments` and the sampleDecks-tab branch never runs. Without `perDeck: false`, B5's change to `slotAssignments` does nothing. **Verification of this step is the wizard producing deck+slot target 0-15 in CMAI, not 0-3.**
  - Each retained row also has `displayName` simplified (no "Slot 1/2/3/4" prefix, since the wizard expands across slots automatically — e.g. just "Volume", "Mute", "FX On", "Filter", "Filter On"). User sees the slot-suffix added by wizard progress display.
- [ ] **B5.** In `WizardCoordinator.swift`, find `currentAssignments` (around line 79-86 per spec). For `currentTab == .sampleDecks`, return `setupConfig.slotAssignments` (= `[.remixSlot1..4]`) instead of `[.deckA..D]`.
- [ ] **B6.** In `WizardCoordinator.swift:104, 113` (`tabProgress`), replace the magic `+ 4` for `sampleDecks` with `setupConfig.slotAssignments.count`.
- [ ] **B7.** Legacy migration — TSIInterpreter post-parse fix-up. After Chunk B2, `TraktorCommands.name(for: 2900..2923)` returns "Command #2900" etc. (default fallback). Find where TSIInterpreter resolves command names (per spec hint, `TSIInterpreter.swift:582`). Add post-resolution fix-up: if the **raw control ID** (the parsed CMAI cmd-id, BEFORE going through `name(for:)`) is in `2900...2923`, rewrite `commandName` to the canonical equivalent AND **override `assignment` to the explicit Deck A Slot N target** (where N = (rawId - base) + 1), matching the broken K3 Deck A files that wrote target 0 alongside the fabricated command ID.

  Implementation notes:
  - Both `let commandName` (line 582) and `let assignment` (line 600) are immutable. Either **promote to `var`** before the fix-up block, or use new `finalCommandName` / `finalAssignment` local rebindings.
  - The override must come AFTER the existing assignment-derivation switch (around `TSIInterpreter.swift:600+`).
  - For the DROP case (2916..2919): **`return nil` from `parseCMAI`** AND log a warning via the existing logger ("Dropping legacy 'Slot N FX Send' binding from imported TSI — not supported in Traktor 4.4"). The caller at line 475 uses `if let` so nil works cleanly. The parsed-frame counter (line 473) increments before the parse call, so the declared-vs-parsed invariant survives. Without the log, dropped bindings are silently lost.

  Specific mapping:
  ```
  2900..2903 → "Slot Volume"        / .remixSlot1..4
  2904..2907 → "Slot Mute On"       / .remixSlot1..4
  2908..2911 → "Slot Filter Adjust" / .remixSlot1..4
  2912..2915 → "Slot Filter On"     / .remixSlot1..4
  2916..2919 → DROP (Slot FX Send — no Traktor equivalent). Log warning, skip the binding entirely.
  2920..2923 → "Slot FX On"         / .remixSlot1..4
  ```
- [ ] **B8.** Legacy migration — JSON `MappingEntry.init(from decoder:)` at approximately `MappingEntry.swift:209`. After decoding `commandName` and `assignment`, key the rewrite on the **exact pre-fix commandName strings** the wizard emitted (read pre-fix `WizardTab.swift:130-167` to confirm — these were `"Slot 1 Volume"` through `"Slot 4 Filter On"` plus `"Slot N FX Send"`). Map each literal:
  ```
  "Slot 1 Volume"|"Slot 2 Volume"|… → "Slot Volume",        assignment = .remixSlot1..4
  "Slot N Mute"                     → "Slot Mute On",       assignment = .remixSlot1..4
  "Slot N Filter"                   → "Slot Filter Adjust", assignment = .remixSlot1..4
  "Slot N Filter On"                → "Slot Filter On",     assignment = .remixSlot1..4
  "Slot N FX On"                    → "Slot FX On",         assignment = .remixSlot1..4
  "Slot N FX Send"                  → DROP from collection. Log warning.
  ```
  If MappingEntry's JSON also persists the numeric `commandId`, prefer ID-based match (`2900..2923` ranges); otherwise the string literals above are the source of truth.
- [ ] **B9.** Update tests:
  - `XtremeMappingTests/TraktorCommandsTests.swift:131-164` — delete slot-ID assertions; remove `2900...2923` from the no-overlap fence at line 164.
  - Any test that asserts a wizard mapping for a Slot N command produces commandId 2920+ — update to expect 239 + Deck A target N-1.
- [ ] **B10.** Build Release.
- [ ] **B11.** Verify via wizard: do a Sample Decks wizard pass mapping Slot 1 FX On + Slot 2 Volume + Slot 3 Mute + Slot 4 Filter On. Save to `/tmp/chunkB_test.tsi`. Decode-script verifies:
  - Slot 1 FX On → commandId 239, Assignment 8
  - Slot 2 Volume → commandId 251, Assignment 9
  - Slot 3 Mute On → commandId 259, Assignment 10
  - Slot 4 Filter On → commandId 250, Assignment 11
- [ ] **B12.** Round-trip verify: open the broken v4 file (`/Users/noahraford/Documents/Native Instruments/Traktor 4.4.1/K3 - Deck A - Dubai - June 26_v4.tsi`) in the rebuilt app. Objective checks:
  - No mapping has `commandName` matching `Command #29[0-2][0-9]`.
  - Every mapping that started as `"Slot N <Op>"` now has the canonical commandName (Volume / Mute On / Filter Adjust / Filter On / FX On).
  - Binding count = `original_binding_count - count(2916..2919 in original)` — i.e. the FX Send rows dropped, everything else preserved.

### Verification & acceptance

- xcodebuild green.
- All tests pass.
- Decode-script results match expectations.
- v4 round-trip cleanly migrates legacy bindings.

### Files touched

- `XtremeMapping/Models/TSI/TraktorCommands.swift`
- `XtremeMapping/Models/Wizard/WizardSetupConfig.swift`
- `XtremeMapping/Models/Wizard/WizardTab.swift`
- `XtremeMapping/Services/WizardCoordinator.swift`
- `XtremeMapping/Models/TSI/TSIInterpreter.swift`
- `XtremeMapping/Models/MappingEntry.swift`
- `XtremeMappingTests/TraktorCommandsTests.swift`
- Other tests as `grep` surfaces

---

## Chunk C — Hotcue ID migration + Loop cleanup

Migrate per-hotcue rows from non-existent IDs 214-221 to Traktor 4.4's canonical id 2328 (Select/Set+Store Hotcue) with `setToValue` selecting the hotcue index. Remove broken loop rows.

### Steps

- [ ] **C1.** Add optional field to `WizardFunction` (`WizardFunction.swift`):
  ```swift
  let setToValue: Float?  // default nil
  ```
  Pass through `init` — all existing call sites use named init args, so adding a parameter with `nil` default is backward-compatible.
- [ ] **C2.** Confirm `setToValue: Float` parameter exists on `MappingEntry.init` (signature spans `MappingEntry.swift:145-203`). Verified at `:225` (decode) and `:160` (default 0.0) per pass-2 reviewer — no change expected; this step is a read-confirm only.
- [ ] **C3.** Extend `WizardCapturedMapping.toMappingEntry` (`WizardFunction.swift:62-74`) to pass `setToValue: function.setToValue ?? 0` through to `MappingEntry`.
- [ ] **C4.** In `WizardTab.swift:91-98`, change Hotcue rows 1-8:
  ```swift
  WizardFunction(displayName: "Hotcue 1", commandName: "Select/Set+Store Hotcue",
                 controllerType: .button, interactionMode: .hold, isBasic: true,
                 setToValue: 0)
  // ...through Hotcue 8 with setToValue: 7
  ```
  **InteractionMode decision:** keep `.hold` for parity with the wizard's current behavior. If Traktor's mapping editor shows the binding as wrong-typed, switch to `.trigger` as a follow-up.
- [ ] **C5.** In `WizardTab.swift:99-102` (Loop rows): **DELETE Loop In, Loop Out, Loop Active, Loop Size rows.** Traktor 4.4 has no direct equivalents. Document in release-note comment.
- [ ] **C6.** Handle the conditional `HasValueUI=1` for Hotcue 2328. Locate the CMAD scalar emit function in `TSIWriter.swift` (per pass-1: `hasValueUI` is hardcoded around line 430 as `var hasValueUI = UInt32(0).bigEndian`). The function takes the `MappingEntry` as input (verify by reading the surrounding function signature). Replace the hardcoded `0` with:
  ```swift
  let isIndexedHotcue = TraktorCommands.id(for: mapping.commandName) == 2328
  var hasValueUI = UInt32(isIndexedHotcue ? 1 : 0).bigEndian
  ```
  Prescribed: **commandId-based check** (more resilient than string equality — survives any future commandName rewording for id 2328).
- [ ] **C7.** Build Release.
- [ ] **C8.** Verify via wizard Cue/Loop pass mapping Hotcue 1-4 (across decks per `perDeck=true`). Save to `/tmp/chunkC_test.tsi`. Decode-script verifies for each binding:
  - commandId == 2328
  - Assignment ∈ {0,1,2,3} (Deck A-D)
  - SetToValue ∈ {0,1,2,3} (Hotcue index)
  - HasValueUI == 1

### Verification & acceptance

- xcodebuild green.
- Decode-script confirms 2328 + Assignment + setToValue + HasValueUI for hotcue bindings.
- Cue/Loop wizard tab no longer offers Loop In/Out/Active/Size.

### Files touched

- `XtremeMapping/Models/Wizard/WizardFunction.swift`
- `XtremeMapping/Models/Wizard/WizardTab.swift`
- `XtremeMapping/Models/MappingEntry.swift`
- `XtremeMapping/Models/TSI/TSIWriter.swift`

---

## Chunk D — End-to-end Traktor verification (human-in-loop)

User runs the rebuilt app, exercises the success-criteria scenarios from the spec (S1-S5):
1. **S1** — Mixer tab end-to-end.
2. **S2** — Decks tab end-to-end.
3. **S3** — Cue/Loop tab Hotcues.
4. **S4** — Sample Decks tab (Slot 1 FX On + Slot 2 Volume + Slot 3 Mute On + Slot 4 Filter On).
5. **S5** — Re-save of broken v4 file.

For each scenario the user:
- Opens the rebuilt app.
- Runs the wizard for that tab.
- Saves to a new file.
- Imports into Traktor 4.4 via controller manager.
- Confirms (a) the mappings appear in Traktor's mapping editor under the imported device, and (b) the physical control actually fires the assigned Traktor command.

### Steps

- [ ] **D1.** Rebuild the app one final time (after Chunks A+B+C committed-locally but not pushed).
- [ ] **D2.** Hand the build to user with the scenario list.
- [ ] **D3.** User reports each S1-S5 outcome.
- [ ] **D4.** If any S fails, capture the failing file + return to the appropriate chunk for re-investigation. Do not skip to commit on partial success.

### Acceptance

S1-S5 all green per the user. No code-only substitution accepted.

---

## Re-applied earlier session fixes (auto-preserved)

The pipeline starts with these in the working tree. They survive the do-it commit:
- 1-channel option in `WizardSetupView.swift` + `WizardSetupConfig.swift`
- `ModeSelectionWindow.selectGuidedMode` direct document passing
- `TSIWriter` DEVI-name coerce to "Generic MIDI" via `recognizedDeviceNames` whitelist

If a chunk step accidentally clobbers any of these, restore from the spec text.

---

## Rollback

If any chunk fails verification and the cause is deeper than the plan anticipated:
- Revert that chunk's git changes (`git checkout HEAD -- <files>`).
- Either iterate on the plan or surface to user for re-scope.

Final commit is one commit covering all chunks; revert the commit to roll back everything.
