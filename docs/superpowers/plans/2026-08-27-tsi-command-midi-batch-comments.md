# Reliable TSI Commands, MIDI, Batch Transfer, and Comments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make command IDs and MIDI control data reliable in Traktor Pro 4.4.1 mappings, then add lossless cross-document macro transfer, shared MIDI reassignment, and first-class comments.

**Architecture:** Store the raw Traktor command ID and a validated MIDI assignment as domain data, with names and verification status supplied by one catalog. Parse and emit direction-specific DDCI/DDCO definitions, centralize mapping cloning/transfer/undo in testable services, and keep SwiftUI views as thin bindings over those operations.

**Tech Stack:** Swift 6, SwiftUI/AppKit, ReferenceFileDocument, CoreMIDI, XCTest, Swift Testing, Xcode 26/macOS.

**Spec:** `docs/superpowers/specs/2026-08-27-tsi-command-midi-batch-comments-design.md`

## Global Constraints

- Traktor Pro 4.4.1 is the source of truth for commands offered when creating or changing a mapping.
- Imported positive legacy or unknown command IDs must be preserved exactly through save, copy, paste, and MIDI reassignment.
- Command ID `0` remains invalid/placeholder data and must never be silently converted to another command.
- New command creation and Voice Learn may use only `verifiedTraktor441` catalog entries.
- MIDI channels are `1...16`; Note and CC numbers are `0...127`; a mapping is Note, CC, or Unassigned, never Note and CC simultaneously.
- DDCI contains input definitions and DDCO contains output/LED definitions; generic DCDT values are `0 = 3Fh/41h` and `1 = 7Fh/01h`.
- One MIDI Learn event applies the same assignment to every selected mapping and preserves each row's other settings.
- Every mapping clone preserves every field except UUID; mapping batches remain in original order and pasted rows remain selected.
- Mapping and device comments remain Unicode-safe and lossless in TSI, JSON, duplicate, copy, and paste paths.
- Keep the existing AppThemeV2 visual system, native controls, compact product density, restrained amber accent, and system typography.
- Do not add dependencies, automate Traktor's live preferences UI, or commit any personal TSI file.
- Preserve unrelated files and changes; all feature work remains on `codex/tsi-midi-batch-comments`.
- Every production behavior change follows a witnessed red-green test cycle.

---

### Task 1: Repeatable Unsigned Unit-Test Runner

**Files:**
- Create: `scripts/test-unit.sh`

**Interfaces:**
- Consumes: `XtremeMapping/SuperXtremeMapping.xcodeproj`, scheme `XtremeMapping`.
- Produces: `scripts/test-unit.sh [xcodebuild test-selection arguments]`, a stable unit-test entry point that excludes UI automation, disables signing, serializes tests, and prints the result bundle path.

- [ ] **Step 1: Record the current full-run baseline**

Run:

```bash
xcodebuild test \
  -project XtremeMapping/SuperXtremeMapping.xcodeproj \
  -scheme XtremeMapping \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO
```

Write the result bundle to a temporary path and inspect it with:

```bash
xcrun xcresulttool get test-results summary --path "$result_bundle" --format json
```

Expected baseline on this host: unit tests execute, while the combined result is not a clean acceptance gate because the UI runner and existing serialized regressions can fail. Record the actual summary instead of assuming a particular shell exit code or signing failure.

- [ ] **Step 2: Add the focused runner**

Create this executable file:

```zsh
#!/bin/zsh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"
test_output="$(mktemp -d -t xtrememapping-unit-tests)"

printf 'Test artifacts: %s\n' "$test_output"

set +e
xcodebuild test \
  -project "$repo_root/XtremeMapping/SuperXtremeMapping.xcodeproj" \
  -scheme XtremeMapping \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath "$test_output/DerivedData" \
  -resultBundlePath "$test_output/UnitTests.xcresult" \
  CODE_SIGNING_ALLOWED=NO \
  -skip-testing:XtremeMappingUITests \
  -parallel-testing-enabled NO \
  "$@"
xcode_status=$?
set -e

result_bundle="$test_output/UnitTests.xcresult"
summary_file="$test_output/summary.json"

guard_result() {
  if [[ ! -d "$result_bundle" ]]; then
    printf 'No result bundle was produced (xcodebuild exit %d).\n' "$xcode_status" >&2
    return 1
  fi

  xcrun xcresulttool get test-results summary \
    --path "$result_bundle" \
    --format json > "$summary_file"

  /usr/bin/python3 - "$summary_file" "$xcode_status" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    summary = json.load(handle)

passed = int(summary.get("passedTests", 0))
failed = int(summary.get("failedTests", 0))
result = summary.get("result")
xcode_status = int(sys.argv[2])

print(f"Unit result: {result}; passed={passed}; failed={failed}")
if xcode_status != 0 or result != "Passed" or passed <= 0 or failed != 0:
    raise SystemExit(1)
PY
}

guard_result
```

Run: `chmod +x scripts/test-unit.sh`

- [ ] **Step 3: Verify the runner executes a real unit suite**

Run:

```bash
scripts/test-unit.sh -only-testing:XtremeMappingTests/MappingEntryTests
```

Expected: `MappingEntryTests` executes with zero failures, `passedTests > 0`, `failedTests == 0`, the result is `Passed`, no UI test identifier appears in `xcrun xcresulttool get test-results tests`, and the printed `.xcresult` exists. The runner itself must exit nonzero if these postconditions are not met.

- [ ] **Step 4: Commit**

```bash
git add scripts/test-unit.sh
git commit -m "test: add reliable unsigned unit runner"
```

---

### Task 2: Versioned Command Catalog and Verified Creation Menu

**Files:**
- Create: `XtremeMapping/XtremeMapping/Models/TSI/TraktorCommandDescriptor.swift`
- Create: `XtremeMapping/XtremeMapping/Models/TSI/Traktor441CommandEvidence.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TraktorCommands.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/CommandHierarchy.swift`
- Modify: `XtremeMapping/XtremeMappingTests/TraktorCommandsTests.swift`

**Interfaces:**
- Consumes: current `commandLookup`, `CommandHierarchy.categories`, the read-only Traktor 4.4.1 corpus audit, and CMDR commit `5b7950272a55f73034d2df15de2917248e2e9616` as a semantic cross-check.
- Produces: `TraktorCommandDescriptor`, conservative 4.4.1 direction evidence, `TraktorCommands.descriptor(for:)`, `TraktorCommands.verifiedDescriptors(supporting:)`, `TraktorCommands.verifiedDescriptor(named:supporting:)`, `TraktorCommands.id(forLegacyName:)`, and `CommandHierarchy.verifiedCategories(for:)`.

- [ ] **Step 1: Write failing catalog-behavior tests**

Add tests that name the known breaks:

```swift
func testUnknownPositiveIDGetsStableUnknownDescriptor() {
    let descriptor = TraktorCommands.descriptor(for: 4242)
    XCTAssertEqual(descriptor.id, 4242)
    XCTAssertEqual(descriptor.name, "Unknown command #4242")
    XCTAssertEqual(descriptor.verification, .unknown)
}

func testZeroIsInvalidRatherThanUnknown() {
    let descriptor = TraktorCommands.descriptor(for: 0)
    XCTAssertEqual(descriptor.id, 0)
    XCTAssertEqual(descriptor.verification, .legacy)
    XCTAssertTrue(descriptor.supportedDirections.isEmpty)
}

func testKnownUnverifiedCommandIsLegacyNotCreatable() {
    let descriptor = TraktorCommands.descriptor(for: 8194)
    XCTAssertEqual(descriptor.verification, .legacy)
    XCTAssertNil(TraktorCommands.verifiedDescriptor(named: descriptor.name, supporting: .input))
}

func testMeterCommandsUseTargetSelectedIDs() {
    XCTAssertEqual(TraktorCommands.descriptor(for: 2688).name, "Deck Pre-Fader Level (L)")
    XCTAssertEqual(TraktorCommands.descriptor(for: 2689).name, "Deck Pre-Fader Level (R)")
    XCTAssertEqual(TraktorCommands.descriptor(for: 2690).name, "Deck Post-Fader Level (L)")
    XCTAssertEqual(TraktorCommands.descriptor(for: 2691).name, "Deck Post-Fader Level (R)")
    XCTAssertEqual(TraktorCommands.descriptor(for: 2703).name, "Master Out Level (L+R)")
    XCTAssertEqual(TraktorCommands.descriptor(for: 2712).name, "Deck Pre-Fader Level (L+R)")
    XCTAssertEqual(TraktorCommands.descriptor(for: 2713).name, "Deck Post-Fader Level (L+R)")
}

func testConfirmedSemanticConflictsAreCorrected() {
    XCTAssertEqual(TraktorCommands.descriptor(for: 201).name, "Reverse Playback On")
    XCTAssertEqual(TraktorCommands.descriptor(for: 203).name, "Is In Active Loop")
    XCTAssertEqual(TraktorCommands.descriptor(for: 736).name, "Current Step")
    XCTAssertEqual(TraktorCommands.descriptor(for: 738).name, "Pattern Length")
    XCTAssertEqual(TraktorCommands.descriptor(for: 3139).name, "Load Preview Player into Deck")
}

func testCreationHierarchyContainsOnlyDirectionVerifiedCommands() {
    let commands = CommandHierarchy.flatten(CommandHierarchy.verifiedCategories(for: .input))
    XCTAssertFalse(commands.isEmpty)
    XCTAssertTrue(commands.allSatisfy { $0.verification == .verifiedTraktor441 })
    XCTAssertTrue(commands.allSatisfy { $0.supportedDirections.contains(.input) })
    XCTAssertFalse(commands.contains { $0.id == 2688 })
    XCTAssertFalse(commands.contains { $0.id == 728 })

    let paired = CommandHierarchy.flatten(CommandHierarchy.verifiedCategories(for: .all))
    XCTAssertTrue(paired.allSatisfy {
        $0.supportedDirections.isSuperset(of: [.input, .output])
    })
}
```

