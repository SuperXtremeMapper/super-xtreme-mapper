# Mapping explanation verification — 12 September 2026

Milestone 3 adds a read-only explanation sheet, local source-row lookup, an opt-in question service, and complete Markdown, plain-text and PDF documentation. K1/K2/K3 remain the controller scope; Euphonia, conversational editing and repair are deferred.

## Automated evidence

Baseline at `27fb050`: 822 tests passed (760 XCTest and 62 Swift Testing), recorded in `/tmp/sxm-assistant-baseline.log`.

Final suite: **861 tests passed** (799 XCTest and 62 Swift Testing), zero failures, `/tmp/sxm-assistant-final-full.log`, exit status 0. The 10,000-row lookup regression completed in 0.150 seconds on this machine. The macOS test command targets all `XtremeMappingTests` with parallel testing disabled. Ad-hoc signing and sandbox/hardened-runtime overrides apply only to this local test invocation; project security settings are unchanged.

Coverage includes full snapshot/guide rows and devices; exact profile pins, manual sources, configured layers and overrides; device-scoped modifier dependencies; a 10,000-row query; 96 KiB context limits including escaped metadata; opaque native data and unknown enum fallback warnings; Markdown escaping and multi-page PDF text extraction; request/response bounds and citation validation; cancellation and late-result rejection; revision changes, metadata and Undo; and lazy credential access. The existing complex TSI and JSON preservation regression suite remains included.

Review found and corrected quadratic dependency expansion, unbounded top-level context notices, missing native-source uncertainty, and eager Keychain access. The final scoped review reported no remaining actionable issues.

## Native demonstration

Imported a synthetic two-device, four-row JSON mapping through the existing review interface. The K2 uses channel 15 and all-controls layers, including two filter mappings and a modifier writer; the K3 uses channel 7 and a custom-map override.

- Explain opened directly into the complete local guide without a credential lookup or network request.
- “Explain modifier 1” found the reader and writer (2 of 4 rows), with omitted-context reporting.
- A source reference selected the intended row in the mapping table; Show All Mappings restored the full view.
- Native save panels exported `native-guide.md`, `native-guide.txt` and `native-guide.pdf` under `/tmp/sxm-assistant-demonstration/`.
- All three exported formats contained all four row UUIDs and both exact profile pins. The PDF text was selectable/extractable, and its first page was visually checked for wrapping, hierarchy and margins.
- The separate 21-page stress PDF was checked on its first, middle and last pages, including Japanese, accented text, emoji and a long unbroken token. Automated extraction verifies complete row coverage.

The native walkthrough used the same interface and export implementation as the final tree, before the final snapshot uncertainty and query-bound fixes; those final fixes are covered by the final full suite.

## Explicit limits

No live model request, comparative model-quality benchmark, physical hardware validation or live MIDI capture was performed. Transport tests use controlled responses. Manufacturer documentation remains the controller evidence basis. Citation validation checks reference membership; users must still compare AI interpretations with the source rows. Native verification did not enable AI or access stored credentials.
