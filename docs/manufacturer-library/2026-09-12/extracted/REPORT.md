# Stage 1 extraction report

Prepared evidence datasets for all **26 ready-for-extraction candidates**, containing **27,735 normalized bindings** and complete protocol text. These include the three existing K-series profiles; **no new runtime profiles are installed**. A binding count includes separate modes, banks, channels and directions, not just physical controls.

Claude’s Assistant presentation changes at `67adb09` were reviewed on local `main`. They use the editor’s amber styling, shared controls, typography, notices and panel treatment. This extraction does not change the Assistant, conversation, edit-review or Undo code.

## Coverage

| Manufacturer | Model | Bindings | Conflict records | Dataset |
|---|---|---:|---:|---|
| Akai Professional | APC mini mk2 | 1,258 | 0 | [JSON](performance-inmusic/akai-apc-mini-mk2.json) |
| Akai Professional | APC40 mkII | 1,179 | 2 | [JSON](performance-inmusic/akai-apc40-mkii.json) |
| Allen & Heath | XONE:K1 | 160 | 1 | [JSON](allen-heath-hercules/xone-k1.json) |
| Allen & Heath | XONE:K2 | 274 | 1 | [JSON](allen-heath-hercules/xone-k2.json) |
| Allen & Heath | XONE:K3 | 276 | 1 | [JSON](allen-heath-hercules/xone-k3.json) |
| Allen & Heath | Xone:92 Mk2 | 6 | 0 | [JSON](allen-heath-hercules/xone-92-mk2.json) |
| Allen & Heath | Xone:96 | 76 | 0 | [JSON](allen-heath-hercules/xone-96.json) |
| AlphaTheta | CDJ-3000X | 90 | 0 | [JSON](pioneer-alphatheta/cdj-3000x.json) |
| AlphaTheta | DDJ-GRV6 | 1,647 | 0 | [JSON](pioneer-alphatheta/ddj-grv6.json) |
| AlphaTheta | Euphonia | 76 | 0 | [JSON](allen-heath-hercules/euphonia.json) |
| AlphaTheta | OMNIS-DUO | 359 | 0 | [JSON](pioneer-alphatheta/omnis-duo.json) |
| AlphaTheta | XDJ-AZ | 1,442 | 0 | [JSON](pioneer-alphatheta/xdj-az.json) |
| Denon DJ | LC6000 PRIME | 78 | 2 | [JSON](performance-inmusic/denon-lc6000-prime.json) |
| Faderfox | UC4 | 8,244 | 0 | [JSON](performance-inmusic/faderfox-uc4.json) |
| Hercules | DJControl Inpulse 500 | 786 | 9 | [JSON](allen-heath-hercules/djcontrol-inpulse-500.json) |
| Novation | Launch Control XL 3 | 223 | 2 | [JSON](performance-inmusic/launch-control-xl-3.json) |
| Novation | Launchpad Mini MK3 | 566 | 0 | [JSON](performance-inmusic/launchpad-mini-mk3.json) |
| Novation | Launchpad Pro MK3 | 741 | 0 | [JSON](performance-inmusic/launchpad-pro-mk3.json) |
| Novation | Launchpad X | 566 | 0 | [JSON](performance-inmusic/launchpad-x.json) |
| Pioneer DJ | DDJ-FLX10 | 3,012 | 0 | [JSON](pioneer-alphatheta/ddj-flx10.json) |
| Pioneer DJ | DDJ-FLX4 | 694 | 5 | [JSON](pioneer-alphatheta/ddj-flx4.json) |
| Pioneer DJ | DDJ-REV5 | 2,746 | 11 | [JSON](pioneer-alphatheta/ddj-rev5.json) |
| Pioneer DJ | DDJ-REV7 | 1,164 | 0 | [JSON](pioneer-alphatheta/ddj-rev7.json) |
| Pioneer DJ | DJM-A9 | 164 | 0 | [JSON](pioneer-alphatheta/djm-a9.json) |
| Pioneer DJ | DJM-S11 | 495 | 16 | [JSON](pioneer-alphatheta/djm-s11.json) |
| Pioneer DJ | XDJ-RX3 | 1,413 | 0 | [JSON](pioneer-alphatheta/xdj-rx3.json) |

## How to interpret the results

Every normalized binding cites an archived source and a page or section. Original source hashes are checked against the candidate catalogue and files on disk. The index also records hashes for the extracted datasets and protocol text. Manufacturer documentation is the evidence standard for this stage; no hardware testing is claimed.

