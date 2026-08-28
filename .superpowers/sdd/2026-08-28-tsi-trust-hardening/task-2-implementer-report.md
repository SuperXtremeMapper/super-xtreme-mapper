# Task 2 Implementer Report: Raw Source Envelope and Preservation Safety Lattice

## Status

Implemented and verified the Task 2 document-boundary source envelope, semantic baseline, closed-world typed inventory, stable risk ordering, and the `ordinarySaveSafe` / `lossyConvertible` / `unwritable` lattice. The implementation preserves exact original XML for unchanged complete imports, refuses an edited unsafe ordinary overwrite, and supports deliberate canonical conversion through `writeConverted`.

## TDD evidence

### Initial RED (before production edits)

Command:

```text
./scripts/test-unit.sh -only-testing:XtremeMappingTests/TSIPreservationTests -only-testing:XtremeMappingTests/MappingEntryTests
```

Result: compilation failed as expected because the tests referenced the not-yet-implemented `TSIParser.parseDocument(_:)`, `TSIRawEnvelope`, preservation risk/report types, `TSIWriter.preservationReport(for:)`, and `TSIWriter.writeConverted(_:)`. Production files had not been edited. Result bundle:

```text
/var/folders/3r/cg8yjhxx553261yzd9yjq71m0000gn/T/xtrememapping-unit-tests.zmrqTvg8kl/UnitTests.xcresult
```

### Additional REDs found while closing the inventory

- A duplicate-DDCI regression test was added before changing interpreter behavior and failed with exit 65 because the interpreter still rejected a structurally valid duplicate container instead of importing the first document-order value and reporting a risk.
- A lossy CMAD-comment regression was added before its implementation. Command:

```text
./scripts/test-unit.sh -only-testing:XtremeMappingTests/TSIPreservationTests/testLossyCMADCommentHasSpecificStringRisk
```

Result: 0 passed, 1 failed. The actual risk was `unreproducibleCMAD`; the required specific risk was `lossyString`. Result bundle:

```text
/var/folders/3r/cg8yjhxx553261yzd9yjq71m0000gn/T/xtrememapping-unit-tests.gc0g6PWKch/UnitTests.xcresult
```

### GREEN

- Focused parser/interpreter/preservation/model run: 245 passed, 0 failed.
- Lossy CMAD regression after the narrow fix: 1 passed, 0 failed. Result bundle: `/var/folders/3r/cg8yjhxx553261yzd9yjq71m0000gn/T/xtrememapping-unit-tests.C124OxssoW/UnitTests.xcresult`.
- Required full command `./scripts/test-unit.sh`: 484 passed, 0 failed. Result bundle: `/var/folders/3r/cg8yjhxx553261yzd9yjq71m0000gn/T/xtrememapping-unit-tests.reSzMNoH1U/UnitTests.xcresult`.
- `git diff --check`: clean.

## Files changed

Production:

- `XtremeMapping/XtremeMapping/Models/MappingFile.swift`
- `XtremeMapping/XtremeMapping/Models/TSI/TSIPreservation.swift` (new)
- `XtremeMapping/XtremeMapping/Models/TSI/TSISourceInventory.swift` (new)
- `XtremeMapping/XtremeMapping/Models/TSI/TSIXMLScanner.swift`
- `XtremeMapping/XtremeMapping/Models/TSI/TSIParser.swift`
- `XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift`
- `XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift`

Tests:

- `XtremeMapping/XtremeMappingTests/TSIPreservationTests.swift` (new)
- `XtremeMapping/XtremeMappingTests/MappingEntryTests.swift`
- `XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift`

## Implementation and integration notes

- `TSIRawEnvelope` owns the exact XML bytes, every Controller entry value in document order, Task 1 bounded primary frames, an acyclic semantic baseline, and deterministically sorted typed risks.
- `MappingFile.sourceEnvelope` is intentionally absent from Codable and semantic equality. The baseline stores `[Device]` plus version rather than recursively embedding another `MappingFile`.
- `TSIParser.parseDocument(_:)` uses the bounded XML scanner, strict base64 decoder, bounded frame cursor/parser, interpreter, and iterative inventory. Existing lower-level compatibility entry points remain intact.
- The XML scanner records extra Controller entries, other Entry structures, and nonstandard hierarchy/attributes/content while retaining compatibility with direct structurally valid Entry documents.
- The iterative, known-container-only binary inventory classifies counts, singleton cardinality, placement, unknown frames, typed scalars, UTF-16 fidelity, definitions, mappings, bindings, native MIDI, command-zero records, proprietary/coerced fields, and CMAD layout/fidelity. Unknown payloads are not recursively guessed. Checked arithmetic is used at byte/string boundaries.
- Duplicate definition containers and duplicate binding IDs are structurally valid imports: the interpreter selects the first document-order value while the inventory blocks an edited ordinary overwrite with a typed risk.
- The ordinary writer returns byte-exact original XML while the semantic baseline matches. Once changed, canonical writer validation runs first; validation failure yields `unwritable`, any source risk yields `lossyConvertible` and ordinary-write refusal, and no risk yields `ordinarySaveSafe`. `writeConverted` is the explicit lossy/canonical path.
- Until Task 3 owns wire scalars, any full CMAD payload that the current writer cannot reproduce is classified as `unreproducibleCMAD`; partial, extended, proprietary, coerced, and lossy-comment cases receive more specific risks.

## Self-review

- Re-read the Task 2 brief and approved design against actual parser, scanner, interpreter, writer, `MappingFile`, `Device`, and `MappingEntry` signatures.
- Confirmed the envelope is document-boundary state, acyclic, Sendable, excluded from Codable, and excluded from semantic equality.
- Confirmed stable risk ordering is path, then risk code, then detail, independent of traversal order.
- Confirmed structurally corrupt frames/counts/CMAD still throw, while structurally valid unknown/duplicate/proprietary/native input imports with an overwrite-blocking risk.
- Confirmed unchanged complete import is exact-byte passthrough and edited unsafe import cannot use ordinary write; explicit conversion reparses.
- Confirmed dry-run writer validation outranks preservation risks in the lattice and returns a typed validation snapshot.
- Confirmed Task 1 bounded scanner/cursor/budget APIs are used and unknown frames are treated atomically.
- Confirmed no document lifecycle/UI behavior, merge, push, package, or unrelated artifact was included.

## Concerns / next-task seams

- The existing document initializer still uses its compatibility parse sequence; Task 4 is expected to adopt `parseDocument(_:)` and surface the preservation report/refusal in the document workflow. This task deliberately does not broaden into document lifecycle/UI changes.
- Task 3 should replace conservative `unreproducibleCMAD` risks only where exact imported scalar/layout ownership is added. It must not accidentally make partial, extended, lossy, proprietary, or coerced payloads ordinary-save-safe.
- The full build continues to emit pre-existing actor-isolation and package dependency warnings; no new Task 2 warning remained after the Sendable audit.

## Rollback

The Task 2 commit can be reverted as one unit. No schema migration or external state is created; envelopes are runtime-only and excluded from Codable.
