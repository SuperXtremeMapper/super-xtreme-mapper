# Reliable TSI Commands, MIDI, Batch Transfer, and Comments Design

**Date:** 2026-08-27

**Status:** Approved

## Goal

Make XtremeMapping a safe editor for Traktor Pro 4.4.1 mappings by preserving the numeric command and MIDI data that Traktor actually consumes, while adding a practical workflow for moving multi-command macros between TSI documents, assigning one learned MIDI control to the pasted group, and reading or writing mapping comments.

## Approved Product Decisions

1. Traktor Pro 4.4.1 is the source of truth for commands offered when creating or changing a mapping.
2. Imported positive command IDs that are legacy or unknown are preserved exactly. They are not dropped, silently renamed to a different command, or offered as verified commands for new mappings.
3. One MIDI Learn event applies the same learned Note or CC and channel to every selected mapping.
4. Mapping comments are visible in a table column, searchable, editable, and copied with mappings. The device-level TSI comment is separately editable.
5. Batch copy and paste works between every open TSI document window in the app. A pasted group remains selected so it can immediately receive a shared MIDI assignment.
6. A paste or bulk edit is one undoable operation.

## Current Problems

### Command identity is label-based

`MappingEntry` stores only `commandName`. `TSIInterpreter` converts each numeric CMAI command ID to a name, and `TSIWriter` later converts the name back to an ID. That round trip is unsafe when a label is wrong, duplicated, renamed, legacy, or unknown. A positive unknown ID can currently be filtered out on save.

The command catalog and menu hierarchy duplicate hundreds of ID/name pairs, so their existing consistency test can pass even when both copies contain the same incorrect data. The current dynamic meter range at 2688–2703 is one confirmed example: deck selection belongs in CMAD assignment data, while the command IDs describe meter channels rather than Deck A/B/C/D variants. Other early command entries also conflict with the CMDR reference and observed Traktor files.

### MIDI state can be ambiguous or invalid

`MappingEntry` can contain both `midiNote` and `midiCC`. The UI displays Note first while the writer emits CC first. MIDI channels and control numbers are not consistently validated, and a negative note can crash note-name formatting.

The UI-facing `EncoderMode` raw values are intentionally `7Fh/01h = 0` and `3Fh/41h = 1`, but Traktor's DCDT values are the inverse for generic MIDI controls: `3Fh/41h = 0` and `7Fh/01h = 1`. The writer currently hard-codes `1`, and the interpreter does not parse DDCI/DCDT, so the user's encoder choice is not restored on import.

### Mapping transfer is window-local and lossy

`ContentView` stores copied mapping rows in window-local state. Copying in one TSI window therefore cannot paste into another. Duplicate, paste, and drop each rebuild `MappingEntry` manually and omit some newer CMAD pass-through fields. The Edit menu has a fourth, even more lossy duplicate implementation.

### Comments are persisted but poorly exposed

The reader and writer already round-trip DDIC device comments and CMAD per-mapping comments, including UTF-16 text. Mapping comments are available only in the single-selection settings panel and are not searchable or visible in the table. There is no device-comment editor.

## Architecture

### 1. Numeric command IDs are authoritative

`MappingEntry` gains a stored `commandID: Int`. All TSI serialization and command-specific behavior uses this property directly.

`commandName` becomes display metadata derived from `commandID` through the catalog. JSON encoding continues to include the display name for readability and backward compatibility, but decoding follows these rules:

1. If `commandID` exists, it wins even if an encoded `commandName` is stale.
2. If an older JSON entry has only `commandName`, resolve it once through the legacy name lookup.
3. Apply the existing legacy Remix Slot migration before deriving the canonical ID and assignment.
4. A legacy JSON name that cannot be resolved becomes command ID `0` and is visibly invalid; no raw ID existed to recover.

TSI import stores the raw positive CMAI ID before looking up any label. TSI export writes that stored ID. Command ID `0` remains Traktor's placeholder/unassigned row and is not exported as a usable mapping. Any other positive unknown command ID is preserved.

### 2. One catalog with evidence status

Each command descriptor contains:

```swift
struct TraktorCommandDescriptor: Identifiable, Equatable, Sendable {
    enum Verification: String, Codable, Sendable {
        case verifiedTraktor441
        case legacy
        case unknown
    }

    let id: Int
    let name: String
    let verification: Verification
}
```

Catalog evidence is interpreted conservatively:

- `verifiedTraktor441`: the numeric ID is observed in the local Traktor 4.4.1 mapping corpus and its semantic label is corroborated by the independent command reference used for the audit.
- `legacy`: the ID/name pair exists in the older reference catalog but is not verified in the 4.4.1 corpus.
- `unknown`: the positive imported ID has no trusted catalog descriptor.

