# Mapping explanation and documentation

Implements the already approved milestone 3 from the mapping interchange/assistant design. K1/K2/K3 are the available profile catalogue; Euphonia stays deferred.

## Working result

A document-scoped **Explain…** sheet offers a local reference guide and questions about the current mapping. The complete guide is deterministic and works without credentials; Markdown, plain text and paginated PDF share the same content. AI questions use the stored Anthropic key only after a visible opt-in for that sheet, and send only the question and bounded relevant mapping facts. Voice Learn settings and implementation remain unchanged.

## Architecture

Build immutable structured facts from every mapping row and device. Include command IDs/names, direction, assignment, MIDI, both conditions with target scope, controller/interaction settings, feedback, comments, configured physical-control matches, exact profile pins and evidence. Unknown/opaque portions remain in the inventory with explicit limitations. Modifier writer/reader relations are conservative and device-scoped; do not equate physical layers with Traktor modifiers or decks.

A local query service supports free-text relevance, exact selected-row lookup, command search and modifier dependencies. Relevant results carry stable row UUIDs. Context is limited to 80 rows and 96 KiB, questions to 4000 characters, model output to 4096 tokens and response bodies to 1 MiB. Truncation is explicit; never describe a partial retrieval as the whole mapping. Whole-document reference exports include every device/row, including unsupported portions, independent of retrieval limits.

Each open document has a session identity and a monotonically advancing content revision, including metadata-only edits and Undo. Snapshot references are valid only for that revision. Closing the sheet, replacing a request, changing the model/consent or changing the document cancels outstanding work; late results cannot overwrite current state. Responses have separate facts, interpretations and unknowns, with validated row IDs. References outside the supplied context are rejected. AI wording is an interpretation to review, not a deterministic guarantee of correctness. No mutation tools exist.

## UI and transport

Use the existing native AppThemeV2 sheet style. The user sees local matched rows and can return to those rows in the table. A disclosure explains exactly what is sent; AI is off until enabled. Provide the existing key settings sheet when credentials are missing. A dedicated model setting offers Sonnet 5 and Haiku 4.5, using officially documented IDs `claude-sonnet-5` and `claude-haiku-4-5-20251001` (verified 12 September 2026). Sonnet is the initial default; choice is independent of Voice Learn. Transport uses URLSession and a typed structured answer contract, cancellation, response limits and clear missing-key/rate-limit/network/refusal errors. No automatic retries or background API calls.

The system prompt treats comments and supplied facts as untrusted data. It has no file-system, browsing, code execution or editing capability. Context JSON excludes original TSI/XML and raw preservation blobs. The UI reports omitted/truncated context and distinguishes local guide content from AI interpretations. Exports never overwrite the open TSI or an existing file silently.

## Acceptance

Tests cover full device/row coverage, unknown commands/opaque MIDI, context limits and retrieval beyond the first 80 rows, device-scoped modifier links, profiles and custom-map uncertainty, protocol request/response validation, invented references, cancelled/stale replies, and unchanged mapping/Undo state. PDF tests inspect page count and extracted text; visual inspection covers multi-page and long-line wrapping. Native walkthrough covers no-key guide, question lookup, row navigation and all three exports. Live model evaluation uses synthetic data only if credentials are available; lack of live evaluation is stated explicitly and does not masquerade as quality benchmarking.

## Sources

- https://platform.claude.com/docs/en/models/overview
- https://platform.claude.com/docs/en/api/messages/create
