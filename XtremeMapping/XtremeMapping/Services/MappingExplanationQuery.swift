import Foundation

nonisolated struct ExplanationContext: Codable, Sendable, Equatable {
    let revision: String
    let rows: [ExplanationRow]
    let totalRows: Int
    let omittedRows: Int
    let limitations: [String]
}

nonisolated enum MappingExplanationQuery {
    private static let maximumBytes = 96 * 1024
    private static let maximumStringCharacters = 16_384

    static func retrieve(question: String, snapshot: MappingExplanationSnapshot,
                         selectedIDs: Set<UUID> = [], limit: Int = 80) -> ExplanationContext {
        let boundedLimit = max(0, min(80, limit))
        let selectedDevices = Set(snapshot.rows.filter { selectedIDs.contains($0.id) }.map(\.deviceID))
        let searchableRows = selectedDevices.isEmpty ? snapshot.rows : snapshot.rows.filter { selectedDevices.contains($0.deviceID) }
        let selected = snapshot.rows.filter { selectedIDs.contains($0.id) }
        let tokens = queryTokens(question)
        let requestedModifiers = modifierNumbers(in: question)

        var scored: [(row: ExplanationRow, score: Int, order: Int)] = []
        for (order, row) in searchableRows.enumerated() where !selectedIDs.contains(row.id) {
            let rowModifiers = Set(row.modifierReads + row.modifierWrites)
            if !requestedModifiers.isEmpty && requestedModifiers.isDisjoint(with: rowModifiers) { continue }
            let score = relevance(of: row, tokens: tokens)
            if score > 0 || !requestedModifiers.isEmpty {
                scored.append((row, score + requestedModifiers.intersection(rowModifiers).count * 100, order))
            }
        }
        scored.sort { lhs, rhs in lhs.score == rhs.score ? lhs.order < rhs.order : lhs.score > rhs.score }

        let roots = selected + scored.map(\.row)
        var modifiersByDevice: [UUID: Set<Int>] = [:]
        for root in roots {
            modifiersByDevice[root.deviceID, default: []].formUnion(root.modifierReads)
            modifiersByDevice[root.deviceID, default: []].formUnion(root.modifierWrites)
        }
        let dependencies = searchableRows.filter { row in
            guard !selectedIDs.contains(row.id), let modifiers = modifiersByDevice[row.deviceID],
                  !modifiers.isEmpty else { return false }
            return !modifiers.isDisjoint(with: row.modifierReads + row.modifierWrites)
        }
        var ordered = selected + scored.map(\.row) + dependencies
        var seen = Set<UUID>()
        ordered = ordered.filter { seen.insert($0.id).inserted }

        let relevantDeviceIDs = Set(ordered.prefix(boundedLimit).map(\.deviceID))
        var limitations: [String] = snapshot.limitations
        limitations.append(contentsOf: snapshot.devices.filter { relevantDeviceIDs.contains($0.id) }.flatMap(\.limitations))
        limitations = boundedNotices(limitations)
        if selected.isEmpty && scored.isEmpty {
            limitations.append("No matching rows were found; unrelated rows were not substituted.")
        }
        var candidates = Array(ordered.prefix(boundedLimit)).map { truncate($0, limitations: &limitations) }
        var included: [ExplanationRow] = []
        for candidate in candidates {
            let proposed = included + [candidate]
            let omitted = snapshot.rows.count - proposed.count
            let trialLimitations = omissionLimitations(base: limitations, omitted: omitted)
            let context = ExplanationContext(revision: snapshot.revision, rows: proposed,
                                             totalRows: snapshot.rows.count, omittedRows: omitted,
                                             limitations: trialLimitations)
            if encodedSize(context) <= maximumBytes { included = proposed } else { break }
        }
        candidates.removeAll(keepingCapacity: false)
        let omitted = snapshot.rows.count - included.count
        limitations = omissionLimitations(base: limitations, omitted: omitted)
        var result = ExplanationContext(revision: snapshot.revision, rows: included,
                                        totalRows: snapshot.rows.count, omittedRows: omitted,
                                        limitations: limitations)
        while encodedSize(result) > maximumBytes, !included.isEmpty {
            included.removeLast()
            let newOmitted = snapshot.rows.count - included.count
            result = ExplanationContext(revision: snapshot.revision, rows: included,
                                        totalRows: snapshot.rows.count, omittedRows: newOmitted,
                                        limitations: omissionLimitations(base: limitations, omitted: newOmitted))
        }
        while encodedSize(result) > maximumBytes, !limitations.isEmpty {
            limitations.removeLast()
            let compact = limitations + ["Additional limitation notices omitted to keep context within 96 KiB."]
            result = ExplanationContext(revision: snapshot.revision, rows: included,
                                        totalRows: snapshot.rows.count, omittedRows: snapshot.rows.count - included.count,
                                        limitations: omissionLimitations(base: compact, omitted: snapshot.rows.count - included.count))
        }
        return result
    }

    private static func queryTokens(_ question: String) -> [String] {
        let stopwords: Set<String> = ["a", "an", "and", "are", "do", "does", "for", "how", "i", "in", "is", "it", "of", "on", "the", "this", "to", "what", "where", "which", "with"]
        return Array(Set(question.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)))
            .filter { !$0.isEmpty && !stopwords.contains($0) }
            .sorted()
    }

    private static func modifierNumbers(in question: String) -> Set<Int> {
        let words = question.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var result = Set<Int>()
        for (index, word) in words.enumerated() {
            if word.first == "m", let number = Int(word.dropFirst()), (1...8).contains(number) {
                result.insert(number)
            }
            if word == "modifier", index + 1 < words.count,
               let number = Int(words[index + 1]), (1...8).contains(number) {
                result.insert(number)
            }
        }
        return result
    }

    private static func relevance(of row: ExplanationRow, tokens: [String]) -> Int {
        guard !tokens.isEmpty else { return 0 }
        let haystack = ([row.command, String(row.commandID), row.deviceName, row.direction, row.assignment,
                         row.midi, row.controllerType, row.interaction, row.comment]
                        + row.conditions + row.details + row.controls + row.sources + row.limitations)
            .joined(separator: " ").lowercased()
        return tokens.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
    }

    private static func truncate(_ row: ExplanationRow, limitations: inout [String]) -> ExplanationRow {
        var didTruncate = false
        func string(_ value: String) -> String {
            guard value.count > maximumStringCharacters else { return value }
            didTruncate = true
            return String(value.prefix(maximumStringCharacters)) + "… [truncated]"
        }
        func strings(_ values: [String]) -> [String] { values.map(string) }
        let result = ExplanationRow(id: row.id, deviceID: row.deviceID, deviceName: string(row.deviceName),
                                    position: row.position, commandID: row.commandID, command: string(row.command),
                                    direction: string(row.direction), assignment: string(row.assignment), midi: string(row.midi),
                                    controllerType: string(row.controllerType), interaction: string(row.interaction),
                                    conditions: strings(row.conditions), modifierReads: row.modifierReads,
                                    modifierWrites: row.modifierWrites, details: strings(row.details),
                                    controls: strings(row.controls), sources: strings(row.sources),
                                    limitations: strings(row.limitations), comment: string(row.comment))
        if didTruncate {
            limitations.append("Long strings were truncated in bounded question context; the complete local guide retains them.")
        }
        return result
    }

    private static func omissionLimitations(base: [String], omitted: Int) -> [String] {
        var result = base.filter { !$0.contains("row(s) omitted") }
        if omitted > 0 { result.append("\(omitted) row(s) omitted from bounded question context.") }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    private static func boundedNotices(_ values: [String]) -> [String] {
        var didTruncate = false
        let maximumNotices = 24
        var result = values.prefix(maximumNotices).map { value -> String in
            guard value.count > 512 else { return value }
            didTruncate = true
            return String(value.prefix(512)) + "… [truncated]"
        }
        if values.count > maximumNotices {
            result.append("\(values.count - maximumNotices) additional limitation notice(s) omitted from bounded context.")
        }
        if didTruncate {
            result.append("Long limitation notices were truncated in bounded question context.")
        }
        var seen = Set<String>()
        return result.filter { seen.insert($0).inserted }
    }

    private static func encodedSize(_ context: ExplanationContext) -> Int {
        (try? JSONEncoder().encode(context).count) ?? Int.max
    }
}
