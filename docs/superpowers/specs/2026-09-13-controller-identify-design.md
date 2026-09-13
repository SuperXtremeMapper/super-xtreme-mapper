# Controller Identify workflow — design spec

Date: 2026-09-13 · Effort ceiling: medium

## Problem

When a TSI loads, SXM does not know which physical hardware the Generic-MIDI
devices represent. The `ControllerProfileLibrary` holds per-model profiles that
map physical controls (e.g. "Play button") to MIDI addresses, and the document
can store a per-device association in `mappingFile.interchangeMetadata.deviceProfiles`.
Today none of this is reachable:

1. No prompt appears on load when a device has no associated profile.
2. The association screen (`ControllerProfileSheet`) is orphaned — nothing ever
   sets `activeSheet = .controllerProfile(deviceID)` in `ContentView.swift`.
3. That screen is a dense inspector (native pickers + jargon: unit map, operating
   mode, port, coverage state), wrong for a first-run "which controller?" ask.
4. The mapping table shows only raw CC/MIDI — never the physical control name.

## Success criteria (measurable)

- Loading a TSI whose device(s) have no `deviceProfiles` entry shows a soft,
  dismissible notice banner above the table with **Identify controller** and
  **Not now**. Dismiss is session-scoped, not permanent.
- The identify flow is re-openable after dismiss via a persistent entry point.
- The identify screen is a clean "Which controller is this?": searchable
  brand/model list grouped by manufacturer, plain coverage chips
  (FULL MIDI / PARTIAL / DOCS ONLY), a confirm strip with the chosen controller
  + MIDI channel pre-filled to the documented default, and Skip / Confirm.
- It uses ONLY AppThemeV2 tokens + V2 components (no native `Picker`/`TextField`
  for the identify step). AppThemeV2 token values are unchanged (byte-identical).
- Multi-device files identify ONE device at a time via a header switcher.
- The dense controls (unit map, operating mode, port, control list, overrides,
  export) remain available in an advanced panel reached after/aside identify —
  no capability is removed.
- A new **Physical Control** column is ADDED to the mappings table. Existing
  columns (I/O, Assignment, Command, Comment, Type, Interaction, MIDI, Mod 1/2)
  and their CC/MIDI values are unchanged. The new column shows the resolved
  physical-control name for a row when an associated profile resolves its MIDI
  address; blank otherwise. It appears only when the row's device has a profile.
- `xcodebuild build … -scheme XtremeMapping` exits 0 / BUILD SUCCEEDED.

## Approach

**Reverse resolver (chunk A).** `ControllerControlResolver` currently resolves
control → bindings and control → matching rows. For the column we need the
reverse (row MIDI → control name). Add a helper that, given a profile
configuration + device, builds a MIDI-address → control-display-name index by
resolving every control's bindings once, then maps each row's `midiAssignment`
to a name. Build the index per device per revision (cheap; profiles are small)
and cache in the table view model input. No change to existing resolver methods.

**Physical Control column (chunk A).** The table is SwiftUI `Table`/`TableColumn`.
Add one `TableColumn("Physical")` after the MIDI column, rendering the resolved
name (or empty). Feed it a `[UUID: String]` row→name map computed in ContentView
from the device's associated profile; nil map = column shows blank / hidden.

**Identify screen (chunk B).** Split `ControllerProfileSheet` into:
- an **identify step** (new, clean, V2-component based): search field, grouped
  results list with coverage chips, confirm strip (controller + channel), footer
  Skip / Confirm, truth-telling line, device switcher in the header;
- the **advanced/inspect panel** (the existing dense content: modes, unit map,
  port, control list, overrides, export) reached via an "Advanced…" affordance.
The two live in the same sheet, identify shown first. Selecting a controller
writes the same `ControllerConfiguration` draft the sheet already manages;
Confirm applies it (the existing `apply` path). Skip dismisses without writing.

**On-load banner + wiring (chunk C).** In `ContentView`, compute
`devicesNeedingProfile` (devices with no `deviceProfiles` entry). If non-empty
and not session-dismissed, render an `AssistantNoticeBanner`-styled notice above
the mappings header. **Identify controller** sets
`activeSheet = .controllerProfile(firstUnidentifiedDeviceID)`. **Not now** sets a
`@State` dismissed flag. A persistent re-open entry (a small Controller control
in the mappings header area or the existing header cluster) also sets the sheet.
The sheet's header device switcher lets the user move between devices.

## Alternatives considered

- **Auto-detect the controller from MIDI channel/addresses** — rejected: the
  library is documented address lookup, not fingerprinting; guessing a brand is
  exactly what the profiles' provenance rules forbid. The user names it.
- **Replace CC numbers with physical names in existing columns** — rejected by
  the user: they want both. Hence an additive column.
- **A separate standalone identify window** — rejected: a sheet keeps it modal,
  cheap, and consistent with the app's other sheets; re-entrancy is simpler.
- **Rebuild the sheet from scratch** — rejected: the existing sheet already has
  correct draft/apply/undo/export/MIDI-learn logic. We re-skin the front and
  demote the dense parts, preserving that logic.

## Blast radius / rollback

- Files: `ControllerProfileSheet.swift` (restructure), `ContentView.swift`
  (banner + wiring + row→name map), `MappingsTableView.swift` (one column),
  `ControllerControlResolver.swift` (add reverse helper, no edits to existing
  methods). Possibly one new small view file for the identify step.
- No model/schema change: reuses `deviceProfiles` / `ControllerConfiguration`.
- No AppThemeV2 token change.
- Rollback: revert these files; the feature is additive and gated on an
  associated profile, so removing it restores prior behavior exactly.

## Open questions

- None blocking. Advanced-panel entry placement (button vs segmented) is a
  cosmetic choice resolved in the plan using existing components.
