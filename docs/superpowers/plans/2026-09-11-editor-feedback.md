# Editor feedback implementation plan

Approved spec: user feedback and accepted recommendations in the September 11 conversation, including red shared-MIDI highlights. All changes are local, reversible editor work; no release publishing.

## Acceptance and implementation units

1. Correctness: retain a valid interaction on single-row MIDI Learn, preserve LED output semantics, replace generic Loop Size Selector values with evidence-backed discrete labels and symmetric read/write encoding. Tests: Direct button learns remain Direct, invalid modes reset, output remains Output, native loop values roundtrip. Own SettingsPanelV2, TSI codec and new loop metadata/tests.
2. Bulk edits: selection-scoped comment find/replace, case option, before/after preview and atomic Undo; compatible bulk command changes for Hotcue Type outputs. Preserve MIDI, conditions, comments, LED settings, opaque imported data; reject incompatible edits. Own new bulk editor services/views/tests; root integrates table and ContentView.
3. Table: minimum modifier width 50; Manual Order mode with per-device persistent multi-row moves, keyboard and drag destination, disabled while filtered or sorted; red matching assignments for selected rows and immediate edits, matching device, direction, MIDI kind/channel/number; unassigned excluded. Own table, ContentView, new pure table operations/tests.
4. Clone: explain excluded assignments; explicit FX Unit 1–4 source/destination cloning, no deck-to-FX assumptions, preserve settings and deduplicate. Own transform service/tests and root UI integration.

## Verification

- Establish baseline with scripts/test-unit.sh (macOS arm64, signing disabled).
- Add meaningful failing regressions before behavior code, then focused tests.
- Run complete suite and build after integration; inspect native UI with a synthetic document, verify undo and ordering save/reopen.
- Independent fresh-context review of all changes and tests; resolve findings.
- Deliver reviewed local branch and built app; no deployment.

## Constraints and decisions

macOS 14+, SwiftUI, existing amber/stone design and native controls. Preserve unrelated diagnostics and existing worktrees. Keep mutations selection-scoped, lock-aware and undoable. Use user-approved recommendations; no second design approval needed. All implementers require their Agency composition. Plan and execution share one isolated worktree at .worktrees/editor-feedback. Main branch remains untouched.
