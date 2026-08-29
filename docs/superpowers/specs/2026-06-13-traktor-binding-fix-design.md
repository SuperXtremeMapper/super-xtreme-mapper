# Traktor binding fix — design spec

**Date:** 2026-06-13
**Status:** APPROVED (passed 3-pass spec review, judge STOP-VELOCITY at pass 3)
**Owner:** Noah Raford (Claude assisting)

**Review log:**
- Pass 1: 13 findings (3B/7S/1C/2NC). 3 BLOCKERs fixed in pass-2 revision.
- Pass 2: 10 findings (3B/6S/1C/1E + 2NC). 3 BLOCKERs fixed in pass-3 revision.
- Pass 3: 5 findings (0B/3S/1C/1R). Judge STOP-VELOCITY. Three remaining SUBSTANTIVE findings deferred to plan stage:
  - (i) Chunk C step 1: enumerate `WizardFunction` field addition (`setToValue: Float?`), `toMappingEntry()` propagation, and `MappingEntry.init` signature check.
  - (ii) Chunk B step 7 migration: split into two insertion points — `MappingEntry.init(from decoder:)` for app-saved JSON, plus `TSIInterpreter` post-parse fix-up for `name(for: 2900..2923)` legacy reads.
  - (iii) Chunk C: confirm or change `interactionMode` for Hotcue 2328 (currently `.hold` for the per-hotcue 214-221 IDs; 2328's parameterized semantics may need `.trigger` or `.hold` differently).

## Problem statement

> **Post-plan correction (Codex RCA, 2026-06-13):** direct decoding of a locally owned Traktor 4.4.1 settings export shows remix-slot commands do **not** use a flat `Assignment = 8..11` model. For command IDs 239/249/250/251/259, Traktor overloads the CMAD target as `deckIndex * 4 + slotIndex`: Deck A slots 1-4 = targets 0-3, Deck B = 4-7, Deck C = 8-11, Deck D = 12-15. The implementation must use explicit deck+slot assignments and keep parser/writer symmetric.


Wizard-produced .tsi files appear in Traktor 4.4's controller-manager list when added from disk, but Traktor's mapping editor shows **zero** bindings under them. The wizard, voice mapping, and manual mapping all flow through the same writer (`TSIWriter`), so the bug almost certainly affects every emit path.

Empirically verified by decoding a locally owned Traktor 4.4 settings export (2.4 MB, 7 device entries — 5 Generic MIDI + 2 native NI), the failure modes are:

### Defect 1 — Many wizard command IDs no longer exist in Traktor 4.4

The wizard emits Traktor-3-era command IDs that have been removed or renumbered in Traktor 4.4. Evidence: in the user's own Traktor settings (a definitive source of "what Traktor 4.4 recognizes"), **zero** bindings reference IDs 214-221 (Hotcue 1-8), 200 (Loop In), or 2900-2923 (the wizard's fabricated slot range). The IDs that Traktor 4.4 actually uses for the equivalent functions:

| Wizard says | Wizard emits | Real Traktor 4.4 ID | How slot/index is encoded |
|---|---|---|---|
| Hotcue 1-8 | 214-221 | **2328** ("Select/Set+Store Hotcue") | per-deck binding (`Assignment = 0..3` for Deck A-D) + **`SetValueTo = 0..7` selects the hotcue index** (CMAD +44). The field exists in `MappingEntry.swift:60` as `setToValue: Float`; the writer reads it at `TSIWriter.swift:446`. A full hotcue mapping = (decks × hotcue indices) — wizard expansion required, see Chunk C step 1 |
| Slot N FX On | 2920-2923 | **239** ("Slot FX On") | `target = deckIndex * 4 + slotIndex` (CMAD +12) |
| Slot N Volume | 2900-2903 | **251** ("Slot Volume") | `target = deckIndex * 4 + slotIndex` |
| Slot N Filter On | 2912-2915 | **250** ("Slot Filter On") | `target = deckIndex * 4 + slotIndex` |
| Slot N Filter Adjust | (no entry) | **249** ("Slot Filter Adjust") | `target = deckIndex * 4 + slotIndex` |
| Slot N Mute | 2904-2907 | **259** ("Slot Mute On") | `target = deckIndex * 4 + slotIndex` |
| Slot N FX Send | 2916-2919 | **Does not exist** | — must be removed from wizard |
| Loop In | 200 | (Traktor 4.4 uses 2317/2318 etc. for loop sizing; no direct "Loop In") | needs design call (see Open Q1) |
| Loop Out | 201? | Same as above | — |

