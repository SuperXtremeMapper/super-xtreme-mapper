# Claude handoff: refine the Assistant UI/UX

Prepared 12 September 2026 against local commit `37cb575` in `/Users/noahraford/Projects/XtremeMapping`.

## Your assignment

Refine the native macOS Assistant window so it feels intuitive and belongs to the rest of Super Xtreme Mapper (SXM), a Traktor TSI mapping editor. Improve hierarchy, wording, spacing, feedback, discoverability and review presentation while preserving the working mapping, validation and Undo infrastructure.

The user’s explicit decision is: **one message box, one Send button**. Questions and editing requests use that same conversation. The user found labels such as “Find locally,” “Search mapping” and “Ask assistant” confusing. “Find locally” was removed from the Assistant in the latest commit. Do not restore competing submission modes or require users to understand retrieval versus AI.

This is a UI/UX pass. Do not expand the roadmap into additional controllers, a visual controller editor, new AI capabilities or a replacement mapping engine. Inspect the current app beside the main editor before designing. The inventories below describe current behavior; suggested refinements are separately identified.

## Product context and terminology

A TSI is a Traktor configuration file containing mapping devices and mapping rows. A row connects a MIDI message with a Traktor command, a target such as Deck A, and settings or modifier conditions. One physical control can correspond to multiple rows.

- **Mapping device:** A device entry inside the open TSI. It is not necessarily a connected piece of hardware.
- **Physical controller:** Hardware such as a Xone K1, K2 or K3.
- **MIDI address:** Message kind, channel and number. Capturing an address identifies the signal; it does not by itself establish the desired Traktor function.
- **Command:** A supported Traktor action from the application’s command catalogue, such as a volume or filter function. This is distinct from a chat message.
- **Assignment:** The Traktor target. Physical fader position, MIDI channel and Traktor deck are distinct concepts.
- **Modifier condition:** A condition determining when a mapping row operates. Explain these in ordinary language where possible.
- **Proposal:** Locally validated changes awaiting explicit Apply. A reply is not evidence that the mapping has already changed.

The Assistant must work without a physical controller. A user can open an existing TSI and ask what it does, discuss it, or request edits. K1/K2/K3 profiles enrich the available facts using official documentation. Unknown or preserved native data must remain honestly identified as uncertain.

## Intended workflows

### 1. Understand an existing mapping

1. Open a TSI and choose Assistant.
2. If necessary, enable AI for this session and configure the stored Anthropic API key.
3. Type “Which controls change the volume?” and choose Send.
4. Read the answer, inspect source-row links, and ask a follow-up in the same message box.
5. Optionally export the reply or open the complete reference guide.

No MIDI capture or microphone is needed. Relevant mapping facts are retrieved automatically when sending. AI context is bounded; do not imply every row in a large TSI was inspected. The local reference guide covers the complete mapping.

### 2. Edit existing mappings

1. Optionally select rows in the main editor and enable “Use N selected mappings.”
2. Type a request such as “Change the selected mappings to Deck B.”
3. Send and inspect the proposed changes, affected rows, before/after values and warnings.
4. Refine the pending proposal with another message, discard it, or explicitly Apply changes.
5. Inspect the result in the editor. Undo reverses the entire accepted proposal in one step.
6. Save the document through the normal editor workflow when desired. Apply does not itself save a TSI to disk.

Selection supplies context; it is not a substitute for an exact review of the rows the proposal will affect.

### 3. Map a physical control

1. Expand MIDI control and choose the destination mapping device.
2. Choose Learn a control, then move a fader/knob or press a button.
3. The first supported CC or Note On freezes the captured MIDI address and stops capture.
4. Type or dictate a request such as “Make this Deck A volume.”
5. Review the message, choose Send, then review and Apply the proposed mapping changes.

Voice and MIDI capture are independent. MIDI capture supplies an address; the message supplies the intended behavior. Neither input automatically sends or applies anything. Missing or ambiguous details should prompt clarification rather than invented control identity.

### 4. Speak instead of typing

1. Turn Voice on.
2. Speak and wait for text to appear in the same message box.
3. Correct the transcript if needed, then choose Send.
4. Read the text reply. There is no spoken output.