The runtime profile schema currently has a global MIDI channel and a small set of K-series layers, colors and encodings. Most new records therefore require an adapter before SXM can use them. Explicitly retained modes, ports, compound values, RGB/palette behavior and SysEx descriptions must not be flattened into that schema.

Conflict counts are issue records, not numbers of physical controls. Some record historical diagram inconsistencies with independently supported bindings retained. Other issues quarantine multiple bindings. The per-model JSON identifies the excluded entries and their evidence.

## Remaining work by model

### Akai Professional APC mini mk2

Complete clip address range, track/scene/Shift buttons and faders; all sixteen documented RGB behavior channels. Session input channel unspecified within documented 0–15 range; Drum/Note port contexts kept separate.

- **Unsupported:** RGB SysEx uses paired MSB/LSB per 8-bit RGB component and pad ranges. Introduction reply claims four data bytes but lists nine faders; literal 00x4F/00x7F typos retained. Needs dedicated parser, initialization reply excluded. Evidence: protocol: PDF pp9–14.

### Akai Professional APC40 mkII

Complete unambiguous Mode 1/2 input note chart, track faders, primary knob CC banks, host LED and ring feedback. Generic Mode 0 device-knob banks retained separately. Duplicate/misaligned inbound labels and Cue conflict excluded.

- **Conflict:** Inbound table repeats Device Knob1–8 at CC0x18–0x1F and Track Knob1–8 at CC0x38–0x3F, which outbound chart identifies as ring-style addresses. Do not recast as physical input. Note0x41 is both Detail View and stray Metronome(8); unlabeled CLIP STOP row retained raw. Evidence: protocol: PDF pp32–36; pp24–26.
- **Conflict:** Cue Level CC0x2F appears in absolute and relative inbound tables. Relative table defines signed delta but no authoritative correction distinguishes Cue. Excluded pending clarification. Evidence: protocol: PDF pp35,37.
- **Scope:** Generic-mode note banking/toggles are not normalized beyond definite CC banks. Introduction/inquiry and ring segment bit patterns remain complete raw evidence; dedicated adapter required. Evidence: protocol: PDF pp2–12,27–29.

### Allen & Heath XONE:K1

Existing reviewed factory profile facts transcribed with original manufacturer provenance, distinct sends/returns and layers. Mode configuration and reservations retained. This extraction makes no additional hardware or integration claim; custom maps and unspecified velocities remain unresolved.

- **Scope:** Addresses use the configured global MIDI channel (documented default 15). Physical position and Traktor deck assignment are independent. Evidence: s1: XoneK1_UG_AP9694_2.pdf p.12 MIDI channel; s1: XoneK1_UG_AP9694_2.pdf pp.8-9 controls.
- **Scope:** LED diagrams document note addresses and colors, but not universal on/off velocity thresholds. Evidence: s1: XoneK1_UG_AP9694_2.pdf p.13.
- **Scope:** MIDI note labels vary by application; numeric note IDs use the manufacturer conversion table. Evidence: s1: XoneK1_UG_AP9694_2.pdf p.15 upper matrix.
- **Conflict:** The small lower conversion table on p.15 misprints decimal 13–15 hex values. The upper matrix and hexadecimal arithmetic establish 0D, 0E and 0F. K2 embedded latching layers are not documented for K1. Evidence: s1: XoneK1_UG_AP9694_2.pdf p.15 upper and lower conversion tables; s1: XoneK1_UG_AP9694_2.pdf pp.13-14 MIDI send/return.

### Allen & Heath XONE:K2

Existing reviewed factory profile facts transcribed with original manufacturer provenance, distinct sends/returns and layers. Mode configuration and reservations retained. This extraction makes no additional hardware or integration claim; custom maps and unspecified velocities remain unresolved.

