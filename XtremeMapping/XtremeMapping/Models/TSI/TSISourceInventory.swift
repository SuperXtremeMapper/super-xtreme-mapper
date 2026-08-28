//
//  TSISourceInventory.swift
//  SuperXtremeMapping
//

import Foundation

/// Closed-world inventory of the source structures the canonical writer would replace.
///
/// The walk is iterative and descends only through known containers. Unknown
/// frame payloads are retained in the envelope but never guessed to be another
/// container. Structural validation remains the interpreter's responsibility;
/// this pass classifies every accepted source structure for write safety.
enum TSISourceInventory {
    private enum Context {
        case top
        case diom
        case devs
        case devi(device: Int)
        case ddat(device: Int)
        case dddc(device: Int)
        case ddcb(device: Int)
        case definitions(device: Int, direction: IODirection)
        case mappings(device: Int)
        case bindings(device: Int)
    }

    private struct WorkItem {
        let frames: [TSIFrame]
        let path: String
        let depth: Int
        let context: Context
    }

    private enum ValidationContext {
        case diom
        case devs
        case devi
        case ddat
        case dddc
        case ddcb
        case definitions
        case mappings
        case bindings
    }

    private struct ValidationWorkItem {
        let frames: [TSIFrame]
        let depth: Int
        let context: ValidationContext
    }

    private struct DefinitionRecord {
        let name: String
        let direction: IODirection
        let path: String
    }

    private struct BindingRecord {
        let id: UInt32
        let name: String
        let path: String
    }

    private struct MappingRecord {
        let bindingID: UInt32
        let direction: IODirection
        let commandID: UInt32
        let path: String
    }

    private struct DeviceInventory {
        var definitions: [DefinitionRecord] = []
        var bindings: [BindingRecord] = []
        var mappings: [MappingRecord] = []
    }

