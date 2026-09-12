import Foundation

nonisolated enum JSONRepairError: LocalizedError, Sendable {
    case unsafeInput, tooLarge, invalidPatch, invalidResponse, failedValidation
    var errorDescription: String? {
        switch self {
        case .unsafeInput: return "AI repair cannot safely isolate retained source in this JSON. Fix JSON syntax locally first, or export a fresh JSON copy from the original TSI. The file has not changed."
        case .tooLarge: return "This file or repair exceeds AI repair limits. Use the local diagnostics to edit a copy, then import it again."
        case .invalidPatch: return "The proposed edits were ambiguous, overlapping, empty, or touched protected source. No repair was applied."
        case .invalidResponse: return "The service returned an invalid repair response. No repair was applied."
        case .failedValidation: return "The proposed repair did not pass the mapping and TSI preservation checks. Correct the original using the local diagnostics or try again."
        }
    }
}

nonisolated struct JSONRepairPatch: Codable, Equatable, Sendable {
    let before: String
    let after: String
}

/// Immutable input bytes; only a separately redacted view may cross the network.
nonisolated struct JSONRepairInput: Sendable {
    let original: Data
    let redactedText: String
    fileprivate let protectedRanges: [Range<Int>]
    fileprivate static let marker = "\"[SOURCE RETAINED LOCALLY — DO NOT EDIT]\""

    init(original: Data) throws {
        guard original.count <= 8 * 1024 * 1024 else { throw JSONRepairError.tooLarge }
        guard String(data: original, encoding: .utf8) != nil else { throw JSONRepairError.unsafeInput }
        let bytes = Array(original)
        let tokens = try Self.tokens(bytes)
        let validSyntax = (try? SXMJSONScanner.validate(original, maximumBytes: 8 * 1024 * 1024)) != nil
        let preservationTokens = tokens.indices.filter { tokens[$0].text == "preservation" }
        guard preservationTokens.count <= 16 else { throw JSONRepairError.tooLarge }
        // Malformed input is eligible only when punctuation-only normalization can
        // prove the full tree is source-free. Never infer safety from token absence
        // alone: a split or partially typed key could hide a retained payload.
        let inspection: Data
        if validSyntax { inspection = original }
        else {
            guard preservationTokens.isEmpty else { throw JSONRepairError.unsafeInput }
            inspection = try Self.punctuationNormalized(original, tokens: tokens)
        }
        guard let root = try? JSONSerialization.jsonObject(with: inspection) as? [String: Any] else {
            throw JSONRepairError.unsafeInput
        }
        try SXMJSONCodec.validateRepairVisibility(root)
        var protected: [Range<Int>] = []
        var values: [Range<Int>] = []
        for index in preservationTokens {
            guard index + 2 < tokens.count, tokens[index + 1].symbol == 58 else { continue }
            let first = index + 2
            var last = first
            if tokens[first].symbol == 123 || tokens[first].symbol == 91 {
                var depth = 1
                while depth > 0 {
                    last += 1
                    guard last < tokens.count else { throw JSONRepairError.unsafeInput }
                    if tokens[last].symbol == 123 || tokens[last].symbol == 91 { depth += 1 }
                    if tokens[last].symbol == 125 || tokens[last].symbol == 93 { depth -= 1 }
                }
            }
            let value = tokens[first].range.lowerBound..<tokens[last].range.upperBound
            let whole = tokens[index].range.lowerBound..<value.upperBound
            if !protected.contains(where: { $0.contains(whole.lowerBound) }) {
                protected.append(whole); values.append(value)
            }
        }
        // A moved source field must not become visible just because the parent key
        // was renamed. Root typos are refused above; source-shaped nested fields
        // outside a protected preservation object are also refused.
        for index in tokens.indices where tokens[index].text?.lowercased() == "originalxml" {
            if index + 1 < tokens.count, tokens[index + 1].symbol == 58,
               !protected.contains(where: { $0.contains(tokens[index].range.lowerBound) }) {
                throw JSONRepairError.unsafeInput
            }
        }
        var redacted = original
        for range in values.reversed() { redacted.replaceSubrange(range, with: Self.marker.utf8) }
        guard redacted.count <= 96 * 1024 else { throw JSONRepairError.tooLarge }
        self.original = original
        self.redactedText = String(decoding: redacted, as: UTF8.self)
        self.protectedRanges = protected
    }

    private struct Token {
        let range: Range<Int>
        let text: String?
        let symbol: UInt8?
    }
    /// Only trailing commas and missing commas before object keys are tolerated.
    /// This temporary copy proves safety; neither original nor repair text changes.
    private static func punctuationNormalized(_ data: Data, tokens: [Token]) throws -> Data {
        var edits: [(Range<Int>, Data)] = []
        for index in tokens.indices {
            let token = tokens[index]
            let next = index + 1 < tokens.count ? tokens[index + 1] : nil
            if token.symbol == 44, next == nil || next?.symbol == 125 || next?.symbol == 93 {
                edits.append((token.range, Data()))
            }
            if index > 0, token.text != nil, next?.symbol == 58 {
                let previous = tokens[index - 1]
                if previous.symbol == nil || previous.symbol == 125 || previous.symbol == 93 {
                    edits.append((token.range.lowerBound..<token.range.lowerBound, Data([44])))
                }
            }
        }
        guard !edits.isEmpty, edits.count <= 16 else { throw JSONRepairError.unsafeInput }
        var normalized = data
        for (range, replacement) in edits.reversed() { normalized.replaceSubrange(range, with: replacement) }
        guard (try? SXMJSONScanner.validate(normalized, maximumBytes: 8 * 1024 * 1024)) != nil else {
            throw JSONRepairError.unsafeInput
        }
        return normalized
    }

    /// A conservative lexer, independent of schema decoding. Unclosed strings,
    /// invalid escapes and non-JSON bare words make source isolation unsafe.
    private static func tokens(_ bytes: [UInt8]) throws -> [Token] {
        var result: [Token] = []
        var i = 0
        let whitespace: Set<UInt8> = [32, 9, 10, 13]
        let punctuation: Set<UInt8> = [123, 125, 91, 93, 44, 58]
        while i < bytes.count {
            if whitespace.contains(bytes[i]) { i += 1; continue }
            let start = i
            if bytes[i] == 34 {
                i += 1
                var closed = false
                while i < bytes.count {
                    if bytes[i] == 92 { i += 2; continue }
                    if bytes[i] == 34 { i += 1; closed = true; break }
                    i += 1
                }
                guard closed, i <= bytes.count,
                      let string = try? JSONDecoder().decode(String.self, from: Data(bytes[start..<i])) else { throw JSONRepairError.unsafeInput }
                result.append(Token(range: start..<i, text: string, symbol: nil))
            } else if punctuation.contains(bytes[i]) {
                result.append(Token(range: i..<(i + 1), text: nil, symbol: bytes[i])); i += 1
            } else {
                while i < bytes.count, !whitespace.contains(bytes[i]), !punctuation.contains(bytes[i]), bytes[i] != 34 { i += 1 }
                let literal = String(decoding: bytes[start..<i], as: UTF8.self)
                guard ["true", "false", "null"].contains(literal) || (!literal.isEmpty && literal.utf8.allSatisfy({ (48...57).contains($0) || [UInt8(45), 43, 46, 69, 101].contains($0) })) else {
                    throw JSONRepairError.unsafeInput
                }
                result.append(Token(range: start..<i, text: nil, symbol: nil))
            }
            guard result.count <= 250_000 else { throw JSONRepairError.tooLarge }
        }
        return result
    }
}

