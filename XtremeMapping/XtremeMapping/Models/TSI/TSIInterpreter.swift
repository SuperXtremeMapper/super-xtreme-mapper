//
//  TSIInterpreter.swift
//  SuperXtremeMapping
//
//  Created by u/nonomomomo2 on 13/01/2026.
//

import Foundation
import os

/// CMAI MidiNoteBindingId values with special meaning, shared by
/// TSIWriter and TSIInterpreter.
enum TSIBindingID {
    /// "No MIDI assignment" sentinel — mirrors the −1 convention DCDT
    /// already uses for an unassigned ControlId (TSI-File-Format.md).
    /// A mapping carrying this ID gets no DCDT or DCBM entry.
    static let unassigned: UInt32 = 0xFFFF_FFFF
}

/// Errors thrown when parsed TSI frames don't form a coherent mapping document.
///
/// Surfacing these instead of returning partial results prevents a corrupt
/// file from silently opening as an empty/partial document that a later save
/// would then overwrite.
enum TSIInterpreterError: Error, Equatable, LocalizedError {
    /// The DEVS container is too small to hold its 4-byte device count.
    case malformedDevicesContainer
    /// The DEVS count prefix disagrees with the number of parsed DEVI frames.
    case deviceCountMismatch(declared: Int, parsed: Int)
    /// The CMAS frame is too small to hold its 4-byte mapping count, or its
    /// payload contains bytes that are not CMAI frames.
    case malformedMappingsList
    /// The CMAS count prefix disagrees with the number of parsed CMAI frames.
    case mappingCountMismatch(declared: Int, parsed: Int)
    /// A CMAI frame is truncated or its declared size overruns its container.
    case malformedMappingItem
    /// A CMAI's settings frame (CMAD) is missing, truncated, or its declared
    /// size disagrees with its CMAI container.
    case malformedMappingData
    /// A CMAI references a MIDI binding ID that is absent from the DCBM list.
    case danglingMidiBinding(bindingId: Int)
    /// A DEVI frame is too small to hold its device-name length prefix.
    case malformedDevice
    /// A device metadata frame (DDIV/DDIC/DDPT) is present but unreadable.
    case malformedDeviceMetadata(frame: String)
    /// The DCBM MIDI binding list (or one of its binding entries) is malformed.
    case malformedMidiBindingList
    /// The frame stream contains no DIOM root frame.
    case missingDeviceIOMappings
    /// The DIOM frame contains no DEVS devices container.
    case missingDevicesContainer
    /// A DEVI frame contains no CMAS mappings list. The writer (and Traktor)
    /// always emit one, even when empty — absence means the device's mappings
    /// were lost to corruption, and opening it as "zero mappings" would let
    /// the next save wipe them for good.
    case missingMappingsList
    /// Bytes remained after the last declared frame in a container — the
    /// writer emits no padding anywhere, so trailing bytes are corruption
    /// that a save would silently drop.
    case unexpectedTrailingBytes(context: String)
    /// A DCBM MIDI control name is not in a recognized "ChXX.CC.NNN" /
    /// "ChXX.Note.XN" form. Defaulting it would strip the user's MIDI
    /// assignment on the next save. TSI-File-Format.md defines exactly these
    /// two forms, so anything else is corruption rather than a foreign
    /// variant. (Unknown ENUM values inside CMAD are tolerated and coerced —
    /// real Traktor writes values this app doesn't model — but a binding
    /// NAME that doesn't parse can't be preserved through the MIDI fields.)
    case unrecognizedMidiControl(name: String)
    /// The CMAI MappingType field carries a value other than 0 (In) or
    /// 1 (Out). Unlike CMAD enums, the spec is exhaustive here — Traktor
    /// never writes anything else, and coercing the direction would flip
    /// the mapping on the next save.
    case unsupportedFieldValue(field: String, value: Int)

    var errorDescription: String? {
        switch self {
        case .malformedDevicesContainer:
            return "The TSI device list (DEVS) is malformed — the file is corrupt."
        case .deviceCountMismatch(let declared, let parsed):
            return "The TSI file declares \(declared) device(s) but \(parsed) could be parsed — the file is corrupt."
        case .malformedMappingsList:
            return "A device's mappings list (CMAS) is malformed — the file is corrupt."
        case .mappingCountMismatch(let declared, let parsed):
            return "A device declares \(declared) mapping(s) but \(parsed) could be parsed — the file is corrupt."
        case .malformedMappingItem:
            return "A mapping entry (CMAI) is truncated — the file is corrupt."
        case .malformedMappingData:
            return "A mapping's settings block (CMAD) is missing or truncated — the file is corrupt."
        case .danglingMidiBinding(let bindingId):
            return "A mapping references MIDI binding #\(bindingId), which does not exist in the file — the file is corrupt."
        case .malformedDevice:
            return "A device entry (DEVI) is truncated — the file is corrupt."
        case .malformedDeviceMetadata(let frame):
            return "A device metadata frame (\(frame)) is truncated — the file is corrupt."
        case .malformedMidiBindingList:
            return "The MIDI binding list (DCBM) is malformed — the file is corrupt."
        case .missingDeviceIOMappings:
            return "The TSI controller data has no DIOM root frame — the file is corrupt."
        case .missingDevicesContainer:
            return "The TSI controller data has no device list (DEVS) — the file is corrupt."
        case .missingMappingsList:
            return "A device has no mappings list (CMAS) — the file is corrupt."
        case .unexpectedTrailingBytes(let context):
            return "Stray bytes after the last frame in \(context) — the file is corrupt."
        case .unrecognizedMidiControl(let name):
            return "The MIDI control \"\(name)\" is not in a recognized format — the file is corrupt or uses an unsupported MIDI control type."
        case .unsupportedFieldValue(let field, let value):
            return "A mapping's \(field) value (\(value)) is outside the documented TSI range — the file is corrupt or unsupported."
        }
    }
}