The catalog is the only source for ID/name lookup. The hierarchical Add menu contains verified 4.4.1 descriptors only and passes the whole descriptor, not a bare string, to mapping creation. Voice-created mappings use the same verified list. Legacy and unknown imported rows remain visible and editable in every non-command field, with a status badge and a stable fallback such as `Unknown command #4242`.

The audit will correct conflicting entries rather than perpetuating current names. Tests compare the menu hierarchy against the catalog, but do not treat internal self-consistency as external verification.

### 3. A validated MIDI assignment value

MIDI control state is represented by one value:

```swift
enum MIDIAssignment: Equatable, Sendable, Codable {
    case unassigned(channel: Int)
    case note(channel: Int, number: Int)
    case controlChange(channel: Int, number: Int)
}
```

The valid ranges are channel `1...16` and Note/CC `0...127`. Creating an assignment outside those ranges fails validation. Applying a Note necessarily clears CC; applying a CC necessarily clears Note. Existing `midiChannel`, `midiNote`, and `midiCC` compatibility accessors may remain during migration, but every write boundary uses `MIDIAssignment` so ambiguous state cannot be produced.

External boundaries behave as follows:

- MIDI Learn ignores Note Off and stops after the first valid Note On or CC message.
- TSI parsing rejects malformed or out-of-range generic DCBM control names with a precise import error.
- JSON decoding rejects an impossible state such as both Note and CC.
- The writer never emits an invalid MIDI control name. An invalid in-memory mapping is reported and omitted rather than crashing or emitting corrupt bytes.
- Unassigned mappings remain valid and keep their chosen channel for later editing.

### 4. DDCI/DCDT encoder-mode fidelity

`EncoderMode` retains its existing Codable raw values and adds explicit Traktor conversion:

```swift
var tsiDCDTValue: UInt32
init?(tsiDCDTValue: UInt32)
```

For generic MIDI controls, the conversion is `3Fh/41h -> 0` and `7Fh/01h -> 1`.

The writer builds each unique DCDT definition from `(controlName, direction, encoderMode)` and writes the selected Traktor value. Input definitions are emitted under DDCI and output/LED definitions under DDCO, matching Traktor's separate definition containers. If two mappings share the same control and direction but claim different encoder modes, export fails with a descriptive conflict rather than depending on row order.

The interpreter parses DDCI and DDCO definitions structurally and indexes them by control name plus direction. DCBM remains authoritative for mapping-to-control binding; DCDT supplies control metadata such as encoder mode. Missing definitions retain the current default for backward compatibility. Unknown proprietary DCDT mode values are preserved as opaque metadata when possible and never relabeled as one of the two generic encoder modes.

### 5. Lossless app-wide mapping clipboard

`ClipboardManager.shared` gains an app-wide mapping batch alongside its existing MIDI and modifier clipboards. It owns copied value snapshots, so copying in one document window and pasting in another works for the lifetime of the app session.

`MappingEntry.copyWithNewID()` is the only cloning operation. It copies every property, including command ID, comments, modifiers, interaction settings, auto-repeat, LED ranges, LED MIDI values, inversion/blend flags, resolution, and encoder mode, while generating a fresh UUID.

All duplicate, paste, and drop paths use the same clone operation. Pasting appends rows in their original order to the target document's first device, creating a `Generic MIDI` device only when the target contains no devices. The newly created IDs replace the current selection.

Standard Copy/Paste commands and the table context menu call the same shared operations. Copying mappings does not overwrite the specialized “Mapped To” or modifier clipboards.

### 6. Bulk MIDI assignment and Learn

The multi-selection settings view exposes:

- the shared assignment type: Note, CC, or Unassigned;
- channel `1...16`;
- Note/CC number `0...127` when applicable;
- a one-shot Learn button.

Manual Apply and a learned MIDI message update only the selected rows' MIDI assignments. They do not flatten controller type, interaction mode, LED settings, modifiers, or comments. A learned Note or CC and its channel are applied identically to the whole selection.

Single-row Learn continues to infer controller type where that existing behavior is useful. Multi-row Learn deliberately does not infer or replace per-row controller behavior.

### 7. Real undo transactions

`TraktorMappingDocument` owns an undoable mutation helper that snapshots the value-typed `MappingFile`, applies one mutation, marks the document dirty, and registers the inverse snapshot for undo/redo.

The following are single undo units regardless of selection size:

- batch paste or duplicate;
- a learned or manually applied MIDI assignment;
- bulk assignment/type/interaction/modifier edits;
- applying one comment to a selection;
- device-comment edits.

This replaces the current placeholder undo registration that marks the document changed without restoring data.

### 8. Comment experience

The mappings table adds a resizable Comment column. Search is case-insensitive and matches:

- command display name;
- mapping comment;
- owning device name;
- owning device comment.

