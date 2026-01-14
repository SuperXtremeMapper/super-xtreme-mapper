//
//  TraktorCommands.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation

/// Lookup table for Traktor command IDs to human-readable names.
/// Based on CMDR TSI Editor: https://github.com/cmdr-editor/cmdr
enum TraktorCommands {

    /// Returns the command ID for a human-readable name
    /// If the name is not found, returns 0
    static func id(for name: String) -> Int {
        // Check if it's a "Command #N" format
        if name.hasPrefix("Command #"), let idStr = name.split(separator: "#").last, let id = Int(idStr) {
            return id
        }

        // Search the lookup table
        for (id, cmdName) in commandLookup {
            if cmdName == name {
                return id
            }
        }

        // Handle dynamic ranges
        if name.hasPrefix("Slot 1 Cell ") && name.hasSuffix(" Trigger") {
            if let num = Int(name.dropFirst(12).dropLast(8)) {
                return 600 + num
            }
        }
        if name.hasPrefix("Slot 2 Cell ") && name.hasSuffix(" Trigger") {
            if let num = Int(name.dropFirst(12).dropLast(8)) {
                return 616 + num
            }
        }
        if name.hasPrefix("Slot 3 Cell ") && name.hasSuffix(" Trigger") {
            if let num = Int(name.dropFirst(12).dropLast(8)) {
                return 632 + num
            }
        }
        if name.hasPrefix("Slot 4 Cell ") && name.hasSuffix(" Trigger") {
            if let num = Int(name.dropFirst(12).dropLast(8)) {
                return 648 + num
            }
        }
        if name.hasPrefix("Modifier #") {
            if let num = Int(name.dropFirst(10)) {
                return 2547 + num
            }
        }

        return 0
    }

    /// Returns the human-readable name for a Traktor command ID
    static func name(for commandId: Int) -> String {
        // Check static lookup first
        if let name = commandLookup[commandId] {
            return name
        }

        // Handle Remix Deck Cell ranges (Slot 1-4, Cell 1-16)
        if commandId >= 601 && commandId <= 616 {
            return "Slot 1 Cell \(commandId - 600) Trigger"
        }
        if commandId >= 617 && commandId <= 632 {
            return "Slot 2 Cell \(commandId - 616) Trigger"
        }
        if commandId >= 633 && commandId <= 648 {
            return "Slot 3 Cell \(commandId - 632) Trigger"
        }
        if commandId >= 649 && commandId <= 664 {
            return "Slot 4 Cell \(commandId - 648) Trigger"
        }
        if commandId >= 665 && commandId <= 680 {
            return "Slot 1 Cell \(commandId - 664) State"
        }
        if commandId >= 681 && commandId <= 696 {
            return "Slot 2 Cell \(commandId - 680) State"
        }
        if commandId >= 697 && commandId <= 712 {
            return "Slot 3 Cell \(commandId - 696) State"
        }
        if commandId >= 713 && commandId <= 728 {
            return "Slot 4 Cell \(commandId - 712) State"
        }

        // Modifiers 1-8
        if commandId >= 2548 && commandId <= 2555 {
            return "Modifier #\(commandId - 2547)"
        }

        // Duplicate Track Deck A-D
        if commandId >= 2401 && commandId <= 2404 {
            let decks = ["A", "B", "C", "D"]
            return "Duplicate Track Deck \(decks[commandId - 2401])"
        }

        // Mixer Meters (Output only)
        if commandId >= 2688 && commandId <= 2691 {
            let decks = ["A", "B", "C", "D"]
            return "Deck \(decks[commandId - 2688]) Pre-Fader Level (L)"
        }
        if commandId >= 2692 && commandId <= 2695 {
            let decks = ["A", "B", "C", "D"]
            return "Deck \(decks[commandId - 2692]) Pre-Fader Level (R)"
        }
        if commandId >= 2696 && commandId <= 2699 {
            let decks = ["A", "B", "C", "D"]
            return "Deck \(decks[commandId - 2696]) Post-Fader Level (L)"
        }
        if commandId >= 2700 && commandId <= 2703 {
            let decks = ["A", "B", "C", "D"]
            return "Deck \(decks[commandId - 2700]) Post-Fader Level (R)"
        }

        // Unknown command
        return "Command #\(commandId)"
    }