- **Scope:** Addresses use the configured global MIDI channel (documented default 15). Physical position and Traktor deck assignment are independent. Evidence: s1: XoneK2_UG_AP8509_3.pdf p.11 MIDI channel; s1: XoneK2_UG_AP8509_3.pdf pp.12-13 latching layers.
- **Scope:** LED diagrams document note addresses and colors, but not universal on/off velocity thresholds. Evidence: s1: XoneK2_UG_AP8509_3.pdf p.17.
- **Scope:** MIDI note labels vary by application; numeric note IDs use the manufacturer conversion table. Evidence: s1: XoneK2_UG_AP8509_3.pdf pp.19-20.
- **Scope:** The LAYER button is freely assignable only with layers off. Its diagrammed colored sends are retained as evidence but it is reserved for layer switching in enabled modes. Evidence: s1: XoneK2_UG_AP8509_3.pdf pp.12-13 latching layers.
- **Scope:** All-controls mode uses embedded soft pickup for pots and faders. This is hardware behavior, separate from Traktor soft takeover. Evidence: s1: XoneK2_UG_AP8509_3.pdf pp.12-13 latching layers.
- **Conflict:** Send p.14 pot switch row 2 column 3 misprints A#2 alongside Bb5/Bb8. Return p.17 and the conversion table support numeric notes 82/118, respectively. Evidence: s1: XoneK2_UG_AP8509_3.pdf p.14 send diagram; s1: XoneK2_UG_AP8509_3.pdf p.17 return diagram; s1: XoneK2_UG_AP8509_3.pdf pp.19-20 conversion table.

### Allen & Heath XONE:K3

Existing reviewed factory profile facts transcribed with original manufacturer provenance, distinct sends/returns and layers. Mode configuration and reservations retained. This extraction makes no additional hardware or integration claim; custom maps and unspecified velocities remain unresolved.

- **Scope:** Addresses use the configured global MIDI channel (documented default 15). Physical position and Traktor deck assignment are independent. Evidence: s6: Xone-K3-User-Guide.txt Global MIDI Channel; s6: Xone-K3-User-Guide.txt Latching Layer Options; s6: Xone-K3-User-Guide.txt UNIT MAPS.
- **Scope:** LED diagrams document note addresses and colors, but not universal on/off velocity thresholds. Evidence: s5: midi-return-01.png.
- **Scope:** MIDI note labels vary by application; numeric note IDs use the manufacturer conversion table. Evidence: s6: Xone-K3-User-Guide.txt MIDI CONVERSION TABLE.
- **Scope:** The LAYER button is freely assignable only with layers off. Its diagrammed colored sends are retained as evidence but it is reserved for layer switching in enabled modes. Evidence: s6: Xone-K3-User-Guide.txt Latching Layer Options.
- **Scope:** All-controls mode uses embedded soft pickup for pots and faders. This is hardware behavior, separate from Traktor soft takeover. Evidence: s6: Xone-K3-User-Guide.txt Latching Layer Options.
- **Scope:** Only factory hardware map 1 uses these bindings. custom-1/custom-2/custom-3 correspond to hardware map slots 2/3/4; channels, messages, encodings and LED behavior remain unresolved without explicit custom settings. Evidence: s6: Xone-K3-User-Guide.txt UNIT MAPS; s7: Xone-Controller-Editor-Help.txt UNIT MAPS.
- **Scope:** Remote LEDs follow host messages; linked LEDs follow their physical switch. With latching layers off and Remote selected, layer 1/2/3 messages select colors. With layers enabled, displayed color follows the active layer. Evidence: s7: Xone-Controller-Editor-Help.txt LED MODE; s7: Xone-Controller-Editor-Help.txt THE LED COLOUR PALETTE.
- **Conflict:** The guide Specifications lists Note On/Off range 127/1, while Editor Help defaults press/release to 127/0. Do not infer a universal release velocity. Evidence: s6: Xone-K3-User-Guide.txt SPECIFICATIONS; s7: Xone-Controller-Editor-Help.txt ON PRESS / ON RELEASE.

### Allen & Heath Xone:92 Mk2

Complete four documented CC addresses plus documented clock and transport functions. Transmit only; default channel 16 with internal channel 15 option.

- **Scope:** Start/stop-rewind byte sequence and CC94 range not explicitly specified; transport retained as descriptive compound, no invented bytes. Received column documents no supported MIDI input. Evidence: s1: PDF pages 24–25 / MIDI Control Codes / MIDI Implementation Chart.

### Allen & Heath Xone:96

All explicitly numbered controls in official MIDI Control and input-source matrices; input and output kept separate. Default channel 16, configurable 1–16. Rotary selectors send discrete notes, not relative encoder CC.

- **Scope:** Addresses apply to configured channel 1–16; bindings show documented default 16. Evidence: s2: MIDI Channel Setup.

### AlphaTheta CDJ-3000X

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–4.

### AlphaTheta DDJ-GRV6

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–4.

### AlphaTheta Euphonia

