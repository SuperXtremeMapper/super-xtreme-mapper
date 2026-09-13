# Stage 1 — performance and inMusic evidence

These are documented extractions, not runtime profiles, compatibility claims or hardware-tested mappings. `extract.py` reproduces the JSON from the dated archive and explicit visual transcriptions. All source SHA-256 hashes were checked against the archived PDF bytes.

| Model | Normalized bindings | Coverage |
|---|---:|---|
| APC mini mk2 | 1,258 | Pad address range in three port/mode contexts; all sixteen RGB behavior channels; UI buttons, LEDs and faders; 128-color palette |
| APC40 mkII | 1,179 | Unambiguous Mode 1/2 input notes; primary absolute CCs and Mode 0 knob banks; RGB/mono LEDs and ring position/style; 128-color palette |
| LC6000 PRIME | 78 | All definite send buttons and encoders; jog/pitch compound pairs; scalar LED addresses |
| UC4 | 8,244 | Every assigned control in all eight groups across all eighteen factory setups; documented feedback assignments |
| Launch Control XL 3 | 223 | DAW physical controls, relative encoder variants, touch reports, LED feedback, feature set/query/reply |
| Launchpad Pro MK3 | 741 | Complete Programmer diagram addresses; input types and both Note/CC feedback variants |
| Launchpad X | 566 | Complete Programmer diagram addresses; input types and both Note/CC feedback variants |
| Launchpad Mini MK3 | 566 | Complete Programmer diagram addresses; input types and both Note/CC feedback variants |

Total: 12,855 normalized bindings. Counts include distinct setup, direction, mode and behavior variants; they are not physical-control counts. Eight complete protocol texts are retained with page markers (UC4's full manual is its sole protocol source), plus four rendered Novation mapping diagrams.

## Precise remaining work

- LC6000: Scrub CC upper/lower both equal 64 (0x40) in source; excluded. Palette decimal values are one greater than hexadecimal; RGB addresses preserved but every palette interpretation excluded. Wheel display SysEx unspecified.
- APC40: Cue Level input appears in both absolute and relative tables; excluded. Duplicate input CC24–31 and CC56–63 conflict with outbound ring-style definitions; excluded as input. Note65 Detail View / stray Metronome row ambiguous; excluded as input. Generic-mode note toggles/banks, SysEx transactions and detailed ring segment patterns remain raw.
- APC mini: Initialization response lists nine faders but declares four data bytes. RGB SysEx component pairing, inquiries and initialization remain raw. Note-mode addresses reflect the protocol chart, not an inferred scale/octave layout. Session input channel remains null with documented source range 0–15.
- UC4: Editable relative, high-resolution, pressure, pitch bend, program change and SysEx backup alternatives remain documented raw rather than factory assignments. Button upper/lower values are configurable and not replaced with assumed 127/0.
- Launchpads: DAW Session/Drum/Fader and custom layouts remain raw, as do SysEx lighting/configuration/scrolling/inquiry. Programmer input channels remain null because the address diagrams do not explicitly fix them. LED behavior channels are explicit 1/2/3. Palette swatches remain in authoritative PDFs, without guessed RGB values.
- XL3: Global-channel feature CC100 has inconsistent hexadecimal/decimal endpoints; excluded. Screen target IDs and bitmap terminators contradict other sections; screen/bitmap messages excluded. Auxiliary diagram CC104 has an unclear semantic label; excluded. Standalone mappings are editable. Feature-mode values use the coherent p17 table; p10 overlap remains an issue.

Validation checked all 12,855 address/channel bounds, IDs, evidence references, raw-file existence and original PDF hashes. No runtime integration or hardware verification was performed.
