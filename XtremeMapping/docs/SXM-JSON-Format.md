# SXM JSON format, version 1

SXM JSON (`.sxm.json`) is an editable interchange format independent of the runtime and clipboard Codable formats. Its discriminator is `"format": "sxm-mapping"` and integer `"schemaVersion": 1`. Root `tsiVersion` is the runtime MappingFile version, not the schema version. Device `tsiVersion` is a separate Traktor version string.

The schema is [sxm-mapping-v1.schema.json](../XtremeMapping/Resources/Schemas/sxm-mapping-v1.schema.json). It describes structure and numeric representations; the import validator and ordinary TSI writer also check semantic compatibility. Passing JSON Schema alone does not prove that a file can produce a valid, lossless TSI. Import review reports per-field writer normalization warnings when ordinary TSI output changes an editable projected value; inspect these differences before accepting the candidate.

## Structure and limits

Root `format`, `schemaVersion`, `tsiVersion`, and ordered `devices` are required. Each device requires `id`, `name`, `comment`, `inPort`, `outPort`, `tsiVersion`, `mappingFileRevision`, and ordered `mappings`. Each mapping requires all fields in the editable MappingEntry inventory below, with runtime `midiAssignment` represented as `midi`, except the two optional modifier conditions. `commandName` is optional derived text. Optional fields may be omitted or null; exports omit nil values.

Unknown keys are rejected at every defined object, including metadata. Duplicate JSON object keys, unsupported schema versions, malformed syntax and duplicate device/mapping UUIDs are rejected. Device and mapping identities share one uniqueness domain. Use standard hyphenated UUID strings; retained identities should not be changed when editing or reordering existing rows.

Runtime limits are 128 MiB encoded JSON, nesting depth 64, 256 devices, 100,000 current mappings across all devices, and 1 MiB of UTF-8 per editable text field. Embedded source bytes additionally obey `TSIParseLimits`. JSON Schema cannot express encoded byte size, total mappings across nested arrays, source parsing, or UTF-8 byte length; `maxLength` is only a character-count bound. These runtime checks remain required. Model integer fields use the full signed 64-bit structural range so inherited source values remain representable. Runtime validation constrains new or edited command IDs, conditions, LED data and resolution, while allowing unchanged verified source exceptions where appropriate. Canonical base64 pad bits and source correspondence also require runtime validation.

Encoding uses sorted object keys and deterministic formatting while retaining array order. Repeated encoding of the same document is stable; new UUID allocation naturally changes output. The public projection represents current unsaved edits, while preservation retains the original source baseline.

## Stored model field inventory

**Editable** means a field belongs to the public projection and may be changed subject to validation and writer compatibility. **Preserved** means it is reconstructed from verified original source, never trusted as an externally supplied internal structure. **Derived** means generated from authoritative fields. Fields grouped in a cell each have the stated classification.

