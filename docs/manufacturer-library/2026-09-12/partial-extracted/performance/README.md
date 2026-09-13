# Performance partial manufacturer extraction

Stage-2 evidence only; no hardware validation or application integration. Counts retain bank, setup, template, mode and direction contexts. SysEx controls are protocol bindings, not physical controls.

| Model | Normalized bindings | Issues |
|---|---:|---:|
| DJ TechTools Midi Fighter 3D | 348 | 7 |
| DJ TechTools Midi Fighter Twister | 720 | 4 |
| Faderfox EC4 | 9408 | 3 |
| Korg nanoKONTROL2 | 97 | 2 |
| Novation Launch Control XL MK1/MK2 | 122 | 3 |
| Reloop Neon | 6909 | 35 |

Run `python3 extract.py` in this directory to reproduce this batch. Every source hash is verified before extraction. All source documents have complete local text copies in raw/, preserving page markers or the original unpaginated text structure. Original PDFs remain authoritative. Specific missing information, setup provenance, quarantined cells and coverage scope are recorded in each model JSON.
