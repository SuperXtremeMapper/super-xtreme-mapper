# TSI Trust Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Make TSI import, no-op save, edited save, batch transfer, wizard/voice mutation, and hostile-file parsing conservative, loss-aware, and verifiably safe.

**Architecture:** MappingFile remains the editable semantic projection while an import-only raw envelope lives at the document boundary. A bounded streaming XML parser and offset-based binary cursor produce the projection and a typed source inventory; a pure analyzer selects exact passthrough, safe regeneration, lossy export, or refusal. All edit surfaces use one preflighted document transaction path.

**Tech Stack:** Swift 5, SwiftUI ReferenceFileDocument, AppKit NSDocument/UndoManager, Foundation XMLParser, XCTest/Swift Testing, Xcode 26 with macOS 14 target.

**Spec:** docs/superpowers/specs/2026-08-28-tsi-trust-hardening-design.md

## Global Constraints

- Ordinary Save must never silently degrade an imported TSI.
- An unchanged complete import emits the exact original bytes.
- XML is UTF-8 only; streaming limits and DTD/entity rejection happen before attribute retention.
- Default limits exactly match the specification.
- Imported CMAD, device/port strings, comments, modifiers, opaque MIDI bindings, and DCDT metadata remain wire-faithful until their owning field is explicitly edited.
- Converted copy is a lossy Export and never changes document URL, dirty state, envelope, baseline, or Undo state.
- Every visible mutation is atomic, preflighted, and Undoable; failure has no document or Undo side effect.
- Every production behavior begins with a witnessed failing test using hand-derived expectations.
- Do not touch unrelated parent-checkout artifacts.
- Do not merge, push, publish, package, update the website, or change release signing.

---

### Task 1: Bounded streaming XML and linear binary cursor

**Files:**
- Create: XtremeMapping/XtremeMapping/Models/TSI/TSIParseLimits.swift
- Create: XtremeMapping/XtremeMapping/Models/TSI/TSIXMLScanner.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIParser.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIFrame.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift
- Test: XtremeMapping/XtremeMappingTests/TSIParserTests.swift
- Test: XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift

**Interfaces:**
- TSIParseLimits.default contains the exact limits in the spec and is injectable through TSIParser.init(limits:).
- TSIXMLScanResult contains controllerValues, hasNonControllerEntries, and elementCount. The XML resource limit is `maximumXMLElements`, counted exactly once per `didStartElement` callback.
- TSIFrame.parse(from:at:limits:) returns a frame and nextOffset.
- extractControllerData remains a compatibility wrapper returning the first scanned controller value.
- Nested parsing consumes offsets and one shared cumulative TSIParseBudget.

- [ ] **Step 1: Write failing threat and boundary tests**

Add literal tests for UTF-16/32 rejection, UTF-8 BOM, false encoding declarations, DTD/entity amplification, external entities, XML byte/element/depth/controller limits, strict Base64 alphabet/padding/whitespace, decoded bytes, frame payload, per-container/cumulative frame counts, UTF-16 strings, binary depth, overflow and truncation. Exercise each numerical boundary at limit minus one, limit, and limit plus one.

Example expected behavior:

~~~swift
func testRejectsUTF16BeforeXMLParsing() {
    let data = "<?xml version=\"1.0\" encoding=\"UTF-16\"?><NIXML/>".data(using: .utf16)!
    XCTAssertThrowsError(try TSIParser.scanXML(data)) {
        XCTAssertEqual($0 as? TSIParserError, .unsupportedXMLEncoding)
    }
}
~~~

- [ ] **Step 2: Run TSIParserTests and TSIInterpreterTests; witness RED**

Run xcodebuild test for only those two test classes with CODE_SIGNING_ALLOWED=NO. The new tests must fail for the missing limit/scanner/cursor APIs, not from test syntax.

- [ ] **Step 3: Implement limits and streaming XML**

Use XMLParserDelegate with shouldResolveExternalEntities false. Abort every DTD/entity declaration callback. Validate UTF-8/BOM/declaration and scan validated text for prohibited declarations before XMLParser. Count elements/depth/controller entries in didStartElement before retaining attributes.