Run:

```bash
scripts/test-unit.sh -only-testing:XtremeMappingTests/TraktorCommandsTests
```

Expected: FAIL because the descriptor/status APIs do not exist and the confirmed names are currently wrong.

- [ ] **Step 2: Add the descriptor type**

Implement:

```swift
struct TraktorCommandDescriptor: Identifiable, Hashable, Sendable {
    enum Verification: String, Codable, Hashable, Sendable {
        case verifiedTraktor441
        case legacy
        case unknown
    }

    let id: Int
    let name: String
    let verification: Verification
    let supportedDirections: Set<IODirection>

    func supports(_ direction: IODirection) -> Bool
}
```

Replace `CommandItem(id:name:)` with an ID-only wrapper whose initializer resolves `TraktorCommands.descriptor(for:)`; mechanically rewrite every hierarchy literal to `CommandItem(id:)`. Expose its descriptor properties for menu use. This removes the hierarchy's independent label copy. Add the exact recursive helper used by tests and menus:

```swift
static func flatten(_ categories: [CommandCategory2]) -> [TraktorCommandDescriptor]
static func verifiedCategories(for direction: IODirection) -> [CommandCategory2]
```

- [ ] **Step 3: Add the conservative audited 4.4.1 evidence sets**

The local read-only audit decoded 77 controller-bearing Traktor 4.4.1 files with 22,525 CMAI rows. Use only IDs whose current app label exactly matched the pinned semantic cross-check, plus the individually corrected IDs listed below. Observed direction is a conservative creation capability, not proof that the opposite direction is impossible.

```swift
static let inputOnlyIDs: Set<Int> = Set(
    [60, 64, 232, 246, 255, 256, 258, 266, 267, 268, 326, 349, 362, 363,
     364, 740, 2249, 2253, 2331, 3048, 5129]
    + Array(601...664)
)

static let outputOnlyIDs: Set<Int> = Set(
    [247, 323, 512, 513, 2238, 2302, 2333, 2334, 2335, 2336, 2337, 2338,
     2339, 2340, 2591, 2811]
    + Array(665...727)
)

static let bothDirectionIDs: Set<Int> = Set([
    7, 9, 19, 69, 119, 120, 123, 125, 202, 204, 206, 235, 237, 238,
    265, 321, 322, 338, 339, 348, 400, 402, 406, 729, 730, 731, 732,
    733, 2002, 2004, 2187, 2192, 2196, 2248, 2301, 2311, 2313, 2328,
    2350, 2351, 2401, 2402, 2403, 2404, 2408, 2409, 2473, 2548, 2549,
    2550, 2551, 2552, 2553, 2554, 2555, 4209,
] + Array(741...756))

static let correctedOutputOnlyIDs: Set<Int> = [201, 203, 736, 2688, 2689, 2703, 2712, 2713]
static let correctedBothDirectionIDs: Set<Int> = [738]
```

IDs 232, 513, and 740–756 are explicit descriptors absent from the old app catalog but locally observed and semantically cross-checked; they account for the additions to the direction sets above. Keep every other known positive ID `.legacy`. Do not promote IDs 261–262, 2690–2701, 2704, or 3139: their proposed labels are semantically corroborated but those IDs were not observed locally. Do not promote ID 728. Add count tests for `85 input-only`, `79 output-only`, `72 both-direction`, and `9 manually corrected` so accidental expansion is visible.

- [ ] **Step 4: Correct and consolidate catalog semantics**

Implement these APIs:

```swift
static func descriptor(for commandID: Int) -> TraktorCommandDescriptor
static func verifiedDescriptors(supporting direction: IODirection) -> [TraktorCommandDescriptor]
static func verifiedDescriptor(named name: String, supporting direction: IODirection) -> TraktorCommandDescriptor?
static func id(forLegacyName name: String) -> Int
static func name(for commandID: Int) -> String
```

Preserve the existing labels for the 217 exact-match IDs. Individually correct these nine observed conflicts in the catalog; because hierarchy items are now ID-only, their display names follow automatically:

```text
201 Reverse Playback On
203 Is In Active Loop
736 Current Step
738 Pattern Length
2688 Deck Pre-Fader Level (L)
2689 Deck Pre-Fader Level (R)
2703 Master Out Level (L+R)
2712 Deck Pre-Fader Level (L+R)
2713 Deck Post-Fader Level (L+R)
```

Add these locally observed missing descriptors to the catalog and appropriate hierarchy sections:

```text
232 Slot FX Amount (Submix) — input
513 Beat Phase — output
740 Selected Sample — input
741–756 Enable Step 1–16 — input and output
```

Correct these corroborated but unobserved legacy display labels without adding creation capability: `261 Slot Pre-Fader Level (L)`, `262 Slot Pre-Fader Level (R)`, `2690 Deck Post-Fader Level (L)`, `2691 Deck Post-Fader Level (R)`, `2692 Mixer Level (L)`, `2693 Mixer Level (R)`, `2694 Master Out Level (L)`, `2695 Master Out Level (R)`, `2696 Master Out Clip (L)`, `2697 Master Out Clip (R)`, `2698 Record Input Level (L)`, `2699 Record Input Level (R)`, `2700 Record Input Clip (L)`, `2701 Record Input Clip (R)`, `2704 Master Out Clip (L+R)`, and `3139 Load Preview Player into Deck`.

Remove the false Deck A/B/C/D dynamic expansion for 2688–2703. Deck selection remains `TargetAssignment` data.

Have `verifiedCategories(for:)` recursively remove legacy/unknown or direction-incompatible commands and empty categories. Have `TraktorCommands.allNames` return verified input names only. Replace every Voice Learn `isKnownCommand` and disambiguation guard with `verifiedDescriptor(named:supporting: .input)` so no alternate path can create a legacy/output-only command.

- [ ] **Step 5: Run catalog tests**

Run:

```bash
scripts/test-unit.sh -only-testing:XtremeMappingTests/TraktorCommandsTests
```

Expected: PASS. Mutation check: restoring the old 2688 deck expansion or promoting ID 728 must fail at least one test.

- [ ] **Step 6: Commit**

```bash
git add XtremeMapping/XtremeMapping/Models/TSI/TraktorCommandDescriptor.swift \
  XtremeMapping/XtremeMapping/Models/TSI/Traktor441CommandEvidence.swift \
  XtremeMapping/XtremeMapping/Models/TSI/TraktorCommands.swift \
  XtremeMapping/XtremeMapping/Models/TSI/CommandHierarchy.swift \
  XtremeMapping/XtremeMappingTests/TraktorCommandsTests.swift
git commit -m "fix: audit Traktor command catalog"
```

---

### Task 3: Authoritative Command ID in MappingEntry

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/MappingEntry.swift`
- Modify: `XtremeMapping/XtremeMappingTests/MappingEntryTests.swift`

**Interfaces:**
- Consumes: Task 2 catalog APIs.
- Produces: stored `MappingEntry.commandID`, derived `commandName` and `commandDescriptor`, backward-compatible JSON migration.

- [ ] **Step 1: Write failing command-identity tests**

```swift
@Test func testExplicitCommandIDWinsOverStaleEncodedName() throws {
    let entry = MappingEntry(commandID: 201)
    var json = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
    )
    json["commandName"] = "Loop Out"
    let data = try JSONSerialization.data(withJSONObject: json)

    let decoded = try JSONDecoder().decode(MappingEntry.self, from: data)
    #expect(decoded.commandID == 201)
    #expect(decoded.commandName == "Reverse Playback On")
}

@Test func testExplicitCommandIDDoesNotRequireRedundantName() throws {
    let entry = MappingEntry(commandID: 201)
    var json = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
    )
    json.removeValue(forKey: "commandName")
    let decoded = try JSONDecoder().decode(
        MappingEntry.self,
        from: JSONSerialization.data(withJSONObject: json)
    )
    #expect(decoded.commandID == 201)
}

@Test func testLegacyNameOnlyJSONDerivesCommandID() throws {
    let entry = MappingEntry(commandID: 100)
    var json = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
    )
    json.removeValue(forKey: "commandID")
    json["commandName"] = "Play/Pause (Deck Common)"
    let data = try JSONSerialization.data(withJSONObject: json)

    let decoded = try JSONDecoder().decode(MappingEntry.self, from: data)
    #expect(decoded.commandID == 100)
}

@Test func testUnknownPositiveCommandIDSurvivesCodable() throws {
    let entry = MappingEntry(commandID: 4242, comment: "Legacy macro")
    let decoded = try JSONDecoder().decode(
        MappingEntry.self,
        from: JSONEncoder().encode(entry)
    )
    #expect(decoded.commandID == 4242)
    #expect(decoded.commandName == "Unknown command #4242")
    #expect(decoded.comment == "Legacy macro")
}

