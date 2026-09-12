# Assistant polish and repair implementation plan

Use superpowers:subagent-driven-development. Parent owns builds and native checks. One repair implementation agent owns import subsystem; parent owns Assistant UI independently. No concurrent builds or worker-spawned reviewers.

Spec: docs/superpowers/specs/2026-09-12-assistant-polish-repair.md
Base a675136, isolated .worktrees/assistant-polish-repair.

- [x] Parent: restyle UnifiedAssistantView and AssistantWindowController, reuse AppThemeV2. Extract scoped reusable visual controls if useful. Test appearance/window regressions; native layout and interaction walkthrough.
- [x] Repair agent: tests first for immutable original, protected preservation, malformed/source-free and schema-invalid repairs, strict patches, atomic validation, stale/cancelled transport. Notify parent for RED. Implement new JSONRepair service/plan/coordinator; integrate JSONImportCoordinator and JSONImportReviewSheet. Keep existing injected reviewFile tests backward-compatible. Parent GREEN then independent review.
- [ ] Parent: live fixture evaluation with existing stored key if accessible; document actual outcomes and unavailable inputs. Repair remains independent of key access.
- [x] Full suite; whole-change independent review; scoped fixes and verification. User guide, repair guide and acceptance record. Locally commit/fast-forward verified tree; preserve unrelated files. Pause after these items.

Evaluation status: available native startup/cancel/geometry/local import checks completed. Live Sonnet replies and successful repair generation blocked by macOS Keychain authorization. Speech startup cancelled while pending; no transcript or physical MIDI event supplied. Keep evaluation checkbox open, pause as requested after delivering completed UI and repair implementation.

Final suite: 908 passed; independent task/scoped/whole-change reviews PASS. Keychain async lifecycle and AppKit container sizing corrections included.
