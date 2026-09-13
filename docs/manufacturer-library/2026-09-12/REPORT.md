# DJ controller manufacturer documentation library

**Collection and assessment: 12 September 2026**

The library now covers **68 model records across 15 manufacturers**, with **88 newly downloaded official PDFs**, four previously archived PDFs reused, and official web/text/diagram sources. There are **114 unique model-referenced source files** (about 536 MiB), each checked against its recorded SHA-256. Shared manuals are counted once as files, even when used by several models. Some records cover closely related variants; this is not 68 separately validated hardware SKUs.

**26 records have documentation suitable to begin extraction; 21 have partial evidence; 21 have a protocol gap.** Three of the extraction-ready records are the already implemented Xone K1/K2/K3 profiles. Euphonia reuses its earlier source archive and remains unimplemented. These grades describe evidence, not working SXM support.

## Deliverables

- [Full model index](MODEL-INDEX.md): every model, assessment and direct links to its archived source documents and manufacturer originals.
- [CSV catalogue](catalogue.csv): sortable model list, findings, gaps and source links.
- [JSON catalogue](catalogue.json): structured metadata, provenance, hashes, coverage and evidence locators.
- [Archive verification](verification.json): file/hash verification results and exact counts.
- Detailed evidence reports: [Pioneer DJ / AlphaTheta](pioneer-alphatheta/group-report.md), [Native Instruments / Hercules / Allen & Heath](ni-hercules-ah/group-report.md), [Rane / Denon DJ / Numark / Akai](inmusic/group-report.md), [Novation / Reloop / Roland / DJ TechTools / Faderfox / Korg](performance/group-report.md).

## What “top” means here

This is an editorial shortlist for SXM coverage: prominent flagship controllers, accessible entry models, widely encountered legacy generations, club mixers/players and useful modular MIDI surfaces. Manufacturer product/support listings establish model identity and documentation availability. No sales data was collected, so this is **not a market-share or bestseller ranking**, and a support listing does not prove a product is currently on sale.

Pioneer DJ and AlphaTheta retain their product branding in the index but share one research group. Keyboard/synthesizer ranges, pure audio interfaces, speakers, headphones and turntables without relevant control functionality are outside this pass. Current-generation additions found during research include NI MX2, Hercules Inpulse 200 MK3, AlphaTheta CDJ-3000X/SLAB and Novation Launch Control XL 3.

## Coverage by manufacturer

A = extraction candidate; B = partial evidence; C = protocol gap. These are practical triage labels, not numerical quality scores. A can be a clearly bounded subset; it never means every control or feedback feature is supported. B includes configurable templates or unresolved chart conflicts. C means the acquired documentation does not establish the wire map, including native/proprietary-only cases. “Not found” is bounded to this search and acquired corpus, not a claim that a private specification cannot exist.

| Manufacturer | Models in this collection | A / B / C |
|---|---|---|

| Akai Professional | APC mini mk2, APC40 mkII, APC64, MPD218 | 2 / 2 / 0 |
| Allen & Heath | Xone:92 Mk2, Xone:96, XONE:K1, XONE:K2, XONE:K3, Xone:PX5 | 5 / 1 / 0 |
| AlphaTheta | CDJ-3000X, DDJ-GRV6, Euphonia, OMNIS-DUO, SLAB, XDJ-AZ | 5 / 1 / 0 |
| DJ TechTools | Midi Fighter 3D, Midi Fighter Twister | 0 / 2 / 0 |
| Denon DJ | LC6000 PRIME, PRIME 4+, PRIME GO+, SC LIVE 4, SC6000 PRIME, X1850 PRIME | 1 / 0 / 5 |
| Faderfox | EC4, UC4 | 1 / 1 / 0 |
| Hercules | DJControl Inpulse 200 MK2, DJControl Inpulse 200 MK3, DJControl Inpulse 300 MK2, DJControl Inpulse 500, DJControl Inpulse T7 / T7 Premium, DJControl Starlight | 1 / 5 / 0 |
| Korg | nanoKONTROL2 | 0 / 1 / 0 |
| Native Instruments | Traktor Kontrol F1, Traktor Kontrol S2 MK3, Traktor Kontrol S3, Traktor Kontrol S4 MK3, Traktor MX2, Traktor X1 MK3, Traktor Z1 MK2 | 0 / 6 / 1 |
| Novation | Launch Control XL 3, Launch Control XL MK1/MK2, Launchpad Mini MK3, Launchpad Pro MK3, Launchpad X | 4 / 1 / 0 |
| Numark | Mixtrack Platinum FX, Mixtrack Pro FX, NS4FX, NS6II | 0 / 0 / 4 |
| Pioneer DJ | DDJ-FLX10, DDJ-FLX4, DDJ-REV5, DDJ-REV7, DJM-A9, DJM-S11, XDJ-RX3 | 7 / 0 / 0 |
| Rane | FOUR, ONE, PERFORMER, SEVENTY-TWO MKII, TWELVE MKII | 0 / 0 / 5 |
| Reloop | Buddy, Mixon 8 Pro, Neon, Ready | 0 / 1 / 3 |
| Roland | DJ-202, DJ-505, DJ-808 | 0 / 0 / 3 |

