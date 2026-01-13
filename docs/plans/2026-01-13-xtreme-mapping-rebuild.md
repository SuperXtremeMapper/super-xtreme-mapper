# Xtreme Mapping Rebuild - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebuild Xtreme Mapping as a native macOS SwiftUI app for editing Traktor Pro TSI mapping files, targeting open-source release for the DJ community.

**Architecture:** Document-based SwiftUI app using `DocumentGroup`. TSI files (gzipped XML with Base64-encoded binary) are parsed into Swift models, edited via a two-column UI (mappings table + settings panel), and serialized back on save. Leverages existing reverse-engineered TSI format documentation.

**Tech Stack:** SwiftUI, Swift 5.9+, macOS 14+, XMLCoder (or Foundation XMLParser), Compression framework

---

## Table of Contents

1. [Project Setup](#task-1-project-setup)
2. [TSI File Format Parser](#task-2-tsi-file-format-parser)
3. [Data Models](#task-3-data-models)
4. [Document Architecture](#task-4-document-architecture)
5. [Main Window UI](#task-5-main-window-ui)
6. [Mappings Table](#task-6-mappings-table)
7. [Settings Panel](#task-7-settings-panel)
8. [Toolbar Actions](#task-8-toolbar-actions)
9. [Edit Menu & Bulk Operations](#task-9-edit-menu--bulk-operations)
10. [Filtering](#task-10-filtering)
11. [Drag and Drop](#task-11-drag-and-drop)
12. [Multi-Window Support](#task-12-multi-window-support)
13. [Controller Templates](#task-13-controller-templates)
14. [Polish & Theming](#task-14-polish--theming)

---

## Reference: TSI File Format

**Source:** [ivanz/TraktorMappingFileFormat](https://github.com/ivanz/TraktorMappingFileFormat/wiki/File-Format-Specification)

### File Structure
```
TSI File (XML)
└── <NIXML>
    └── <TraktorSettings>
        └── <Entry Name="DeviceIO.Config.Controller" Value="[BASE64]"/>
```

### Binary Structure (Big-Endian)
```
Frame {
    char[4] Identifier  // e.g., "DEVI", "CMAS", "CMAI"
    int32   Size
    byte[]  Data
}
```

### Key Frame Types
| Frame | Purpose |
|-------|---------|
| DEVI | Device definition |
| DDAT | Device data container |
| DDCB | Mappings container |
| CMAS | Mappings list |
| CMAI | Individual mapping |
| CMAD | Mapping settings |

### Enums
```swift
enum ControllerType: Int { case button = 0, faderOrKnob = 1, encoder = 2, led = 65535 }
enum InteractionMode: Int { case toggle, hold, direct, relative, increment, decrement, reset, output }
enum TargetDeck: Int { case deviceTarget = -1, deckA = 0, deckB, deckC, deckD, fxUnit1, fxUnit2, fxUnit3, fxUnit4, ... }
```

---

## Reference: Traktor Command Categories

### Deck Common
- Play/Pause, Cue, Cup, Sync, Tempo, Keylock, Flux, Reverse
- Jog Touch/Turn/Scratch, Loop controls, Beatjump
- **Submix** (Stem/Slot volume, filter, FX send, mute)

### Track Deck
- Hotcue 1-8 (Select, Set, Delete, Type)
- Beatgrid (Adjust, Lock, Reset), Load, Waveform Zoom

### Remix Deck / Pattern Player
- Slot Trigger/Volume/Filter/Mute/FX Send
- Step Sequencer (Steps 1-16, Pattern, Swing)
- Pattern Player (Start/Stop, Reset, Sound/Kit Select)

### Stem Deck (TP4)
- Stem 1-4: Volume, Filter, FX Send, Mute, Solo

### FX Unit
- Unit On/Off, Dry/Wet, Knob 1-3, Button 1-3, Effect Select

### Mixer
- Gain, EQ Hi/Mid/Lo, Filter, Channel Fader, Crossfader, Monitor

### Other
- Browser, Master Clock, Loop Recorder, Audio Recorder, Global, Layout, Modifier (M1-M8)

---

## Reference: UI Specification

### Window Layout
```
┌─────────────────────────────────────────────────────────────┐
│  [Add In] [Add Out] [Add In/Out] [Wizard] [Controller]  🔒  │
├─────────────────────────────────┬───────────────────────────┤
│  XMAPPINGS      Filters:[▾][▾]  │  XSETTINGS            [≡] │
├─────────────────────────────────┼───────────────────────────┤
│  Command|I/O|Assign|Int|Map|M1|M2│  Comment: [___________]  │
│  ───────────────────────────────│                           │
│  Filter    In  Deck A  Direct   │  Mapped to: [▾] [Learn]   │
│  Filter On In  Deck A  Toggle   │                    [Reset]│
│  Key On    In  Deck A  Toggle   │  Assignment: [__________] │
│  (magenta selection highlight)  │                           │
│                                 │  Modifiers: [▾][±] [▾][±] │
│                                 │                           │
│                                 │  Controller Interaction:  │
│                                 │  [___________________▾]   │
│                                 │  ☐ Invert                 │
└─────────────────────────────────┴───────────────────────────┘
```

### Table Columns
| Column | Content |
|--------|---------|
| Command | Traktor command name |
| I/O | In / Out |
| Assignment | Deck A-D, FX Unit 1-4, Global, etc. |
| Interaction | Direct, Toggle, Hold, Inc, Dec, etc. |
| Mapped to | MIDI note/CC (e.g., Ch01 CC 008) |
| Mod. 1 | First modifier condition |
| Mod. 2 | Second modifier condition |

### Settings Panel Fields
- **Comment**: Text field
- **Mapped to**: Dropdown + Learn + Reset buttons
- **Assignment**: Dropdown (Global, Deck A-D, FX Unit 1-4, etc.)
- **Modifiers**: 2 rows × (dropdown + stepper)
- **Controller Interaction**: Dropdown (Direct, Toggle, Hold, etc.)
- **Invert**: Checkbox

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| ⌘N | New Generic MIDI |
| ⌘O | Open |
| ⌘S | Save |
| ⌘D | Duplicate |
| ⌥⌘C | Copy Mapped to |
| ⌥⌘V | Paste Mapped to |
| ⇧⌘C | Copy Modifiers |
| ⇧⌘V | Paste Modifiers |
| ⌘A | Select All |
| Delete | Delete selected |

### Filter Options
**Category Filter:**
- All, Decks, Sample Decks, Effects Units, Mixer, Cue/Loops, Loop Recorder, Browser, Globals

**I/O Filter:**
- All, In, Out

---

## Task 1: Project Setup

**Files:**
- Create: `XtremeMapping.xcodeproj` (via Xcode)
- Create: `XtremeMapping/XtremeMappingApp.swift`
- Create: `XtremeMapping/Info.plist`
- Create: `Package.swift` (for SPM dependencies)

**Step 1: Create Xcode Project**

Open Xcode → File → New → Project → macOS → Document App

Settings:
- Product Name: `XtremeMapping`
- Team: (your team)
- Organization Identifier: `com.yourname`
- Interface: SwiftUI
- Language: Swift
- Include Tests: Yes
- Create Git repository: Yes

**Step 2: Configure document types in Info.plist**

Add to `Info.plist` under `CFBundleDocumentTypes`:
```xml
<dict>
    <key>CFBundleTypeName</key>
    <string>Traktor Settings Import</string>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>LSHandlerRank</key>
    <string>Owner</string>
    <key>LSItemContentTypes</key>
    <array>
        <string>com.native-instruments.traktor.tsi</string>
    </array>
</dict>
```

Add UTI declaration under `UTExportedTypeDeclarations`:
```xml
<dict>
    <key>UTTypeConformsTo</key>
    <array>
        <string>public.data</string>
    </array>
    <key>UTTypeDescription</key>
    <string>Traktor Settings Import File</string>
    <key>UTTypeIdentifier</key>
    <string>com.native-instruments.traktor.tsi</string>
    <key>UTTypeTagSpecification</key>
    <dict>
        <key>public.filename-extension</key>
        <array>
            <string>tsi</string>
        </array>
    </dict>
</dict>
```

**Step 3: Add SPM dependency for XML parsing**

File → Add Package Dependencies → Add:
- `https://github.com/CoreOffice/XMLCoder` (latest version)

**Step 4: Verify project builds**

Run: `⌘B` (Build)
Expected: Build Succeeded

**Step 5: Commit**

```bash
cd ~/Projects/XtremeMapping
git add .
git commit -m "chore: initial project setup with document type registration"
```

---

## Task 2: TSI File Format Parser

**Files:**
- Create: `XtremeMapping/Models/TSI/TSIFrame.swift`
- Create: `XtremeMapping/Models/TSI/TSIParser.swift`
- Create: `XtremeMapping/Models/TSI/TSIWriter.swift`
- Test: `XtremeMappingTests/TSIParserTests.swift`

**Step 1: Write failing test for frame parsing**

```swift
// XtremeMappingTests/TSIParserTests.swift
import XCTest
@testable import XtremeMapping

final class TSIParserTests: XCTestCase {
    func testParseFrameIdentifier() throws {
        // "DEVI" followed by size (4 bytes) and empty data
        let data = Data([0x44, 0x45, 0x56, 0x49, 0x00, 0x00, 0x00, 0x00])
        let frame = try TSIFrame.parse(from: data)
        XCTAssertEqual(frame.identifier, "DEVI")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `⌘U` or `xcodebuild test -scheme XtremeMapping`
Expected: FAIL - "Cannot find 'TSIFrame' in scope"

**Step 3: Implement TSIFrame**

```swift
// XtremeMapping/Models/TSI/TSIFrame.swift
import Foundation

struct TSIFrame {
    let identifier: String
    let size: Int32
    let data: Data
    var children: [TSIFrame]

    static func parse(from data: Data, offset: Int = 0) throws -> TSIFrame {
        guard data.count >= offset + 8 else {
            throw TSIParserError.unexpectedEndOfData
        }

        let identifierData = data.subdata(in: offset..<(offset + 4))
        let identifier = String(data: identifierData, encoding: .ascii) ?? ""

        let sizeData = data.subdata(in: (offset + 4)..<(offset + 8))
        let size = sizeData.withUnsafeBytes { $0.load(as: Int32.self).bigEndian }

        let frameData = data.subdata(in: (offset + 8)..<(offset + 8 + Int(size)))

        return TSIFrame(identifier: identifier, size: size, data: frameData, children: [])
    }
}

enum TSIParserError: Error {
    case unexpectedEndOfData
    case invalidXML
    case missingControllerEntry
    case invalidBase64
    case decompressionFailed
}
```

**Step 4: Run test to verify it passes**

Run: `⌘U`
Expected: PASS

**Step 5: Write test for XML extraction**

```swift
func testExtractBase64FromXML() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <NIXML>
      <TraktorSettings>
        <Entry Name="DeviceIO.Config.Controller" Type="3" Value="SEVMTE8="/>
      </TraktorSettings>
    </NIXML>
    """
    let base64 = try TSIParser.extractControllerData(from: xml.data(using: .utf8)!)
    XCTAssertEqual(base64, "SEVMTE8=")
}
```

**Step 6: Run test to verify it fails**

Expected: FAIL - "Cannot find 'TSIParser' in scope"

**Step 7: Implement TSIParser**

```swift
// XtremeMapping/Models/TSI/TSIParser.swift
import Foundation

struct TSIParser {
    static func extractControllerData(from xmlData: Data) throws -> String {
        let xml = try XMLDocument(data: xmlData)
        let nodes = try xml.nodes(forXPath: "/NIXML/TraktorSettings/Entry[@Name='DeviceIO.Config.Controller']/@Value")
        guard let valueNode = nodes.first, let value = valueNode.stringValue else {
            throw TSIParserError.missingControllerEntry
        }
        return value
    }

    static func decodeBase64(_ string: String) throws -> Data {
        guard let data = Data(base64Encoded: string) else {
            throw TSIParserError.invalidBase64
        }
        return data
    }

    static func parseFrames(from binaryData: Data) throws -> [TSIFrame] {
        var frames: [TSIFrame] = []
        var offset = 0

        while offset < binaryData.count - 8 {
            let frame = try TSIFrame.parse(from: binaryData, offset: offset)
            frames.append(frame)
            offset += 8 + Int(frame.size)
        }

        return frames
    }
}
```

**Step 8: Run tests**

Run: `⌘U`
Expected: All PASS

**Step 9: Commit**

```bash
git add .
git commit -m "feat: add TSI frame parser with XML extraction"
```

---

## Task 3: Data Models

**Files:**
- Create: `XtremeMapping/Models/MappingFile.swift`
- Create: `XtremeMapping/Models/Device.swift`
- Create: `XtremeMapping/Models/MappingEntry.swift`
- Create: `XtremeMapping/Models/Enums/ControllerType.swift`
- Create: `XtremeMapping/Models/Enums/InteractionMode.swift`
- Create: `XtremeMapping/Models/Enums/TargetAssignment.swift`
- Create: `XtremeMapping/Models/Enums/CommandCategory.swift`
- Test: `XtremeMappingTests/MappingEntryTests.swift`

**Step 1: Create enum types**

```swift
// XtremeMapping/Models/Enums/ControllerType.swift
import Foundation

enum ControllerType: Int, Codable, CaseIterable {
    case button = 0
    case faderOrKnob = 1
    case encoder = 2
    case led = 65535

    var displayName: String {
        switch self {
        case .button: return "Button"
        case .faderOrKnob: return "Fader/Knob"
        case .encoder: return "Encoder"
        case .led: return "LED"
        }
    }
}
```

```swift
// XtremeMapping/Models/Enums/InteractionMode.swift
import Foundation

enum InteractionMode: Int, Codable, CaseIterable {
    case toggle = 0
    case hold = 1
    case direct = 2
    case relative = 3
    case increment = 4
    case decrement = 5
    case reset = 6
    case output = 7
    case trigger = 8

    var displayName: String {
        switch self {
        case .toggle: return "Toggle"
        case .hold: return "Hold"
        case .direct: return "Direct"
        case .relative: return "Relative"
        case .increment: return "Inc"
        case .decrement: return "Dec"
        case .reset: return "Reset"
        case .output: return "Output"
        case .trigger: return "Trigger"
        }
    }
}
```

```swift
// XtremeMapping/Models/Enums/TargetAssignment.swift
import Foundation

enum TargetAssignment: Int, Codable, CaseIterable {
    case deviceTarget = -1
    case global = 0
    case deckA = 1
    case deckB = 2
    case deckC = 3
    case deckD = 4
    case fxUnit1 = 5
    case fxUnit2 = 6
    case fxUnit3 = 7
    case fxUnit4 = 8

    var displayName: String {
        switch self {
        case .deviceTarget: return "Device Target"
        case .global: return "Global"
        case .deckA: return "Deck A"
        case .deckB: return "Deck B"
        case .deckC: return "Deck C"
        case .deckD: return "Deck D"
        case .fxUnit1: return "FX Unit 1"
        case .fxUnit2: return "FX Unit 2"
        case .fxUnit3: return "FX Unit 3"
        case .fxUnit4: return "FX Unit 4"
        }
    }
}
```

```swift
// XtremeMapping/Models/Enums/CommandCategory.swift
import Foundation

enum CommandCategory: String, Codable, CaseIterable {
    case all = "All"
    case decks = "Decks"
    case sampleDecks = "Sample Decks"
    case effectsUnits = "Effects Units"
    case mixer = "Mixer"
    case cueLoops = "Cue/Loops"
    case loopRecorder = "Loop Recorder"
    case browser = "Browser"
    case globals = "Globals"
}

enum IODirection: String, Codable, CaseIterable {
    case all = "All"
    case input = "In"
    case output = "Out"
}
```

**Step 2: Create MappingEntry model**

```swift
// XtremeMapping/Models/MappingEntry.swift
import Foundation

struct MappingEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var commandName: String
    var ioType: IODirection
    var assignment: TargetAssignment
    var interactionMode: InteractionMode
    var midiChannel: Int
    var midiNote: Int?
    var midiCC: Int?
    var modifier1Condition: ModifierCondition?
    var modifier2Condition: ModifierCondition?
    var comment: String
    var controllerType: ControllerType
    var invert: Bool

    var mappedToDisplay: String {
        let channelStr = "Ch\(String(format: "%02d", midiChannel))"
        if let note = midiNote {
            return "\(channelStr) Note \(midiNoteToName(note))"
        } else if let cc = midiCC {
            return "\(channelStr) CC \(String(format: "%03d", cc))"
        }
        return channelStr
    }

    private func midiNoteToName(_ note: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let noteName = noteNames[note % 12]
        return "\(noteName)\(octave)"
    }

    init(id: UUID = UUID(), commandName: String = "", ioType: IODirection = .input,
         assignment: TargetAssignment = .global, interactionMode: InteractionMode = .direct,
         midiChannel: Int = 1, midiNote: Int? = nil, midiCC: Int? = nil,
         modifier1Condition: ModifierCondition? = nil, modifier2Condition: ModifierCondition? = nil,
         comment: String = "", controllerType: ControllerType = .button, invert: Bool = false) {
        self.id = id
        self.commandName = commandName
        self.ioType = ioType
        self.assignment = assignment
        self.interactionMode = interactionMode
        self.midiChannel = midiChannel
        self.midiNote = midiNote
        self.midiCC = midiCC
        self.modifier1Condition = modifier1Condition
        self.modifier2Condition = modifier2Condition
        self.comment = comment
        self.controllerType = controllerType
        self.invert = invert
    }
}

struct ModifierCondition: Codable, Hashable {
    var modifier: Int // M1-M8
    var value: Int    // 0-7

    var displayString: String {
        "M\(modifier) = \(value)"
    }
}
```

**Step 3: Create Device and MappingFile models**

```swift
// XtremeMapping/Models/Device.swift
import Foundation

struct Device: Identifiable, Codable {
    let id: UUID
    var name: String
    var comment: String
    var inPort: String
    var outPort: String
    var mappings: [MappingEntry]

    init(id: UUID = UUID(), name: String = "Generic MIDI", comment: String = "",
         inPort: String = "", outPort: String = "", mappings: [MappingEntry] = []) {
        self.id = id
        self.name = name
        self.comment = comment
        self.inPort = inPort
        self.outPort = outPort
        self.mappings = mappings
    }
}
```

```swift
// XtremeMapping/Models/MappingFile.swift
import Foundation

struct MappingFile: Codable {
    var devices: [Device]
    var version: Int

    init(devices: [Device] = [], version: Int = 0) {
        self.devices = devices
        self.version = version
    }

    var allMappings: [MappingEntry] {
        devices.flatMap { $0.mappings }
    }
}
```

**Step 4: Write test**

```swift
// XtremeMappingTests/MappingEntryTests.swift
import XCTest
@testable import XtremeMapping

final class MappingEntryTests: XCTestCase {
    func testMappedToDisplayCC() {
        let entry = MappingEntry(midiChannel: 1, midiCC: 8)
        XCTAssertEqual(entry.mappedToDisplay, "Ch01 CC 008")
    }

    func testMappedToDisplayNote() {
        let entry = MappingEntry(midiChannel: 2, midiNote: 60)
        XCTAssertEqual(entry.mappedToDisplay, "Ch02 Note C4")
    }
}
```

**Step 5: Run tests**

Run: `⌘U`
Expected: All PASS

**Step 6: Commit**

```bash
git add .
git commit -m "feat: add data models for mapping entries, devices, and enums"
```

---

## Task 4: Document Architecture

**Files:**
- Create: `XtremeMapping/Document/TraktorMappingDocument.swift`
- Modify: `XtremeMapping/XtremeMappingApp.swift`
- Test: `XtremeMappingTests/DocumentTests.swift`

**Step 1: Write failing test**

```swift
// XtremeMappingTests/DocumentTests.swift
import XCTest
import UniformTypeIdentifiers
@testable import XtremeMapping

final class DocumentTests: XCTestCase {
    func testDocumentReadableTypes() {
        let types = TraktorMappingDocument.readableContentTypes
        XCTAssertTrue(types.contains(where: { $0.identifier == "com.native-instruments.traktor.tsi" }))
    }
}
```

**Step 2: Run test to verify it fails**

Expected: FAIL - "Cannot find 'TraktorMappingDocument'"

**Step 3: Implement TraktorMappingDocument**

```swift
// XtremeMapping/Document/TraktorMappingDocument.swift
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var tsi: UTType {
        UTType(exportedAs: "com.native-instruments.traktor.tsi")
    }
}

struct TraktorMappingDocument: FileDocument {
    var mappingFile: MappingFile

    static var readableContentTypes: [UTType] { [.tsi] }

    init(mappingFile: MappingFile = MappingFile()) {
        self.mappingFile = mappingFile
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Parse TSI file
        let base64String = try TSIParser.extractControllerData(from: data)
        let binaryData = try TSIParser.decodeBase64(base64String)
        let frames = try TSIParser.parseFrames(from: binaryData)

        // Convert frames to model (simplified for now)
        self.mappingFile = try TSIParser.buildMappingFile(from: frames)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Serialize model back to TSI format
        let data = try TSIWriter.write(mappingFile: mappingFile)
        return .init(regularFileWithContents: data)
    }
}
```

**Step 4: Update App entry point**

```swift
// XtremeMapping/XtremeMappingApp.swift
import SwiftUI

@main
struct XtremeMappingApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TraktorMappingDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Menu("New") {
                    Button("Generic MIDI") {
                        NSDocumentController.shared.newDocument(nil)
                    }
                    .keyboardShortcut("n", modifiers: .command)

                    Divider()

                    Button("Kontrol X1") { /* Template */ }
                    Button("Kontrol S2") { /* Template */ }
                    Button("Kontrol S4") { /* Template */ }
                }
            }
        }
    }
}
```

**Step 5: Run tests**

Run: `⌘U`
Expected: All PASS

**Step 6: Commit**

```bash
git add .
git commit -m "feat: add document architecture with TSI file type registration"
```

---

## Task 5: Main Window UI

**Files:**
- Create: `XtremeMapping/Views/ContentView.swift`
- Create: `XtremeMapping/Views/MappingsTableView.swift`
- Create: `XtremeMapping/Views/SettingsPanel.swift`
- Create: `XtremeMapping/Views/ToolbarView.swift`

**Step 1: Create ContentView with two-column layout**

```swift
// XtremeMapping/Views/ContentView.swift
import SwiftUI

struct ContentView: View {
    @Binding var document: TraktorMappingDocument
    @State private var selectedMappings: Set<MappingEntry.ID> = []
    @State private var categoryFilter: CommandCategory = .all
    @State private var ioFilter: IODirection = .all
    @State private var isLocked: Bool = false

    var filteredMappings: [MappingEntry] {
        document.mappingFile.allMappings.filter { entry in
            let categoryMatch = categoryFilter == .all || matchesCategory(entry)
            let ioMatch = ioFilter == .all || entry.ioType == ioFilter
            return categoryMatch && ioMatch
        }
    }

    var body: some View {
        HSplitView {
            // Left: Mappings Table
            VStack(alignment: .leading, spacing: 0) {
                // Header with filters
                HStack {
                    Text("MAPPINGS")
                        .font(.headline)
                        .foregroundColor(.pink)

                    Spacer()

                    Text("Filters:")
                        .foregroundColor(.secondary)

                    Picker("Category", selection: $categoryFilter) {
                        ForEach(CommandCategory.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .frame(width: 120)

                    Picker("I/O", selection: $ioFilter) {
                        ForEach(IODirection.allCases, id: \.self) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                    .frame(width: 60)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
                    .background(Color.pink)

                // Mappings table
                MappingsTableView(
                    mappings: filteredMappings,
                    selection: $selectedMappings,
                    isLocked: isLocked
                )
            }
            .frame(minWidth: 500)

            // Right: Settings Panel
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("SETTINGS")
                        .font(.headline)
                        .foregroundColor(.pink)

                    Spacer()

                    Menu {
                        Button("Duplicate") { duplicateSelected() }
                        Divider()
                        Button("Copy Mapped to") { copyMappedTo() }
                        Button("Paste Mapped to") { pasteMappedTo() }
                        Button("Change Mapped to") { }
                        Divider()
                        Button("Copy Modifiers") { copyModifiers() }
                        Button("Paste Modifiers") { pasteModifiers() }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()
                    .background(Color.pink)

                SettingsPanel(
                    document: $document,
                    selectedMappings: selectedMappings,
                    isLocked: isLocked
                )
            }
            .frame(minWidth: 250, maxWidth: 300)
        }
        .toolbar {
            ToolbarView(
                document: $document,
                isLocked: $isLocked
            )
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func matchesCategory(_ entry: MappingEntry) -> Bool {
        // TODO: Implement category matching based on command name
        true
    }

    private func duplicateSelected() { }
    private func copyMappedTo() { }
    private func pasteMappedTo() { }
    private func copyModifiers() { }
    private func pasteModifiers() { }
}
```

**Step 2: Run to verify it compiles**

Run: `⌘B`
Expected: Build Succeeded (with placeholder views)

**Step 3: Commit**

```bash
git add .
git commit -m "feat: add main window layout with two-column split view"
```

---

## Task 6: Mappings Table

**Files:**
- Create: `XtremeMapping/Views/MappingsTableView.swift`

**Step 1: Implement mappings table**

```swift
// XtremeMapping/Views/MappingsTableView.swift
import SwiftUI

struct MappingsTableView: View {
    let mappings: [MappingEntry]
    @Binding var selection: Set<MappingEntry.ID>
    let isLocked: Bool

    var body: some View {
        Table(mappings, selection: $selection) {
            TableColumn("Command") { entry in
                Text(entry.commandName)
            }
            .width(min: 100, ideal: 150)

            TableColumn("I/O") { entry in
                Text(entry.ioType == .input ? "In" : "Out")
            }
            .width(30)

            TableColumn("Assignment") { entry in
                Text(entry.assignment.displayName)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Interaction") { entry in
                Text(entry.interactionMode.displayName)
            }
            .width(min: 50, ideal: 70)

            TableColumn("Mapped to") { entry in
                Text(entry.mappedToDisplay)
            }
            .width(min: 80, ideal: 100)

            TableColumn("Mod. 1") { entry in
                if let mod = entry.modifier1Condition {
                    Text(mod.displayString)
                }
            }
            .width(50)

            TableColumn("Mod. 2") { entry in
                if let mod = entry.modifier2Condition {
                    Text(mod.displayString)
                }
            }
            .width(50)
        }
        .tableStyle(.bordered)
        .alternatingRowBackgrounds(.disabled)
    }
}
```

**Step 2: Add row styling for selection**

```swift
// Add custom row background modifier
extension View {
    func mappingRowStyle(isSelected: Bool) -> some View {
        self.background(isSelected ? Color.pink.opacity(0.6) : Color.clear)
    }
}
```

**Step 3: Run and verify**

Run: `⌘R`
Expected: Table displays with columns (empty data for now)

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add mappings table with all columns"
```

---

## Task 7: Settings Panel

**Files:**
- Create: `XtremeMapping/Views/SettingsPanel.swift`
- Create: `XtremeMapping/Views/Components/MappedToPicker.swift`
- Create: `XtremeMapping/Views/Components/ModifierRow.swift`

**Step 1: Implement settings panel**

```swift
// XtremeMapping/Views/SettingsPanel.swift
import SwiftUI

struct SettingsPanel: View {
    @Binding var document: TraktorMappingDocument
    let selectedMappings: Set<MappingEntry.ID>
    let isLocked: Bool

    @State private var comment: String = ""
    @State private var mappedTo: String = ""
    @State private var assignment: TargetAssignment = .global
    @State private var interactionMode: InteractionMode = .direct
    @State private var modifier1: ModifierCondition?
    @State private var modifier2: ModifierCondition?
    @State private var invert: Bool = false

    private var selectedEntry: MappingEntry? {
        guard selectedMappings.count == 1,
              let id = selectedMappings.first else { return nil }
        return document.mappingFile.allMappings.first { $0.id == id }
    }

    private var isMultipleSelection: Bool {
        selectedMappings.count > 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if selectedMappings.isEmpty {
                    Text("No selection")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if isMultipleSelection {
                    Text("\(selectedMappings.count) items selected")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else if let entry = selectedEntry {
                    // Command name display
                    Text(entry.commandName)
                        .font(.headline)

                    Divider().background(Color.pink)

                    // Comment
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comment")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("", text: $comment)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isLocked)
                    }

                    Divider().background(Color.pink)

                    // Mapped to
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mapped to")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Picker("", selection: $mappedTo) {
                                Text(entry.mappedToDisplay).tag(entry.mappedToDisplay)
                            }
                            .frame(maxWidth: .infinity)

                            Button("Learn") {
                                // TODO: MIDI learn
                            }
                            .disabled(isLocked)

                            Button("Reset") {
                                // TODO: Reset MIDI
                            }
                            .disabled(isLocked)
                        }
                    }

                    // Assignment
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assignment")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $assignment) {
                            ForEach(TargetAssignment.allCases, id: \.self) { target in
                                Text(target.displayName).tag(target)
                            }
                        }
                        .disabled(isLocked)
                    }

                    Divider().background(Color.pink)

                    // Modifiers
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Modifiers")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ModifierRow(condition: $modifier1, isLocked: isLocked)
                        ModifierRow(condition: $modifier2, isLocked: isLocked)
                    }

                    Divider().background(Color.pink)

                    // Controller Interaction
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Controller Interaction")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("", selection: $interactionMode) {
                            ForEach(InteractionMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .disabled(isLocked)
                    }

                    // Invert
                    Toggle("Invert", isOn: $invert)
                        .disabled(isLocked)
                }

                Spacer()
            }
            .padding()
        }
        .onChange(of: selectedEntry) { _, newEntry in
            if let entry = newEntry {
                comment = entry.comment
                mappedTo = entry.mappedToDisplay
                assignment = entry.assignment
                interactionMode = entry.interactionMode
                modifier1 = entry.modifier1Condition
                modifier2 = entry.modifier2Condition
                invert = entry.invert
            }
        }
    }
}
```

**Step 2: Implement ModifierRow**

```swift
// XtremeMapping/Views/Components/ModifierRow.swift
import SwiftUI

struct ModifierRow: View {
    @Binding var condition: ModifierCondition?
    let isLocked: Bool

    @State private var selectedModifier: Int = 0
    @State private var selectedValue: Int = 0

    var body: some View {
        HStack {
            Picker("", selection: $selectedModifier) {
                Text("-").tag(0)
                ForEach(1...8, id: \.self) { num in
                    Text("M\(num)").tag(num)
                }
            }
            .frame(maxWidth: .infinity)
            .disabled(isLocked)

            Stepper(value: $selectedValue, in: 0...7) {
                Text("\(selectedValue)")
                    .frame(width: 20)
            }
            .disabled(isLocked || selectedModifier == 0)
        }
        .onChange(of: selectedModifier) { _, newValue in
            if newValue == 0 {
                condition = nil
            } else {
                condition = ModifierCondition(modifier: newValue, value: selectedValue)
            }
        }
        .onChange(of: selectedValue) { _, newValue in
            if selectedModifier > 0 {
                condition = ModifierCondition(modifier: selectedModifier, value: newValue)
            }
        }
    }
}
```

**Step 3: Run and verify**

Run: `⌘R`
Expected: Settings panel shows with all fields

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add settings panel with all edit fields"
```

---

## Task 8: Toolbar Actions

**Files:**
- Create: `XtremeMapping/Views/ToolbarView.swift`
- Create: `XtremeMapping/Resources/Assets.xcassets` (toolbar icons)

**Step 1: Implement toolbar**

```swift
// XtremeMapping/Views/ToolbarView.swift
import SwiftUI

struct ToolbarView: ToolbarContent {
    @Binding var document: TraktorMappingDocument
    @Binding var isLocked: Bool

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                addMapping(ioType: .input)
            } label: {
                VStack {
                    Image(systemName: "arrow.down.to.line")
                    Text("Add In")
                        .font(.caption2)
                }
            }
            .help("Add MIDI Input mapping")
            .disabled(isLocked)

            Button {
                addMapping(ioType: .output)
            } label: {
                VStack {
                    Image(systemName: "arrow.up.to.line")
                    Text("Add Out")
                        .font(.caption2)
                }
            }
            .help("Add MIDI Output mapping")
            .disabled(isLocked)

            Button {
                addInOutPair()
            } label: {
                VStack {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Add In/Out")
                        .font(.caption2)
                }
            }
            .help("Add paired In/Out mapping")
            .disabled(isLocked)

            Divider()

            Button {
                showWizard()
            } label: {
                VStack {
                    Image(systemName: "wand.and.stars")
                    Text("Wizard")
                        .font(.caption2)
                }
            }
            .help("Open Mapping Wizard")
            .disabled(isLocked)

            Button {
                showControllerSetup()
            } label: {
                VStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Controller")
                        .font(.caption2)
                }
            }
            .help("Controller Setup")
        }

        ToolbarItem(placement: .automatic) {
            Spacer()
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                isLocked.toggle()
            } label: {
                VStack {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open")
                    Text("Lock")
                        .font(.caption2)
                }
            }
            .help(isLocked ? "Unlock editing" : "Lock to prevent changes")
        }
    }

    private func addMapping(ioType: IODirection) {
        let newEntry = MappingEntry(
            commandName: "New Command",
            ioType: ioType
        )
        // Add to first device or create one
        if document.mappingFile.devices.isEmpty {
            document.mappingFile.devices.append(Device(mappings: [newEntry]))
        } else {
            document.mappingFile.devices[0].mappings.append(newEntry)
        }
    }

    private func addInOutPair() {
        addMapping(ioType: .input)
        addMapping(ioType: .output)
    }

    private func showWizard() {
        // TODO: Implement wizard sheet
    }

    private func showControllerSetup() {
        // TODO: Implement controller setup sheet
    }
}
```

**Step 2: Run and verify**

Run: `⌘R`
Expected: Toolbar displays with all buttons

**Step 3: Commit**

```bash
git add .
git commit -m "feat: add toolbar with Add In/Out, Wizard, Controller, and Lock buttons"
```

---

## Task 9: Edit Menu & Bulk Operations

**Files:**
- Modify: `XtremeMapping/XtremeMappingApp.swift`
- Create: `XtremeMapping/Commands/EditCommands.swift`

**Step 1: Add edit menu commands**

```swift
// XtremeMapping/Commands/EditCommands.swift
import SwiftUI

struct EditCommands: Commands {
    @FocusedBinding(\.selectedMappings) var selectedMappings
    @FocusedBinding(\.document) var document

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()

            Button("Duplicate") {
                // TODO: Implement
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button("Copy Mapped to") {
                // TODO: Implement
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Button("Paste Mapped to") {
                // TODO: Implement
            }
            .keyboardShortcut("v", modifiers: [.command, .option])

            Button("Reset Mapped to") {
                // TODO: Implement
            }

            Menu("Change Mapped to") {
                Menu("Move to MIDI Channel") {
                    ForEach(1...16, id: \.self) { channel in
                        Button("Channel \(channel)") {
                            // TODO: Implement
                        }
                    }
                }
            }

            Menu("Change Assignment") {
                Button("Device Target") { }
                Divider()
                Button("Deck A") { }
                Button("Deck B") { }
                Button("Deck C") { }
                Button("Deck D") { }
            }

            Divider()

            Button("Copy Modifiers") {
                // TODO: Implement
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Paste Modifiers") {
                // TODO: Implement
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
        }
    }
}

// Focus keys for document state
struct SelectedMappingsKey: FocusedValueKey {
    typealias Value = Binding<Set<MappingEntry.ID>>
}

struct DocumentKey: FocusedValueKey {
    typealias Value = Binding<TraktorMappingDocument>
}

extension FocusedValues {
    var selectedMappings: Binding<Set<MappingEntry.ID>>? {
        get { self[SelectedMappingsKey.self] }
        set { self[SelectedMappingsKey.self] = newValue }
    }

    var document: Binding<TraktorMappingDocument>? {
        get { self[DocumentKey.self] }
        set { self[DocumentKey.self] = newValue }
    }
}
```

**Step 2: Update App to include commands**

```swift
// In XtremeMappingApp.swift, add:
.commands {
    EditCommands()
}
```

**Step 3: Run and verify**

Run: `⌘R`
Expected: Edit menu shows all custom commands

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add Edit menu with bulk operations and keyboard shortcuts"
```

---

## Task 10: Filtering

**Files:**
- Modify: `XtremeMapping/Views/ContentView.swift`
- Create: `XtremeMapping/Utilities/CommandCategoryMatcher.swift`

**Step 1: Implement category matching**

```swift
// XtremeMapping/Utilities/CommandCategoryMatcher.swift
import Foundation

struct CommandCategoryMatcher {
    static func category(for commandName: String) -> CommandCategory {
        let name = commandName.lowercased()

        if name.contains("deck") && !name.contains("sample") && !name.contains("remix") {
            return .decks
        }
        if name.contains("sample") || name.contains("remix") || name.contains("slot") {
            return .sampleDecks
        }
        if name.contains("fx") || name.contains("effect") {
            return .effectsUnits
        }
        if name.contains("eq") || name.contains("gain") || name.contains("fader") ||
           name.contains("crossfader") || name.contains("filter") {
            return .mixer
        }
        if name.contains("cue") || name.contains("loop") || name.contains("hotcue") {
            return .cueLoops
        }
        if name.contains("loop recorder") {
            return .loopRecorder
        }
        if name.contains("browser") || name.contains("tree") || name.contains("list") {
            return .browser
        }
        if name.contains("global") || name.contains("master") || name.contains("snap") ||
           name.contains("quantize") {
            return .globals
        }

        return .decks // Default
    }

    static func matches(_ entry: MappingEntry, category: CommandCategory) -> Bool {
        if category == .all { return true }
        return self.category(for: entry.commandName) == category
    }
}
```

**Step 2: Update ContentView filtering**

```swift
// In ContentView.swift, update filteredMappings:
var filteredMappings: [MappingEntry] {
    document.mappingFile.allMappings.filter { entry in
        let categoryMatch = CommandCategoryMatcher.matches(entry, category: categoryFilter)
        let ioMatch = ioFilter == .all || entry.ioType == ioFilter
        return categoryMatch && ioMatch
    }
}
```

**Step 3: Run and verify**

Run: `⌘R`
Expected: Filters correctly narrow displayed mappings

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add category and I/O filtering for mappings table"
```

---

## Task 11: Drag and Drop

**Files:**
- Modify: `XtremeMapping/Views/MappingsTableView.swift`
- Create: `XtremeMapping/Utilities/MappingTransferable.swift`

**Step 1: Make MappingEntry transferable**

```swift
// XtremeMapping/Utilities/MappingTransferable.swift
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var mappingEntry: UTType {
        UTType(exportedAs: "com.xtrememapping.mapping-entry")
    }
}

extension MappingEntry: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: MappingEntry.self, contentType: .mappingEntry)
    }
}
```

**Step 2: Add drag and drop to table**

```swift
// In MappingsTableView.swift, wrap table rows with:
.draggable(entry) {
    Text("\(entry.commandName)")
        .padding(4)
        .background(Color.pink.opacity(0.8))
        .cornerRadius(4)
}

// Add drop destination to table:
.dropDestination(for: MappingEntry.self) { items, location in
    // Handle drop - insert at location
    return true
}
```

**Step 3: Run and verify**

Run: `⌘R`
Expected: Can drag rows within table

**Step 4: Commit**

```bash
git add .
git commit -m "feat: add drag and drop for reordering mappings"
```

---

## Task 12: Multi-Window Support

**Files:**
- Modify: `XtremeMapping/Views/ContentView.swift`

**Step 1: Enable cross-window drag and drop**

SwiftUI's `DocumentGroup` already supports multiple windows. Drag and drop between windows works automatically with `Transferable` conformance.

**Step 2: Test multi-window**

Run: `⌘R`, then `⌘N` to open second window
Expected: Can drag mappings between windows

**Step 3: Commit**

```bash
git add .
git commit -m "feat: verify multi-window drag and drop support"
```

---

## Task 13: Controller Templates

**Files:**
- Create: `XtremeMapping/Resources/Templates/GenericMIDI.swift`
- Create: `XtremeMapping/Resources/Templates/KontrolX1.swift`
- Create: `XtremeMapping/Resources/Templates/KontrolS2.swift`
- Create: `XtremeMapping/Resources/Templates/KontrolS4.swift`

**Step 1: Create template protocol**

```swift
// XtremeMapping/Resources/Templates/ControllerTemplate.swift
import Foundation

protocol ControllerTemplate {
    static var name: String { get }
    static func createDocument() -> TraktorMappingDocument
}

struct GenericMIDITemplate: ControllerTemplate {
    static var name = "Generic MIDI"

    static func createDocument() -> TraktorMappingDocument {
        let device = Device(name: "Generic MIDI")
        return TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
    }
}

struct KontrolX1Template: ControllerTemplate {
    static var name = "Kontrol X1"

    static func createDocument() -> TraktorMappingDocument {
        let device = Device(name: "Kontrol X1", comment: "Native Instruments Kontrol X1")
        // TODO: Add default X1 mappings
        return TraktorMappingDocument(mappingFile: MappingFile(devices: [device]))
    }
}
```

**Step 2: Wire up File → New menu**

```swift
// Update XtremeMappingApp.swift New menu:
Button("Kontrol X1") {
    let doc = KontrolX1Template.createDocument()
    // Open new document
}
```

**Step 3: Commit**

```bash
git add .
git commit -m "feat: add controller templates for New menu"
```

---

## Task 14: Polish & Theming

**Files:**
- Create: `XtremeMapping/Theme/AppTheme.swift`
- Create: `XtremeMapping/Resources/Assets.xcassets/AppIcon.appiconset`
- Modify: All view files for consistent theming

**Step 1: Create theme constants**

```swift
// XtremeMapping/Theme/AppTheme.swift
import SwiftUI

enum AppTheme {
    static let accentColor = Color.pink
    static let backgroundColor = Color(nsColor: .windowBackgroundColor)
    static let tableBackground = Color(nsColor: .controlBackgroundColor)
    static let selectionColor = Color.pink.opacity(0.6)
    static let dividerColor = Color.pink.opacity(0.5)

    static let headerFont = Font.headline
    static let labelFont = Font.caption
    static let bodyFont = Font.body
}
```

**Step 2: Apply theme consistently**

Update all views to use `AppTheme` constants.

**Step 3: Add app icon**

Create 1024x1024 app icon with "X" branding in magenta/pink style.

**Step 4: Final build and test**

Run: `⌘R`
Expected: Complete app with consistent theming

**Step 5: Commit**

```bash
git add .
git commit -m "feat: add app theming and icon"
```

---

## Summary

### Phase 1 (MVP) - Tasks 1-7
- Project setup, TSI parser, data models, document architecture
- Basic two-column UI with table and settings panel
- **Deliverable:** Can open, view, edit, and save TSI files

### Phase 2 (Core Editing) - Tasks 8-10
- Toolbar actions, Edit menu with bulk operations
- Filtering by category and I/O direction
- **Deliverable:** Full editing capabilities

### Phase 3 (Power Features) - Tasks 11-13
- Drag and drop within and between documents
- Multi-window support
- Controller templates
- **Deliverable:** Power user workflows

### Phase 4 (Polish) - Task 14
- Consistent theming, app icon
- **Deliverable:** Release-ready app

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| XMLCoder | Latest | XML parsing |

## Test Coverage Goals

- TSI parsing: 90%+
- Data models: 80%+
- UI: Manual testing

## Future Enhancements (Post-MVP)

- MIDI Learn with live input detection
- Mapping Wizard dialogs
- Command browser with search
- Undo/redo history viewer
- iCloud sync
- Traktor Pro 4 stem/pattern player command templates
