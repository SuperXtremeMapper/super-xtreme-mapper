# TSI File Format Specification

This document describes the binary format of Traktor's `.tsi` (Traktor Settings Interface) files, based on reverse engineering and the [CMDR project](https://github.com/cmdr-editor/cmdr).

## Overview

TSI files store MIDI controller mappings for Native Instruments Traktor Pro. The file consists of:

1. **XML wrapper** - Contains metadata and Base64-encoded binary data
2. **Binary payload** - Hierarchical frame structure with mapping data

This document describes the canonical layout the writer emits and the compatible source forms the importer preserves. It is not a claim that every proprietary/native frame has known editable semantics.

## Document preservation model

Opening a TSI creates an editable `MappingFile` plus a document-boundary raw envelope. The envelope retains the exact UTF-8 XML bytes, every controller entry, parsed primary frames, a semantic baseline, and a closed-world inventory of structures that the canonical writer cannot reproduce safely. Envelope data is deliberately excluded from clipboard payloads and semantic model equality.

Save uses a three-state safety lattice:

- **ordinarySaveSafe** — the modeled projection passes writer validation and every accepted source structure is reproducible. An edited document may regenerate normally.
- **lossyConvertible** — the file opens and its modeled projection can be written, but typed risks would be omitted or normalized. An unchanged save is still exact; an edited ordinary save refuses. The user may explicitly export a converted copy after reviewing the risks.
- **unwritable** — writer validation fails. Neither ordinary save nor converted export writes output.

An unchanged imported document always returns the envelope's original XML byte for byte, even when it contains native controls, compact legacy layout, unknown frames, duplicate singleton frames, or extra XML. Unknown/native structures therefore do **not** simply disappear on Save. They become ordered preservation risks that block an edited overwrite. A deliberately converted export writes only the modeled projection and leaves the source URL, source envelope, dirty state, baseline, and Undo history unchanged.

### XML Structure

```xml
<?xml version="1.0" encoding="UTF-8" standalone="no" ?>
<NIXML>
  <TraktorSettings>
    <Entry Name="DeviceIO.Config.Controller" Type="3" Value="[BASE64_DATA]"/>
  </TraktorSettings>
</NIXML>
```

## Binary Frame Structure

All binary data uses **big-endian** byte order.

### Frame Header

Every frame follows this structure:

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | char[4] | Frame identifier (ASCII) |
| 4 | 4 | uint32 | Frame size (excluding header) |
| 8 | N | byte[] | Frame data |

### Frame Hierarchy

```
DIOM (Device IO Mappings - root)
├── DIOI (version info)
└── DEVS (devices list)
    └── DEVI (device)
        ├── [Device Name - wide string]
        └── DDAT (device data)
            ├── DDIF (device target info)
            ├── DDIV (version info)
            ├── DDIC (comment)
            ├── DDPT (ports)
            ├── DDDC (MIDI definitions container)
            │   └── DDCI (MIDI in definitions)
            │       └── DCDT[] (MIDI definition entries)
            └── DDCB (command bindings)
                ├── CMAS (mappings list)
                │   └── CMAI[] (mapping entries)
                │       └── CMAD (mapping settings)
                └── DCBM (MIDI note binding list)
                    └── DCBM[] (binding entries)
```

Traktor 4.4.x controller-only exports may use a complete but compact variant: DDCI directly contains an uncounted stream of DCBM binding entries, whether DDCI appears under canonical DDDC or in the observed flattened layout, and CMAS directly contains an uncounted stream of CMAI mappings. The interpreter and preservation inventory recognize these layouts only when the next bounded frame identifier is exactly DCBM or CMAI, validate that frames tile the enclosing payload, enforce per-container and cumulative limits, retain the original bytes, and classify the noncanonical structure as lossy-convertible for edits. The canonical writer continues to emit counted lists.

## Input validation and resource limits

TSI XML must be UTF-8, optionally with a UTF-8 BOM. An encoding declaration must also name UTF-8; UTF-16 and UTF-32 are rejected. DTD and entity declarations are prohibited, external entity resolution is disabled, and Base64 must use the strict RFC 4648 alphabet with `=` only in valid final padding positions. Whitespace or ignored characters inside Base64 are not accepted.

The parser uses a streaming XML scanner and offset-based, unaligned-safe big-endian frame cursor. Default limits are:

| Resource | Default limit |
|---|---:|
| XML bytes | 96 MiB |
| Base64 attribute characters | 64 MiB |
| Decoded controller bytes | 48 MiB |
| Individual frame payload | 32 MiB |
| Frames per parsed container | 250,000 |
| UTF-16 string bytes | 1 MiB |
| XML elements | 100,000 |
| XML nesting depth | 128 |
| Controller entries | 64 |
| Binary container depth | 16 |
| Cumulative frames per document | 500,000 |

Each XML start-element callback counts exactly once. Within both the interpreter and inventory phases, one binary budget is shared across all nested containers, so nesting cannot reset cumulative work. Each limit has a distinct parse error.

## Frame Specifications

### DIOI (Device IO Info)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | Version (canonical writer emits 1; other imported values are preservation risks) |

