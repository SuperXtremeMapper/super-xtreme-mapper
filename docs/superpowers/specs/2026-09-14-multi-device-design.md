# Multi-device workflows

Approved direction: implement device management, explicit editing destinations, source-aware MIDI learning, and cross-device operations before exploring a larger UI redesign.

Mapping devices remain independent of physical MIDI endpoints. Existing Device IDs identify mapping groups; ports describe hardware routing. Offline mapping is supported. Existing single-device behavior remains convenient; ambiguous multi-device destinations must never fall back to the first device.

Provide undoable add/update/duplicate/delete and copy/move operations. Duplicate IDs and profile row references must be remapped. Remove metadata referring to deleted devices/rows. Preserve imported opaque TSI data through the existing writer/preflight rules. Selected-device export must use deliberate conversion without overwriting the source file.

Keep an active device on the document, shared by editor and assistant. Basic controls in the existing layout expose creation, selection, management, transfer, and export. A later UX proposal will evaluate sidebar and combined-view ownership. New mappings and paste use an explicit active device, otherwise a single selected owner, otherwise the sole device; empty documents may create their first device. Invalid explicit destinations fail. All-device view never guesses between devices.

MIDI messages retain source endpoint identity. Learning filters by configured input port, distinguishing identical MIDI addresses from separate devices. Missing or ambiguous endpoints fail closed. Reconnection cannot redirect capture to another device. Existing all-port single-device capture remains possible. Wire this through settings, wizard, voice, and assistant capture.

Verify creation/duplication/deletion, metadata cleanup, atomic transfer and stale destination rejection, undo/redo, multiple-device save/reopen and selected export, and same-address source filtering. Hardware verification remains separate from automated tests.