- [ ] **Step 4: Implement offset frame parsing**

Use checked offset arithmetic and loadUnaligned for UInt32. Copy only the final retained payload. Convert every interpreter container loop, including CMAS and DCBM, to offsets with depth and cumulative budget.

- [ ] **Step 5: Add a scaling regression**

After warm-up, parse 2,000 and 8,000 equal-size frames. Require exact counts and a generous less-than-8x runtime ratio. Add a test-visible instrumentation count proving no remaining-tail copies.

- [ ] **Step 6: Run focused tests and ./scripts/test-unit.sh**

Expected: all pass with no crash and no new warnings from changed files.

- [ ] **Step 7: Commit**

Commit message: fix: bound and linearize TSI parsing

---

### Task 2: Raw source envelope and preservation safety lattice

**Files:**
- Create: XtremeMapping/XtremeMapping/Models/TSI/TSIPreservation.swift
- Create: XtremeMapping/XtremeMapping/Models/TSI/TSISourceInventory.swift
- Modify: XtremeMapping/XtremeMapping/Models/MappingFile.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIParser.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift
- Test: XtremeMapping/XtremeMappingTests/TSIPreservationTests.swift
- Test: XtremeMapping/XtremeMappingTests/MappingEntryTests.swift

**Interfaces:**
- TSISemanticBaseline stores devices/version without recursively embedding MappingFile.
- TSIRawEnvelope stores originalXML, every controller value, primary frames, baseline and typed risks.
- TSIPreservationRisk.Code is stable and covers every closed-world exclusion.
- TSIPreservationReport.disposition is ordinarySaveSafe, lossyConvertible, or unwritable.
- MappingFile.sourceEnvelope is excluded from Codable and semantic equality.
- TSIParser.parseDocument(_:) is the document import seam.
- TSIWriter.writeConverted(_:) deliberately bypasses passthrough but retains structural validation.

- [ ] **Step 1: Write failing lattice tests**

Build literal complete documents for minimal safe, unknown frames, extra XML/controller entries, noncanonical DIOI/DDIF, duplicate singleton, unused/duplicate DCDT/DCBM, command-zero CMAI, proprietary DeviceType, coerced enums, partial/extended CMAD, dangling binding, and writer-invalid projections. Assert exact stable risk codes and dispositions. Prove envelope data is absent from clipboard Codable and ignored by semantic equality.

- [ ] **Step 2: Run the new preservation tests; witness RED**

The failure must be missing behavior/types.

- [ ] **Step 3: Implement envelope and semantic-only Codable/equality**

Use explicit MappingFile coding keys for devices/version. sourceEnvelope defaults nil. Equality compares devices/version only.

- [ ] **Step 4: Implement exhaustive source inventory**

Walk the known hierarchy iteratively with path/cardinality rules from the spec. Any unclassified byte, frame, scalar, count, definition, binding, placeholder, tail, or XML structure produces a stable risk. Structural corruption still throws.

- [ ] **Step 5: Implement the analyzer and writer seams**

Dry-run converted output first: failure means unwritable; any inventory risk means lossyConvertible; empty risk inventory means ordinarySaveSafe. Sort risks by path then code. TSIWriter.write returns originalXML when semantic baseline is unchanged, refuses unsafe changed sources, and writeConverted performs canonical output.

- [ ] **Step 6: Run focused tests and full unit suite**

- [ ] **Step 7: Commit**

Commit message: feat: add loss-aware TSI source envelopes

---

### Task 3: Preserve imported CMAD, device and port wire values

**Files:**
- Create: XtremeMapping/XtremeMapping/Models/TSI/ImportedCMAD.swift
- Modify: XtremeMapping/XtremeMapping/Models/MappingEntry.swift
- Modify: XtremeMapping/XtremeMapping/Models/Device.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift
- Modify: XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift
- Test: XtremeMapping/XtremeMappingTests/MappingEntryTests.swift
- Test: XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift

