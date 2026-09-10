# Issue 1: software-state conditions

Status: implementation, native Traktor round trip, SXM visual check and cleanup passed. No release or public issue update. The unidentified truncated condition in the issue remains outside the verified scope.

## Scope and evidence

[Issue 1](https://github.com/SuperXtremeMapper/super-xtreme-mapper/issues/1) reports unavailable software-state conditions and numeric modifier labels. Existing Hotcue State support handles IDs 2333–2340. This change adds Deck Play (the Play/Pause state, 100) and Is In Active Loop (203) to the same editor, for all controllers, in either condition slot.

The primary [CMDR condition catalogue](https://github.com/cmdr-editor/cmdr/blob/master/cmdr/cmdr.TsiLib/Conditions/Interpretation/KnownConditions.cs) identifies both conditions as track-targeted On/Off enums. Its [OnOff enum](https://github.com/cmdr-editor/cmdr/blob/master/cmdr/cmdr.TsiLib/Enums/OnOff.cs) defines Off = 0 and On = 1. Native Traktor 4.5.1 build 21 capture confirms identifiers 100/203. Its menu calls playback **Deck Play**, while the selected field shows a truncated Play/Pause label. Its value menu shows **off/on** for Deck Play and **0/1** for Is In Active Loop. SXM follows the menu name and each condition's native value choices (capitalising Off/On).

The unmodified native fixture `traktor-4.5.1-software-conditions.tsi` has SHA-256 `03e79a71a0e41d9804f3c53e143cfe586d2d04bfa46d3943b39a8882862dcd71`. Independent binary decoding gives `(identifier, target, value)`:

| Row | First condition | Second condition |
| --- | --- | --- |
| 1 | (100, 0, 0): Deck A, off | (203, 1, 1): Deck B, 1 |
| 2 | (100, 3, 1): Deck D, on | (203, 4294967295, 0): Device Target, 0 |

The fixture's decoded strings contain only native version/device metadata, MIDI definitions and temporary test comments.

The screenshot's truncated `M42949…` identifier is not identifiable from the issue. It is not assigned a speculative name. Unknown identifiers, values and targets continue to round-trip unchanged.

## Behaviour and walkthrough

1. Select an IN or OUT mapping and open either condition menu.
2. Choose Deck Play or Is In Active Loop, then Deck A–D or Device Target. The editor and table display the condition name, target and Off/On or 0/1 state respectively.
3. Changing only a condition's target keeps its imported value, including unrecognised values. Switching to another condition type starts at zero; Hotcue-to-Hotcue selections retain the existing Hotcue state behaviour.
4. Explicit choices apply to selected rows, including a mixed selection. Undo restores the previous tuples. A locked editor rejects mutations.
5. Export preserves both condition slots. Deck cloning translates a Deck A condition to the destination and retains Device Target.

No reader/writer schema or command identifiers were changed. Recovery is to revert the narrow metadata/editor/test change. Existing unknown-condition preservation remains in place.

## Verification record

- The initial regression test failed on missing readable state/target labels and editable values.
- The first full run passed 690 tests and exposed an undo-test setup error (manual grouping disabled without opening a group). The test now opens/closes an explicit group. All 11 focused condition tests pass.
- Final full suite after native fixture and label corrections: **692 tests passed, zero failed or skipped** (699 executions including parameterised runs). Result: `Test-XtremeMapping-2026.09.10_20-05-10-+0400.xcresult`; log `/tmp/sxm-issue1-native-final-tests.log`. The addressed probe generation test also passed separately.
- Independent fresh-context code review: **pass, no actionable production-code findings**, including final native labels, fixture and exact byte-preservation test. One P3 documentation finding (stale blocked/test status) corrected in this record.
- The first native capture attempt was blocked by the locked Mac before any changes. After the user unlocked it, native menu/value/target capture and independently decoded fixture checks passed.
- The initial generated probe had unassigned MIDI addresses and Traktor imported it as an empty device. Empty-export evidence is `/tmp/sxm-issue1-generated-empty-reexport.tsi`. That temporary device was removed. A replacement probe uses explicit Channel 16 Note 115–119 addresses with both ports None.
- Addressed SXM export/import/re-export comparison: **pass**. Traktor retained five rows; independent decoding found all ten condition tuples, five comments, directions and commands unchanged. Targets cover Deck A–D and Device Target for both conditions; values alternate 0/1. Source `/tmp/sxm-issue1-generated-addressed.tsi` SHA-256 `f5931fc08b8150ca8cccfa5fd669e7a453dbe125d29997bbf14af9a8f9af93f9`; native `/tmp/sxm-issue1-generated-reexport.tsi` SHA-256 `9b10b4d21e559112d7fdfbb3f9702b5479c08f06a8b19ac48a092937a2fec888`. Native inspected values were off/on/off/on/off and 1/0/1/0/1 respectively.
- Traktor cleanup passed: both remaining issue 1 temporary devices removed, original `K3_D_v5` selected, Preferences closed.
- SXM visual walkthrough passed in the current Debug build: the five-row table displayed both condition names, Deck A–D/Device Target and their expected values. Both condition families and all five targets were present in the type menus. Value menus showed Off/On and 0/1 respectively. Changing the first Deck Play value from Off to On updated the visible row; Undo restored Off and cleared Edited. Only the disposable probe document was closed; Welcome remained. Visual evidence was inspected inline through CUA; no standalone screenshots were saved. Lock rejection is covered by automated tests, not a claimed visible lock control.

## Review workflow

Medium, reversible scope. User-approved requirements reused; no deployment or release gate applies because neither is requested.

- Agency implementation: `01a08bed-df18-7397-b068-18591ef3ac99`; final evaluation **95/100, complete**, recorded after native and visual verification. Initial evaluation was 70/100, incomplete while the Mac was locked; draft preparation preceded native verification, and that gate is now satisfied.
- Agency independent code review: `01a08bf3-0dcf-71f5-8cb9-b02d1a98edf7`; final evaluation **95/100, complete**. Native-evidence changes passed code review, and the reviewer explicitly closed the corrected P3 documentation finding. No outstanding findings.
- Base: `90bf083`. Unrelated September 9 customer diagnostics excluded.