    /// Static lookup table for known command IDs
    private static let commandLookup: [Int: String] = [
        // ===========================================
        // MIXER
        // ===========================================
        5: "X-Fader Position",
        6: "Master Volume",
        7: "Limiter On",
        8: "Monitor Volume",
        9: "Deck Focus Selector",
        14: "Crossfader Curve",
        17: "Monitor Mix",
        19: "Tempo Range Selector",
        29: "Audio Recorder Gain",
        60: "Auto Master Mode",
        62: "Clock Int/Ext",
        64: "Set Master Tempo",
        69: "Master Tempo Selector",

        // ===========================================
        // DECK COMMON - Transport
        // ===========================================
        100: "Play/Pause",
        101: "Play",
        102: "Volume",
        103: "Seek Position",
        104: "Scratch",
        117: "Mixer Gain",
        118: "Auto-Gain",
        119: "Monitor Cue On",
        120: "Jog Turn",
        121: "Jog Scratch",
        122: "Tempo Sync",
        123: "Tempo Adjust",
        124: "Phase Sync",
        125: "Sync On",
        126: "Beat Sync",
        127: "Balance",

        // ===========================================
        // CUE / LOOP
        // ===========================================
        200: "Loop In",
        201: "Loop Out",
        202: "Loop Active On",
        203: "Reloop",
        204: "CUP (Cue Play)",
        205: "Cup (Cue Play & Pause)",
        206: "Cue",
        207: "Cue/Play",
        208: "Cue/Pause",
        209: "Cue/Set+Store",
        210: "Preview Play/Pause",
        211: "Preview Seek Position",
        212: "Preview Load Selected",
        213: "Set Cue & Store as Next Hotcue",
        214: "Hotcue 1",
        215: "Hotcue 2",
        216: "Hotcue 3",
        217: "Hotcue 4",
        218: "Hotcue 5",
        219: "Hotcue 6",
        220: "Hotcue 7",
        221: "Hotcue 8",
        229: "Quantize Selector",
        230: "Quantize On (Remix)",

        // ===========================================
        // REMIX DECK
        // ===========================================
        233: "Load Set from List",
        234: "Save Remix Set",
        235: "Slot Punch On",
        236: "Slot Stop/Delete/Load",
        237: "Slot Keylock On",
        238: "Slot Monitor On",
        239: "Slot FX On",
        240: "Slot Reverse On",
        241: "Remix Deck Play",
        242: "Play Mode All Slots",
        243: "Stop All Slots",
        244: "Slot Load from List",
        245: "Slot Capture from Deck",
        246: "Slot Unload",
        247: "Slot State",
        248: "Slot Pitch Adjust",
        249: "Slot Filter Adjust",
        250: "Slot Filter On",
        251: "Slot Volume",
        252: "Slot Gain",
        253: "All Slots Volume",
        254: "Delete All Slots",
        255: "Play All Slots",
        256: "Trigger All Slots",
        257: "Slot Trigger",
        258: "Slot Retrigger Play",
        259: "Slot Mute On",
        260: "Slot Retrigger",
        261: "Slot BPM Sync",
        262: "Slot Color",
        263: "Slot Capture from Loop Recorder",
        264: "Slot Copy from Slot",
        265: "Slot Play Mode",
        266: "Slot Size x2",
        267: "Slot Size /2",
        268: "Slot Size Reset",
        269: "Slot Pitch Reset",

        // ===========================================
        // LOOP RECORDER
        // ===========================================
        280: "Loop Recorder Record",
        281: "Loop Recorder Size",
        282: "Loop Recorder Dry/Wet",
        283: "Loop Recorder Play/Pause",
        284: "Loop Recorder Delete",
        285: "Loop Recorder Overdub On",
        286: "Loop Recorder State",
        287: "Undo/Redo",

        // ===========================================
        // MICROPHONE
        // ===========================================
        295: "Microphone Gain",
        296: "Microphone On",

        // ===========================================
        // EQ
        // ===========================================
        301: "EQ Low",
        302: "EQ Mid",
        303: "EQ High",
        304: "EQ Low Kill",
        305: "EQ Mid Kill",
        306: "EQ High Kill",
        307: "EQ Mid-Low Kill",
        308: "EQ Low Reset",
        309: "EQ Mid Reset",
        310: "EQ High Reset",
        316: "EQ Mid-Low",

        // ===========================================
        // FILTER & FX
        // ===========================================
        319: "Filter On",
        320: "Filter",
        321: "FX Unit 1 On",
        322: "FX Unit 2 On",
        323: "Effect LFO Reset",
        324: "FX Single Mode",
        325: "FX Routing Selector",
        326: "FX Store Preset",
        327: "FX Snapshot",
        338: "FX Unit 3 On",
        339: "FX Unit 4 On",
        348: "Deck Effect On",
        349: "Mixer FX Selector",
        350: "Mixer FX On",
        351: "Mixer FX Adjust",
        362: "Effect 1 Selector",
        363: "Effect 2 Selector",
        364: "Effect 3 Selector",
        365: "FX Dry/Wet",
        366: "FX Knob 1",
        367: "FX Knob 2",
        368: "FX Knob 3",
        369: "FX Unit On",
        370: "FX Button 1",
        371: "FX Button 2",
        372: "FX Button 3",
        373: "FX Snapshot 1",
        374: "FX Snapshot 2",
        375: "FX Reset",

        // ===========================================
        // KEY & TEMPO
        // ===========================================
        400: "Keylock On",
        401: "Key Reset",
        402: "Key Adjust",
        403: "Key Match",
        404: "Tempo Bend (Stepless)",
        405: "Keylock On (Preserve Pitch)",
        406: "Tempo Bend",

        // ===========================================
        // REMIX DECK CELL MODIFIERS & STEP SEQUENCER
        // ===========================================
        729: "Cell Load Modifier",
        730: "Cell Delete Modifier",
        731: "Cell Reverse Modifier",
        732: "Cell Capture Modifier",
        733: "Sample Page Selector",
        734: "Step Sequencer On",
        735: "Step Sequencer Swing Amount",
        736: "Step Sequencer Pattern Length",
        737: "Step Sequencer Current Step",
        738: "Step Sequencer Selected Sound",
        739: "Step Sequencer Selected Pattern",

        // ===========================================
        // SLOT SIZE & CAPTURE
        // ===========================================
        2000: "Slot Size Adjust",
        2001: "Slot Size",
        2002: "Capture Source Selector",
        2003: "Slot Trigger Type",
        2004: "Slot Capture/Trigger/Mute",

        // ===========================================
        // AUDIO RECORDER
        // ===========================================
        2055: "Audio Recorder Cut",
        2056: "Audio Recorder Record/Stop",
        2057: "Broadcasting On",
        2058: "Audio Recorder State",

        // ===========================================
        // TRANSPORT & LOADING
        // ===========================================
        2113: "Auto X-Fade Left",
        2114: "Auto X-Fade Right",
        2176: "Load Next",
        2177: "Load Previous",
        2178: "Unload Deck",
        2179: "Unload Preview Player",
        2180: "Load Selected",
        2187: "Jog Touch On",
        2188: "Jog Mode",

        // ===========================================
        // LOOP
        // ===========================================
        2192: "Loop Set",
        2193: "Loop Size",
        2194: "Loop Size +1",
        2195: "Loop Size -1",
        2196: "Loop Size Selector",
        2197: "Loop Move Forward",
        2198: "Loop Move Backward",

        // ===========================================
        // GRID
        // ===========================================
        2237: "Autogrid",
        2238: "BPM Adjust",
        2239: "Grid Adjust",
        2240: "Beat Tap",
        2241: "BPM Lock On",
        2242: "Gridlock On",
        2248: "Set Grid Marker",
        2249: "Delete Grid Marker",
        2250: "Grid Marker Position",
        2251: "Beat Phase",
        2252: "Tick On",
        2253: "Move Grid Marker",
        2254: "Reset BPM",
        2255: "Copy Phase from Tempo Master",
        2256: "Detected BPM",
        2257: "Track BPM",
        2258: "BPM x2",
        2259: "BPM /2",

        // ===========================================
        // DECK CONTROL
        // ===========================================
        2288: "Scratch Control On",
        2289: "Timecode Tracking",
        2290: "Timecode Quality",
        2291: "Is Key Locked",
        2292: "Tempo",
        2293: "Set as Tempo Master",
        2294: "Is Tempo Master",
        2295: "Elapsed Time",
        2296: "Remaining Time",
        2297: "Next Cue Position",
        2298: "Advanced Panel Tab Selector",
        2299: "Advanced Panel Toggle",
        2300: "Deck Size Selector",
        2301: "FX Unit Mode Selector",
        2302: "Deck Flavor Selector",
        2303: "Deck Type",
        2304: "Track Length",
        2305: "Platter/Scope View Selector",
        2306: "Jump to Next/Prev Cue/Loop",
        2307: "Active Cue/Loop",
        2308: "Store Floating Cue/Loop as Next Hotcue",
        2309: "Delete Current Hotcue",
        2310: "Active Hotcue Index",
        2311: "Snap On",
        2312: "Quant On",
        2313: "Quant On (Global)",
        2314: "Hotcue Type",
        2315: "Map Hotcue",
        2316: "Loop Active",
        2317: "Loop Size Select+Set",
        2318: "Backward Loop Size Select+Set",
        2319: "Current Loop Size",
        2327: "Cue Type Selector",
        2328: "Select/Set+Store Hotcue",
        2329: "Hotcue State",
        2330: "Total Hotcues",
        2331: "Delete Hotcue",
        2350: "Flux Mode On",
        2351: "Move",
        2352: "Move Forward",
        2353: "Move Backward",
        2372: "Move Size Selector",
        2380: "Beatjump",
        2381: "Beatjump Forward",
        2382: "Beatjump Backward",
        2391: "Move Mode Selector",
        2392: "Loop In / Set Cue",
        2393: "Loop Out",
        2394: "Load",
        2395: "Load, Loop and Play",

        // ===========================================
        // ASSIGNMENT
        // ===========================================
        2408: "Assign Left",
        2409: "Assign Right",
        2410: "X-Fader Assign",

        // ===========================================
        // MASTER CLOCK
        // ===========================================
        2468: "Clock Send",
        2469: "Master Clock Beat Tap",
        2470: "Master Clock Tick On",
        2471: "Master Clock Tempo",
        2472: "Master Clock Phase",
        2473: "Clock Trigger MIDI Sync",
        2474: "Clock Receive",
        2475: "Clock Tempo Adjust",
        2476: "Tempo Bend Up",
        2477: "Tempo Bend Down",

        // ===========================================
        // DECK STATUS (Output)
        // ===========================================
        2588: "Toggle Last Focus",
        2589: "Is Playing",
        2590: "Is Synced",
        2591: "Deck Is Loaded",
        2592: "Track Title",
        2593: "Track Artist",
        2594: "Track Album",
        2595: "Track Genre",
        2596: "Track Comment",
        2597: "Track Key",
        2598: "Track Rating",

        // ===========================================
        // MIXER METERS (Output)
        // ===========================================
        2704: "Main Level (L)",
        2705: "Main Level (R)",
        2706: "Booth Level (L)",
        2707: "Booth Level (R)",
        2708: "Monitor Level (L)",
        2709: "Monitor Level (R)",
        2710: "Microphone Level",
        2711: "FX Unit 1 Level",
        2712: "FX Unit 2 Level",
        2713: "FX Unit 3 Level",
        2714: "FX Unit 4 Level",

        // ===========================================
        // GLOBAL
        // ===========================================
        2748: "Show Slider Values On",
        2798: "Analyze Loaded Track",
        2807: "Auto-Gain View On",
        2808: "Stripe View",
        2809: "Phase Meter View",
        2810: "Downbeat",
        2811: "Reset Downbeat",

        // ===========================================
        // SEND MONITOR STATE
        // ===========================================
        3048: "Send Monitor State",
        3072: "Save Traktor Settings",
        3076: "Load Selected (Timecode)",
        3077: "Check Consistency",
        3084: "Load Last Recording",
        3137: "Load Selected (Preview)",
        3138: "Preview Player State",
        3139: "Preview Player Position",
        3172: "Consolidate",

        // ===========================================
        // BROWSER LIST
        // ===========================================
        3200: "Browser Select Up/Down",
        3201: "Browser Select Page Up/Down",
        3202: "Browser Select Top/Bottom",
        3203: "Browser Select Extend Up/Down",
        3204: "Browser Select Extend Page Up/Down",
        3205: "Browser Select Extend Top/Bottom",
        3206: "Browser Select All",
        3207: "Browser Scroll",
        3208: "Browser Select",
        3209: "Browser Deselect All",
        3210: "Browser Open",
        3211: "Browser Delete",
        3212: "Browser Reset Played State",
        3213: "Browser Analyze",
        3214: "Save Collection",
        3215: "Browser Edit",
        3216: "Browser Relocate",
        3217: "Add as Track to Collection",
        3218: "Remove from Collection",
        3219: "Add to Playlist",
        3220: "Remove from Playlist",
        3221: "Browser Search",
        3222: "Browser Search Clear",
        3223: "Expand Remix Set",
        3224: "Browser Clear",
        3225: "Sort by Column",
        3231: "Browser Analysis Lock",
        3232: "Browser Analysis Unlock",
        3233: "Refresh Explorer Folder",

        // ===========================================
        // BROWSER TREE
        // ===========================================
        3328: "Browser Tree Select Up/Down",
        3329: "Browser Tree Expand/Collapse",
        3330: "Browser Tree Scroll",
        3336: "Browser Tree Delete",
        3337: "Browser Tree Reset Played State",
        3338: "Browser Tree Analyze",
        3339: "Browser Tree Edit",
        3340: "Browser Tree Relocate",
        3345: "Import Music Folders",
        3346: "Export",
        3347: "Export NML",
        3348: "Export Printable",
        3349: "Rename Playlist or Folder",
        3353: "Import Collection",
        3354: "Import Playlist",
        3357: "Search in Playlists",
        3358: "Show in Explorer",
        3366: "Jump to Current Track",
        3367: "Restore Auto Gain",
        3373: "Create Playlist",
        3374: "Delete Playlist",
        3375: "Create Playlist Folder",
        3376: "Delete Playlist Folder",

        // ===========================================
        // FAVORITES & PREPARATION
        // ===========================================
        3456: "Favorites Selector",
        3457: "Add Folder to Favorites",
        3458: "Add Folder to Music Folders",
        3459: "Remove from Favorites",
        3460: "Append to Preparation List",
        3461: "Add as Next to Preparation List",
        3462: "Clear Preparation List",
        3469: "Add as Loop to Collection",
        3470: "Add as One-Shot Sample to Collection",
        3471: "Remove Sample from Collection",
        3472: "Set to Track",
        3473: "Set to Looped Sample",
        3474: "Set to One-Shot Sample",
        3475: "Export as Remix Set",
        3476: "Preparation List Count",
        3477: "Browser Tree Analysis Lock",
        3478: "Browser Tree Analysis Unlock",
        3480: "Add/Remove from Preparation List",

        // ===========================================
        // VIEW & LAYOUT
        // ===========================================
        4162: "Waveform Zoom",
        4163: "DAW View",
        4208: "Layout Selector",
        4209: "Only Browser On",
        4210: "Fullscreen On",
        4211: "Tooltips On",
        4212: "Mixer View",
        4213: "Effect View",
        4214: "Master View",
        4215: "Deck View",
        4216: "Browser View",

        // ===========================================
        // TIMECODE
        // ===========================================
        5129: "Playback Mode Int/Rel/Abs",
        5144: "Calibrate",
        5154: "Reset Tempo Offset",
        5155: "Timecode Input",
        5156: "Timecode Input State",

        // ===========================================
        // CRUISE MODE
        // ===========================================
        8194: "Cruise Mode On",
        8195: "Cruise Mode Skip",
        8196: "Cruise Mode Shuffle",
    ]
}
