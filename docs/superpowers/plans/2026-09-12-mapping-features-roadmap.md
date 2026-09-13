# Mapping features delivery roadmap

**Design:** [Agreed direction and proposed defaults](../specs/2026-09-12-mapping-interchange-assistant-design.md)

## Where to start

Start with the source-preserving JSON round trip, before UI or API work. Existing MappingFile Codable excludes sourceEnvelope, so reusing it as a public file format would not meet the preservation requirement. Phase 1 has a separate implementation plan: [JSON interchange](2026-09-12-json-interchange.md).

## Milestones

| Phase | Deliverable | Acceptance demonstration | Dependencies |
|---|---|---|---|
| 1 | JSON export/import, local diagnostics, schema and editing guide | Complex TSI exports to JSON and returns byte-identically without edits; supported external edits survive; invalid imports explain errors without touching open documents | Existing parser, writer, command catalogue |
| 2 | Versioned profiles, K1/K2/K3 first, control lookup, learned overrides | Resolve K1 controls and K2/K3 layer-dependent addresses from official evidence; distinguish physical position/MIDI channel/deck; handle feedback and unknown custom maps; hardware checks optional | Phase 1 metadata contract |
| 3 | Read-only assistant and documentation | Find filter mappings with row references; explain a modifier layer; identify uncertainty; export Markdown/text and a readable PDF | Shared mapping queries, validation; phase 2 enriches answers but generic mappings still work |
| 4 | Conversational edits with review and Undo | Retarget an identified control group, inspect exact changes, apply once, undo once; stale or ambiguous requests do not mutate | Phase 3 plus shared validation |
| 5 | Proposed JSON repair and broader profile coverage | Recover a representative malformed/invalid import through a reviewed proposal and revalidation; release another evidence-backed profile | Phases 1 and 4 |

## Planning allowance

These are rough engineering allowances, not completion promises; measured phase-1 progress should replace them.

- Phase 1: approximately 1–2 focused days, with source identity/preservation the main uncertainty.
- Phase 2: approximately 1–2 days for the profile system and one documented pilot; manufacturer documentation is the acceptance basis; hardware verification is optional.
- Phase 3: approximately 1–3 days for the read-only assistant, exports, and evaluation.
- Phase 4: approximately 1–2 days for reviewed operations and regression coverage.
- Phase 5: approximately 1–2 days for initial repair behavior; catalogue expansion is ongoing.

A focused first day should aim for phase 1, with the codec and preservation proof as the minimum useful checkpoint. The full set is a multi-day effort, approximately 5–11 focused engineering days under these assumptions. AI assistance may compress implementation time but does not remove source review or answer evaluation.

## First-day sequence

1. Record repository/test baseline in an isolated development branch; preserve unrelated working files.
2. Inventory the model fields and freeze the first schema with source identity tests.
3. Prove no-op and edited JSON/TSI round trips using real fixtures.
4. Add deterministic diagnostics and refusal behavior.
5. Add import review and export actions after the core passes.
6. Demonstrate external edit, invalid import, cancellation, and TSI output; document remaining gaps honestly.

Do not weaken preservation or quietly drop unsupported controls to fit a time box. If the preservation proof takes the day, that is the checkpoint; JSON import is not declared ready.

## Evaluation examples to retain across phases

- Unchanged complex imported TSI, including opaque data.
- Comment edit and mapping reorder in an external editor.
- Valid command reassignment, and conflicting name/ID.
- Missing comma, duplicate key, typo, unknown version, oversized file.
- Unknown source command versus newly invented command.
- Euphonia LOW knob to a chosen Traktor deck filter, with hardware-EQ caveat grounded in evidence.
- LED request for a device without MIDI receive capability.
- Ambiguous fader label requiring MIDI Learn or clarification.
- Multi-row edit, stale document revision, atomic rejection, and Undo.
- Assistant answer/documentation with traceable references and explicit uncertainty.

## Execution policy

Implement phase 1 first and review its working result before starting the next subsystem. Write each later subsystem's detailed plan against the actual interfaces produced. Parallel work is useful for independent official-document collection once the profile schema exists; the core preservation/validation work is sequential. Do not require live API calls for routine tests. Keep real-device tests and live model evaluation explicit, and never label them passed when unavailable.

