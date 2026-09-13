# JSON Interchange Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export editable JSON and review imports without silently losing TSI source data or accepting invalid mappings.

**Architecture:** A dedicated public JSON document and codec surround MappingFile. A preservation bridge reconstructs trusted parser state from embedded source bytes, and a pure validator produces an import candidate and diagnostics before UI acceptance.

**Tech Stack:** Swift, Foundation, SwiftUI/AppKit, XCTest, existing TSI parser/writer. No new API dependency.

**Spec:** `docs/superpowers/specs/2026-09-12-mapping-interchange-assistant-design.md` (JSON release and diagnostics sections).

## Global constraints

- MappingFile remains the runtime mapping model.
- No API key is needed for JSON, local diagnostics, profiles, or deterministic reference tables.
- Import JSON opens a reviewed new untitled TSI document.
- Save continues to produce TSI; Export JSON is a separate action that does not clear dirty state.
- Exact no-op TSI round trips are required for source-backed documents the existing parser accepts.
- Unsupported edits must not trigger silent regeneration.
- Preserve current unsaved edits in the editable projection, even when the retained source predates those edits.
- Never replace the source baseline with that edited projection.

## File boundaries

All app paths below are relative to `XtremeMapping/XtremeMapping/`; tests are under `XtremeMapping/XtremeMappingTests/`.

| New file | Responsibility |
|---|---|
| `Models/Interchange/SXMJSONDocument.swift` | Versioned public DTOs and exhaustive field conversion |
| `Models/Interchange/SXMJSONCodec.swift` | Deterministic serialization and bounded structural decoding |
| `Models/Interchange/SXMJSONPreservation.swift` | Source reconstruction and stable-ID correspondence |
| `Models/Interchange/MappingDiagnostic.swift` | Shared diagnostic records and import result |
| `Services/MappingValidationService.swift` | Semantic checks and writer preflight |
| `Services/JSONImportService.swift` | Decode, validation, and immutable candidate orchestration |
| `Commands/JSONImportExportCommands.swift` | File panels and reviewed document creation |
| `Views/JSONImportReviewSheet.swift` | Summary and actionable diagnostics |

Integrate through `XtremeMappingApp.swift`, `ContentView.swift`, and `XtremeMappingDocument.swift` where required. Reuse `Commands/TSIExportCommands.swift` publication safeguards without altering converted-export semantics. Add source files to `XtremeMapping/SuperXtremeMapping.xcodeproj/project.pbxproj` if its group configuration requires registration.

## Task 1: Baseline, field contract, and codec

- [ ] Record `git status --short`; create an isolated `codex/` development branch/worktree according to repository guidance. Do not include existing unrelated diagnostic files or `default.profraw` in commits.
- [ ] Run `scripts/test-unit.sh` and record any pre-existing failures before editing.
- [ ] Inventory stored fields in MappingFile, Device, MappingEntry, ModifierCondition, MIDIAssignment, and ImportedCMAD. Write `XtremeMapping/docs/SXM-JSON-Format.md` with one editable/derived/preserved classification per field. Derived text never overrides command identity silently; opaque fields remain in source-backed preservation.
- [ ] Create `XtremeMapping/XtremeMapping/Resources/Schemas/sxm-mapping-v1.schema.json` matching the spec limits, string enums, ID requirements, metadata envelope, and version discriminator. Use decimal human MIDI channels 1–16 and bytes 0–127. Explicitly document exceptional floating-point/raw-bit preservation rather than emitting invalid JSON NaN/Infinity.
- [ ] Add `SXMJSONCodecTests.swift` with the test below, then tests for stable repeated encoding, Unicode comments, reordered rows, all editable fields, unsupported version, missing required fields, unknown keys, and JSON-created source-free mappings. Run the focused suite to establish failure before implementation.

Proposed boundary signatures (define these in this task):

```swift
enum SXMJSONCodec {
    static func encode(_ file: MappingFile) throws -> Data
    static func decode(_ data: Data) throws -> MappingFile
}
```

Initial test:

```swift
import XCTest
@testable import XtremeMapping

final class SXMJSONCodecTests: XCTestCase {
    func testEmptyDocumentHasStableRoundTrip() throws {
        let file = MappingFile()
        let data = try SXMJSONCodec.encode(file)
        XCTAssertEqual(try SXMJSONCodec.decode(data), file)
        XCTAssertEqual(try SXMJSONCodec.encode(file), data)
    }
}
```

- [ ] Implement the separate DTO conversion and codec against the field inventory. Do not change clipboard decoding to use the new format. Perform bounded token scanning before decoding, rejecting duplicate keys and depth/size violations; preserve source byte offsets for syntax diagnostics. Do not use regex to parse JSON.
- [ ] Run `scripts/test-unit.sh -only-testing:XtremeMappingTests/SXMJSONCodecTests`; require the schema and Swift validation to agree on accepted examples. Commit only this task's schema, codec, tests, and format documentation once passing.

## Task 2: Preservation bridge and fixture proof

**Consumes:** `SXMJSONCodec.encode(_:)` and `decode(_:)`, plus the existing `TSIParser().parseDocument(_:)` and `TSIWriter().write(_:)`.

**Produces:** source-backed encode/decode behavior retaining original bytes, baseline identity, and current edits.

- [ ] Add `SXMJSONPreservationTests.swift` with the following regression. Resolve fixture paths with `#filePath` as existing fixture tests do, not a developer-specific absolute directory.

```swift
func testUneditedComplexFixtureReturnsExactBytes() throws {
    let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("Fixtures/TSI")
    let data = try Data(contentsOf: directory.appendingPathComponent(
        "traktor-4.4.x-sanitized-complete.tsi"))
    let original = try TSIParser().parseDocument(data)
    let restored = try SXMJSONCodec.decode(SXMJSONCodec.encode(original))
    XCTAssertEqual(try TSIWriter().write(restored), data)
}
```

