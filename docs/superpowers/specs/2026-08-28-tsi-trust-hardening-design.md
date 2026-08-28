# TSI Trust Hardening Design

## Status and authority

This specification implements the repository audit items approved by the user on 2026-08-28: findings 1 through 4 plus the related performance and resilience fixes. It is intentionally conservative. When the application cannot prove an edited native Traktor file is safe to rewrite, it must preserve the original and refuse an ordinary overwrite rather than silently discarding information.

## Product outcome

Super Xtreme Mapper must be safe to use as a Traktor mapping migration tool:

1. Opening and saving an unchanged valid TSI returns the exact original bytes.
2. Imported CMAD, device, port, MIDI-definition, comment, and unknown/native information is never silently normalized or discarded.
3. An edited file is overwritten only when every source element is understood and writable. Otherwise the user receives a preservation report and may deliberately export a converted copy.
4. Every edit path uses the same validated, atomic, Undoable document transaction behavior.
5. Large or malicious files fail predictably within explicit resource limits rather than causing quadratic work, unbounded allocation, or unsafe unaligned reads.

## Scope

### Included

- A raw source envelope retained by an opened document.
- Byte-identical no-op writes.
- A side-effect-free preservation report and overwrite safety decision.
- A deliberate converted-copy writer path for unsupported source documents.
- Preservation of imported CMAD scalar values and raw device/port identity.
- Strict handling of multiple controller XML entries, unknown frames, duplicate singleton frames, and unsupported source structures.
- Complete regression-fixture support with provenance manifests; fixtures must be labeled accurately as real exports, captured fragments, or generated files.
- Correct opaque-MIDI batch paste behavior in every command path.
- Destination and write-validity preflight for cross-document transfers.
- Atomic Undo for wizard and voice save operations.
- Semantic conflict identity shared by wizard and voice flows.
- Bounded, cursor-based binary parsing with strict Base64 decoding and safe unaligned integer reads.
- Focused performance and adversarial regression tests.

### Not included

- Claiming semantic edit support for proprietary native HID controls whose behavior is not understood.
- A general-purpose event-sourced document rewrite.
- Automatic repair of unknown or ambiguous Traktor structures.
- Community controller profiles, Macro Capsules, Mapping Health UI, or behavior simulation.
- Release signing, notarization, updater replacement, website work, or publishing a release.
- Replacing whole-document Undo snapshots or redesigning the mapping table in this increment. Parser complexity and save safety are the measurable performance/resilience targets for this work.

## Trust model

The semantic `MappingFile` remains the editable model. An imported `TraktorMappingDocument` additionally owns a `TSIRawEnvelope` containing the exact original XML, all controller-entry payloads, an inventory of source structures, and the original semantic baseline. The first controller entry in XML document order is the displayed primary entry. Additional entries are retained in the envelope, make ordinary edited Save unsafe, and are omitted only by an explicitly lossy converted export.

The raw envelope does not participate in clipboard Codable payloads and is not copied into individual mappings. It exists at the document boundary so model equality, drag/drop, and batch transfer remain lightweight.

### Save decisions

The document snapshot is a distinct `DocumentWriteSnapshot` containing the editable mapping, source envelope, a monotonically increasing snapshot generation, and a pure `TSIWritePlan`. A plan has a concrete output `Data`, semantic baseline-at-write, preservation report, and one of two write dispositions: `.originalPassthrough` or `.regenerated`.

- **New document:** write the normal modeled TSI representation.
- **Imported and unchanged:** return `originalXML` byte for byte.
- **Imported, changed, preservation report is ordinary-save safe:** write the modeled representation using imported raw scalar/device values.
- **Imported, changed, preservation report is lossy-convertible:** throw a localized unsafe-overwrite error. Do not modify the original file.
- **Imported or new, preservation report is unwritable:** throw the underlying validation error. Converted export is disabled.
- **Export Lossy Converted Copy:** explicitly write the modeled representation for a lossy-convertible source. This is Export, not Save As: it must use a Save panel, require a destination different from the source by standardized path, symlink resolution, volume-aware canonical comparison, and existing filesystem resource identity, enumerate every omitted/normalized category, write atomically, and never change the document URL, dirty state, semantic baseline, source envelope, Undo stack, or the behavior of the next Command-S.

Before `fileWrapper` returns, the document records one pending write receipt: generation, exact output bytes, semantic baseline-at-write, and disposition. NSDocument save operations for one document are serialized; the document rejects creation of a second in-flight receipt rather than guessing about notification correlation. A successful NSDocument save notification commits that sole receipt. A failed or cancelled save commits nothing; the explicit save-completion bridge discards its receipt, and a retry creates a new generation.

