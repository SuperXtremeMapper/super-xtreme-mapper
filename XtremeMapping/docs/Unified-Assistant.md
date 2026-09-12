# Assistant

Open **Assistant** from the editor toolbar. Its floating window belongs to the mapping document named in its header, so you can keep the mapping table visible while asking questions and reviewing changes.

## Questions and local guides

No controller is required. Ask about the loaded TSI, modifier conditions, assignments or physical controls identified by its pinned profile. **Find locally** finds source rows without an API request. **Guide & export** opens the complete local guide with Markdown, text and PDF exports. Unknown native details remain explicitly identified.

To chat, open **AI setup**, enable AI for the session and use your stored Anthropic API key. Sonnet is the default; model selection is shared with the explanation feature. The legacy voice interpreter also defaults to Sonnet. Opening Assistant does not read credentials or send mapping data.

Questions and recent conversation, relevant mapping facts, authoritative command definitions and any captured MIDI are sent to Anthropic only when you choose **Send**. Requests can incur API charges. Original TSI preservation bytes and full manuals are excluded. Replies distinguish facts, interpretations and unknowns, with source-row links. **Export reply…** saves an individual current reply.

## Voice and physical controls

Voice starts off. Turn it on to dictate into the composer, correct the transcript if needed, then choose **Send** (Command-Return). Replies are text only. Speech recognition uses Apple Speech and may send audio to Apple. Turning voice off stops listening; closing Assistant stops both voice and MIDI capture.

To map a physical control, expand **MIDI control**, choose its destination device, click **Learn a control**, and move or press it. The first supported CC or Note On freezes the captured address. Describe its purpose, for example “Make this Deck A volume.” MIDI capture and voice are independent: you can capture MIDI and type, or speak without any controller connected. Clear or re-arm capture to select another control.

For a blank new document, **Create MIDI device** adds an empty Generic MIDI device as an undoable setup action. Imported documents use their existing devices. Device identity and MIDI address are visible before sending a creation request.

## Reviewed edits

Describe the change, inspect **Review proposed changes**, then choose **Apply changes**. Review text comes from the actual before/after mappings. It includes affected rows, changed fields, additions/deletions, order and validation warnings. You can refine a pending proposal with another message or discard it.

Supported proposals add, update, delete, duplicate or reorder rows within a device. Updates cover commands, targets, direction, MIDI, controller/interaction settings, comments, conditions and the supported scalar settings. Reordering is reviewed separately from other changes to that device. Other requests must be clarified or reported as unsupported.

Apply commits one Undo step. It is disabled while the mapping is locked. Invalid proposals are rejected as a whole; stale proposals cannot overwrite edits made in the table. Changing the document marks older conversation as historical and invalidates active requests and proposals. Closing the window starts a fresh session next time; chat history is not written into the TSI.

Requests and responses are bounded. The question limit is 4000 characters and 16 KiB of UTF-8 text, mapping context 80 rows / 96 KiB, conversation history 24 KiB, command catalogue 48 KiB and response 1 MiB / 8192 output tokens. A review is limited to 100 operations and 100 affected rows. Omitted context is reported; the reference guide still contains the whole mapping.

Controller support remains K1/K2/K3. The visual controller editor, Euphonia profiles and AI import repair are separate future work.

## Window and setup

Assistant uses the editor’s stone surfaces, compact controls and amber primary actions. The composer stays at the bottom; the conversation scrolls above it. AI setup and MIDI setup open one at a time to keep smaller windows usable. The window supports a minimum content size of 720 × 560.

Example prompts fill the composer for review. The selected-mappings example also enables selection context and is unavailable when no rows are selected. AI never sends automatically. Keychain access and API-key settings load asynchronously; a waiting state remains cancellable.

Invalid JSON imports can offer a separate reviewed repair flow. See [JSON repair](JSON-Repair.md).
