# K-series controller profile verification — 12 September 2026

Scope: implementation-plan tasks 1–6: bundled K1/K2/K3 evidence, configured control lookup, JSON v2 device annotations, Undo, and the native profile/override interface. The foundation started at `d1e620a`; the configured workflow started from `b5a5eea` on `codex/xone-controller-profiles`.

## Results

| Check | Result |
| --- | --- |
| Existing baseline | 778 tests passed (716 XCTest + 62 Swift Testing) |
| New contract tests | 11 passed |
| Bundled profile tests | 5 passed |
| Foundation suite | 794 tests passed (732 XCTest + 62 Swift Testing), zero failures |
| Configured workflow final suite | 822 tests passed (760 XCTest + 62 Swift Testing), zero failures |
| JSON schema | v1 and v2 schemas and their examples validate |
| Native round trip | Two differently configured devices retain exact metadata and mapping data through export, import, menu Duplicate/Undo and re-export |
| Resource source integrity | All source URLs/hashes match manifests and archived file bytes |
| Address review | Every send/return address compared with a separately transcribed, visually reviewed inventory |
| Physical hardware | Not tested; manufacturer documentation is the acceptance basis |

Expected failing runs preceded implementation: missing contract types; missing bundled resources; then malformed kind/encoding and empty-binding cases accepted before validation was tightened. The final suite includes all existing JSON/TSI round-trip preservation tests. Profile annotation leaves the TSI writer and its source-preservation envelope unchanged; the new metadata is carried in SXM JSON.

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

## Configured workflow acceptance

The final full suite passed after the native walkthrough exposed and fixed a menu Undo issue. Command-menu mutations can receive no SwiftUI undo manager; the document now falls back to its backing NSDocument manager for both undo registration and dirty-state accounting. An explicit manager still takes precedence. Two regression tests failed before the fix and passed afterwards. Metadata-only changes have their own equality comparison at the document mutation/restore boundary; TSI semantic equality is unchanged.

The configured tests cover exact version pins, supported channel/layer combinations, K1 layer refusal, K3 custom maps and Remote/Linked feedback restrictions, contextual overrides, duplicate matching rows, stale/locked drafts, no-op Apply, multi-device metadata, Undo/Redo and unknown-reference retention. Every accepted TSI preservation fixture remains byte-identical after profile annotation. A large metadata regression guards against repeatedly decoding the same profile for each physical-control reference.

Native walkthrough results:

- K1 offers base lookup without inferred K2 latching modes; its first fader resolves CC16.
- K2 all-controls mode, green layer, channel15 resolves first fader CC60 and shows both matching rows, including their different modifier conditions. Show Mappings filters/selects those rows; duplicating selected rows clears the filter so the new rows remain visible.
- K3 factory first fader resolves CC16 on explicitly selected channel7. Custom1 is unresolved until an explicit base/input override is set. Removing the override restores the unresolved state.
- Applying a profile is undoable and redoable. Cancel leaves the draft unapplied. The native sheet was inspected for all three models without clipped controls.
- A two-device native JSON export retained K2 channel15/all-controls/factory and K3 channel7/off/custom1 with a user-supplied CC16 override. Import review showed zero errors, plus the expected shared-MIDI and source-free device-name warnings. Re-export after menu Duplicate/Undo retained exactly equal metadata and device data and validated against schema v2.

Local final evidence: `/tmp/sxm-profile-acceptance.log` (822 passing), `/tmp/sxm-undo-fallback-red.log` (expected pre-fix failure), and `/tmp/sxm-controller-demonstration/configured-profiles-verified.sxm.json` / `reimported-profiles.sxm.json` (native round trip). Earlier focused logs are `/tmp/sxm-profile-resolver-red.log`, `/tmp/sxm-profile-metadata-red.log`, `/tmp/sxm-profile-workflow-red.log` and `/tmp/sxm-profile-workflow-green.log`.

No physical controller or live MIDI capture was used. MIDI Learn reuses the existing lease-based input listener, stages a single observed address for explicit acceptance, and releases only its own listener. The documentation-based address inventory and deterministic tests are the acceptance basis. K3 Editor file import, Euphonia and other profiles remain deferred. The next milestone is the read-only explanation assistant and Markdown, text and PDF documentation exports.