@Test func testLegacySlotNameMigratesToCanonicalIDAndTarget() throws {
    let entry = MappingEntry(commandID: 251, assignment: .deckA)
    var json = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
    )
    json.removeValue(forKey: "commandID")
    json["commandName"] = "Slot 3 Volume"
    let data = try JSONSerialization.data(withJSONObject: json)

    let decoded = try JSONDecoder().decode(MappingEntry.self, from: data)
    #expect(decoded.commandID == 251)
    #expect(decoded.assignment == .remixDeckASlot3)
}

@Test func testHistoricRenamedLabelPreservesItsOldRawID() throws {
    let entry = MappingEntry(commandID: 100)
    var json = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
    )
    json.removeValue(forKey: "commandID")
    json["commandName"] = "Loop Out"
    let decoded = try JSONDecoder().decode(
        MappingEntry.self,
        from: JSONSerialization.data(withJSONObject: json)
    )
    #expect(decoded.commandID == 201)
}

@Test func testUnknownNameOnlyJSONBecomesVisibleInvalidID() throws {
    let entry = MappingEntry(commandID: 100)
    var json = try #require(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any]
    )
    json.removeValue(forKey: "commandID")
    json["commandName"] = "Not a Traktor command"
    let decoded = try JSONDecoder().decode(
        MappingEntry.self,
        from: JSONSerialization.data(withJSONObject: json)
    )
    #expect(decoded.commandID == 0)
    #expect(decoded.commandName == "")
}
```

Run: `scripts/test-unit.sh -only-testing:XtremeMappingTests/MappingEntryTests`

Expected: FAIL because `commandID` does not exist.

- [ ] **Step 2: Add authoritative command storage and compatibility initialization**

Use this public shape:

```swift
var commandID: Int

var commandDescriptor: TraktorCommandDescriptor {
    TraktorCommands.descriptor(for: commandID)
}

var commandName: String {
    commandID == 0 ? "" : commandDescriptor.name
}
```

Change the initializer's command parameters to:

```swift
commandID: Int? = nil,
commandName: String = "",
```

Initialize with `commandID ?? TraktorCommands.id(forLegacyName: commandName)`. Explicit IDs therefore win. Keep the name parameter only as a source-compatibility migration seam; new code must pass IDs or descriptors.

Add `.commandID` to `CodingKeys`. Encode both `commandID` and derived `commandName`. Decode both with `decodeIfPresent`; explicit-ID JSON remains valid when the redundant name is absent. When ID is absent, run the existing Slot migration on the legacy name and assignment before calling `id(forLegacyName:)`.

Freeze aliases for every label changed by the Task 2 audit before replacing catalog names. Alias lookup intentionally runs before canonical-name lookup for name-only legacy JSON, so old app JSON preserves the raw ID it would previously have written (for example `"Loop Out" -> 201` and the old meter labels -> their old IDs). New code never creates mappings through this ambiguous string seam.

- [ ] **Step 3: Run model tests and compile-check all consumers**

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingEntryTests \
  -only-testing:XtremeMappingTests/TraktorCommandsTests
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add XtremeMapping/XtremeMapping/Models/MappingEntry.swift \
  XtremeMapping/XtremeMappingTests/MappingEntryTests.swift
git commit -m "feat: store authoritative Traktor command IDs"
```

---

### Task 4: Raw Command-ID TSI Import, Export, and Creation

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift`
- Modify: `XtremeMapping/XtremeMapping/XtremeMappingDocument.swift`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`
- Modify: `XtremeMapping/XtremeMapping/Services/VoiceMappingCoordinator.swift`
- Modify: `XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/VoiceMappingCoordinatorTests.swift`

**Interfaces:**
- Consumes: `MappingEntry.commandID`, verified command descriptors.
- Produces: lossless encodable positive unknown-ID round trips, throwing invalid-ID export, direction-filtered Add menus that pass descriptors, and Voice Learn rejection of unverified names.

- [ ] **Step 1: Write failing raw-ID round-trip tests**

First add these test-local helpers using the existing parser and `roundTripDevice(_:)` support:

```swift
private func interpretTSIData(_ data: Data) throws -> MappingFile {
    let parser = TSIParser()
    let base64 = try TSIParser.extractControllerData(from: data)
    let binary = try parser.decodeBase64(base64)
    return try TSIInterpreter.interpret(frames: parser.parseFrames(from: binary))
}

private func roundTripEntries(_ entries: [MappingEntry]) throws -> [MappingEntry] {
    try XCTUnwrap(roundTripDevice(Device(name: "Generic MIDI", mappings: entries))).mappings
}

private func scanCMAICommandTargets(in tsi: Data) throws -> [(commandID: UInt32, target: Int32)]
```

Implement the scanner by walking the decoded frame hierarchy, reading CMAI command ID at bytes `8...11`, then the bounded CMAD target field. It must fail on malformed frames rather than byte-searching for marker strings. Then add:

```swift
func testUnknownPositiveCommandIDRoundTripsWithComment() throws {
    let source = MappingEntry(
        commandID: 4242,
        ioType: .input,
        assignment: .deckC,
        interactionMode: .hold,
        midiChannel: 3,
        midiCC: 17,
        comment: "Keep this legacy macro"
    )
    let tsi = try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: [source])]))
    let result = try interpretTSIData(tsi)
    let decoded = try XCTUnwrap(result.devices.first?.mappings.first)

    XCTAssertEqual(decoded.commandID, 4242)
    XCTAssertEqual(decoded.comment, "Keep this legacy macro")
    XCTAssertEqual(decoded.assignment, .deckC)
    XCTAssertEqual(try scanCMAICommandTargets(in: tsi).map(\.commandID), [4242])
}

func testWriterUsesStoredIDNotDisplayNameReverseLookup() throws {
    let source = MappingEntry(commandID: 201, midiChannel: 1, midiCC: 12)
    let tsi = try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: [source])]))
    let decoded = try XCTUnwrap(try interpretTSIData(tsi).devices.first?.mappings.first)
    XCTAssertEqual(decoded.commandID, 201)
    XCTAssertEqual(decoded.commandName, "Reverse Playback On")
}

func testMeterIDAndDeckTargetRemainIndependent() throws {
    let decks: [TargetAssignment] = [.deckA, .deckB, .deckC, .deckD]
    let rows = decks.map {
        MappingEntry(commandID: 2688, ioType: .output, assignment: $0, midiChannel: 1, midiCC: 20)
    }
    let tsi = try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)]))
    let result = try roundTripEntries(rows)
    XCTAssertEqual(result.map(\.commandID), [2688, 2688, 2688, 2688])
    XCTAssertEqual(result.map(\.assignment), decks)
    let rawPairs = try scanCMAICommandTargets(in: tsi)
    XCTAssertEqual(rawPairs.map(\.commandID), [2688, 2688, 2688, 2688])
    XCTAssertEqual(rawPairs.map(\.target), [0, 1, 2, 3])
}

func testCommandIDOutsideTSIUInt32RangeThrows() {
    let row = MappingEntry(commandID: Int(UInt32.max) + 1, midiChannel: 1, midiCC: 1)
    XCTAssertThrowsError(try TSIWriter().write(MappingFile(devices: [Device(mappings: [row])]))) {
        XCTAssertEqual($0 as? TSIWriterError, .invalidCommandID(Int(UInt32.max) + 1))
    }
}
```

Run: `scripts/test-unit.sh -only-testing:XtremeMappingTests/TSIInterpreterTests`

Expected: FAIL because the writer still reverse-resolves `commandName` and filters unknown names.

- [ ] **Step 2: Use commandID at every binary boundary**

In `TSIInterpreter.parseCMAI`, pass the raw CMAI integer to `MappingEntry(commandID:)`. Remove the raw-TSI 2900–2923 rewrite: a positive imported TSI ID has provenance and must remain byte-stable. The name-only JSON Slot migration from Task 3 remains the only migration.

In `TSIWriter`, replace every `TraktorCommands.id(for: mapping.commandName)` call in writable filtering, CMAI construction, CMAD target handling, and CMAD profile selection with `mapping.commandID`. Continue omitting placeholder IDs `<= 0`. Introduce `TSIWriterError.invalidCommandID(Int)`, make `write(_:)` and its frame-builder chain throwing, and reject values above `UInt32.max` before conversion. Update `TraktorMappingDocument.fileWrapper` and every direct writer test call to use `try`.

- [ ] **Step 3: Make new mapping creation descriptor-based**

Change both Add menu component callbacks from `(String) -> Void` to `(TraktorCommandDescriptor) -> Void`. Feed Input from `verifiedCategories(for: .input)`, Output from `.output`, and In/Out from `.all`; create rows with `MappingEntry(commandID: command.id)`. Change every Voice Learn known-command guard, disambiguation filter, and insertion path to resolve through `verifiedDescriptor(named:supporting: .input)`; if absent, refuse insertion through the existing error path.

- [ ] **Step 4: Run focused tests**

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/TSIInterpreterTests \
  -only-testing:XtremeMappingTests/VoiceMappingCoordinatorTests \
  -only-testing:XtremeMappingTests/TraktorCommandsTests
