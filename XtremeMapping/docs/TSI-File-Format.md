# TSI File Format Specification

This document describes the binary format of Traktor's `.tsi` (Traktor Settings Interface) files, based on reverse engineering and the [CMDR project](https://github.com/cmdr-editor/cmdr).

## Overview

TSI files store MIDI controller mappings for Native Instruments Traktor Pro. The file consists of:

1. **XML wrapper** - Contains metadata and Base64-encoded binary data
2. **Binary payload** - Hierarchical frame structure with mapping data

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

## Frame Specifications

### DIOI (Device IO Info)

| Offset | Size | Type | Description |
|--------|------|------|-------------|
| 0 | 4 | uint32 | Version (must be 1) |

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

This is the most complex frame with 30 fields:

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
- 0 = A / FX1 / Global (context-dependent)
- 1 = B / FX2
- 2 = C / FX3
- 3 = D / FX4

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

MIDI notes follow the pattern: `Ch{channel:02d}.{type}.{value:03d}`

Examples:
- `Ch01.CC.000` - Channel 1, CC 0
- `Ch15.CC.016` - Channel 15, CC 16
- `Ch09.Note.C4` - Channel 9, Note C4

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