/// Interprets parsed TSI frames into the app's data model.
///
/// TSI binary format structure:
/// ```
/// DIOM (Device IO Mappings)
/// ├── DIOI (Header/version)
/// └── DEVS (Devices container, 4-byte count prefix)
///     └── DEVI (Device) × N
///         ├── Device name (UTF-16BE string)
///         └── DDAT (Device Data)
///             ├── DDIF (Device info flags)
///             ├── DDIV (Version + MappingFileRevision)
///             ├── DDIC (Device comment)
///             ├── DDPT (In/out ports)
///             ├── DDDC (MIDI Definitions Container)
///             │   └── DDCI (Control Index, 4-byte count prefix)
///             │       └── DCDT × N (MIDI control definitions)
///             └── DDCB (Command Bindings)
///                 ├── CMAS (Mappings list, 4-byte count prefix)
///                 │   └── CMAI × N (Individual mappings)
///                 │       └── CMAD (Mapping data)
///                 └── DCBM (MIDI note binding list, 4-byte count prefix)
///                     └── DCBM × N (binding id → MIDI note string)
/// ```
struct TSIInterpreter {

    private static let logger = Logger(subsystem: "com.sxm.app", category: "TSIInterpreter")

    // MARK: - Frame Identifiers

    private enum FrameID {
        static let deviceIOMappings = "DIOM"
        static let header = "DIOI"
        static let devicesContainer = "DEVS"
        static let device = "DEVI"
        static let deviceData = "DDAT"
        static let deviceVersion = "DDIV"
        static let deviceComment = "DDIC"
        static let devicePorts = "DDPT"
        static let midiDefinitionsContainer = "DDDC"
        static let commandBindings = "DDCB"
        static let mappingsList = "CMAS"
        static let mappingItem = "CMAI"
        static let mappingData = "CMAD"
        static let bindingList = "DCBM"
    }

    private static func isRemixSlotCommand(_ commandId: Int) -> Bool {
        [239, 249, 250, 251, 259].contains(commandId)
    }

    // MARK: - Public API

    /// Interprets TSI frames into a MappingFile.
    ///
    /// The frame stream must contain a DIOM root with a DEVS container —
    /// a stream without them would open as an empty document that the next
    /// save then writes over the user's real file, so both are required.
    ///
    /// Frame identifiers this app doesn't model are TOLERATED (skipped) when
    /// the frame itself is structurally wellformed — real Traktor writes
    /// frame types beyond what this app reads, and rejecting the whole file
    /// is worse than the documented limitation that unknown frames don't
    /// survive a save. Structural corruption (truncated frames, trailing
    /// bytes) still throws: wellformedness is the gate, not the identifier.
    static func interpret(frames: [TSIFrame]) throws -> MappingFile {
        var devices: [Device] = []
        var foundDIOM = false
        var foundDEVS = false

        for frame in frames {
            guard frame.identifier == FrameID.deviceIOMappings else {
                continue // unknown-but-wellformed top-level frame — tolerated
            }
            foundDIOM = true
            let diomFrames = try parseNestedFrames(from: frame.data, context: "DIOM")

            for nested in diomFrames {
                switch nested.identifier {
                case FrameID.header:
                    continue // DIOI version header — no mapping content
                case FrameID.devicesContainer:
                    foundDEVS = true
                    // DEVS has 4-byte count prefix
                    guard nested.data.count >= 4 else {
                        throw TSIInterpreterError.malformedDevicesContainer
                    }
                    let declaredCount = Int(readUInt32BE(from: nested.data, at: 0))
                    let dataAfterCount = nested.data.subdata(in: 4..<nested.data.count)
                    let devsFrames = try parseNestedFrames(from: dataAfterCount, context: "DEVS")

                    var parsedCount = 0
                    for devsNested in devsFrames {
                        // Unknown-but-wellformed frames inside DEVS are
                        // skipped (and don't count toward the device count,
                        // which declares DEVI frames only).
                        guard devsNested.identifier == FrameID.device else {
                            continue
                        }
                        let device = try parseDevice(from: devsNested.data)
                        devices.append(device)
                        parsedCount += 1
                    }

                    // A zero-device file (declared 0, parsed 0) is valid;
                    // any disagreement means frames were lost to corruption.
                    guard parsedCount == declaredCount else {
                        throw TSIInterpreterError.deviceCountMismatch(
                            declared: declaredCount, parsed: parsedCount)
                    }
                default:
                    continue // unknown-but-wellformed frame inside DIOM — tolerated
                }
            }
        }

        guard foundDIOM else { throw TSIInterpreterError.missingDeviceIOMappings }
        guard foundDEVS else { throw TSIInterpreterError.missingDevicesContainer }

        return MappingFile(devices: devices)
    }

    // MARK: - Device Parsing