```

Expected: PASS. Mutation check: changing the writer back to name lookup must fail the unknown-ID test.

- [ ] **Step 5: Commit**

```bash
git add XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift \
  XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift \
  XtremeMapping/XtremeMapping/XtremeMappingDocument.swift \
  XtremeMapping/XtremeMapping/ContentView.swift \
  XtremeMapping/XtremeMapping/Services/VoiceMappingCoordinator.swift \
  XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift \
  XtremeMapping/XtremeMappingTests/VoiceMappingCoordinatorTests.swift
git commit -m "fix: preserve raw command IDs through TSI"
```

---

### Task 5: Validated Exclusive MIDI Assignment

**Files:**
- Create: `XtremeMapping/XtremeMapping/Models/MIDIAssignment.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/MappingEntry.swift`
- Modify: `XtremeMapping/XtremeMapping/Utilities/MIDIUtilities.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift`
- Create: `XtremeMapping/XtremeMappingTests/MIDIAssignmentTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/MappingEntryTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift`

**Interfaces:**
- Consumes: `MIDIMessage`, DCBM generic names.
- Produces: `MIDIAssignment`, `MappingEntry.midiAssignment`, compatibility accessors, safe display and parser/writer validation.

- [ ] **Step 1: Write failing assignment-domain tests**

```swift
@Test func noteAssignmentClearsControlChange() throws {
    var entry = MappingEntry(midiChannel: 1, midiCC: 7)
    entry.midiNote = 60
    #expect(entry.midiAssignment == (try MIDIAssignment.note(channel: 1, number: 60)))
    #expect(entry.midiCC == nil)
}

@Test func controlChangeAssignmentClearsNote() throws {
    var entry = MappingEntry(midiChannel: 2, midiNote: 61)
    entry.midiCC = 8
    #expect(entry.midiAssignment == (try MIDIAssignment.controlChange(channel: 2, number: 8)))
    #expect(entry.midiNote == nil)
}

@Test func noteOffDoesNotProduceLearnAssignment() {
    let message = MIDIMessage(channel: 1, note: 60, cc: nil, value: 0)
    #expect(MIDIAssignment(learnMessage: message) == nil)
}

@Test func zeroValueControlChangeIsStillLearnable() throws {
    let message = MIDIMessage(channel: 1, note: nil, cc: 7, value: 0)
    #expect(MIDIAssignment(learnMessage: message) == (try MIDIAssignment.controlChange(channel: 1, number: 7)))
}

@Test func validationAcceptsBoundariesAndRejectsOutsideThem() throws {
    let lowestNote = try MIDIAssignment.note(channel: 1, number: 0)
    let highestCC = try MIDIAssignment.controlChange(channel: 16, number: 127)
    #expect(try MIDIAssignment(validatingChannel: 1, note: 0, cc: nil) == lowestNote)
    #expect(try MIDIAssignment(validatingChannel: 16, note: nil, cc: 127) == highestCC)
    #expect(throws: MIDIAssignment.ValidationError.self) {
        try MIDIAssignment(validatingChannel: 0, note: nil, cc: 1)
    }
    #expect(throws: MIDIAssignment.ValidationError.self) {
        try MIDIAssignment(validatingChannel: 1, note: 128, cc: nil)
    }
    #expect(throws: MIDIAssignment.ValidationError.self) {
        try MIDIAssignment(validatingChannel: 1, note: 60, cc: 1)
    }
}
```

Add parser tests through the real `TSIInterpreter`, using the existing `rawFrame`, `tsiString`, `interpretDEVI`, and `interpretBinary` fixture builders rather than the duplicate parser helper at the bottom of `TSIInterpreterTests`. DCBM names `Ch00.CC.001`, `Ch17.CC.001`, `Ch01.CC.128`, and `Ch01.Note.C10` must each throw `TSIInterpreterError.unrecognizedMidiControl(name:)` with the exact offending string. Add one table-driven real-interpreter boundary test for `Ch01.Note.C-1`, `Ch16.Note.G9`, `Ch01.CC.000`, and `Ch16.CC.127`.

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MIDIAssignmentTests \
  -only-testing:XtremeMappingTests/MappingEntryTests \
  -only-testing:XtremeMappingTests/TSIInterpreterTests
```

Expected: FAIL because the type and validation do not exist.

- [ ] **Step 2: Implement the assignment value**

Implement this exact state surface. Private stored validation prevents public enum-case construction from bypassing the initializer:

```swift
struct MIDIAssignment: Hashable, Codable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case unassigned
        case note
        case controlChange
    }

    enum ValidationError: Error, Equatable {
        case channelOutOfRange(Int)
        case controlOutOfRange(Int)
        case ambiguousNoteAndCC
    }

    private(set) var kind: Kind
    private(set) var channel: Int
    private(set) var number: Int?

    init(validatingChannel channel: Int, note: Int?, cc: Int?) throws
    init?(learnMessage: MIDIMessage)
    static func unassigned(channel: Int) throws -> Self
    static func note(channel: Int, number: Int) throws -> Self
    static func controlChange(channel: Int, number: Int) throws -> Self
    func replacingChannel(with channel: Int) throws -> Self
    var note: Int? { get }
    var cc: Int? { get }
    var displayName: String { get }
}
```

Store `midiAssignment` in `MappingEntry`. Make the primary initializer accept a valid `MIDIAssignment`, while keeping the legacy channel/note/CC arguments as a source-compatibility seam during this branch. That nonthrowing seam and the compatibility computed-property setters use a programmer-error precondition for invalid direct values; UI inputs are range-constrained and external inputs never use the seam. Setting a Note clears CC and setting CC clears Note. Setting a nil Note clears only a current Note; setting a nil CC clears only a current CC. Channel replacement preserves assignment kind/number. Add tests for those setter semantics. The JSON encoder continues writing the legacy three keys. The decoder validates them and throws `DecodingError.dataCorrupted` for invalid data.

- [ ] **Step 3: Validate parser and writer boundaries**

Have `TSIInterpreter.parseMidiControlName` return `MIDIAssignment` and map every syntax/range failure to `.unrecognizedMidiControl(name:)`. Fix octave parsing as a normal signed decimal suffix—`C10` must not be reversed to `C1`—then apply the final MIDI `0...127` range check. Have `TSIWriter.midiControlName(for:)` switch only on the validated assignment. `midiNoteToName` may precondition its now-domain-valid input; external and diagnostic paths validate before calling it rather than masking invariant breaches with a fallback.

- [ ] **Step 4: Run MIDI tests**

Run the command from Step 1.

Expected: PASS. Mutation check: preferring Note in display but CC in serialization, or accepting channel 17, must fail.

- [ ] **Step 5: Commit**

```bash
git add XtremeMapping/XtremeMapping/Models/MIDIAssignment.swift \
  XtremeMapping/XtremeMapping/Models/MappingEntry.swift \
  XtremeMapping/XtremeMapping/Utilities/MIDIUtilities.swift \
  XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift \
  XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift \
  XtremeMapping/XtremeMappingTests/MIDIAssignmentTests.swift \
  XtremeMapping/XtremeMappingTests/MappingEntryTests.swift \
  XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift
git commit -m "fix: enforce valid exclusive MIDI assignments"
```

---

### Task 6: Direction-Specific DCDT Encoder Definitions

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/Enums/EncoderMode.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/MappingEntry.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift`
- Modify: `XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift`

**Interfaces:**
- Consumes: validated MIDI assignment and I/O direction.
- Produces: `EncoderMode.tsiDCDTValue`, `init?(tsiDCDTValue:)`, bounded DDCI/DDCO parsing with explicit corruption errors, throwing TSI export conflicts, and opaque raw-mode pass-through.

- [ ] **Step 1: Write failing encoder-definition tests**

```swift
func testEncoderModeUsesTraktorRawValues() {
    XCTAssertEqual(EncoderMode.mode3Fh41h.tsiDCDTValue, 0)
    XCTAssertEqual(EncoderMode.mode7Fh01h.tsiDCDTValue, 1)
    XCTAssertEqual(EncoderMode(tsiDCDTValue: 0), .mode3Fh41h)
    XCTAssertEqual(EncoderMode(tsiDCDTValue: 1), .mode7Fh01h)
    XCTAssertNil(EncoderMode(tsiDCDTValue: 3))
}

func testInputAndOutputDefinitionsUseSeparateContainers() throws {
    let rows = [
        MappingEntry(commandID: 100, ioType: .input, midiChannel: 1, midiCC: 20),
        MappingEntry(commandID: 2591, ioType: .output, midiChannel: 1, midiCC: 20, controllerType: .led),
    ]
    let tsi = try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)]))
    let definitions = try scanDCDTEntries(inTSI: tsi)
    XCTAssertEqual(definitions.filter { $0.container == "DDCI" }.map(\.controlType), [7])
    XCTAssertEqual(definitions.filter { $0.container == "DDCO" }.map(\.controlType), [8])
}

func testBothGenericEncoderModesRoundTrip() throws {
    for mode in EncoderMode.allCases {
        let source = MappingEntry(
            commandID: 123,
            interactionMode: .relative,
            midiChannel: 4,
            midiCC: 22,
            controllerType: .encoder,
            encoderMode: mode
        )
        let decoded = try XCTUnwrap(try roundTripEntries([source]).first)
        XCTAssertEqual(decoded.encoderMode, mode)
    }
}