    static func risks(
        sourceBinary: Data,
        primaryFrames: [TSIFrame],
        mappingFile: MappingFile,
        xml: TSIXMLScanResult,
        limits: TSIParseLimits,
        instrumentation: TSIParseInstrumentation?
    ) throws -> [TSIPreservationRisk] {
        var risks: [TSIPreservationRisk] = []
        risks.reserveCapacity(16)

        for path in xml.nonControllerEntryPaths {
            risks.append(.init(code: .extraXMLEntry, path: path))
        }
        for path in xml.controllerEntryPaths.dropFirst() {
            risks.append(.init(code: .extraControllerEntry, path: path))
        }
        for path in xml.nonstandardStructurePaths {
            risks.append(.init(code: .nonstandardXMLStructure, path: path))
        }

        let budget = try TSIParseBudget(
            limits: limits,
            instrumentation: instrumentation,
            initialFrameCount: primaryFrames.count
        )
        try budget.enterContainer(atDepth: 0)

        var devices: [DeviceInventory] = []
        var stack = [WorkItem(frames: primaryFrames, path: "/binary", depth: 0, context: .top)]

        while let work = stack.popLast() {
            try budget.enterContainer(atDepth: work.depth)
            var occurrence: [String: Int] = [:]

            for frame in work.frames {
                let index = occurrence[frame.identifier, default: 0]
                occurrence[frame.identifier] = index + 1
                let path = "\(work.path)/\(frame.identifier)[\(index)]"

                switch work.context {
                case .top:
                    guard frame.identifier == "DIOM" else {
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    guard index == 0 else {
                        try validateKnownContainer(
                            frame.data, context: .diom, depth: work.depth + 1,
                            budget: budget, limits: limits
                        )
                        add(.duplicateSingletonFrame, path, detail: "DIOM", to: &risks)
                        continue
                    }
                    stack.append(try nestedWork(
                        frame.data, path: path, depth: work.depth + 1,
                        context: .diom, budget: budget
                    ))

                case .diom:
                    switch frame.identifier {
                    case "DIOI":
                        guard frame.data.count == 4 else {
                            throw TSIParserError.unexpectedEndOfData
                        }
                        if index > 0 {
                            add(.duplicateSingletonFrame, path, detail: "DIOI", to: &risks)
                        }
                        if readUInt32(frame.data, 0) != 1 {
                            add(.noncanonicalDIOI, path, to: &risks)
                        }
                    case "DEVS":
                        guard index == 0 else {
                            try validateKnownContainer(
                                frame.data, context: .devs, depth: work.depth + 1,
                                budget: budget, limits: limits
                            )
                            add(.duplicateSingletonFrame, path, detail: "DEVS", to: &risks)
                            continue
                        }
                        stack.append(try countedWork(
                            frame.data, path: path, depth: work.depth + 1,
                            context: .devs, expectedIdentifier: "DEVI", budget: budget
                        ))
                    default:
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                    }

                case .devs:
                    guard frame.identifier == "DEVI" else {
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    let deviceIndex = devices.count
                    devices.append(DeviceInventory())
                    let sourceName = try readWideString(frame.data, at: 0, limits: limits)
                    if sourceName.lossy {
                        add(.lossyString, "\(path)/Name", to: &risks)
                    }
                    if deviceIndex < mappingFile.devices.count,
                       sourceName.value != TSIWriter().canonicalDeviceName(for: mappingFile.devices[deviceIndex]) {
                        add(.unreproducibleDeviceIdentity, "\(path)/Name", to: &risks)
                    }
                    let children = try parseFrames(
                        frame.data, startingAt: sourceName.end, depth: work.depth + 1, budget: budget
                    )
                    stack.append(.init(
                        frames: children, path: path, depth: work.depth + 1,
                        context: .devi(device: deviceIndex)
                    ))

                case .devi(let device):
                    guard frame.identifier == "DDAT" else {
                        if isModeledFrame(frame.identifier) {
                            add(.noncanonicalFramePlacement, path, detail: frame.identifier, to: &risks)
                        } else {
                            add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        }
                        continue
                    }
                    guard index == 0 else {
                        try validateKnownContainer(
                            frame.data, context: .ddat, depth: work.depth + 1,
                            budget: budget, limits: limits
                        )
                        add(.duplicateSingletonFrame, path, detail: "DDAT", to: &risks)
                        continue
                    }
                    stack.append(try nestedWork(
                        frame.data, path: path, depth: work.depth + 1,
                        context: .ddat(device: device), budget: budget
                    ))

                case .ddat(let device):
                    switch frame.identifier {
                    case "DDIF":
                        guard frame.data.count == 4 else {
                            throw TSIParserError.unexpectedEndOfData
                        }
                        duplicateIfNeeded(index, id: "DDIF", path: path, risks: &risks)
                        if readUInt32(frame.data, 0) != 0 {
                            add(.noncanonicalDDIF, path, to: &risks)
                        }
                    case "DDIV":
                        duplicateIfNeeded(index, id: "DDIV", path: path, risks: &risks)
                        try classifyDDIV(frame.data, path: path, limits: limits, risks: &risks)
                    case "DDIC":
                        duplicateIfNeeded(index, id: "DDIC", path: path, risks: &risks)
                        try classifySingleString(frame.data, path: path, limits: limits, risks: &risks)
                    case "DDPT":
                        duplicateIfNeeded(index, id: "DDPT", path: path, risks: &risks)
                        try classifyPorts(
                            frame.data, device: device, path: path,
                            mappingFile: mappingFile, limits: limits, risks: &risks
                        )
                    case "DDDC":
                        guard index == 0 else {
                            try validateKnownContainer(
                                frame.data, context: .dddc, depth: work.depth + 1,
                                budget: budget, limits: limits
                            )
                            add(.duplicateSingletonFrame, path, detail: "DDDC", to: &risks)
                            continue
                        }
                        stack.append(try nestedWork(
                            frame.data, path: path, depth: work.depth + 1,
                            context: .dddc(device: device), budget: budget
                        ))
                    case "DDCB":
                        guard index == 0 else {
                            try validateKnownContainer(
                                frame.data, context: .ddcb, depth: work.depth + 1,
                                budget: budget, limits: limits
                            )
                            add(.duplicateSingletonFrame, path, detail: "DDCB", to: &risks)
                            continue
                        }
                        stack.append(try nestedWork(
                            frame.data, path: path, depth: work.depth + 1,
                            context: .ddcb(device: device), budget: budget
                        ))
                    case "DDCI" where frame.data.starts(with: Data("DCBM".utf8)):
                        // Controller-only Traktor 4.4.x exports flatten their
                        // input binding table into an uncounted DDCI stream.
                        // Import it losslessly, but keep edited overwrite
                        // conservative because the canonical writer nests a
                        // counted DCBM under DDCB instead.
                        add(
                            .noncanonicalFramePlacement,
                            path,
                            detail: "uncounted DCBM bindings in DDCI",
                            to: &risks
                        )
                        stack.append(try nestedWork(
                            frame.data, path: path, depth: work.depth + 1,
                            context: .bindings(device: device), budget: budget
                        ))
                    default:
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                    }

                case .dddc(let device):
                    let direction: IODirection
                    switch frame.identifier {
                    case "DDCI": direction = .input
                    case "DDCO": direction = .output
                    default:
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    guard index == 0 else {
                        try validateKnownContainer(
                            frame.data, context: .definitions, depth: work.depth + 1,
                            budget: budget, limits: limits
                        )
                        add(.duplicateSingletonFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    stack.append(try countedWork(
                        frame.data, path: path, depth: work.depth + 1,
                        context: .definitions(device: device, direction: direction),
                        expectedIdentifier: "DCDT", budget: budget
                    ))

                case .ddcb(let device):
                    switch frame.identifier {
                    case "CMAS":
                        guard index == 0 else {
                            try validateKnownContainer(
                                frame.data, context: .mappings, depth: work.depth + 1,
                                budget: budget, limits: limits
                            )
                            add(.duplicateSingletonFrame, path, detail: "CMAS", to: &risks)
                            continue
                        }
                        if frame.data.starts(with: Data("CMAI".utf8)) {
                            add(
                                .noncanonicalFramePlacement,
                                path,
                                detail: "uncounted CMAI mappings in CMAS",
                                to: &risks
                            )
                            stack.append(try nestedWork(
                                frame.data, path: path, depth: work.depth + 1,
                                context: .mappings(device: device), budget: budget
                            ))
                        } else {
                            stack.append(try countedWork(
                                frame.data, path: path, depth: work.depth + 1,
                                context: .mappings(device: device),
                                expectedIdentifier: "CMAI", budget: budget
                            ))
                        }
                    case "DCBM":
                        guard index == 0 else {
                            try validateKnownContainer(
                                frame.data, context: .bindings, depth: work.depth + 1,
                                budget: budget, limits: limits
                            )
                            add(.duplicateSingletonFrame, path, detail: "DCBM", to: &risks)
                            continue
                        }
                        stack.append(try countedWork(
                            frame.data, path: path, depth: work.depth + 1,
                            context: .bindings(device: device),
                            expectedIdentifier: "DCBM", budget: budget
                        ))
                    default:
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                    }

                case .definitions(let device, let direction):
                    guard frame.identifier == "DCDT" else {
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    let name = try readWideString(frame.data, at: 0, limits: limits)
                    if name.lossy { add(.lossyString, path, to: &risks) }
                    devices[device].definitions.append(.init(
                        name: name.value, direction: direction, path: path
                    ))

                case .mappings(let device):
                    guard frame.identifier == "CMAI", frame.data.count >= 20 else {
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    let bindingID = readUInt32(frame.data, 0)
                    let direction: IODirection = readUInt32(frame.data, 4) == 1 ? .output : .input
                    let commandID = readUInt32(frame.data, 8)
                    try budget.enterContainer(atDepth: work.depth + 1)
                    var cmaiChildCount = 0
                    try budget.consumeFrame(containerCount: &cmaiChildCount)
                    let cmadCursor = TSIFrameCursor(
                        data: frame.data, limits: limits, instrumentation: instrumentation
                    )
                    let parsed = try cmadCursor.parse(at: 12)
                    guard parsed.frame.identifier == "CMAD", parsed.nextOffset == frame.data.count else {
                        throw TSIInterpreterError.malformedMappingData
                    }
                    let cmadPath = "\(path)/CMAD[0]"
                    let semanticIndex: Int?
                    if commandID == 0 {
                        semanticIndex = nil
                        add(.commandZeroMapping, path, to: &risks)
                    } else {
                        semanticIndex = devices[device].mappings.reduce(into: 0) {
                            if $1.commandID > 0 { $0 += 1 }
                        }
                    }
                    try classifyCMAD(
                        parsed.frame.data, commandID: commandID, path: cmadPath,
                        device: device, semanticIndex: semanticIndex,
                        mappingFile: mappingFile, limits: limits, risks: &risks
                    )
                    devices[device].mappings.append(.init(
                        bindingID: bindingID, direction: direction, commandID: commandID,
                        path: path
                    ))

                case .bindings(let device):
                    guard frame.identifier == "DCBM", frame.data.count >= 8 else {
                        add(.unknownFrame, path, detail: frame.identifier, to: &risks)
                        continue
                    }
                    let name = try readWideString(frame.data, at: 4, limits: limits)
                    if name.lossy { add(.lossyString, path, to: &risks) }
                    devices[device].bindings.append(.init(
                        id: readUInt32(frame.data, 0), name: name.value, path: path
                    ))
                }
            }

            classifyCardinality(work, occurrence: occurrence, risks: &risks)
        }

        for device in devices {
            classifyReferences(device, risks: &risks)
        }

        // A structurally valid import must remain openable even when its
        // modeled projection cannot pass converted-writer validation. The
        // report's dry run owns that `unwritable` decision; byte comparison is
        // only the final closed-world guard when preserving output exists.
        if let preservingXML = try? TSIWriter().write(mappingFile),
           let preservingValue = try? TSIParser.extractControllerData(
               from: preservingXML, limits: limits
           ),
           let preservingBinary = try? TSIParser(limits: limits).decodeBase64(preservingValue),
           preservingBinary != sourceBinary,
           risks.isEmpty {
            add(.unclassifiedSourceData, "/binary", to: &risks)
        }

        return Array(Set(risks)).sorted {
            if $0.path != $1.path { return $0.path < $1.path }
            if $0.code.rawValue != $1.code.rawValue { return $0.code.rawValue < $1.code.rawValue }
            return $0.detail < $1.detail
        }
    }

    private static func classifyCardinality(
        _ work: WorkItem,
        occurrence: [String: Int],
        risks: inout [TSIPreservationRisk]
    ) {
        let required: [String]
        switch work.context {
        case .top: required = ["DIOM"]
        case .diom: required = ["DIOI", "DEVS"]
        case .devi: required = ["DDAT"]
        case .ddat: required = ["DDIF", "DDIV", "DDIC", "DDPT", "DDDC", "DDCB"]
        case .ddcb: required = ["CMAS", "DCBM"]
        default: required = []
        }
        for identifier in required where occurrence[identifier, default: 0] == 0 {
            add(.missingSingletonFrame, "\(work.path)/\(identifier)", detail: identifier, to: &risks)
        }
    }

    private static func classifyReferences(
        _ device: DeviceInventory,
        risks: inout [TSIPreservationRisk]
    ) {
        var firstBindingByID: [UInt32: BindingRecord] = [:]
        var firstBindingByName: [String: BindingRecord] = [:]
        for binding in device.bindings {
            if firstBindingByID[binding.id] != nil || firstBindingByName[binding.name] != nil {
                add(.duplicateMIDIBinding, binding.path, to: &risks)
            }
            if firstBindingByID[binding.id] == nil { firstBindingByID[binding.id] = binding }
            if firstBindingByName[binding.name] == nil { firstBindingByName[binding.name] = binding }
            if !isModeledMIDIName(binding.name) {
                add(.nativeMIDIControl, binding.path, detail: binding.name, to: &risks)
            }
        }

        let positiveMappings = device.mappings.filter { $0.commandID > 0 }
        let usedBindingIDs = Set(positiveMappings.map(\.bindingID).filter { $0 != TSIBindingID.unassigned })
        for binding in device.bindings where !usedBindingIDs.contains(binding.id) {
            add(.unusedMIDIBinding, binding.path, to: &risks)
        }

        var usedDefinitionKeys: Set<String> = []
        for mapping in positiveMappings where mapping.bindingID != TSIBindingID.unassigned {
            guard let binding = firstBindingByID[mapping.bindingID] else {
                add(.danglingMIDIBinding, mapping.path, detail: "\(mapping.bindingID)", to: &risks)
                continue
            }
            let key = definitionKey(binding.name, mapping.direction)
            usedDefinitionKeys.insert(key)
            if !device.definitions.contains(where: {
                definitionKey($0.name, $0.direction) == key
            }) {
                add(.missingMIDIDefinition, mapping.path, detail: binding.name, to: &risks)
            }
        }

        var seenDefinitions: Set<String> = []
        for definition in device.definitions {
            let key = definitionKey(definition.name, definition.direction)
            if !seenDefinitions.insert(key).inserted {
                add(.duplicateMIDIDefinition, definition.path, to: &risks)
            }
            if !usedDefinitionKeys.contains(key) {
                add(.unusedMIDIDefinition, definition.path, to: &risks)
            }
        }
    }

    private static func classifyCMAD(
        _ data: Data,
        commandID: UInt32,
        path: String,
        device: Int,
        semanticIndex: Int?,
        mappingFile: MappingFile,
        limits: TSIParseLimits,
        risks: inout [TSIPreservationRisk]
    ) throws {
        guard data.count >= 52 else { return } // Interpreter rejects this before inventory.
        let commentUnits = Int(readUInt32(data, 48))
        let (commentBytes, overflow) = commentUnits.multipliedReportingOverflow(by: 2)
        guard !overflow else { return }
        let (fullLength, lengthOverflow) = 120.addingReportingOverflow(commentBytes)
        guard !lengthOverflow else { throw TSIParserError.integerOverflow }
        if data.count < fullLength {
            add(.partialCMAD, path, detail: "\(data.count)/\(fullLength)", to: &risks)
            return
        }
        if data.count > fullLength {
            add(.extendedCMAD, path, detail: "\(data.count)/\(fullLength)", to: &risks)
            return
        }

        var hasTypedCMADRisk = false
        let comment = try readWideString(data, at: 48, limits: limits)
        if comment.lossy {
            add(.lossyString, "\(path)/Comment", to: &risks)
            hasTypedCMADRisk = true
        }
        if readUInt32(data, 0) != 4 {
            add(.proprietaryDeviceType, path, to: &risks)
            hasTypedCMADRisk = true
        }
        if ![0, 1, 2, 65_535].contains(readUInt32(data, 4)) {
            add(.coercedControllerType, path, to: &risks)
            hasTypedCMADRisk = true
        }
        if !(0...8).contains(readUInt32(data, 8)) {
            add(.coercedInteractionMode, path, to: &risks)
            hasTypedCMADRisk = true
        }
        let target = Int32(bitPattern: readUInt32(data, 12))
        if !(-1...15).contains(target) {
            add(.coercedTargetAssignment, path, to: &risks)
            hasTypedCMADRisk = true
        }

        guard !hasTypedCMADRisk, commandID > 0,
              let semanticIndex,
              mappingFile.devices.indices.contains(device),
              mappingFile.devices[device].mappings.indices.contains(semanticIndex) else { return }
        let reproducible = try TSIWriter().preservingCMADPayload(
            for: mappingFile.devices[device].mappings[semanticIndex]
        )
        if reproducible != data {
            add(.unreproducibleCMAD, path, to: &risks)
        }
    }

    private static func classifyDDIV(
        _ data: Data,
        path: String,
        limits: TSIParseLimits,
        risks: inout [TSIPreservationRisk]
    ) throws {
        let string = try readWideString(data, at: 0, limits: limits)
        if string.lossy { add(.lossyString, path, to: &risks) }
        let (expectedEnd, overflow) = string.end.addingReportingOverflow(4)
        guard !overflow, expectedEnd <= data.count else {
            throw TSIParserError.unexpectedEndOfData
        }
        if expectedEnd != data.count {
            add(.unclassifiedSourceData, path, to: &risks)
        }
    }

    private static func classifySingleString(
        _ data: Data,
        path: String,
        limits: TSIParseLimits,
        risks: inout [TSIPreservationRisk]
    ) throws {
        let string = try readWideString(data, at: 0, limits: limits)
        if string.lossy { add(.lossyString, path, to: &risks) }
        if string.end != data.count { add(.unclassifiedSourceData, path, to: &risks) }
    }

    private static func classifyPorts(
        _ data: Data,
        device: Int,
        path: String,
        mappingFile: MappingFile,
        limits: TSIParseLimits,
        risks: inout [TSIPreservationRisk]
    ) throws {
        let input = try readWideString(data, at: 0, limits: limits)
        let output = try readWideString(data, at: input.end, limits: limits)
        if input.lossy || output.lossy { add(.lossyString, path, to: &risks) }
        if output.end != data.count { add(.unclassifiedSourceData, path, to: &risks) }
        if mappingFile.devices.indices.contains(device) {
            let semantic = mappingFile.devices[device]
            let preserveImported = semantic.importedIdentity != nil
            let expectedInput = preserveImported
                ? semantic.inPort
                : TSIWriter.canonicalPort(semantic.inPort)
            let expectedOutput = preserveImported
                ? semantic.outPort
                : TSIWriter.canonicalPort(semantic.outPort)
            if input.value != expectedInput || output.value != expectedOutput {
                add(.unreproducibleDeviceIdentity, path, to: &risks)
            }
        }
    }

    /// Structurally validates a duplicate known container before the semantic
    /// inventory discards it in favor of the first document-order singleton.
    /// Unknown frames remain atomic, but every known descendant and count is
    /// bounded and validated using the same cursor/budget as the main walk.
    private static func validateKnownContainer(
        _ data: Data,
        context: ValidationContext,
        depth: Int,
        budget: TSIParseBudget,
        limits: TSIParseLimits
    ) throws {
        var stack = [try validationWork(
            data, context: context, depth: depth, budget: budget, limits: limits
        )]

        while let work = stack.popLast() {
            for frame in work.frames {
                switch work.context {
                case .diom:
                    switch frame.identifier {
                    case "DIOI":
                        guard frame.data.count == 4 else {
                            throw TSIParserError.unexpectedEndOfData
                        }
                    case "DEVS":
                        stack.append(try validationWork(
                            frame.data, context: .devs, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    default:
                        continue
                    }

                case .devs:
                    guard frame.identifier == "DEVI" else { continue }
                    stack.append(try validationWork(
                        frame.data, context: .devi, depth: work.depth + 1,
                        budget: budget, limits: limits
                    ))

                case .devi, .ddat, .dddc, .ddcb:
                    switch frame.identifier {
                    case "DDAT":
                        stack.append(try validationWork(
                            frame.data, context: .ddat, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    case "DDDC":
                        stack.append(try validationWork(
                            frame.data, context: .dddc, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    case "DDCB":
                        stack.append(try validationWork(
                            frame.data, context: .ddcb, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    case "DDCI", "DDCO":
                        stack.append(try validationWork(
                            frame.data, context: .definitions, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    case "CMAS":
                        stack.append(try validationWork(
                            frame.data, context: .mappings, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    case "DCBM":
                        stack.append(try validationWork(
                            frame.data, context: .bindings, depth: work.depth + 1,
                            budget: budget, limits: limits
                        ))
                    case "DDIF":
                        guard frame.data.count == 4 else {
                            throw TSIParserError.unexpectedEndOfData
                        }
                    case "DDIV":
                        let value = try readWideString(frame.data, at: 0, limits: limits)
                        let (requiredEnd, overflow) = value.end.addingReportingOverflow(4)
                        guard !overflow, requiredEnd <= frame.data.count else {
                            throw TSIParserError.unexpectedEndOfData
                        }
                    case "DDIC":
                        _ = try readWideString(frame.data, at: 0, limits: limits)
                    case "DDPT":
                        let input = try readWideString(frame.data, at: 0, limits: limits)
                        _ = try readWideString(frame.data, at: input.end, limits: limits)
                    default:
                        continue
                    }

                case .definitions:
                    guard frame.identifier == "DCDT" else {
                        throw TSIParserError.unexpectedEndOfData
                    }
                    let name = try readWideString(frame.data, at: 0, limits: limits)
                    let (expectedEnd, overflow) = name.end.addingReportingOverflow(20)
                    guard !overflow, expectedEnd == frame.data.count else {
                        throw TSIParserError.unexpectedEndOfData
                    }

                case .mappings:
                    guard frame.identifier == "CMAI", frame.data.count >= 20 else {
                        throw TSIParserError.unexpectedEndOfData
                    }
                    guard readUInt32(frame.data, 4) <= 1 else {
                        throw TSIParserError.unexpectedEndOfData
                    }
                    try budget.enterContainer(atDepth: work.depth + 1)
                    var childCount = 0
                    try budget.consumeFrame(containerCount: &childCount)
                    let parsed = try TSIFrameCursor(
                        data: frame.data, limits: limits,
                        instrumentation: budget.instrumentation
                    ).parse(at: 12)
                    guard parsed.frame.identifier == "CMAD",
                          parsed.nextOffset == frame.data.count,
                          parsed.frame.data.count >= 52 else {
                        throw TSIParserError.unexpectedEndOfData
                    }
                    _ = try readWideString(parsed.frame.data, at: 48, limits: limits)

                case .bindings:
                    guard frame.identifier == "DCBM", frame.data.count >= 8 else {
                        throw TSIParserError.unexpectedEndOfData
                    }
                    let name = try readWideString(frame.data, at: 4, limits: limits)
                    guard name.end == frame.data.count else {
                        throw TSIParserError.unexpectedEndOfData
                    }
                }
            }
        }
    }

    private static func validationWork(
        _ data: Data,
        context: ValidationContext,
        depth: Int,
        budget: TSIParseBudget,
        limits: TSIParseLimits
    ) throws -> ValidationWorkItem {
        let frames: [TSIFrame]
        switch context {
        case .devs:
            frames = try countedFrames(
                data, expectedIdentifier: "DEVI", depth: depth, budget: budget
            )
        case .definitions:
            frames = try countedFrames(
                data, expectedIdentifier: "DCDT", depth: depth, budget: budget
            )
        case .mappings:
            frames = try countedFrames(
                data, expectedIdentifier: "CMAI", depth: depth, budget: budget
            )
        case .bindings:
            frames = try countedFrames(
                data, expectedIdentifier: "DCBM", depth: depth, budget: budget
            )
        case .devi:
            let name = try readWideString(data, at: 0, limits: limits)
            frames = try parseFrames(data, startingAt: name.end, depth: depth, budget: budget)
        case .diom, .ddat, .dddc, .ddcb:
            frames = try parseFrames(data, startingAt: 0, depth: depth, budget: budget)
        }
        return .init(frames: frames, depth: depth, context: context)
    }

    private static func nestedWork(
        _ data: Data,
        path: String,
        depth: Int,
        context: Context,
        budget: TSIParseBudget
    ) throws -> WorkItem {
        .init(
            frames: try parseFrames(data, startingAt: 0, depth: depth, budget: budget),
            path: path, depth: depth, context: context
        )
    }

    private static func countedWork(
        _ data: Data,
        path: String,
        depth: Int,
        context: Context,
        expectedIdentifier: String,
        budget: TSIParseBudget
    ) throws -> WorkItem {
        let frames = try countedFrames(
            data, expectedIdentifier: expectedIdentifier, depth: depth, budget: budget
        )
        return .init(frames: frames, path: path, depth: depth, context: context)
    }

    private static func countedFrames(
        _ data: Data,
        expectedIdentifier: String,
        depth: Int,
        budget: TSIParseBudget
    ) throws -> [TSIFrame] {
        guard data.count >= 4 else { throw TSIParserError.unexpectedEndOfData }
        let declared = Int(readUInt32(data, 0))
        try budget.validateDeclaredFrameCount(declared)
        let frames = try parseFrames(data, startingAt: 4, depth: depth, budget: budget)
        guard frames.lazy.filter({ $0.identifier == expectedIdentifier }).count == declared else {
            throw TSIParserError.unexpectedEndOfData
        }
        return frames
    }

    private static func parseFrames(
        _ data: Data,
        startingAt start: Int,
        depth: Int,
        budget: TSIParseBudget
    ) throws -> [TSIFrame] {
        try budget.enterContainer(atDepth: depth)
        var frames: [TSIFrame] = []
        let cursor = TSIFrameCursor(
            data: data, limits: budget.limits, instrumentation: budget.instrumentation
        )
        var offset = start
        var count = 0
        while offset < data.count {
            guard data.count - offset >= TSIFrame.headerSize else {
                throw TSIParserError.unexpectedEndOfData
            }
            try budget.consumeFrame(containerCount: &count)
            let parsed = try cursor.parse(at: offset)
            frames.append(parsed.frame)
            offset = parsed.nextOffset
        }
        return frames
    }

    private static func readWideString(
        _ data: Data,
        at offset: Int,
        limits: TSIParseLimits
    ) throws -> (value: String, end: Int, lossy: Bool) {
        guard offset >= 0, offset <= data.count, data.count - offset >= 4 else {
            throw TSIParserError.unexpectedEndOfData
        }
        let count = Int(readUInt32(data, offset))
        let (byteCount, byteOverflow) = count.multipliedReportingOverflow(by: 2)
        guard !byteOverflow else { throw TSIParserError.integerOverflow }
        guard byteCount <= limits.maximumUTF16StringBytes else {
            throw TSIParserError.utf16StringByteLimitExceeded
        }
        let (start, startOverflow) = offset.addingReportingOverflow(4)
        let (end, endOverflow) = start.addingReportingOverflow(byteCount)
        guard !startOverflow, !endOverflow, end <= data.count else {
            throw TSIParserError.unexpectedEndOfData
        }
        var units: [UInt16] = []
        units.reserveCapacity(count)
        for index in stride(from: start, to: end, by: 2) {
            units.append(UInt16(data[index]) << 8 | UInt16(data[index + 1]))
        }
        let value = String(decoding: units, as: UTF16.self)
        return (value, end, Array(value.utf16) != units)
    }

    private static func duplicateIfNeeded(
        _ index: Int,
        id: String,
        path: String,
        risks: inout [TSIPreservationRisk]
    ) {
        if index > 0 { add(.duplicateSingletonFrame, path, detail: id, to: &risks) }
    }

    private static func add(
        _ code: TSIPreservationRisk.Code,
        _ path: String,
        detail: String = "",
        to risks: inout [TSIPreservationRisk]
    ) {
        risks.append(.init(code: code, path: path, detail: detail))
    }

    private static func definitionKey(_ name: String, _ direction: IODirection) -> String {
        "\(direction.rawValue)|\(name)"
    }

    private static func isModeledFrame(_ identifier: String) -> Bool {
        ["DDIF", "DDIV", "DDIC", "DDPT", "DDDC", "DDCB", "CMAS", "DCBM"].contains(identifier)
    }

    private static func isModeledMIDIName(_ name: String) -> Bool {
        let parts = name.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[0].hasPrefix("Ch"),
              let channel = Int(parts[0].dropFirst(2)), (1...16).contains(channel) else {
            return false
        }
        if parts[1] == "CC" {
            return (1...3).contains(parts[2].count) && parts[2].allSatisfy(\.isNumber)
                && (Int(parts[2]) ?? 128) <= 127
        }
        if parts[1] == "Note" {
            let note = String(parts[2])
            return !note.isEmpty && !note.contains("+")
        }
        return false
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        guard offset >= 0, offset <= data.count, data.count - offset >= 4 else { return 0 }
        return data.withUnsafeBytes {
            $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }
}