Voice uses Apple Speech, which may send audio to Apple. It does not stream speech directly into the mapping editor or automatically execute spoken commands.

### 5. Use documentation without AI

1. Choose Guide & export.
2. Read the complete locally generated reference guide.
3. Choose Export guide and select Markdown, plain text or PDF.
4. Choose Done to return to the conversation.

No API key, AI consent, hardware or model request is needed for this workflow.

## Every control in the current Assistant

### Entry points and window

| Control | Current function and important behavior |
|---|---|
| Main toolbar **ASSISTANT** | Opens the document’s Assistant. If already open, brings that window forward. |
| Editor **Assistant…** button | Opens the same Assistant, not another mode. |
| Document name in header/title | Identifies the TSI this conversation belongs to. An open session must not silently switch documents. |
| Native close button | Ends the session, cancels active requests, stops speech/MIDI, and clears in-memory credentials. Reopening starts a fresh conversation. Chat history is not stored in the TSI. This does not delete the saved Keychain key. |
| Native minimize/resize/zoom controls | Standard window management. Current window floats above the editor. Default content size is 850 × 740; minimum is 720 × 560. |
| Lock indicator | Appears when the editor is locked. It is informational; unlock in the editor. Reading and asking remain possible, but Apply and MIDI creation/capture controls are restricted. |

### Header and AI connection

| Control | Current function and important behavior |
|---|---|
| **Guide & export** | Opens the read-only Reference Guide sheet. Disabled until a current mapping snapshot is available. |
| **AI setup** / current model name | Toggles the AI connection panel. Label becomes the selected model name when session consent and a key are available. |
| **Done** in AI connection | Collapses connection settings; does not disable AI or end the conversation. |
| **Enable AI for this session** checkbox | Gives session permission for model requests and starts asynchronous retrieval of the stored key. Turning it off cancels work/proposals and clears the in-memory key. It does not erase the Keychain key. |
| **Model** picker | Selects the model. Current code lists Claude Sonnet 5 (default) and Claude Haiku 4.5. These are configured identifiers, not a claim of successful live availability. Selection persists and is shared with the explanation feature. Changing it cancels pending work/proposals. |
| **API key…** | Opens shared Anthropic key settings. Disabled while Assistant credentials are loading. See the separate inventory below. |
| **Set up AI to chat** | Composer link shown without session consent or a loaded key. Expands the same AI panel; it is not another chat action. |

The connection panel explains that Send shares the request, recent conversation, relevant mappings and captured MIDI with Anthropic; API charges may apply. Original TSI preservation data and full manuals are excluded. Opening Assistant alone does not read credentials or send mapping data.

Keychain waiting must remain asynchronous and cancellable. Explain what the user needs to do without freezing the window or claiming the connection is verified merely because a key is stored.

### Empty conversation and composer

| Control | Current function and important behavior |
|---|---|
| **Explain modifier 1** example | Fills the message box, turns selection context off, and focuses text entry. Does not send. |
| **Which controls change the volume?** example | Same behavior with that question. Does not send. |
| **Change the selected mappings to Deck B** example | Fills the message box and enables selection context. Disabled with no selected rows. Does not send. |
| **Use N selected mappings** checkbox | Appears when rows are selected in the editor. Includes those row IDs as request context when enabled. The selection is live, not a permanently captured group. |
| **Message to Assistant** field | One multiline field for questions, follow-ups, edit requests and dictated text. Placeholder: “Ask a question or describe a change…” It currently grows from two to five lines. |
| **Voice** switch | Starts/stops Apple Speech input. Labels change to “Starting…” or “Listening.” Recognized phrases append to the existing draft and focus the composer. Turning off stops listening. |
| **N/4000** counter | Character count. Requests are also limited to 16 KiB of UTF-8 text. Over-limit drafts show an error and cannot send. |
| **Send** | Submits the draft, recent eligible conversation, automatically retrieved mapping context, optional selected rows and optional captured MIDI. Clears the draft after dispatch. Never applies edits. Shortcut: Command–Return. |

