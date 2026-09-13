# Xone K1, K2 and K3 Controller Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Let users identify physical controls and matching mapping rows for Xone K1, K2 and K3 using versioned manufacturer evidence, explicit device settings and optional local overrides.

**Architecture:** Bundle three immutable profile resources and resolve their addresses through a deterministic service. Attach configuration and control references to JSON metadata, keeping hardware facts separate from Traktor assignments and the TSI preservation envelope. Profile selection never rewrites MIDI assignments.

**Tech Stack:** Existing Swift, SwiftUI, Foundation, XCTest and local JSON resources; no new dependency or model API.

**Spec:** `docs/superpowers/specs/2026-09-12-mapping-interchange-assistant-design.md`, amended by the user’s 12 September instruction: K1, K2 and K3 first; Euphonia and other controllers later. Evidence: `XtremeMapping/docs/Xone-K-Series-Profile-Evidence.md` and its linked source packages.

## Global constraints

- Manufacturer documentation is the acceptance basis. Physical hardware testing is optional and never claimed unless performed.
- Profiles supply hardware facts, not Traktor assignments.
- Keep physical position, MIDI channel, hardware layer and Traktor deck separate.
- Unknown profile references must not prevent an otherwise valid generic MIDI import.
- Never silently upgrade pinned profiles in existing documents.
- Existing exact TSI preservation and writer refusal behavior must remain intact.
- No API key is needed for JSON, local diagnostics, profiles, or deterministic reference tables.
- Euphonia, assistant features, conversational edits and AI repair are outside this implementation.

## Interface findings and decisions

The existing `SXMJSONMetadata` contains `profileReferences`, `physicalControls` and `localOverrides`. It has no device configuration: channel, layer mode and K3 map slot cannot be reconstructed reliably from those arrays. `MappingFile.interchangeMetadata` is already retained by the codec. It is deliberately excluded from clipboard Codable and `MappingFile.==`.

`TraktorMappingDocument.performUndoableMutation` currently rejects a mutation when `after == before`; metadata-only changes consequently need explicit comparison at that document boundary. Keep TSI semantic equality unchanged. Change its guard to `after != before || after.interchangeMetadata != before.interchangeMetadata` and test Undo/Redo.

Add `deviceProfiles` metadata with device UUID, profile ID, exact profile version, human MIDI channel (1–16), layer mode, and unit map. Since v1 rejects unknown metadata fields, introduce JSON schema v2 for documents using device configuration; retain v1 reading and v1 output for documents without new fields. Do not silently extend the strict v1 contract. Preserve unresolved references verbatim.

Profile IDs: `allen-heath.xone-k1`, `allen-heath.xone-k2`, `allen-heath.xone-k3`; initial versions `1.0.0`. Use stable positional control IDs, e.g. `encoder.top.1.turn`, `encoder.top.1.push`, `fader.1`. Define a complete inventory from the diagrams before writing resource tables; do not invent missing addresses.

## Task 1: Profile contract, loader and validation

**Create:** `XtremeMapping/XtremeMapping/Models/Controllers/ControllerProfile.swift`, `XtremeMapping/XtremeMapping/Services/ControllerProfileLibrary.swift`, `XtremeMapping/XtremeMappingTests/ControllerProfileLibraryTests.swift`.

**Interfaces:** `ControllerProfileLibrary.profile(id: String, version: String) throws -> ControllerProfile`; `ControllerProfile` is Codable and Sendable. Its records contain model, profile version, source revision, controls, operating modes, send/return bindings, encoding, value range, evidence page/section and verification status. Loading is exact-version only.

- [x] Record a fresh full XCTest baseline in an isolated `codex/xone-controller-profiles` worktree, following the worktree skill. Use the project’s listed macOS scheme and installed destination; retain command and result in verification notes.
- [x] Write loader tests for malformed resources, duplicate control IDs, missing source references, MIDI numbers outside 0–127, channels outside 1–16 and unknown version pins.
- [x] Define distinct binding direction (`send`, `receive`) and encoding (`absolute7Bit`, `relativeTwosComplement`, `noteGate`). LED color/value rules belong to receive bindings; rotary press and turn have separate IDs.
- [x] Implement bounded resource decoding and validation. Invalid bundled resources fail with the resource and field path; unavailable user references return an unresolved lookup result without failing generic mapping import.
- [x] Run the focused tests, confirm valid fixtures load and invalid fixtures fail for the intended reason, then commit this independent contract.

## Task 2: Complete source-reviewed K-series resources

**Create:** `XtremeMapping/XtremeMapping/Resources/ControllerProfiles/xone-k1-1.0.0.json`, `xone-k2-1.0.0.json`, `xone-k3-1.0.0.json` in the same directory; `XtremeMapping/XtremeMappingTests/XoneProfileEvidenceTests.swift`.