- [ ] Extend the regression to all fixtures accepted by the existing parser. Add original-source/current-unsaved-edit, external-comment-edit, reorder, add/remove row, duplicate source identity, inconsistent preservation metadata, damaged base64, and unsupported semantic edit cases. Assert refusal rather than loss for edits the existing writer cannot preserve.
- [ ] Run the focused suite and confirm failure before adding the bridge.
- [ ] Serialize original XML plus correspondence between original device/mapping positions and stable public IDs. Reparse source to rebuild raw frames, risks, and semantic baseline; validate correspondence counts, uniqueness, and source locations, then restore exported IDs. Reuse source-derived imported state only for matched rows. Treat new rows as new, and reject dangling or duplicate source references. A source digest never replaces parsing or validation.
- [ ] Overlay editable projection by stable identity without overwriting the reconstructed baseline. Keep array order from JSON. For source-free imports, create canonical modeled state without claiming retained opaque data.
- [ ] Run `scripts/test-unit.sh -only-testing:XtremeMappingTests/SXMJSONPreservationTests -only-testing:XtremeMappingTests/TSIPreservationTests -only-testing:XtremeMappingTests/MappingTransferCodecTests`. Commit the bridge only after byte-level assertions and existing preservation tests pass.

## Task 3: Diagnostic model and import service

**Produces:** these boundary records and entry point, defined here for UI consumption:

```swift
enum MappingDiagnosticSeverity: String, Codable { case error, warning, information }
struct MappingDiagnostic: Identifiable {
    let id: UUID
    let code: String
    let severity: MappingDiagnosticSeverity
    let path: String
    let deviceID: UUID?
    let mappingID: UUID?
    let message: String
    let suggestion: String?
}
struct JSONImportCandidate {
    let mappingFile: MappingFile?
    let diagnostics: [MappingDiagnostic]
    let canOpen: Bool
    let canWriteTSI: Bool
}
enum JSONImportService {
    static func review(_ data: Data) -> JSONImportCandidate
}
```

- [ ] Add `JSONImportServiceTests.swift`. Assert malformed JSON yields `canOpen == false`, no mappingFile, and a syntax diagnostic. Assert well-formed invalid MIDI values identify the exact path. Cover command name/ID conflict, known-invalid direction, duplicate IDs, unknown new commands, unchanged unknown source commands, unsupported schema, resource limits, and suspicious but intentional overlaps.
- [ ] Run `scripts/test-unit.sh -only-testing:XtremeMappingTests/JSONImportServiceTests` to confirm failure.
- [ ] Implement structural error translation, aggregate semantic checks, and writer preflight. Keep `canOpen` independent from `canWriteTSI` for compatible inspection-only cases. Syntax/schema/known-invalid semantic errors block acceptance. Untouched source-unknown commands can pass through only when the writer agrees. No partial acceptance or silent row deletion.
- [ ] Confirm review does not access a live document or mutate source bytes. Retain deterministic warning codes for future assistant/profile integration. Run the focused suite and commit the diagnostic/import layer.

## Task 4: Import review and JSON export

**Consumes:** `JSONImportService.review(_:)`, `JSONImportCandidate`, `MappingDiagnostic`, `SXMJSONCodec.encode(_:)`.

- [ ] Add `JSONImportExportTests.swift` for export leaving document dirty state unchanged; cancelled/invalid review creating no document; accepted review creating a new untitled document with the exact candidate; existing TSI content and file URL remaining unchanged. Inject file-panel/review decisions so these tests need no dialogs.
- [ ] Run the focused suite to confirm failure.
- [ ] Implement File → Import JSON and Export JSON actions. Decode large files off the main thread with cancellation and ignore cancelled results. Limit file reads before allocating oversized input. Resolve the active document at action time. Use a save panel for `.sxm.json`, protect the source destination, and publish atomically with existing safeguards.
- [ ] Implement review counts, per-issue path/row display, errors versus warnings, preservation status, and Import/Cancel. Disable Import for blocking errors. Import accepted candidates through the app's document-opening path as a new untitled TSI document. Ordinary Save must continue to use TSI.
- [ ] Run focused tests and manually verify keyboard/menu access, long diagnostic text, a large mapping, cancellation, two open documents, and source-free JSON. Commit integration after passing checks.

## Task 5: Release verification and external editing guide

- [ ] Add `XtremeMapping/docs/SXM-JSON-Editing-Guide.md` and a generated small valid example. Explain IDs, authoritative command references, schema usage, preservation section, readable fields, profile metadata, and the Import → Review → Save TSI workflow. Include one valid command edit and one rejected mismatch with actual catalogue values verified during implementation.
- [ ] Demonstrate opening a real fixture, JSON export, external comment and command edits, import review, TSI save, and reparse verifying intended changes. Separately demonstrate malformed JSON and an unknown command.
- [ ] Run `scripts/test-unit.sh` once all changes are integrated; investigate regressions. Record targeted and full-suite results. Do not claim Traktor/hardware validation from parser tests alone; record a manual Traktor import separately if available.
- [ ] Review the diff against the spec: every mapped field classified, preservation retained, diagnostics actionable, no clipboard regression, no API requirement, no unintended changes to source files. Commit remaining documentation and report any manual validation still outstanding.

## Completion boundary

Phase 1 is complete when the acceptance demonstration and tests above pass. It does not include a profile catalogue, assistant UI, documentation generation, or AI repair; those have separately testable milestones in the roadmap.