    private static func parseDevice(from data: Data) throws -> Device {
        // Parse device name (UTF-16BE string with 4-byte length prefix).
        // A DEVI too small (or too garbled) to hold its own name is corruption —
        // throw instead of fabricating a placeholder device.
        guard let (deviceName, nameEnd) = readUTF16BEString(from: data, at: 0) else {
            throw TSIInterpreterError.malformedDevice
        }

        // WALK the declared child-frame stream after the name (no byte-scan):
        // every frame header is read, every declared size must tile its
        // container exactly, and unknown frames are skipped WITHOUT scanning
        // their payload. The old marker scan had two failure modes the walk
        // closes: a wrapper (DDAT/DDCB) with a corrupt declared size was
        // bypassed because the scan found the inner bytes anyway, and an
        // unknown frame whose payload coincidentally embedded "CMAS"/"DCBM"
        // bytes misparsed.
        let children = try collectDeviceFrames(
            from: data.subdata(in: nameEnd..<data.count), context: "DEVI")

        // Parse device metadata frames (DDIV version/revision, DDIC comment, DDPT ports).
        // ABSENCE of a metadata frame keeps the writer-compatible default —
        // foreign TSI variants may omit them, and nothing is lost on save.
        // PRESENCE with an unreadable payload is corruption and throws:
        // defaulting would silently rewrite the user's metadata on save.
        // Every read is BOUNDED to the frame's declared payload (TSIFrame.parse
        // cuts it) — an under-declared frame must not silently borrow bytes
        // from the frame that follows it.
        var tsiVersion = "3.11.0"
        var mappingFileRevision = 2
        var comment = ""
        var inPort = ""
        var outPort = ""

        if let ddivData = children.deviceVersion {
            guard let (version, afterVersion) = readUTF16BEString(from: ddivData, at: 0),
                  // MappingFileRevision is required per TSI-File-Format.md —
                  // a DDIV whose payload ends after the version string is
                  // truncated (or under-declared).
                  afterVersion + 4 <= ddivData.count else {
                throw TSIInterpreterError.malformedDeviceMetadata(frame: "DDIV")
            }
            tsiVersion = version
            mappingFileRevision = Int(readUInt32BE(from: ddivData, at: afterVersion))
        }

        if let ddicData = children.deviceComment {
            guard let (parsedComment, _) = readUTF16BEString(from: ddicData, at: 0) else {
                throw TSIInterpreterError.malformedDeviceMetadata(frame: "DDIC")
            }
            comment = parsedComment
        }

        if let ddptData = children.devicePorts {
            guard let (parsedInPort, afterInPort) = readUTF16BEString(from: ddptData, at: 0),
                  let (parsedOutPort, _) = readUTF16BEString(from: ddptData, at: afterInPort) else {
                throw TSIInterpreterError.malformedDeviceMetadata(frame: "DDPT")
            }
            inPort = parsedInPort
            outPort = parsedOutPort
        }

        // Build DCBM binding lookup (binding ID -> MIDI control name)
        let controlLookup = try buildControlLookup(fromBindingList: children.bindingList)

        // Parse CMAS (mappings list). TSIWriter and Traktor ALWAYS emit one
        // (count 0 when empty), so absence means the mappings were lost to
        // corruption — opening as "zero mappings" would let the next save
        // wipe them. (Contrast: a missing DCBM is tolerated because any CMAI
        // that actually needs a binding then throws danglingMidiBinding.)
        guard let cmasData = children.mappingsList else {
            throw TSIInterpreterError.missingMappingsList
        }
        let mappings = try parseMappings(fromMappingsList: cmasData, controlLookup: controlLookup)

        print("TSI: Device '\(deviceName)' with \(mappings.count) mappings")

        return Device(
            name: deviceName,
            comment: comment,
            inPort: inPort,
            outPort: outPort,
            tsiVersion: tsiVersion,
            mappingFileRevision: mappingFileRevision,
            mappings: mappings
        )
    }

    // MARK: - Device Child-Frame Walk

    /// The frames this app models, collected from a DEVI's child-frame tree.
    /// Each payload is already cut to its frame's DECLARED size by
    /// TSIFrame.parse, so readers can never borrow bytes from a following
    /// frame.
    private struct DeviceFrames {
        var deviceVersion: Data?   // DDIV
        var deviceComment: Data?   // DDIC
        var devicePorts: Data?     // DDPT
        var mappingsList: Data?    // CMAS
        var bindingList: Data?     // DCBM (outer list frame)
    }

    /// Walks a DEVI child-frame stream, recursing into the containers
    /// TSIWriter nests (DDAT → metadata frames + DDDC + DDCB, DDDC → DDCI,
    /// DDCB → CMAS + DCBM) and collecting the first occurrence of each
    /// modeled frame. Modeled frames are dispatched wherever they appear in
    /// the walked tree — foreign TSI variants (and this app's test fixtures)
    /// may flatten the writer's nesting, and nothing is lost by accepting
    /// that. Unknown-but-wellformed frames (including modeled-but-unread
    /// ones like DDIF and DDCI) are skipped whole; their payloads are never
    /// scanned. Structural mismatch — a declared size overrunning its
    /// container, a truncated header, trailing bytes — throws from the walk.
    private static func collectDeviceFrames(from data: Data, context: String) throws -> DeviceFrames {
        var collected = DeviceFrames()
        try collectDeviceFrames(into: &collected, from: data, context: context)
        return collected
    }

    private static func collectDeviceFrames(into collected: inout DeviceFrames, from data: Data, context: String) throws {
        for frame in try parseNestedFrames(from: data, context: context) {
            switch frame.identifier {
            case FrameID.deviceData, FrameID.midiDefinitionsContainer, FrameID.commandBindings:
                try collectDeviceFrames(into: &collected, from: frame.data, context: frame.identifier)
            case FrameID.deviceVersion:
                if collected.deviceVersion == nil { collected.deviceVersion = frame.data }
            case FrameID.deviceComment:
                if collected.deviceComment == nil { collected.deviceComment = frame.data }
            case FrameID.devicePorts:
                if collected.devicePorts == nil { collected.devicePorts = frame.data }
            case FrameID.mappingsList:
                if collected.mappingsList == nil { collected.mappingsList = frame.data }
            case FrameID.bindingList:
                if collected.bindingList == nil { collected.bindingList = frame.data }
            default:
                continue // unknown-but-wellformed frame — tolerated, payload unscanned
            }
        }
    }

