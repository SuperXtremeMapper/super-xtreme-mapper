# Claude handoff: integrated workflow and UI cleanup

Prepared 12 September 2026. Project: `/Users/noahraford/Projects/XtremeMapping`. Work on the existing `main` branch as requested by the user. Inspect current changes before editing: the controller-library work is local and uncommitted. Preserve that work and the Assistant improvements already on main. Do not reset, clean, overwrite or indiscriminately stage the workspace.

This is the consolidated change list agreed with the user. It supersedes the earlier Assistant-only handoff for scope and recommendations. That handoff remains useful as a function inventory: [earlier function inventory](2026-09-12-claude-assistant-ui-ux.md). Verify behavior against current code rather than relying on its historical counts or labels.

## Outcome

Make the mapping table the centre of the app. Controller knowledge and Assistant should support the user's work there. Users should be able to open a TSI, understand an assignment, identify a physical control, request a change, inspect the affected rows, review, apply and undo without navigating unrelated feature panels.

Keep the existing native macOS stone/amber appearance and dense editor. This is workflow consolidation and component consistency, not a new visual identity. One Assistant message box, one Send button. Voice dictates into that box; replies remain text. Generic mappings and ordinary editing must work without a controller profile or AI key.

## 1. Consolidate navigation and entry points

- Keep one main Assistant toolbar button. Remove the duplicate Assistant button above the table.
- Add `Ask about selected mappings` to the table contextual menu. Open the same document-bound Assistant with those rows attached.
- Keep Wizard functionality available but describe its purpose clearly, such as `Create mappings step by step…`. It must not look like an alternative chat mode. A concise toolbar label with explanatory help is acceptable where space is constrained.
- Move controller association into the mapping device's setup/details workflow. A TSI mapping device and physical hardware are distinct; do not silently equate their names or MIDI ports.
- Keep reference-guide generation and exports discoverable, including without an AI key. Distinguish exporting the current reply from exporting the complete mapping guide.

## 2. Make controller setup a short, focused task

Normal flow: select mapping device, choose physical controller, confirm applicable hardware channel/mode/port, save the association and return to editing.

- Show the associated controller in device context. Make established physical-control names available in mapping details and Assistant context without requiring repeated visits to the library.
- Put manuals, evidence, coverage limitations, protocol details and address corrections under optional `Controller details`.
- Separate initial association from the current combined setup/control-browser/override inspector. Retain advanced capabilities but reveal them when needed.
- Use searchable model selection suitable for 47 entries; include manufacturer where needed to disambiguate. Avoid a huge undifferentiated protocol list as the primary experience.
- Display `Partial MIDI coverage` and `Documentation only` honestly. Documentation-only entries have no invented controls. Offer their sources and existing row MIDI Learn guidance.
- Controller selection describes hardware settings; it does not reconfigure the hardware or install a Traktor mapping. Do not imply automatic hardware detection or complete coverage.
- If several source variants could match, expose the relevant context or uncertainty rather than displaying one guessed physical identity.

## 3. Make Assistant scope explicit

Replace the ambiguous `Use N selected mappings` toggle with a clear scope summary/control. Show understandable context such as `Entire mapping`, `Selected rows · 4`, or an attached `Captured control · Fader 1` when that identity is established.

- Captured MIDI may supplement selected rows; do not incorrectly force those into mutually exclusive modes. Show what is included and allow removing attachments.
- Opening from selected rows attaches those rows automatically. Ordinary toolbar opening must show its actual scope.
- Each submitted request and edit proposal should make its scope clear. Changing the live table selection must not silently retarget a request already submitted or a pending proposal.
- Keep the current revision/stale-proposal protections and explicit Apply requirement.
- AI setup should be a clear first-use step, then a secondary settings control. Do not permanently crowd the composer with setup instructions, counters and technical details. Retain necessary consent and active listening indications; reveal length limits when relevant.

## 4. Distinguish capture actions by consequence

Use consistent labels with distinct meanings:

| Location | Suggested action | Effect |
|---|---|---|
| Mapping inspector | Learn MIDI assignment | Assign a captured address to the selected mapping using existing editing semantics |
| Assistant | Identify a control | Capture MIDI as request context, without immediately changing a mapping |
| Controller details | Correct this control's address | Record a local, context-specific override |