**Interfaces:**
- ImportedCMAD is Codable and contains exact payload, all decoded raw scalars and immutable semantic-at-import wire fingerprint.
- MappingEntry.importedCMAD survives Codable and copyWithNewID.
- Writer compares raw bit patterns and uses command profiles only for new/converted rows or explicitly changed owning groups.
- Device writer emits name/inPort/outPort verbatim; no allowlist or empty-port coercion.

- [ ] **Step 1: Write failing noncanonical round-trip and ownership-isolation tests**

Use literal CMAD values for proprietary DeviceType, nondefault UI scalars, negative-zero/NaN bit patterns, condition targets, LED data, blend, UnknownVUI, resolution, UseFactoryMap and optional/trailing bytes. Add native name and empty ports. At byte level, vary exactly one semantic ownership group at a time—comment, assignment/I/O, modifiers, set-to, MIDI, LED fields, controller-type, command-ID, and interaction—and prove unrelated raw values remain identical. Cover every coordinated profile replacement and assert lossyConvertible or unwritable for every unreconcilable state.

- [ ] **Step 2: Run focused tests; witness RED**

- [ ] **Step 3: Implement ImportedCMAD parsing and propagation**

Store floating values as UInt32 wire bits in the fingerprint and decode older Codable payloads with nil imported state.

- [ ] **Step 4: Implement ownership-aware output**

Start imported output from raw values and replace only groups named in the spec. Unreconcilable state yields a risk/refusal. Retain profiles for new/converted rows.

- [ ] **Step 5: Remove device/port normalization and validate new rows**

Imported/current strings emit exactly. A new empty device name is unwritable; existing UI-created Generic MIDI paths remain valid.

- [ ] **Step 6: Run focused/full tests and commit**

Commit message: fix: preserve imported CMAD and device wire values

---

### Task 4: Document save lifecycle and lossy converted export

**Files:**
- Modify: XtremeMapping/XtremeMapping/XtremeMappingDocument.swift
- Modify: XtremeMapping/XtremeMapping/XtremeMappingApp.swift
- Create: XtremeMapping/XtremeMapping/Commands/TSIExportCommands.swift
- Test: XtremeMapping/XtremeMappingTests/DocumentTests.swift
- Test: XtremeMapping/XtremeMappingTests/TSIPreservationTests.swift

**Interfaces:**
- DocumentWriteSnapshot is ReferenceFileDocument.Snapshot and contains mappingFile, plan and generation.
- TSIWritePlan contains exact output, baseline, report and passthrough/regenerated disposition.
- TraktorMappingDocument exposes prepareWriteSnapshot, commitPendingWrite and discardPendingWrite with one receipt.
- DocumentSaveCoordinator replaces DocumentGroup Save/Save As commands and is also used by close/termination paths so every save has a completion callback.
- exportLossyConvertedCopy(to:) uses filesystem identity checks and atomic Data.write.

- [ ] **Step 1: Write failing lifecycle tests**

Cover exact fileWrapper no-op bytes; safe edit/save/second save; unchanged and regenerated Save As; failed save/retry; edit during save; Undo after save; concurrent receipt refusal; converted export success/failure; source aliases through symlink, case, Unicode normalization and resource identifier. Assert URL/dirty/envelope/baseline/Undo invariants. Exercise Save, Save As, close and termination through the same completion-aware coordinator; failure or cancellation must discard the receipt and allow a retry.

- [ ] **Step 2: Run DocumentTests and TSIPreservationTests; witness RED**

- [ ] **Step 3: Implement plan and receipt state machine**

Compute one immutable plan in snapshot(contentType:), reject a second in-flight receipt, and let fileWrapper return immutable plan bytes. Replace the DocumentGroup Save and Save As command group with a coordinator that invokes NSDocument completion APIs; route close/termination through it too. Success commits; failure/cancellation discards. Regenerated success reparses exact output into the new authoritative envelope. Never combine new baseline with old bytes. Autosave remains disabled, and the success notification is not relied upon to clean up failed receipts.