Entire MIDI message list normalized: transmit-to-computer controls, discrete selectors and timing clock. Chart status bytes 90/B0 identify channel 1; no receive map is asserted.

- **Scope:** Source only specifies MIDI-IN (to computer). No host-to-device control map or LED-return behavior is established. Evidence: s2: PDF pages 2–4 / MIDI-IN (to computer).

### AlphaTheta OMNIS-DUO

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–3.

### AlphaTheta XDJ-AZ

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–4.

### Denon DJ LC6000 PRIME

All definite scalar send buttons/encoders and receive LED addresses; documented paired jog/pitch messages retained as compound. RGB palette interpretation and scrub pair quarantined.

- **Conflict:** Needle Drop Scrub upper and lower CC both printed as decimal 64 / hex 0x40. Ambiguous pair excluded. Evidence: protocol: PDF p4.
- **Conflict:** Every decimal velocity is one above hexadecimal column (OFF decimal 1 vs hex 0). RGB addresses retained without palette interpretation. Evidence: protocol: PDF pp7–9.
- **Unsupported:** Wheel display needs SysEx; manual gives no wire format. Evidence: protocol: PDF p6.

### Faderfox UC4

Factory setups 1–18: every encoder, push button with an assigned note, green button and all nine faders in each group; feedback uses same assignments. Editable assignments remain configuration dependent.

- **Unsupported:** CCr1 1/127 and CCr2 63/65, high-resolution CC MSB 0–31 plus LSB MSB+32, pitch bend, channel pressure and program change are editable alternatives, not factory bindings. SysEx backup format is not specified. Program-change is outside stage-1 message_type vocabulary. Evidence: protocol: PDF pp9–12.

### Hercules DJControl Inpulse 500

Both decks, mixer and browser numeric scalar addresses, explicit pad modes 1–8 with Shift, palette and meter data. Source anomalies are quarantined; all 14 protocol pages retained. Human channel derived from status nibble, not printed zero-based Channel column.

- **Scope:** Pad row requires recovery of split address cells. Evidence: s2: PDF page 4 / P1-7    Pad 3        Toggle          -      Mode 6.
- **Scope:** Pad row requires recovery of split address cells. Evidence: s2: PDF page 12 / P2-9    Pad 5        Toggle       +Shift    Mode 1.
- **Scope:** Pad row requires recovery of split address cells. Evidence: s2: PDF page 13 / P2-11    Pad 7        Toggle          -      Mode 5.
- **Conflict:** Deck 1 Centre backlight has blank note address; jog touch CC08 overlaps tempo MSB CC08, including Shift. Exclude both ambiguous controls and associated tempo LSB pending manufacturer clarification. Evidence: s2: PDF page 2 / D1-13, D1-15, D1-16.
- **Conflict:** Deck 2 Centre backlight has blank note address; jog touch CC08 overlaps tempo MSB CC08, including Shift. Exclude both ambiguous controls and associated tempo LSB pending manufacturer clarification. Evidence: s2: PDF page 11 / D2-13, D2-15, D2-16.
- **Conflict:** M-3 Deck 1 volume repeats B1 00 for both MSB/LSB and B4 20 for both shifted components; excluded without correction. Evidence: s2: PDF page 5 / M-3.
- **Conflict:** Shifted Deck 1/2 PFL output cells are malformed (4 94 0C and 5 95 0C); excluded. Evidence: s2: PDF page 5 / M-5 and M-7.
- **Conflict:** M-6 Guides output lists 90 01 00 but detail says off/on, and its input duplicates B4 Assistant 90 01. Both input interpretations and Guides output require clarification. Evidence: s2: PDF page 5 M-6; page 8 B4.
- **Conflict:** Deck meter CC40 table includes malformed upper bound 7FF. Individual LED notes normalized; CC meter thresholds remain raw. Evidence: s2: PDF page 7 / M-22.
- **Scope:** Master meter CC40/41 threshold ranges retained in raw evidence; endpoint transcription requires review. Evidence: s2: PDF page 8 / M-29.
- **Conflict:** B2 Load 2 Shift printed channel 4 conflicts with status 95 (human channel 6). Binding excluded until clarified. Evidence: s2: PDF page 8 / B2 Load 2 Shift.
- **Conflict:** Browser Energy LED table prints illegal status 09 for several Deep Sky Blue / Medium spring green rows. These palette values are excluded; other 90 04 rows retained verbatim. Evidence: s2: PDF pages 8–9 / B3 Energy LED color table.
- **Conflict:** Deck 2 mode 4A printed channel 2 conflicts with status 91 (human channel 2, Deck 1). Binding excluded. Evidence: s2: PDF page 11 / P2-4 Mode 4A.

