# Controller profile foundation

The first catalogue contains Allen & Heath Xone K1, K2 and K3, each pinned to profile version `1.0.0`. These are manufacturer-documented facts, not hardware-tested configurations. Euphonia and other models are deferred.

This delivery implements the shared data contract, validated bundled loader and complete MIDI address inventories. Profile selection, configured address resolution, mapping-row lookup, MIDI Learn overrides and device-configuration JSON persistence are the next steps; these are not yet exposed in the application interface.

## Catalogue

| Profile ID | Physical controls | Addressable actions | LED targets | Scope |
| --- | --- | --- | --- | --- |
| `allen-heath.xone-k1` | 52 | 58 | 34 | Documented fixed map; configurable global MIDI channel |
| `allen-heath.xone-k2` | 52 | 58 | 34 | Fixed map with five latching-layer modes |
| `allen-heath.xone-k3` | 52 | 58 | 34 | Factory map and explicit unresolved custom-map slots |

Encoder turns and pushes share a physical ID but have separate control IDs. Rows/columns are numbered from 1, top-to-bottom and left-to-right. Examples: `encoder.top.1.turn`, `encoder.top.1.push`, `pot.2.3`, `pot.switch.2.3`, `matrix.1.1`, `fader.1`. The bottom-right K1/K2 control retains the printed “EXIT SETUP” label; K3 calls this SHIFT.

Original documents, revisions and source discrepancies are recorded in [Xone K-series evidence](Xone-K-Series-Profile-Evidence.md). The resources retain source URLs, snapshot hashes and per-fact page/section locators.

## Contract

`ControllerProfileLibrary` loads a fixed bundled catalogue atomically. `profile(id:version:)` requires an exact pin. Missing versions raise an unavailable result; they never select a newer version. Malformed resources identify the resource filename and JSON field path. A missing/corrupt bundled file is a catalogue error, distinct from an unavailable document reference.

The separate profile schema is version 1; it does not change the existing SXM mapping JSON format. The profile data uses immutable Codable/Sendable records and a maximum of 1 MB/32 nesting levels per resource. Structural and reference validation checks IDs, evidence, modes, MIDI ranges and encoding compatibility. This is currently a curated bundled format, not a user profile importer; unknown object keys are not rejected by Codable.

- Global channel is human-numbered 1–16; the documented default is 15. No current hardware setting is inferred.
- `base` is the unlayered address, also used on the red first layer when that control participates in the selected layer mode. Amber/green sends are explicit addresses, including the bottom encoders’ CC68/69 exception.
- A mode lists the control groups that change addresses. Controls outside those groups retain base addresses. `reservedInModes` prevents treating the LAYER button as freely assignable while it controls hardware layers.
- Receive binding `color` identifies LED color. Its `layer` remains `base`: a color does not identify the current input layer. Runtime feedback interpretation must also honor the documented mode limitations.
- `valueMin`/`valueMax` are both present only when the cited source establishes a range. Missing bounds mean undocumented values, not an assumed full range. Momentary Note On/Off is recorded without invented velocity thresholds.
- K3 `factory` means hardware map 1. `custom-1`, `custom-2`, `custom-3` mean hardware map slots 2, 3, 4 and explicitly do not use factory bindings. They need supplied configuration before resolution.
- Source verification remains `manufacturer-documented`. Hashes identify archived bytes; they do not authenticate a manufacturer or establish hardware testing.

Profiles contain no Traktor command or deck assignment, and loading them does not alter mappings or controller hardware. Existing TSI preservation is unchanged.
