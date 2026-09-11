# Live validation — 11 September 2026

Implementation: `97a0bb8`, `codex/editor-feedback`. Tested against installed Traktor Pro 4 version 4.5.1 (21), with the local feedback preview. No application source changes were made during this validation.

## Observed passes

- Traktor imported the preview file saved during the previous UI session, including both FX Unit On and FX Button 1 clones assigned to FX Unit 2. Original Unit 1 rows remained present.
- Loop selector raw values 0, 4, 7, and 10 drove Traktor Deck A to visibly distinct 1/32, 1/2, 4, and 32 selections. Events were Note On/Off on channel 16, notes 110, 111, 113, and 114, through a temporary CoreMIDI virtual source. Traktor also displayed the imported four-beat Set to Value correctly. No track was playing; this verifies selector behavior, not measured audio-loop duration.
- Actual preview UI MIDI Learn received channel 16 Note 116 and preserved Button / Direct. Learning was stopped after the check.
- A native UI stress document reached 504 rows. Shared assignments visibly turned all displayed matching rows red, with a 504-share count.
- Native comment replacement preview reported 248 selected changes from LEFT PAD 1 to RIGHT PAD 1. Search displayed the changed rows. Native save-on-quit succeeded. Independent parse of that saved UI file confirmed 504 rows: 248 RIGHT comments, 256 unchanged LEFT comments, and all 504 interactions still Direct.
- A separate direct application-service check on a copy of 381 real imported mappings passed 250 scoped replacements, exact preservation of every other mapping field, and stable movement of a ten-row block.
- A separate 504-row safe mapping passed 248 replacements, block reordering, ordinary writer save, and parser reopen, preserving row order, comments, and MIDI assignments.

## Limits and findings

- No physical MIDI controller was connected. CoreMIDI listed only Traktor's virtual output before the temporary source was created. Physical button feel, controller LEDs, and audible loop duration remain untested.
- The full Traktor settings file has unsupported source content (including native MIDI controls, unused definitions, extra XML settings, and unknown frames). Its existing preservation guard refuses ordinary Save after edits. The source was not converted or overwritten for this test. This is not a safe ordinary-save fixture; support for such full-settings edits remains outside this feature change.
- The automated Open and initial Save dialogs in the preview kept their confirmation buttons disabled. A restart and a normal rebuild did not resolve that path; a new document and save-on-quit worked. Native application sampling showed the main thread idle in its event loop, not a CPU-bound hang. The file-dialog issue remains unresolved and must not be described as a passed Open/Save As test.
- UI automation also produced stale element errors and long action delays. The final large-table reorder persistence assertion is from direct application services, not a confidently observed native drag placement. Earlier native Move Up/Undo and drag movement checks are recorded in the implementation handoff.

## Evidence and cleanup

Local-only evidence is under `/tmp/sxm-live-validation`: `scale-results.txt`, `scale.swift`, `stress504.tsi`, `large-roundtrip.tsi`, and the loop/MIDI helpers. Real user settings are deliberately excluded from git.

Traktor was quit after testing. `Traktor Settings.tsi` was restored byte-for-byte from the pre-test backup, with SHA-256 equality verified. The virtual MIDI source process exited. The UI stress document was saved to the temporary evidence directory and the preview was closed. The installed SXM application was not replaced. No release was published.

The earlier full suite result remains 727 passing tests. This follow-up adds live and scale evidence, but is not a claim that every release acceptance check is complete.