- [ ] **Step 4: Implement Export Lossy Converted Copy**

Add a focused File menu command available only for lossyConvertible. Present ordered risks before the Save panel. Compare standardized/symlink-resolved paths, volume case/normalization and existing resource identifiers. Reject aliases and write atomically.

- [ ] **Step 5: Run focused and full suites**

- [ ] **Step 6: Commit**

Commit message: feat: make TSI saves preservation-aware

---

### Task 5: Safe batch paste and transfer

**Files:**
- Modify: XtremeMapping/XtremeMapping/Services/ClipboardManager.swift
- Modify: XtremeMapping/XtremeMapping/Services/MappingTransferService.swift
- Modify: XtremeMapping/XtremeMapping/Commands/EditCommands.swift
- Modify: XtremeMapping/XtremeMapping/ContentView.swift
- Test: XtremeMapping/XtremeMappingTests/ClipboardManagerTests.swift
- Test: XtremeMapping/XtremeMappingTests/MappingTransferServiceTests.swift
- Test: XtremeMapping/XtremeMappingTests/DocumentTests.swift

**Interfaces:**
- ClipboardManager applies complete assignment/raw metadata to selected IDs.
- MappingTransferService.insertCopies becomes throwing and returns MappingTransferResult.
- Existing documents require a valid explicit target; only a truly empty file may create Generic MIDI.
- preflight builds a candidate and dry-runs TSIWriter.writeConverted before mutation.

- [ ] **Step 1: Write failing paste/transfer tests**

Prove menu-equivalent batch paste retains raw control name, binding ID, DCDT metadata, pitch bend and paired CC fields. Replace stale fallback expectations with missing/stale destination errors and no mutation. Add conflicting DCDT candidate and Undo-no-side-effect tests.

- [ ] **Step 2: Run focused tests; witness RED**

- [ ] **Step 3: Unify mapped-to paste**

Both toolbar and Edit menu call the complete ClipboardManager operation. Do not route an opaque copy through midiAssignment.didSet unless it is an explicit normalized reassignment.

- [ ] **Step 4: Add throwing destination/preflight transfer**

Mutate a candidate only, validate converted output, then assign the candidate on success. Return localized typed errors.

- [ ] **Step 5: Wire safe UI behavior**

Use the sole selected device when unambiguous. Disable/explain paste for multi-device selection and surface preflight failure without dirty state.

- [ ] **Step 6: Run focused/full tests and commit**

Commit message: fix: preflight and preserve batch mapping transfers

---

### Task 6: Atomic wizard and staged voice transactions

**Files:**
- Create: XtremeMapping/XtremeMapping/Models/SemanticBindingKey.swift
- Create: XtremeMapping/XtremeMapping/Services/VoiceMappingBuilder.swift
- Modify: XtremeMapping/XtremeMapping/Services/WizardCoordinator.swift
- Modify: XtremeMapping/XtremeMapping/Services/VoiceMappingCoordinator.swift
- Modify: XtremeMapping/XtremeMapping/ContentView.swift
- Modify: XtremeMapping/XtremeMapping/Views/VoiceLearnOverlay.swift
- Test: XtremeMapping/XtremeMappingTests/WizardCoordinatorTests.swift
- Test: XtremeMapping/XtremeMappingTests/VoiceMappingCoordinatorTests.swift
- Test: XtremeMapping/XtremeMappingTests/DocumentTests.swift

**Interfaces:**
- SemanticBindingKey includes command ID, direction, canonical target, command-aware set-to wire representation and two full condition target/modifier/value tuples; destination device scopes replacement separately.
- VoiceMappingBuilder.makeEntry(midi:result:) returns MappingEntry without document mutation.
- Voice coordinator owns stagedMappings; Save & Continue appends only there.
- Wizard and voice Finish use one throwing performUndoableMutation and validate the candidate before assignment.

- [ ] **Step 1: Write failing identity/atomicity tests**

