# Run: controller-identify
Instruction: Build the controller identify workflow in XtremeMapping. Effort ceiling: MEDIUM. Reuse the existing design system (AppThemeV2 + V2 components). (1) On-load dismissible banner when a device has no controller profile → "Identify controller"/"Not now", re-openable. (2) Redesign the orphaned ControllerProfileSheet into a clean "Which controller is this?" identify screen (searchable brand/model list, coverage chips, confirm channel, Skip/Confirm), jargon moved to advanced panel. (3) Wire the trigger (activeSheet=.controllerProfile is never set today). (4) Per-device identification with a device switcher. (5) Additive "Physical Control" column in MappingsTableView (do NOT replace CC/MIDI columns) resolved via ControllerControlResolver. Never touch AppThemeV2 tokens. Extend the uncommitted controller-library work, don't revert it. Reference mockup: docs/mockups/controller-identify-flow.html.
Stage: done (commit 6063817 pushed to origin/main)
Rung: medium (start-floor: user-capped "up to medium"; evaluator sets light|medium, ceiling medium)
Spec: docs/superpowers/specs/2026-09-13-controller-identify-design.md
Plan: docs/superpowers/plans/2026-09-13-controller-identify.md
Agency project: — (see Notes: executed via scoped Agent subagents, not Agency MCP)

## Scorecards
Pass 1 [spec]: 0B/1S/1C/0R · fixed -/- · velocity = (—→2) · judge: n/a-medium
Pass 1 [plan]: 0B/0S/1C/0R · fixed -/- · velocity = (—→1) · judge: n/a-medium
Pass 1 [code:all]: 2B/2S/2C/0R · fixed -/- · velocity = (—→6, escalation no) · judge: n/a-medium (fresheyes)
Pass 2 [code:all]: 0B/0S/1C/0R · fixed 4/4 prior · velocity ↓ (6→1, escalation no) · judge: n/a-medium

## Chunks
- [x] A — Reverse resolver + Physical Control column — build clean, self-review no blockers
- [x] B — Identify screen redesign — identify step V2-only, advanced keeps prior logic, switcher retargets deviceID
- [x] C — On-load banner + wiring + re-open entry — AssistantNoticeBanner-styled, session-dismiss
Build: EXIT=0 BUILD SUCCEEDED · tokens byte-identical · 4 files (+503/-37)
Self-review notes: reverse resolver "first control claims address" heuristic + ~348 resolve calls/device once per revision (both acceptable). Awaiting fresheyes independent pass.

## Verification gate
- Build: EXIT=0 BUILD SUCCEEDED. Tokens byte-identical.
- ControllerControlResolverTests: 15/15 pass (8 new).
- Full XtremeMappingTests: 10 FAILURES, ALL in the Assistant domain this run never touched
  (MappingAssistantServiceTests ×6, AssistantConversationServiceTests ×1, AssistantWindowControllerTests ×1;
  citation/validation + window-size). Match the earlier committed citation-behavior change ("demote uncited
  facts to interpretations"). Isolation check: running them at clean HEAD a19f628 (no controller changes) to
  confirm PRE-EXISTING, not a regression from this run.
- CONFIRMED PRE-EXISTING: the same tests FAIL at clean HEAD a19f628 with none of this run's changes.
  This run introduced ZERO new test failures. The 10 Assistant-domain failures already live in the
  pushed history (a19f628 or earlier) — separate issue, flagged to user for a later fix.

## Notes
- Deviation (recorded per anti-skip rule): execution via scoped Agent subagents + direct edits rather than the Agency MCP, because this is one cohesive medium UI feature and the user capped effort at medium; all mandatory artifacts (manifest/spec/plan) still produced and the code still gets an independent review pass + build verification. Reported in end summary.
- Working tree already holds uncommitted controller-library work in the target files — extend, never revert. Commit staging must be handled carefully at Step 5 (surface to user; main-push needs confirmation).
