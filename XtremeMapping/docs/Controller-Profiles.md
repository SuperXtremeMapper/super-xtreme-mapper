# Controller profiles

The bundled catalogue now contains 47 entries at exact version `1.0.0`: the unchanged first 26, eight additional profiles with partial MIDI coverage, and thirteen documentation-only entries. See [the second-batch report](../../docs/manufacturer-library/2026-09-12/partial-extracted/REPORT.md). This establishes documented address lookup, not hardware testing or automatic configuration. See [the integration report](../../docs/manufacturer-library/2026-09-12/INTEGRATION.md) for coverage and [DJ controller priorities](../../docs/manufacturer-library/2026-09-12/DJ-CONTROLLER-PRIORITIES.md) for the next list review.

The editor now offers device-scoped profile selection, configured control lookup, mapping-row navigation, explicit or learned address overrides, JSON persistence and Undo. Open **Controller…** above the mapping table and choose the mapping device to configure.

## Existing K-series catalogue

| Profile ID | Physical controls | Addressable actions | LED targets | Scope |
| --- | --- | --- | --- | --- |
| `allen-heath.xone-k1` | 52 | 58 | 34 | Documented fixed map; configurable global MIDI channel |
| `allen-heath.xone-k2` | 52 | 58 | 34 | Fixed map with five latching-layer modes |
| `allen-heath.xone-k3` | 52 | 58 | 34 | Factory map and explicit unresolved custom-map slots |

Encoder turns and pushes share a physical ID but have separate control IDs. Rows/columns are numbered from 1, top-to-bottom and left-to-right. Examples: `encoder.top.1.turn`, `encoder.top.1.push`, `pot.2.3`, `pot.switch.2.3`, `matrix.1.1`, `fader.1`. The bottom-right K1/K2 control retains the printed “EXIT SETUP” label; K3 calls this SHIFT.

Original documents, revisions and source discrepancies are recorded in [Xone K-series evidence](Xone-K-Series-Profile-Evidence.md). The resources retain source URLs, snapshot hashes and per-fact page/section locators.

## Contract

`ControllerProfileLibrary` loads a fixed bundled catalogue atomically. `profile(id:version:)` requires an exact pin. Missing versions raise an unavailable result; they never select a newer version. Malformed resources identify the resource filename and JSON field path. A missing/corrupt bundled file is a catalogue error, distinct from an unavailable document reference.

The separate bundled profile schema supports versions 1 and 2; the existing K-series files remain version 1. Device configuration is exported using SXM mapping JSON version 2; documents without device configuration still export version 1. The profile data uses immutable Codable/Sendable records and a maximum of 12,000,000 bytes/32 nesting levels per resource and 64,000,000 bytes/64 resources per catalogue. Structural and reference validation checks IDs, evidence, modes, MIDI ranges and encoding compatibility. This is currently a curated bundled format, not a user profile importer; unknown object keys are not rejected by Codable.

- Global channel is human-numbered 1–16; the documented default is 15. No current hardware setting is inferred.
- `base` is the unlayered address, also used on the red first layer when that control participates in the selected layer mode. Amber/green sends are explicit addresses, including the bottom encoders’ CC68/69 exception.
- A mode lists the control groups that change addresses. Controls outside those groups retain base addresses. `reservedInModes` prevents treating the LAYER button as freely assignable while it controls hardware layers.
- Receive binding `color` identifies LED color. Its `layer` remains `base`: a color does not identify the current input layer. Runtime feedback interpretation must also honor the documented mode limitations.
- `valueMin`/`valueMax` are both present only when the cited source establishes a range. Missing bounds mean undocumented values, not an assumed full range. Momentary Note On/Off is recorded without invented velocity thresholds.
- K3 `factory` means hardware map 1. `custom-1`, `custom-2`, `custom-3` mean hardware map slots 2, 3, 4 and explicitly do not use factory bindings. They need supplied configuration before resolution.
- Source verification remains `manufacturer-documented`. Hashes identify archived bytes; they do not authenticate a manufacturer or establish hardware testing.

Profiles contain no Traktor command or deck assignment, and loading them does not alter mappings or controller hardware. Existing TSI preservation is unchanged.

