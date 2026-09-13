# DJM-S7 / SXM 1.0.0 / Traktor Pro 4 import diagnosis

The primary defect is SXM's reuse of mapping binding IDs across rows assigned to the same MIDI message. The supplied Traktor re-export contains exactly the first row for every distinct binding ID in the SXM export. This accounts for all 54 missing mappings, without a command-support hypothesis.

Analysis was performed against repository commit `3bb1aaf` and the two supplied files. During the original diagnostic pass, no application code or original TSI was changed. No new live Traktor import was performed; the user's supplied re-export is the observed import result.

## Inputs and measured difference

Both files contain one controller device with the same device comment.

| File | Role | Mapping rows | Distinct CMAI binding IDs |
|---|---|---:|---:|
| `b5fdec89-8779-4b0b-9e2a-e47c94969483.tsi` | SXM export | 94 | 40 |
| `Settings2(1).tsi` | Reported Traktor re-export | 40 | 40 |

| Command | Raw command ID | SXM | Traktor | Dropped |
|---|---:|---:|---:|---:|
| Select/Set+Store Hotcue | 2328 | 16 | 16 | 0 |
| Delete Hotcue | 2331 | 16 | 16 | 0 |
| Modifier #1 | 2548 | 4 | 4 | 0 |
| Modifier #2 | 2549 | 4 | 4 | 0 |
| Modifier #3 | 2550 | 4 | 0 | 4 |
| Modifier #4 | 2551 | 4 | 0 | 4 |
| Slot Mute On | 259 | 28 | 0 | 28 |
| Slot FX On | 239 | 12 | 0 | 12 |
| FX Unit 1 On | 321 | 3 | 0 | 3 |
| FX Button 2 | 371 | 3 | 0 | 3 |

SHA-256 of SXM input: `8db542c85557b3a562d28a064523982c82ae3e510259f2ced2b684551afed10d`.

SHA-256 of Traktor input: `94eeaf6efd7a00d979d921cc0f07a55904414691ce758ed2256e4fdf9c2fd84c`.

## 1. Mapping ID reuse explains every dropped row

`TSIWriter.swift:577` implements `bindingIds(for:)` as a dictionary keyed by MIDI control name. `buildCMAI` retrieves that shared ID for every row using the same control. `buildDCBM` emits just one binding entry per distinct control name.

For example, binding ID 32 is used first by Modifier #1 and then by Modifier #3. The first survives and the second disappears. IDs 36–39 similarly pair Modifier #2 with #4. All the missing slot/FX rows reuse IDs already occupied by earlier hotcue rows.

An independent binary decode and comparison verified that taking the first SXM row for each binding ID reproduces the complete set of 40 retained rows, comparing binding ID, direction, command ID and comment. Every one of the 54 dropped rows is a subsequent occurrence of an existing ID. The Modifier #3/#4 settings use the same indexed-selector profile as the surviving #1/#2 entries; they are not the older malformed modifier profile already handled by SXM.

Independent supporting evidence:

