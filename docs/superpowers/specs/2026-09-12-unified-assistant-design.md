# Unified Assistant — approved design

User approved one Assistant window combining explanation, typed conversation, spoken input with text replies, and physical MIDI learning. Sonnet is the default for all interpretation. Questions require no hardware. A later visual controller editor is explicitly out of scope, as are Euphonia and AI repair.

## Acceptance contract

- Replace the primary Voice and Explain entry points with Assistant. A resizable document-bound floating window keeps the table accessible. Its title identifies its source document. Closing cancels work, releases microphone/MIDI leases and clears credentials; reopening may begin a fresh conversation. No chat history is written to the TSI.
- One chronological conversation supports typed and spoken requests and follow-up refinements. Voice is off initially; transcripts populate the composer, are editable, and Send submits them. Replies are text only. Turning voice off must cancel pending starts and prevent late transcripts.
- Learn a control independently captures a supported Note/CC, with an explicit destination device. The captured address is frozen for a submitted request and shown in the review. No MIDI capture is required for questions or edits to existing rows. No silent guessed address or destination.
- Local lookup and complete reference guide exports remain available without an API key or AI opt-in. Existing provenance, uncertainty, reference navigation and Markdown/text/PDF exports remain intact.
- Explicit AI opt-in explains that question, bounded conversation, relevant mapping facts, command catalogue subset and captured MIDI are sent to Anthropic. Reuse stored key lazily. Sonnet default; no autonomous network call on opening or transcription. Retain existing bounded transport and sanitized errors.
- Model output is data: explanation with validated row citations, clarification, or typed proposed operations. No model tools execute filesystem/network/mapping actions. Supported initial operations: add, update, delete, duplicate and reorder rows within a device. Updates cover command, direction, target, controller/interaction, MIDI, comments, modifiers and meaningful scalar settings through a whitelist. Unsupported edits produce a clear limitation, never silent partial application.
- Review is computed locally from exact before/after rows, not model prose. It lists affected device, row, every changed field, additions/deletions and validation warnings. Apply is explicit, respects document lock, checks revision and underlying source snapshot, validates all operations before publishing, and commits exactly one Undo transaction. Invalid/stale/cancelled/no-op proposals make no document or Undo change. Refinements replace the pending proposal; old cards cannot apply.
- Preserve all unchanged row IDs, native opaque data and profile metadata. Deletion cleans dangling row annotations. Duplication must not invent provenance. Explicit MIDI edits must reveal loss of opaque MIDI details. Reuse source-aware JSON validation and safe TSI serialization checks; pre-existing unusual data may remain unchanged.
- Changes to source document invalidate active responses and pending proposals. Prior conversation is marked historical and excluded from current requests until a fresh context is established. Row links resolve only against current valid IDs.

## Implementation boundaries

Pure operation/preview engine; bounded conversation transport; MainActor conversation coordinator; separately cancellable voice/MIDI input adapter; native SwiftUI Assistant view hosted in a document-owned NSWindow controller. Reuse existing facts, guide renderers, key snapshot store, speech provider and MIDI lease ownership. Keep the old voice coordinator available for legacy tests but upgrade its default model too.

## Verification and recovery

Baseline/full XCTest plus Swift Testing. Meaningful regressions for preservation, atomic rejection, Undo/Redo, stale metadata/revision, command/direction validation, unknown fields, proposal replacement and cancellation, transcript/lease lifecycle, transport privacy/bounds and follow-up context. Native walkthrough covers no-key local lookup, guide access, document-bound window and disabled unsafe actions. Live API and hardware checks are optional and must be reported accurately. Local isolated branch, independent review, local integration only; recovery is revert of feature commit(s), no migration.

## Integration rulings

A blank new document has an explicit Create MIDI device setup button, protected by the existing truly-empty-file check and its own Undo step. It does not change a document on opening. The reference guide inside Assistant hides its old Questions tab to keep one conversation surface. Individual current replies retain Markdown/text/PDF exports.

Review hardening: questions have both 4000-character and 16 KiB UTF-8 limits; explanation-only referential followups retain their prior cited rows. This prevents unusual combining-mark inputs bypassing bounds and keeps “Why?” grounded.
