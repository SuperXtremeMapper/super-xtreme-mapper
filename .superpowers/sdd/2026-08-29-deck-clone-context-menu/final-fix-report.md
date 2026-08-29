# Deck Clone Final Fix Wave Report

**Date:** 2026-08-29

**Base:** `4637194` (`fix: distinguish deck clone conflicts`)

**Planned commit subject:** `fix: harden deck clone review execution`

**Scope:** One final-review fix wave; no push, deploy, or SDD ledger change

## Outcome

All five whole-feature review findings are addressed in one coherent change:

1. A proposed clone now owns one review item and one decision even when it matches several existing mappings. `Replace Existing` carries the exact selected mapping ID, so the executor cannot receive contradictory actions for the same proposal.
2. The plan retains one ordered candidate stream covering safe inserts, duplicate skips, and reviewed proposals. Execution walks that stream once, preserving destination-group and source/device order after review resolution.
3. Every proposal snapshots the exact-duplicate and functional-conflict match set in its owning device. Immediately before candidate-file construction, execution compares the current match set with that snapshot and fails with `stalePlan` on additions or classification changes.
4. Review items carry a human-readable source-device label. Duplicate names are deterministically shown as `Name (1)`, `Name (2)`, and blank names use `Unnamed Device`; the visible row and accessibility labels both include the label.
5. `Change > Deck` now consumes a dedicated list containing only Deck A, Deck B, Deck C, and Deck D. Existing `Change` actions such as MIDI Channel, Comment, Type, Interaction, Encoder Mode, and modifiers retain their accurate labels.

## Root Causes Verified Before Implementation

- Review identity included the individual conflict reason and existing mapping ID, producing multiple independent rows for one proposed clone.
- The executor appended `plan.inserts` first and then traversed `plan.reviewItems`, splitting one planner sequence into safe and reviewed groups.
- Stale validation checked source, ignored, duplicate, conflict, and proposed-ID references, but did not compare every proposal against newly added or edited owning-device mappings.
- Review presentation had command, destination, MIDI, and comment context but no device identity.
- The Deck submenu iterated `TargetAssignment.allCases`, which included non-deck targets and remix-slot targets.

## TDD Evidence

### RED: observable regressions

Command:

```sh
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingTransformServiceTests/testOneProposalWithMultipleFunctionalConflictsProducesOneReviewItem \
  -only-testing:XtremeMappingTests/MappingTransformExecutorTests/testMixedSafeAndReviewedClonesKeepPlannerOrderAcrossDestinationsAndDevices \
  -only-testing:XtremeMappingTests/MappingTransformExecutorTests/testNewExactDuplicateMakesSafePlanStaleWithoutMutation \
  -only-testing:XtremeMappingTests/MappingTransformExecutorTests/testNewFunctionalConflictMakesSafePlanStaleWithoutMutation
```

Result: `Failed; passed=0; failed=4`, with 12 expected assertion failures:

- one proposal produced 2 review rows and `2 mappings need review` instead of one;
- safe mappings appeared before reviewed mappings in both tested devices;
- a newly introduced exact duplicate did not throw and mutated the document/Undo state;
- a newly introduced functional conflict did not throw and mutated the document/Undo state.

The stale regression fixtures were subsequently strengthened, without changing the asserted behavior, so another selected proposal keeps the review sheet open while the new duplicate or conflict is introduced.

### RED: missing coherent model and presentation boundaries

Command:

```sh
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingTransformServiceTests/testOneProposalWithMultipleFunctionalConflictsProducesOneReviewItem \
  -only-testing:XtremeMappingTests/MappingTransformExecutorTests/testOneProposalDecisionCanReplaceOneExplicitTargetAmongMultipleConflicts \
  -only-testing:XtremeMappingTests/DeckClonePresentationTests/testReviewStateRequiresExplicitReplacementTargetWhenProposalHasMultipleConflicts \
  -only-testing:XtremeMappingTests/DeckClonePresentationTests/testDuplicateDeviceNamesAreDisambiguatedInRowsAndAccessibilityLabels \
  -only-testing:XtremeMappingTests/DeckClonePresentationTests/testChangeDeckMenuOffersOnlyActualDeckAssignments
```

