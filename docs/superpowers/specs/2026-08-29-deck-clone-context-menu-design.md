# Deck Clone Context Menu Design

**Date:** 2026-08-29

**Status:** Approved

## Goal

Let users select Deck A mappings and clone them to Deck B, C, D, or all three from the table's right-click menu. Update deck references in the copies, adjust clearly recognized deck names in comments, validate the complete result, and make the operation undoable.

## Product Decisions

1. The workflow starts with the selected mappings.
2. It lives in the existing table context menu. There is no user-facing "Transform Studio."
3. The source mappings remain unchanged.
4. Only Deck A and Remix Deck A mappings are cloned. Global, Device Target, FX, and other-deck mappings are ignored.
5. MIDI assignments stay unchanged during cloning.
6. Deck references in assignments, known condition targets, and recognized comment tokens are updated automatically.
7. Exact duplicates are skipped. Existing mappings are never replaced without an explicit choice.
8. The complete operation is validated before it changes the document and is registered as one Undo action.
9. UI text stays short and plain. Technical details remain internal.

## User Experience

The mapping table context menu adds:

```text
Clone Deck A to
  Deck B
  Deck C
  Deck D
  Decks B, C and D

Change
  Deck
  MIDI Channel
  Comment
```

`Clone Deck A to` is enabled when the document is unlocked and the selection contains at least one eligible Deck A mapping.

After a successful clone, the new mappings become the active selection. This lets the user immediately apply an existing batch action such as changing their MIDI channel.

The status bar reports the result in one sentence:

```text
30 mappings created. 4 duplicates skipped. 2 other mappings ignored.
```

If an existing mapping requires a decision, a small review sheet says:

```text
2 mappings need review.
```

Each item offers only these choices:

```text
Keep Existing
Create Another
Replace Existing
```

There is no review screen when every result is safe and unambiguous.

## Clone Rules

For every eligible selected mapping and requested destination deck:

1. Make a complete copy with a fresh ID.
2. Change Deck A to the destination deck in the primary assignment.
3. Change Remix Deck A slot assignments to the same slot on the destination deck.
4. Change known Deck A condition targets to the destination deck.
5. Update recognized Deck A tokens in the comment.
6. Preserve MIDI, command, direction, interaction, modifiers, controller settings, LED settings, and opaque native data that the edit does not own.
7. Insert the copy into the same device as its source.

New mappings retain source order. When cloning to all three decks, destination groups are inserted in Deck B, Deck C, then Deck D order.

## Comment Rules

Automatic comment edits are conservative and preserve capitalization:

```text
Deck A Loop  -> Deck B Loop
DECK A PLAY  -> DECK B PLAY
deck a sync  -> deck b sync
[A] Hotcue   -> [B] Hotcue
A: Tempo     -> B: Tempo
```

The automatic edit does not replace a bare letter `A` in ordinary text. For example, it leaves these unchanged:

```text
AUX Send
Layer A
Macro A1
Load A Track
```

Unusual naming schemes can be handled later through a separate plain `Find and Replace` comment action.

## Condition Targets

`ModifierCondition` currently stores only modifier number and value. Native condition target bytes may be preserved in `ImportedCMAD`, but they are not represented as editable model state.

Deck cloning therefore adds a wire-aware condition target value with two requirements:

1. Known Deck A targets can be changed safely to Deck B, C, or D.
2. Unknown target values retain their raw representation and are never guessed.

A selected mapping with an unknown target that would need rewriting is not cloned. The result reports that the mapping needs review.

The parser, writer, import fingerprint, semantic identity, Codable migration, and preservation checks must all understand the new modeled target. Existing documents and imported mappings without an editable target remain readable.

## Conflicts

Conflict checks are scoped to the source mapping's device.

- An exact duplicate has the same writable mapping data after ignoring its UUID. It is skipped automatically.
- A mapping with the same functional identity but different MIDI or comment data needs review.
- Sharing a MIDI control across different commands is allowed. Traktor macros commonly do this, so it is not treated as a conflict.
- Replace removes only the specific existing mapping shown in the review sheet and inserts the planned clone.
- Keep Existing omits the planned clone.
- Create Another keeps both mappings.

## Internal Design

The feature uses a reusable internal planning boundary even though the UI is a simple menu.

### `MappingTransformRequest`

Contains the selected mapping IDs and requested destination decks.

### `MappingTransformPlanner`

Reads a `MappingFile` and returns a plan without changing the document. It owns deck translation, comment rewriting, eligibility checks, conflict detection, and result counts.

### `MappingTransformPlan`

Contains the proposed inserts, skipped rows, ignored rows, review items, new selection IDs, and plain status text.

### `MappingTransformExecutor`

Builds a complete candidate `MappingFile`, validates it through `TSIWriter`, and commits it through `performUndoableMutation` only when the candidate is valid.

The context menu and any later bulk operations call these domain types. Transformation logic does not live in `ContentView` or `MappingsTableView`.

## Data Flow

1. The user selects mappings and chooses a destination from the context menu.
2. The planner resolves each selected row and its owning device.
3. Ineligible rows are counted and ignored.
4. The planner creates destination copies and checks them against existing mappings.
5. If review is required, the small review sheet gathers the user's choices and updates the plan.
6. The executor applies the plan to a candidate file.
7. `TSIWriter` validates the complete candidate.
8. One undoable document mutation replaces the live mapping file with the candidate.
9. The new mapping IDs become selected and the status bar shows the result.

## Failure Handling

- A locked document disables the clone menu.
- A stale or empty selection does nothing and shows no misleading success message.
- An unsupported native condition target is not rewritten.
- Invalid generated data prevents the entire commit.
- A failed validation leaves the document and Undo stack unchanged.
- If the selection spans devices, each eligible clone remains in its source device.
- Existing mappings are never silently deleted or replaced.

## Verification

Tests cover:

1. Deck A cloning to B, C, D, and all three.
2. Remix Deck slot translation while preserving the slot number.
3. Known condition target translation and unknown target preservation.
4. Conservative, case-preserving comment replacement.
5. Ignoring Global, Device Target, FX, and non-Deck-A rows.
6. Exact duplicate detection.
7. Functional conflicts with Keep Existing, Create Another, and Replace Existing.
8. Legitimate multi-command MIDI macros not being flagged as conflicts.
9. Source order and device ownership.
10. Selection of the created mappings.
11. One-step undo and redo.
12. TSI write and reparse using generated files and real sanitized fixtures.
13. A failed preflight leaving the document and Undo stack unchanged.

## Out of Scope

- Changing MIDI during Deck Clone.
- Sequential MIDI ranges and MIDI offsets.
- General-purpose formulas or scripting.
- Automatically rewriting ambiguous bare letters in comments.
- Cloning Global, Device Target, or FX mappings as part of a Deck A operation.
- A permanent Transform Studio window or inspector.
