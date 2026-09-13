# Pioneer DJ / AlphaTheta documentation audit

Retrieved 12 September 2026. Editorial selection covers flagship, entry, scratch, standalone, club mixer/player and performance-pad use cases; it is not a sales ranking. All 12 models have an original official owner manual and MIDI message-list PDF downloaded. Euphonia remains in the existing archive and is indexed separately in the master catalogue.

## Assessment

Ready-for-extraction means a documented subset can be transcribed with page evidence. It does not mean a complete SXM profile exists or that current schema supports every documented behavior. Eleven source-ready models and one partial (SLAB) are recorded.

## Pioneer DJ DDJ-FLX10 — ready-for-extraction

MIDI chart pp.1–7: numbered physical diagram; channel allocation; browse/transport/mixer/FX/pad and host feedback tables. Owner manual p179: other DJ software.

Extract well-defined Note/CC controls and supported feedback first. Paired MSB/LSB pots/faders, pad/Shift channel groups, rich color feedback and jog/display behavior need richer schema or explicit exclusions.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/16716272919193)

- [owner-manual — 183 PDF pages](ddj-flx10/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DDJ_FLX10_DRI1822D_manual.pdf)
- [midi-implementation — 7 PDF pages](ddj-flx10/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX10/DDJ-FLX10_MIDI_Message_List_E1.pdf)

## Pioneer DJ DDJ-FLX4 — ready-for-extraction

MIDI chart pp.1–5: deck, mixer, browse, FX, performance-pad send/receive and settings. Owner manual p161: other DJ software.

Preserve 0x40-centered jog encoding, paired tempo CCs, Shift/pad modes. Chart p5 says BEAT SYNC transmits on release and FX ON/OFF lights/blinks with special receive semantics; do not assume every button uses identical press/LED rules. Vinyl mode is host-controlled.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/12267724407961)

- [owner-manual — 165 PDF pages](ddj-flx4/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DDJ_FLX4_DRI1804A_manual.pdf)
- [midi-implementation — 5 PDF pages](ddj-flx4/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX4/DDJ-FLX4_MIDI_message_List_E1.pdf)

## Pioneer DJ DDJ-REV7 — ready-for-extraction

Current MIDI list E2 pp.1–7, not search-indexed older E1: channels, controls, FX modes, pad feedback. Owner pp101/105: AUTO/GENERAL MIDI mode and other DJ software.

Use E2 revision. Motorized platter and display integration is not established by a scalar control profile. Preserve hardware-only entries, FX-dependent controls, paired CCs and RGB feedback.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/4414650995737)

- [owner-manual — 118 PDF pages](ddj-rev7/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DDJ_REV7_DRI1713D_manual.pdf)
- [midi-implementation — 7 PDF pages](ddj-rev7/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-REV7/DDJ-REV7_MIDI_message_List_E2.pdf)

## Pioneer DJ DDJ-REV5 — ready-for-extraction

MIDI chart pp.1–9: browse/transport/mixer/FX/pad maps with Shift, deck groups, send/receive values. Owner p131: MIDI MODE.

Paired high-resolution CCs and multiple performance-pad channels/modes exceed current simple profiles. Start with explicitly scoped transport/buttons and ordinary CCs; preserve color-number feedback limits.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/21326568940057)

- [owner-manual — 144 PDF pages](ddj-rev5/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DDJ_REV5_DRI1872B_manual.pdf)
- [midi-implementation — 9 PDF pages](ddj-rev5/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-REV5/DDJ-REV5_MIDI_message_List_E1.pdf)

## AlphaTheta DDJ-GRV6 — ready-for-extraction

MIDI chart pp.1–4: diagram, channel allocation, transport, mixer, Groove Circuit/FX and pad tables.

Strong documentation; arbitrary deck/Shift/mode routing, paired CCs and colored feedback need adaptation. Browse relative values are explicitly documented. Do not interpret hardware-specific function labels as Traktor assignments.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/37071169629849)

- [owner-manual — 174 PDF pages](ddj-grv6/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DDJ_GRV6_DRI1927A_manual.pdf)
- [midi-implementation — 4 PDF pages](ddj-grv6/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-GRV6/DDJ-GRV6_MIDI_Message_List_E1.pdf)

## AlphaTheta XDJ-AZ — ready-for-extraction

MIDI chart pp.1–4: channel matrix and send/receive; hardware-only entries; p4 jog LED/display-related values.

Standalone controls are not all MIDI controls. Preserve hardware-only exclusions, mode routing and paired CCs; p4 angle-related pairs are not independent 7-bit knobs.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/37072366390681)

- [owner-manual — 159 PDF pages](xdj-az/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/XDJ-AZ/XDJ-AZ_DRI1936C_manual_EN.pdf)
- [midi-implementation — 4 PDF pages](xdj-az/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-AZ/XDJ-AZ_MIDI_Message_List_E1.pdf)

## AlphaTheta OMNIS-DUO — ready-for-extraction

MIDI chart p1 diagram; pp2–3 channels, deck/mixer/browse and receive meter/indicator tables.

Suitable documented subset; paired tempo CCs, relative/speed jog behavior and per-deck channels need faithful encoding. Standalone operation does not imply every function can be remotely driven.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/26559298056217)

- [owner-manual — 134 PDF pages](omnis-duo/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/all-in-one-dj-systems/OMNIS-DUO/OMNIS_DUO_DRI1882B_manual.pdf)
- [midi-implementation — 3 PDF pages](omnis-duo/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/OMNIS-DUO/OMNIS-DUO_MIDI_Message_List_E1.pdf)