### Novation Launch Control XL 3

Complete DAW physical address diagram; encoder absolute and relative variants, touch events, host position/LED feedback, and feature controls with query/report directions. Standalone surface is configurable.

- **Conflict:** Global MIDI channel CC100 table says hex 00–0e (0–15), and 0Eh (15) channel16. Inconsistent last value excluded. Evidence: protocol: PDF p17.
- **Conflict:** Screen target IDs conflict: configuration stationary 53/temporary54 versus bitmap32/33. Bitmap message/response terminate 7F rather than F7. p10 custom mode ranges overlap Custom8; p17 coherent range retained. Evidence: protocol: PDF pp10,13–15,17.
- **Unsupported:** RGB LED and screen text/bitmap SysEx retained raw; standalone custom mappings are editable, not fixed. Diagram auxiliary CC104 lacks a clear semantic label and is quarantined pending manufacturer clarification. Evidence: protocol: PDF pp7,9,12–15.

### Novation Launchpad Mini MK3

Entire Programmer mode diagram addresses transcribed individually from original PDF; input type and both accepted feedback types retained. No musical scale grid inferred. Full protocol retained for additional DAW/custom mode work.

- **Scope:** DAW Session/Drum/Fader and factory/custom layouts are distinct contexts and are retained in full raw protocol, but not normalized here. SysEx lighting, configuration, scrolling and inquiry require dedicated adapters. Programmer input channel is not asserted from another mode. Evidence: protocol: PDF Programmer mode; DAW mode; SysEx message summary.

### Novation Launchpad Pro MK3

Entire Programmer mode diagram addresses transcribed individually from original PDF; input type and both accepted feedback types retained. No musical scale grid inferred. Full protocol retained for additional DAW/custom mode work.

- **Scope:** DAW Session/Drum/Fader and factory/custom layouts are distinct contexts and are retained in full raw protocol, but not normalized here. SysEx lighting, configuration, scrolling and inquiry require dedicated adapters. Programmer input channel is not asserted from another mode. Evidence: protocol: PDF Programmer mode; DAW mode; SysEx message summary.

### Novation Launchpad X

Entire Programmer mode diagram addresses transcribed individually from original PDF; input type and both accepted feedback types retained. No musical scale grid inferred. Full protocol retained for additional DAW/custom mode work.

- **Scope:** DAW Session/Drum/Fader and factory/custom layouts are distinct contexts and are retained in full raw protocol, but not normalized here. SysEx lighting, configuration, scrolling and inquiry require dedicated adapters. Programmer input channel is not asserted from another mode. Evidence: protocol: PDF Programmer mode; DAW mode; SysEx message summary.

### Pioneer DJ DDJ-FLX10

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–7.

### Pioneer DJ DDJ-FLX4

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Conflict:** Decimal channel reference 6 disagrees with status B4; excluded. Evidence: midi: PDF p.2, table 1, row 32.
- **Conflict:** Decimal channel reference 7 disagrees with status 90; excluded. Evidence: midi: PDF p.2, table 1, row 63.
- **Conflict:** Decimal channel reference 7 disagrees with status 90; excluded. Evidence: midi: PDF p.2, table 1, row 64.
- **Conflict:** Decimal channel reference 7 disagrees with status 91; excluded. Evidence: midi: PDF p.2, table 1, row 65.
- **Conflict:** Decimal channel reference 7 disagrees with status 91; excluded. Evidence: midi: PDF p.2, table 1, row 66.
- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–5.

### Pioneer DJ DDJ-REV5

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 81.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 82.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 83.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 84.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 85.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 86.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 87.
- **Conflict:** Visually verified manufacturer table has displaced NOTE/decimal/pitch-name fields in MIDI-IN status columns for BASS / PAD 3; input excluded, explicit independent MIDI-OUT retained. Evidence: midi: PDF p.2, table 1, row 88.
- **Conflict:** Decimal data-1 24 56 disagrees with hexadecimal 19 39; excluded. Evidence: midi: PDF p.3, table 1, row 38.
- **Conflict:** Decimal data-1 24 56 disagrees with hexadecimal 1A 3A; excluded. Evidence: midi: PDF p.3, table 1, row 39.
- **Conflict:** Decimal data-1 12 44 disagrees with hexadecimal 07 27; excluded. Evidence: midi: PDF p.4, table 1, row 41.
- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–9.

