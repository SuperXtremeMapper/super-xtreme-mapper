# Loop Size Selector values — 11 September 2026

## Evidence

The checked-in native Traktor fixtures contain no command 2196 row. This change therefore relies on the primary CMDR implementation, not a claim that these values were manually verified in the current Traktor application.

CMDR checkout `/tmp/sxm-diagnosis-cmdr`, commit `5b7950272a55f73034d2df15de2917248e2e9616`:

- [KnownCommands.cs](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Commands/Interpretation/KnownCommands.cs) declares command 2196 as `EnumInCommand<LoopSize>` / `EnumOutCommand<LoopSize>`.
- [LoopSize.cs](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Enums/LoopSize.cs) maps raw integers 0 through 10 to 1/32, 1/16, 1/8, 1/4, 1/2, 1, 2, 4, 8, 16, 32.
- [EnumParser.cs](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Parsers/EnumParser.cs) encodes/decodes enum values as signed 32-bit integers, not IEEE floating point.
- [AValueInCommand.cs](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Commands/Base/AValueInCommand.cs) connects this parser to `SetValueTo` and uses ComboBox UI. [AValueCommand.cs](https://github.com/cmdr-editor/cmdr/blob/5b7950272a55f73034d2df15de2917248e2e9616/cmdr/cmdr.TsiLib/Commands/Base/AValueCommand.cs) enables that UI for button Direct/Hold.

SXM's existing format reader/writer handles byte order. The command-specific correction concerns the interpretation of the four-byte CMAD value at offset 44.

## Scope

Only Loop Size Selector (2196) receives the new discrete choices. Related loop commands require their own acceptance coverage before extension. Unknown imported values remain visible as “Unknown (…)” and retain their original wire value until explicitly replaced. Unrelated edits use the existing exact-payload preservation path.

## Verification

- Test-first Learn regression failed with Direct becoming Hold (and other valid interactions resetting), then passed after retaining compatible modes. Log: `/tmp/sxm-correctness-red6.log`.
- Test-first codec regressions failed on IEEE-float words in place of integers and incorrect unknown-selector interpretation. Log: `/tmp/sxm-correctness-red7.log`.
- All eight initial focused tests passed in `/tmp/sxm-correctness-green.log`.
- Final 228 focused plus TSI interpreter/preservation tests passed with zero failures in `/tmp/sxm-correctness-final.log`, including the extra label/unknown-choice test. Coverage includes all eleven raw selectors, corresponding decoded values, unknown Int32.max payload retention across unrelated edits, and explicit replacement changing only the value word.
- Xcode filesystem-synchronized groups compiled both new files automatically; no project configuration edit was needed. `git diff --check` passed.

No native Traktor application import/export validation was performed for this change. Labels and integer semantics are grounded in the cited reference implementation; current-version native confirmation remains a practical validation limit.

## Review follow-up: interaction-only edits

The independent review identified that imported Loop Size Selector rows changing only their interaction did not refresh HasValueUI at offset 36. The existing preservation branch refreshed that flag only for boolean commands. Added a byte-exact regression for all six transitions among Increment, Direct and Hold. Four transitions failed before the fix (`/tmp/sxm-loop-review-red.log`): entering and leaving the Direct/Hold value UI. Extended the existing narrow flag update to command 2196, leaving all other CMAD words intact.

Follow-up validation: all 37 loop and preservation tests passed with zero failures (`/tmp/sxm-loop-review-green.log`), including all six interaction transitions. `git diff --check` also passed.