nonisolated struct JSONRepairPlan: Sendable {
    let patches: [JSONRepairPatch]
    let repaired: Data
    let candidate: JSONImportCandidate

    init(input: JSONRepairInput, patches: [JSONRepairPatch]) throws {
        guard !patches.isEmpty, patches.count <= 16 else { throw JSONRepairError.invalidPatch }
        var total = 0
        var edits: [(Range<Int>, JSONRepairPatch)] = []
        for patch in patches {
            let before = Data(patch.before.utf8), after = Data(patch.after.utf8)
            total += before.count + after.count
            guard !before.isEmpty, before != after, before.count <= 4096, after.count <= 4096,
                  total <= 32 * 1024, !patch.before.contains(JSONRepairInput.marker), !patch.after.contains(JSONRepairInput.marker),
                  let range = input.original.range(of: before),
                  input.original.range(of: before, in: (range.lowerBound + 1)..<input.original.count) == nil,
                  !input.protectedRanges.contains(where: { $0.overlaps(range) }),
                  !edits.contains(where: { $0.0.overlaps(range) }) else { throw JSONRepairError.invalidPatch }
            // Review strings are exact slices of the local immutable bytes.
            edits.append((range, JSONRepairPatch(before: String(decoding: input.original[range], as: UTF8.self), after: patch.after)))
        }
        edits.sort { $0.0.lowerBound < $1.0.lowerBound }
        var result = input.original
        for (range, patch) in edits.reversed() { result.replaceSubrange(range, with: patch.after.utf8) }
        guard result != input.original else { throw JSONRepairError.invalidPatch }
        // Reject changes that move retained bytes outside their original field,
        // introduce a new field, or encode a protected key differently.
        let checked = try JSONRepairInput(original: result)
        guard input.protectedRanges.map({ input.original.subdata(in: $0) }) == checked.protectedRanges.map({ result.subdata(in: $0) }) else {
            throw JSONRepairError.invalidPatch
        }
        let candidate = JSONImportService.review(result)
        guard candidate.canOpen, candidate.canWriteTSI,
              !candidate.diagnostics.contains(where: { $0.severity == .error }) else { throw JSONRepairError.failedValidation }
        self.patches = edits.map(\.1)
        self.repaired = result
        self.candidate = candidate
    }
}