### DDIF (Device Target Info)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | DeviceTarget enum |

**DeviceTarget enum:**
- 0 = Focus
- 1 = DeckA
- 2 = DeckB
- 3 = DeckC
- 4 = DeckD

### DDIV (Version Info)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4+N | wide string | Version string (e.g., "3.11.0") |
| N | 4 | uint32 | MappingFileRevision (typically 2) |

**Note:** The MappingFileRevision field is required - Traktor expects this extra 4 bytes.

### DDIC (Comment)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4+N | wide string | User comment |

### DDPT (Device Ports)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4+N | wide string | Input port name |
| N | 4+M | wide string | Output port name |

### DDCI (MIDI In Definitions)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | Definition count |
| 4 | N | DCDT[] | DCDT frames |

### DCDT (MIDI Definition)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4+N | wide string | MIDI note (e.g., "Ch15.CC.016") |
| N | 4 | uint32 | MidiControlType enum |
| N+4 | 4 | float | MinValue (typically 0.0) |
| N+8 | 4 | float | MaxValue (typically 127.0) |
| N+12 | 4 | uint32 | EncoderMode enum |
| N+16 | 4 | int32 | ControlId (-1 for unassigned) |

**MidiControlType enum:**
- 1 = Button
- 2 = FaderOrKnob
- 4 = PushEncoder
- 5 = Encoder
- 7 = GenericIn (use this for CC controls)
- 8 = Out
- 16 = Jog

**EncoderMode enum:**
- 0 = 3Fh/41h
- 1 = 7Fh/01h

### CMAS (Mappings List)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | Mapping count |
| 4 | N | CMAI[] | CMAI frames |

### CMAI (Mapping)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | MidiNoteBindingId (index into DCBM) |
| 4 | 4 | uint32 | MappingType (0=In, 1=Out) |
| 8 | 4 | uint32 | TraktorControlId |
| 12 | N | CMAD | Mapping settings frame |

### CMAD (Mapping Settings)

The canonical complete form is the most complex frame with 30 fields. Short or extended imported forms remain openable and exact on no-op save, but are typed preservation risks for edits.

| Offset | Size | Type | Field | Notes |
|--------|------|------|-------|-------|
| 0 | 4 | uint32 | DeviceType | **Must be 4 for GenericMidi** |
| 4 | 4 | uint32 | ControllerType | See enum below |
| 8 | 4 | uint32 | InteractionMode | See enum below |
| 12 | 4 | int32 | Target | See enum below |
| 16 | 4 | uint32 | AutoRepeat | 0 or 1 |
| 20 | 4 | uint32 | Invert | 0 or 1 |
| 24 | 4 | uint32 | SoftTakeover | 0 or 1 |
| 28 | 4 | float | RotarySensitivity | Default 1.0 |
| 32 | 4 | float | RotaryAcceleration | Default 0.0 |
| 36 | 4 | uint32 | HasValueUI | 0 or 1 |
| 40 | 4 | uint32 | ValueUIType | 1=ComboBox, 2=Slider |
| 44 | 4 | float | SetValueTo | Default 1.0 for sliders |
| 48 | 4+N | wide string | Comment | |
| ... | 4 | uint32 | ConditionOneId | Modifier M1-M8 (0=none) |
| ... | 4 | uint32 | ConditionOneTarget | 0 |
| ... | 4 | uint32 | ConditionOneValue | 0-7 |
| ... | 4 | uint32 | ConditionTwoId | |
| ... | 4 | uint32 | ConditionTwoTarget | |
| ... | 4 | uint32 | ConditionTwoValue | |
| ... | 4 | uint32 | LedMinControllerRangeType | 0 |
| ... | 4 | uint32 | LedMinControllerRange | 0 |
| ... | 4 | uint32 | LedMaxControllerRangeType | 0 |
| ... | 4 | uint32 | LedMaxControllerRange | 1 (integer, not float) |
| ... | 4 | uint32 | LedMinMidiRange | 0 |
| ... | 4 | uint32 | LedMaxMidiRange | 127 |
| ... | 4 | uint32 | LedInvert | 0 or 1 |
| ... | 4 | uint32 | LedBlend | 0 or 1 |
| ... | 4 | uint32 | UnknownValueUIType | 0 |
| ... | 4 | uint32 | Resolution | See enum |
| ... | 4 | uint32 | UseFactoryMap | 0 or 1 |

**DeviceType enum (CRITICAL):**
- 1 = Proprietary_Synth
- 2 = Proprietary_Audio
- 3 = Proprietary_Controller
- **4 = GenericMidi** (use this!)

**Note on proprietary device types (1-3):** these are real values Traktor writes for proprietary device sections. Imported CMAD data retains its exact payload and decoded wire scalars, including DeviceType, raw floating-point bit patterns, UI fields, conditions, LED fields, resolution, factory-map flag, and optional/trailing bytes. Unchanged values are preserved exactly. Field ownership limits an edit to its corresponding wire group. If an edited native CMAD cannot be reconciled, ordinary save is lossy-convertible or unwritable instead of guessing. Converted output normalizes proprietary DeviceType to Generic MIDI value 4 and reports that normalization.