**Consumes:** Task 1 loader and record types. **Produces:** Three fully validated bundled profiles, with no automatic profile selection based only on port names.

- [x] Inventory every physical control and receive target from K1 pp.13–14, K2 pp.14–18 and the five saved K3 diagrams. Record numeric note IDs, not only octave labels. Verify every transcription against a rendered diagram.
- [x] Write independent expected-address assertions before filling resources. Include K1 top encoder CC0–3, faders CC16–19 and top-left push note52; K2/K3 first encoder CC0/22/44, first fader CC16/38/60 and green bottom encoders CC68/69. Assert channel default15 separately from these address facts.
- [x] Transcribe all addresses explicitly, including mode applicability and LED return colors. Do not generate expectations using the same offset formula as the profile data. K1 has no inferred K2 latching behavior. Attach the K1 conversion-table discrepancy to its source notes.
- [x] Represent K2’s five modes: off, matrix switches, pot/encoder switches, all switches, all controls. Mark hardware soft pickup for all-controls mode independently of Traktor soft takeover.
- [x] Build K3 factory data from its own archived diagrams and source references. Record custom slots1–3 as configurable; do not supply factory addresses for unknown custom maps. Feedback interpretation includes remote/linked mode and layer restrictions.
- [x] Run resource completeness, source-reference and address tests; review the entire address inventory against the originals and commit.

## Task 3: Deterministic control lookup

**Create:** `XtremeMapping/XtremeMapping/Services/ControllerControlResolver.swift`, `XtremeMapping/XtremeMappingTests/ControllerControlResolverTests.swift`.

**Interfaces:** `ControllerConfiguration` contains profile pin, global channel, layer mode and unit map. `ControllerControlResolver.resolve(controlID: String, configuration: ControllerConfiguration, layer: ControllerLayer, direction: ControllerDirection) -> ControlResolution`. Results are resolved bindings, ambiguous candidates or unresolved with a concrete reason. `matchingRows(bindings: [ControllerBinding], device: Device) -> [UUID]` returns all compatible row IDs, never a guessed single row.

- [x] Write tests covering every layer-mode/control-family combination, channel1 and16, K1 rejection of layer modes, K3 unknown custom configuration, input versus LED output, duplicate matching rows and absent controls.
- [x] Resolve only applicable bindings. Missing configuration returns choices rather than silently choosing defaults. UI may offer documented defaults for explicit acceptance.
- [x] Match numeric MIDI kind/channel/number and direction within the selected device. Preserve all matching rows across modifier conditions and deck assignments; expose those differences to the caller.
- [x] Apply explicit local overrides before documented bindings and label their provenance as user supplied or learned. An address learned for one row is not proof of the entire custom map.
- [x] Run focused tests and commit. Example acceptance: K2 all-controls green first fader resolves CC60; the same control in off mode resolves base CC16; its Traktor deck does not affect hardware resolution.

## Task 4: Persist configuration and support metadata Undo

**Modify:** `Models/Interchange/SXMJSONDocument.swift`, `Models/Interchange/SXMJSONCodec.swift`, `XtremeMappingDocument.swift` under `XtremeMapping/XtremeMapping/`; add `Resources/Schemas/sxm-mapping-v2.schema.json`. **Tests:** `XtremeMapping/XtremeMappingTests/ControllerProfileMetadataTests.swift` and existing JSON preservation suites.

**Consumes:** Existing metadata, profile pins and Task 3 configuration. **Produces:** Optional device-scoped configuration, backward-compatible v1 loading, explicit v2 export and undoable profile annotation.

- [x] Write failing tests for two devices with different channels/layers, unknown profile pins, exact JSON metadata retention, stale mapping/device references and metadata-only Undo/Redo.
- [x] Add optional `deviceProfiles` and validate referenced UUIDs, exact version pins, channel bounds and model-supported configuration. Dangling or unavailable profile annotations produce actionable warnings; malformed structure produces schema errors. Do not discard unknown profile IDs or reinterpret their configuration using another model.
- [x] Update scanner field allowlists and version dispatch with the new schema; reject v2-only fields in v1. Retain all existing v1 limits, preservation checks and diagnostics. Make v2 inherit the same preservation semantics.
- [x] Update the document mutation guard as specified above. Profile assignment changes metadata only. Learned MIDI assignment changes remain explicit operations using the existing undoable mutation path.
- [x] Assert profile annotation leaves TSI output byte-identical for every accepted no-op preservation fixture. Verify v1 examples remain valid and v2 configuration survives export/import. Run focused tests and commit.

## Task 5: Device profile and physical-control interface