Result: expected compile failure because production did not yet provide `MappingTransformReviewDecision`, aggregated `conflicts`, review-state `decisions`/replacement-target selection, row `deviceTitle`/`existingSummaries`, or `DeckClonePresentation.deckAssignments`. A test-only type-inference error was corrected before the valid behavioral RED run and is not counted as product evidence.

### GREEN: focused suites

Command:

```sh
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/ModifierConditionTargetTests \
  -only-testing:XtremeMappingTests/MappingTransformServiceTests \
  -only-testing:XtremeMappingTests/MappingTransformExecutorTests \
  -only-testing:XtremeMappingTests/DeckClonePresentationTests \
  -only-testing:XtremeMappingTests/MappingBatchEditorTests
```

Result: `Passed; passed=69; failed=0`.

Coverage includes:

- known/unknown condition-target modeling and writer round trips;
- planner translation, eligibility, deterministic IDs, device ownership, duplicates, conflicts, and one-row multi-conflict proposals;
- coherent keep/create/replace decisions, explicit replacement target selection, safe/review ordering, stale duplicate/conflict rejection, TSI preflight failure, exact-reference safety, created selection, and one-step Undo/Redo;
- compact review state, approved labels, duplicate device-name presentation/accessibility, status text, and Deck-only choices;
- existing MIDI, comment, assignment, learn, and Undo batch behavior.

## Final Verification

### Complete unit suite

Command: `scripts/test-unit.sh`

Result: `Passed; passed=645; failed=0` (`583` XCTest tests plus `62` Swift Testing tests).

### No-sign Release build

Command:

```sh
xcodebuild build -quiet \
  -project XtremeMapping/SuperXtremeMapping.xcodeproj \
  -scheme XtremeMapping \
  -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

Result: exit `0`.

The build emitted existing actor-isolation warnings in `CommandHierarchy.swift`, `TraktorCommands.swift`, and `MappingEntry.swift`, plus existing Swift-package dependency-scan warnings for Hub/WhisperKit. There were no build errors and no new warning attributed to this fix wave.

## Files and Responsibilities

Seven implementation/test files changed, plus this report:

- `XtremeMapping/XtremeMapping/Services/MappingTransformService.swift` — proposal-level conflict aggregation, coherent decisions, ordered candidate retention/execution, and current-device match revalidation.
- `XtremeMapping/XtremeMapping/Views/DeckCloneReviewSheet.swift` — one action per proposal, explicit multi-conflict replacement target, visible device label, and accessibility labels.
- `XtremeMapping/XtremeMapping/Views/MappingsTableView.swift` — dedicated Deck A/B/C/D batch menu options.
- `XtremeMapping/XtremeMapping/ContentView.swift` — passes proposal decisions from the sheet to the executor.
- `XtremeMapping/XtremeMappingTests/MappingTransformServiceTests.swift` — aggregated multi-conflict proposal regression.
- `XtremeMapping/XtremeMappingTests/MappingTransformExecutorTests.swift` — explicit target, ordered execution, and stale-new-match regressions.
- `XtremeMapping/XtremeMappingTests/DeckClonePresentationTests.swift` — single-choice state, target selection, device labels/accessibility, and Deck-only menu regressions.
- `.superpowers/sdd/2026-08-29-deck-clone-context-menu/final-fix-report.md` — delivery evidence and risk assessment.

## Architecture and Integration Seams

The planner remains pure and value-based. Its public result still separates inserts, duplicate skips, ignored mappings, and review items for presentation/counting, while an internal `orderedCandidates` stream preserves the single authoritative traversal used by execution. Each ordered candidate also retains its proposed mapping and original live-match signature.

Review presentation converts `MappingTransformReviewChoice` into one `MappingTransformReviewDecision` per proposal. A replacement decision embeds the chosen conflict mapping ID. The executor validates the decision keys and replacement target against the exact planned item before inspecting the live document.

The executor then validates all retained source/existing/proposed references, revalidates proposal match signatures against current owning-device contents, constructs the candidate in planner order, runs `TSIWriter.writeConverted`, and performs one `performUndoableMutation`. No integration seam replans, allocates a new ID, or mutates before preflight.

No parallel work streams were used in this wave, so there are no cross-agent merge seams. The relevant internal seams—planner to review sheet, review sheet to ContentView, ContentView to executor, and table presentation to batch mutation—are all compiled and covered by the focused/full suites.

## Safety and Requirement Self-Review

- **Coherent decisions:** one review item per source/device/destination proposal; state stores one choice key; later choices replace earlier choices; the decision enum embeds an explicit replacement target.
- **Ordering:** executor no longer loops safe and review arrays separately; mixed B/C/D and two-device regression checks exact final ID order.
- **Stale safety:** new exact and functional matches fail before `var candidate` is created; regression asserts document equality, clean dirty state, and unchanged Undo/Redo state.
- **Device labels:** unique names remain plain; duplicates use stable device-array ordinals; blank names receive `Unnamed Device`; visible and accessibility strings share the retained label.
- **Deck menu:** exactly `.deckA`, `.deckB`, `.deckC`, `.deckD` are offered.
- **TSI preflight:** unchanged full-candidate `TSIWriter().writeConverted(candidate)` remains before mutation.
- **Undo:** unchanged single `Clone Deck A Mappings` document mutation; Undo/Redo regression remains green.
- **Exact plan retention:** proposed mapping values and IDs come only from the retained plan; executor does not call the planner or allocate IDs.
- **Source/MIDI/opaque preservation:** translation code is unchanged and existing preservation tests remain green.
- **Unknown targets:** blocked review behavior and wire-aware condition suites remain green.
- **Selection:** only successful execution returns created IDs for ContentView to select; stale errors return before the selection assignment path.
- **Conflict scope:** live-match revalidation reads only the proposal's owning device.
- **Repository hygiene:** `git diff --check` passed; the SDD ledger was not modified; no push or deploy was performed.

## Delivery Risk Assessment

### Hidden scope items covered

- Multi-conflict rows required both a domain decision model and a compact replacement-target control; changing only executor branching would not prevent contradictory UI state.
- Ordered execution required retaining skipped/reviewed positions, not sorting only the final insert arrays.
- Stale validation required recording the original match classification as well as IDs so an exact duplicate changing into a functional conflict (or vice versa) cannot silently change the plan's meaning.
- Device disambiguation had to consider all devices, including duplicate or blank names, before building selected rows.
- The menu fix needed a reusable presentation list so tests validate actual options rather than source text.

### Test breakage surface

The direct breakage surface is seven files: four production files and three test files listed above. The broader regression surface includes condition wire modeling, planner/executor behavior, TSI writing, document Undo, ContentView selection handoff, review presentation, and batch editing; all are covered by the focused and full gates.

### Rollback

Every change is reversible by reverting the single final-fix commit. There is no persisted schema migration, external data write, network side effect, or irreversible operation. Rollback restores the prior review-row model, execution traversal, stale-reference behavior, labels, and menu options together, avoiding a partially compatible state.

## Concerns

No blocking concern remains. Two non-blocking observations:

1. The project continues to emit pre-existing Swift actor-isolation and package dependency-scan warnings during Release builds; this wave does not expand or resolve that separate migration surface.
2. The review sheet is covered through production presentation/state tests and compilation, not a screenshot/UI automation test. Its width and compact sheet structure remain unchanged, and multi-conflict replacement adds only a conditional picker.

## Verdict

Ready to ship from the scope of this final fix wave. All five findings are resolved, focused/full tests and the no-sign Release build pass, rollback is fully reversible, and there are no unresolved integration gaps.