Send is disabled for an empty/whitespace draft, an over-limit draft, missing AI consent/key, Keychain loading, an active request, or a mapping snapshot still being prepared/outdated. The reason should be understandable to the user.

### Optional MIDI controls

| Control | Current function and important behavior |
|---|---|
| **MIDI control** disclosure | Opens optional capture setup. Summary shows “Optional,” “Listening…,” or the captured address and destination name. Closing it stops active capture; a completed capture remains until cleared/replaced. |
| **Destination** picker | Chooses a device entry inside this TSI, not an OS MIDI input port or a Traktor deck. One existing device is automatically selected on opening. Changing destination clears the captured MIDI. |
| **Create MIDI device** | Shown when there are no devices. Adds an empty “Generic MIDI” device and selects it. Allowed only for a truly empty, unlocked document. This is a direct, undoable setup action—the exception to AI proposal review, because no AI is involved. |
| **Learn a control** | Arms the MIDI listener. Disabled without a destination, while a request is running, or while locked. Re-arming clears the previous capture. |
| **Cancel MIDI capture** | Replaces Learn while listening. Stops capture without making a mapping. |
| **Clear** beside captured MIDI | Stops capture and removes the captured address. Does not delete a mapping or clear the chat draft. |
| **Move a control…** | Listening instruction; not a button. |

AI setup and MIDI setup currently expand one at a time to reduce crowding. Expanding AI setup collapses MIDI and therefore stops active capture. Do not let hidden listeners continue unexpectedly.

### Conversation, sources and export

| Control or label | Current function and important behavior |
|---|---|
| **YOU / ASSISTANT / SESSION** | Distinguishes user messages, model responses and local status messages. |
| **Facts / Interpretations / Limitations** | Separates supported statements, interpretation and uncertainty. Presentation can improve, but preserve that distinction. |
| **Show N source rows** | Selects referenced rows and reveals them in the main editor. Clears conflicting category/input-output/text filters and applies the referenced-row filter. Does not modify mappings. Disabled for historical answers. |
| **Source rows · N of total** | Shows automatically retrieved context and its limits. This remains after removal of Find locally. It is not a second search mode. |
| Individual source-row links | Reveal that row in the editor. Labels currently include device name, row position, command and MIDI address. |
| **Export reply** menu | Saves one current structured reply as **Markdown…**, **Plain text…** or **PDF…** through a native save dialog. It is separate from exporting the complete guide. |
| **Earlier version** | Marks messages referring to a previous document revision. Historical source links and reply export are disabled. Old prose remains visible. |
| **Cancel** next to “Working on your request…” | Cancels the active request. Does not undo an already applied edit. The user message remains visible; the cleared draft is not automatically restored. |

Source-row navigation changes editor selection/filter state, not mapping data. Its interaction with the “Use N selected mappings” checkbox is worth making understandable.

### Proposed-change review

| Control or label | Current function and important behavior |
|---|---|
| **Review proposed changes** | Review generated from the actual locally prepared change set, not merely the model’s description. |
| **N affected rows · not applied** | Communicates scope and that the document has not yet changed. |
| Device heading and change summaries | Show which device/rows are affected and the actual changes, including additions, deletions and order where relevant. |
| **Row details** disclosure | Currently reveals the internal row UUID. Keep technical identifiers secondary to useful human-readable identity. |
| Warning text | Validation warnings that must remain visible before Apply. |
| **Apply changes** | Applies the entire current, valid proposal atomically, with one Undo step. Disabled while locked, working or empty; the underlying service also rejects stale proposals. Clears captured MIDI after successful application. |
| **Discard proposal** | Removes the pending proposal without altering the mapping. Leaves conversation text. |
| **One Undo step** | Informational label, not a button. Use normal Edit → Undo / Command–Z to reverse the accepted proposal. |

A new message can refine a pending proposal. The previous operations are included as context, but the current review is cleared while awaiting the replacement. Document edits, consent/model changes and cancellation can invalidate a proposal. The interface must not imply a discarded or stale review is still applicable.

## Guide and API-key sheets

The Assistant opens `MappingExplanationSheet` with `guideOnly: true`. Its legacy Questions tab, Find locally and Ask AI controls exist in source but are **not part of this Assistant path**. Do not accidentally expose them in the redesign.