func testConflictingModesForSameControlAndDirectionThrow() {
    let rows = EncoderMode.allCases.map {
        MappingEntry(commandID: 123, midiChannel: 1, midiCC: 10, controllerType: .encoder, encoderMode: $0)
    }
    XCTAssertThrowsError(try TSIWriter().write(MappingFile(devices: [Device(name: "Generic MIDI", mappings: rows)])))
}
```

Add exact reference payloads, extracted read-only from Traktor 4.4.1 mappings, to a test helper:

```swift
let traktor44Mode0DCDTPayloadHex = "0000000b0043006800300031002e00430043002e003000320032000000070000000042fe000000000000ffffffff"
let traktor44Mode1DCDTPayloadHex = "0000000b0043006800300031002e00430043002e003000300030000000070000000042fe000000000001ffffffff"
```

Assert their parsed names, types, and encoder values are respectively `Ch01.CC.022 / 7 / 0` and `Ch01.CC.000 / 7 / 1`.

Before the tests, replace the old marker-search helper with bounded test support:

```swift
private struct ScannedDCDT: Equatable {
    let container: String
    let name: String
    let controlType: UInt32
    let min: Float32
    let max: Float32
    let encoderMode: UInt32
    let controlID: UInt32
}

private func scanDCDTEntries(inTSI data: Data) throws -> [ScannedDCDT]
```

The helper must decode XML/Base64 and walk DDDC → DDCI/DDCO → bounded DCDT frames and counts; it must not scan arbitrary bytes for `DCDT`. Add `roundTripEntries(_:)` as specified in Task 4. Wrap each literal payload in a valid DCDT/container/device fixture with matching DCBM and CMAI before asserting interpreter integration.

Add failing tests for all parser contracts before implementation:

- DDCI and DDCO shorter than the count prefix;
- declared-count mismatch, trailing bytes, truncated DCDT string, and truncated fixed scalar block;
- duplicate container for one direction and duplicate `(controlName, direction)` definitions;
- DDCI carrying type 8 or DDCO carrying type 7;
- a missing matching definition retaining the existing generic default;
- raw mode `3` surviving import and export unchanged;
- the same CC used for one input and one output receiving metadata from its own direction.

Run: `scripts/test-unit.sh -only-testing:XtremeMappingTests/TSIInterpreterTests`

Expected: FAIL because mode is hard-coded, DDCO is absent, and the interpreter skips definitions.

- [ ] **Step 2: Add explicit Traktor conversion without changing Codable raw values**

```swift
var tsiDCDTValue: UInt32 {
    switch self {
    case .mode3Fh41h: return 0
    case .mode7Fh01h: return 1
    }
}

init?(tsiDCDTValue: UInt32) {
    switch tsiDCDTValue {
    case 0: self = .mode3Fh41h
    case 1: self = .mode7Fh01h
    default: return nil
    }
}
```

Add `rawDCDTEncoderMode: UInt32?` to `MappingEntry` Codable with a nil legacy default. It is non-nil only for an unrecognized imported raw value. Define `effectiveDCDTEncoderMode` as `rawDCDTEncoderMode ?? encoderMode.tsiDCDTValue`. Add `setEncoderMode(_:)` to update the UI mode and clear the raw override; route every UI/menu encoder edit through it. The effective raw value participates in same-control conflict detection.

- [ ] **Step 3: Parse DDCI and DDCO structurally**

Add optional `inputDefinitions` and `outputDefinitions` payloads to `DeviceFrames`. A second DDCI or DDCO for the same device throws instead of silently winning. Parse each declared count, bounded DCDT frame, UTF-16BE control name, control type, min/max, encoder mode, and control ID. Derive direction from the container and require DDCI/type 7 and DDCO/type 8. Add these exact interpreter errors:

```swift
case malformedMidiDefinitions(container: String)
case midiDefinitionCountMismatch(container: String, declared: Int, parsed: Int)
case malformedMidiDefinition(container: String)
case duplicateMidiDefinitionsContainer(direction: IODirection)
case duplicateMidiDefinition(name: String, direction: IODirection)
case midiDefinitionDirectionMismatch(container: String, controlType: Int)
```

Index valid definitions by:

```swift
struct MIDIControlDefinitionKey: Hashable {
    let controlName: String
    let direction: IODirection
}
```

DCBM remains the sole mapping-binding-ID authority. Match DCDT metadata with `(resolved DCBM control name, CMAI mapping direction)`. When a matching generic definition has raw mode 0 or 1, set `encoderMode`; for other values, retain `rawDCDTEncoderMode`. Missing containers or definitions keep the existing default.

- [ ] **Step 4: Emit DDCI and DDCO and make conflicts explicit**

Add:

```swift
// Extend the error introduced in Task 4.
enum TSIWriterError: Error, Equatable {
    case invalidCommandID(Int)
    case conflictingEncoderModes(controlName: String, direction: IODirection)
}
```

`write(_:)` is already throwing from Task 4. Emit input definitions under DDCI and output/LED definitions under DDCO as sibling frames inside DDDC. Deduplicate on `(controlName, direction)` and throw if effective raw encoder values disagree.

Before editing, enumerate direct writer calls with `rg -n 'TSIWriter\(\)\.write|writer\.write' XtremeMapping --glob '*.swift'`; Task 4 must already have converted each one to `try`.

- [ ] **Step 5: Run encoder and full parser tests**

Run:

```bash
scripts/test-unit.sh -only-testing:XtremeMappingTests/TSIInterpreterTests
```

Expected: PASS, including the two literal real-frame fixtures.

- [ ] **Step 6: Commit**

```bash
git add XtremeMapping/XtremeMapping/Models/Enums/EncoderMode.swift \
  XtremeMapping/XtremeMapping/Models/MappingEntry.swift \
  XtremeMapping/XtremeMapping/Models/TSI/TSIWriter.swift \
  XtremeMapping/XtremeMapping/Models/TSI/TSIInterpreter.swift \
  XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift
git commit -m "fix: round-trip Traktor MIDI encoder definitions"
```

---

### Task 7: Lossless Group Clipboard and Transfer Service

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/MappingEntry.swift`
- Modify: `XtremeMapping/XtremeMapping/Services/ClipboardManager.swift`
- Create: `XtremeMapping/XtremeMapping/Services/MappingTransferService.swift`
- Modify: `XtremeMapping/XtremeMappingTests/MappingEntryTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/ClipboardManagerTests.swift`
- Create: `XtremeMapping/XtremeMappingTests/TestFixtures.swift`
- Create: `XtremeMapping/XtremeMappingTests/MappingTransferServiceTests.swift`

**Interfaces:**
- Consumes: complete `MappingEntry`, validated MIDI assignment.
- Produces: `copyWithNewID()`, shared mapping clipboard, ordered paste service returning inserted IDs.

- [ ] **Step 1: Write failing clone and clipboard tests**

Create this shared test-target fixture first so the red failure is about the missing clone API rather than an undefined helper:

```swift
extension MappingEntry {
    static var fullFieldSentinel: MappingEntry {
        MappingEntry(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            commandID: 4242,
            ioType: .output,
            assignment: .remixDeckDSlot4,
            interactionMode: .decrement,
            midiChannel: 16,
            midiNote: 127,
            modifier1Condition: ModifierCondition(modifier: 1, value: 7),
            modifier2Condition: ModifierCondition(modifier: 8, value: 3),
            comment: "Macro 🧪\nsecond line",
            controllerType: .encoder,
            invert: true,
            softTakeover: true,
            setToValue: 0.75,
            rotarySensitivity: 2.5,
            rotaryAcceleration: 0.8,
            encoderMode: .mode3Fh41h,
            rawDCDTEncoderMode: 3,
            autoRepeat: true,
            ledMinRangeType: 2,
            ledMinRangeData: -3,
            ledMaxRangeType: 4,
            ledMaxRangeData: 9,
            ledMinMidi: 5,
            ledMaxMidi: 120,
            ledInvert: true,
            ledBlend: true,
            resolution: 2
        )
    }
}
```

Then assert:

```swift
@Test func copyWithNewIDChangesOnlyIdentity() {
    let source = MappingEntry.fullFieldSentinel
    let copy = source.copyWithNewID()
    #expect(copy.id != source.id)
    #expect(copy.commandID == source.commandID)
    #expect(copy.ioType == source.ioType)
    #expect(copy.assignment == source.assignment)
    #expect(copy.midiAssignment == source.midiAssignment)
    #expect(copy.modifier1Condition == source.modifier1Condition)
    #expect(copy.modifier2Condition == source.modifier2Condition)
    #expect(copy.comment == source.comment)
    #expect(copy.controllerType == source.controllerType)
    #expect(copy.invert == source.invert)
    #expect(copy.softTakeover == source.softTakeover)
    #expect(copy.setToValue == source.setToValue)
    #expect(copy.rotarySensitivity == source.rotarySensitivity)
    #expect(copy.rotaryAcceleration == source.rotaryAcceleration)
    #expect(copy.encoderMode == source.encoderMode)
    #expect(copy.rawDCDTEncoderMode == source.rawDCDTEncoderMode)
    #expect(copy.autoRepeat == source.autoRepeat)
    #expect(copy.ledMinRangeType == source.ledMinRangeType)
    #expect(copy.ledMinRangeData == source.ledMinRangeData)
    #expect(copy.ledMaxRangeType == source.ledMaxRangeType)
    #expect(copy.ledMaxRangeData == source.ledMaxRangeData)
    #expect(copy.ledMinMidi == source.ledMinMidi)
    #expect(copy.ledMaxMidi == source.ledMaxMidi)
    #expect(copy.ledInvert == source.ledInvert)
    #expect(copy.ledBlend == source.ledBlend)
    #expect(copy.resolution == source.resolution)
}
```