| Model | Stored field(s) | Classification / public representation |
|---|---|---|
| MappingFile | `devices` | Editable ordered array |
| MappingFile | `version` | Editable root `tsiVersion` |
| MappingFile | `interchangeMetadata` | Editable optional root `metadata` |
| MappingFile | `sourceEnvelope` | Preserved through `preservation` |
| Device | `id` | Editable identity; retain for existing device |
| Device | `name`, `comment`, `inPort`, `outPort` | Editable text, including exact imported empty strings |
| Device | `tsiVersion`, `mappingFileRevision` | Editable device format metadata |
| Device | `mappings` | Editable ordered array |
| Device | `importedIdentity` | Preserved original identity marker |
| ImportedDeviceIdentity | `name`, `inPort`, `outPort` | Preserved original wire strings |
| MappingEntry | `id` | Editable identity; retain for existing row |
| MappingEntry | `commandID` | Editable authoritative numeric command identity |
| MappingEntry | `ioType`, `assignment`, `interactionMode` | Editable enum tokens |
| MappingEntry | `midiAssignment` | Editable `midi` object |
| MappingEntry | `modifier1Condition`, `modifier2Condition` | Editable optional condition objects |
| MappingEntry | `comment`, `controllerType`, `invert`, `softTakeover` | Editable |
| MappingEntry | `setToValue`, `rotarySensitivity`, `rotaryAcceleration` | Editable Float32 values, with exceptional representation below |
| MappingEntry | `encoderMode`, `autoRepeat` | Editable |
| MappingEntry | `ledMinRangeType`, `ledMinRangeData`, `ledMaxRangeType`, `ledMaxRangeData` | Editable integer selectors/data; native data may contain unsigned float bit patterns |
| MappingEntry | `ledMinMidi`, `ledMaxMidi`, `ledInvert`, `ledBlend` | Editable output options; new/edited MIDI bytes 0–127, with unchanged-source exceptions |
| MappingEntry | `resolution` | Editable integer value, potentially a native unsigned float bit pattern |
| MappingEntry | `rawMidiControlName`, `rawMidiBindingID` | Preserved opaque/proprietary MIDI assignment |
| MappingEntry | `rawDCDTEncoderMode`, `rawDCDTControlType`, `rawDCDTMinValueBits`, `rawDCDTMaxValueBits`, `rawDCDTControlID` | Preserved native MIDI definition state |
| MappingEntry | `importedCMAD` | Preserved full original mapping payload and baseline |
| MIDIAssignment | `kind`, `channel`, `number` | Editable `midi` fields |
| ModifierCondition | `modifier`, `value`, `target` | Editable; target uses token and optional `rawTarget` |

Computed properties are not additional stored fields. `commandName` and `commandDescriptor` are derived from `commandID`; only optional `commandName` is exposed. A conflicting supplied name is an error, never a request to resolve a different command silently. MIDI aliases `midiChannel`, `midiNote`, `midiCC`, all display/sort strings, condition `wireID`, `effectiveDCDTEncoderMode`, flattened mappings and compatibility warnings are derived and are not accepted as extra keys.

All stored ImportedCMAD fields below are **preserved** and reconstructed from parsed source:

| Group | Fields |
|---|---|
| Payload/header | `payload`, `deviceType`, `controllerType`, `interactionMode`, `assignment`, `autoRepeat`, `invert`, `softTakeover`, `rotarySensitivityBits`, `rotaryAccelerationBits`, `hasValueUI`, `valueUIType`, `setToValueBits`, `commentLength`, `commentWasLossy` |
| Conditions | `conditionOneID`, `conditionOneTarget`, `conditionOneValue`, `conditionTwoID`, `conditionTwoTarget`, `conditionTwoValue` |
| Output/tail | `ledMinRangeType`, `ledMinRangeData`, `ledMaxRangeType`, `ledMaxRangeData`, `ledMinMidi`, `ledMaxMidi`, `ledInvert`, `ledBlend`, `unknownVUI`, `resolutionBits`, `useFactoryMap`, `optionalBytes`, `trailingBytes` |
| Baseline | `semanticAtImport` |

Every stored SemanticFingerprint field is likewise **preserved**: `commandID`, `ioType`, `assignment`, `interactionMode`, `midiAssignment`, `rawMidiControlName`, `rawMidiBindingID`, `modifier1Condition`, `modifier2Condition`, `comment`, `controllerType`, `invert`, `softTakeover`, `setToValueBits`, `rotarySensitivityBits`, `rotaryAccelerationBits`, `encoderMode`, `rawDCDTEncoderMode`, `rawDCDTControlType`, `rawDCDTMinValueBits`, `rawDCDTMaxValueBits`, `rawDCDTControlID`, `autoRepeat`, `ledMinRangeType`, `ledMinRangeData`, `ledMaxRangeType`, `ledMaxRangeData`, `ledMinMidi`, `ledMaxMidi`, `ledInvert`, `ledBlend`, and `resolution`. The baseline is never overwritten by current JSON edits.

