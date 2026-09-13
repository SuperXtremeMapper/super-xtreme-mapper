# Full manufacturer/model source index

[Read the assessment report](REPORT.md) · [CSV](catalogue.csv) · [JSON](catalogue.json)

Grades refer to documentation, not implemented or hardware-tested support. Each entry links original manufacturer documents and archived copies. Failed attempts are retained in the detailed manifests, not listed as downloaded files.

## Akai Professional

### APC mini mk2

**ready-for-extraction** · No profile added by this collection

Protocol maps clip pads 0x00–0x3F, track buttons 0x64–0x6B, scenes 0x70–0x77 and Shift 0x7A. Absolute faders CC 0x30–0x38 channel 0 port 0. LED Note-On channel specifies brightness/pulse/blink, velocity specifies palette. Owner guide v1.7 documents Ableton Port 2 input setup and editable Note Mode scale/octave/layout.

Remaining work: Ready to extract scalar subset only. Official user guide v1.7 recovered after earlier candidate path failures.; Session port 0 differs from Drum mode channel 09 and Note mode port 1/channel 00. Do not merge port/channel addresses.; RGB behavior channel is not necessarily input channel. Full custom RGB and initialization use SysEx. Source has literal typos (00x4F) and initialization response length ambiguity.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [APC_mini_mk2_-_Communication_Protocol_-_v1.0.pdf](inmusic/apc-mini-mk2/APC_mini_mk2_-_Communication_Protocol_-_v1.0.pdf) · 16 pages · [manufacturer source](https://cdn.inmusicbrands.com/akai/attachments/APC%20mini%20mk2%20-%20Communication%20Protocol%20-%20v1.0.pdf)
- [APC_mini_mk2_User_Guide_v1.7.pdf](inmusic/apc-mini-mk2/APC_mini_mk2_User_Guide_v1.7.pdf) · 76 pages · [manufacturer source](https://cdn.inmusicbrands.com/akai/apc-mini-mkii/APC%20mini%20mk2%20-%20User%20Guide%20-%20v1.7.pdf)

### APC40 mkII

**ready-for-extraction** · No profile added by this collection

Protocol provides input Note IDs, absolute CCs, relative controls, LED/ring receive tables. Channel fields are zero-based; track faders use CC 0x07 on channels 0–7. Cue Level CC 0x2F and Tempo CC 0x0D have relative encoding +1..63 / -64..-1 as 64..127.

Remaining work: Mode 0 starts by default; track-selection changes banks without sending selection MIDI, and some buttons toggle. Modes 1/2 require SysEx introduction and have different host LED ownership.; Channel normalization must preserve zero-based source indexing. Ring style feedback and initialization exceed a simple per-control scalar mapping.; Source contains duplicated/misaligned labels and Cue Level in both absolute and relative tables; reconcile before import.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [APC40Mk2_Communications_Protocol_v1.2.pdf](inmusic/apc40-mkii/APC40Mk2_Communications_Protocol_v1.2.pdf) · 38 pages · [manufacturer source](https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40Mk2_Communications_Protocol_v1.2.pdf)
- [APC40_mkII_User_Guide_v1.0.pdf](inmusic/apc40-mkii/APC40_mkII_User_Guide_v1.0.pdf) · 28 pages · [manufacturer source](https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40%20mkII%20-%20User%20Guide%20-%20v1.0.pdf)

### APC64

**partial** · No profile added by this collection

Custom pad notes/channels and fader CCs are user editable. Chord mode channel 1 and drum mode channel 16 in Ableton; global drum notes configurable.

Remaining work: No complete fixed MIDI map or host LED receive protocol acquired. Custom preset must be captured alongside profile.; Faders support Single (1 CC) or Double (2 CC); manual does not establish double-message numeric interpretation. Pads can send poly aftertouch, outside scalar Note/CC.; Editor color settings document local on/off behavior, not proof of host LED receive messages.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [APC64_-_User_Guide_-_v1.0.pdf](inmusic/apc64/APC64_-_User_Guide_-_v1.0.pdf) · 66 pages · [manufacturer source](https://cdn.inmusicbrands.com/akai/APC64/APC64%20-%20User%20Guide%20-%20v1.0.pdf)

### MPD218

**partial** · No profile added by this collection

Pads/knobs have three banks and 16 programs. Knobs send continuous-controller data. NR Config and Prog Select suppress normal pad MIDI while held.

Remaining work: No preset documentation or editor guide acquired; factory note/CC/channel assignments unresolved.; Pressure-sensitive pads and MIDI clock repeat cannot be reduced to Note/CC-only semantics. No LED receive protocol established.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [MPD218-UserGuide-v1.0.pdf](inmusic/mpd218/MPD218-UserGuide-v1.0.pdf) · 20 pages · [manufacturer source](https://cdn.inmusicbrands.com/akai/attachments/MPD218/MPD218-UserGuide-v1.0.pdf)

## Allen & Heath

### Xone:92 Mk2

**ready-for-extraction** · No profile added by this collection

Small, explicit transmit-only implementation: filters CC12/13, crossfader CC92, optional internally configured data CC94. Clock/start-stop exceed current simple Note/CC scope.

[Detailed source manifest](ni-hercules-ah/xone-92-mk2/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/xone-92-mk2/manual.pdf) · [manufacturer source](https://www.allen-heath.com/content/uploads/2024/10/Xone92-Mk2-User-Guide.pdf)

### Xone:96

**ready-for-extraction** · No profile added by this collection

PDF endpoints returned 403, but official full HTML user guide and MIDI implementation tables downloaded successfully. Explicit numeric send/receive matrix supports extraction.

[Detailed source manifest](ni-hercules-ah/xone-96/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.html](ni-hercules-ah/xone-96/manual.html) · [manufacturer source](https://support.allen-heath.com/hc/en-gb/articles/43053562464017-Xone-96-User-Guide)
- [midi.html](ni-hercules-ah/xone-96/midi.html) · [manufacturer source](https://support.allen-heath.com/hc/en-gb/articles/43084536824849-Xone-96-MIDI-Implementation)

### XONE:K1

**ready-for-extraction** · Existing SXM profile

Original official PDF already archived; separate extracted text added here for indexing.

[Detailed source manifest](ni-hercules-ah/xone-k1/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [XoneK1_UG_AP9694_2.pdf](../../../XtremeMapping/docs/controllers/xone-k1/sources/XoneK1_UG_AP9694_2.pdf) · 16 pages · [manufacturer source](https://www.allen-heath.com/content/uploads/2023/07/XoneK1_UG_AP9694_2.pdf)

### XONE:K2

**ready-for-extraction** · Existing SXM profile

Original official PDF already archived; separate extracted text added here for indexing.

[Detailed source manifest](ni-hercules-ah/xone-k2/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [XoneK2_UG_AP8509_3.pdf](../../../XtremeMapping/docs/controllers/xone-k2/sources/XoneK2_UG_AP8509_3.pdf) · 30 pages · [manufacturer source](https://www.allen-heath.com/content/uploads/2023/06/XoneK2_UG_AP8509_3.pdf)

### XONE:K3

**ready-for-extraction** · Existing SXM profile

Factory Map(1) matches K2; per-control custom map and global channel choices require separate profile assumptions.

[Detailed source manifest](ni-hercules-ah/xone-k3/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [midi-send-01.png](../../../XtremeMapping/docs/controllers/xone-k3/sources/midi-send-01.png) · [manufacturer source](https://support.allen-heath.com/hc/article_attachments/39744783045009)
- [midi-send-02.png](../../../XtremeMapping/docs/controllers/xone-k3/sources/midi-send-02.png) · [manufacturer source](https://support.allen-heath.com/hc/article_attachments/39744774054673)
- [midi-send-03.png](../../../XtremeMapping/docs/controllers/xone-k3/sources/midi-send-03.png) · [manufacturer source](https://support.allen-heath.com/hc/article_attachments/39744783047313)
- [midi-return-02.png](../../../XtremeMapping/docs/controllers/xone-k3/sources/midi-return-02.png) · [manufacturer source](https://support.allen-heath.com/hc/article_attachments/39744783050257)
- [midi-return-01.png](../../../XtremeMapping/docs/controllers/xone-k3/sources/midi-return-01.png) · [manufacturer source](https://support.allen-heath.com/hc/article_attachments/39744774056977)
- [Xone-K3-User-Guide.txt](../../../XtremeMapping/docs/controllers/xone-k3/sources/Xone-K3-User-Guide.txt) · [manufacturer source](https://support.allen-heath.com/hc/en-gb/articles/39744774067985-Xone-K3-User-Guide)
- [Xone-Controller-Editor-Help.txt](../../../XtremeMapping/docs/controllers/xone-k3/sources/Xone-Controller-Editor-Help.txt) · [manufacturer source](https://support.allen-heath.com/hc/en-gb/articles/39744832920081-Xone-Controller-Editor-Help)

### Xone:PX5

**partial** · No profile added by this collection

Extensive MIDI controls documented, but note names use C-2 in mapping while conversion table maps zero to C-1. Do not silently normalize conflicting octaves. CC portion is extractable; resolve Note numbers and return-value details first.

[Detailed source manifest](ni-hercules-ah/xone-px5/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/xone-px5/manual.pdf) · [manufacturer source](https://www.allen-heath.com/content/uploads/2023/06/AP10733_2_XONE_PX5_USER_GUIDE.pdf)
- [midi.html](ni-hercules-ah/xone-px5/midi.html) · [manufacturer source](https://support.allen-heath.com/hc/en-gb/articles/43523536283409-Xone-PX5-MIDI-Control)

## AlphaTheta

### CDJ-3000X

**ready-for-extraction** · No profile added by this collection

MIDI chart pp1–2 diagrams; pp3–4 transmit Note/CC controls and hardware-only exclusions. Owner p98 MIDI/HID DJ-software operation; p105 MIDI channel setting.

Remaining work: Useful transport/input subset. Chart does not supply a complete host screen/LED receive protocol. Jog values encode signed speed around64, distinct from ordinary relative encoder increments. MIDI and HID operation must remain separate. Owner p99: enter SOURCE > SOFTWARE CONTROL; loading a track from another device exits control mode.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/cdj-3000x/owner-manual.pdf) · 122 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/dj-players/CDJ-3000X/CDJ-3000X_DRI1956C_EN_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/cdj-3000x/midi-implementation.pdf) · 4 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-3000X/CDJ3000X_MIDI_Message_List_En.pdf)

### DDJ-GRV6

**ready-for-extraction** · No profile added by this collection

MIDI chart pp.1–4: diagram, channel allocation, transport, mixer, Groove Circuit/FX and pad tables.

Remaining work: Strong documentation; arbitrary deck/Shift/mode routing, paired CCs and colored feedback need adaptation. Browse relative values are explicitly documented. Do not interpret hardware-specific function labels as Traktor assignments.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/ddj-grv6/owner-manual.pdf) · 174 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DDJ_GRV6_DRI1927A_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/ddj-grv6/midi-implementation.pdf) · 4 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-GRV6/DDJ-GRV6_MIDI_Message_List_E1.pdf)

### Euphonia

**ready-for-extraction** · No profile added by this collection

Existing manufacturer owner manual and MIDI message list archived in previous work. Profile implementation deferred by user priority.

Remaining work: Re-audit exact transmit/receive scope and extract per-control evidence before implementing; this pass reuses archive, not new hardware verification.

[Detailed source manifest](../../../XtremeMapping/docs/controllers/euphonia/source-manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [euphonia_DRI1891A_manual.pdf](../../../XtremeMapping/docs/controllers/euphonia/sources/euphonia_DRI1891A_manual.pdf) · 66 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/euphonia_DRI1891A_manual.pdf)
- [euphonia_MIDI_Message_List_E10.pdf](../../../XtremeMapping/docs/controllers/euphonia/sources/euphonia_MIDI_Message_List_E10.pdf) · 4 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-mixers/euphonia/euphonia_MIDI_Message_List_E10.pdf)

### OMNIS-DUO

**ready-for-extraction** · No profile added by this collection

MIDI chart p1 diagram; pp2–3 channels, deck/mixer/browse and receive meter/indicator tables.

Remaining work: Suitable documented subset; paired tempo CCs, relative/speed jog behavior and per-deck channels need faithful encoding. Standalone operation does not imply every function can be remotely driven.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/omnis-duo/owner-manual.pdf) · 134 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/OMNIS-DUO/OMNIS_DUO_DRI1882B_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/omnis-duo/midi-implementation.pdf) · 3 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/OMNIS-DUO/OMNIS-DUO_MIDI_Message_List_E1.pdf)

### SLAB

**partial** · No profile added by this collection

MIDI chart pp1–4: control/pad/touch-strip mappings, page modes, aftertouch and colored receive. PDF p1 E1 encoder-mode row visually reviewed.

Remaining work: Unresolved source conflict: E1 decimal MIDI channel1 but status96 (channel7). Dial/encoder turn values are CW01/CCW41, not two’s-complement. Paired touch strip, poly aftertouch, arbitrary pages and RGB feedback need adaptation; quarantine contradictory row. Both unshifted note16 and shifted note17 show the E1 contradiction. Conservatively partial because this mode-control ambiguity remains, though other isolated rows are extractable.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/slab/owner-manual.pdf) · 43 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/music-production/SLAB/SLAB_DRI1975A_EN_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/slab/midi-implementation.pdf) · 4 pages · [manufacturer source](https://downloads.support.alphatheta.com/midi-mapping/music-production/SLAB/SLAB_MIDI_Message_List_en.pdf)

### XDJ-AZ

**ready-for-extraction** · No profile added by this collection

MIDI chart pp.1–4: channel matrix and send/receive; hardware-only entries; p4 jog LED/display-related values.

Remaining work: Standalone controls are not all MIDI controls. Preserve hardware-only exclusions, mode routing and paired CCs; p4 angle-related pairs are not independent 7-bit knobs.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/xdj-az/owner-manual.pdf) · 159 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/XDJ-AZ/XDJ-AZ_DRI1936C_manual_EN.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/xdj-az/midi-implementation.pdf) · 4 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-AZ/XDJ-AZ_MIDI_Message_List_E1.pdf)

## DJ TechTools

### Midi Fighter 3D

**partial** · No profile added by this collection

User/MIDI guide pp.2-8,12; bank tables pp.14-17; motion chart p.18 visually inspected, animation p.19.

Remaining work: Source p.18 Edge Tilt table visibly contradicts p.7 CC0-7 prose (table contains note names and40/39/38/43). Channel nomenclature must be verified; quarantine conflicting motion rows rather than guess.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-and-midi-guide.pdf](performance/midi-fighter-3d/owner-and-midi-guide.pdf) · 19 pages · [manufacturer source](https://drive.google.com/uc?export=download&id=0B-QvIds_FsH3OHhuZlpzVkM2QjQ)

### Midi Fighter Twister

**partial** · No profile added by this collection

User/MIDI guide pp.2-8,14-16; default bank tables pp.17-24 and animation/color appendices.

Remaining work: Mixed channel numbering conventions across source sections require normalization by section and hardware verification; some earlier text still refers to four banks. Ready subset: default encoder/switch address tables with explicit zero-based convention.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-and-midi-guide.pdf](performance/midi-fighter-twister/owner-and-midi-guide.pdf) · 29 pages · [manufacturer source](https://drive.google.com/uc?export=download&id=0B-QvIds_FsH3Z0ZLT041VnZfOTA)

## Denon DJ

### LC6000 PRIME

**ready-for-extraction** · No profile added by this collection

Channel 1 Note inputs include Play 0x01, Cue 0x02, pads 0x20–0x27. Relative CC Auto Loop Size 0x03 and Select 0x06. LED note receive map includes dim/full states and pad palette.

Remaining work: Ready only to extract well-defined scalar subset; no claim of implemented readiness.; Jog uses double precision CC 0x37/0x36; pitch 0x08/0x28; do not collapse paired values into independent scalar controls.; Needle Drop double-precision table repeats CC 0x40 for both bytes: unresolved source ambiguity.; Wheel display explicitly requires SysEx; not available via manual MIDI mapping (p6).; Color table p7–9 decimal column is offset from hexadecimal (e.g. 1 vs 0x00 OFF); requires source/hardware resolution before palette import.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [LC6000_PRIME_-_User_Guide_-_v1.4.pdf](inmusic/lc6000/LC6000_PRIME_-_User_Guide_-_v1.4.pdf) · 56 pages · [manufacturer source](https://cdn.inmusicbrands.com/engine/LC6000%20PRIME%20-%20User%20Guide%20-%20v1.4.pdf)
- [LC6000-PRIME-MIDI-Specification-v1.0.pdf](inmusic/lc6000/LC6000-PRIME-MIDI-Specification-v1.0.pdf) · 9 pages · [manufacturer source](https://cdn.inmusicbrands.com/denondj/lc6000/LC6000-PRIME-MIDI-Specification-v1.0.pdf)

### PRIME 4+

**protocol-gap** · No profile added by this collection

Computer Mode sends/receives MIDI; standalone features and control descriptions are operational documentation, not an address map.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Separate standalone Engine behavior from computer MIDI mode. No supported HID or proprietary protocol address mapping established.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf](inmusic/denon-shared/PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf) · 109 pages · [manufacturer source](https://cdn.inmusicbrands.com/Software/ENDJ5/PRIME%204%2C%20PRIME%204%2B%2C%20PRIME%202%2C%20PRIME%20GO%2C%20PRIME%20GO%2B%2C%20SC%20LIVE%204%2C%20SC%20LIVE%202%20-%20User%20Guide%20-%20v5.0.0.pdf)

### PRIME GO+

**protocol-gap** · No profile added by this collection

Computer Mode sends/receives MIDI; standalone features and control descriptions are operational documentation, not an address map.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Separate standalone Engine behavior from computer MIDI mode. No supported HID or proprietary protocol address mapping established.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf](inmusic/denon-shared/PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf) · 109 pages · [manufacturer source](https://cdn.inmusicbrands.com/Software/ENDJ5/PRIME%204%2C%20PRIME%204%2B%2C%20PRIME%202%2C%20PRIME%20GO%2C%20PRIME%20GO%2B%2C%20SC%20LIVE%204%2C%20SC%20LIVE%202%20-%20User%20Guide%20-%20v5.0.0.pdf)

### SC LIVE 4

**protocol-gap** · No profile added by this collection

Computer Mode sends/receives MIDI; standalone features and control descriptions are operational documentation, not an address map.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Separate standalone Engine behavior from computer MIDI mode. No supported HID or proprietary protocol address mapping established.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf](inmusic/denon-shared/PRIME_4_PRIME_4_PRIME_2_PRIME_GO_PRIME_GO_SC_LIVE_4_SC_LIVE_2_-_User_Guide_-_v5.0.0.pdf) · 109 pages · [manufacturer source](https://cdn.inmusicbrands.com/Software/ENDJ5/PRIME%204%2C%20PRIME%204%2B%2C%20PRIME%202%2C%20PRIME%20GO%2C%20PRIME%20GO%2B%2C%20SC%20LIVE%204%2C%20SC%20LIVE%202%20-%20User%20Guide%20-%20v5.0.0.pdf)

### SC6000 PRIME

**protocol-gap** · No profile added by this collection

USB computer connection and Computer Mode send/receive MIDI; no control address implementation chart found.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Jog precision and display feedback cannot be inferred from documented USB MIDI transport.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [SC6000_PRIME_SC6000M_PRIME_SC5000_PRIME_SC5000M_PRIME_-_User_Guide_-_v5.0.0.pdf](inmusic/denon-shared/SC6000_PRIME_SC6000M_PRIME_SC5000_PRIME_SC5000M_PRIME_-_User_Guide_-_v5.0.0.pdf) · 66 pages · [manufacturer source](https://cdn.inmusicbrands.com/Software/ENDJ5/SC6000%20PRIME%2C%20SC6000M%20PRIME%2C%20SC5000%20PRIME%2C%20SC5000M%20PRIME%20-%20User%20Guide%20-%20v5.0.0.pdf)

### X1850 PRIME

**protocol-gap** · No profile added by this collection

Utility MIDI menu separately enables Clock Send and Active Send per USB/DIN destination. Start/Stop button sends MIDI transport.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Clock and transport are system messages, outside scalar Note/CC profile mapping.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [X1850_PRIME_-_User_Guide_-_v1.4.pdf](inmusic/x1850/X1850_PRIME_-_User_Guide_-_v1.4.pdf) · 76 pages · [manufacturer source](https://cdn.inmusicbrands.com/denondj/X1850Prime/X1850 PRIME - User Guide - v1.4.pdf)

## Faderfox

### EC4

**partial** · No profile added by this collection

Owner/MIDI manual pp.6-7 feedback and special commands; pp.11-13 command/channel/address modes; p.15 factory table visually inspected.

Remaining work: Original p.15 factory table extends beyond right page edge (visually verified), so do not silently repair clipped values. Special fixed SysEx description not linked by discovered current page. Ready subset: readable factory group ranges; full map requires resolving clipped table and special controls.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-and-midi-guide.pdf](performance/faderfox-ec4/owner-and-midi-guide.pdf) · 16 pages · [manufacturer source](https://www.faderfox.de/PDF/EC4%20Manual%20V03.PDF)

### UC4

**ready-for-extraction** · No profile added by this collection

Owner/MIDI manual pp.6,8-10 control modes, feedback and command configuration; p.13 factory tables visually inspected.

Remaining work: Source-ready for explicit generic factory setup subset. More than3 groups, special setups and configurable per-control channels require schema choices. CCr2 is binary-offset rather than twos-complement; highres CC/pitchbend/pressure are unsupported by current app.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-and-midi-guide.pdf](performance/faderfox-uc4/owner-and-midi-guide.pdf) · 16 pages · [manufacturer source](https://www.faderfox.de/PDF/UC4%20Manual%20V03.PDF)

## Hercules

### DJControl Inpulse 200 MK2

**partial** · No profile added by this collection

Official user manual/control descriptions archived; no complete manufacturer wire-address/LED chart found in the retrieved support resources. Software action mappings do not prove Note/CC values.

[Detailed source manifest](ni-hercules-ah/djcontrolinpulse200mk2/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [support.html](ni-hercules-ah/djcontrolinpulse200mk2/support.html) · [manufacturer source](https://support.hercules.com/en/product/djcontrolinpulse200mk2-en/)
- [manual.pdf](ni-hercules-ah/djcontrolinpulse200mk2/manual.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_200_MK2/DJControl_Inpulse_200_MK2_User_Manual_-_21L.pdf)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulse200mk2/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-200-mk2-2023-mapping-and-manual/)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulse200mk2/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-200-mk2-2023-manuel-et-controles-midi/)

### DJControl Inpulse 200 MK3

**partial** · No profile added by this collection

Official user manual/control descriptions archived; no complete manufacturer wire-address/LED chart found in the retrieved support resources. Software action mappings do not prove Note/CC values. Added as a current-generation supplement discovered on current official support; retained MK2 as explicitly requested legacy model.

[Detailed source manifest](ni-hercules-ah/djcontrolinpulse200mk3/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [support.html](ni-hercules-ah/djcontrolinpulse200mk3/support.html) · [manufacturer source](https://support.hercules.com/en/product/djcontrolinpulse200mk3-en/)
- [manual.pdf](ni-hercules-ah/djcontrolinpulse200mk3/manual.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_200_MK3/DJControl_Inpulse_200_MK3_User_Manual_-_21_Languages.pdf)

### DJControl Inpulse 300 MK2

**partial** · No profile added by this collection

Official user manual/control descriptions archived; no complete manufacturer wire-address/LED chart found in the retrieved support resources. Software action mappings do not prove Note/CC values.

[Detailed source manifest](ni-hercules-ah/djcontrolinpulse300mk2/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [support.html](ni-hercules-ah/djcontrolinpulse300mk2/support.html) · [manufacturer source](https://support.hercules.com/en/product/djcontrolinpulse300mk2-en/)
- [manual.pdf](ni-hercules-ah/djcontrolinpulse300mk2/manual.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_300_MK2/HERCULES_DJC_INPULSE_300MK2_-_USER_MANUAL_21_LANGUAGES.pdf)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulse300mk2/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-300-mk2-2023-mapping-and-manual/)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulse300mk2/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-300-mk2-2023-manuel-et-controles-midi/)

### DJControl Inpulse 500

**ready-for-extraction** · No profile added by this collection

Detailed official 14-page MIDI chart has Note/CC bytes, Shift and pad modes, relative encoders, paired MSB/LSB tempo and LED colors. Ready means extraction may begin; source anomalies require a review queue.

[Detailed source manifest](ni-hercules-ah/djcontrolinpulse500/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [support.html](ni-hercules-ah/djcontrolinpulse500/support.html) · [manufacturer source](https://support.hercules.com/en/product/djcontrolinpulse500-en/)
- [midi.pdf](ni-hercules-ah/djcontrolinpulse500/midi.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse500/DJControlInpulse500_MIDI_Commands.pdf)
- [manual.pdf](ni-hercules-ah/djcontrolinpulse500/manual.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse500/DJControl_Inpulse_500_User_Manual.pdf)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulse500/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-500/)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulse500/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-500-manuel-et-controles-midi/)

### DJControl Inpulse T7 / T7 Premium

**partial** · No profile added by this collection

Official user manual/control descriptions archived; no complete manufacturer wire-address/LED chart found in the retrieved support resources. Software action mappings do not prove Note/CC values.

[Detailed source manifest](ni-hercules-ah/djcontrolinpulset7/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [support.html](ni-hercules-ah/djcontrolinpulset7/support.html) · [manufacturer source](https://support.hercules.com/en/product/djcontrolinpulset7-en/)
- [manual.pdf](ni-hercules-ah/djcontrolinpulset7/manual.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Inpulse_T7/DJC_INPULSE_T7_&_PREMIUM_USER_MANUAL_EN_FR_DE_DU_IT_ES_PT_RU_CS_TU_PL_SV_FI_SL_HU_AR_HE_AR_JP_ZH_KO.pdf)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulset7/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-t7-mapping-and-manual/)
- [djuced-midi.html](ni-hercules-ah/djcontrolinpulset7/djuced-midi.html) · [manufacturer source](https://www.djuced.com/kb/hercules-djcontrol-inpulse-t7-manuel-et-controles-midi/)

### DJControl Starlight

**partial** · No profile added by this collection

Official user manual/control descriptions archived; no complete manufacturer wire-address/LED chart found in the retrieved support resources. Software action mappings do not prove Note/CC values.

[Detailed source manifest](ni-hercules-ah/djcontrolstarlight/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [support.html](ni-hercules-ah/djcontrolstarlight/support.html) · [manufacturer source](https://support.hercules.com/en/product/djcontrolstarlight-en/)
- [manual.pdf](ni-hercules-ah/djcontrolstarlight/manual.pdf) · [manufacturer source](https://ts.hercules.com/download/sound/manuals/DJC_Starlight/How_To_Use_Hercules_DJControl_Starlight_-_En_Fr_De_Nl_It_Es_Pr_Ru_Cz_Tr_Pl_Zh_Ko_Ar.pdf)

## Korg

### nanoKONTROL2

**partial** · No profile added by this collection

Parameter guide pp.4-9 CC mode and external LEDs; full MIDI Implementation revision1.00 sections1-4, especially339-byte scene parameter layout and Native KORG LED commands; one-page capability chart and owner manual inspected.

Remaining work: Protocol is detailed but full default control-number map still requires editor scene export or hardware capture. DAW modes can output pitchbend and use different protocols; do not treat capability chart as complete map.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [midi-implementation.txt](performance/korg-nanokontrol2/midi-implementation.txt) · [manufacturer source](https://cdn.korg.com/us/support/download/files/aeb2862daf0cb7db826d8c62f51ec28d.txt?response-content-disposition=attachment%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_MIDIimp.txt&response-content-type=application%2Foctet-stream%3B)
- [midi-chart.pdf](performance/korg-nanokontrol2/midi-chart.pdf) · 1 pages · [manufacturer source](https://cdn.korg.com/us/support/download/files/902f10b95c3bac3b52113b0d8799a9e7.pdf?response-content-disposition=inline%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_MIDI_Chart_E1.pdf&response-content-type=application%2Fpdf%3B)
- [owner-guide.pdf](performance/korg-nanokontrol2/owner-guide.pdf) · 8 pages · [manufacturer source](https://cdn.korg.com/us/support/download/files/b61f4da2e9b32e7825edc729e7d71a0d.pdf?response-content-disposition=inline%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_OM_EFGSCJ2.pdf&response-content-type=application%2Fpdf%3B)
- [parameter-guide.pdf](performance/korg-nanokontrol2/parameter-guide.pdf) · 14 pages · [manufacturer source](https://cdn.korg.com/us/support/download/files/c8d0cd6808e12d3672845cadcdbbfe9b.pdf?response-content-disposition=inline%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_PG_E1.pdf&response-content-type=application%2Fpdf%3B)

## Native Instruments

### Traktor Kontrol F1

**partial** · No profile added by this collection

MIDI mode and configurable Controller Editor behavior documented. Ordinary MIDI requires the MIDI Mode preference; default User Map uses proprietary NHL. Need a pinned/exported Controller Editor template before assigning concrete addresses.

[Detailed source manifest](ni-hercules-ah/f1/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/f1/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/traktor_kontrol_f1_manual_english.pdf)
- [controller-editor.pdf](ni-hercules-ah/f1/controller-editor.pdf) · [manufacturer source](https://www.native-instruments.com/fileadmin/ni_media/downloads/manuals/Controller_Editor_Manual_English_2017_11.pdf)

### Traktor Kontrol S2 MK3

**partial** · No profile added by this collection

Official support confirms fixed firmware MIDI mode: hold left FLX while connecting, disconnect to exit. Manual lacks control-address chart; do not apply S2 MK2 addresses.

[Detailed source manifest](ni-hercules-ah/s2-mk3/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/s2-mk3/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/TRAKTOR_KONTROL_S2_MK3_Manual_English_1218.pdf)

### Traktor Kontrol S3

**partial** · No profile added by this collection

Official support confirms fixed firmware MIDI mode: hold left FLX while connecting, disconnect to exit. Manual lacks control-address chart. NI staff distinguishes fixed firmware messages from Controller Editor configuration.

[Detailed source manifest](ni-hercules-ah/s3/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/s3/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/TRAKTOR_KONTROL_S3_MK1_Manual_English_0120.pdf)

### Traktor Kontrol S4 MK3

**protocol-gap** · No profile added by this collection

Owner manual describes native Traktor operation, not a MIDI address chart. NI employee MichaelK_NI explicitly confirms S4 MK3 never supported MIDI. Native overmapping is not proof of MIDI mode.

[Detailed source manifest](ni-hercules-ah/s4-mk3/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/s4-mk3/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/TRAKTOR_KONTROL_S4_MK3_Manual_English_0719.pdf)
- [ni-staff-midi-explanation.html](ni-hercules-ah/s4-mk3/ni-staff-midi-explanation.html) · [manufacturer source](https://community.native-instruments.com/discussion/9022/why-does-the-s4mk3-still-not-have-midi-mode)

### Traktor MX2

**partial** · No profile added by this collection

Included because current official product page and downloads identify MX2. MIDI-mode support table says left SHIFT + right SHIFT; manual focuses on native Traktor behavior and has no numeric MIDI chart.

[Detailed source manifest](ni-hercules-ah/mx2/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/mx2/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/Traktor_MX2_user_guide-en.pdf)

### Traktor X1 MK3

**partial** · No profile added by this collection

MIDI mode explicitly documented via SHIFT + Mode Select. No numeric address/channel/encoder/LED protocol table found in downloaded manual.

[Detailed source manifest](ni-hercules-ah/x1-mk3/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/x1-mk3/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/Traktor_X1_MK3_Manual_English_0923.pdf)

### Traktor Z1 MK2

**partial** · No profile added by this collection

Manual confirms MIDI mode via --- + menu buttons. Native four-deck switching does not establish MIDI layer addresses. No complete wire protocol table found.

[Detailed source manifest](ni-hercules-ah/z1-mk2/manifest.json) · [Group report](ni-hercules-ah/group-report.md)

- [manual.pdf](ni-hercules-ah/z1-mk2/manual.pdf) · [manufacturer source](https://docs.native-instruments.com/pdf-guides/traktor/Traktor_Z1_Manual_EN_30102024.pdf)

## Novation

### Launch Control XL 3

**ready-for-extraction** · No profile added by this collection

Programmer reference pp.5-17; p.9 address graphic visually checked; pp.9-10 input/relative modes, pp.11-15 feedback, pp.16-17 feature controls.

Remaining work: SXM cannot capture full screen/SysEx protocol. Source p.10 has overlapping Custom mode wording (8 vs9); p.17 global channel hexadecimal upper-bound typo conflicts with decimal. Preserve raw evidence and resolve those fields before implementation.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/launch-control-xl-3/owner-guide.pdf) · 91 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_3-pdf-en.pdf)
- [programmer-reference-1.pdf](performance/launch-control-xl-3/programmer-reference-1.pdf) · 17 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_3_programmer_s_reference_guide-pdf_en.pdf)

### Launch Control XL MK1/MK2

**partial** · No profile added by this collection

Programmer reference pp.3-9; getting started guide supplied.

Remaining work: Excellent feedback specification but missing full factory input map; obtain template definitions or hardware capture before ready status.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [programmer-reference.pdf](performance/launch-control-xl-legacy/programmer-reference.pdf) · 9 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_programmer_s_reference_guide.pdf)
- [supplemental-owner-guide.pdf](performance/launch-control-xl-legacy/supplemental-owner-guide.pdf) · 7 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launch%20Control%20XL%20GSG%20v2.pdf)

### Launchpad Mini MK3

**ready-for-extraction** · No profile added by this collection

Programmer reference pp.6-15; owner guide pp.19-23; default and Programmer layout diagrams.

Remaining work: Extract a mode-specific input map. SysEx and RGB feedback require richer representation.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/launchpad-mini-mk3/owner-guide.pdf) · 24 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launchpad_mini_user_guide_v2-pdf-en.pdf)
- [programmer-reference-1.pdf](performance/launchpad-mini-mk3/programmer-reference-1.pdf) · 23 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20Mini%20-%20Programmers%20Reference%20Manual.pdf)

### Launchpad Pro MK3

**ready-for-extraction** · No profile added by this collection

Programmer reference pp.6-13; programmer layout p.8; DAW mode pp.14-18; owner guide Custom modes pp.29-32 and Appendix pp.59-62.

Remaining work: Extract the fixed Programmer mode separately; custom templates require captured configuration. RGB, SysEx and aftertouch must not be forced into SXM Note/CC fields.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/launchpad-pro-mk3/owner-guide.pdf) · 66 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20Pro%20User%20Guide.pdf)
- [programmer-reference-1.pdf](performance/launchpad-pro-mk3/programmer-reference-1.pdf) · 21 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/LPP3_prog_ref_guide_200415.pdf)

### Launchpad X

**ready-for-extraction** · No profile added by this collection

Programmer reference pp.6-15, particularly graphic map p.10 (visually inspected); owner guide default maps pp.37-39.

Remaining work: Retain MIDI versus DAW port and mode. Custom mode changes invalidate default assumptions; RGB SysEx and pressure exceed a plain Note/CC map.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [programmer-reference.pdf](performance/launchpad-x/programmer-reference.pdf) · 29 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20X%20-%20Programmers%20Reference%20Manual.pdf)
- [owner-guide-1.pdf](performance/launchpad-x/owner-guide-1.pdf) · 39 pages · [manufacturer source](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launchpad_x_user_guide_v2_en.pdf)

## Numark

### Mixtrack Platinum FX

**protocol-gap** · No profile added by this collection

USB MIDI documented; capacitive jog and display operation described without receive protocol.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [MixTrackPlatinumFX-UserGuide-v1.2.pdf](inmusic/mixtrack-platinum-fx/MixTrackPlatinumFX-UserGuide-v1.2.pdf) · 32 pages · [manufacturer source](https://cdn.inmusicbrands.com/Numark/vAC9uYWEnT/mtplfx/MixTrackPlatinumFX-UserGuide-v1.2.pdf)

### Mixtrack Pro FX

**protocol-gap** · No profile added by this collection

USB MIDI documented; pad modes described without address implementation.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [MixTrackProFX-UserGuide-v1.2.pdf](inmusic/mixtrack-pro-fx/MixTrackProFX-UserGuide-v1.2.pdf) · 28 pages · [manufacturer source](https://cdn.inmusicbrands.com/Numark/vAC9uYWEnT/mtprfx/MixTrackProFX-UserGuide-v1.2.pdf)

### NS4FX

**protocol-gap** · No profile added by this collection

USB sends MIDI data to software. Pad modes and deck Layer functions described, with no address implementation.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [NS4_FX_-_User_Guide_-_v1.3.pdf](inmusic/ns4fx/NS4_FX_-_User_Guide_-_v1.3.pdf) · 44 pages · [manufacturer source](https://www.numark.com/images/product_downloads/NS4_FX_-_User_Guide_-_v1.3.pdf)

### NS6II

**protocol-gap** · No profile added by this collection

Channel controls send MIDI only when Input Selector is PC; legacy user guide and quickstart both acquired.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Deck/layer changes, jog resolution, displays, encoders and LED feedback need independent protocol documentation or hardware capture.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [NS6II_-_Quickstart_Guide_-_v1.1.pdf](inmusic/ns6ii/NS6II_-_Quickstart_Guide_-_v1.1.pdf) · 52 pages · [manufacturer source](https://www.numark.com/images/product_downloads/NS6II_-_Quickstart_Guide_-_v1.1.pdf)
- [NS6II-UserGuide-v1.1.pdf](inmusic/ns6ii/NS6II-UserGuide-v1.1.pdf) · 76 pages · [manufacturer source](https://www.numark.com/images/product_downloads/NS6II-UserGuide-v1.1.pdf)

## Pioneer DJ

### DDJ-FLX10

**ready-for-extraction** · No profile added by this collection

MIDI chart pp.1–7: numbered physical diagram; channel allocation; browse/transport/mixer/FX/pad and host feedback tables. Owner manual p179: other DJ software.

Remaining work: Extract well-defined Note/CC controls and supported feedback first. Paired MSB/LSB pots/faders, pad/Shift channel groups, rich color feedback and jog/display behavior need richer schema or explicit exclusions.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/ddj-flx10/owner-manual.pdf) · 183 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DDJ_FLX10_DRI1822D_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/ddj-flx10/midi-implementation.pdf) · 7 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX10/DDJ-FLX10_MIDI_Message_List_E1.pdf)

### DDJ-FLX4

**ready-for-extraction** · No profile added by this collection

MIDI chart pp.1–5: deck, mixer, browse, FX, performance-pad send/receive and settings. Owner manual p161: other DJ software.

Remaining work: Preserve 0x40-centered jog encoding, paired tempo CCs, Shift/pad modes. Chart p5 says BEAT SYNC transmits on release and FX ON/OFF lights/blinks with special receive semantics; do not assume every button uses identical press/LED rules. Vinyl mode is host-controlled.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/ddj-flx4/owner-manual.pdf) · 165 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DDJ_FLX4_DRI1804A_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/ddj-flx4/midi-implementation.pdf) · 5 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX4/DDJ-FLX4_MIDI_message_List_E1.pdf)

### DDJ-REV5

**ready-for-extraction** · No profile added by this collection

MIDI chart pp.1–9: browse/transport/mixer/FX/pad maps with Shift, deck groups, send/receive values. Owner p131: MIDI MODE.

Remaining work: Paired high-resolution CCs and multiple performance-pad channels/modes exceed current simple profiles. Start with explicitly scoped transport/buttons and ordinary CCs; preserve color-number feedback limits.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/ddj-rev5/owner-manual.pdf) · 144 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DDJ_REV5_DRI1872B_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/ddj-rev5/midi-implementation.pdf) · 9 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-REV5/DDJ-REV5_MIDI_message_List_E1.pdf)

### DDJ-REV7

**ready-for-extraction** · No profile added by this collection

Current MIDI list E2 pp.1–7, not search-indexed older E1: channels, controls, FX modes, pad feedback. Owner pp101/105: AUTO/GENERAL MIDI mode and other DJ software.

Remaining work: Use E2 revision. Motorized platter and display integration is not established by a scalar control profile. Preserve hardware-only entries, FX-dependent controls, paired CCs and RGB feedback.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/ddj-rev7/owner-manual.pdf) · 118 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DDJ_REV7_DRI1713D_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/ddj-rev7/midi-implementation.pdf) · 7 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-REV7/DDJ-REV7_MIDI_message_List_E2.pdf)

### DJM-A9

**ready-for-extraction** · No profile added by this collection

MIDI chart p1 diagram; pp2–6 transmit control matrix. Owner p57 USB/MIDI; p80 MIDI channel and transmission method settings.

Remaining work: Good transmit-only profile candidate for ordinary mixer controls. The acquired chart does not define general host LED receive control. TIME uses an MSB/LSB pair and Timing Clock F8 is a system message, not a Note/CC. Owner p58: timing clock and START/STOP continue even with MIDI ON/OFF off; this is a documented transmit subset, not proof the hardware cannot receive MIDI.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/djm-a9/owner-manual.pdf) · 108 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DJM_A9_DRI1785B_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/djm-a9/midi-implementation.pdf) · 6 pages · [manufacturer source](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-A9/DJM-A9_MIDI_Message_List_E_10.pdf)

### DJM-S11

**ready-for-extraction** · No profile added by this collection

MIDI chart p1 diagram; pp2–9 channel allocation, mixer, FX, pad/mode and receive tables. Manufacturer MIDI support page requires appropriate other-software utility setting.

Remaining work: Mode-dependent pad/FX controls and paired high-resolution CCs need scoped extraction; do not claim full touchscreen/Serato/native feature emulation.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/djm-s11/owner-manual.pdf) · 126 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/DJM_S11_DRI1653B_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/djm-s11/midi-implementation.pdf) · 9 pages · [manufacturer source](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-S11/DJM-S11_MIDI_Message_v100_E.pdf)

### XDJ-RX3

**ready-for-extraction** · No profile added by this collection

English MIDI chart pp.1–5: panel diagram, deck/mixer/pad/browse and LED/display tables.

Remaining work: Recovered English chart from current official support instead of the old Japanese search result. Exclude hardware-only entries; preserve pad layers/color numbers and jog/display semantics separately.

[Detailed source manifest](pioneer-alphatheta/manifest.json) · [Group report](pioneer-alphatheta/group-report.md)

- [owner-manual.pdf](pioneer-alphatheta/xdj-rx3/owner-manual.pdf) · 127 pages · [manufacturer source](https://downloads.support.alphatheta.com/manuals/XDJ_RX3_DRI1702C_manual.pdf)
- [midi-implementation.pdf](pioneer-alphatheta/xdj-rx3/midi-implementation.pdf) · 5 pages · [manufacturer source](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX3/XDJ-RX3_MIDI_Message_List_E1.pdf)

## Rane

### FOUR

**protocol-gap** · No profile added by this collection

Deck source selects USB A/B MIDI destination; deck controls send MIDI only with source USB A or B. Custom pad mode is software MIDI-mappable.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; FOUR jogs are non-motorized. Jog data, screen feedback and hardware effects require separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [FOUR_-_User_Guide_-_v1.2.pdf](inmusic/four/FOUR_-_User_Guide_-_v1.2.pdf) · 39 pages · [manufacturer source](https://cdn.inmusicbrands.com/rane/four/FOUR%20-%20User%20Guide%20-%20v1.2.pdf)

### ONE

**protocol-gap** · No profile added by this collection

Deck controls send MIDI only when deck source selector is USB A/B.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Motorized platter data requires separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [RANE-ONE-User-Guide-v1_5.pdf](inmusic/one/RANE-ONE-User-Guide-v1_5.pdf) · 56 pages · [manufacturer source](https://cdn.inmusicbrands.com/rane/one/RANE-ONE-User-Guide-v1_5.pdf)

### PERFORMER

**protocol-gap** · No profile added by this collection

Deck-source USB mode enables MIDI to chosen computer; guide describes on-device parameter encoder and displays without wire addresses.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Motorized platter data, screen feedback and hardware effects require separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [PERFORMER_-_User_Guide_-_v1.3.pdf](inmusic/performer/PERFORMER_-_User_Guide_-_v1.3.pdf) · 50 pages · [manufacturer source](https://cdn.inmusicbrands.com/rane/performer/PERFORMER%20-%20User%20Guide%20-%20v1.3.pdf)

### SEVENTY-TWO MKII

**protocol-gap** · No profile added by this collection

Up to three custom pad sets via Serato hardware remapping; guide gives user operation, not protocol identifiers.

Remaining work: No complete manufacturer Note/CC address/channel chart or LED receive protocol was located in acquired documentation. Do not infer from USB MIDI compatibility or Serato mapping.; Touchscreen feedback, hardware effects and DVS audio behavior require separate protocol evidence; the owner guide does not establish scalar Note/CC mappings.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [Seventy-Two_MKII-UserGuide-v1.4.pdf](inmusic/seventy-two-mkii/Seventy-Two_MKII-UserGuide-v1.4.pdf) · 104 pages · [manufacturer source](https://cdn.inmusicbrands.com/rane/seventy-twoMKII/Seventy-Two_MKII-UserGuide-v1.4.pdf)

### TWELVE MKII

**protocol-gap** · No profile added by this collection

Owner guide recovered from official CDN. USB mode and DVS audio mode are distinct; manufacturer recommends RCA for DVS platter control alongside USB for Browse, Load/Instant Doubles and Hot Cues. Touch Strip switches Needle Drop/Hot Cue modes, and Deck Select chooses software deck.

Remaining work: No control address/channel or LED receive implementation chart appears in the owner guide.; DVS platter timecode is audio, outside scalar MIDI profiles. USB motorized-platter precision and screen protocol are not specified; do not infer scalar maps from behavior.

[Detailed source manifest](inmusic/manifest.json) · [Group report](inmusic/group-report.md)

- [Twelve_MKII-UserGuide-v1.1.pdf](inmusic/twelve-mkii/Twelve_MKII-UserGuide-v1.1.pdf) · 36 pages · [manufacturer source](https://cdn.inmusicbrands.com/rane/twelveMKII/Twelve_MKII-UserGuide-v1.1.pdf)

## Reloop

### Buddy

**protocol-gap** · No profile added by this collection

English pp.2-6

Remaining work: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/buddy/owner-guide.pdf) · 28 pages · [manufacturer source](https://www.reloop.com/media/custom/upload/Reloop-243599_Reloop_IM.pdf)

### Mixon 8 Pro

**protocol-gap** · No profile added by this collection

English pp.4-12

Remaining work: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/mixon-8-pro/owner-guide.pdf) · 44 pages · [manufacturer source](https://www.reloop.com/media/catalog/product/pdf/2/4/4/244789_Reloop_IM.pdf)

### Neon

**partial** · No profile added by this collection

MIDI chart pp.1-9 (p.1 visually inspected); owner quick-start English pp.5-8.

Remaining work: Unspecified encoder pp values and RGB/LED value semantics need verification; chart has suspected copy errors (e.g. repeated Deck C/D SYNC addresses). Aftertouch messages are outside Note/CC schema.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/neon/owner-guide.pdf) · 16 pages · [manufacturer source](https://www.reloop.com/media/custom/upload/Reloop-232520_Reloop_IM.pdf)
- [midi-chart-1.pdf](performance/neon/midi-chart-1.pdf) · 9 pages · [manufacturer source](https://www.reloop.com/media/custom/upload/Reloop-NEON_MIDI-Map.pdf)

### Ready

**protocol-gap** · No profile added by this collection

English pp.2-7

Remaining work: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/ready/owner-guide.pdf) · 28 pages · [manufacturer source](https://www.reloop.com/media/catalog/product/pdf/2/4/3/243598_Reloop_IM.pdf)

## Roland

### DJ-202

**protocol-gap** · No profile added by this collection

Owner pp.4-7; supplemental Operating the DJ-202 guide supplied

Remaining work: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/dj-202/owner-guide.pdf) · 12 pages · [manufacturer source](https://static.roland.com/assets/media/pdf/DJ-202_Startup_Guide_eng03_W.pdf)
- [supplemental-owner-guide.pdf](performance/dj-202/supplemental-owner-guide.pdf) · 17 pages · [manufacturer source](https://static.roland.com/assets/media/pdf/DJ-202_eng03_W.pdf)

### DJ-505

**protocol-gap** · No profile added by this collection

Owner pp.5-9,21-23 (other-software section p.21)

Remaining work: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/dj-505/owner-guide.pdf) · 32 pages · [manufacturer source](https://static.roland.com/assets/media/pdf/DJ-505_eng02_W.pdf)

### DJ-808

**protocol-gap** · No profile added by this collection

Owner pp.5-10,21-22 (other-software section p.21)

Remaining work: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

[Detailed source manifest](performance/manifest.json) · [Group report](performance/group-report.md)

- [owner-guide.pdf](performance/dj-808/owner-guide.pdf) · 32 pages · [manufacturer source](https://static.roland.com/assets/media/pdf/DJ-808_eng03_W.pdf)

