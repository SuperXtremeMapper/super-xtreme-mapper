# JSON interchange milestone — 12 September 2026

Implemented on `codex/json-interchange`, starting from `b262263`.

## Delivered

- Dedicated version 1 JSON format, schema, exhaustive field inventory, and external editing guide.
- Original TSI bytes and stable source identities retained in a preservation envelope. Import reparses those bytes to reconstruct trusted opaque state and the original baseline before applying JSON edits.
- Bounded JSON scanning, duplicate-key rejection, structural and semantic diagnostics, and ordinary TSI writer preflight.
- File → Import JSON with asynchronous review and cancellation; accepted imports become new, edited, untitled TSI documents. File → Export JSON publishes separately without clearing document changes.
- Explicit review warnings for writer normalization and inspection-only imports when an edit cannot safely preserve opaque data.

## Verification

| Check | Result |
| --- | --- |
| Existing baseline | 732 tests passed, zero failures |
| Full suite after application changes | 777 tests passed, zero failures |
| Additional native-fixture external-edit regression | One test passed, zero failures; only this test was added after the full run |
| Unchanged JSON round trips | All 15 accepted TSI fixtures returned byte-identical TSI |
| Schema checks | Generated examples, native demonstrations, and exceptional/maximum Float examples validated |
| Scoped implementation review | No outstanding blockers |

Tests cover editable fields, Unicode, row order and additions/removals, invalid identities, damaged preservation data, unsupported edits, exceptional floating-point bits, unknown inherited versus new commands, invalid MIDI/command combinations, normalization warnings, metadata retention, cancellation, destination safety, and dirty-document behavior. Existing clipboard and preservation tests remain in the full suite.

The native app demonstration exported the complex Traktor 4.4 fixture with two documents open; its JSON contained 112 mappings and the exact original source bytes. A Traktor 4.5.1 benchmark fixture then passed an external JSON comment edit through review (one changed row, zero errors or warnings), new-document import, and ordinary TSI Save. The GUI-saved file was byte-identical to the independently expected writer output. A separate command edit from Play/Pause (100) to Cue (206) was saved and verified. Malformed JSON visibly blocked acceptance in the review interface.

Saving and subsequently exporting were also verified for both source-backed and JSON-created documents. Where the writer has already committed canonical defaults, export uses the saved wire values for unchanged fields while retaining subsequent unsaved edits.

Local evidence:

- Baseline: `/tmp/sxm-json-baseline.log`
- Full suite: `/tmp/sxm-json-complete.log`
- Additional native fixture regression: `/tmp/sxm-json-native-edit.log`
- Demonstration JSON and TSI files: `/tmp/sxm-json-demonstration/`
- GUI-saved native result: `/tmp/sxm-json-demonstration/manual-native-verified.tsi`

These temporary artifacts are local verification evidence, not shipped fixtures.

## Boundaries and follow-up

The complex 4.4 fixture contains opaque state that the existing writer cannot safely edit. Its unchanged round trip is exact; unsupported edits remain inspectable with an explicit refusal to save, rather than silently regenerating the file. The 4.5.1 fixture demonstrates a supported native edit.

Pure model/parser/catalog types received concurrency annotations so JSON review can run off the main thread. Existing TSI writing and clipboard semantics were retained. No API credentials or new service dependency are required.

No Traktor application import or physical-controller validation was performed. Controller profiles, explanation/documentation assistance, conversational editing, and AI repair remain later milestones.

See [the editing guide](SXM-JSON-Editing-Guide.md) and [field contract](SXM-JSON-Format.md).