    // MARK: - MIDI Note Binding Lookup (DCBM)

    /// Builds the binding lookup from the DCBM list: binding ID -> MIDI control name.
    ///
    /// DCBM layout per TSI-File-Format.md (mirrored by TSIWriter.buildDCBM):
    /// - Outer DCBM frame: 4-byte binding count, then `count` nested DCBM frames.
    /// - Each nested DCBM frame: BindingId (uint32) + MidiNote (wide string,
    ///   e.g. "Ch01.CC.100" or "Ch09.Note.A#2").
    ///
    /// The DCBM list is the SOLE authority for CMAI binding-id resolution —
    /// there is deliberately no DCDT fallback. DCDT rows define controls (and
    /// since the direction-aware writer pass there is one row per
    /// (control, direction) pair), so their order does not match binding ids;
    /// resolving through them silently rebinds mappings.
    ///
    /// Structural corruption throws: a binding entry that can't be read is not
    /// skippable — the CMAI that references it would then surface as a
    /// dangling binding anyway, so fail at the source with the precise error.
    private static func buildControlLookup(fromBindingList listData: Data?) throws -> [Int: String] {
        // A device with no DCBM list has no MIDI bindings — valid (every CMAI
        // must then carry the unassigned sentinel or fail as dangling).
        guard let listData else { return [:] }

        // The list payload must at least hold its 4-byte count prefix.
        guard listData.count >= 4 else {
            throw TSIInterpreterError.malformedMidiBindingList
        }
        let declaredCount = Int(readUInt32BE(from: listData, at: 0))

        var lookup: [Int: String] = [:]
        var offset = 4
        for _ in 0..<declaredCount {
            // Nested binding frame header: "DCBM" identifier + 4-byte size
            guard offset + 8 <= listData.count,
                  String(data: listData.subdata(in: offset..<(offset + 4)), encoding: .ascii) == FrameID.bindingList else {
                throw TSIInterpreterError.malformedMidiBindingList
            }
            let entrySize = Int(readUInt32BE(from: listData, at: offset + 4))
            // Entry payload must hold BindingId (4) + string length prefix (4)
            guard entrySize >= 8, offset + 8 + entrySize <= listData.count else {
                throw TSIInterpreterError.malformedMidiBindingList
            }

            let entryData = listData.subdata(in: (offset + 8)..<(offset + 8 + entrySize))
            let bindingId = Int(readUInt32BE(from: entryData, at: 0))
            guard let (midiNote, _) = readUTF16BEString(from: entryData, at: 4) else {
                throw TSIInterpreterError.malformedMidiBindingList
            }
            // Duplicate BindingIds are corruption, not a merge: last-wins
            // overwrite would silently rebind every CMAI referencing the id,
            // and the next save would persist the wrong MIDI control.
            guard lookup.updateValue(midiNote, forKey: bindingId) == nil else {
                throw TSIInterpreterError.malformedMidiBindingList
            }
            offset += 8 + entrySize
        }

        // The declared count must consume the ENTIRE list payload — a low
        // count with binding bytes left over means the count (or the list)
        // is corrupt, and the leftover bindings would vanish on save.
        guard offset == listData.count else {
            throw TSIInterpreterError.malformedMidiBindingList
        }

        return lookup
    }

    // MARK: - Mapping Parsing

    private static func parseMappings(fromMappingsList cmasData: Data, controlLookup: [Int: String]) throws -> [MappingEntry] {
        var mappings: [MappingEntry] = []

        // CMAS must at least hold its 4-byte mapping count
        guard cmasData.count >= 4 else {
            throw TSIInterpreterError.malformedMappingsList
        }
        let declaredCount = Int(readUInt32BE(from: cmasData, at: 0))

        // Parse the CMAI frames within CMAS (after the 4-byte count prefix).
        // The payload is a CONTIGUOUS run of CMAI frames — per the format doc
        // and TSIWriter, nothing else lives here. Anything that isn't a CMAI
        // header at the expected offset (including trailing garbage after the
        // last frame) is corruption: a byte-scan that skips over it would
        // silently drop those bytes on the next save.
        // Every frame counts toward the declared total — including rows that
        // parseCMAI deliberately skips (command ID 0) — so corruption that
        // sheds frames is caught by the count check below.
        var parsedFrameCount = 0
        var offset = 4
        while offset < cmasData.count {
            guard cmasData.count - offset >= 8,
                  String(data: cmasData.subdata(in: offset..<(offset + 4)), encoding: .ascii) == FrameID.mappingItem else {
                throw TSIInterpreterError.malformedMappingsList
            }

            let cmaiSize = Int(readUInt32BE(from: cmasData, at: offset + 4))

            // A CMAI whose declared size overruns its container is truncation —
            // propagate instead of skipping and returning a partial list.
            // (A too-small payload throws inside parseCMAI.)
            guard offset + 8 + cmaiSize <= cmasData.count else {
                throw TSIInterpreterError.malformedMappingItem
            }

            let cmaiData = cmasData.subdata(in: (offset + 8)..<(offset + 8 + cmaiSize))
            parsedFrameCount += 1

            if let mapping = try parseCMAI(from: cmaiData, controlLookup: controlLookup) {
                mappings.append(mapping)
            }

            offset += 8 + cmaiSize
        }

        guard parsedFrameCount == declaredCount else {
            throw TSIInterpreterError.mappingCountMismatch(
                declared: declaredCount, parsed: parsedFrameCount)
        }

        return mappings
    }

