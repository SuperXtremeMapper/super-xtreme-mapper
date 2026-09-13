# Mapping interchange, controller knowledge, and assistant design

Status: captures the direction agreed in conversation; detailed defaults below are proposed implementation decisions. No application code has been changed.

## Product outcome

Users can export a TSI to editable SXM JSON, edit it externally, review import diagnostics, and produce a TSI without silent loss. A controller knowledge library connects physical controls to MIDI messages. An assistant explains the current mapping, creates documentation, and subsequently proposes validated edits and import repairs.

## Shared foundation

MappingFile remains the runtime mapping model. A separate public interchange format prevents internal Codable migrations and clipboard behavior from becoming an external API. All import and assistant mutation paths use shared deterministic validation and the existing TSI writer's preservation decisions. Controller profiles supply hardware facts, not Traktor assignments. The assistant supplies interpretations and proposed operations, not authoritative validation results.

## JSON release

- Use `.sxm.json`, with a format discriminator and integer schema version independent of the TSI version.
- Include ordered devices and mappings, stable UUIDs, readable enum tokens, command IDs with display names, MIDI assignment, conditions, values, comments, and device metadata. Inventory every MappingEntry field before freezing the schema; explicitly classify each as editable, derived, or preserved.
- Numeric command IDs are authoritative; a conflicting supplied name is an actionable diagnostic rather than an ignored edit. Accept omitted derived names and regenerate them on export.
- Use deterministic formatting and sorted object keys; preserve array order. Supply a JSON Schema, realistic example, and external-editing guide with the release.
- Include optional profile references, version pins, physical control references, and local overrides. Unknown profile references must not prevent an otherwise valid generic MIDI import. Reserve these through a defined metadata object, not arbitrary extra mapping fields.
- Preserve original XML and source identity information in a separate preservation section. Reparse original bytes with existing parser limits, reconstruct the baseline, and validate correspondence between source records and public IDs. Never trust a serialized claim that source data is safe. A checksum detects accidental changes, not authenticity.
- Preserve current unsaved edits in the editable projection, even when the retained source predates those edits. Never replace the source baseline with that edited projection.
- Exact no-op TSI round trips are required for source-backed documents the existing parser accepts. Edited round trips retain existing source-patching, conversion, and refusal behavior. Unsupported edits must not trigger silent regeneration.
- A JSON document without source data is valid for supported mappings; it receives normal canonical-writer checks and no claim of opaque-data preservation.
- Import JSON opens a reviewed new untitled TSI document. It does not merge into or replace the current document in this release. Save continues to produce TSI; Export JSON is a separate action that does not clear dirty state.

## Diagnostics and review

Represent each diagnostic with a stable code, severity, JSON path, device/mapping IDs when available, explanation, and optional deterministic suggestion. Separate syntax errors, schema failures, semantic failures, compatibility uncertainty, and preservation outcomes. Collect independent field errors when the structure permits it.

Block invalid structure, duplicate IDs, invalid value ranges, contradictory command references, and known-invalid direction combinations. Unknown commands inherited unchanged from a verified source baseline can remain preservable; unknown new or edited commands cannot be advertised as validated or silently removed. Distinguish opening for inspection from ability to generate a TSI. Warnings such as overlapping mappings are advisory because layering can be intentional.

Recognize misspelled fields rather than silently accepting them. Reject duplicate JSON keys, unsupported schema versions, excessive nesting, and oversized input before uncontrolled decoding. Initial limits: 128 MiB encoded JSON, depth 64, 256 devices, 100,000 mappings total, 1 MiB per editable text field; embedded TSI remains subject to TSIParseLimits. Test these against existing fixture sizes and document any justified limit adjustment before release.

Review shows device/mapping totals, errors and warnings with navigation, preservation status, and whether TSI output is available. For source-backed imports, show added/removed/changed mapping counts against the baseline. Cancel leaves all open documents untouched. No automatic AI repair in the JSON release.

## Controller library

Use versioned profiles distinct from starter mapping templates. Profiles contain exact manufacturer/model/revision, documented operating modes, port hints, control identifiers/names/aliases, message encoding and ranges, layers, feedback capabilities, hardware behavior limitations, source URLs/pages, and per-fact verification status. Distinguish mixer strips, MIDI channels, and Traktor decks.

Build an official-source acquisition and candidate-extraction workflow, followed by schema checks and source review. Mark manufacturer-documented and hardware-tested evidence separately. Keep unsupported or proprietary messages explicit. Do not infer factory defaults apply to programmable controllers. MIDI Learn confirms addresses and stores local overrides. Never silently upgrade pinned profiles in existing documents.

First profile: AlphaTheta Euphonia. Official evidence:
- https://downloads.support.alphatheta.com/software_info/dj-mixers/euphonia/euphonia_MIDI_Message_List_E10.pdf
- https://support.alphatheta.com/en-us/articles/29298607838361

Use the message list for physical control addresses; the support page states that the device does not receive MIDI. Hardware audio behavior requires manual evidence and/or testing. Choose subsequent profiles from hardware available for testing rather than assuming ownership. Broad crawling is not a prerequisite for the first release.

## Explanation and documentation

Add a document-scoped assistant with a mapping snapshot, command catalogue access, relevant profile facts, and row-level references. Build local structured facts and lookup first; retrieve relevant rows and source excerpts for questions instead of sending entire manuals on every turn. For whole-document guides, cover all devices and explicitly identify any unsupported portions.

Reuse API key storage and transport patterns; separate conversational service/model settings from Voice Learn. Verify supported model identifiers and evaluate Haiku/Sonnet candidates at implementation time. Keep voice settings unchanged unless evaluation justifies a separate change. No API key is needed for JSON, local diagnostics, profiles, or deterministic reference tables.

Read-only tools resolve controls, inspect rows, search commands, and report modifier dependencies. Answers link to current rows and distinguish facts, inference, and missing information. Document revision changes invalidate stale context. Imported comments and manuals are data, never instructions. Handle cancellation, missing credentials, rate limits, and bounded requests. Explain what mapping context is sent when users enable the assistant.

Create Markdown/text documentation first; add PDF rendering from the same reviewed content as a separate acceptance item. Include mapping identity/revision, devices, control assignments, layers, feedback, and limitations. Evaluate factual coverage and references, not exact model wording.

## Reviewed edits and repair

Assistant output consists of typed edit operations against stable IDs and a document revision. Resolve ambiguity before proposing mutations. Validate all operations, show exact before/after changes, reject stale plans, and apply atomically through the undoable document path. One accepted request equals one Undo action. Never accept arbitrary assistant-generated code or bypass the TSI writer.

Reuse this proposal mechanism for JSON repair. Keep the original import bytes, show suggested changes, re-run deterministic validation, and require an explicit apply action. A model's confidence is not a validity check.

## Delivery boundaries

1. JSON interchange and local review, including schema/docs and preservation regressions.
2. Profile format, Euphonia pilot, lookup and MIDI Learn confirmation.
3. Read-only assistant and Markdown/text/PDF documentation.
4. Reviewed conversational edits.
5. AI-assisted repair and controlled profile expansion.

Each phase has its own implementation plan and acceptance demonstration. The initial detailed plan covers phase 1 only; later phases are intentionally separate subsystems rather than speculative implementation code.