The wizard's `WizardTab.cueLoopFunctions` (`WizardTab.swift:89-103`) and `sampleDecksFunctions` (lines 130-167) need to be re-targeted. The fabricated slot-ID block in `TraktorCommands.swift:143-163` (and the matching reverse-lookup at lines 207-220) must be deleted.

### Defect 2 — Three CMAD scalar fields default to 0 where Traktor consistently writes 1 (or 5.0)

Field-by-field decode of a wizard CMAI vs a real-Traktor CMAI of the same command revealed these universal deltas (apply to every binding the wizard emits):

| Field | CMAD offset | Wizard value | Traktor value | Touch site |
|---|---|---|---|---|
| RotarySensitivity | +28 | 1.0 (f32) | 5.0 (f32) | `TSIWriter.swift` (search for sensitivity write) |
| LedMin.Type | +76 | 0 | 1 | `TSIWriter.swift` LED-range writer |
| LedMax.Type | +84 | 0 | 1 | same |
| UnknownVUI | +108 | 0 (hardcoded) | 1 | `TSIWriter.swift:504-505` |
| Resolution | +112 | 0 (default) | 1 | `TSIWriter.swift:508-509` |
| HasValueUI (for indexed hotcue only) | +36 | 0 | 1 | Hotcue-specific branch in writer — handled in Chunk C, NOT Chunk A |

