# Xone:K1, K2 and K3 profile evidence

Official-source basis collected on 12 September 2026. As with Euphonia, manufacturer documentation is sufficient for the initial profile; physical testing is optional. The source packages below now back the [implemented profile foundation](Controller-Profiles.md); configured lookup and the application interface follow next.

## Source packages

| Model | Local documentation | MIDI reference | Provenance |
| --- | --- | --- | --- |
| Xone:K1 | [User guide AP9694 issue 2](controllers/xone-k1/sources/XoneK1_UG_AP9694_2.pdf) | Controls p.8; channel p.12; send/return diagrams pp.13–14; conversion p.15 | [Manifest](controllers/xone-k1/source-manifest.json) |
| Xone:K2 | [User guide AP8509 issue 3](controllers/xone-k2/sources/XoneK2_UG_AP8509_3.pdf) | Channel p.11; layers pp.12–13; send pp.14–16; return pp.17–18; conversion pp.19–20 | [Manifest](controllers/xone-k2/source-manifest.json) |
| Xone:K3 | [User guide text snapshot](controllers/xone-k3/sources/Xone-K3-User-Guide.txt) and [Editor Help text snapshot](controllers/xone-k3/sources/Xone-Controller-Editor-Help.txt) | Named sections: Global MIDI Channel, Latching Layers, Unit Maps, MIDI Implementation Default Send/Return | [Manifest](controllers/xone-k3/source-manifest.json) |

K1 and K2 are original downloaded PDFs. K3 is published as a web guide, with a “Print to PDF” option; the saved text is a retrieved snapshot, not a manufacturer-issued PDF. Original K3 MIDI diagrams are separately archived: [send 1](controllers/xone-k3/sources/midi-send-01.png), [send 2](controllers/xone-k3/sources/midi-send-02.png), [send 3](controllers/xone-k3/sources/midi-send-03.png), [return 1](controllers/xone-k3/sources/midi-return-01.png), [return 2](controllers/xone-k3/sources/midi-return-02.png). Manifests record original URLs, hashes, retrieval date and review scope. The K3 guide displays an update date of 23 June 2026; no numbered revision is inferred.

## Xone:K1 findings

The guide specifies default MIDI channel 15, configurable during setup. Top encoders send CC0–3; the four faders send CC16–19. Pots and faders use values 0–127; encoders use relative two’s-complement messages. Top-left encoder push is E3, decimal note 52. Return diagrams distinguish red, amber and green LED addresses from control sends. [Official guide](https://www.allen-heath.com/content/uploads/2023/07/XoneK1_UG_AP9694_2.pdf), pp.8,12–15.

Source discrepancy: the small lower conversion table on p.15 prints incorrect hex values alongside decimal 13–15. The upper matrix and ordinary hexadecimal conversion give 13=0D, 14=0E, 15=0F. Retain this discrepancy in provenance; use numeric bytes, not an unreviewed transcription. Do not import K2’s embedded latching-layer behavior into the K1 profile merely because layouts match.

## Xone:K2 findings

Default MIDI channel is 15. Five layer modes cover off, matrix switches, pot/encoder switches, all switches, and all controls. The all-controls mode includes soft pickup for pots/faders. Top-left encoder rotation is CC0 on red/base, CC22 on amber and CC44 on green when included in layers. The left fader uses CC16/38/60 respectively. Bottom encoders have separately documented addresses, including green CC68/69; do not extrapolate all addresses by one formula. [Official guide](https://www.allen-heath.com/content/uploads/2023/06/XoneK2_UG_AP8509_3.pdf), pp.11–18.

Use the active layer mode to decide which controls change addresses. Keep transmitted control messages and received LED messages separate. Numeric note identity takes priority over software-specific octave labels.

## Xone:K3 findings

The factory map is documented as K2-compatible; there are also three custom map slots. Default global channel is 15. Its send/return diagrams confirm the same example encoder and fader addresses above. Model factory-map compatibility explicitly rather than assuming it describes every K3 configuration. [Official user guide](https://support.allen-heath.com/hc/en-gb/articles/39744774067985-Xone-K3-User-Guide), Unit Maps and MIDI Implementation Default sections.

Custom maps can override individual MIDI channels and change control assignments and LED behavior. Remote LED mode and latching-layer configuration affect feedback interpretation. Accept a user’s editor-exported map or explicit local configuration as evidence of custom assignments; unknown custom configuration stays unresolved. [Official Editor Help](https://support.allen-heath.com/hc/en-gb/articles/39744832920081-Xone-Controller-Editor-Help), Global MIDI Panel, Unit Maps and LED Mode sections.

## Profile acceptance rules

- Separate model identity, document revision, MIDI channel, physical position, layer configuration and Traktor deck assignment.
- Pin manufacturer sources and retain per-fact section/page references. Document updates do not silently upgrade an existing profile pin.
- Test numeric addresses and ranges against the cited tables, including LED return addresses and mode-dependent exceptions.
- Treat all three as capable of documented MIDI feedback; Euphonia’s no-receive restriction does not apply to them.
- Mark sourced facts `manufacturer-documented`, never `hardware-tested`. Optional MIDI Learn can confirm or override a configured address.
- Preserve unknown controls or custom configurations as unresolved rather than substituting factory assumptions.

No application code or controller settings were changed while collecting these references.

## Implementation review additions

The K2 send diagram on p.14 misprints A#2 alongside Bb5 and Bb8 for pot switch row 2, column 3. Its return diagram on p.17 and conversion table support numeric notes 82 and 118. The K3 diagram supplies the corrected sharp labels.

K3 Specifications lists Note On/Off range 127/1, whereas Editor Help gives default press/release values of 127/0. The initial profiles therefore record momentary Note On/Off without asserting a universal release velocity. LED return diagrams establish addresses and colors, but not universal on/off velocity thresholds.

Hardware map 1 is the K3 factory map; the three custom maps occupy hardware slots 2–4. The profiles explicitly distinguish these from factory bindings.
