# Controller-wide LED output mapping: feasibility and delivery plan

**Status:** Approved and implemented on `codex/led-output-mapping`. All 680 automated unit tests pass and independent code review is closed. Native Traktor 4.5.1 evidence was captured and SXM-generated mappings imported successfully. Detailed native re-export matches all four generated rows, temporary devices are removed, and single/mixed/invalid editor views were inspected. Follow-up found visual lock inspection unavailable because the current toolbar has no lock toggle (removed before this work); automated lock guards pass. The recipient confirmed S7 blue (1), cyan/light blue (12), deletion-off and stable feedback; other controllers and broader transitions remain unverified. See `docs/diagnostics/2026-09-10-led-implementation.md` for the execution record. The checklist below retains the original delivery requirements, including outstanding manual checks.

**Goal:** Let users configure Traktor output feedback directly in SXM, across supported MIDI controllers, including Controller Range, MIDI Range, Blend and Invert, then support reliable cue-type colour rules.

**Architecture:** Keep the existing mapping, document undo and TSI preservation architecture. Add a semantic range adapter over existing raw fields, a shared output settings panel and evidence-backed command metadata. Hardware colours belong to optional device profiles, separate from Traktor command values.

**Tech stack:** Swift, SwiftUI, existing XCTest/Swift Testing suites, native Traktor TSI fixtures.

## What the request means

Generalised user story: “For any supported OUT mapping, I can choose which Traktor values activate feedback and which MIDI values are sent, and save those choices without losing them when I reopen, copy or export the mapping.”

This covers on/off buttons, coloured pads, modifier indicators and continuous feedback such as meters and rings, to the extent those devices expose feedback through supported MIDI messages. It is not a promise of arbitrary HID, NHL or SysEx support.

The reported S7 example is an acceptance scenario: Hotcue 1 Type, Controller Range 0–0, MIDI Range 0–1, correct MIDI destination. The reporter observed blue for a cue and off after deletion. His email does not specify Blend/Invert states, channel, note or firmware; record those from a working export before calling the reproduction exact.

## Findings in the current source

Paths below are relative to the repository root.

| Area | Evidence | Implication |
| --- | --- | --- |
| Storage | `XtremeMapping/XtremeMapping/Models/MappingEntry.swift:168` declares all four requested settings as pass-through fields; Codable, copying and equality include them. | This is an editing gap over an existing foundation. |
| Import/export | `Models/TSI/TSIInterpreter.swift` reads the LED tail; `Models/TSI/TSIWriter.swift:782` patches individual LED fields on imported entries. Both live under `XtremeMapping/XtremeMapping/`. | Reuse the preservation machinery. |
| UI | `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift:759` renders `EmptyView()` for LEDs. Its visible Invert toggle writes `mapping.invert`, not `mapping.ledInvert`. | The user is not overlooking an existing detailed editor. |
| Direction | The same panel offers input controller types even for OUT rows; its type menu excludes LED. `ContentView.swift:454` creates outputs using generic MappingEntry defaults (`none` type and interaction). | Make presentation and creation explicitly output-aware. Verify correct native defaults. |
| Export risk | `TSIWriter.swift:1163` selects command/controller profiles before its persisted-field fallback. On imported profile changes, the profile branch excludes MIDI endpoints and LED Invert edits. | Test simultaneous edits and command changes; prevent profile defaults from discarding explicit output settings. This is a code-path risk, not a hardware failure reproduced in this review. |
| Numeric representation | Range data is stored as raw UInt32 words inside Int fields. Existing profiles use integer sentinels and Float32 bits; the writer uses unsigned clamping. | A direct numeric text binding could corrupt negative or fractional values. Decode/encode through an adapter. |
| Existing evidence | `XtremeMapping/XtremeMappingTests/TSIFixtureTests.swift:398` checks real Traktor 4.5.1 Xone K3 outputs and every Blend/Invert combination. `TSIInterpreterTests.swift:1801` tests individual LED byte ownership. | Good regression coverage exists, but not proof of the S7 case or every range type. These tests were inspected, not run during planning. |
| Conditions | `SettingsPanelV2.swift:1203` offers M1–M8 only. `MappingEntry.swift:731` preserves other condition identifiers opaquely but labels conditions as M numbers. | Reliable multicolour authoring needs a separate condition-editor increment. |

## Proposed product behaviour

For a single OUT row, show an **LED Output** section:

| Control | Behaviour |
| --- | --- |
| Controller Range: Min / Max | Display semantic numbers, including equal endpoints, negative states and fractions where supported by the command. Use verified state labels as supplemental help. |
| MIDI Range: Min / Max | Integer fields from 0 through 127 for supported Note/CC output. Allow equal endpoints; verify Traktor's treatment of reversed endpoints before imposing an ordering rule. Do not silently swap values. |
| Blend | Edit `ledBlend`. Explain continuous scaling; do not assume intermediate values represent intermediate colours. |
| Invert | Edit `ledInvert`, clearly separated from input inversion. |
| Output destination | Retain explicit channel and Note/CC assignment; show the device output port context where available. Learning an input address does not prove the LED receives at that address. |

OUT rows should display LED / Output appropriately instead of input button/fader modes. Switch the panel by mapping direction, including legacy OUT rows whose stored controller type is `none`. Opening an entry must never rewrite it merely to normalise its display.

Use draft text for range edits. Incomplete input (such as a minus sign) must not mutate the model; commit only valid values on Apply/Return or completed focus changes. Reject nonfinite numbers, nonintegers for discrete fields and out-of-domain values when the domain is verified. Unknown encodings remain preserved and explicitly unavailable for semantic range editing; supported independent fields can remain editable. Do not reinterpret an unknown raw word as an ordinary integer.

Every commit uses the existing undoable document mutation and respects locked state. Multi-selection shows mixed values and changes only fields explicitly edited. Initially enable batch Controller Range editing only for matching verified domains; let users batch MIDI endpoints and flags across compatible outputs. Mixed IN/OUT selections explain that users must select outputs to edit LED settings. Do not change hidden IN values.

## Alternatives

1. **Expose raw fields only.** Smallest UI change, but raw bits, signed values and profile replacement make it unsafe as a general solution.
2. **Shared semantic editor plus export hardening — recommended.** Solves the immediate request for supported MIDI devices and provides a sound basis for colour workflows.
3. **Full colour wizard with device libraries immediately.** More convenient eventually, but expands evidence collection and hardware maintenance before basic editing is reliable.

## Delivery sequence

### 1. Establish a native output reference matrix

- [ ] Extend `XtremeMapping/XtremeMappingTests/Fixtures/TSI/` with minimal real Traktor exports: the reported S7 setup; Hotcue Type at -1, 0 and 5; a Boolean output; a continuous output with fractional endpoints; Note and CC assignments; equal MIDI endpoints; every Blend/Invert combination.
- [ ] Change one setting per export. Record Traktor version, command, displayed range, assignment, controller mode and expected feedback in `XtremeMapping/docs/TSI-Fixture-Provenance.md`.
- [ ] Use existing K3 fixtures immediately; obtain new exports during implementation if unavailable locally. Capture known working Hotcue State conditions for each deck before creating condition metadata.
- [ ] Add assertions to `TSIFixtureTests.swift` and `TSIInterpreterTests.swift` that distinguish semantic value from wire representation. Cross-check disputed values by importing/re-exporting in Traktor; an SXM-only round trip cannot prove compatibility.

**Exit:** Exact encoding and native defaults identified for the first release's Boolean, Hotcue and continuous domains. Unknown cases are explicitly preserved rather than guessed.

### 2. Add semantic range handling and harden export

Files: modify `Models/MappingEntry.swift`, `Models/TSI/TSIWriter.swift` and `Models/TSI/TraktorCommandDescriptor.swift` under `XtremeMapping/XtremeMapping/`; create focused `Models/LEDOutputSettings.swift` and `Models/TSI/TraktorOutputMetadata.swift` there.

- [ ] First add failing tests in a new `LEDOutputSettingsTests.swift` plus the existing interpreter/preservation suites: signed -1 remains its verified wire word, Float32 fractions survive, 0–0 is valid, invalid edits leave the mapping unchanged, and unknown encodings survive unrelated edits.
- [ ] Implement an adapter that exposes discrete/continuous/unsupported range values while retaining the existing raw storage and document compatibility. Numeric type conversion must be explicit; never feed semantic -1 into unsigned clamping.
- [ ] Separate creation defaults from existing explicit settings. Ensure output fields win over input profiles where appropriate, including Modifier outputs. Ensure simultaneous command/profile changes and MIDI range/LED Invert edits are all represented in the exported record.
- [ ] Route Add Out and Add In/Out Pair through verified output defaults in `ContentView.swift`; inspect wizard/voice creation paths for the same need. Do not infer continuous defaults from a hardware knob type alone.
- [ ] Test new mappings, imported mappings, command changes and converted exports separately. Verify unchanged bytes outside fields owned by the edit, including unknown/trailing payloads.