## Controller priority update — 12 September 2026

Per user direction, implement Xone K1, K2 and K3 before Euphonia or other controllers. Official manufacturer documentation is sufficient for profile acceptance; physical testing is optional. Execute [the K-series implementation plan](2026-09-12-xone-controller-profiles.md) against the completed JSON interfaces. Euphonia examples above remain future evaluation cases, not prerequisites for milestone 2.

## Milestone 2 complete — 12 September 2026

K1/K2/K3 profile selection, configured control lookup, contextual overrides, matching-row navigation, JSON v2 configuration persistence and Undo/Redo are implemented. Final verification passed 822 tests and a native two-device JSON export/import round trip. Source-backed profiles meet the documentation acceptance basis; no physical hardware test or live MIDI capture is claimed. See `XtremeMapping/docs/Controller-Profile-Verification.md` for the completed checks.

**Milestone 3 scope:** Begin with shared deterministic mapping queries and traceable row references, then answers about controls/modifier layers and Markdown, text and PDF exports. Generic mappings must remain usable without controller profiles. Conversational mutation and AI repair stay in milestones 4 and 5.

## Milestone 3 complete — 12 September 2026

The read-only Explain interface now provides complete local reference guides, device-scoped source-row lookup, optional AI questions with validated references, and Markdown/text/PDF exports. Final verification passed 861 tests plus native lookup, row navigation and all three exports. Preserved native data uncertainty is explicit. No live model evaluation or physical hardware test is claimed. See `XtremeMapping/docs/Mapping-Explanation-Verification.md`.

**Next: milestone 4, conversational editing.** Build typed, validated edit proposals against the existing JSON/model contract; show the affected rows and exact changes before applying. Reject stale or invalid proposals atomically, preserve opaque TSI data, and apply accepted changes as one Undo step. K1/K2/K3 remain the controller priority; Euphonia and AI repair remain deferred.

## Milestone 4 complete — 12 September 2026

Unified Assistant now combines typed questions, optional spoken input with text replies, optional physical MIDI capture, and conversational edit proposals in one document-bound floating window. Sonnet is the default. Changes require local review and explicit Apply, validate atomically, preserve native data, reject stale proposals, and provide one Undo. Local lookup and Markdown/text/PDF guides remain available without AI. Final verification passed 890 tests and independent review; native checks covered local questions, row navigation, guide export, device setup and Undo. No live AI, microphone or physical MIDI test is claimed. See `XtremeMapping/docs/Unified-Assistant-Verification.md`.

**Next: milestone 5, AI repair.** Use actionable import diagnostics to propose corrections, show their exact effects, and rerun deterministic validation before allowing import. Keep original input recoverable and require review; AI cannot bypass preservation or validation rules. The visual controller editor is a separate later feature: documented K1/K2/K3 controls can be selected in a diagram and assigned through typing or speech. Euphonia and other profiles remain deferred.

## Assistant polish and initial AI repair delivered — 12 September 2026

Assistant now matches the main editor’s compact stone/amber design, with an anchored composer, progressive AI/MIDI setup, selection-aware examples and stable window resizing. Keychain lookup and API-key settings no longer block the interface while awaiting authorization.

The AI repair portion of milestone 5 is implemented: failed imports can request bounded exact textual repairs, review Before/After changes, accept the repair, rerun the existing deterministic validation and explicitly import a new document. Original input and retained native source stay protected. Unfamiliar structures and ambiguously damaged source refuse locally. Broader controller coverage remains deferred.

Final verification: 908 tests passed and independent reviews passed. Native checks covered default/minimum Assistant layout, key/speech startup cancellation, MIDI arming/stopping and repair eligibility/consent/cancellation. Live Sonnet responses, successful live repair generation, speech transcription and physical MIDI capture remain unverified: Keychain authorization and live test input were unavailable. See `XtremeMapping/docs/Assistant-Polish-Repair-Verification.md` and `XtremeMapping/docs/JSON-Repair.md`.

**Pause here per user direction.** Resume with the outstanding live evaluation once access/input is available. Euphonia/other profiles and the visual controller editor are later work, not started in this pass.