## Enum and scalar representations

| Field | Tokens |
|---|---|
| `ioType` | `input`, `output`; `all` is reserved for unchanged inherited source state |
| `midi.kind` | `unassigned`, `note`, `controlChange` |
| `controllerType` | `none`, `button`, `faderOrKnob`, `encoder`, `led` |
| `interactionMode` | `none`, `toggle`, `hold`, `direct`, `relative`, `increment`, `decrement`, `reset`, `output`, `trigger` |
| `encoderMode` | `mode7Fh01h`, `mode3Fh41h` |
| `assignment` | `none`, `deviceTarget`, `global`, `deckA`, `deckB`, `deckC`, `deckD`, `fxUnit1`–`fxUnit4`, `remixSlot1`–`remixSlot8`, and all sixteen `remixDeckASlot1`–`remixDeckDSlot4` combinations |
| Condition `target` | `deckA`, `deckB`, `deckC`, `deckD`, `deviceTarget`, `raw` |

MIDI channels use decimal human numbering 1–16. Notes and CC numbers use 0–127. `note` and `controlChange` require a non-null `number`; `unassigned` omits it or sets it to null. A MIDI edit replaces opaque source MIDI/DCDT definition state for that row.

Condition `modifier` uses 1–8 for M1–M8, whose values are 0–7. Other identifiers describe software states or retained opaque conditions, so do not constrain every condition to eight modifiers. Hotcue state can use 4294967295 for no hotcue. A `raw` target requires an unsigned 32-bit `rawTarget`; other targets omit it or use null. Slot State condition 247 uses targets 0–15; values 4–15 therefore use `raw` even though they have known deck/slot meanings. Known condition values and targets receive command-specific runtime validation.

The three floating fields accept finite Float32 JSON numbers. Their ranges depend on command meaning: `setToValue` may be a selector or negative hotcue sentinel, and rotary sensitivity is not universally bounded to 3. Exceptional values use `{"sourceBits": 2147483648}` for negative zero, or the IEEE-754 unsigned 32-bit pattern for a nonfinite value. `sourceBits` is forbidden for ordinary finite values. Nonfinite values must match the same field of the verified original row bit-for-bit; they cannot create new nonfinite state. Negative zero is representable without source. Bare NaN and Infinity are invalid JSON.

## Preservation

Optional `preservation` requires `originalXML` (canonical base64 of exact original XML bytes) and ordered `devices`. Each source device contains `id` and ordered `mappingIDs`, corresponding positionally to every parsed original device and row. This array describes original source positions, not the current editable order.

Import reparses the original bytes, validates full correspondence and unique IDs, restores identities, then overlays the current projection by stable ID. It does not trust serialized raw frames, fingerprints, risk assessments or safety claims. Current arrays may reorder or remove records and include genuinely new IDs; keep the preservation correspondence unchanged. Moving an original mapping identity into another device is rejected; a new row needs a new UUID.

Unedited source-backed data can use exact original-byte passthrough. Edits retain the ordinary writer's source-patching, regeneration and refusal rules. Unsupported edits to opaque source data may be inspectable but cannot be saved through ordinary TSI output. Removing preservation is not a safe repair: it discards retained source information. Source-free JSON is valid for supported modeled mappings and makes no claim to preserve opaque bytes.

## Controller metadata

Optional root `metadata` requires all three arrays when present:

- `profileReferences`: objects with required `profileID` and optional `version` pin.
- `physicalControls`: objects with required `mappingID`, `profileID`, and `controlID`.
- `localOverrides`: objects with required `mappingID` and `midi`.

These are descriptive references and local hardware facts, not alternative authoritative Traktor assignments. Unknown profiles do not block otherwise valid generic MIDI imports. Metadata MIDI overrides do not silently rewrite the row's `midi`. No arbitrary extension keys are accepted and no API key is required.