    /// Parse CMAI (Controller Mapping Assignment Item)
    /// Per TSI spec (github.com/ivanz/TraktorMappingFileFormat):
    /// - MidiNoteBindingId: int (references DCBM binding)
    /// - Type: int (0=Input, 1=Output)
    /// - TraktorControlId: int (Traktor command identifier)
    /// - Settings: CMAD frame
    private static func parseCMAI(from data: Data, controlLookup: [Int: String]) throws -> MappingEntry? {
        // Too small to hold the 3-int header + CMAD frame header — truncation, not a skip.
        guard data.count >= 20 else { throw TSIInterpreterError.malformedMappingItem }

        // Parse CMAI header (3 x 4-byte integers before CMAD)
        let midiBindingId = Int(readUInt32BE(from: data, at: 0))
        let ioTypeValue = readUInt32BE(from: data, at: 4)
        let traktorControlId = Int(readUInt32BE(from: data, at: 8))

        // Type per spec: 0 = In, 1 = Out. Anything else is corruption —
        // coercing it to .input would rewrite the mapping direction on save.
        let ioType: IODirection
        switch ioTypeValue {
        case 0: ioType = .input
        case 1: ioType = .output
        default:
            throw TSIInterpreterError.unsupportedFieldValue(
                field: "MappingType", value: Int(ioTypeValue))
        }

        // CMAD must sit immediately after the 12-byte CMAI header (per the
        // format doc and TSIWriter) and fill the CMAI payload EXACTLY.
        // A missing, undersized, or overrunning CMAD used to fall through to
        // a default-settings mapping — which an open+save would then write
        // over the user's real settings. Any disagreement throws instead.
        guard String(data: data.subdata(in: 12..<16), encoding: .ascii) == FrameID.mappingData else {
            throw TSIInterpreterError.malformedMappingData
        }
        let cmadSize = Int(readUInt32BE(from: data, at: 16))
        guard 20 + cmadSize == data.count else {
            throw TSIInterpreterError.malformedMappingData
        }
        let cmadSettings = try parseCMAD(from: data.subdata(in: 20..<(20 + cmadSize)))

        // Skip unassigned/empty mappings (command ID 0 means no command
        // assigned — a placeholder row, not corruption; its CMAD was still
        // structurally validated above). TSIWriter never writes such rows.
        guard traktorControlId > 0 else { return nil }

        // Resolve the MIDI control name from the DCBM lookup:
        // - the 0xFFFFFFFF sentinel means "deliberately unassigned" (nil name)
        // - any OTHER id missing from the lookup is corruption and must throw —
        //   silently treating it as unassigned would erase the user's MIDI
        //   assignment and save over it.
        let midiControlName: String?
        if UInt32(truncatingIfNeeded: midiBindingId) == TSIBindingID.unassigned {
            midiControlName = nil
        } else if let resolved = controlLookup[midiBindingId] {
            midiControlName = resolved
        } else {
            throw TSIInterpreterError.danglingMidiBinding(bindingId: midiBindingId)
        }

        // Map interaction mode per spec: Trigger=0, Toggle=1, Hold=2, Direct=3,
        // Relative=4, Increment=5, Decrement=6, Reset=7, Output=8.
        // Unknown values are TOLERATED and coerced to the direction's default
        // (hold for input, output for output) — real Traktor writes modes
        // this app doesn't model, and rejecting the file is worse than the
        // documented limitation that the coerced mode is what gets saved.
        let interactionMode: InteractionMode
        switch cmadSettings.interactionMode {
        case 0: interactionMode = .trigger
        case 1: interactionMode = .toggle
        case 2: interactionMode = .hold
        case 3: interactionMode = .direct
        case 4: interactionMode = .relative
        case 5: interactionMode = .increment
        case 6: interactionMode = .decrement
        case 7: interactionMode = .reset
        case 8: interactionMode = .output
        default: interactionMode = ioType == .output ? .output : .hold
        }

        // Map controller type per spec: Button=0, Fader=1, Encoder=2, LED=65535.
        // Unknown values coerce to .button — same tolerance rationale as
        // interaction mode above.
        let controllerType: ControllerType
        switch cmadSettings.controllerType {
        case 0: controllerType = .button
        case 1: controllerType = .faderOrKnob
        case 2: controllerType = .encoder
        case 65535: controllerType = .led
        default: controllerType = .button
        }

        // Parse one validated MIDI assignment from the bound control name.
        let midiAssignment: MIDIAssignment
        if let midiControlName {
            midiAssignment = try parseMidiControlName(midiControlName)
        } else {
            midiAssignment = try MIDIAssignment.unassigned(channel: 1)
        }

        // Map target assignment per TSI encoding. Remix-slot commands overload
        // the 0...15 target range as deckIndex * 4 + slotIndex; other commands
        // use the standard deck/FX mapping.
        // Values outside -1...15 collapse to .global by prior design — the
        // same tolerance as the other CMAD enums above.
        let assignment: TargetAssignment
        if Self.isRemixSlotCommand(traktorControlId), (0...15).contains(cmadSettings.targetDeck) {
            assignment = TargetAssignment.remixSlotAssignment(forTargetValue: cmadSettings.targetDeck)
        } else {
            switch cmadSettings.targetDeck {
            case -1: assignment = .deviceTarget
            case 0: assignment = .deckA
            case 1: assignment = .deckB
            case 2: assignment = .deckC
            case 3: assignment = .deckD
            case 4: assignment = .fxUnit1
            case 5: assignment = .fxUnit2
            case 6: assignment = .fxUnit3
            case 7: assignment = .fxUnit4
            case 8: assignment = .remixSlot1
            case 9: assignment = .remixSlot2
            case 10: assignment = .remixSlot3
            case 11: assignment = .remixSlot4
            case 12: assignment = .remixSlot5
            case 13: assignment = .remixSlot6
            case 14: assignment = .remixSlot7
            case 15: assignment = .remixSlot8
            default: assignment = .global
            }
        }

        let setToValue: Float = traktorControlId == 2328
            ? Float(cmadSettings.setToValueRaw)
            : cmadSettings.setToValue

        // Build modifier conditions from parsed values
        let modifier1: ModifierCondition? = cmadSettings.modifierOneId > 0
            ? ModifierCondition(modifier: cmadSettings.modifierOneId, value: cmadSettings.modifierOneValue)
            : nil
        let modifier2: ModifierCondition? = cmadSettings.modifierTwoId > 0
            ? ModifierCondition(modifier: cmadSettings.modifierTwoId, value: cmadSettings.modifierTwoValue)
            : nil

        return MappingEntry(
            commandID: traktorControlId,
            ioType: ioType,
            assignment: assignment,
            interactionMode: interactionMode,
            midiAssignment: midiAssignment,
            modifier1Condition: modifier1,
            modifier2Condition: modifier2,
            comment: cmadSettings.comment,
            controllerType: controllerType,
            invert: cmadSettings.invert,
            softTakeover: cmadSettings.softTakeover,
            setToValue: setToValue,
            rotarySensitivity: cmadSettings.rotarySensitivity,
            rotaryAcceleration: cmadSettings.rotaryAcceleration,
            autoRepeat: cmadSettings.autoRepeat,
            ledMinRangeType: cmadSettings.ledMinRangeType,
            ledMinRangeData: cmadSettings.ledMinRangeData,
            ledMaxRangeType: cmadSettings.ledMaxRangeType,
            ledMaxRangeData: cmadSettings.ledMaxRangeData,
            ledMinMidi: cmadSettings.ledMinMidi,
            ledMaxMidi: cmadSettings.ledMaxMidi,
            ledInvert: cmadSettings.ledInvert,
            ledBlend: cmadSettings.ledBlend,
            resolution: cmadSettings.resolution
        )
    }

