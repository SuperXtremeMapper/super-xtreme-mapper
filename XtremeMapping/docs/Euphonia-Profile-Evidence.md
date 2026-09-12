# Euphonia profile evidence — manufacturer-documented basis

Milestone 1 is integrated locally. Per the user’s 12 September 2026 direction, the Euphonia pilot uses official manufacturer documentation as its acceptance basis. Physical testing is optional supplementary evidence and does not block the profile. This note records the source basis; the profile subsystem is not yet implemented.

## Verified manufacturer references

The [AlphaTheta MIDI message list E10](https://downloads.support.alphatheta.com/software_info/dj-mixers/euphonia/euphonia_MIDI_Message_List_E10.pdf), pages 2–3, identifies strip LOW controls as follows. Status B0 denotes a control change on human MIDI channel 1; control numbers below are decimal conversions of the documented hexadecimal bytes.

| Physical control | Reference | CC | Value range |
| --- | --- | --- | --- |
| Strip 1 LOW | CH1/C5 | 4 | 0–127 |
| Strip 2 LOW | CH2/C5 | 9 | 0–127 |
| Strip 3 LOW | CH3/C5 | 21 | 0–127 |
| Strip 4 LOW | CH4/C5 | 82 | 0–127 |

These strip numbers are physical mixer positions, not Traktor deck assignments. The documented B0 status should not be treated as proof of the user's current hardware configuration.

AlphaTheta's [MIDI connection statement](https://support.alphatheta.com/en-us/articles/29298607838361) says the mixer transmits control messages and MIDI clock but does not accept MIDI input. The profile must therefore identify software-driven MIDI feedback as unsupported.

## Integration requirements from the agreed design

Use a versioned profile separate from mapping templates. Resolve profile pins explicitly; retain unknown versions without substituting newer ones. Attach physical-control references and local learned overrides through the existing `SXMJSONMetadata` contract. Keep manufacturer documentation and observed hardware evidence distinct.

The first acceptance case is resolving strip 1 LOW from message-list page 2 and finding matching mapping rows. MIDI Learn remains an optional way to record a local override; hardware capture is not required to accept manufacturer-documented addresses. The UI must distinguish physical strip, MIDI channel, and assigned Traktor deck. A software mapping must not imply that the control's hardware audio behavior has been disabled.

## Local source package

- [Instruction manual DRI1891A, 66 pages](controllers/euphonia/sources/euphonia_DRI1891A_manual.pdf): page 45 covers USB/MIDI; page 27 documents the channel EQ audio function.
- [MIDI Message List E10, four pages](controllers/euphonia/sources/euphonia_MIDI_Message_List_E10.pdf): page 1 locates physical controls; pages 2–4 specify addresses, values, and selector behavior.
- [Source manifest](controllers/euphonia/source-manifest.json): original URLs, document revisions, retrieval date, page counts, reviewed pages, and SHA-256 hashes.

The manual’s page 45 explicitly directs readers to the support site for detailed MIDI messages. These two publications therefore form a complementary reference, rather than two independent confirmations of every address. Both PDFs were downloaded from AlphaTheta’s official download host; table pages and relevant manual pages were visually inspected.

## Interpretation rules for the profile

- The manual confirms USB control of software and continuous MIDI timing clock (page 45).
- The message list specifies selector transitions as previous selection off, new selection on (page 4). Do not model selectors as a single ordinary knob value.
- Channel EQ changes hardware audio by -26 to +6 dB (manual page 27). A Traktor assignment does not establish that this audio action is bypassed; that would require separate evidence.
- Preserve the distinction between note and CC messages even when their numeric addresses coincide. Treat clock separately from channel control messages.
- Use `manufacturer-documented` for sourced facts. Do not label document review as `hardware-tested`, infer firmware compatibility from a document revision, or invent observed port names.

This supersedes earlier roadmap language requiring a physical address confirmation for the Euphonia pilot. The detailed implementation plan should retain optional learned overrides but use source review, address/range tests, and profile lookup tests as the release gate. No physical equipment is required to continue.