Assistant flow: identify a control, move it, see the captured attachment, then type or dictate what to ask/change and Send. If the physical name is unknown, show its MIDI address without inventing a label. Keep explicit stop/cancel/clear behavior. Voice is dictation, not a separate assistant or automatic submission mechanism.

## 5. Connect answers and reviews to the table

- Use `Show these mappings` to navigate from an answer to relevant rows. Keep conversation and draft intact while the user inspects the editor; provide an easy way back.
- Preserve the floating Assistant if it works well. Do not introduce a new docked layout merely to satisfy this brief.
- Show edit reviews using meaningful control/command names, device, deck and before/after values. Put internal UUIDs and raw technical details behind disclosure.
- Show affected-row count, request scope and a clear pending/applied/discarded state.
- Keep Apply and Discard, with a clear Undo route after application. Never turn a conversational answer into an automatic mutation.

## 6. Establish shared typography and form controls

Current issues: fixed sizes and system text styles are mixed; native Pickers, custom dropdowns and bare Menus differ; field widths and chevron positions vary; essential labels can be smaller and dimmer than necessary.

Use these as starting sizes, verify visually in the actual macOS app:

| Role | Baseline |
|---|---|
| Command names, table content, selected dropdown text, text-field values | 12 pt regular |
| Field labels and supporting text | 11 pt regular |
| Section labels | 11 pt semibold |
| Panel titles | 13–14 pt semibold |
| MIDI addresses/numeric values | 12 pt monospaced |
| Assistant prose and composer | 13 pt regular |

- A command should have equivalent readability in the table, inspector and selection control. Use weight and spacing for hierarchy, not arbitrary size changes.
- Reserve tiny badge typography for nonessential badges. Do not use it for required settings or instructions.
- Retain native opened-menu behavior and accessibility. macOS may control popup-menu typography; do not replace native menus solely to force pixel-identical fonts.
- Standardise closed dropdowns: left-aligned selected text, trailing chevron anchored to the right, common background/border/radius/padding and a consistent height, initially 28 pt for form controls.
- Dense table/header controls may use a documented compact size; no random per-screen heights.
- Text fields, dropdowns and numeric controls sharing a row must align vertically and use matching heights.
- Align inspector labels in one column and values in another. Let fields fill their column rather than changing width with the selected option.
- Do not shrink long command/model names. Use sensible minimum widths, full menu labels and access to the complete selected text when truncated.
- Preserve visible focus, keyboard navigation, selected checkmarks, disabled states and readable contrast. Do not indicate state solely by color.

## 7. Rebuild the modifier conditions section first

This is the user's strongest specific complaint. The current active condition is a wide two-line block; the empty condition becomes a small centred None control. Values, arrows and widths do not align. Invert appears close enough to be mistaken for part of the conditions.

- Label the section `Modifier conditions`, with compact help: `Run this mapping only when these conditions match.`
- Use two consistent rows with aligned condition and value columns. Preserve width and height when a condition is None; disable its empty value field.
- Show that two active conditions combine with AND. Do not imply OR or add unsupported operators.

Illustrative structure, not a pixel specification:

    Condition                 Value
    [M4                    ▾] [0  ▾]
                   AND
    [None                  ▾] [—   ]

- For deck/state/remix conditions, show the actual named condition, its meaningful value and a labelled target where applicable. Preserve all existing condition types, target choices and native unknown values.
- Avoid reducing this to M1–M8 only. Do not coerce imported conditions or discard opaque data merely because the new form cannot interpret it.
- Put Invert with the mapping's applicable interaction settings, clearly outside the modifier-conditions section.
- For multiple selected mappings, show `Multiple values` where values differ. Do not present the first row's value as common to the selection. An explicit choice updates the intended field across the selection; displaying or opening the form must not mutate anything.
- Retain existing batching, Undo and preservation behavior. Test mixed selections and nonstandard imported conditions.

## 8. Restyle and regroup table-header controls

The user specifically finds Manual Order and Edit Selection out of place.