- The repository's native Traktor 4.5.1 outputs/comments/modifiers fixture has eight rows with eight different IDs, despite using just four MIDI names. Each repeated MIDI name has separate binding entries.
- CMDR explicitly allocates a new ID for each inserted mapping in [Device.cs](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Device.cs#L233), then attaches the MIDI binding to that mapping.

**Required fix:** allocate IDs per mapping row within each device and emit matching per-row DCBM bindings, allowing the same MIDI name in multiple bindings. MIDI control definitions in DCDT are a separate concern and may remain shared where appropriate. Include input/output rows sharing a MIDI control, copied rows, multiple modifier actions and multi-command pad macros in regression coverage. Do not fix this merely by expanding the command whitelist or changing the slot IDs.

## 2. Modifier conditions are also being lost

All 32 surviving hotcue/delete mappings had conditions in the SXM file. All 32 have both condition triples cleared to zero in the Traktor file. Consequently, “the row appears” does not establish that its mode/shift gating survived.

The SXM file writes condition IDs `1`, `2`, `3`, `4` for M1–M4. `TSIWriter.swift:989` writes the model's modifier number directly into the condition ID field. `TSIInterpreter.swift:1044` also treats the raw condition ID as the model's modifier number.

The TSI condition identifiers for M1–M4 are `2548`, `2549`, `2550`, `2551`, respectively, as recorded in [CMDR's condition definitions](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Conditions/Interpretation/KnownConditions.cs#L303). SXM conflates the UI modifier number with the on-disk condition identifier.

**Required fix:** translate modeled M1–M8 to/from their wire condition IDs at the serialization boundary while retaining unknown and non-modifier condition identities. Audit preservation/edit paths as well as canonical writing. Correct the format documentation, which currently describes this field as 0–8. Validate mode gating after import, not only row counts.

## 3. Additional value-encoding defects need separate validation

- **Delete Hotcue:** the 16 rows survive, but every raw SetValueTo becomes `0xFFFFFFFF` on re-export. SXM wrote float encodings of 0–7 and the generic button profile. Its selector special case covers command 2328 and modifiers but omits command 2331 (`TSIWriter.swift:1132`; matching omission in the interpreter at line 1036). CMDR defines Delete Hotcue as an enum-valued hotcue command. The attached files prove that the selected values were not preserved. Capture a native Delete Hotcue reference to establish the entire correct profile and verify actual deletion targets.
- **Slot FX On:** `setValueRaw` hard-codes command 239 to integer 1. All 12 supplied rows contain 1, including rows whose comments describe FX OFF. Comments alone do not prove what value the user selected, but the code cannot emit an OFF value through this canonical path. Fix using a native reference for both ON and OFF.
- **Slot Mute On:** the supplied Direct rows encode ON as float bits `0x3F800000`. Its full boolean/selector profile should be compared with a native Direct ON/OFF export. These settings are secondary to the ID collision and cannot be established as the cause of the observed row losses.

## 4. LEGACY / UNKNOWN FX labels are a separate catalog issue

`TraktorCommands.descriptor(for:)` labels known commands LEGACY when the local evidence catalog has no supported direction. UNKNOWN means the numeric ID lacks a catalog name. These labels describe SXM's evidence, not a rejection verdict from Traktor.

ID 371 (`FX Button 2`) appears in the attached file and has a known name, but is absent from the current direction-evidence sets, so it is classified LEGACY. The writer still writes its positive stored numeric ID. Its three rows in this example disappear with the same duplicate-ID pattern as the other missing rows.

Neither attachment contains an unnamed command ID under the current catalog. A specific older source TSI or numeric ID is needed to diagnose any additional UNKNOWN FX commands. Do not rename or replace unknown numeric IDs based only on their badge.

## Verification and acceptance criteria

The binary comparison validated bounded frame traversal and asserted the 94-to-40 row counts, exact first-occurrence correspondence and clearing of all 32 surviving conditioned rows. The accompanying `2026-09-09-djm-s7-evidence.json` records every dropped row and its decoded fields.

After implementation, perform an actual Traktor import/re-export of a corrected copy and require all 94 mappings to remain, M1–M4 conditions to retain their identities/values, hotcue deletion to target the intended cue, and slot ON/OFF values to remain distinct. An SXM-only read/write round trip is insufficient: its reader and writer share several of the same assumptions.


## Implementation and verification

The subsequent fix allocates per-row binding IDs, accepts repeated MIDI names
under distinct bindings, translates modifier condition IDs, corrects the Delete
Hotcue selector/profile and affected boolean values (including FX Buttons 1–3),
and adds the native FX benchmark commands to the creation catalog. Regeneration
recognizes the old generic profiles even when the selected value is edited.
Hotcue `0xFFFFFFFF` is modeled as an unset selector instead of NaN, and numeric
clamping occurs before integer conversion to avoid crashes on extreme values.

Final macOS unit test result: **658 tests passed, zero failures**, with UI tests
excluded. The result bundle is `/tmp/sxm-djm-verified.xcresult`. Regression tests
were observed failing before fixes. A separate local validation exercised both
original attachments through the production parser/writer; that temporary test
was removed so the suite does not depend on customer files or local paths.

The repaired copy is `/Users/noahraford/Downloads/DJM-S7-SXM-repaired.tsi`.
Independent binary inspection verified 94 distinct CMAI IDs, unchanged command
counts, native modifier condition IDs, Delete Hotcue indices 0–7 for each deck,
and integer boolean values. Its SHA-256 is
`0be1fd3369bef113e7347b1766239e2430550a21251794bd207d3cdbd44d8edd`.
Reopening the repaired copy produces no preservation risks. The original files'
hashes remain unchanged.

Exact no-op save remains byte-preserving. Since repairs change old malformed
payloads, the app's existing safety checks require **Export Lossy Converted
Copy** when editing the affected original file. Conversion of the supplied
Traktor re-export also completes without the unset-hotcue crash, but it still
contains only the 40 mappings Traktor retained.

A live Traktor import/re-export remains unverified. Some Slot FX rows labelled
OFF already contain the value ON in the original SXM file; repair preserves
those stored choices and does not infer settings from comments. Those values
must be reselected if the comments reflect the user's intent.