### Pioneer DJ DDJ-REV7

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–7.

### Pioneer DJ DJM-A9

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–6.

### Pioneer DJ DJM-S11

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Conflict:** Decimal channel reference 1 disagrees with status 91; excluded. Evidence: midi: PDF p.2, table 1, row 44.
- **Conflict:** Decimal data-1 2 34 disagrees with hexadecimal 0A 2A; excluded. Evidence: midi: PDF p.4, table 1, row 11.
- **Conflict:** Decimal data-1 4 36 disagrees with hexadecimal 02 22; excluded. Evidence: midi: PDF p.4, table 1, row 12.
- **Conflict:** Decimal channel reference 7 disagrees with status 94; excluded. Evidence: midi: PDF p.4, table 1, row 20.
- **Conflict:** Decimal channel reference 7 disagrees with status 94; excluded. Evidence: midi: PDF p.4, table 1, row 21.
- **Conflict:** Decimal channel reference 7 disagrees with status 94; excluded. Evidence: midi: PDF p.4, table 1, row 22.
- **Conflict:** Decimal channel reference 7 disagrees with status 94; excluded. Evidence: midi: PDF p.4, table 1, row 23.
- **Conflict:** Decimal channel reference 7 disagrees with status 94; excluded. Evidence: midi: PDF p.4, table 1, row 24.
- **Conflict:** Decimal channel reference 7 disagrees with status 94; excluded. Evidence: midi: PDF p.4, table 1, row 25.
- **Conflict:** Decimal channel reference 7 disagrees with status 95; excluded. Evidence: midi: PDF p.4, table 1, row 26.
- **Conflict:** Decimal channel reference 7 disagrees with status 95; excluded. Evidence: midi: PDF p.4, table 1, row 27.
- **Conflict:** Decimal channel reference 7 disagrees with status 95; excluded. Evidence: midi: PDF p.4, table 1, row 28.
- **Conflict:** Decimal channel reference 7 disagrees with status 95; excluded. Evidence: midi: PDF p.4, table 1, row 29.
- **Conflict:** Decimal channel reference 7 disagrees with status 95; excluded. Evidence: midi: PDF p.4, table 1, row 30.
- **Conflict:** Decimal channel reference 7 disagrees with status 95; excluded. Evidence: midi: PDF p.4, table 1, row 31.
- **Conflict:** Decimal channel reference 2 disagrees with status B0; excluded. Evidence: midi: PDF p.6, table 1, row 12.
- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–9.

### Pioneer DJ XDJ-RX3

Numeric manufacturer MIDI chart extraction across all protocol pages. Per-channel expansions follow explicit decimal channel lists. Ordered CC pairs, mode/shift contexts and feedback are retained. No runnable profile or native HID/display/motor emulation claim. See issues for unnormalized rows.

- **Scope:** Complete protocol page text is retained. Footnotes, color palettes, hardware-only rows and channel-allocation explanations remain authoritative raw context; no hardware validation. Table extraction preserves merged-cell context; combined modifier cells are retained literally and do not imply every modifier simultaneously. Evidence: midi: PDF pp.1–5.

## Verification

- Exact coverage of the catalogue’s 26 candidates; no partial or documentation-only candidates promoted.
- Original source hashes, candidate/source association, unique binding identities, channel and data-byte ranges, evidence references and raw artifacts validated.
- 16 focused Python checks cover validation failures and selected source facts: FLX4 base/Shift and paired tempo direction, APC mini channel numbering, LC6000 scrub exclusion, and DJM-A9 channel-strip identity.
- Baseline application run: 846 XCTest tests and 62 Swift Testing tests passed (908 total). The separate UI-test runner failed to initialize macOS automation before running its tests. A follow-up unit-only launch stalled and was cancelled; no additional pass is claimed.
- Selected original charts were visually inspected and an independent extraction review was performed. These checks do not constitute an exhaustive audit of every binding.

## Recommended next step

Adapt the documented subsets into the runtime library, starting with the required channel/mode/encoding representation and tests. Show coverage and exclusions explicitly. Resolve conflicting rows separately from supported controls. The second batch of 21 partial candidates and the 21 documentation-only candidates remain deferred.

See [format and use](README.md), [machine index](index.json), [validation results](validation.json), and [extraction contract](CONTRACT.md).
