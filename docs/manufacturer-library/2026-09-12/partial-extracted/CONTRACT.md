# Stage 1 extraction contract

These are reviewable manufacturer evidence datasets, not runnable SXM profiles. Preserve every protocol page in page-addressed text alongside normalized bindings. No hardware validation is claimed. Existing K profiles remain unchanged. Work on main; do not modify Assistant or other application code.

One JSON per model, named with a lowercase hyphenated slug. Required fields:
- schema_version: 1
- manufacturer, model (exact catalogue strings)
- status: "documented-extraction" (not a completeness or compatibility claim)
- hardware_tested: false
- sources: array of {id, local_file, url, sha256}. local_file relative to dated catalogue directory; use original source hash.
- scope: plain-language supported modes and extraction coverage
- bindings: array of {id, control, direction, message_type, channel, number, encoding, values, mode, evidence, app_support, notes}
  - direction device-to-host or host-to-device
  - message_type note, cc, pitch-bend, poly-aftertouch, channel-aftertouch, sysex, realtime, or compound
  - channel human 1..16 integer or null if configurable/unknown; explain in notes. Never infer a default from another model.
  - number 0..127 integer or null for non-numbered message types
  - encoding descriptive explicit string; do not force unsupported semantics into K-series enums
  - values object with documented bounds/bytes/semantics (empty allowed if undocumented)
  - mode explicit source context, not guessed
  - evidence nonempty array {source_id, locator}; locator page/section/table precise
  - app_support: "existing-profile", "requires-adapter", or "unsupported". All newly extracted bindings default requires-adapter; no runtime integration in this stage.
  - notes array of strings
  - source_group and source_figure optional strings preserving chart section and physical diagram references; retain when needed to distinguish identically named controls
- issues: array {id, severity: "conflict"|"unsupported"|"scope", description, evidence: [{source_id,locator}], excluded_bindings: array of descriptions}. Ambiguous addresses excluded from bindings; raw evidence retained.
- raw_evidence: array {source_id, file, extraction_method}; file relative to extracted directory. Preserve complete protocol page text (not entire owner manuals unless sole protocol source). Text uses page markers, original PDFs remain authoritative.

Extract as much of each numeric chart as supported, not a handful of representative bindings. Expand regular grids only where the source explicitly defines the formula. Keep modes, channels, input/output distinct. If a complex table cannot be reliably normalized, retain the complete page text and record precise remaining work in issues; never call it full coverage. Row labels from merged PDF cells must be recovered from context; never guess across sections. Include source contradictions rather than smoothing them over. Reports must distinguish normalized bindings from raw protocol evidence.

# Stage 2 overrides (take precedence above)

Exact21 catalogue models with source_grade partial. Status `partial-extraction`; add coverage_state `partial` when numeric bindings established, or `documentation-only` when none. bindings may be empty ONLY for documentation-only, with explicit nonempty scope/issues describing missing address evidence. Never add invented/sample bindings just to populate UI. Sources always exact catalogue hash/path/URL. raw_evidence.file relative to partial-extracted root; owner manual full page-marked text acceptable when no protocol. Add `setup_notes`: array of readable source-grounded instructions (MIDI mode entry, templates needed etc) and `missing_information`: array of specific gaps. Source provenance for setup_notes via issues with relevant evidence locator. No new research needed if local archives suffice; numeric facts must be manufacturer documents, not software actions. User prioritizes DJ controllers but approved all21 includingmixers/accessories. Do not modify existing26 resources or originalarchives. No appcode edits.