Add clipboard tests proving a second copy replaces the prior group, every paste generates fresh IDs, order is stable, and the specialized mapped-to/modifier clipboards are unchanged.

Add service tests:

```swift
func testPasteIntoEmptyFileCreatesGenericDeviceAndReturnsIDs() {
    var file = MappingFile()
    let source = [MappingEntry(commandID: 100), MappingEntry(commandID: 201)]
    let inserted = MappingTransferService.insertCopies(source, into: &file)
    XCTAssertEqual(file.devices.map(\.name), ["Generic MIDI"])
    XCTAssertEqual(file.devices[0].mappings.map(\.commandID), [100, 201])
    XCTAssertEqual(inserted, Set(file.devices[0].mappings.map(\.id)))
}
```

Add service tests for a stale `targetDeviceID` falling back to the first device without changing its name/comment/ports/version metadata, and a valid target appending only to that device.

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingEntryTests \
  -only-testing:XtremeMappingTests/ClipboardManagerTests \
  -only-testing:XtremeMappingTests/MappingTransferServiceTests
```

Expected: FAIL because the clone and group APIs do not exist.

- [ ] **Step 2: Implement the single clone path**

Add `func copyWithNewID() -> MappingEntry` and explicitly pass every stored field to the initializer. Do not use JSON as a clone mechanism.

- [ ] **Step 3: Add the app-wide group clipboard**

Add:

```swift
@Published private(set) var mappingsClipboard: [MappingEntry] = []

func copyMappings(_ mappings: [MappingEntry]) {
    mappingsClipboard = mappings
}

var hasMappingsData: Bool { !mappingsClipboard.isEmpty }
```

`copyMappings([])` is the supported reset used by singleton tests. Clipboard storage never changes IDs; `MappingTransferService.insertCopies` below is the single owner of fresh-ID generation. Change `MappedToData` to carry `MIDIAssignment`, so its paste path is also exclusive.

- [ ] **Step 4: Implement ordered insertion**

```swift
enum MappingTransferService {
    @discardableResult
    static func insertCopies(
        _ source: [MappingEntry],
        into mappingFile: inout MappingFile,
        targetDeviceID: Device.ID? = nil
    ) -> Set<MappingEntry.ID>
}
```

Choose the requested device when present, otherwise the first device, otherwise create `Generic MIDI`. Append in source order and return exactly the new IDs.

- [ ] **Step 5: Run transfer tests**

Run the command from Step 1.

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add XtremeMapping/XtremeMapping/Models/MappingEntry.swift \
  XtremeMapping/XtremeMapping/Services/ClipboardManager.swift \
  XtremeMapping/XtremeMapping/Services/MappingTransferService.swift \
  XtremeMapping/XtremeMappingTests/MappingEntryTests.swift \
  XtremeMapping/XtremeMappingTests/ClipboardManagerTests.swift \
  XtremeMapping/XtremeMappingTests/TestFixtures.swift \
  XtremeMapping/XtremeMappingTests/MappingTransferServiceTests.swift
git commit -m "feat: add lossless shared mapping clipboard"
```

---

### Task 8: Real Undo and Cross-Window Copy/Paste Wiring

**Files:**
- Modify: `XtremeMapping/XtremeMapping/XtremeMappingDocument.swift`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`
- Modify: `XtremeMapping/XtremeMapping/Commands/EditCommands.swift`
- Modify: `XtremeMapping/XtremeMapping/Views/MappingsTableView.swift`
- Modify: `XtremeMapping/XtremeMapping/Utilities/MappingTransferable.swift`
- Modify: `XtremeMapping/XtremeMappingTests/DocumentTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/MappingTransferServiceTests.swift`
- Create: `XtremeMapping/XtremeMappingTests/MappingTransferCodecTests.swift`

**Interfaces:**
- Consumes: shared clipboard and transfer service.
- Produces: result-returning `performUndoableMutation`, one-step paste/duplicate, a Codable system-pasteboard batch, standard table-focused Copy/Paste, and destination selection.

- [ ] **Step 1: Write failing undo transaction tests**

```swift
@MainActor
func testUndoableMutationRestoresWholeMappingFileAndRedo() throws {
    let original = MappingFile(devices: [Device(name: "Generic MIDI")])
    let document = TraktorMappingDocument(mappingFile: original)
    let undoManager = UndoManager()

    document.performUndoableMutation(actionName: "Paste Mappings", undoManager: undoManager) { file in
        _ = MappingTransferService.insertCopies([MappingEntry(commandID: 100)], into: &file)
    }
    XCTAssertEqual(document.mappingFile.allMappings.map(\.commandID), [100])

    undoManager.undo()
    XCTAssertEqual(document.mappingFile, original)

    undoManager.redo()
    XCTAssertEqual(document.mappingFile.allMappings.map(\.commandID), [100])
}
```

Add `testBatchPasteRegistersOneUndoAction` and `testNoOpMutationRegistersNoUndo`.

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/DocumentTests \
  -only-testing:XtremeMappingTests/MappingTransferServiceTests \
  -only-testing:XtremeMappingTests/MappingTransferCodecTests
```

Expected: FAIL because the transaction helper does not exist.

- [ ] **Step 2: Implement snapshot-based undo/redo**

Add this interface on the main actor:

```swift
@MainActor
func performUndoableMutation<Result>(
    actionName: String,
    undoManager: UndoManager?,
    _ mutation: (inout MappingFile) -> Result
) -> Result?
```

Capture `before`, mutate a local `after`, return `nil` without dirtying when equal, assign `after`, call `noteChange()`, register a private inverse snapshot operation that also registers redo, and return the mutation result. Set the action name on the manager. Add a test proving a no-op returns nil and no caller selection should change.

- [ ] **Step 3: Replace every lossy UI duplicate/paste path**

In `ContentView`:

- remove `@State private var clipboard`;
- copy selected rows in current document order to `ClipboardManager.shared`;
- paste through `MappingTransferService` inside one undoable mutation;
- replace `selectedMappings` with returned IDs;
- duplicate by walking each source device and appending `copyWithNewID()` rows to that same device in document order; add a two-device regression so duplication cannot move rows into device 0;
- drop through the transfer service into the destination selected row's owning device when exactly one owner is implied;
- keep lock guards before mutation.

In `EditCommands`, add `@Environment(\.undoManager)`, use the focused document, focused selection binding, shared clipboard, transfer service, and the same transaction helper. Remove the manual partial `MappingEntry` constructor.

- [ ] **Step 4: Wire native table Copy/Paste behavior**

Add `UTType.mappingBatch` and a `MappingBatchCodec` in `MappingTransferable.swift`:

```swift
enum MappingBatchCodec {
    static func encode(_ mappings: [MappingEntry]) throws -> Data
    static func decode(_ data: Data) throws -> [MappingEntry]
    static func itemProvider(for mappings: [MappingEntry]) -> NSItemProvider
    static func load(from providers: [NSItemProvider]) async throws -> [MappingEntry]
}
```

Encode one ordered `[MappingEntry]` payload. Add codec tests using `MappingEntry.fullFieldSentinel`. On `MappingsTableView`, wire concrete `.onCopyCommand` and `.onPasteCommand(of: [.mappingBatch])` callbacks: Copy orders selected rows by current document order, updates `ClipboardManager.shared`, and returns one provider; Paste decodes the provider then calls the same undoable transfer path on the main actor. Because the handlers are attached to the table, a focused `TextEditor` keeps native text Command-C/Command-V.

Restructure the context menu: Paste is outside the nonempty-selection guard and is enabled whenever the document is unlocked and the app-wide mapping clipboard is nonempty; Copy/Duplicate/Delete and mapping-property menus remain individually gated on selection.

- [ ] **Step 5: Run undo and clipboard suites**

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/DocumentTests \
  -only-testing:XtremeMappingTests/ClipboardManagerTests \
  -only-testing:XtremeMappingTests/MappingTransferServiceTests \
  -only-testing:XtremeMappingTests/MappingTransferCodecTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add XtremeMapping/XtremeMapping/XtremeMappingDocument.swift \
  XtremeMapping/XtremeMapping/ContentView.swift \
  XtremeMapping/XtremeMapping/Commands/EditCommands.swift \
  XtremeMapping/XtremeMapping/Views/MappingsTableView.swift \
  XtremeMapping/XtremeMapping/Utilities/MappingTransferable.swift \
  XtremeMapping/XtremeMappingTests/DocumentTests.swift \
  XtremeMapping/XtremeMappingTests/MappingTransferServiceTests.swift \
  XtremeMapping/XtremeMappingTests/MappingTransferCodecTests.swift
git commit -m "feat: wire undoable cross-document mapping paste"
```

---

### Task 9: Shared Manual MIDI Assignment and One-Shot Learn

**Files:**
- Create: `XtremeMapping/XtremeMapping/Services/MappingBatchEditor.swift`
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift`
- Modify: `XtremeMapping/XtremeMapping/Commands/EditCommands.swift`
- Create: `XtremeMapping/XtremeMappingTests/MappingBatchEditorTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/ClipboardManagerTests.swift`