- Use the shared app toggle for `Manual order`, with help: `Preserve your row sequence and enable drag reordering.` Preserve the actual existing ordering semantics.
- If filters or another state prevent reordering, explain the reason. Do not imply that enabling the toggle overrides these restrictions.
- Rename `Edit Selection` to `Edit selected…`. Use the shared dropdown-button treatment with consistent font, surface, border, height and trailing chevron.
- Disable the edit menu when nothing is selected. Show `4 selected` or equivalent nearby when applicable.
- Group ordering and selection actions at the right of the mapping header with consistent alignment and spacing. Remove the duplicate Assistant entry and relocate controller setup as described above.
- The header should communicate view context, ordering and selection actions. Avoid turning it into a feature launcher.

## 9. Clarify saving and exporting without risking preservation

Important workflow issue: TSI saves the Traktor mapping but cannot retain SXM controller annotations and overrides. Users should not discover this only through a footer telling them to export JSON.

Desired distinction: `Save SXM project` retains the SXM work; `Export TSI for Traktor` produces the Traktor file. JSON already provides a preservation-capable foundation, but a complete native project document lifecycle is not assumed to exist.

For this cleanup, make current save/export choices and metadata retention explicit. Do not merely rename TSI Save as project save, silently change existing Save behavior, or claim JSON retains data beyond its actual contract. If implementing a true project workflow requires new document types, autosave/restoration or migration, document that as a separate functional follow-up. Preserve standard macOS shortcuts and existing TSI compatibility.

## Suggested implementation order

1. Shared typography, dropdown/text-field styles and alignment rules.
2. Modifier conditions and the Manual order/Edit selected header controls.
3. Duplicate entry-point removal and clearer device/controller setup.
4. Assistant scope, capture naming and table-linked answer/review presentation.
5. Save/export clarity and a concise report of any remaining project-file work.

## Acceptance checks

- Compare the main table, inspector, controller setup and Assistant side by side. Command names, fields and dropdowns follow shared sizing rules.
- Check narrow and normal inspector widths, long command/model names, empty and populated documents, no selection, one selection and mixed selections.
- Both modifier rows align with None, M1–M8, targeted conditions and preserved unknown values. Opening the inspector makes no changes. Mixed-value edits and Undo work.
- Manual order and Edit selected belong visually to the app, expose correct enablement, and preserve reorder/filter behavior.
- Only one main Assistant launcher remains. Contextual launch attaches the intended rows; source navigation preserves conversation and draft.
- A request's scope stays stable after submission. Review uses readable before/after values and preserves stale/atomic-validation protections.
- Controller details remain accessible, including partial/documentation-only states. No source evidence, library resources, overrides or metadata are dropped.
- Test keyboard navigation, focus, disabled controls, menu checkmarks, accessibility labels and minimum supported window sizes.
- Run focused meaningful regressions for changed behavior, then the appropriate app suite. Existing latest batch baseline: 931 app unit tests and 33 manufacturer-data tests passed. Do not claim live AI, speech or hardware checks without actually exercising them.
- Inspect the rebuilt current app. The app instance observed during review was still showing the earlier 26-profile catalogue, while current bundled source contains 47; do not mistake an old running process for current build behavior.
- End with what changed, verification performed and specific remaining issues. No new manufacturers, community-template ingestion, graphical controller editor or AI capabilities are required by this cleanup.

## Useful implementation locations

- `XtremeMapping/XtremeMapping/Theme/AppThemeV2.swift`
- `XtremeMapping/XtremeMapping/Views/V2Components/V2FormControls.swift`
- `XtremeMapping/XtremeMapping/Views/V2Components/V2ModifierRow.swift`
- `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift`
- `XtremeMapping/XtremeMapping/Views/MappingsTableView.swift`
- `XtremeMapping/XtremeMapping/Views/UnifiedAssistantView.swift`
- `XtremeMapping/XtremeMapping/Views/ControllerProfileSheet.swift`
- `XtremeMapping/XtremeMapping/Views/MappingExplanationSheet.swift`
- `docs/manufacturer-library/2026-09-12/UI-WORKFLOW.md`
- `docs/manufacturer-library/2026-09-12/PARTIAL-INTEGRATION.md`

These are starting points, not an exhaustive edit list. Inspect current ownership and call sites before changing shared components.