**Exit:** The requested values can be set through a tested service and survive save/export/reopen without damaging unrelated data.

### 3. Deliver single and batch output editing

Files: modify `Views/V2Components/SettingsPanelV2.swift`, `ContentView.swift` and, as needed, `Services/MappingBatchEditor.swift`; create `Views/V2Components/LEDOutputSettingsView.swift` under `XtremeMapping/XtremeMapping/`.

- [ ] Build the shared panel with the controls and validation rules above. Keep numeric conversion out of the SwiftUI view.
- [ ] Replace input-only type/interaction/invert controls for OUT selections; audit the table context-menu Invert action so it cannot mislead output users or invert the wrong field.
- [ ] Add field-specific batch edits with mixed-state presentation, compatible-domain checks and one undo action per Apply.
- [ ] Extend `DocumentTests.swift`, `MappingBatchEditorTests.swift` and UI tests for locked state, undo/redo, selection changes, invalid drafts, mixed values and input/output isolation.
- [ ] Verify copy/paste, duplication, cross-document transfer and deck cloning retain all settings using the existing transfer and transform suites.

**Exit:** A user can create the reported range configuration entirely in SXM and see the same settings in Traktor after export.

### 4. Support reliable cue-type colours

Files: evolve `Models/MappingEntry.swift` condition presentation, extract the condition UI from `SettingsPanelV2.swift`, and extend `Models/TSI/TraktorOutputMetadata.swift`; tests in `ModifierConditionTargetTests.swift`, `MappingTransformServiceTests.swift` and `TSIInterpreterTests.swift`.

- [ ] Expose verified Hotcue State conditions alongside M1–M8, with correct deck targets and state values. Migrate documents compatibly and retain opaque conditions without relabelling them as invented modifiers.
- [ ] Support manual duplicate-and-edit rules for separate cue types. Validate state transitions, empty/deleted cues, track changes, deck clones and modifier layers in Traktor; multiple rows must not fight over the same LED.
- [ ] Document a worked example using controller-specific MIDI values and explicitly configured conditions. Keep numeric editing available regardless of whether a colour profile exists.
- [ ] Consider a subsequent “Create cue-type feedback” helper and verified per-device palettes only after the manual workflow passes. Do not hard-code the S7 colour value globally.

**Exit:** Several cue states display their intended colours reliably, including clearing feedback after deletion. Stage 3 can ship independently; it should not be described as completing multicolour authoring.

### 5. Release validation and documentation

- [ ] Run relevant targeted tests for each increment, then the full suite from `XtremeMapping`: `xcodebuild test -scheme XtremeMapping -destination 'platform=macOS'`.
- [ ] Import SXM-created and SXM-edited files into Traktor, inspect settings, re-export and compare. Test S7 feedback on hardware and use K3 or another device with different feedback addressing/colours as the portability check.
- [ ] Use MIDI monitoring to verify emitted messages for transitions; inspect continuous scaling with Blend on/off. Record hardware observations separately from file-compatibility results.
- [ ] Update `README.md` with the exact editing capabilities and limits, and correct the oversimplified range notes in `XtremeMapping/docs/TSI-File-Format.md` using collected evidence.

## Scope and confidence

Feasibility is high for the shared editor: the storage and most preservation machinery already exist. This is a medium-sized feature with export correctness work, not just four missing widgets. The uncertain parts are native range metadata/defaults, controller-specific behaviour and condition encoding for the richer colour workflow. The reference matrix is the first delivery gate; elapsed-time estimates should follow it.

No firmware-specific S7 colour table, live LED preview engine, arbitrary protocol support or universal RGB conversion is required for the first release. Preserve proprietary device records under existing compatibility rules; only enable editing where the record layout is supported.

## External evidence

Native Instruments' [official MASCHINE/Traktor mapping tutorial](https://blog.native-instruments.com/how-to-make-a-maschine-mapping-for-traktor-part-2/) documents Hotcue values -1 through 5, equal controller endpoints for individual states, Blend/Invert, and state conditions for multiple colour rules. Its palette is explicitly device-specific. This supports the separation between shared command semantics and hardware colour values; it does not verify S7 values or current binary encoding.

Native Instruments' [Controller Manager guidance](https://support.native-instruments.com/support/solutions/articles/69000879471-how-to-use-the-controller-manager-in-traktor) distinguishes MIDI output addresses from input addresses and describes proprietary device mappings. Consult it when documenting the supported-device boundary.