**Interfaces:**
- Consumes: selected IDs, `MIDIAssignment`, document transaction helper, MIDI messages.
- Produces: pure batch assignment/comment operations and multi-selection Learn/manual UI.

- [ ] **Step 1: Write failing batch-operation tests**

```swift
func testSharedMIDIAssignmentChangesOnlySelectedRows() {
    let first = MappingEntry(commandID: 100, controllerType: .button, comment: "a")
    let second = MappingEntry(commandID: 201, controllerType: .encoder, comment: "b")
    let untouched = MappingEntry(commandID: 202, controllerType: .faderOrKnob, comment: "c")
    var file = MappingFile(devices: [Device(name: "Generic MIDI", mappings: [first, second, untouched])])

    MappingBatchEditor.apply(
        try! MIDIAssignment.controlChange(channel: 9, number: 22),
        to: Set([first.id, second.id]),
        in: &file
    )

    XCTAssertEqual(file.devices[0].mappings[0].midiAssignment, try! .controlChange(channel: 9, number: 22))
    XCTAssertEqual(file.devices[0].mappings[1].midiAssignment, try! .controlChange(channel: 9, number: 22))
    XCTAssertEqual(file.devices[0].mappings[2].midiAssignment, untouched.midiAssignment)
    XCTAssertEqual(file.devices[0].mappings.map(\.controllerType), [.button, .encoder, .faderOrKnob])
    XCTAssertEqual(file.devices[0].mappings.map(\.comment), ["a", "b", "c"])
}

func testBatchLearnIgnoresNoteOffAndAcceptsFirstNoteOn() throws {
    XCTAssertNil(MIDIAssignment(learnMessage: MIDIMessage(channel: 2, note: 64, cc: nil, value: 0)))
    XCTAssertEqual(
        MIDIAssignment(learnMessage: MIDIMessage(channel: 2, note: 64, cc: nil, value: 100)),
        try MIDIAssignment.note(channel: 2, number: 64)
    )
}

func testChannelOnlyEditPreservesEachRowsAssignmentKindAndNumber() throws {
    let note = MappingEntry(commandID: 100, midiAssignment: try .note(channel: 1, number: 64))
    let cc = MappingEntry(commandID: 201, midiAssignment: try .controlChange(channel: 2, number: 22))
    let none = MappingEntry(commandID: 202, midiAssignment: try .unassigned(channel: 3))
    var file = MappingFile(devices: [Device(mappings: [note, cc, none])])

    try MappingBatchEditor.applyChannel(12, to: Set([note.id, cc.id, none.id]), in: &file)

    XCTAssertEqual(file.devices[0].mappings[0].midiAssignment, try .note(channel: 12, number: 64))
    XCTAssertEqual(file.devices[0].mappings[1].midiAssignment, try .controlChange(channel: 12, number: 22))
    XCTAssertEqual(file.devices[0].mappings[2].midiAssignment, try .unassigned(channel: 12))
}
```

Run: `scripts/test-unit.sh -only-testing:XtremeMappingTests/MappingBatchEditorTests`

Expected: FAIL because the batch editor does not exist.

- [ ] **Step 2: Implement the pure batch editor**

```swift
enum MappingBatchEditor {
    static func apply(
        _ assignment: MIDIAssignment,
        to selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    )

    static func applyComment(
        _ comment: String,
        to selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    )

    static func applyChannel(
        _ channel: Int,
        to selectedIDs: Set<MappingEntry.ID>,
        in mappingFile: inout MappingFile
    ) throws
}
```

`applyChannel` calls `MIDIAssignment.replacingChannel(with:)` for each selected row. Learn uses `MIDIAssignment(learnMessage:)` directly so Note-Off and range rules have one implementation.

- [ ] **Step 3: Add compact multi-selection controls**

In `SettingsPanelV2.multipleSelectionView`, add one `MIDI ASSIGNMENT` section using existing V2 form controls:

- Note / CC / Unassigned selector;
- channel stepper `1...16`;
- number stepper `0...127` when Note or CC;
- `APPLY TO N` button;
- one-shot `LEARN` button with active state and accessible label.

Add dedicated multi-row draft state—`batchAssignmentKind`, `batchChannel`, `batchNumber`—and reset it to Unassigned/channel 1/number 0 whenever the selected ID set changes. Do not reuse the single-row `midiChannel` state, because `selectedEntry` is nil for multiple selection.

Manual Apply validates the draft and runs `MappingBatchEditor.apply` inside one `performUndoableMutation` call. A valid learned message does the same, then immediately clears the callback and stops MIDI listening. Note Off leaves Learn active. Multi-row Learn must not change controller type or interaction mode. Single-row Learn may retain its current inference behavior but must ignore Note Off.

`MIDIInputManager.shared` currently has one callback. Disable Learn while the manager is already listening for another screen, acquire it only when idle, and add `.onDisappear { stopLearning() }` so Settings never steals or strands the Wizard/Voice listener. The Wizard and Voice surfaces are already exclusive overlays; their close paths must continue stopping their own listener.

- [ ] **Step 4: Route mapped-to paste and menu channel edits through MIDIAssignment**

Use `applyChannel` for the Edit menu and store one `MIDIAssignment` in `ClipboardManager.MappedToData`, so every bulk MIDI path has identical exclusivity and validation.

- [ ] **Step 5: Run batch tests**

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingBatchEditorTests \
  -only-testing:XtremeMappingTests/ClipboardManagerTests \
  -only-testing:XtremeMappingTests/MIDIAssignmentTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add XtremeMapping/XtremeMapping/Services/MappingBatchEditor.swift \
  XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift \
  XtremeMapping/XtremeMapping/Commands/EditCommands.swift \
  XtremeMapping/XtremeMappingTests/MappingBatchEditorTests.swift \
  XtremeMapping/XtremeMappingTests/ClipboardManagerTests.swift
git commit -m "feat: assign one learned MIDI control to mapping groups"
```

---

### Task 10: Searchable Mapping and Device Comments

**Files:**
- Create: `XtremeMapping/XtremeMapping/Utilities/MappingSearch.swift`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`
- Modify: `XtremeMapping/XtremeMapping/Views/MappingsTableView.swift`
- Modify: `XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift`
- Create: `XtremeMapping/XtremeMappingTests/MappingSearchTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/MappingBatchEditorTests.swift`
- Modify: `XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift`

**Interfaces:**
- Consumes: mapping comments, owning device metadata, batch editor, undo helper.
- Produces: owner-aware search, Comment table column, explicit single/bulk comment saves, inline device-comment editor.

- [ ] **Step 1: Write failing search and persistence tests**

```swift
func testMappingCommentMatchesOnlyItsRow() {
    let target = MappingEntry(commandID: 100, comment: "shift layer macro")
    let other = MappingEntry(commandID: 201, comment: "transport")
    let device = Device(name: "X1", comment: "club setup", mappings: [target, other])
    XCTAssertTrue(MappingSearch.matches(target, in: device, query: "layer"))
    XCTAssertFalse(MappingSearch.matches(other, in: device, query: "layer"))
}

func testDeviceCommentMatchesEveryOwnedRow() {
    let rows = [MappingEntry(commandID: 100), MappingEntry(commandID: 201)]
    let device = Device(name: "X1 MK3", comment: "Noah macros", mappings: rows)
    XCTAssertTrue(rows.allSatisfy { MappingSearch.matches($0, in: device, query: "noah") })
}

func testSearchIsCaseAndDiacriticInsensitive() {
    let row = MappingEntry(commandID: 100, comment: "Écho Macro")
    let device = Device(name: "Generic MIDI", mappings: [row])
    XCTAssertTrue(MappingSearch.matches(row, in: device, query: "echo"))
}
```

Add a TSI round-trip test that explicitly constructs both strings:

```swift
let mappingComment = "Macro layer 🧪\n𐐷 second line"
let deviceComment = "X1 port notes 🎛\n𐐷 device line"
let row = MappingEntry(commandID: 100, midiChannel: 1, midiCC: 7, comment: mappingComment)
let device = Device(name: "Generic MIDI", comment: deviceComment, mappings: [row])
let decoded = try XCTUnwrap(try roundTripDevice(device))
XCTAssertEqual(decoded.comment, deviceComment)
XCTAssertEqual(decoded.mappings.first?.comment, mappingComment)
```

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingSearchTests \
  -only-testing:XtremeMappingTests/TSIInterpreterTests/testRoundTripPreservesNonBMPCommentAndDeviceName