    /// Parse CMAD (Controller Mapping Assignment Data)
    /// Per TSI spec (github.com/ivanz/TraktorMappingFileFormat):
    /// - Bytes 0-3: DeviceType (constant 4 = GenericMidi)
    /// - Bytes 4-7: ControllerType (Button=0, FaderOrKnob=1, Encoder=2, LED=65535)
    /// - Bytes 8-11: InteractionMode (Toggle=1, Hold=2, Direct=3, Relative=4, Output=8)
    /// - Bytes 12-15: Target (-1=Device, 0-3=Decks A-D, 4-7=FX Units;
    ///   remix-slot commands overload 0-15 as deckIndex * 4 + slotIndex)
    /// - Bytes 16-19: AutoRepeat
    /// - Bytes 20-23: Invert
    /// - Bytes 24-27: SoftTakeover
    /// - Bytes 28-31: RotarySensitivity (float)
    /// - Bytes 32-35: RotaryAcceleration (float)
    /// - Bytes 36-39: HasValueUI
    /// - Bytes 40-43: ValueUIType
    /// - Bytes 44-47: SetValueTo (float for most commands, raw index for hotcue 2328)
    /// - Bytes 48-51: CommentLength
    /// - Bytes 52+: Comment (variable length wchar_t[])
    /// - After comment, the 24-byte condition block:
    ///   ConditionOneId(4), ConditionOneTarget(4), ConditionOneValue(4),
    ///   ConditionTwoId(4), ConditionTwoTarget(4), ConditionTwoValue(4)
    /// - Then the LED block:
    ///   LedMinControllerRange type(4)+data(4), LedMaxControllerRange type(4)+data(4),
    ///   LedMinMidiRange(4), LedMaxMidiRange(4), LedInvert(4), LedBlend(4),
    ///   unknownValueUIType(4), Resolution(4), UseFactoryMap(4)
    private struct CMADParsed {
        var controllerType: Int = 0
        var interactionMode: Int = 0
        var targetDeck: Int = -1
        var autoRepeat: Bool = false
        var invert: Bool = false
        var softTakeover: Bool = false
        var rotarySensitivity: Float = 1.0
        var rotaryAcceleration: Float = 0.0
        var setToValueRaw: UInt32 = 0
        var setToValue: Float = 0.0
        var comment: String = ""
        var modifierOneId: Int = 0
        var modifierOneValue: Int = 0
        var modifierTwoId: Int = 0
        var modifierTwoValue: Int = 0
        // LED block defaults match the constants TSIWriter historically wrote
        var ledMinRangeType: Int = 0
        var ledMinRangeData: Int = 0
        var ledMaxRangeType: Int = 0
        var ledMaxRangeData: Int = 1
        var ledMinMidi: Int = 0
        var ledMaxMidi: Int = 127
        var ledInvert: Bool = false
        var ledBlend: Bool = false
        var resolution: Int = 0
    }

