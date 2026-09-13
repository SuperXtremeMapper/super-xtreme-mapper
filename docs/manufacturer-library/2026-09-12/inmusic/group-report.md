# inMusic manufacturer documentation collection — 2026-09-12

19 model records across Rane, Denon DJ, Numark and Akai Professional. Selection is practical current/legacy coverage, not a sales ranking. Manufacturer PDF bytes and layout-preserving text are stored beside this report. `manifest.json` records files, direct URLs, SHA256 hashes, classifications and evidence. `evidence-index.json` indexes matching protocol terms by one-based PDF page.

## Current SXM schema fit

The current schema accepts Note/CC and absolute7Bit, relativeTwosComplement or noteGate; layers are base/amber/green and colors red/amber/green. These constraints do not encode full RGB palettes, arbitrary mode/channel behavior, SysEx initialization, paired high-resolution CC, MIDI clock or aftertouch. Ready-for-extraction refers to source documents, not app compatibility.

## Priority for later extraction

1. APC40 mkII: richest complete protocol; explicitly choose operating mode, handle initialization and channel normalization.
2. APC mini mk2: scalar pads, faders and palette feedback; retain USB-port and mode distinctions. Official user guide v1.7 is now included.
3. LC6000: extract transport/pad/relative-encoder subset; defer double-precision controls, wheel screen and inconsistent palette rows.
4. APC64 and MPD218: custom-preset work after acquiring/capturing exact preset assignments.
5. Rane, Numark and standalone Denon models: obtain manufacturer implementation charts or perform authorized hardware capture before profile generation.

## Per-model findings

### Rane FOUR — protocol-gap