A mapping-comment match returns only that row. A device name/comment match returns all rows belonging to that device.

The single-selection settings panel uses a multiline comment editor. The multi-selection panel provides an explicit `Apply comment to selection` action so merely opening the editor cannot erase mixed comments. Device comments are edited in a small sheet with a device picker because one TSI may contain multiple devices. Device names are not repurposed as user labels.

Comments remain UTF-16BE TSI strings on disk and are copied losslessly with mapping batches.

## Data Flow

### TSI import

1. Parse XML and binary frame hierarchy.
2. Read DDIC device metadata, DDCI/DDCO control definitions, DCBM bindings, CMAI raw command IDs, and CMAD mapping settings/comments.
3. Validate generic MIDI control names and build one `MIDIAssignment` per row.
4. Store the raw positive command ID and derive a display descriptor without changing the ID.
5. Attach encoder metadata by `(control name, direction)`.

### Batch transfer

1. Copy selected rows in document order into `ClipboardManager.shared`.
2. Paste clones them with fresh IDs into the destination document as one undoable mutation.
3. Replace the destination selection with the pasted IDs.
4. One manual assignment or MIDI Learn applies the same `MIDIAssignment` to the selected group as one undoable mutation.

### TSI export

1. Validate each mapping's command ID and MIDI assignment.
2. Preserve every positive command ID, including unknown imported IDs.
3. Build separate DDCI input and DDCO output definitions with the correct generic encoder value.
4. Build DCBM/CMAI/CMAD using the stored command ID and mapping settings.
5. Emit DDIC and CMAD comments without normalization.

## Error Handling

- Structural TSI corruption continues to fail import rather than producing partially shifted frames.
- Invalid generic MIDI ranges report the offending control string.
- Conflicting encoder definitions report the control and direction involved.
- Unknown positive command IDs are warnings/status information, not import or export errors.
- Command ID `0` is an invalid/placeholder mapping and is not silently converted to another command.
- Locked documents disable mutations, paste, Learn, and comment editing.
- Empty mapping clipboards disable Paste.

## Verification Strategy

All behavior changes follow test-first development. The test suite will cover:

1. Codable migration from name-only mappings to authoritative command IDs.
2. Unknown positive command-ID import, export, and comment preservation.
3. Corrected catalog IDs and status classification, including known conflict examples.
4. Every verified command descriptor round-tripping its exact numeric ID.
5. MIDI channels 1 and 16, Note/CC values 0 and 127, and rejection outside those bounds.
6. Note/CC exclusivity in display, clipboard, Learn, and writer output.
7. DCDT values `0` and `1`, direction-aware lookup, missing definitions, malformed definitions, and conflicting definitions.
8. Sanitized reference DCDT bytes extracted from real Traktor 4.4.1 mappings for both generic encoder modes. Tests compare stable frame semantics and the exact DCDT value rather than whole personal TSI files.
9. Fresh-ID lossless clones preserving every `MappingEntry` field.
10. Cross-document batch copy/paste, order, selection, and one-step undo/redo.
11. Shared manual MIDI assignment and one-shot Learn that ignores Note Off.
12. Search and editing for mapping and device comments, plus Unicode TSI round trips.

The repository gains a repeatable unit-test command that disables signing for the test build, skips UI automation when unavailable, disables parallel execution for stateful singleton tests, and produces an `.xcresult`. A full app build remains a separate required gate. UI behavior that cannot be covered reliably through the current UI runner is driven through extracted domain operations and manually smoke-tested in the built app.

## Compatibility and Migration

- Existing JSON documents without `commandID` remain readable.
- Existing app raw values for `EncoderMode` do not change, avoiding a persistence migration.
- Imported legacy/unknown positive command IDs remain byte-stable across save.
- Existing DDIC and CMAD comments remain byte-compatible UTF-16BE strings.
- Existing specialized “Copy/Paste Mapped To” and “Copy/Paste Modifiers” commands remain available.

## Out of Scope

- Sequential MIDI Learn that walks each pasted row one by one.
- Persisting the mapping clipboard across app relaunches or exposing its private payload to other applications.
- Editing arbitrary unknown XML entries or unknown binary TSI frames unrelated to mappings.
- Claiming that an unofficial older catalog proves a command is supported by Traktor 4.4.1 without corroborating evidence.
- Automating Traktor's preferences UI or importing test mappings into the user's live Traktor configuration.

## Evidence Sources

- The locally installed Traktor Pro 4.4.1 application and 96 TSI files under the user's Traktor 4.4.1 data directory, inspected read-only.
- CMDR's public command and format references, used as an independent semantic cross-check rather than as proof of 4.4.1 support.
- `py-ni-traktor-tsi` format/constants implementation, used as a second check for selected command and binary-field meanings.
- The repository's existing parser/writer tests and `docs/TSI-File-Format.md`.