    /// Parses a CMAD payload, throwing on structural corruption.
    ///
    /// The 52-byte fixed header (DeviceType through CommentLength) and the
    /// full declared comment are REQUIRED — a payload too short for either
    /// is corruption, not a defaults case.
    ///
    /// The condition block and LED block are OPTIONAL TAIL fields: older
    /// Traktor versions emit shorter CMADs that end before them, so their
    /// length-guarded reads keep writer-compatible defaults when absent.
    private static func parseCMAD(from data: Data) throws -> CMADParsed {
        var result = CMADParsed()

        guard data.count >= 52 else { throw TSIInterpreterError.malformedMappingData }

        // DeviceType at bytes 0-3: 4 = GenericMidi (what this app writes);
        // 1-3 are real proprietary Traktor values (TSI-File-Format.md).
        // ALL device types are tolerated and read with the GenericMidi field
        // layout — proprietary-section fidelity is a pre-existing, documented
        // limitation, and rejecting the file would block every real Traktor
        // export that includes a proprietary section.

        // Controller type at bytes 4-7
        result.controllerType = Int(readUInt32BE(from: data, at: 4))

        // Interaction mode at bytes 8-11
        result.interactionMode = Int(readUInt32BE(from: data, at: 8))

        // Target deck at bytes 12-15 (signed, -1 = device target)
        let deckValue = Int32(bitPattern: readUInt32BE(from: data, at: 12))
        result.targetDeck = Int(deckValue)

        // AutoRepeat at bytes 16-19
        result.autoRepeat = readUInt32BE(from: data, at: 16) != 0

        // Invert at bytes 20-23
        result.invert = readUInt32BE(from: data, at: 20) != 0

        // SoftTakeover at bytes 24-27
        result.softTakeover = readUInt32BE(from: data, at: 24) != 0

        // RotarySensitivity at bytes 28-31 (float)
        result.rotarySensitivity = readFloatBE(from: data, at: 28)

        // RotaryAcceleration at bytes 32-35 (float)
        result.rotaryAcceleration = readFloatBE(from: data, at: 32)

        // SetValueTo at bytes 44-47 is overloaded: indexed hotcue (2328)
        // stores a raw UInt32 selector, while fader-like commands store a
        // float bit pattern. Preserve both interpretations; parseCMAI picks
        // the command-specific one after it has the raw TraktorControlId.
        result.setToValueRaw = readUInt32BE(from: data, at: 44)
        result.setToValue = readFloatBE(from: data, at: 44)

        // Comment: length at bytes 48-51, then wchar_t[] string.
        // The declared comment must fit inside the CMAD payload — that byte
        // bound is the real validator (no arbitrary length cap: the old
        // `< 1000` sanity cap silently DROPPED legitimate comments of 1000+
        // characters and misread the condition block at the wrong offset for
        // corrupt lengths). The payload size itself bounds the allocation.
        let commentLength = Int(readUInt32BE(from: data, at: 48))

        // The 24-byte condition block follows the comment (byte 52 when no comment)
        var conditionOffset = 52
        if commentLength > 0 {
            let commentStart = 52
            let commentEnd = commentStart + commentLength * 2
            guard commentEnd <= data.count else {
                throw TSIInterpreterError.malformedMappingData
            }

            result.comment = decodeUTF16BE(from: data, at: commentStart, codeUnitCount: commentLength)
            conditionOffset = commentEnd
        }

        // Condition block per spec (24 bytes):
        // ConditionOneId(4), ConditionOneTarget(4), ConditionOneValue(4),
        // ConditionTwoId(4), ConditionTwoTarget(4), ConditionTwoValue(4)
        // OPTIONAL TAIL (see doc comment): absent in older/shorter CMADs.
        if conditionOffset + 24 <= data.count {
            result.modifierOneId = Int(readUInt32BE(from: data, at: conditionOffset))
            // ConditionOneTarget at +4 is skipped (always 0 in our output)
            result.modifierOneValue = Int(readUInt32BE(from: data, at: conditionOffset + 8))
            result.modifierTwoId = Int(readUInt32BE(from: data, at: conditionOffset + 12))
            // ConditionTwoTarget at +16 is skipped
            result.modifierTwoValue = Int(readUInt32BE(from: data, at: conditionOffset + 20))
        }

        // LED block after the condition block:
        // LedMinControllerRange type+data, LedMaxControllerRange type+data,
        // LedMinMidiRange, LedMaxMidiRange, LedInvert, LedBlend,
        // unknownValueUIType (skipped), Resolution
        // OPTIONAL TAIL (see doc comment): absent in older/shorter CMADs.
        let ledOffset = conditionOffset + 24
        if ledOffset + 32 <= data.count {
            result.ledMinRangeType = Int(readUInt32BE(from: data, at: ledOffset))
            result.ledMinRangeData = Int(readUInt32BE(from: data, at: ledOffset + 4))
            result.ledMaxRangeType = Int(readUInt32BE(from: data, at: ledOffset + 8))
            result.ledMaxRangeData = Int(readUInt32BE(from: data, at: ledOffset + 12))
            result.ledMinMidi = Int(readUInt32BE(from: data, at: ledOffset + 16))
            result.ledMaxMidi = Int(readUInt32BE(from: data, at: ledOffset + 20))
            result.ledInvert = readUInt32BE(from: data, at: ledOffset + 24) != 0
            result.ledBlend = readUInt32BE(from: data, at: ledOffset + 28) != 0
        }
        if ledOffset + 40 <= data.count {
            // unknownValueUIType at +32 is skipped
            result.resolution = Int(readUInt32BE(from: data, at: ledOffset + 36))
        }

        return result
    }

    /// Reads a big-endian float from data at the given offset.
    /// The zero default is defensive only — every call site bounds-checks
    /// (and throws) before reading, so corrupt input cannot reach it.
    private static func readFloatBE(from data: Data, at offset: Int) -> Float {
        guard offset + 4 <= data.count else { return 0.0 }
        let bits = readUInt32BE(from: data, at: offset)
        return Float(bitPattern: bits)
    }

    // MARK: - MIDI Control Name Parsing