[Official product/support page](https://www.rane.com/downloads/). Deck source selects USB A/B MIDI destination; deck controls send MIDI only with source USB A or B. Custom pad mode is software MIDI-mappable.

- [user-manual](https://cdn.inmusicbrands.com/rane/four/FOUR%20-%20User%20Guide%20-%20v1.2.pdf) → `four/FOUR_-_User_Guide_-_v1.2.pdf`; 39 PDF pages.
- Evidence: user-manual, PDF pp. 10, 12, 15 — Features / USB / Custom Pad Sets.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- FOUR jogs are non-motorized. Jog data, screen feedback and hardware effects require separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

### Rane PERFORMER — protocol-gap

[Official product/support page](https://www.rane.com/downloads/). Deck-source USB mode enables MIDI to chosen computer; guide describes on-device parameter encoder and displays without wire addresses.

- [user-manual](https://cdn.inmusicbrands.com/rane/performer/PERFORMER%20-%20User%20Guide%20-%20v1.3.pdf) → `performer/PERFORMER_-_User_Guide_-_v1.3.pdf`; 50 PDF pages.
- Evidence: user-manual, PDF pp. 19, 23 — Features / USB / Custom Pad Sets.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Motorized platter data, screen feedback and hardware effects require separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

### Rane ONE — protocol-gap

[Official product/support page](https://www.rane.com/downloads/?legacy=true). Deck controls send MIDI only when deck source selector is USB A/B.

- [user-manual](https://cdn.inmusicbrands.com/rane/one/RANE-ONE-User-Guide-v1_5.pdf) → `one/RANE-ONE-User-Guide-v1_5.pdf`; 56 PDF pages.
- Evidence: user-manual, PDF pp. 5, 9 — Features / USB / Custom Pad Sets.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Motorized platter data requires separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

### Rane SEVENTY-TWO MKII — protocol-gap

[Official product/support page](https://www.rane.com/downloads/?legacy=true). Up to three custom pad sets via Serato hardware remapping; guide gives user operation, not protocol identifiers.

- [user-manual](https://cdn.inmusicbrands.com/rane/seventy-twoMKII/Seventy-Two_MKII-UserGuide-v1.4.pdf) → `seventy-two-mkii/Seventy-Two_MKII-UserGuide-v1.4.pdf`; 104 PDF pages.
- Evidence: user-manual, PDF pp. 5, 7, 20 — Features / USB / Custom Pad Sets.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Touchscreen feedback, hardware effects and DVS audio behavior require separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

### Rane TWELVE MKII — protocol-gap

[Official product/support page](https://www.rane.com/downloads/?product=Twelve%20MKII). Owner guide recovered from official CDN. USB mode and DVS audio mode are distinct; manufacturer recommends RCA for DVS platter control alongside USB for Browse, Load/Instant Doubles and Hot Cues. Touch Strip switches Needle Drop/Hot Cue modes, and Deck Select chooses software deck.

- [user-manual](https://cdn.inmusicbrands.com/rane/twelveMKII/Twelve_MKII-UserGuide-v1.1.pdf) → `twelve-mkii/Twelve_MKII-UserGuide-v1.1.pdf`; 36 PDF pages.
- Evidence: User Guide v1.1, PDF pp. 4, 7, 8 — Connect and Start DJing / Features / Deck Select.
- No control address/channel or LED receive implementation chart appears in the owner guide.
- DVS platter timecode is audio, outside scalar MIDI profiles. USB motorized-platter precision and screen protocol are not specified; do not infer scalar maps from behavior.

### Denon DJ PRIME 4+ — protocol-gap

[Official product/support page](https://www.denondj.com/downloads.html). Computer Mode sends/receives MIDI; standalone features and control descriptions are operational documentation, not an address map.

- [user-manual](https://cdn.inmusicbrands.com/Software/ENDJ5/PRIME%204%2C%20PRIME%204%2B%2C%20PRIME%202%2C%20PRIME%20GO%2C%20PRIME%20GO%2B%2C%20SC%20LIVE%204%2C%20SC%20LIVE%202%20-%20User%20Guide%20-%20v5.0.0.pdf) → `denon-shared/PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf`; 109 PDF pages.
- Evidence: shared Engine all-in-one user guide v5.0.0, PDF pp. 61 — Control Center > Parameters > Computer Mode.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Separate standalone Engine behavior from computer MIDI mode. No supported HID or proprietary protocol address mapping established.

### Denon DJ PRIME GO+ — protocol-gap

[Official product/support page](https://www.denondj.com/downloads.html). Computer Mode sends/receives MIDI; standalone features and control descriptions are operational documentation, not an address map.

- [user-manual](https://cdn.inmusicbrands.com/Software/ENDJ5/PRIME%204%2C%20PRIME%204%2B%2C%20PRIME%202%2C%20PRIME%20GO%2C%20PRIME%20GO%2B%2C%20SC%20LIVE%204%2C%20SC%20LIVE%202%20-%20User%20Guide%20-%20v5.0.0.pdf) → `denon-shared/PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf`; 109 PDF pages.
- Evidence: shared Engine all-in-one user guide v5.0.0, PDF pp. 63 — Control Center > Parameters > Computer Mode.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Separate standalone Engine behavior from computer MIDI mode. No supported HID or proprietary protocol address mapping established.

### Denon DJ SC LIVE 4 — protocol-gap

[Official product/support page](https://www.denondj.com/downloads.html). Computer Mode sends/receives MIDI; standalone features and control descriptions are operational documentation, not an address map.

- [user-manual](https://cdn.inmusicbrands.com/Software/ENDJ5/PRIME%204%2C%20PRIME%204%2B%2C%20PRIME%202%2C%20PRIME%20GO%2C%20PRIME%20GO%2B%2C%20SC%20LIVE%204%2C%20SC%20LIVE%202%20-%20User%20Guide%20-%20v5.0.0.pdf) → `denon-shared/PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf`; 109 PDF pages.
- Evidence: shared Engine all-in-one user guide v5.0.0, PDF pp. 64 — Control Center > Parameters > Computer Mode.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Separate standalone Engine behavior from computer MIDI mode. No supported HID or proprietary protocol address mapping established.

### Denon DJ SC6000 PRIME — protocol-gap

[Official product/support page](https://www.denondj.com/downloads.html). USB computer connection and Computer Mode send/receive MIDI; no control address implementation chart found.

- [user-manual](https://cdn.inmusicbrands.com/Software/ENDJ5/SC6000%20PRIME%2C%20SC6000M%20PRIME%2C%20SC5000%20PRIME%2C%20SC5000M%20PRIME%20-%20User%20Guide%20-%20v5.0.0.pdf) → `denon-shared/SC6000_PRIME_SC6000M_PRIME_SC5000_PRIME_SC5000M_PRIME_-_User_Guide_-_v5.0.0.pdf`; 66 PDF pages.
- Evidence: shared player guide v5.0.0, PDF pp. 14, 48 — Rear Panel / Control Center > Parameters.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Jog precision and display feedback cannot be inferred from documented USB MIDI transport.

### Denon DJ X1850 PRIME — protocol-gap

[Official product/support page](https://www.denondj.com/downloads.html). Utility MIDI menu separately enables Clock Send and Active Send per USB/DIN destination. Start/Stop button sends MIDI transport.

- [user-manual](https://cdn.inmusicbrands.com/denondj/X1850Prime/X1850 PRIME - User Guide - v1.4.pdf) → `x1850/X1850_PRIME_-_User_Guide_-_v1.4.pdf`; 76 PDF pages.
- Evidence: user-manual v1.4, PDF pp. 9, 10, 16 — MIDI Start/Stop; MIDI Output; Utility > MIDI.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Clock and transport are system messages, outside scalar Note/CC profile mapping.

### Denon DJ LC6000 PRIME — ready-for-extraction

[Official product/support page](https://www.denondj.com/downloads.html). Channel 1 Note inputs include Play 0x01, Cue 0x02, pads 0x20–0x27. Relative CC Auto Loop Size 0x03 and Select 0x06. LED note receive map includes dim/full states and pad palette.

- [user-manual](https://cdn.inmusicbrands.com/engine/LC6000%20PRIME%20-%20User%20Guide%20-%20v1.4.pdf) → `lc6000/LC6000_PRIME_-_User_Guide_-_v1.4.pdf`; 56 PDF pages.
- [midi-protocol](https://cdn.inmusicbrands.com/denondj/lc6000/LC6000-PRIME-MIDI-Specification-v1.0.pdf) → `lc6000/LC6000-PRIME-MIDI-Specification-v1.0.pdf`; 9 PDF pages.
- Evidence: MIDI Specification v1.0, PDF pp. 2, 3 — Inbound Send Messages.
- Evidence: MIDI Specification v1.0, PDF pp. 4 — Double Precision Control.
- Evidence: MIDI Specification v1.0, PDF pp. 5, 6, 7, 8, 9 — Outbound Receive Messages / Color Table.
- Ready only to extract well-defined scalar subset; no claim of implemented readiness.
- Jog uses double precision CC 0x37/0x36; pitch 0x08/0x28; do not collapse paired values into independent scalar controls.
- Needle Drop double-precision table repeats CC 0x40 for both bytes: unresolved source ambiguity.
- Wheel display explicitly requires SysEx; not available via manual MIDI mapping (p6).
- Color table p7–9 decimal column is offset from hexadecimal (e.g. 1 vs 0x00 OFF); requires source/hardware resolution before palette import.

### Numark NS4FX — protocol-gap

[Official product/support page](https://www.numark.com/product/ns4fx). USB sends MIDI data to software. Pad modes and deck Layer functions described, with no address implementation.

- [user-manual](https://www.numark.com/images/product_downloads/NS4_FX_-_User_Guide_-_v1.3.pdf) → `ns4fx/NS4_FX_-_User_Guide_-_v1.3.pdf`; 44 PDF pages.
- Evidence: user-manual, PDF pp. 7 — Rear Panel USB / Top Panel Input Selector.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

### Numark Mixtrack Platinum FX — protocol-gap

[Official product/support page](https://www.numark.com/product/mixtrack-platinum-fx). USB MIDI documented; capacitive jog and display operation described without receive protocol.

- [user-manual](https://cdn.inmusicbrands.com/Numark/vAC9uYWEnT/mtplfx/MixTrackPlatinumFX-UserGuide-v1.2.pdf) → `mixtrack-platinum-fx/MixTrackPlatinumFX-UserGuide-v1.2.pdf`; 32 PDF pages.
- Evidence: user-manual, PDF pp. 5 — Rear Panel USB / Top Panel Input Selector.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

### Numark Mixtrack Pro FX — protocol-gap

[Official product/support page](https://www.numark.com/product/mixtrack-pro-fx). USB MIDI documented; pad modes described without address implementation.

- [user-manual](https://cdn.inmusicbrands.com/Numark/vAC9uYWEnT/mtprfx/MixTrackProFX-UserGuide-v1.2.pdf) → `mixtrack-pro-fx/MixTrackProFX-UserGuide-v1.2.pdf`; 28 PDF pages.
- Evidence: user-manual, PDF pp. 5 — Rear Panel USB / Top Panel Input Selector.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

### Numark NS6II — protocol-gap

[Official product/support page](https://www.numark.com/product/ns6ii). Channel controls send MIDI only when Input Selector is PC; legacy user guide and quickstart both acquired.

- [user-manual](https://www.numark.com/images/product_downloads/NS6II_-_Quickstart_Guide_-_v1.1.pdf) → `ns6ii/NS6II_-_Quickstart_Guide_-_v1.1.pdf`; 52 PDF pages.
- [user-manual](https://www.numark.com/images/product_downloads/NS6II-UserGuide-v1.1.pdf) → `ns6ii/NS6II-UserGuide-v1.1.pdf`; 76 PDF pages.
- Evidence: user-manual, PDF pp. 7 — Rear Panel USB / Top Panel Input Selector.
- No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.
- Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

### Akai Professional APC40 mkII — ready-for-extraction

[Official product/support page](https://www.akaipro.com/downloads-and-support/downloads/). Protocol provides input Note IDs, absolute CCs, relative controls, LED/ring receive tables. Channel fields are zero-based; track faders use CC 0x07 on channels 0–7. Cue Level CC 0x2F and Tempo CC 0x0D have relative encoding +1..63 / -64..-1 as 64..127.

- [midi-protocol](https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40Mk2_Communications_Protocol_v1.2.pdf) → `apc40-mkii/APC40Mk2_Communications_Protocol_v1.2.pdf`; 38 PDF pages.
- [user-manual](https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40%20mkII%20-%20User%20Guide%20-%20v1.0.pdf) → `apc40-mkii/APC40_mkII_User_Guide_v1.0.pdf`; 28 PDF pages.
- Evidence: Communications Protocol v1.2, PDF pp. 10, 11, 12 — Generic / Ableton / Alternate modes.
- Evidence: Communications Protocol v1.2, PDF pp. 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 — LED receive, palettes and rings.
- Evidence: Communications Protocol v1.2, PDF pp. 29, 30, 31, 32, 33, 34, 35, 36, 37 — Inbound Note / absolute and relative CC.
- Mode 0 starts by default; track-selection changes banks without sending selection MIDI, and some buttons toggle. Modes 1/2 require SysEx introduction and have different host LED ownership.
- Channel normalization must preserve zero-based source indexing. Ring style feedback and initialization exceed a simple per-control scalar mapping.
- Source contains duplicated/misaligned labels and Cue Level in both absolute and relative tables; reconcile before import.

### Akai Professional APC mini mk2 — ready-for-extraction

[Official product/support page](https://www.akaipro.com/downloads-and-support/downloads/). Protocol maps clip pads 0x00–0x3F, track buttons 0x64–0x6B, scenes 0x70–0x77 and Shift 0x7A. Absolute faders CC 0x30–0x38 channel 0 port 0. LED Note-On channel specifies brightness/pulse/blink, velocity specifies palette. Owner guide v1.7 documents Ableton Port 2 input setup and editable Note Mode scale/octave/layout.

- [midi-protocol](https://cdn.inmusicbrands.com/akai/attachments/APC%20mini%20mk2%20-%20Communication%20Protocol%20-%20v1.0.pdf) → `apc-mini-mk2/APC_mini_mk2_-_Communication_Protocol_-_v1.0.pdf`; 16 PDF pages.
- [user-manual](https://cdn.inmusicbrands.com/akai/apc-mini-mkii/APC%20mini%20mk2%20-%20User%20Guide%20-%20v1.7.pdf) → `apc-mini-mk2/APC_mini_mk2_User_Guide_v1.7.pdf`; 76 PDF pages.
- Evidence: Communication Protocol v1.0, PDF pp. 1, 2, 3, 4, 5, 6 — LED messages, behavior, color palette.
- Evidence: Communication Protocol v1.0, PDF pp. 9, 10, 13, 14 — SysEx RGB / initialization.
- Evidence: Communication Protocol v1.0, PDF pp. 15, 16 — Control Mapping.
- Evidence: User Guide v1.7, PDF pp. 4, 12, 13, 14, 15, 16 — Setup / Drum Mode / Note Mode configuration.
- Ready to extract scalar subset only. Official user guide v1.7 recovered after earlier candidate path failures.
- Session port 0 differs from Drum mode channel 09 and Note mode port 1/channel 00. Do not merge port/channel addresses.
- RGB behavior channel is not necessarily input channel. Full custom RGB and initialization use SysEx. Source has literal typos (00x4F) and initialization response length ambiguity.

### Akai Professional APC64 — partial

[Official product/support page](https://www.akaipro.com/downloads-and-support/downloads/). Custom pad notes/channels and fader CCs are user editable. Chord mode channel 1 and drum mode channel 16 in Ableton; global drum notes configurable.

- [user-manual](https://cdn.inmusicbrands.com/akai/APC64/APC64%20-%20User%20Guide%20-%20v1.0.pdf) → `apc64/APC64_-_User_Guide_-_v1.0.pdf`; 66 PDF pages.
- Evidence: user-manual v1.0, PDF pp. 29, 47, 50, 52, 57, 58 — Drum/Chord, Global Menu, Custom Mode / Project Editor.
- No complete fixed MIDI map or host LED receive protocol acquired. Custom preset must be captured alongside profile.
- Faders support Single (1 CC) or Double (2 CC); manual does not establish double-message numeric interpretation. Pads can send poly aftertouch, outside scalar Note/CC.
- Editor color settings document local on/off behavior, not proof of host LED receive messages.

### Akai Professional MPD218 — partial

[Official product/support page](https://www.akaipro.com/downloads-and-support/downloads/). Pads/knobs have three banks and 16 programs. Knobs send continuous-controller data. NR Config and Prog Select suppress normal pad MIDI while held.

- [user-manual](https://cdn.inmusicbrands.com/akai/attachments/MPD218/MPD218-UserGuide-v1.0.pdf) → `mpd218/MPD218-UserGuide-v1.0.pdf`; 20 PDF pages.
- Evidence: user-manual v1.0, PDF pp. 3, 4, 5 — Features / Preset Documentation reference.
- No preset documentation or editor guide acquired; factory note/CC/channel assignments unresolved.
- Pressure-sensitive pads and MIDI clock repeat cannot be reduced to Note/CC-only semantics. No LED receive protocol established.

## Retrieval limitations

No third-party hosted PDF was admitted. TWELVE MKII and APC mini mk2 user guides were recovered after targeted retry with refined official-site searches; TWELVE link was also confirmed in the manufacturer browser downloads page. MPD218 preset/editor documentation remains unacquired. The exact failed candidate URLs and HTTP statuses are in the manifest. HTTP 404 from a guessed legacy CDN path is a failed retrieval, not proof that a manual never existed. Rane and Akai modern pages returned navigation shells to the HTTP client; search-discovered official CDN documents supplied most usable files.

All classifications describe documentation sufficiency. Nothing in this collection is a tested or implemented SXM profile. HID, SysEx, system clock, aftertouch, paired-CC and motor/display behavior remain outside an ordinary scalar Note/CC profile unless separately implemented and verified.