## Pioneer DJ XDJ-RX3 — ready-for-extraction

English MIDI chart pp.1–5: panel diagram, deck/mixer/pad/browse and LED/display tables.

Recovered English chart from current official support instead of the old Japanese search result. Exclude hardware-only entries; preserve pad layers/color numbers and jog/display semantics separately.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/4409181796121)

- [owner-manual — 127 PDF pages](xdj-rx3/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/XDJ_RX3_DRI1702C_manual.pdf)
- [midi-implementation — 5 PDF pages](xdj-rx3/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/all-in-one-dj-systems/XDJ-RX3/XDJ-RX3_MIDI_Message_List_E1.pdf)

## Pioneer DJ DJM-A9 — ready-for-extraction

MIDI chart p1 diagram; pp2–6 transmit control matrix. Owner p57 USB/MIDI; p80 MIDI channel and transmission method settings.

Good transmit-only profile candidate for ordinary mixer controls. The acquired chart does not define general host LED receive control. TIME uses an MSB/LSB pair and Timing Clock F8 is a system message, not a Note/CC.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/15916598774553)

- [owner-manual — 108 PDF pages](djm-a9/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DJM_A9_DRI1785B_manual.pdf)
- [midi-implementation — 6 PDF pages](djm-a9/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-A9/DJM-A9_MIDI_Message_List_E_10.pdf)

## Pioneer DJ DJM-S11 — ready-for-extraction

MIDI chart p1 diagram; pp2–9 channel allocation, mixer, FX, pad/mode and receive tables. Manufacturer MIDI support page requires appropriate other-software utility setting.

Mode-dependent pad/FX controls and paired high-resolution CCs need scoped extraction; do not claim full touchscreen/Serato/native feature emulation.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/4404665542425)

- [owner-manual — 126 PDF pages](djm-s11/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/DJM_S11_DRI1653B_manual.pdf)
- [midi-implementation — 9 PDF pages](djm-s11/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/midi-mapping/dj-mixers/DJM-S11/DJM-S11_MIDI_Message_v100_E.pdf)

## AlphaTheta CDJ-3000X — ready-for-extraction

MIDI chart pp1–2 diagrams; pp3–4 transmit Note/CC controls and hardware-only exclusions. Owner p98 MIDI/HID DJ-software operation; p105 MIDI channel setting.

Useful transport/input subset. Chart does not supply a complete host screen/LED receive protocol. Jog values encode signed speed around64, distinct from ordinary relative encoder increments. MIDI and HID operation must remain separate.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/49578856455577)

- [owner-manual — 122 PDF pages](cdj-3000x/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/dj-players/CDJ-3000X/CDJ-3000X_DRI1956C_EN_manual.pdf)
- [midi-implementation — 4 PDF pages](cdj-3000x/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/software_info/dj-players/CDJ-3000X/CDJ3000X_MIDI_Message_List_En.pdf)

## AlphaTheta SLAB — partial

MIDI chart pp1–4: control/pad/touch-strip mappings, page modes, aftertouch and colored receive. PDF p1 E1 encoder-mode row visually reviewed.

Unresolved source conflict: E1 decimal MIDI channel1 but status96 (channel7). Dial/encoder turn values are CW01/CCW41, not two’s-complement. Paired touch strip, poly aftertouch, arbitrary pages and RGB feedback need adaptation; quarantine contradictory row.

[Official owner-manual page](https://support.alphatheta.com/en-US/articles/52906226059545)

- [owner-manual — 43 PDF pages](slab/owner-manual.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/manuals/music-production/SLAB/SLAB_DRI1975A_EN_manual.pdf)
- [midi-implementation — 4 PDF pages](slab/midi-implementation.pdf) · [original manufacturer file](https://downloads.support.alphatheta.com/midi-mapping/music-production/SLAB/SLAB_MIDI_Message_List_en.pdf)

## Cross-model extraction rules

Note/CC; absolute7Bit/relativeTwosComplement/noteGate; base/amber/green layers; red/amber/green colors; global channel plus contextual overrides. High-resolution pairs, arbitrary banks, independent per-binding channels, RGB palettes, non-twos-complement encoders and SysEx need adaptation or exclusion.

Normalize source perspective: these charts often call device→computer MIDI-IN and computer→device MIDI-OUT. SXM profile send/receive is from the device perspective. Do not reverse these.

Use numeric bytes as evidence; note names vary by octave convention. Preserve contradictory columns in a review queue. General MIDI compatibility does not establish full screen, motor, RGB, HID or proprietary integration. Controls marked Hardware Control must not receive invented MIDI addresses.

Current support-page links were read in the native browser when direct requests returned403. The original PDF bytes, extraction aids and hashes are archived. The current DDJ-REV7 E2 supersedes the older indexed E1 in this collection. The SLAB inconsistency is visible in the original chart, not just PDF extraction.

This is a source collection only; no app code or bundled profiles changed.

## Cross-check additions

- DJM-A9 owner p58: timing clock and START/STOP continue even when MIDI ON/OFF is off. The classification is a documented transmit subset, not proof that the hardware cannot receive any MIDI.
- CDJ-3000X owner p99: enter SOURCE → SOFTWARE CONTROL; loading a track from another device exits control mode.
- SLAB E1 conflict affects both note16 and shifted note17. Its partial grade is conservative because the mode-control row is ambiguous, even though isolated other rows can be extracted.
- Schema nuance: mode IDs can exist as metadata, but bindings have no independent channel/mode field and only three enumerated layer values. Generalized mode routing, rather than basic mode metadata, is the gap.
