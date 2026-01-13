# Codex Improvement Suggestions (Ranked by Priority and Impact)

This list expands on the review points and orders them by priority and impact for project success, correctness, and user experience.

1) File-format pipeline fidelity (XML -> Base64 -> gzip -> frames)
- Why it matters: A single incorrect step breaks every file; this is the core of the app.
- Risks in current plan: Frame parsing is specified, but the gzip and binary container details are not fully described or tested end-to-end.
- Suggestions:
  - Document the exact pipeline with references and expected byte-level outcomes.
  - Add unit tests for: base64 decode, gzip decompress, frame parsing, and a full round-trip.
  - Ensure bounds checks for frame sizes and offsets to prevent crashes on malformed data.
  - Decide whether nested frames are allowed and how they are parsed.

2) Round-trip fidelity tests (golden fixtures)
- Why it matters: Users expect "open -> save" to preserve all data unless intentionally changed.
- Risks in current plan: No golden file tests; potential for silent data loss.
- Suggestions:
  - Add fixtures for small, medium, and large TSI files.
  - Verify that unedited save output is byte-identical or document intentional differences.
  - Include tests for unknown/extra frames to ensure they are preserved.

3) Parser strategy and platform imports (XMLDocument vs XMLCoder vs XMLParser)
- Why it matters: Wrong parser choice can cause subtle bugs and platform issues.
- Risks in current plan: Uses XMLDocument without calling out FoundationXML import; also mentions XMLCoder as optional without decision criteria.
- Suggestions:
  - Choose a parser early and document why (performance, streaming, dependencies).
  - If using XMLDocument, call out FoundationXML and macOS-only assumption.
  - If using XMLCoder/XMLParser, outline the schema mapping strategy.

4) Model integrity for "mapped to" (note vs CC vs none)
- Why it matters: Current model allows invalid combinations (note and CC at once), leading to incorrect save output.
- Risks in current plan: Mixed optional fields can drift into invalid states.
- Suggestions:
  - Replace `midiNote` + `midiCC` with a single enum like `MappedTo`.
  - Add validation logic and tests for conversion to/from binary.

5) Device ownership and ordering for mappings
- Why it matters: Flattening `allMappings` hides device boundaries and can corrupt order on save.
- Risks in current plan: Editing a mapping might lose its device context.
- Suggestions:
  - Store a device ID reference on MappingEntry or keep table rows as (device, entry).
  - Preserve original device ordering and mapping order.
  - Add tests for device-scoped edits.

6) Stable identity strategy across reloads
- Why it matters: Selection, undo/redo, and drag/drop depend on stable IDs.
- Risks in current plan: Uses UUIDs without noting persistence; may cause selection reset on reload.
- Suggestions:
  - Use deterministic IDs derived from file position or a stable hash.
  - Maintain a mapping layer that survives read/write cycles.

7) Error handling UX for invalid or partial files
- Why it matters: TSI files in the wild may be corrupted or partially invalid.
- Risks in current plan: Errors are thrown but not surfaced to user with actionable messaging.
- Suggestions:
  - Provide user-facing errors with guidance (e.g., "Invalid Base64 in Entry...").
  - Consider partial load with warnings when possible.
  - Log or export error details for debugging.

8) Filtering accuracy with command categorization
- Why it matters: Poor categorization reduces usability; users will not trust filters.
- Risks in current plan: Heuristic keyword matching will misclassify many commands.
- Suggestions:
  - Build a mapping table for known command names and categories.
  - Keep heuristic fallback only for unknown commands.
  - Add tests for a representative command list.

9) Multi-window drag/drop and reorder behavior
- Why it matters: Drag/drop in DocumentGroup apps can be tricky and inconsistent.
- Risks in current plan: Assumes automatic support; doesn’t define how ordering updates in data model.
- Suggestions:
  - Define a drop strategy (insert index, reorder within device, cross-device handling).
  - Test drag/drop across windows early with Transferable payloads.

10) Undo/redo integration
- Why it matters: Users expect standard macOS editing behavior.
- Risks in current plan: No `UndoManager` wiring or change registration.
- Suggestions:
  - Wrap edits with undo registrations.
  - Ensure bulk operations are undoable as single grouped actions.

11) DocumentGroup "New" workflow and templates
- Why it matters: "File -> New" in DocumentGroup apps uses `NSDocumentController`.
- Risks in current plan: Template creation is not connected to actual document creation flow.
- Suggestions:
  - Define how templates instantiate and open new documents.
  - Ensure templates are saved to correct file format on first save.

12) Performance strategy for large mappings
- Why it matters: Large mapping files will be common for power users.
- Risks in current plan: No mention of selection performance, filtering overhead, or view updates.
- Suggestions:
  - Profile with a large fixture file.
  - Avoid repeated full-array filtering on every keystroke if needed.
  - Consider diffing or virtualization for large tables.
