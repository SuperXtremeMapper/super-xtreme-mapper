# Euphonia profile evidence — initial checkpoint

Milestone 1 is integrated locally. This note prepares milestone 2; it is not an implemented controller profile or hardware verification.

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

The first acceptance case is resolving strip 1 LOW, finding matching mapping rows, and confirming the address with MIDI Learn. The UI must distinguish physical strip, MIDI channel, and assigned Traktor deck. A software mapping must not imply that the control's hardware audio behavior has been disabled.

No physical MIDI controller was available during the Traktor check. Hardware revision, configured MIDI channel, port names, operating-mode details, and audio-path caveats need further evidence before declaring the pilot verified. The detailed implementation plan remains the next step under the roadmap's separate-subsystem policy.
