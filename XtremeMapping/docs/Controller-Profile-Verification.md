# K-series profile foundation verification — 12 September 2026

Scope: implementation-plan tasks 1–2, shared profile contract and complete bundled K1/K2/K3 data. Work started at `d1e620a` on `codex/xone-controller-profiles`. Configured resolver, device annotations, UI and MIDI Learn integration remain later tasks.

## Results

| Check | Result |
| --- | --- |
| Existing baseline | 778 tests passed (716 XCTest + 62 Swift Testing) |
| New contract tests | 11 passed |
| Bundled profile tests | 5 passed |
| Final full suite | 794 tests passed (732 XCTest + 62 Swift Testing), zero failures |
| Resource source integrity | All source URLs/hashes match manifests and archived file bytes |
| Address review | Every send/return address compared with a separately transcribed, visually reviewed inventory |
| Physical hardware | Not tested; manufacturer documentation is the acceptance basis |

Expected failing runs preceded implementation: missing contract types; missing bundled resources; then malformed kind/encoding and empty-binding cases accepted before validation was tightened. The final suite includes all existing JSON/TSI round-trip preservation tests. The profile subsystem does not alter the writer or mapping model.

A scoped code review found and resolved acceptance of contradictory MIDI kind/encoding pairs. Independent data review found no address, mode-group, source-reference or control-coverage mismatches. Known manual discrepancies are retained in [source evidence](Xone-K-Series-Profile-Evidence.md).

## Reproduction

From the repository root:

```sh
xcodebuild test \
  -project XtremeMapping/SuperXtremeMapping.xcodeproj \
  -scheme XtremeMapping \
  -destination 'platform=macOS' \
  -only-testing:XtremeMappingTests \
  -parallel-testing-enabled NO \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
  ENABLE_HARDENED_RUNTIME=NO ENABLE_APP_SANDBOX=NO
```

These command-line overrides apply only to the local test build; project signing/sandbox settings are unchanged. The first baseline attempt could not load the test bundle due to differing signing identities. After ad-hoc signing, two existing tests could not overwrite their hardcoded `/tmp/sxm-json-demonstration` outputs under the app sandbox. With the local test sandbox override, the unchanged baseline passed completely.

Local logs: `/tmp/sxm-xone-baseline-local.log`, `/tmp/sxm-xone-contract-red.log`, `/tmp/sxm-xone-contract-green.log`, `/tmp/sxm-xone-data-red.log`, `/tmp/sxm-xone-data-green.log`, `/tmp/sxm-xone-validation-red.log`, `/tmp/sxm-xone-full.log`. These are temporary local evidence, not required application resources. Existing system warnings about the TSI type declaration and macOS shortcut services remain outside this change.
