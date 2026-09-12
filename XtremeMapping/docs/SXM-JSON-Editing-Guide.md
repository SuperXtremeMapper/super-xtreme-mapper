# Editing a mapping with SXM JSON

Use SXM JSON to change readable mapping fields while retaining the original TSI source. Ordinary Save still produces TSI. JSON export is a separate operation and does not mark unsaved mapping changes as saved.

## Workflow

1. Open the TSI and export `.sxm.json`. Work on a copy of that JSON in a text editor.
2. Edit fields inside the ordered `devices` and `mappings` arrays. Keep existing UUIDs and the entire `preservation` section unchanged.
3. Import the JSON and review diagnostics, affected rows, preservation status and TSI output availability. Errors block acceptance; warnings can describe intentional overlapping assignments or per-field values normalized by the TSI writer. Review every reported before/after difference; a successful write check does not mean every JSON value has an identical wire representation.
4. Accept a valid candidate as a new untitled TSI document, then Save to a new TSI destination. Cancelling review leaves open documents untouched. The current TSI is not merged with or replaced by the JSON import.

Try the [complete example](examples/basic-mapping.sxm.json) for a small source-free mapping.

## Make a command edit

Numeric `commandID` is authoritative. The catalogue identifies command 100 as `Play/Pause` and command 206 as `Cue`. For an appropriate supported input row, change this pair:

```json
"commandID": 100,
"commandName": "Play/Pause"
```

To:

```json
"commandID": 206,
"commandName": "Cue"
```

These snippets are properties inside an existing complete mapping, not standalone import documents. You may instead remove `commandName`; export regenerates it from the command ID. Keep the row's assignment, controller type and interaction mode compatible with its new command. Source preservation still determines whether the particular edit can be written.

This mismatch is rejected with an actionable diagnostic:

```json
"commandID": 206,
"commandName": "Play/Pause"
```

Changing only the name never silently changes command identity. Unknown newly created commands are not validated simply because their IDs fit in an integer.

## Edit MIDI, comments and conditions

Comments accept Unicode. MIDI uses human channels 1–16 and note/CC numbers 0–127:

```json
"midi": { "kind": "controlChange", "channel": 1, "number": 8 }
```

For no generic assignment, use `{"kind":"unassigned","channel":1}`. MIDI reassignment replaces any opaque original assignment for that row; review preservation diagnostics before saving.

Condition `modifier` 1 means M1, not M2, and modifier values range from 0 to 7. Software-state conditions have different identifiers and value ranges. Retain exported condition targets unless deliberately changing them. See the [format reference](SXM-JSON-Format.md) for known and raw target representation.

## Reorder, add and remove rows

Move complete mapping objects within their current device array to reorder them. Delete a mapping object to remove a current row. Leave the original preservation correspondence unchanged in both cases.

Give each new row a newly generated UUID and provide every required mapping property. Copying an existing row requires a new UUID; duplicate identities are rejected. Each device also needs a distinct UUID. A row with a new UUID does not inherit the original row's opaque data. Moving a retained row ID to a different device is rejected; model the destination as a new row and review the resulting removal/addition.

A source-free document omits `preservation`, retains the format/version envelope, and provides complete modeled devices and mappings with unique UUIDs. It is suitable for supported new mappings. Do not convert an opaque source mapping to source-free JSON as a way to bypass a refusal.

## Keep preservation intact

The `preservation.originalXML` base64 text retains exact original bytes; `preservation.devices` associates original positions with exported IDs. Neither is an editable backup of the current JSON projection. Current unsaved changes appear in normal mapping fields while this section stays tied to the original baseline.

After a TSI save, export uses the saved wire values for fields unchanged since that save (for example Generic MIDI and All Ports defaults), while retaining subsequent unsaved edits. It checks byte-equivalent TSI output when the live import records differ from the reconstructed source.

A harmless comment edit may be patched safely into the original source. A structural or semantic change to a source containing unmodeled native records may instead produce a preservation refusal. In that case ordinary TSI output is unavailable: retain the original, undo or revise the unsupported change, and review again. Do not delete raw source, alter correspondence, or rely on automatic regeneration to discard unknown data. Untouched unknown source commands can be retained only when verified source reconstruction and the writer allow them.

Keep exported `sourceBits` objects intact unless replacing the field with a valid finite number. They preserve exceptional Float32 values, including negative zero; they are not ordinary parameter values.

## Schema and metadata

Associate the [v1 JSON Schema](../XtremeMapping/Resources/Schemas/sxm-mapping-v1.schema.json) through your editor's external schema configuration. Do not insert `$schema` into the document root: unrecognized fields are rejected. The schema catches many spelling, missing-field and range mistakes; import review additionally checks global UUID uniqueness, command semantics, source correspondence, resource limits and writer compatibility.

Optional `metadata` carries `profileReferences`, `physicalControls`, and `localOverrides`; supply all three arrays even if some are empty. Profile references may have explicit version pins. Physical controls associate a mapping UUID with a profile/control ID. Local overrides record MIDI hardware facts and do not override a row's command or assignment. An unknown profile reference does not invalidate an otherwise valid generic MIDI mapping.

No API key, controller-profile download, or AI repair is required for this workflow.