**ControllerType enum:**
- 0 = Button
- 1 = FaderOrKnob
- 2 = Encoder
- **65535 = LED** (not 3!)

**InteractionMode enum:**
- 0 = Trigger
- 1 = Toggle
- 2 = Hold
- 3 = Direct
- 4 = Relative
- 5 = Increment
- 6 = Decrement
- 7 = Reset
- 8 = Output

**Target (MappingTargetDeck) enum:**
- -1 = DeviceTarget
- 0 = Deck A (Global commands also encode as 0 — the Global/Deck A collapse is a known TSI ambiguity)
- 1 = Deck B
- 2 = Deck C
- 3 = Deck D
- 4 = FX Unit 1
- 5 = FX Unit 2
- 6 = FX Unit 3
- 7 = FX Unit 4
- 8-15 = command-dependent extension range

**Remix-slot command target overload:** for slot commands such as `Slot FX On`
(239), `Slot Filter Adjust` (249), `Slot Filter On` (250), `Slot Volume`
(251), and `Slot Mute On` (259), Traktor uses the target field as
`deckIndex * 4 + slotIndex`:

| Target | Remix Deck / Slot |
|--------|-------------------|
| 0-3 | Deck A, Slots 1-4 |
| 4-7 | Deck B, Slots 1-4 |
| 8-11 | Deck C, Slots 1-4 |
| 12-15 | Deck D, Slots 1-4 |

**ValueUIType enum:**
- 1 = ComboBox (for buttons)
- 2 = Slider (for faders/encoders)

### DCBM (MIDI Note Binding List)

This frame is **critical** - it links BindingId values to actual MIDI note strings.

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | Binding count |
| 4 | N | DCBM[] | Nested DCBM frames |

Each nested DCBM binding:

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | BindingId |
| 4 | 4+N | wide string | MidiNote (e.g., "Ch15.CC.016") |

## Wide String Format

Strings are encoded as UTF-16BE with a 4-byte length prefix:

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | Character count |
| 4 | N*2 | uint16[] | UTF-16BE characters |

Example: "Ch15.CC.016" (11 characters)
```
0000000b 0043 0068 0031 0035 002e 0043 0043 002e 0030 0031 0036
```

## MIDI Note String Format

Canonical Generic MIDI output uses `Ch{channel:02d}.{type}.{value}`. CC output is zero-padded to three digits; the importer also accepts valid real Traktor CC values written with one or two digits and preserves their original spelling. Note names use their musical spelling.

Examples:
- `Ch01.CC.000` - Channel 1, CC 0
- `Ch15.CC.016` - Channel 15, CC 16
- `Ch09.Note.C4` - Channel 9, Note C4

Pitch Bend and paired high-resolution CC bindings use native/opaque names such as `Ch02.PitchBend` and `Ch05.CC.034+Ch05.CC.002`. They open, display, copy/paste, and transfer without losing their raw control name or DCDT metadata, and unchanged source passthrough retains every original binding byte. A copied or converted row may receive a newly generated binding ID because IDs are document-local. Native names are not coerced to an arbitrary Note or CC. Reassigning MIDI explicitly replaces the opaque binding with the selected modeled assignment.

## Imported device values and comments

Imported device registry names and input/output port strings are wire values and are emitted verbatim while unchanged; an empty imported port is not silently changed to `All Ports`. New devices use validated canonical defaults. Device comments (DDIC) and mapping comments (CMAD) are decoded, exposed for editing, and written back. This supports annotating macro groups without treating comments as disposable metadata.

## Fixture policy

Regression fixtures must be registered in `XtremeMappingTests/Fixtures/TSI/manifest.json` and follow [TSI-Fixture-Provenance.md](TSI-Fixture-Provenance.md). Tests verify SHA-256 before parsing and record whether evidence is a sanitized real export, a captured/reduced fragment, or generated data. A generated version label must never be presented as a real export. Complete-source fixtures must exercise the `TraktorMappingDocument` snapshot/file-wrapper boundary, not only parser helpers.

## Common Issues and Solutions

### Issue: Traktor crashes on import
**Solution:** Set DeviceType = 4 (GenericMidi) in CMAD

### Issue: Assignment shows wrong deck
**Solution:** Use correct Target values (A=0, B=1, C=2, D=3)

### Issue: Controller type shows "Assign !"
**Solution:** Set ValueUIType = 2 (Slider) for faders/knobs

### Issue: MIDI notes not showing
**Solution:** Include DCBM frame in DDCB to link BindingId to MIDI strings

### Issue: LED mappings don't work
**Solution:** Use ControllerType = 65535 for LED (not 3)

### Issue: Trigger mode not recognized
**Solution:** InteractionMode = 0 for Trigger (not 9)

## References

- [TraktorMappingFileFormat Wiki](https://github.com/ivanz/TraktorMappingFileFormat/wiki/File-Format-Specification)
- [CMDR Source Code](https://github.com/cmdr-editor/cmdr)
- [010 Editor Template](https://github.com/ivanz/TraktorMappingFileFormat/blob/master/Tools/TSI%20Mapping%20Template.bt)
