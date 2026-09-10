# Issue 9 evidence and resolution

Source: https://github.com/SuperXtremeMapper/super-xtreme-mapper/issues/9
Base: `edb166e`; branch: `codex/led-output-mapping`.

## Scope and findings

The source screenshot identifies unknown command 3482, with additional unknown inputs and outputs. The author identifies Modifier #2 and #7 as two examples. The banner's 20 native MIDI assignments in compatibility mode is separate from command-name recognition. The commercial mapping was never supplied, so all original unknown rows cannot be enumerated.

Native Traktor 4.5.1 established 3482 as Generate Stems, available under Browser → List in both Add In and Add Out. The catalogue lacked this identity. Added the name, both creation directions, an explicit 4.5.1 verification status, and both picker routes. New inputs use Button/Trigger/Global; outputs use LED/Output/Global with the observed default range 0–1.

All eight Modifier outputs already had the correct IDs (2548–2555). New generated and native fixture coverage confirms range 7–7, MIDI 0–127 and flags off. A native import/re-export preserved all eight rows' settings exactly.

Native exports revealed that target word 0 means Global for these modifier outputs and Generate Stems. SXM previously displayed Deck A. The correction is limited to modifier outputs and Generate Stems; deck commands and FX/remix encodings keep their existing interpretation. Nonzero imported targets and unknown IDs remain unchanged during unrelated edits. Modifier input semantics were not broadened from output-only evidence.

## Verification and recovery

- Identity and global-target regression tests failed before their fixes.
- Focused command, LED and native-fixture suites passed after implementation.
- Full unit suite: **687 passed, 0 failed, 0 skipped** (694 executions including dynamic parameters), exit 0. Result bundle `Test-XtremeMapping-2026.09.10_18-27-55-+0400.xcresult`; log `/tmp/sxm-issue9-full-tests-final.log`. An earlier full run caught the older menu test requiring 4.4.1-only verification; its expectation now accepts verified versions while retaining direction checks.
- Native Add In/Add Out identity capture and all-eight modifier import/export completed.
- Fresh native fixtures are hash-checked and included in document-layer byte-exact no-op preservation coverage. See `XtremeMapping/docs/TSI-Fixture-Provenance.md`.
- Three temporary Traktor devices were removed, original K3_D_v5 selection restored, Preferences closed. No user mappings were edited or commands triggered.
- Initial identity probe omitted explicit ports and imported as All Ports. The agent immediately set its ports to None before further work; no MIDI controls were triggered. Diagnostic generators now specify None explicitly.
- No push, release or public issue comment. Keep issue 9 open until the reporter confirms their full mapping or supplies the remaining IDs.

## Reviews and Agency

- Implementation: `01a08ba8-352b-7e84-9242-e521615edfa6`; evaluation submitted, complete, 95/100.
- Independent spec: `01a08bac-cb66-761f-9ef9-47f54fa72fc9`; approved with evidence/version, target-scope, preservation and private-data boundaries; evaluation submitted, complete, 95/100.
- Independent code: `01a08bb5-97de-734e-918c-d27fe79a740a`; approved with no blocking findings, including follow-up test/documentation review; evaluation submitted, complete, 95/100.

The two pre-existing untracked S7 diagnosis/evidence files are excluded from this change.