```

Expected: FAIL because owner-aware search does not exist. Replace the old device-name expectation—which conflicts with the writer's intentional `Generic MIDI` normalization—with the explicit DDIC device-comment assertion above.

- [ ] **Step 2: Implement owner-aware matching**

```swift
enum MappingSearch {
    static func matches(_ mapping: MappingEntry, in device: Device, query: String) -> Bool
}
```

Trim whitespace/newlines; an empty query matches. Compare command name, mapping comment, device name, and device comment with `range(of:options: [.caseInsensitive, .diacriticInsensitive])`.

Change `ContentView.filteredMappings` to iterate devices so each row is tested with its owner, then apply the existing category and I/O filters.

- [ ] **Step 3: Add the Comment table column and status cue**

Add a resizable Comment column after Command, minimum 120 and ideal 220 points, with one-line truncation and a help tooltip containing the full comment. In the Command cell, show a small restrained `LEGACY` or `UNKNOWN` micro-label only when the descriptor is not verified; do not color verified rows.

- [ ] **Step 4: Add deliberate comment editors**

- Single selection: replace the one-line live-binding field with a styled `TextEditor` backed by local draft state and an explicit Save action. Give it a 72-point minimum and 140-point maximum height, AppThemeV2 stone background/border, and normal text focus behavior.
- Multiple selection: add a multiline field plus `APPLY TO N` button that calls `MappingBatchEditor.applyComment` in one undo transaction.
- Add `MappingBatchEditor.applyDeviceComment(_:to:in:)` for one selected `Device.ID`, with unit tests proving no mapping comment or other device metadata changes.
- Device comment: add a compact disclosed section in Settings with `selectedDeviceID` and `deviceCommentDraft` state, a device picker, the same styled multiline editor, and Save through the undo helper. On picker change, load that device's exact comment. Display duplicate names with a stable ordinal suffix. With no devices, show a compact empty state and disable editing. Do not use device name as the comment and do not open a modal by default.
- Disable every editor while the document is locked. Add accessibility labels that include the selected row/device count.

- [ ] **Step 5: Run comment/search tests**

Run:

```bash
scripts/test-unit.sh \
  -only-testing:XtremeMappingTests/MappingSearchTests \
  -only-testing:XtremeMappingTests/MappingBatchEditorTests \
  -only-testing:XtremeMappingTests/TSIInterpreterTests
```

Expected: PASS, including exact Unicode comments.

- [ ] **Step 6: Commit**

```bash
git add XtremeMapping/XtremeMapping/Utilities/MappingSearch.swift \
  XtremeMapping/XtremeMapping/ContentView.swift \
  XtremeMapping/XtremeMapping/Views/MappingsTableView.swift \
  XtremeMapping/XtremeMapping/Views/V2Components/SettingsPanelV2.swift \
  XtremeMapping/XtremeMappingTests/MappingSearchTests.swift \
  XtremeMapping/XtremeMappingTests/MappingBatchEditorTests.swift \
  XtremeMapping/XtremeMappingTests/TSIInterpreterTests.swift
git commit -m "feat: surface and search TSI comments"
```

---

### Task 11: Wizard/Voice Propagation and Full Verification

**Files:**
- Modify: `XtremeMapping/XtremeMapping/Models/Wizard/WizardFunction.swift`
- Modify: `XtremeMapping/XtremeMapping/Models/Wizard/WizardTab.swift`
- Modify: `XtremeMapping/XtremeMapping/Services/WizardCoordinator.swift`
- Modify: `XtremeMapping/XtremeMapping/Resources/Templates/ControllerTemplate.swift`
- Modify: `XtremeMapping/XtremeMapping/ContentView.swift`
- Modify: `XtremeMapping/XtremeMappingTests/WizardCoordinatorTests.swift`
- Create: `XtremeMapping/XtremeMappingTests/ControllerTemplateTests.swift`

**Interfaces:**
- Consumes: authoritative command IDs, MIDI assignment, lossless clone, throwing writer.
- Produces: every creation/transfer path using the new contracts; clean unit suite and application build.

- [ ] **Step 1: Write failing Wizard and template propagation tests**

Add these concrete behaviors:

```swift
func testWizardCapturedMappingUsesVerifiedCommandAndMIDIIDs() throws {
    let function = WizardFunction(
        displayName: "Play/Pause",
        commandID: 100,
        controllerType: .button,
        interactionMode: .toggle
    )
    let captured = WizardCapturedMapping(
        function: function,
        assignment: .deckC,
        midiMessage: MIDIMessage(channel: 9, note: 64, cc: nil, value: 127),
        modifierCondition: ModifierCondition(modifier: 1, value: 1)
    )
    let entry = captured.toMappingEntry()
    XCTAssertEqual(entry.commandID, 100)
    XCTAssertEqual(entry.midiAssignment, try .note(channel: 9, number: 64))
    XCTAssertEqual(entry.assignment, .deckC)
    XCTAssertEqual(entry.modifier1Condition, ModifierCondition(modifier: 1, value: 1))
}

func testEveryWizardFunctionUsesVerifiedInputCommand() {
    for tab in WizardTab.allCases {
        for function in tab.functions {
            let descriptor = TraktorCommands.descriptor(for: function.commandID)
            XCTAssertEqual(descriptor.verification, .verifiedTraktor441, "\(tab): \(function.displayName)")
            XCTAssertTrue(descriptor.supportedDirections.contains(.input), "\(tab): \(function.displayName)")
        }
    }
}
```

Add separate fixtures for hotcue command ID `2328` with `setToValue == 7` and a Remix Slot command retaining `.remixDeckDSlot4`. Add template tests that instantiate every built-in controller template and assert every produced row has a positive, verified descriptor supporting its I/O direction and a valid MIDI assignment. Confirm these tests fail on current name-only propagation before changing production sources.

- [ ] **Step 2: Update Wizard, templates, and the known ContentView creation boundaries**

Change `WizardFunction` to store `commandID`; derive its display command name from the catalog. Rewrite every literal in `WizardTab.swift` to an explicit audited ID. Remove any wizard row that cannot pass the verified-input test rather than silently resolving through a legacy name. `WizardCapturedMapping.toMappingEntry()` passes both `function.commandID` and a `MIDIAssignment` constructed from the captured message.

Change `WizardCoordinator.BindingKey` from command name to `(commandID, assignment, quantized setToValue)` and keep the existing conflict/overwrite tests. Add a regression where a stale historic label would previously collide but two different raw IDs must not overwrite one another.

In `ControllerTemplate.swift`, replace every name-only constructor with an explicit audited ID. Correct the known broken aliases (`Channel Fader`, `Crossfader`, `Dry/Wet`, `EQ Hi`, `EQ Lo`, `FX On`, `Sync`, `Tempo`); hotcue rows use command ID `2328` plus zero-based `setToValue`. A template row that is not direction-verified is removed from the preset instead of emitted optimistically.

Audit the known ContentView creation boundaries—Voice insertion and Input/Output/In-Out actions—plus all remaining constructors with:

```bash
rg -n 'MappingEntry\(' XtremeMapping/XtremeMapping
rg -n 'TSIWriter\(\)\.write|writer\.write' XtremeMapping
rg -n 'TraktorCommands\.id\(for:' XtremeMapping/XtremeMapping
```

Every production creation boundary passes an exact command ID or verified descriptor. `id(forLegacyName:)` remains only in `MappingEntry`'s name-only JSON compatibility decoder; templates, Wizard, Voice, Add menus, duplicate, paste, and drop do not call it. Every writer call handles `throws`. Task 8's Codable batch test plus Task 7's full-field clone test cover transfer propagation.

- [ ] **Step 3: Run the complete serialized unit suite**

Run:

```bash
scripts/test-unit.sh
```

Expected: all `XtremeMappingTests` execute with zero failures. Record the test count and `.xcresult` path in the task report.

- [ ] **Step 4: Build the application independently of tests**

Run:

```bash
xcodebuild build \
  -project XtremeMapping/SuperXtremeMapping.xcodeproj \
  -scheme XtremeMapping \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/xtrememapping-final-build \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** BUILD SUCCEEDED **` with exit 0.

- [ ] **Step 5: Inspect the final behavioral mutation points**

Confirm each of these searches is empty or contains only the documented migration API:

```bash
rg -n 'TraktorCommands\.id\(for:' XtremeMapping/XtremeMapping/Models/TSI
rg -n '@State private var clipboard' XtremeMapping/XtremeMapping
rg -n -U 'midiNote\s*=.*\n\s*.*midiCC\s*=' XtremeMapping/XtremeMapping
rg -n -U 'midiCC\s*=.*\n\s*.*midiNote\s*=' XtremeMapping/XtremeMapping
rg -n 'commandName:' XtremeMapping/XtremeMapping/Resources/Templates XtremeMapping/XtremeMapping/Models/Wizard
```

Then run `git diff --check` and inspect `git status --short` for only intended files.

- [ ] **Step 6: Commit**

Review `git diff --name-only` against the recorded worktree baseline, then stage only the seven explicit Task 11 files listed above. Do not use a broad directory add. Commit with `git commit -m "fix: propagate reliable mapping contracts"`.

---

## Final Acceptance Checklist

- [ ] Imported command ID 4242 saves and reloads as 4242 with its comment intact.
- [ ] Verified command creation passes the descriptor ID directly; no TSI writer path reverse-resolves a label.
- [ ] Meter IDs 2688/2689 use deck assignment targets rather than fabricated per-deck IDs.
- [ ] Note and CC are mutually exclusive across JSON, TSI, clipboard, manual edits, and Learn.
- [ ] Both encoder modes emit and re-import their real DCDT values; output controls are under DDCO.
- [ ] A batch copied from one `MappingFile` pastes into another in order with fresh IDs and every field intact.
- [ ] One learned message applies to the entire pasted selection and is one undo step.
- [ ] Mapping comments are visible, searchable, editable, and batch-applicable; device comments are separately editable.
- [ ] `scripts/test-unit.sh` reports zero unit-test failures with real executed test counts.
- [ ] Unsigned Debug application build exits 0.