## Using profiles in the editor

1. Open **Controller…** and choose a mapping device. Select a controller, then confirm its MIDI channel, operating/layer mode, unit map and any documented port used by your hardware. K-series channel 15 is the documented default, not a detected setting. New profiles identify their documented default or explicitly label the initial channel as a value to confirm. Fixed binding channels take precedence over this setting.
2. Search for a physical control and select its input or LED feedback direction. For K2 all-controls mode, first fader on green resolves to CC60; in off mode it resolves to CC16. K3 host feedback requires an explicit Remote LED-mode selection.
3. The preview lists matching actions with their Traktor deck, direction and modifier conditions. **Apply & Show Mappings** records the profile and displays matching rows; **Show All Mappings** clears that view. Profile selection never changes row MIDI or command assignments.
4. To record a custom address, enter Note/CC, channel and number, or use **MIDI Learn** for an input control. Learn listens to all connected MIDI inputs: move only the intended control. Review **Use Captured Address** before accepting it into the draft. The final **Apply Profile** records the draft as one undoable change. Cancel discards it.
5. Use **Export JSON** to retain profiles and overrides. Import JSON reviews the saved configuration and opens it in a new document. Saving only TSI retains mapping data but cannot retain these SXM annotations.

Overrides are specific to device/profile, unit map, operating/layer mode, lookup layer, documented port and direction. Switching context retains other overrides without applying them to the new context. Their explicit MIDI channel can differ from the global channel. An override confirms one address; it does not prove all custom-map behavior or LED thresholds. MIDI Learn is not used to infer LED return addresses from input messages.

Exact unavailable profile pins and unsupported future configuration strings remain in imported JSON with actionable warnings. They do not stop generic mapping use or cause automatic upgrades. Removing a device profile retains unrelated and legacy metadata.

Legacy v1 `physicalControls` and `localOverrides` annotations remain preserved. They lack the context needed by configured lookup, so they are not automatically converted or applied by the resolver. Reconfirm the physical control and context in this interface before creating a v2 override.


## Version 2 representation and coverage

Bindings can specify a fixed channel, operating mode and logical MIDI port. Missing channel uses the explicitly confirmed document configuration. Missing mode/port is unrestricted; it does not infer a device mode or auto-detect hardware. Ports are documented protocol port identities, not OS input names; the mapping device's actual input/output routing remains independently configured.

Compound messages preserve their components and source semantics. They never become a single guessed Note/CC or a collection of independently actionable scalar controls. Unsupported messages remain visible as **Documented only**. Ordinary Note/CC bindings provide **Address lookup**, including when their value encoding or lighting behavior needs device-specific interpretation. Address lookup finds mapping rows; it does not generate initialization, palette values, SysEx, or high-resolution TSI behavior.

Source context and values are retained per binding. Where a model lacks a reliably standardized operating-mode model, the picker uses **Documented contexts** and control variants retain literal mode/Shift/deck descriptions. A match is a candidate physical action with its documented condition, not detection of the controller's live state. Shared controls are not incorrectly excluded by invented operating modes.

The sheet filters actions by selected mode, port and direction and provides searchable, virtualized rows. Coverage counts refer to documented bindings/action variants, not unique physical controls. Expand coverage notes for model limitations, or message details for original semantics. Missing/contradictory source rows remain excluded with cited limitations.

The catalogue is validated once and cached for the main application bundle. Control IDs are indexed for explanation lookups. JSON profile annotations and port-scoped overrides preserve their context across export/import; TSI preservation and native mapping commands remain unchanged. An explicit user-supplied scalar override is separate evidence and can be used without claiming it reconstructs a documented compound protocol.

## Partial and documentation-only coverage

Schema 2 optionally declares `coverageState` as `partial` or `documentationOnly`. A documentation-only profile must have no controls and must retain coverage notes and limitations. Other profiles require controls. The UI labels both states explicitly; documentation-only selection offers sources and MIDI Learn guidance without a fictitious control list or channel configuration. Assistant snapshots retain this limitation. See [current and intended workflow](../../docs/manufacturer-library/2026-09-12/UI-WORKFLOW.md).
