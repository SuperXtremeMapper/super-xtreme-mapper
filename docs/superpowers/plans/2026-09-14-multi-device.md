# Multi-device Implementation Plan

> Use superpowers:subagent-driven-development for bounded independent components, then integrate and review the complete diff.

**Goal:** Enable creating and editing multiple mapping devices safely in one document.
**Architecture:** Pure device operations and destination resolution feed document transactions; source-aware MIDI captures feed existing workflows. Minimal UI exposes the foundation before a separate UX exploration.
**Tech Stack:** Swift, SwiftUI, CoreMIDI, XCTest.
**Spec:** docs/superpowers/specs/2026-09-14-multi-device-design.md

## Constraints
- Preserve existing TSI compatibility checks and undo transactions.
- No silent first-device targeting or ambiguous hardware matching.
- No dependency additions; retain current project deployment targets.
- Work on codex/multi-device-workflows in the clean shared checkout. Do not commit or change branches from workers.

## Tasks
- [x] Device operations: add `Services/DeviceManagementService.swift` and focused XCTest coverage. Implement add/update/duplicate/delete, copy/move with atomic preflight, metadata remapping, selected-device export model. Publish exact API to integrator.
- [x] MIDI identity: extend `Utilities/MIDIInputManager.swift` with source identity and filtered listener leases. Add deterministic tests for identical messages from distinct endpoints and unavailable/ambiguous routes. Integrate wizard and voice routing; publish API for settings and assistant.
- [x] Shared editing context: add document active-device selection and central destination resolver. Cover stale selection and empty/sole/multi-device behavior with tests before implementation. Route add/paste/drop/wizard/profile/assistant through this context.
- [x] Minimal controls: device picker and management sheet; route basic add/edit/duplicate/delete/transfer/export through the tested services and document undo. Keep existing layout conventions.
- [x] Verification: run the targeted and full unit suite with `scripts/test-unit.sh`, inspect failures, review complete diff, fix regressions. Record actual results and hardware limitations.
- [x] UX exploration: document the working behavior and propose a device sidebar, combined-view ownership, and context-sensitive learning controls without committing to a visual redesign.

## Integration review
Device service owns pure mutations; root owns document/context/UI integration. MIDI worker owns manager and wizard/voice coordinators; root owns settings and assistant integration. Both consume Device.inPort while source IDs remain session metadata. Tests must cover mutation atomicity and routing independently before end-to-end integration.

## Verification record

- Shared context/assistant: initial 10 tests passed after isolating the SwiftUI view expression.
- Device and transfer: risky imported-source regression reproduced before fix; 25 focused tests passed after ordinary-save preflight replaced converted preflight for document changes.
- MIDI/wizard/voice: 105 focused tests passed, including lease contention, source identity, same-name source ID selection, reconnect and stale delivery gates.
- Undo route regression reproduced (`XCTAssertNil` received new endpoint ID after Undo), then fixed by invalidating session endpoint bindings when saved input ports change.
- Full suite: 982 passed, 0 failed, 0 skipped in `/tmp/xtreme-multidevice-root/Logs/Test/Test-XtremeMapping-2026.09.14_17-07-58-+0400.xcresult`.
- Manual native-app check: created Left and Right devices, saved labels, added a mapping to Right, verified Right count 1 / Left count 0 and filtered table, and saved the resulting TSI. Test file: `/tmp/xtreme-multi-device-manual-check.tsi`.
- Code review fixes: ordinary-save validation before document mutations, pinned delete-confirmation snapshot, explicit lossy-export warning, shared profile context, lease-owned setup callbacks, and connection tokens rejecting queued events from an earlier capture.
- UI exploration: `docs/Multi-Device-Workflow.md`. No physical two-controller or Traktor runtime test is claimed.

Final integrated verification: 985 tests passed, 0 failed; result bundle `/tmp/xtreme-multidevice-root/Logs/Test/Test-XtremeMapping-2026.09.14_17-12-34-+0400.xcresult`. This includes the final single-device/empty All Ports and route-change regressions.