## What has the information we need?

**The strongest broad controller coverage is Pioneer DJ / AlphaTheta.** All 12 newly assessed models have both an owner manual and a separate MIDI list archived. The charts connect numbered physical controls to message bytes, channel/mode conditions and, where supplied, return messages. DJM-A9 and CDJ-3000X offer documented input/transmit subsets; their acquired charts do not establish complete host LED/screen control. SLAB is conservatively partial because a mode-button channel column conflicts with the status byte. See the [DDJ-FLX4 chart](https://downloads.support.alphatheta.com/software_info/dj-controllers/DDJ-FLX4/DDJ-FLX4_MIDI_message_List_E1.pdf) and the [group’s per-model evidence](pioneer-alphatheta/group-report.md).

**Novation and Akai provide useful programmer-level documentation.** Launchpad Pro MK3, X, Mini MK3 and Launch Control XL 3 have detailed references. APC40 mkII and APC mini mk2 have communication protocols as well as acquired user guides. Fixed modes are good extraction targets; custom templates, port distinctions, initialization and RGB behavior require explicit treatment. Source-ready does not mean their full functionality fits SXM today. [Novation evidence](performance/group-report.md), [APC40 mkII protocol](https://cdn.inmusicbrands.com/akai/attachments/apc40II/APC40Mk2_Communications_Protocol_v1.2.pdf), [APC mini mk2 protocol](https://cdn.inmusicbrands.com/akai/attachments/APC%20mini%20mk2%20-%20Communication%20Protocol%20-%20v1.0.pdf).

**Allen & Heath remains a sensible next step for straightforward profiles.** Xone:92 Mk2 has a small documented transmit map; Xone:96 has an official numeric send/receive matrix. The 96’s PDF links failed, but the full official HTML guide and MIDI tables were saved. PX5 has useful CC evidence but conflicting note-octave conventions that must be resolved before numeric Note bindings are trusted. The K-series archive and implemented profiles remain intact. [Xone:96 implementation](https://support.allen-heath.com/hc/en-gb/articles/43084536824849-Xone-96-MIDI-Implementation), [A&H evidence](ni-hercules-ah/group-report.md).

**Hercules Inpulse 500 and Denon LC6000 are particularly useful additions.** Inpulse 500 has a detailed 14-page MIDI chart, including Shift/modes, encoder behavior and feedback. LC6000 has a dedicated implementation specification; start with the unambiguous transport/pad/encoder subset. Its double-precision controls, wheel display and inconsistent palette/needle-drop entries need separate handling. [Hercules evidence](ni-hercules-ah/djcontrolinpulse500/manifest.json), [LC6000 specification](https://cdn.inmusicbrands.com/denondj/lc6000/LC6000-PRIME-MIDI-Specification-v1.0.pdf).

**Faderfox UC4 is a useful compact-surface candidate.** Its factory generic layout can be extracted; EC4 remains partial because the archived factory table is clipped and additional SysEx material is outstanding. MIDI Fighter Twister/3D, Reloop Neon, legacy Launch Control XL and Korg nanoKONTROL2 have valuable evidence but still need precise template, encoding or source-conflict resolution. [Performance-controller evidence](performance/group-report.md).

**Owner manuals alone are insufficient for many Rane, Numark, Roland, standalone Denon and Reloop controllers.** They establish controls and operational modes, but the retrieved sources do not supply complete per-control MIDI/feedback maps. The manuals are still useful for explanations, control naming and future diagrams. They must not be turned into invented MIDI addresses. All selected Rane owner manuals were ultimately acquired, including TWELVE MKII. [inMusic evidence](inmusic/group-report.md), [Roland/Reloop evidence](performance/group-report.md).

**Native Instruments needs special care.** The S4 MK3 should not be treated as a generic MIDI controller: a named NI employee explicitly confirms that it has never supported MIDI. Other acquired NI manuals establish MIDI modes or configurable Controller Editor behavior, but not enough fixed numeric bindings for complete profiles. In particular, F1 native/User Map operation and ordinary MIDI must be distinguished; a pinned template is necessary. [NI evidence and exact source locators](ni-hercules-ah/s4-mk3/manifest.json), [F1 evidence](ni-hercules-ah/f1/manifest.json).

## Evidence fields required before a profile is accepted

For every control/action, retain the physical label/location; model and hardware/document revision; applicable mode/bank/layer; port and MIDI channel convention; input message kind/address/value encoding; separate receive message/address/value behavior; evidence page/section; and explicit unknowns. Encoder push and turn can be different actions on the same physical control. A hardware bank, LED color and Traktor deck are different things.

Preserve factory versus custom configuration. Record zero-based source channels alongside human channels1–16. Use numeric Note bytes rather than assuming an octave naming convention. Source-direction labels also vary: Pioneer often calls device→computer “MIDI-IN,” whereas SXM calls that device send. Never infer LED receive messages from input messages alone.

## App-format work revealed by this audit

The current profile schema is sufficient for the implemented K-series, but it is not yet a universal MIDI-device description. It permits Note/CC bindings, absolute7Bit/two’s-complement/noteGate encodings, three layer values (base/amber/green) and three colors. Bindings do not carry their own independent channel/mode fields; configured global channels and contextual overrides serve the existing profiles. Mode metadata can already have arbitrary IDs, but generalized per-binding routing is a separate need.

Before claiming broad support, extend or explicitly bound:

1. Independent per-action channels/ports and arbitrary bank/Shift/mode routing.
2. Encoder encodings beyond two’s-complement: centered/binary-offset, signed-bit and speed-valued jog messages are not interchangeable.
3. Paired high-resolution CCs. A two-byte control cannot be represented as two unrelated knobs without losing meaning.
4. RGB palettes, LED animations, rings and output values that differ from input behavior.
5. SysEx initialization/feedback, aftertouch, MIDI clock and HID/proprietary integrations. These may remain intentionally unsupported, but the profile must say so.

This does not prevent useful smaller profiles: exclude unsupported features explicitly and preserve source facts for later. It does prevent labeling the entire controller supported just because its Play button is mapped.

## Source discrepancies worth resolving

- SLAB E1: decimal channel1 conflicts with status96/channel7 for both unshifted and shifted rows; visually confirmed in the original PDF.
- Xone:PX5: MIDI mapping and conversion tables use conflicting octave-zero conventions.
- Inpulse500: source anomalies are recorded in its manifest rather than silently fixed.
- LC6000: inconsistent decimal/hex palette numbering and repeated Needle Drop CC byte in the double-precision table.
- Midi Fighter3D: motion table contradicts earlier prose; Twister mixes channel-numbering conventions across sections.
- Reloop Neon: encoder values are placeholders rather than a defined direction encoding; some repeated addresses need confirmation.

These are review items, not evidence that the devices are defective. The original bytes remain unchanged. Detailed locators are in the per-model manifests.

## Recommended next sequence

1. **Prepare a richer intermediate evidence table** before expanding bundled profiles. Keep source facts independent of SXM’s current enum restrictions.
2. **Extract Xone:92 Mk2 and Xone:96** as small, well-documented additions with explicit transmit/receive scope.
3. **Extract Inpulse500 and a DDJ-FLX4 subset**, exercising Shift, channels, relative encodings and high-resolution exclusions.
4. **Add UC4, APC and Launchpad fixed-mode subsets**, then expand RGB/template behavior deliberately.
5. **Resolve documentation gaps** for NI templates, Rane/Numark/Roland and the remaining standalone controllers. Manufacturer clarification or known configuration exports are preferable; hardware capture is a fallback when documentary evidence is insufficient, not a requirement for all profiles.

This is a suggested extraction order, not a change to the user’s earlier feature priorities. Euphonia and other profile implementation remain deferred until chosen. No controllers were connected or configured, no firmware was installed, and this work adds source documentation rather than application support.

## Remaining collection limits

This is a broad first library, not every manufacturer or model ever released. Additional legacy DDJ/SX/SZ ranges, DJM-V10, newer support-list models, Behringer, Vestax and discontinued specialist MIDI brands merit later passes if they match user demand. Missing protocol documents may exist outside the public resources found here. No sales, shipping-stock or hardware verification claim is made.

HTTP failures and unsuccessful candidate URLs are retained in the group manifests/logs. Current manufacturer download links recovered several old links; DDJ-REV7 uses the currently linked E2 MIDI chart rather than the older indexed E1. Original owner manuals, protocol PDFs and HTML/text fallbacks were inspected, not merely counted from search snippets. Hash checks establish archive integrity, not accuracy of manufacturer claims.

The optional deeper-research pipeline could not run because its required Exa key was absent. This deliverable instead uses direct official-site discovery, raw file acquisition, document inspection, a normalized catalogue, mechanical hash verification and a scoped second-agent source check. It does not claim completion of that pipeline or an independent-provider review.