- A successful passthrough retains its envelope and advances no stale baseline.
- A successful regenerated Save reparses the exact emitted bytes and replaces the envelope with that new authoritative envelope and the semantic baseline-at-write. It never combines the new baseline with old `originalXML`.
- A successful Save As follows the same disposition rules and updates only the normal NSDocument URL association.
- If the user edits while a save is in flight, the committed envelope baseline is the snapshot that was actually written; the newer in-memory mapping remains different and dirty.
- A second unchanged Save after regeneration returns the regenerated bytes, never the pre-edit source bytes.
- Save cancellation, write failure, retry, Undo after Save, and exported converted copy each have focused lifecycle tests.

## Raw source inventory

`TSIRawEnvelope` records enough facts to make a conservative decision without claiming unsupported semantics. Every source byte or decoded semantic structure is classified as preserved, deliberately regenerated by an explicit edit, or a typed preservation risk; an unclassified structure can never produce an ordinary-save-safe report.

- Exact original XML bytes.
- Number and raw values of every `DeviceIO.Config.Controller` entry.
- Parsed primary controller frames.
- Unknown frame identifiers and their structural paths.
- Duplicate singleton frames at paths where the semantic model currently selects one value.
- Extra controller entries beyond the primary entry.
- XML entries outside the single minimal controller wrapper.
- Whether each modeled device and mapping had complete writable data.
- The semantic `MappingFile` baseline produced by the interpreter.

### Closed-world ordinary-save grammar

An edited imported document is ordinary-save safe only when all of these statements are true:

- The XML contains one controller Entry and no other settings Entry or nonstandard element content that the writer would omit. XML declarations and insignificant whitespace do not by themselves make it unsafe.
- The binary has exactly one DIOM, one four-byte DIOI with the supported value, one DEVS, matching declared counts, and no top-level or container siblings unknown to the writer.
- Each DEVI has one name and one DDAT. Each modeled singleton frame appears exactly once; DIOI, DDIF, version/revision, comments, ports, and all scalar values equal either preserved imported values or an explicitly edited replacement.
- Every DDCI/DDCO/DCBM definition is structurally unique, referenced, and represented by the semantic model. There are no unused rows, duplicate semantic keys, duplicate binding IDs, or last-wins collapses.
- Every CMAI has a positive command ID, one supported complete CMAD layout, recognized non-coerced mapping/interaction/controller/target values, and a resolvable modeled or opaquely preserved binding.
- DeviceType is Generic MIDI for ordinary semantic editing. Proprietary layouts remain openable and no-op-saveable but any edit is lossy-convertible, never ordinary-save safe.
- There are no command-zero placeholders, lossy strings, partial/extended CMAD tails, extra bytes, duplicate singleton frames, extra controller entries, or unknown frames.

Known-but-unmodeled DIOI/DDIF values, unused definitions/bindings, placeholder CMAIs, duplicate DCDTs, coerced enums, proprietary DeviceType, and partial/extended CMAD tails are explicit risk codes. They are not hidden under a generic “unknown” label.

### Safety lattice

- `ordinarySaveSafe`: the closed-world grammar is satisfied and a dry-run writer validation succeeds.
- `lossyConvertible`: import succeeded and the modeled projection passes converted-writer validation, but one or more typed source risks would be omitted or normalized.
- `unwritable`: the modeled projection cannot produce a structurally valid TSI. The report includes the validation error and neither ordinary Save nor converted export writes a destination.

Unknown frames and extra XML are tolerated on import. They make an edited ordinary overwrite unsafe until a future patch writer can preserve them. Duplicate modeled singleton frames import as lossy-convertible when the interpreter can deterministically select the first document-order value without structural ambiguity; structurally contradictory counts or truncated data remain import errors. An unchanged save remains byte-identical and safe.

## Imported value preservation

### CMAD

`MappingEntry` gains an optional imported CMAD representation containing the exact CMAD payload plus every decoded scalar the parser reads, including:

- DeviceType
- ControllerType
- InteractionMode
- Assignment
- SetValueTo raw bits
- HasValueUI and ValueUIType
- condition target/value scalars
- LED min/max types and raw data
- LED MIDI range, invert, and blend
- UnknownVUI
- Resolution raw bits
- UseFactoryMap
- Optional and trailing CMAD bytes

For imported rows, the writer starts from those raw values and compares the row with its envelope baseline using wire representations. Floating-point values compare by raw bit pattern so NaN payloads and negative zero cannot be mistaken for an unchanged canonical value. The imported CMAD object carries its own immutable semantic-at-import snapshot, so a copied row retains a self-contained baseline even when its new destination document has no source-envelope record for its new UUID. Command-type profiles remain defaults for newly created rows only. Field ownership is explicit:

- Comment edits replace only the CMAD comment.
- Assignment and I/O edits replace their corresponding wire fields.
- Modifier edits replace the complete two-condition block.
- Set-to edits replace the raw set-to value using the command-aware encoder.
- MIDI edits replace binding/definition data and clear only obsolete opaque MIDI metadata.
- LED range/MIDI/invert/blend edits replace their corresponding raw values.
- Controller-type or command-ID edits replace the coordinated profile group: HasValueUI, ValueUIType, set-to encoding, LED range type/data defaults, blend, UnknownVUI, resolution, and any controller-type-coupled scalar.
- Interaction-mode edits replace only interaction when the imported combination remains valid; otherwise writer validation makes the document unwritable.

If a raw scalar or tail byte cannot be reconciled with an edited semantic field, the preservation report marks the ordinary overwrite lossy-convertible or unwritable instead of guessing. Converted output normalizes proprietary DeviceType to Generic MIDI `4`, normalizes its device registry name to `Generic MIDI`, omits unrepresented source structures, and uses the same profiles as a newly created row; every such normalization appears in the export warning.

### Device and ports

Imported device registry names and port strings are wire values, not labels to normalize. They are emitted verbatim while unchanged. Newly created devices may use existing safe defaults, but an imported empty port must not become `All Ports`, and an imported native name must not become `Generic MIDI` merely because it is absent from a hard-coded allowlist.

## Editing transactions

All user-visible mutations route through `TraktorMappingDocument.performUndoableMutation` or a single equivalent transaction helper.

- Edit-menu “Paste Mapped To” must call the same opaque-preserving clipboard operation as the toolbar path.
- Cross-document transfer into an existing document must require an explicit, currently valid destination device. `nil` or a stale identifier may not silently mean the first device. Pasting into a truly empty document may create one Generic MIDI destination as an explicit empty-document behavior.
- A proposed transfer is validated against the destination before insertion. Writer-level conflicts must surface before the document is mutated.
- Wizard completion applies all additions/removals in one named Undo transaction.
- Voice and wizard replacement is scoped to one explicit destination device and uses one exact `SemanticBindingKey`: command ID, I/O direction, canonical wire target, command-aware canonical set-to representation, normalized modifier 1, and normalized modifier 2. Each normalized modifier is its complete `(condition target, modifier number, value)` tuple. A missing modifier and its fully canonical inactive tuple normalize identically; different targets, modifier numbers, or values remain distinct. A condition target the app cannot model makes the binding nonreplaceable. Command display name, MIDI assignment, and comments are not part of replacement identity.
- Voice “Save & Continue” stages a mapping in session memory and changes the UI copy to “Added to Session”; it does not mutate the document or register Undo. Finish preflights the complete proposed file, applies all removals and staged insertions in one named Undo transaction, and then clears staging. Cancel discards staging and leaves the document exactly unchanged.

## Parser limits and cursor

`TSIParseLimits` provides explicit defaults and injectable test limits:

- Maximum XML bytes: 96 MiB.
- Maximum Base64 attribute characters: 64 MiB.
- Maximum decoded controller bytes: 48 MiB.
- Maximum individual frame payload: 32 MiB.
- Maximum frames per parsed container: 250,000.
- Maximum UTF-16 string bytes: 1 MiB.
- Maximum XML nodes: 100,000.
- Maximum XML nesting depth: 128.
- Maximum controller entries: 64.
- Maximum binary container depth: 16.
- Maximum cumulative frames across the document: 500,000.

Limit failures use distinct localized errors. Base64 accepts only the RFC 4648 standard alphabet with `=` padding solely in the final valid positions; whitespace and ignored characters are rejected. TSI XML input must be valid UTF-8, optionally with a UTF-8 BOM, and any XML encoding declaration must name UTF-8; UTF-16 and UTF-32 inputs are rejected before XML parsing with `unsupportedXMLEncoding`. The parser does not construct an `XMLDocument` DOM. A bounded `XMLParser` delegate performs extraction and inventory in one streaming pass, counting elements, XML depth, and controller entries before retaining attribute values. Before that pass, the validated UTF-8 text is scanned case-insensitively to reject `DOCTYPE`, `ENTITY`, and external-entity declarations. External entity resolution is also disabled in `XMLParser`, and every DTD/entity declaration callback aborts parsing as defense in depth. Tests cover UTF-8 internal entity amplification, external declarations, UTF-16/UTF-32 entity encodings, XML node/depth boundaries, and every binary depth boundary at limit minus one, limit, and limit plus one.