| Guide control | Function |
|---|---|
| **Export guide… → Markdown… / Plain text… / PDF…** | Exports the complete deterministic guide. Native save dialog chooses a new destination; export guards protect existing/source files. |
| **Done** / Escape | Closes the read-only sheet and returns to Assistant. |
| Preparing/error/export status | Reports guide generation, failures and completed export. Device/mapping counts describe the guide’s scope. |

| API-key control | Function |
|---|---|
| Secure API-key field | Accepts an Anthropic key without displaying it in plain text. Format feedback is not a live authentication test. |
| **SAVE** | Saves a format-valid key to macOS Keychain. |
| **CLEAR** | Opens confirmation to remove the stored key. Confirmation’s Clear deletes it; Cancel keeps it. This is unrelated to clearing captured MIDI. |
| **console.anthropic.com** | Opens Anthropic’s console to obtain/manage a key. |
| **SPONSOR / BUY US A COFFEE** | Open the existing GitHub Sponsors / Ko-fi support pages. These are shared app-support links, not Assistant actions. |
| **CHECK FOR UPDATES** | Existing shared settings action that checks app releases; unrelated to AI readiness. Treat as existing adjacent UI, not an Assistant command. |
| **DONE** / Return | Closes the loaded settings sheet. |
| **Cancel** / Escape while Keychain is loading | Closes the waiting sheet without blocking the conversation. |

## Supported conversational commands

There are no slash commands or separate question/edit modes. Requests use ordinary language, and exact command choices must resolve through the supported catalogue. Examples below describe supported intent, not verified live model transcripts.

| Intent | Example | Supported scope |
|---|---|---|
| Explain | “Explain modifier 1.” | Answer from supplied mapping facts with references and uncertainty. |
| Locate/explain controls | “Which controls change the volume?” | Automatic retrieval and source-row navigation. |
| Follow up | “Why does that need modifier 1?” | Uses recent same-revision history and retained references within bounded context. |
| Update | “Change the selected mappings to Deck B.” | Patch identified rows; omitted fields retain their original values. |
| Add | “Make this captured fader control Deck A volume.” | Add a row to an identified existing mapping device, with validated command/settings. |
| Delete | “Remove these selected mappings.” | Reviewed deletion of identified rows. |
| Duplicate | “Duplicate this mapping for Deck B.” | Copy an identified row with a new identity and supported overrides. |
| Reorder | “Move these mappings before the other group in this device.” | Complete validated ordering within a device; order changes are reviewed separately from other changes to that device. |

Supported update fields: command; input/output direction; assignment; interaction mode; MIDI kind/channel/number; either modifier condition (set or explicitly clear); comment; controller type; invert; soft takeover; set value; rotary sensitivity and acceleration; encoder mode; auto-repeat; LED minimum/maximum range type and data, minimum/maximum MIDI value, invert and blend; resolution. Validity still depends on the command and local validators. Field support is not a guarantee that every combination is meaningful.

Do not promise arbitrary file manipulation, executing code, unrestricted device creation, cross-device moves, a complete rewrite of every unknown native structure, automatic repair from chat, or a diagram-based controller editor.

## Behaviors the UI pass must preserve

- One message box and one Send action. Explicit Send for typed and spoken input; explicit Apply for model-proposed edits.
- Correct document ownership, live selection, revision checks and atomic rejection of stale/invalid proposals.
- Exact before/after review, warnings, preservation of opaque TSI data and one-step Undo.
- Voice off initially; text replies only; speech and MIDI independent; cleanup on close.
- Session consent and secure key handling. No network request simply from opening the window or selecting an example.
- Guide/export access without AI. Facts, interpretations, uncertainty and context omissions remain distinguishable.
- Bounded requests: 4000 characters / 16 KiB; context up to 80 rows / 96 KiB; history 24 KiB; catalogue 48 KiB; response 1 MiB / 8192 output tokens; proposals up to 100 operations and 100 affected rows.
- Stable resizing and keyboard/accessibility behavior. The composer stays visible while conversation/review content scrolls.

## Recommended UX focus

These are refinement opportunities, not already implemented features:

1. Make the primary flow obvious: ask or describe a change → Send → read or review → Apply if desired.
2. Make disabled Send explain itself, especially consent, missing key and Keychain waiting.
3. Give answer text priority while keeping sources and uncertainty easily accessible. A long source list should not bury the answer or review.
4. Make “not applied,” affected control identity, before/after and the consequences of Apply immediately readable.
5. Clarify selected rows versus captured MIDI versus destination device without putting implementation terminology in the main flow.
6. Differentiate voice listening, MIDI listening and AI working. Each should have an obvious way to stop it.
7. Review confusing repeated labels such as Done and Clear in their local context; preserve their distinct effects.
8. Preserve compact native styling, but improve legibility and focus order. Test long names, errors, multiline drafts, long reviews and minimum window size.
9. Consider making the session’s temporary nature clearer; currently closing loses the conversation.

Use the existing stone/dark surfaces, restrained amber primary actions, system typography, spacing and controls from the editor. Do not add a separate visual identity or web-style dashboard around the conversation.

## Code map and verification

Repository root: `/Users/noahraford/Projects/XtremeMapping`.

Paths below are relative to that root:

- `XtremeMapping/XtremeMapping/Views/UnifiedAssistantView.swift`: primary UI and its wiring.
- `XtremeMapping/XtremeMapping/Theme/AppThemeV2.swift`: editor design tokens.
- `XtremeMapping/XtremeMapping/Views/AssistantButtonStyle.swift`: shared Assistant button treatment.
- `XtremeMapping/XtremeMapping/Views/AssistantWindowController.swift`: native floating window and Undo routing.
- `XtremeMapping/XtremeMapping/ContentView.swift`: launch actions and source-row selection/filter integration.
- `XtremeMapping/XtremeMapping/Views/MappingExplanationSheet.swift`: guide-only sheet plus legacy explanation UI.
- `XtremeMapping/XtremeMapping/Views/APIKeySettingsView.swift`: shared key settings.
- `XtremeMapping/XtremeMapping/Services/AssistantConversationCoordinator.swift`: conversation, proposals, cancellation and revisions.
- `XtremeMapping/XtremeMapping/Services/AssistantConversationService.swift`: bounded model request/response contract.
- `XtremeMapping/XtremeMapping/Services/AssistantInputCoordinator.swift`: independent speech and MIDI lifecycles.
- `XtremeMapping/XtremeMapping/Services/AssistantEditPlan.swift`: validated before/after preparation and atomic Apply.
- `XtremeMapping/XtremeMapping/Models/Assistant/AssistantEditOperation.swift`: supported edit operations and fields.
- `XtremeMapping/docs/Unified-Assistant.md`: user guide; contains a stale earlier sentence calling AI repair future work. Repair is now implemented in a separate import flow.
- `XtremeMapping/docs/Assistant-Polish-Repair-Verification.md`: latest full verification and honest live-test gaps.

Important regression: `AssistantWindowController` deliberately wraps the SwiftUI hosting view in a plain AppKit container. Direct hosting previously reset native window geometry after layout. Preserve this mechanism unless a replacement passes the existing geometry tests after the event loop settles.

Latest full feature verification passed 908 automated tests. The subsequent one-Send simplification passed 10 focused Assistant tests and native visual inspection. Live Sonnet answers, successful live repair generation, speech transcription and actual physical MIDI capture remain unverified; previous live evaluation stopped at Keychain authorization or unavailable input. Do not present mocked-response tests as live success. Manufacturer documentation is sufficient for K-series profile acceptance; physical hardware verification is optional.

For this pass, inspect and exercise: fresh session; no key/consent; waiting/cancellation; questions; source navigation; selection; captured MIDI; voice states; proposal review/refinement/discard/Apply/Undo; locked and changed documents; long/error states; guide and reply export; close/reopen; default and minimum size. Use injected responses where appropriate and label what was actually tested. Never print keys or send personal mappings as test data without authorization.

Finish with the refined implementation, appropriate checks, and a concise report of visible changes and remaining usability issues. Keep unrelated working files intact. Do not start Euphonia profiles, the visual controller editor or other roadmap work as part of this handoff.