Vary device, direction, target, set-to, condition target, modifier number and modifier value individually. Unsupported condition targets are nonreplaceable. Assert one-step wizard/voice Undo, no voice mutation before Finish, Cancel unchanged, and failed Finish leaves staging but document unchanged.

- [ ] **Step 2: Run focused tests; witness RED**

- [ ] **Step 3: Implement shared identity**

Use the same command-aware set-to wire encoder as TSIWriter; do not round generically. Normalize only canonical inactive modifier tuples.

- [ ] **Step 4: Make wizard one transaction**

Scope replacement to the explicit destination device, build/validate a candidate inside performUndoableMutation and use the backing NSDocument UndoManager. Remove direct mutation plus noteChange.

- [ ] **Step 5: Stage voice and finish once**

Replace the mutating insertion closure with VoiceMappingBuilder. Change copy to Added to Session. Finish preflights and commits removal/insertion once; Cancel clears staging only.

- [ ] **Step 6: Run focused/full tests and commit**

Commit message: fix: make wizard and voice saves atomic

---

### Task 7: Fixtures, provenance and final integration

**Files:**
- Create: XtremeMapping/XtremeMappingTests/Fixtures/TSI/manifest.json
- Create: XtremeMapping/XtremeMappingTests/Fixtures/TSI/traktor-4.4.x-sanitized-complete.tsi
- Create: XtremeMapping/XtremeMappingTests/Fixtures/TSI/generated-safe-minimal.tsi
- Create: XtremeMapping/XtremeMappingTests/Fixtures/TSI/generated-unsafe-native.tsi
- Create: XtremeMapping/XtremeMappingTests/TSIFixtureTests.swift
- Create: XtremeMapping/docs/TSI-Fixture-Provenance.md
- Modify: XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift
- Modify: XtremeMapping/docs/TSI-File-Format.md

**Interfaces:**
- Manifest fields: filename, SHA-256, provenance, completeness, evidenced version, controller, source/license, sanitization, expected disposition and ordered risk codes.
- Loader validates hashes before using fixtures.
- Reduced 4.4.1 and constructed 4.5.2 tests are renamed to captured/reduced truthfully.

- [ ] **Step 1: Write failing manifest/fixture tests**

Fail for missing fixture, wrong hash, unknown metadata, non-identical complete document-layer no-op, or risk drift. Exercise TraktorMappingDocument snapshot/fileWrapper, not only helper round-trip.

- [ ] **Step 2: Run fixture tests; witness RED**

- [ ] **Step 3: Add sanitized real and generated fixtures**

Choose the smallest locally available, user-owned complete Traktor 4.4.x export that exercises real controller structures. Remove personal comments/labels and document every transformation without inventing version evidence. Add deterministic generated safe/unsafe files.

If no complete 4.5.2 specimen is locally available, record the exact gap; keep existing opaque-name evidence labeled capturedFragment, never realExport or completeDocument.

- [ ] **Step 4: Validate hashes and behavior**

The real fixture must open and exact no-op round-trip or expose a structural defect that blocks this branch. Generated files prove safe regeneration and lossy conversion.

- [ ] **Step 5: Update file-format documentation**

Document envelope, safety lattice, exact limits, UTF-8, Pitch Bend/paired CC/native behavior, imported CMAD and fixture rules. Remove the old statement that unknown frames simply disappear on Save.

- [ ] **Step 6: Run fresh final verification**

Run:

~~~bash
./scripts/test-unit.sh
xcodebuild analyze -project XtremeMapping/SuperXtremeMapping.xcodeproj -scheme XtremeMapping -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project XtremeMapping/SuperXtremeMapping.xcodeproj -scheme XtremeMapping -configuration Release -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO
git diff --check
~~~

Expected: zero test failures, analyze/build exit zero and no whitespace errors.

- [ ] **Step 7: Commit**

Commit message: test: add provenance-backed TSI regression fixtures

---

## Final review package

The whole-branch reviewer receives the approved specification, this plan, complete diff from 2c1293c, tracked/untracked/generated status, SDD ledger with all rulings and Agency IDs, fresh verification, and fixture provenance. This plan does not merge or push the branch.
