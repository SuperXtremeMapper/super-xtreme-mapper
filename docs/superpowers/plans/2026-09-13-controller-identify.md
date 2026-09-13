# Plan: Controller Identify workflow

Spec: docs/superpowers/specs/2026-09-13-controller-identify-design.md · Rung: medium

Verification (run after every chunk):
`cd XtremeMapping && xcodebuild build -scheme XtremeMapping -project SuperXtremeMapping.xcodeproj -destination 'platform=macOS' -configuration Debug > /tmp/ci.log 2>&1; echo EXIT=$?; grep -E "BUILD SUCCEEDED|error:" /tmp/ci.log`
Global acceptance: BUILD SUCCEEDED; AppThemeV2.swift unchanged (`git diff --quiet -- .../Theme/AppThemeV2.swift`); no native Picker/TextField in the new identify step.

## Chunk A — Reverse resolver + Physical Control column

- [ ] A1. In `ControllerControlResolver.swift`, add a non-mutating helper
  `physicalNames(configuration:profile:device:) -> [UUID: String]` (or a
  `reverseIndex(...) -> [MIDIAssignment: String]` + row mapping). Build by
  iterating `profile.controls`, resolving each control's bindings for the
  configured layer/direction (reuse existing `resolve`), and mapping each
  binding's MIDI address → control display name; then map device rows whose
  `midiAssignment` matches. Do not modify existing `resolve`/`matchingRows`.
- [ ] A2. In `ContentView.swift`, compute a `[UUID: String]` row→physicalName map
  for the currently shown device using the associated profile config from
  `interchangeMetadata.deviceProfiles` + `ControllerProfileLibrary`. Recompute on
  `explanationRevision` change. Pass it into the table view.
- [ ] A3. In `MappingsTableView.swift`, add `physicalNames: [UUID: String] = [:]`
  input and a `TableColumn("Physical")` inserted after the MIDI column, rendering
  `physicalNames[entry.id] ?? ""` in `AppThemeV2` body style. Existing columns
  untouched. Column contributes nothing when the map is empty.
- Acceptance: with a K-series profile associated, matching rows show the physical
  name in the new column; CC/MIDI column still shows numbers; unmatched rows blank.

## Chunk B — Identify screen (restructure ControllerProfileSheet)

- [ ] B1. Add sheet state `mode: .identify | .advanced` (default `.identify`).
- [ ] B2. Build `identifyStep` view using V2 components only: `V2TextField`
  search bound to `query`; a scrollable grouped results list (manufacturer
  section headers + selectable rows) filtered by `query`; each row shows model +
  a coverage chip via `ControllerProfileCoverage.label`. Selecting sets the draft
  profile (reuse `chooseProfile`).
- [ ] B3. Confirm strip: chosen controller name + coverage + a `V2Dropdown` MIDI
  channel bound to the existing `setting(\.globalChannel, fallback: 15)`
  (documented default). Footer: `V2SmallButton` "Skip — keep generic" (dismiss,
  no write) and primary "Confirm controller" (existing `apply(showMappings:)`).
  Keep the "settings describe your hardware; they never change your mapping" line.
- [ ] B4. Header: title "Which controller is this?", subtitle, and a device
  switcher (`V2Dropdown` over `document.mappingFile.devices`) bound to a new
  `@Binding`/callback so the sheet can retarget `deviceID` — see C3.
- [ ] B5. Move the current dense content (modes, unit map, port, control list,
  details, overrides, export, doc-only messaging) behind `mode == .advanced`,
  reached by an "Advanced…" `V2SmallButton`. No logic removed.
- Acceptance: identify step renders with V2 components only; picking a controller
  + Confirm writes the association (undoable) exactly as before; Advanced still
  exposes all prior functionality.

## Chunk C — On-load banner + wiring + switcher

- [ ] C1. In `ContentView.swift` add `@State private var identifyBannerDismissed = false`
  and computed `devicesNeedingProfile: [Device]` = devices with no
  `deviceProfiles` entry (and not documentation-only-skip). 
- [ ] C2. Render an `AssistantNoticeBanner`-styled soft banner above the mappings
  header when `!devicesNeedingProfile.isEmpty && !identifyBannerDismissed && !isLocked`.
  "Identify controller" → `activeSheet = .controllerProfile(devicesNeedingProfile.first!.id)`.
  "Not now" → `identifyBannerDismissed = true`.
- [ ] C3. Extend `ControllerProfileSheet` init to accept the device list / allow
  retargeting `deviceID` from the switcher (B4). Simplest: make `deviceID` a
  `@State` seeded from the passed id; switcher updates it; draft reloads on change.
- [ ] C4. Add a persistent re-open entry (small "Controller" `V2ToolbarButton`/
  icon in the existing header cluster) that opens the sheet for the shown device —
  so dismiss isn't a dead end.
- Acceptance: fresh multi-device TSI shows the banner; Identify opens the screen
  on the first unidentified device; switcher moves between devices; Not now hides
  the banner; the re-open entry reopens it.

## Rollback
Revert the four files (+ any new identify view file). Feature is additive and
gated on an associated profile; removal restores prior behavior.