**Create:** `XtremeMapping/XtremeMapping/Views/ControllerProfileSheet.swift`. **Modify:** `XtremeMapping/XtremeMapping/ContentView.swift` and reuse `Utilities/MIDIInputManager.swift` through its existing subscription/lifecycle pattern. **Tests:** `XtremeMapping/XtremeMappingTests/ControllerProfileWorkflowTests.swift`.

**Consumes:** Library, resolver and metadata mutation path. **Produces:** A device-scoped profile selector and searchable physical-control lookup with mapping-row navigation.

- [x] Follow the existing single active-sheet routing in ContentView. Add a controller action for the selected device; offer K1/K2/K3 and no profile. Show exact profile version and manufacturer-documentation status.
- [x] Provide channel, model-appropriate layer mode and K3 factory/custom-slot settings. Configuration is user-declared, not a claim that SXM changed the controller hardware.
- [x] Show control label, address, applicable layer, send/feedback direction, source reference and matching rows. Unknown custom maps show a reason and an explicit override or MIDI Learn action.
- [x] Reuse the existing MIDI Learn session without changing unrelated subscribers. Capture only for an explicitly selected control; show the observed address before storing an override. Cancel must leave metadata and mapping rows untouched. Do not automatically retarget rows when selecting a profile.
- [x] Test selection/cancellation, identical settings as a no-op, Undo/Redo, multiple devices, unresolved custom map and match navigation. Explain in the sheet that profile annotations travel through SXM JSON; TSI alone does not retain them.
- [x] Run tests and inspect the native sheet for all three models, then commit.

## Task 6: Regression and acceptance demonstration

**Create:** `XtremeMapping/docs/Controller-Profiles.md`, `XtremeMapping/docs/Controller-Profile-Verification.md`. **Modify:** `XtremeMapping/docs/SXM-JSON-Format.md`, `XtremeMapping/docs/SXM-JSON-Editing-Guide.md` and roadmap status.

- [x] Run the complete suite once after all changes and record the actual counts, command and result. Re-run only when subsequent fixes justify it.
- [x] Demonstrate K1 base lookup, K2 all-controls layer-dependent lookup, K3 factory lookup and unresolved custom-map behavior in the app.
- [x] Demonstrate two differently configured devices, profile selection Undo/Redo, JSON export/import retaining exact pins/configuration, and unchanged complex TSI output including opaque data.
- [x] Document all reviewed source addresses, supported profile versions, JSON v1/v2 compatibility and unresolved custom-map behavior. K3 Editor file import is deferred until its actual exported format is available and validated; explicit settings/overrides support this release.
- [x] Review the implementation against this plan and resolve material findings before claiming completion. Record manufacturer documentation as verified; hardware checks as not performed unless actually run.

## Completion gate

All three profiles are selectable and searchable; every bundled address is traceable to archived official evidence; layers and feedback are resolved correctly; custom-map uncertainty is visible; metadata survives JSON and Undo; existing TSI preservation tests pass. Euphonia remains a later catalogue addition. The next roadmap milestone after this gate is the read-only explanation assistant and documentation exports.

## Execution checkpoint — 12 September 2026

Tasks 1–2 complete in commits `68b0e0c` and `b5a5eea`, integrated locally into main. The full suite passed 794 tests, zero failures. Profile contract, source-reviewed resources and acceptance notes are in `XtremeMapping/docs/Controller-Profiles.md` and `XtremeMapping/docs/Controller-Profile-Verification.md`. Scope of this checkpoint is the next implementation step requested by the user: shared format and K-series data. This foundation checkpoint was followed by the configured workflow completion below.

## Configured workflow completion — 12 September 2026

Tasks 3–6 are complete in commit `27fb050`, integrated locally into main. The app now offers device-scoped K1/K2/K3 profiles, deterministic physical-control lookup, contextual manual/MIDI Learn overrides and matching-row navigation. JSON v2 retains configurations and exact pins; v1 remains supported. Profile changes support Undo/Redo without changing TSI data. The native walkthrough also exposed and fixed the command-menu undo-manager fallback.

Final suite: **822 tests passed (760 XCTest + 62 Swift Testing), zero failures**. Native acceptance covered all three models, K2 green-layer matching with distinct modifier conditions, K3 custom-map uncertainty/overrides, and a two-device JSON round trip with exact metadata/device-data equality after menu Duplicate/Undo. Documentation and reproducible evidence are recorded in `XtremeMapping/docs/Controller-Profile-Verification.md`. Physical hardware and live MIDI capture were not performed; official manufacturer documentation remains the acceptance basis.

Tasks 3–6 were delivered together because the native workflow consumes the resolver and v2 metadata contract. The next milestone is the read-only explanation assistant and Markdown/text/PDF exports. Euphonia and K3 Editor-file import remain deferred.
