# Deck Clone Context Menu Implementation Plan

> **For Codex:** Use `superpowers:executing-plans` and complete each task test-first. Do not change the source mappings, bypass TSI preflight, or mix unrelated working-tree changes into this feature.

**Goal:** Add a plain right-click action that clones selected Deck A mappings to Deck B, C, D, or all three, safely updating deck references and comments.

**Architecture:** Keep SwiftUI responsible only for collecting the destination and any conflict choices. A pure planner will resolve selected mappings, create proposed copies, translate deck-specific fields, and classify duplicates or conflicts. An executor will build and preflight a complete candidate `MappingFile`, then commit it through one undoable document mutation.

**Tech Stack:** Swift 6, SwiftUI for macOS, XCTest/Swift Testing, existing `TSIWriter` round-trip infrastructure.

---

## Task 1: Model native condition targets

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/MappingEntry.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/ImportedCMAD.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/SemanticBindingKey.swift`
- Create: `XtremeMapping/XtremeMappingTests/ModifierConditionTargetTests.swift`

1. Write focused tests proving imported condition targets enter `ModifierCondition`, known target values round-trip through `TSIWriter`, unknown raw values are preserved, and older Codable data defaults safely.
2. Run only `ModifierConditionTargetTests` and confirm the new assertions fail for the missing model state.
3. Add a wire-aware target representation to `ModifierCondition` with a backward-compatible default. Parse it from CMAD condition target fields and write it back without disturbing unrelated optional bytes.
4. Update imported semantic fingerprints and `SemanticBindingKey` to use modeled targets rather than rejecting every nonzero target.
5. Re-run the focused tests and the existing TSI preservation/interpreter tests.

## Task 2: Build the pure clone planner

**Files:**
- Create: `XtremeMapping/XtremeMapping/Services/MappingTransformService.swift`
- Create: `XtremeMapping/XtremeMappingTests/MappingTransformServiceTests.swift`

1. Write tests for Deck A to B/C/D and B+C+D, Remix slot preservation, condition-target translation, casing-preserving comment edits, conservative non-edits, ignored rows, device ownership, order, and fresh IDs.
2. Add tests for exact duplicate skipping, functional conflicts, and legitimate same-MIDI multi-command macros.
3. Run `MappingTransformServiceTests` and confirm the tests fail because the planner does not exist.
4. Implement `DeckCloneDestination`, `MappingTransformRequest`, `MappingTransformPlan`, review-item/choice types, and `MappingTransformPlanner` as pure value-based code.
5. Keep matching scoped to the source device. Define exact duplicates from all writable semantic data except UUID; define review conflicts from functional identity while excluding MIDI and comment.
6. Re-run the focused tests until green.

## Task 3: Add validated, undoable execution

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Services/MappingTransformService.swift`
- Create: `XtremeMapping/XtremeMappingTests/MappingTransformExecutorTests.swift`

1. Write tests for applying Keep Existing, Create Another, and Replace Existing; selecting created IDs; one-step undo/redo; and failed preflight leaving the document and Undo stack unchanged.
2. Run `MappingTransformExecutorTests` and confirm the executor tests fail.
3. Implement resolution of review choices into a candidate file, validate that candidate with `TSIWriter`, and only then call `performUndoableMutation` with one `Clone Deck A Mappings` action.
4. Return created IDs and the compact result sentence from execution.
5. Re-run the focused executor tests until green.

## Task 4: Connect the context menu and compact review sheet

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Views/MappingsTableView.swift`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`
- Create: `XtremeMapping/XtremeMapping/Views/DeckCloneReviewSheet.swift`
- Create: `XtremeMapping/XtremeMappingTests/DeckClonePresentationTests.swift`

1. Write presentation tests for menu eligibility, destination labels, and exact plain status copy.
2. Run the focused tests and confirm the missing presentation behavior fails.
3. Add `Clone Deck A to` with Deck B, Deck C, Deck D, and `Decks B, C and D` actions. Enable it only for an unlocked document with at least one eligible selected mapping.
4. Group existing batch edits under `Change`, with Deck, MIDI Channel 1–16, and Comment actions. Reuse current batch mutation paths so each action remains one undo step.
5. In `ContentView`, plan immediately after the menu action. Execute immediately when there are no conflicts; otherwise show a compact sheet with one row per conflict and only Keep Existing, Create Another, and Replace Existing.
6. On success, select the created mappings and display the one-sentence result. On failure, show the existing plain error style and leave the document unchanged.
7. Re-run focused presentation and transformation tests.

## Task 5: Verify round-trip safety and regressions

**Files:**
- Modify only if a failure identifies a feature-owned defect.

1. Run focused transformation, executor, condition-target, transfer, interpreter, and preservation tests.
2. Run `scripts/test-unit.sh` and require a passing result with zero failures.
3. Build the app with code signing disabled.
4. Inspect `git diff` to confirm only feature-owned files and the approved docs are staged.
5. Request a fresh independent code review against the pre-implementation commit. Address every confirmed finding, then repeat focused and full verification.
6. Commit the verified implementation without pushing or deploying.

## Recovery

The user can undo a completed clone in one step inside SXM. Before release, the implementation commit can be reverted without touching unrelated user work. A TSI preflight failure never mutates the live document, so it needs no data recovery.
