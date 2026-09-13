# Performance controller manufacturer library

Checked 12 September 2026. Editorial representative selection, not a sales ranking. These are research source assets, not shipped SXM controller definitions.

17 models; 5 ready-for-extraction, 6 partial, 6 protocol-gap, 0 inaccessible. All original downloaded PDFs passed PDF parsing and SHA-256 verification. Google Drive documents are explicitly linked by the official DJ TechTools setup page, establishing publisher provenance.

Launch Control XL 3 has a current official download page and programmer guide; legacy XL MK1/MK2 is kept as a separate model. Support-page presence is not evidence of stock availability.

## Model findings

### Novation Launchpad Pro MK3 — ready-for-extraction

[Official source](https://downloads.novationmusic.com/novation/launchpad-mk3/launchpad-pro-mk3-0). Inspection: Programmer reference pp.6-13; programmer layout p.8; DAW mode pp.14-18; owner guide Custom modes pp.29-32 and Appendix pp.59-62.

- **input channel and address**: Programmer mode uses fixed pad/button Note numbers; channel and message conventions given; USB MIDI/DAW/DIN interfaces distinguished.

- **layers**: Programmer, Custom, Note/Chord, DAW; custom maps are configurable.

- **relative encoder**: Not applicable: no rotary encoders.

- **led output**: Note/CC palette feedback plus RGB/bulk lighting SysEx and animation.

- **Gap / extraction constraint**: Extract the fixed Programmer mode separately; custom templates require captured configuration. RGB, SysEx and aftertouch must not be forced into SXM Note/CC fields.

- [owner-guide original PDF](launchpad-pro-mk3/owner-guide.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20Pro%20User%20Guide.pdf) · 66 PDF pages; extracted text: [owner-guide.txt](launchpad-pro-mk3/owner-guide.txt).

- [programmer-reference original PDF](launchpad-pro-mk3/programmer-reference-1.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/LPP3_prog_ref_guide_200415.pdf) · 21 PDF pages; extracted text: [programmer-reference-1.txt](launchpad-pro-mk3/programmer-reference-1.txt).

### Novation Launchpad X — ready-for-extraction

[Official source](https://downloads.novationmusic.com/novation/launchpad-mk3/launchpad-x). Inspection: Programmer reference pp.6-15, particularly graphic map p.10 (visually inspected); owner guide default maps pp.37-39.

- **input channel and address**: Fixed Programmer map: 8x8 notes 11-18 through 81-88; top CC91-99 (99 is logo), side CC19/29/.../89. Message/channel conventions in protocol guide.

- **layers**: Programmer, DAW, Note and configurable Custom modes.

- **relative encoder**: Not applicable: no rotary encoders.

- **led output**: Palette Note/CC lighting; RGB and other lighting commands in SysEx.

- **Gap / extraction constraint**: Retain MIDI versus DAW port and mode. Custom mode changes invalidate default assumptions; RGB SysEx and pressure exceed a plain Note/CC map.

- [programmer-reference original PDF](launchpad-x/programmer-reference.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20X%20-%20Programmers%20Reference%20Manual.pdf) · 29 PDF pages; extracted text: [programmer-reference.txt](launchpad-x/programmer-reference.txt).

- [owner-guide original PDF](launchpad-x/owner-guide-1.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launchpad_x_user_guide_v2_en.pdf) · 39 PDF pages; extracted text: [owner-guide-1.txt](launchpad-x/owner-guide-1.txt).

### Novation Launchpad Mini MK3 — ready-for-extraction

[Official source](https://downloads.novationmusic.com/novation/launchpad-mk3/launchpad-mini-mk3-0). Inspection: Programmer reference pp.6-15; owner guide pp.19-23; default and Programmer layout diagrams.

- **input channel and address**: Programmer Note/CC address diagram and MIDI convention documented, distinct from configurable Custom grids.

- **layers**: Programmer, Session and Custom modes.

- **relative encoder**: Not applicable: no rotary encoders.

- **led output**: Palette feedback and lighting SysEx documented.

- **Gap / extraction constraint**: Extract a mode-specific input map. SysEx and RGB feedback require richer representation.

- [owner-guide original PDF](launchpad-mini-mk3/owner-guide.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launchpad_mini_user_guide_v2-pdf-en.pdf) · 24 PDF pages; extracted text: [owner-guide.txt](launchpad-mini-mk3/owner-guide.txt).

- [programmer-reference original PDF](launchpad-mini-mk3/programmer-reference-1.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launchpad%20Mini%20-%20Programmers%20Reference%20Manual.pdf) · 23 PDF pages; extracted text: [programmer-reference-1.txt](launchpad-mini-mk3/programmer-reference-1.txt).

### Novation Launch Control XL 3 — ready-for-extraction

[Official source](https://downloads.novationmusic.com/novation/launch-control-xl-3/launch-control-xl-3). Inspection: Programmer reference pp.5-17; p.9 address graphic visually checked; pp.9-10 input/relative modes, pp.11-15 feedback, pp.16-17 feature controls.

- **input channel and address**: DAW CC surface: encoders/faders channel16, buttons channel1, Shift channel7. Surface CC addresses in graphic; relative rows CC77-84,85-92,93-100.

- **layers**: Standalone Custom modes 1-16, DAW Mixer, DAW Control; DAW mode requires enable message to DAW USB interface.

- **relative encoder**: Relative pivot64, clockwise65 / anticlockwise63; enable per row with channel7 CC69/72/73 and value127. Relative mode changes CC addresses.

- **led output**: CC palette feedback, SysEx surface RGB and screen bitmap/text.

- **Gap / extraction constraint**: SXM cannot capture full screen/SysEx protocol. Source p.10 has overlapping Custom mode wording (8 vs9); p.17 global channel hexadecimal upper-bound typo conflicts with decimal. Preserve raw evidence and resolve those fields before implementation.

- [owner-guide original PDF](launch-control-xl-3/owner-guide.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_3-pdf-en.pdf) · 91 PDF pages; extracted text: [owner-guide.txt](launch-control-xl-3/owner-guide.txt).

- [programmer-reference original PDF](launch-control-xl-3/programmer-reference-1.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_3_programmer_s_reference_guide-pdf_en.pdf) · 17 PDF pages; extracted text: [programmer-reference-1.txt](launch-control-xl-3/programmer-reference-1.txt).

### Novation Launch Control XL MK1/MK2 — partial

[Official source](https://downloads.novationmusic.com/novation/launch/launch-control-xl-mk1mk2). Inspection: Programmer reference pp.3-9; getting started guide supplied.

- **input channel and address**: Device input Note/CC depends on active editable/factory template; guide does not enumerate full default pot/fader/button input addresses.

- **layers**: 16 templates: user0-7, factory8-15; SysEx template change documented.

- **relative encoder**: Physical pots and faders; do not assume encoder relative modes. HUI emulation described on official download page.

- **led output**: Detailed bi-colour LED velocity encoding, Note/CC matching, SysEx targeting and double buffering.

- **Gap / extraction constraint**: Excellent feedback specification but missing full factory input map; obtain template definitions or hardware capture before ready status.

- [programmer-reference original PDF](launch-control-xl-legacy/programmer-reference.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/downloads/launch_control_xl_programmer_s_reference_guide.pdf) · 9 PDF pages; extracted text: [programmer-reference.txt](launch-control-xl-legacy/programmer-reference.txt).

- [supplemental-owner-guide original PDF](launch-control-xl-legacy/supplemental-owner-guide.pdf) · [manufacturer download](https://fael-downloads-prod.focusrite.com/customer/prod/s3fs-public/downloads/Launch%20Control%20XL%20GSG%20v2.pdf) · 7 PDF pages; extracted text: [supplemental-owner-guide.txt](launch-control-xl-legacy/supplemental-owner-guide.txt).

### Reloop Mixon 8 Pro — protocol-gap

[Official source](https://www.reloop.com/reloop-mixon-8-pro). Inspection: English pp.4-12

- **input channel and address**: No complete input channel/address chart found in downloaded official manuals/support page.

- **layers**: Owner manual describes shift and software performance/pad modes, but no mode-specific numeric MIDI mapping.

- **relative encoder**: No numeric turn-direction encoding found.

- **led output**: Indicators and software feedback behavior described; no complete LED address/value protocol found.

- **Gap / extraction constraint**: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

- [owner-guide original PDF](mixon-8-pro/owner-guide.pdf) · [manufacturer download](https://www.reloop.com/media/catalog/product/pdf/2/4/4/244789_Reloop_IM.pdf) · 44 PDF pages; extracted text: [owner-guide.txt](mixon-8-pro/owner-guide.txt).

### Reloop Ready — protocol-gap

[Official source](https://www.reloop.com/reloop-ready). Inspection: English pp.2-7

- **input channel and address**: No complete input channel/address chart found in downloaded official manuals/support page.

- **layers**: Owner manual describes shift and software performance/pad modes, but no mode-specific numeric MIDI mapping.

- **relative encoder**: No numeric turn-direction encoding found.

- **led output**: Indicators and software feedback behavior described; no complete LED address/value protocol found.

- **Gap / extraction constraint**: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

- [owner-guide original PDF](ready/owner-guide.pdf) · [manufacturer download](https://www.reloop.com/media/catalog/product/pdf/2/4/3/243598_Reloop_IM.pdf) · 28 PDF pages; extracted text: [owner-guide.txt](ready/owner-guide.txt).

### Reloop Buddy — protocol-gap

[Official source](https://www.reloop.com/reloop-buddy). Inspection: English pp.2-6

- **input channel and address**: No complete input channel/address chart found in downloaded official manuals/support page.

- **layers**: Owner manual describes shift and software performance/pad modes, but no mode-specific numeric MIDI mapping.

- **relative encoder**: No numeric turn-direction encoding found.

- **led output**: Indicators and software feedback behavior described; no complete LED address/value protocol found.

- **Gap / extraction constraint**: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

- [owner-guide original PDF](buddy/owner-guide.pdf) · [manufacturer download](https://www.reloop.com/media/custom/upload/Reloop-243599_Reloop_IM.pdf) · 28 PDF pages; extracted text: [owner-guide.txt](buddy/owner-guide.txt).

### Reloop Neon — partial

[Official source](https://www.reloop.com/reloop-neon). Inspection: MIDI chart pp.1-9 (p.1 visually inspected); owner quick-start English pp.5-8.

- **input channel and address**: Explicit hexadecimal status/address tables for pad, encoder push/turn, bank/deck/shift and LEDs. Example Sample layer1 pads97 00-07 pp.

- **layers**: Sampler/Slicer/Hot Cue/Hot Loop each with two layers, shift, banks/decks; hardware versus MIDI bank/LED state distinctions documented.

- **relative encoder**: CC encoder addresses supplied, but pp value placeholder does not establish numeric relative direction encoding.

- **led output**: LED addresses and MIDI IN=MIDI OUT notes; hardware/MIDI feedback distinctions supplied.

- **Gap / extraction constraint**: Unspecified encoder pp values and RGB/LED value semantics need verification; chart has suspected copy errors (e.g. repeated Deck C/D SYNC addresses). Aftertouch messages are outside Note/CC schema.

- [owner-guide original PDF](neon/owner-guide.pdf) · [manufacturer download](https://www.reloop.com/media/custom/upload/Reloop-232520_Reloop_IM.pdf) · 16 PDF pages; extracted text: [owner-guide.txt](neon/owner-guide.txt).

- [midi-chart original PDF](neon/midi-chart-1.pdf) · [manufacturer download](https://www.reloop.com/media/custom/upload/Reloop-NEON_MIDI-Map.pdf) · 9 PDF pages; extracted text: [midi-chart-1.txt](neon/midi-chart-1.txt).

### Roland DJ-808 — protocol-gap

[Official source](https://www.roland.com/global/support/by_product/dj-808/owners_manuals/). Inspection: Owner pp.5-10,21-22 (other-software section p.21)

- **input channel and address**: No complete input channel/address chart found in downloaded official manuals/support page.

- **layers**: Control, pad/shift and sequencer operation described; no complete controller MIDI addresses.

- **relative encoder**: No numeric turn-direction encoding found.

- **led output**: Indicators and software feedback behavior described; no complete LED address/value protocol found.

- **Gap / extraction constraint**: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

- [owner-guide original PDF](dj-808/owner-guide.pdf) · [manufacturer download](https://static.roland.com/assets/media/pdf/DJ-808_eng03_W.pdf) · 32 PDF pages; extracted text: [owner-guide.txt](dj-808/owner-guide.txt).

### Roland DJ-505 — protocol-gap

[Official source](https://www.roland.com/global/support/by_product/dj-505/owners_manuals/). Inspection: Owner pp.5-9,21-23 (other-software section p.21)

- **input channel and address**: No complete input channel/address chart found in downloaded official manuals/support page.

- **layers**: Control, pad/shift and sequencer operation described; no complete controller MIDI addresses.

- **relative encoder**: No numeric turn-direction encoding found.

- **led output**: Indicators and software feedback behavior described; no complete LED address/value protocol found.

- **Gap / extraction constraint**: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

- [owner-guide original PDF](dj-505/owner-guide.pdf) · [manufacturer download](https://static.roland.com/assets/media/pdf/DJ-505_eng02_W.pdf) · 32 PDF pages; extracted text: [owner-guide.txt](dj-505/owner-guide.txt).

### Roland DJ-202 — protocol-gap

[Official source](https://www.roland.com/global/support/by_product/dj-202/owners_manuals/). Inspection: Owner pp.4-7; supplemental Operating the DJ-202 guide supplied

- **input channel and address**: No complete input channel/address chart found in downloaded official manuals/support page.

- **layers**: Control, pad/shift and sequencer operation described; no complete controller MIDI addresses.

- **relative encoder**: No numeric turn-direction encoding found.

- **led output**: Indicators and software feedback behavior described; no complete LED address/value protocol found.

- **Gap / extraction constraint**: Owner manual and general MIDI capability do not provide a full map. Request manufacturer control protocol or capture hardware messages; do not infer addresses from control numbers or MIDI clock output.

- [owner-guide original PDF](dj-202/owner-guide.pdf) · [manufacturer download](https://static.roland.com/assets/media/pdf/DJ-202_Startup_Guide_eng03_W.pdf) · 12 PDF pages; extracted text: [owner-guide.txt](dj-202/owner-guide.txt).

- [supplemental-owner-guide original PDF](dj-202/supplemental-owner-guide.pdf) · [manufacturer download](https://static.roland.com/assets/media/pdf/DJ-202_eng03_W.pdf) · 17 PDF pages; extracted text: [supplemental-owner-guide.txt](dj-202/supplemental-owner-guide.txt).

### DJ TechTools Midi Fighter Twister — partial

[Official source](https://djtechtools.com/midi-fighter-setup/). Inspection: User/MIDI guide pp.2-8,14-16; default bank tables pp.17-24 and animation/color appendices.

- **input channel and address**: Encoder/switch CC maps supplied. Appendix encoder channel0 and switch channel1 explicitly zero-based; system channel4 footnotes use 1-16 numbering.

- **layers**: Up to eight virtual banks documented; configurable encoder push, side buttons, bank CC and shifted encoder layer.

- **relative encoder**: Enc 3FH/41H sends65 clockwise and63 anticlockwise (p.16).

- **led output**: Ring value feedback on same address; RGB colour and animation on additional channels, palettes documented.

- **Gap / extraction constraint**: Mixed channel numbering conventions across source sections require normalization by section and hardware verification; some earlier text still refers to four banks. Ready subset: default encoder/switch address tables with explicit zero-based convention.

- [owner-and-midi-guide original PDF](midi-fighter-twister/owner-and-midi-guide.pdf) · [manufacturer download](https://drive.google.com/uc?export=download&id=0B-QvIds_FsH3Z0ZLT041VnZfOTA) · 29 PDF pages; extracted text: [owner-and-midi-guide.txt](midi-fighter-twister/owner-and-midi-guide.txt).

### DJ TechTools Midi Fighter 3D — partial

[Official source](https://djtechtools.com/midi-fighter-setup/). Inspection: User/MIDI guide pp.2-8,12; bank tables pp.14-17; motion chart p.18 visually inspected, animation p.19.

- **input channel and address**: Arcade note and optional CC maps with bank tables; configurable base channel and side switches.

- **layers**: Four banks, Ableton momentary-CC versus Traktor motion behavior; bank mode configuration.

- **relative encoder**: No rotary encoder. Motion relative mode uses direction-specific channels and proportional orientation CC; do not model as ordinary 63/65 encoder.

- **led output**: Note velocity colour mapping and animation channel documented.

- **Gap / extraction constraint**: Source p.18 Edge Tilt table visibly contradicts p.7 CC0-7 prose (table contains note names and40/39/38/43). Channel nomenclature must be verified; quarantine conflicting motion rows rather than guess.

- [owner-and-midi-guide original PDF](midi-fighter-3d/owner-and-midi-guide.pdf) · [manufacturer download](https://drive.google.com/uc?export=download&id=0B-QvIds_FsH3OHhuZlpzVkM2QjQ) · 19 PDF pages; extracted text: [owner-and-midi-guide.txt](midi-fighter-3d/owner-and-midi-guide.txt).

## Extraction rules and limitations

SXM Note/CC addresses alone do not encode ports, startup handshakes, SysEx RGB/screen, pressure, per-template mappings or firmware state. Channel indexing varies between manuals; preserve original and normalized conventions explicitly.

Do not promote partial records to complete maps without resolving the explicit missing fields. The MIDI Fighter 3D motion-table inconsistency is visible in the original, not an extraction error. Neon tables use pp placeholders and contain suspected repeated-cell errors. Launch Control XL 3 changes encoder CC addresses when relative mode is enabled.

All PDFs remain unmodified; text files are page-numbered extraction aids and preserve imperfect source text. Manifest includes direct/download-landing URLs, local paths, byte counts, SHA-256, page count, source inspection index and failures. No mirrors are used as manufacturer evidence. A bounded follow-up added Faderfox EC4/UC4 and Korg nanoKONTROL2.

## Current app schema adaptation

Current ControllerProfile supports Kind note/controlChange, Encoding absolute7Bit/relativeTwosComplement/noteGate, Layer base/amber/green, Color red/amber/green, global channel plus configuration overrides. Source-ready does not mean directly representable: 63/65 relative-binary-offset encoders are not relativeTwosComplement; arbitrary banks/decks, RGB colors, multi-port/handshake, aftertouch and SysEx need schema adaptation or explicitly bounded subsets.

The five ready-for-extraction records are source-ready only. In particular, XL3 relative mode and Twister Enc 3FH/41H require binary-offset handling, while the application currently exposes relativeTwosComplement. Do not relabel these encodings merely to fit the enum.

## Additional manufacturer coverage

### Faderfox EC4 — partial

[Official source](https://www.faderfox.de/ec4.html). Owner/MIDI manual pp.6-7 feedback and special commands; pp.11-13 command/channel/address modes; p.15 factory table visually inspected.

- **input channel and address**: Factory setups1-14 use channel equal to setup number; encoder absolute CC and push Notes. Groups1/9 through8/16 have ascending16-address ranges; p.15 rightmost112-127 range is clipped in original PDF.
- **layers**: 16 setups and16 groups; setups15/16 specialized Ableton mappings; configurable controls and presets.
- **relative encoder**: CCr1 values1/127 and CCr2 values63/65 documented p.11; direction/acceleration must be checked before mapping to app encoding.
- **led output**: Incoming feedback updates encoder/display values; special setup/group/display/Shift SysEx commands referenced, but no byte-level description retrieved.
- **Gap / extraction constraint**: Original p.15 factory table extends beyond right page edge (visually verified), so do not silently repair clipped values. Special fixed SysEx description not linked by discovered current page. Ready subset: readable factory group ranges; full map requires resolving clipped table and special controls.

- [owner-and-midi-guide original](faderfox-ec4/owner-and-midi-guide.pdf) · [manufacturer download](https://www.faderfox.de/PDF/EC4%20Manual%20V03.PDF)

### Faderfox UC4 — ready-for-extraction

[Official source](https://www.faderfox.de/uc4.html). Owner/MIDI manual pp.6,8-10 control modes, feedback and command configuration; p.13 factory tables visually inspected.

- **input channel and address**: Factory setups1-16 use channel equal to setup; p.13 enumerates encoders, push buttons, green buttons and faders for8 groups. Group1: encoder CC8-15; push Note0-7; green Note64-71; faders CC32-39; fader9 CC112.
- **layers**: 8 groups,18 setups; special Ableton17/18 tables are grey-highlighted and distinct from generic setups1-16.
- **relative encoder**: CCr1 values1/127; CCr2 values63/65 (p.9). Absolute7-bit default; configurable acceleration and fader snap/jump.
- **led output**: External feedback uses same commands as corresponding buttons in external display mode; value feedback and display documented.
- **Gap / extraction constraint**: Source-ready for explicit generic factory setup subset. More than3 groups, special setups and configurable per-control channels require schema choices. CCr2 is binary-offset rather than twos-complement; highres CC/pitchbend/pressure are unsupported by current app.

- [owner-and-midi-guide original](faderfox-uc4/owner-and-midi-guide.pdf) · [manufacturer download](https://www.faderfox.de/PDF/UC4%20Manual%20V03.PDF)

### Korg nanoKONTROL2 — partial

[Official source](https://www.korg.com/us/support/download/product/0/159/). Parameter guide pp.4-9 CC mode and external LEDs; full MIDI Implementation revision1.00 sections1-4, especially339-byte scene parameter layout and Native KORG LED commands; one-page capability chart and owner manual inspected.

- **input channel and address**: Full message types and configurable channel/address fields documented: global channel0-15 and group channel0-16 (16=global) in scene dump; buttons Note/CC, knobs/sliders CC. Factory per-control address values are not enumerated in inspected sources.
- **layers**: CC mode versus Cubase/DP/Live/ProTools/SONAR modes;8 channel strips; per-group/transport MIDI channel settings. Do not confuse strip groups with bank layers.
- **relative encoder**: Physical knobs/sliders use absolute CC range values; no rotary relative encoder.
- **led output**: External LED mode matches assigned Note/CC and on/off values (parameter guide p.9). Native KORG LED SysEx and scene/request/dump protocol explicitly documented in TXT.
- **Gap / extraction constraint**: Protocol is detailed but full default control-number map still requires editor scene export or hardware capture. DAW modes can output pitchbend and use different protocols; do not treat capability chart as complete map.

- [midi-implementation original](korg-nanokontrol2/midi-implementation.txt) · [manufacturer download](https://cdn.korg.com/us/support/download/files/aeb2862daf0cb7db826d8c62f51ec28d.txt?response-content-disposition=attachment%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_MIDIimp.txt&response-content-type=application%2Foctet-stream%3B)
- [midi-chart original](korg-nanokontrol2/midi-chart.pdf) · [manufacturer download](https://cdn.korg.com/us/support/download/files/902f10b95c3bac3b52113b0d8799a9e7.pdf?response-content-disposition=inline%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_MIDI_Chart_E1.pdf&response-content-type=application%2Fpdf%3B)
- [owner-guide original](korg-nanokontrol2/owner-guide.pdf) · [manufacturer download](https://cdn.korg.com/us/support/download/files/b61f4da2e9b32e7825edc729e7d71a0d.pdf?response-content-disposition=inline%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_OM_EFGSCJ2.pdf&response-content-type=application%2Fpdf%3B)
- [parameter-guide original](korg-nanokontrol2/parameter-guide.pdf) · [manufacturer download](https://cdn.korg.com/us/support/download/files/c8d0cd6808e12d3672845cadcdbbfe9b.pdf?response-content-disposition=inline%3Bfilename%2A%3DUTF-8%27%27nanoKONTROL2_PG_E1.pdf&response-content-type=application%2Fpdf%3B)