`TSIFrame` parses from a shared `Data` plus offset. It validates integer overflow before calculating frame bounds, reads big-endian integers with unaligned-safe operations, and copies only the final payload retained by `TSIFrame`. Top-level and nested frame loops advance offsets without copying the entire remaining tail. Arrays reserve bounded capacity where counts are declared.

These changes must make frame parsing linear in input length. Per-container frame limits apply to every frame loop, including CMAS and DCBM, while the cumulative budget applies across the entire controller payload. Inventory traversal is iterative or depth-bounded. A performance regression test compares equivalent payloads with increasing frame counts using a generous ratio rather than brittle wall-clock thresholds.

## Fixtures and evidence

Fixtures live under `XtremeMapping/XtremeMappingTests/Fixtures/TSI/` with a machine-readable manifest containing:

- Fixture filename and SHA-256.
- Provenance category: `realExport`, `capturedFragment`, or `generated`.
- Source application/version when actually evidenced.
- Controller type.
- License/source URL when imported from a public repository.
- Sanitization notes.
- Expected import and save behavior.
- Completeness: `completeDocument` or `capturedFragment`.

No generated or reduced fixture may be described as a real Traktor 4.4.x or 4.5.2 export. The implementation may sanitize a user-owned complete 4.4.x export already present in the local Traktor directory, recording the original hash privately only in the development report and committing only the sanitized fixture. If no 4.5.2 specimen is locally available with reliable provenance, the harness and 4.4.x fixture are shipped honestly and the absent 4.5.2 specimen is a documented evidence gap rather than being fabricated.

Tests cover:

- Exact unchanged round trip for every complete fixture.
- Preservation report inventory for unknown XML, multiple controller entries, unknown nested frames, duplicate singleton frames, and native MIDI bindings.
- Safe edited write for a fully modeled fixture.
- Refusal of edited overwrite for an unsafe fixture.
- Deliberate converted-copy output that reparses successfully.
- Imported CMAD/device/port scalar preservation.
- Stable deterministic risk codes and report ordering.
- An unwritable projection that disables both save paths without dirtying or changing the document.

## Failure behavior and recovery

- Parsing never returns a partial document after a structural or resource-limit error.
- Unsafe overwrite errors name the preservation risks and state that the original was not changed.
- Converted-copy failures leave no partial destination file; the Save panel path uses atomic `Data.write(options: .atomic)`. Success and failure both leave the source document URL, dirty state, baseline, envelope, and Undo stack unchanged.
- Transfer, wizard, and voice preflight failures leave the in-memory document unchanged and register no Undo operation.
- Existing opaque native bindings remain visible through compatibility warnings.

The recovery path for implementation regressions is branch rollback. There is no data migration and no production deployment in this task.

## Acceptance matrix

| Requirement | Observable proof |
|---|---|
| Unchanged import is lossless | The document `snapshot` plus `fileWrapper` path returns bytes exactly equal to each complete fixture |
| Unsafe edited overwrite is prevented | Writer/document throws the dedicated error and original bytes remain unchanged |
| Converted copy is intentional | Separate Export API/UI path, canonical different URL, complete omission warning, output reparses, source state unchanged |
| Unwritable stays unwritten | Both save paths reject before destination mutation and report the writer validation error |
| CMAD fidelity | Non-default imported raw scalar fixture re-exports the same scalar values |
| Device identity fidelity | Unknown native name and empty ports survive unchanged |
| Opaque MIDI paste fidelity | Toolbar and Edit-menu paths retain identical raw binding/definition metadata |
| Transfer safety | Ambiguous destination or conflicting definitions cause no mutation |
| Undo consistency | Wizard and voice save each undo in one step to the exact prior mapping file |
| Conflict scope | Voice overwrite removes only rows in the explicit destination device matching all six `SemanticBindingKey` components; negative tests vary device and every component |
| Parser bounds | Each configured limit has a focused rejection test |
| Parser complexity | Cursor implementation performs no remaining-tail copies and scaling test stays within its documented ratio |
| Regression evidence | Manifest hashes and provenance categories validate in tests |
| Compatibility | All unaffected tests remain green; intentionally superseded fallback/voice tests are updated with rationale; Release build and static analysis pass |

## Shipping gates

This branch is complete only after:

1. Every production behavior was introduced through a witnessed failing test.
2. The full unit suite passes freshly.
3. The Release build and static analyzer succeed.
4. Independent code review closes all critical and important findings.
5. No existing user files or untracked build artifacts are modified.
6. The work remains on its isolated branch; merge, push, DMG creation, website updates, and release publication require separate authorization.