    /// Parses a MIDI control name like "Ch01.CC.100" or "Ch09.Note.A#2".
    ///
    /// Names come from the file's DCBM list. A name that doesn't parse used
    /// to fall back to (channel 1, no number) — which the next save would
    /// write out as an UNASSIGNED mapping, erasing the user's MIDI
    /// assignment. Unrecognized names now throw instead.
    private static func parseMidiControlName(_ name: String) throws -> MIDIAssignment {
        let components = name.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3,
              components[0].hasPrefix("Ch"),
              components[0].count == 4 else {
            throw TSIInterpreterError.unrecognizedMidiControl(name: name)
        }

        let channelText = components[0].dropFirst(2)
        guard channelText.allSatisfy(\.isNumber), let channel = Int(channelText) else {
            throw TSIInterpreterError.unrecognizedMidiControl(name: name)
        }

        do {
            switch components[1] {
            case "CC":
                let controlText = components[2]
                guard controlText.count == 3,
                      controlText.allSatisfy(\.isNumber),
                      let cc = Int(controlText) else {
                    throw TSIInterpreterError.unrecognizedMidiControl(name: name)
                }
                return try .controlChange(channel: channel, number: cc)
            case "Note":
                guard let note = midiNoteNumber(from: String(components[2])) else {
                    throw TSIInterpreterError.unrecognizedMidiControl(name: name)
                }
                return try .note(channel: channel, number: note)
            default:
                throw TSIInterpreterError.unrecognizedMidiControl(name: name)
            }
        } catch is MIDIAssignment.ValidationError {
            throw TSIInterpreterError.unrecognizedMidiControl(name: name)
        }
    }

    /// Converts a note name like "A#2" to MIDI note number
    private static func midiNoteNumber(from noteName: String) -> Int? {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        guard let first = noteName.first, ("A"..."G").contains(String(first)) else {
            return nil
        }
        let accidentalLength = noteName.dropFirst().first == "#" ? 1 : 0
        let noteLength = 1 + accidentalLength
        let note = String(noteName.prefix(noteLength))
        let octaveText = String(noteName.dropFirst(noteLength))
        guard !octaveText.isEmpty, let octave = Int(octaveText) else { return nil }
        guard let noteIndex = noteNames.firstIndex(of: note) else { return nil }

        // MIDI note: (octave + 1) * 12 + noteIndex
        // C-1 = 0, C0 = 12, C4 = 60
        let (shiftedOctave, shiftOverflowed) = octave.addingReportingOverflow(1)
        guard !shiftOverflowed else { return nil }
        let (octaveBase, multiplyOverflowed) = shiftedOctave.multipliedReportingOverflow(by: 12)
        guard !multiplyOverflowed else { return nil }
        let (midiNumber, noteOverflowed) = octaveBase.addingReportingOverflow(noteIndex)
        guard !noteOverflowed else { return nil }
        return midiNumber
    }

    // MARK: - Utility Functions

    /// Decodes UTF-16 big-endian code units into a String.
    ///
    /// Collects raw code units before decoding so surrogate pairs (non-BMP
    /// characters like emoji) survive — decoding code units one-by-one via
    /// `UnicodeScalar` silently drops them. Internal for direct unit testing.
    static func decodeUTF16BE(from data: Data, at offset: Int, codeUnitCount: Int) -> String {
        let end = offset + codeUnitCount * 2
        guard offset >= 0, codeUnitCount >= 0, end <= data.count else { return "" }

        var codeUnits: [UInt16] = []
        codeUnits.reserveCapacity(codeUnitCount)
        for i in stride(from: offset, to: end, by: 2) {
            let hi = UInt16(data[data.startIndex + i])
            let lo = UInt16(data[data.startIndex + i + 1])
            codeUnits.append((hi << 8) | lo)
        }
        return String(decoding: codeUnits, as: UTF16.self)
    }

    /// Reads a length-prefixed UTF-16BE string. Returns nil when the prefix
    /// or string bytes don't fit — every caller treats nil as corruption and
    /// throws (no caller silently defaults). The 10000-char cap is an
    /// allocation bound for absurd corrupt lengths; with throwing callers it
    /// surfaces as an error, never as silently truncated data.
    private static func readUTF16BEString(from data: Data, at offset: Int) -> (String, Int)? {
        guard offset + 4 <= data.count else { return nil }

        let lengthBytes = data.subdata(in: offset..<(offset + 4))
        let charCount = Int(lengthBytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

        guard charCount >= 0 && charCount < 10000 else { return nil }

        let byteCount = charCount * 2
        let stringEnd = offset + 4 + byteCount

        guard stringEnd <= data.count else { return nil }

        let decoded = decodeUTF16BE(from: data, at: offset + 4, codeUnitCount: charCount)
        return (decoded, stringEnd)
    }

    /// Reads a big-endian UInt32 from data at the given offset.
    /// The zero default is defensive only — every call site bounds-checks
    /// (and throws) before reading, so corrupt input cannot reach it.
    private static func readUInt32BE(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        let bytes = data.subdata(in: offset..<(offset + 4))
        return bytes.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }

    /// Parses consecutive frames, propagating any malformed-frame error.
    ///
    /// A truncated or oversized frame mid-stream must surface — swallowing it
    /// would silently return a partial frame list that a later save wipes.
    /// The frames must consume the payload EXACTLY: TSIWriter emits no
    /// padding anywhere, so 1-7 trailing bytes (which the old loop dropped
    /// on the floor, and a save then dropped from the file) are corruption.
    /// This mirrors the strict contract of TSIParser.parseFrames at the top
    /// level of the file.
    private static func parseNestedFrames(from data: Data, context: String) throws -> [TSIFrame] {
        var frames: [TSIFrame] = []
        var offset = 0

        while offset < data.count {
            guard data.count - offset >= TSIFrame.headerSize else {
                throw TSIInterpreterError.unexpectedTrailingBytes(context: context)
            }
            let remainingData = data.subdata(in: offset..<data.count)
            let frame = try TSIFrame.parse(from: remainingData)
            frames.append(frame)
            offset += frame.totalSize
        }

        return frames
    }
}