> **Important:** CMAD offsets above assume an empty `Comment` field. The Comment is variable-length UTF-16BE prefixed by a 4-byte length. With a non-empty comment, every offset after CMAD +48 shifts. Plan stage anchors changes by symbolic field name (the writer's variable names), not by absolute byte offset.

Whether all six are individually load-bearing is unverified. Two hypotheses:
- **(H1)** All six are required — Traktor's loader checks each.
- **(H2)** Only some are — others are cosmetic Traktor-side defaults that don't gate the binding from loading.

We will fix all six because the fix is cheap. The post-fix Traktor-load test confirms which were load-bearing.

### Defect 3 — DDCI/DCDT catalog size is **not** a defect (pass-1 reviewer corrected)

Pass-1 reviewer initially claimed Traktor needs 4112 (or 8216) DCDT entries. Reverification with the user's actual references:
- `kalo DF (Deck AB) 2021` — Generic MIDI, confirmed loadable, has **4104** DCDT entries.
- `TKTR New FX and volume knobs.tsi` — Generic MIDI, confirmed loadable, has **2** DCDT entries.
- Wizard's broken K3 v4 — Generic MIDI, fails to bind, has **58** DCDT entries.

The 2-entry working file disproves the "Traktor needs full catalog" hypothesis. **DCDT catalog size is not the bug.** Removed from scope (was Chunk D in v1).

### Defect 4 — Wizard's deck/slot conflation in `WizardCoordinator`

`WizardCoordinator.currentAssignments` returns `[.deckA, .deckB, .deckC, .deckD]` for the `sampleDecks` tab (line 84). Conceptually wrong: sample-deck slot commands should target `[.remixSlot1..4]`. The TargetAssignment enum already has these cases at `TargetAssignment.swift:49-58` (raw values 9-12), and `TSIWriter.swift:394-401` already serializes them to the correct slot-command target values 0-15 (verified). So this is a one-line change in the coordinator plus follow-on consequences in `tabProgress` (`WizardCoordinator.swift:104, 113` — magic `+ 4` for `sampleDecks`).

### Preserved fixes from the current uncommitted working tree

Three valid in-progress fixes from earlier this session must be carried through:
- 1-channel option in `WizardSetupView.swift` and `WizardSetupConfig.swift`.
- `ModeSelectionWindow.selectGuidedMode` passing the new document directly.
- `TSIWriter` coerce of DEVI name to "Generic MIDI" via `recognizedDeviceNames` whitelist.

These were verified end-to-end by the user during this session (the file loads in Traktor; commands appear absent because of the defects above).

## Success criteria

A user runs the wizard, picks any wizard tab (mixer / decks / cue-loop / fx / sample-decks / browser / loop-recorder), maps every offered function for that tab, saves the file, imports into Traktor 4.4, and **the mappings appear in Traktor's mapping editor and the physical control fires the assigned Traktor command**. End-to-end verification requires a human-in-the-loop Traktor test — code review and unit tests are insufficient (the existing test suite passes on the broken behavior, confirming tests cover round-trip-within-the-app only).

Specific must-work scenarios for sign-off:
- **S1 — Mixer tab end-to-end.** Volume faders, EQ, crossfader, gain. Sets a floor: if any tab works, this one will.
- **S2 — Decks tab end-to-end.** Play/Cue/Sync per deck.
- **S3 — Cue/Loop tab.** Hotcue 1-4 bindings fire (using the migrated 2328 + SetValueTo encoding). Loop functions either work or are removed-with-design-note (see Open Q1).
- **S4 — Sample Decks tab.** Slot 1 FX On + Slot 2 Volume + Slot 3 Mute On + Slot 4 Filter On — at least one binding per slot to prove the Assignment-based slot encoding works.
- **S5 — Re-save of an existing broken file (v2/v3/v4).** Producing a working file. This proves the writer coerce, not just the wizard, was fixed.

Out of scope (explicitly):
- Voice mapping and manual mapping paths — they use the same writer and so benefit as a side-effect, but explicit verification is **deferred**.
- TSI export for native NI hardware (Kontrol X1/S2/S4) — the existing `recognizedDeviceNames` whitelist routes these through a different DEVI-name path; we don't touch them.
- Full audit of every other Traktor-3-era command ID in `TraktorCommands.swift` beyond the cue/loop/slot ranges (Open Q4).

## Proposed approach

Four chunks. Each is independently shippable and individually verifiable. Sequence matters: A before B (B reuses A's writer changes); C is independent of A/B; E (verification) is last.

### Chunk A — Universal CMAD scalar repairs

Bring every emitted CMAD into byte-parity with Traktor on the six value-independent scalar fields (Defect 2). Affects every binding emitted by `TSIWriter`, including manual-add and voice paths as a side-effect.

Touch sites (all in `XtremeMapping/Models/TSI/TSIWriter.swift`):
- `UnknownVUI` constant write site (around line 504-505) — change 0 → 1.
- `Resolution` default (around line 508-509 and `MappingEntry.swift` default) — change 0 → 1.
- `LedMin.Type` / `LedMax.Type` default — change 0 → 1.
- `RotarySensitivity` default — change 1.0 → 5.0.

Exact line numbers will be confirmed against the working tree during plan-writing; spec asserts the existence of these write sites, plan documents the exact lines.

**Acceptance:**
- Build green (`xcodebuild` Release).
- Decode-script run on a fresh wizard-saved TSI shows the six CMAD fields above match Traktor's reference values on **at least 5 sampled CMAI frames from different command-ID classes** (button, fader, encoder, LED, hotcue, slot).
- No unit test added — verification is done via the decode script. (Existing tests asserting the old broken values must be updated.)

### Chunk B — Slot commands: real IDs, real Assignment

Replace the fabricated 2900-2923 ID range with a slot-aware emit path using real Traktor command IDs and Assignment-based slot encoding.

Steps:
1. **Verify TargetAssignment & serializer (no code change).** Confirm `TargetAssignment.swift:49-58` has `remixSlot1..8` cases at raw values 9-12 and `TSIWriter.swift:394-401` maps them to slot-command target values 0-15. No code change; commit a comment if helpful.
2. **`TraktorCommands.swift:143-163` — delete the fabricated 2900-2923 `id(for:)` block.** Also delete the matching reverse-lookup ranges at `TraktorCommands.swift:207-220` (per reviewer Finding #13). After this, `TraktorCommands.id(for: "Slot 1 FX On")` returns 0 — the wizard must stop producing that name.
3. **`WizardTab.swift:130-167` — rewire `sampleDecksFunctions` to use canonical names.** Concrete row → command mapping (canonical name → TraktorCommands.swift line):
   - `Slot N Volume` → `"Slot Volume"` (id 251, line 339)
   - `Slot N Mute` → `"Slot Mute On"` (id 259, line 347)
   - `Slot N FX On` → `"Slot FX On"` (id 239, line 327)
   - `Slot N Filter` (faderOrKnob, lines 157-160) → `"Slot Filter Adjust"` (id 249, line 337)
   - `Slot N Filter On` (button, lines 163-166) → `"Slot Filter On"` (id 250, line 338)
   - **`Slot N FX Send` rows (lines 144-148) — DELETED.** Slot FX Send is not a real Traktor command. See Open Q3 for UX mitigation.
4. **`WizardCoordinator.swift:84` — `currentAssignments` for `sampleDecks` tab returns `[.remixSlot1, .remixSlot2, .remixSlot3, .remixSlot4]`** instead of `[.deckA, .deckB, .deckC, .deckD]`.
5. **`WizardCoordinator.swift:104, 113` — `tabProgress` magic `+ 4` for `sampleDecks`** — replace with a computed `slotAssignments.count`. `slotAssignments` is **a new computed property** on `WizardSetupConfig` (mirrors the existing `deckAssignments` pattern at `WizardSetupConfig.swift:21-27`) returning `[.remixSlot1, .remixSlot2, .remixSlot3, .remixSlot4]`. Define it in the same file as the existing `deckAssignments`. Without this property + the `tabProgress` change, the progress bar miscounts.
6. **Update test fixtures.** Concrete enumeration:
   - `XtremeMappingTests/TraktorCommandsTests.swift:131-164` — hardcodes the 2900-2923 IDs and includes a "no-overlap" range fence at line 164 covering `2900...2923`. Delete the slot-ID assertions; remove `2900...2923` from the fence.
   - Any voice/manual-path test asserting MappingEntry default `ledMinRangeType==0`, `ledMaxRangeType==0`, `resolution==0`, or `rotarySensitivity==1.0` (see Chunk A acceptance) — update to the new Traktor-compatible defaults.
   - Plan stage enumerates the full list via `grep -rn "2900\|2901\|2902\|2903\|2904\|2905\|2906\|2907\|2908\|2909\|2910\|2911\|2912\|2913\|2914\|2915\|2916\|2917\|2918\|2919\|2920\|2921\|2922\|2923\|ledMinRangeType\|ledMaxRangeType\|resolution\|rotarySensitivity" XtremeMappingTests/`.
7. **Legacy `commandName` migration (load-time guard).** Old saved documents and old TSIs may carry `commandName="Slot 1 Volume"` etc. After Chunk B, `TraktorCommands.id(for: "Slot 1 Volume")` returns 0 — the writer's `writableMappings` filter at `TSIWriter.swift:100-107` will silently drop them. Add a one-shot migration in `TSIInterpreter.swift` (where mappings are loaded): if `commandName` matches the legacy `"Slot [1-4] <X>"` form, rewrite to canonical name + set `assignment` accordingly. Symmetric story for `commandName="Slot N FX Send"` (no replacement): drop with a logger warning so users notice.

**Acceptance:**
- Build green.
- A fresh wizard run mapping `Slot 1/2/3/4 FX On` produces 4 CMAIs with `TraktorControlId=239` and `target=0,9,10,11`. Verified via decode script.
- A fresh wizard run mapping `Slot 1 Volume`, `Slot 2 Filter On`, `Slot 3 Mute`, `Slot 4 Filter Adjust` produces CMAIs with IDs 251, 250, 259, 249 and correct deck+slot targets.
- `Slot N FX Send` no longer appears in the wizard UI.

### Chunk C — Hotcue + Loop ID migration

Migrate cue/loop commands to Traktor-4.4-compatible IDs.

Steps:
1. **`WizardTab.swift:91-98` — Hotcue 1-8 rows.** Each row's `commandName` field today is `"Hotcue N"` (referring to non-existent IDs 214-221). Change to **`commandName="Select/Set+Store Hotcue"` (real Traktor 4.4 id 2328)** with a new `setToValue: Float = N-1` parameter on the row. The `WizardFunction` struct already has fields for command/controller/interaction; verify it has or add a `setToValue: Float?` field (default nil meaning "leave at MappingEntry's default of 0.0"). `WizardCapturedMapping.toMappingEntry` (`WizardFunction.swift:62`) must propagate `setToValue` into `MappingEntry.setToValue` (existing field at `MappingEntry.swift:60`). Wizard hotcue rows therefore expand to **(decks × hotcues) bindings** — `perDeck=true` already exists in the wizard flow, so the deck-Assignment side comes from `currentAssignments` automatically; the hotcue-index side comes from `setToValue`. Outcome: mapping `Hotcue 1` produces 2/4 CMAIs (one per deck) with `commandId=2328`, `Assignment=0..3`, `setToValue=0`. Same for Hotcue 2..8 with `setToValue=1..7`.
2. **`TSIWriter` — verify `setToValue` write path.** The field is named `setToValue` in `MappingEntry.swift:60` (NOT `setValueTo`). The writer reads it at `TSIWriter.swift:446` (`let setValue: Float32 = mapping.setToValue`). No new field needed; just ensure Chunk C step 1's wizard-side wiring sets `MappingEntry.setToValue` correctly.
3. **`WizardTab.swift:99-102` — Loop In / Loop Out / Loop Active / Loop Size.** These rows reference IDs that don't exist in Traktor 4.4. Two paths:
   - **C-3a (default):** Remove them from the wizard. They were broken anyway. Add a release-note comment.
   - **C-3b (stretch):** Replace with Traktor 4.4 equivalents. `Loop Size` may map cleanly to `Loop Size Select+Set` (ID 2317). `Loop In`/`Loop Out` have no direct equivalent — Traktor 4.4 uses Loop Set (2192) + size selection. Design call needed.
4. **`TraktorCommands.swift:307-314` — `Hotcue 1..8` lookup entries.** These map to the now-stale 214-221. Either delete them, or keep them as legacy-import compatibility (they only affect parsing of old TSI files). Default: keep but add a comment that emit-side never uses them.

**Acceptance:**
- Build green.
- A wizard run mapping Hotcue 1-4 produces CMAIs with `TraktorControlId=2328` and `SetValueTo` values 0,1,2,3.
- Cue/Loop tab no longer offers `Loop In` / `Loop Out` (path C-3a) OR offers them with working IDs (path C-3b).

### Chunk D — End-to-end Traktor verification (human-in-loop)

User runs the rebuilt app, exercises S1-S5, loads each output into Traktor 4.4 via the controller manager, confirms the mappings appear in Traktor's mapping editor **and** the physical control fires the assigned Traktor command.

This is the chunk that proves the fix works in reality. Cannot be skipped or replaced with code-only verification.

**Acceptance:** S1-S5 all green per the user.

## Alternatives considered

- **(Alt-1) Keep fabricated IDs.** Not possible — Traktor's command catalog is hardcoded in its binary.
- **(Alt-2) Import a known-good Traktor template TSI as scaffold, patch only the MIDI bindings.** Tempting but rejected: requires shipping a template, limits commands to whatever's in the template, doesn't fix voice/manual paths, future Traktor versions could break the template.
- **(Alt-3) Defer slot commands; fix only universal scalars + hotcues.** Tempting smaller scope but user explicitly tested slot commands. Rejected.
- **(Alt-4) Audit every Traktor-3-era ID in `TraktorCommands.swift`** — broader scope than needed for this fix. Deferred to follow-up.

## Blast radius / rollback

- **Files touched:** `TSIWriter.swift`, `TraktorCommands.swift`, `WizardTab.swift`, `WizardCoordinator.swift`, `WizardFunction.swift`, `MappingEntry.swift` (possibly), plus the three earlier session fixes (`WizardSetupView.swift`, `WizardSetupConfig.swift`, `ModeSelectionWindow.swift`).
- **Output-path only.** TSIs loaded back into the app stay parseable; the existing parser tolerates the wider value range.
- **Re-saving previously-broken wizard files** (e.g. v2/v3/v4) through the new writer should fix them — required by S5.
- **Existing tests in `XtremeMappingTests/`** that assert old broken values must be updated. Plan stage enumerates them.
- **Rollback:** revert the do-it commit. The three earlier session fixes are in the uncommitted working tree at pipeline start and survive a single-commit revert.

## Open questions

1. **Loop In / Loop Out / Loop Active** — Traktor 4.4 doesn't have direct equivalents. Path C-3a (remove) or C-3b (find best-fit replacement)? Default: **C-3a (remove)** unless plan stage identifies a clean replacement.
2. **Are the six CMAD scalar deltas all load-bearing, or are some Traktor-side defaults?** Resolved by S1-S5 testing — if Chunk A goes in and S1 still partly fails, we narrow further.
3. **UX mitigation for dropping `Slot FX Send`.** It's a Basic-tier function in the current wizard. Removing it without notice may surprise users mid-mapping. Options: (a) silently drop; (b) add a release-note line; (c) replace with a working slot-FX-related command. Default: **(b) release note**, since (c) requires deciding which command and (a) is too quiet.
4. **Other fabricated ID ranges.** `TraktorCommands.swift` has hardcoded ranges 601-728 (Remix Deck Cells), 2401-2404 (Duplicate Track Deck), 2688-2703 (Deck Meters), and the 2900-2923 we're deleting. The first three look like real Traktor IDs (within plausible range and not obviously fabricated), but spot-check before merge.
5. **DDCI container length / `MidiNoteBindingId` index encoding** (pass-1 reviewer's new categories). Deferred — TKTR working file has 2 DCDT entries with all this stuff and binds correctly, suggesting the writer's existing length/index handling is OK. If S1-S5 testing surfaces a binding-resolution bug, re-open.

## Verification plan

Per chunk:
- A: build; decode-script verifies the five **non-hotcue-conditional** CMAD fields across 5+ frames sampled from different command-ID classes (button, fader, encoder, LED, deck/slot). `HasValueUI` is verified in Chunk C, not here.
- B: build; decode-script verifies command IDs + Assignment values for Slot 1/2/3/4 mappings across Volume/Mute/Filter/Filter On/FX On. Updated tests (`TraktorCommandsTests.swift:131-164`) green.
- C: build; decode-script verifies Hotcue 2328 + SetToValue encoding and HasValueUI=1 for the hotcue branch.
- D: human-in-loop Traktor 4.4 test, scenarios S1-S5.
- D: human-in-loop Traktor test, S1-S5.

Integration verification: a single wizard run that touches all tabs, saved to one file, loads cleanly into Traktor and every binding fires.

## Token / time budget

Investigation phase: ~30k tokens already spent (already done). Plan-writing + chunk execution + reviews: estimate another ~150k for the full pipeline. Within the do-it skill's expected budget.
