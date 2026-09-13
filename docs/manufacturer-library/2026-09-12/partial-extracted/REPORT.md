# Second documentation batch — all 21 candidates

All 21 original partial-evidence candidates have been extracted and bundled. Eight have partial numeric MIDI evidence; thirteen remain documentation only, with no invented controls. The batch retains 18,381 message/action variants, not 18,381 unique physical controls. Prior 26 runtime resources remain byte-identical.

| Model | Coverage | Binding records |
|---|---|---:|
| Akai Professional APC64 | documentation-only | 0 |
| Akai Professional MPD218 | documentation-only | 0 |
| AlphaTheta SLAB | partial | 765 |
| Hercules DJControl Inpulse 200 MK2 | documentation-only | 0 |
| Hercules DJControl Inpulse 200 MK3 | documentation-only | 0 |
| Hercules DJControl Inpulse 300 MK2 | documentation-only | 0 |
| Hercules DJControl Inpulse T7 / T7 Premium | documentation-only | 0 |
| Hercules DJControl Starlight | documentation-only | 0 |
| Native Instruments Traktor Kontrol F1 | documentation-only | 0 |
| Native Instruments Traktor Kontrol S2 MK3 | documentation-only | 0 |
| Native Instruments Traktor Kontrol S3 | documentation-only | 0 |
| Native Instruments Traktor MX2 | documentation-only | 0 |
| Native Instruments Traktor X1 MK3 | documentation-only | 0 |
| Native Instruments Traktor Z1 MK2 | documentation-only | 0 |
| Allen & Heath Xone:PX5 | partial | 12 |
| Faderfox EC4 | partial | 9408 |
| Korg nanoKONTROL2 | partial | 97 |
| Novation Launch Control XL MK1/MK2 | partial | 122 |
| DJ TechTools Midi Fighter 3D | partial | 348 |
| DJ TechTools Midi Fighter Twister | partial | 720 |
| Reloop Neon | partial | 6909 |

## What the labels mean

Partial MIDI coverage means only explicitly evidenced subsets are available. Conflicting source rows remain excluded and cited in each record's issues. Documentation only means manuals and setup instructions are available, but no physical-control addresses are established. Neither label means hardware tested. Numeric address lookup does not imply support for every value encoding, LED behavior, SysEx command or compound message.

The NI MIDI-mode support article was additionally archived and registered for S2 MK3, S3 and MX2. The catalogue now has 123 model/source references and 115 unique verified files; the initial research counts are retained separately. This setup evidence does not supply missing control maps.

## Important boundaries

Korg nanoKONTROL2 has evidence for its fixed Native KORG mode, not a recovered normal-scene factory map. Faderfox EC4 excludes clipped groups and special Ableton setups. Neon excludes inconsistent channel/range cells. SLAB excludes the contradictory E1 address. Midi Fighter source discrepancies remain recorded. Each extraction retains setup requirements, missing information, source hashes and exact evidence locators.

See [the machine-readable index](index.json), [validation results](validation.json), and [UI workflow](../UI-WORKFLOW.md). The source data is reproducibly converted into the app catalogue by `scripts/manufacturer-library/generate_profiles.py`.

Validation and app test results: [integration report](../PARTIAL-INTEGRATION.md).
