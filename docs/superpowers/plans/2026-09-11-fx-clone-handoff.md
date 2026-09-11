---
timestamp: 2026-09-11T15:04:00Z
branch: codex/editor-feedback
completion: FX service and sheet complete; parent integration pending
---

1. Implement explicit FX unit clone service, sheet, exclusion explanation and tests (editor-feedback.md lines 10–10). Complete in FXCloneService.swift, FXCloneSheet.swift, MappingTransformService.swift and FXCloneServiceTests.swift.
2. Focused verification (editor-feedback.md lines 14–17). Four tests passed, zero failed in /tmp/sxm-fx-green.log. Tests cover complete field preservation, native TSI roundtrip with imported provenance, atomic undo/redo, lock and stale rejection, and duplicates/exclusions. Tests were written first; the initial red build stopped on concurrently incomplete table tests before reaching FX tests, so a clean behavior-level red was not obtained.
3. Parent integration (editor-feedback.md lines 10–10, 16–18). Present FXCloneSheet(document: document, selectedMappingIDs: selectedMappingIDs, isLocked: isLocked, onApplied: callback). Callback receives MappingTransformExecutionResult for selection/status. Sheet handles undo, errors and dismissal. Show MappingTransformPlanner.exclusionExplanation in deck clone help.

Dependency analysis: source and destination pickers and preview are self-contained; parent ContentView integration depends on completed sheet API. Final complete-suite and native UI verification depend on all parallel units integrating.

Dispatch strategy: this unit ran alongside parent table and independent bulk/settings work; no further delegation needed. Parent assembles once and runs final verification. No commits or publishing occurred.

Follow-up, 2026-09-11T15:20Z: Parent native preview exposed ordinary-save refusal for generated FX370 Direct mappings. Added full-envelope parseDocument → clone → ordinary write → parseDocument regression for FX369–372, including an ordinary comment edit. Observed expected red at FX370 unreproducibleCMAD. Root cause: unset controller encoded as Button but canonical fallback omitted boolean Direct value UI, triggering legacy malformed-profile repair at reimport. TSIWriter canonical boolean commands now choose Button profile for unset controllers; other unset command profiles unchanged. FXCloneServiceTests, TSIPreservationTests and LEDOutputSettingsTests pass 53/53 in /tmp/sxm-fx-save-green.log. Parent owns full-suite recheck and native assembly; no further dependency or dispatch change.
