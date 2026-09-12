import Foundation

nonisolated struct SXMJSONIssue: Error, LocalizedError, Sendable {
    let code: String
    let path: String
    let message: String
    let byteOffset: Int?

    init(code: String, path: String, message: String, byteOffset: Int? = nil) {
        self.code = code
        self.path = path
        self.message = message
        self.byteOffset = byteOffset
    }

    var errorDescription: String? {
        "\(path): \(message)" + (byteOffset.map { " (byte \($0))" } ?? "")
    }
}

/// Validates grammar and resource bounds before a decoder allocates the object graph.
nonisolated enum SXMJSONScanner {
    static func validate(_ data: Data, maximumBytes: Int = 128 * 1024 * 1024, maximumDepth: Int = 64) throws {
        guard maximumBytes >= 0, data.count <= maximumBytes, maximumDepth >= 0 else {
            throw SXMJSONIssue(code: "json.resourceLimit", path: "$", message: "JSON exceeds the configured resource limits.")
        }
        var parser = Parser(bytes: Array(data), maximumDepth: maximumDepth)
        try parser.value(path: "$", depth: 0)
        parser.whitespace()
        guard parser.index == parser.bytes.count else { throw parser.issue("Unexpected trailing content.", path: "$") }
    }

    private struct Parser {
        let bytes: [UInt8]
        let maximumDepth: Int
        var index = 0
        var current: UInt8? { index < bytes.count ? bytes[index] : nil }

        func issue(_ message: String, path: String, code: String = "json.syntax", offset: Int? = nil) -> SXMJSONIssue {
            SXMJSONIssue(code: code, path: path, message: message, byteOffset: offset ?? index)
        }

        mutating func whitespace() {
            while let byte = current, byte == 32 || byte == 9 || byte == 10 || byte == 13 { index += 1 }
        }

        mutating func consume(_ byte: UInt8) -> Bool {
            guard current == byte else { return false }
            index += 1
            return true
        }

        mutating func value(path: String, depth: Int) throws {
            whitespace()
            guard let byte = current else { throw issue("Expected a JSON value.", path: path) }
            switch byte {
            case 123, 91:
                // A hard ceiling also protects callers that accidentally supply an unbounded limit.
                guard depth < min(maximumDepth, 512) else {
                    throw issue("JSON nesting exceeds the resource limit.", path: path, code: "json.resourceLimit")
                }
                if current == 123 { try object(path: path, depth: depth + 1) }
                else { try array(path: path, depth: depth + 1) }
            case 34: _ = try string(path: path, capture: false)
            case 116: try literal("true", path: path)
            case 102: try literal("false", path: path)
            case 110: try literal("null", path: path)
            case 45, 48...57: try number(path: path)
            default: throw issue("Expected a JSON value.", path: path)
            }
            if let byte = current, ![UInt8(32), 9, 10, 13, 44, 93, 125].contains(byte) {
                throw issue("Unexpected character after JSON value.", path: path)
            }
        }

        mutating func object(path: String, depth: Int) throws {
            index += 1
            whitespace()
            if consume(125) { return }
            var keys = Set<Data>()
            while true {
                whitespace()
                let keyOffset = index
                guard current == 34 else { throw issue("Expected an object key.", path: path) }
                let keyBytes = try string(path: path, capture: true)
                let key = String(decoding: keyBytes, as: UTF8.self)
                let childPath = memberPath(path, key)
                guard keys.insert(Data(keyBytes)).inserted else {
                    throw issue("Duplicate object key.", path: childPath, code: "json.duplicateKey", offset: keyOffset)
                }
                whitespace()
                guard consume(58) else { throw issue("Expected ':' after the object key.", path: childPath) }
                try value(path: childPath, depth: depth)
                whitespace()
                if consume(125) { return }
                guard consume(44) else { throw issue("Expected ',' or '}'.", path: path) }
            }
        }

        func memberPath(_ parent: String, _ fullKey: String) -> String {
            // Diagnostic paths must not amplify a bounded malicious input by
            // copying megabyte keys at every nested level. Matching still uses
            // the complete decoded key; only its diagnostic label is shortened.
            let key = fullKey.utf8.count > 256
                ? String(decoding: fullKey.utf8.prefix(256), as: UTF8.self) + "…" : fullKey
            if !key.isEmpty, key.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95 }) {
                return parent + "." + key
            }
            let escaped = key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\t", with: "\\t")
            return parent + "[\"" + escaped + "\"]"
        }

        mutating func array(path: String, depth: Int) throws {
            index += 1
            whitespace()
            if consume(93) { return }
            var element = 0
            while true {
                try value(path: "\(path)[\(element)]", depth: depth)
                element += 1
                whitespace()
                if consume(93) { return }
                guard consume(44) else { throw issue("Expected ',' or ']'.", path: path) }
            }
        }

        mutating func literal(_ value: String, path: String) throws {
            for byte in value.utf8 {
                guard consume(byte) else { throw issue("Invalid JSON literal.", path: path) }
            }
        }

        mutating func number(path: String) throws {
            _ = consume(45)
            if !consume(48) {
                guard let byte = current, (49...57).contains(byte) else { throw issue("Expected a digit.", path: path) }
                digits()
            }
            if consume(46) {
                guard let byte = current, (48...57).contains(byte) else { throw issue("Expected a fractional digit.", path: path) }
                digits()
            }
            if current == 101 || current == 69 {
                index += 1
                if current == 43 || current == 45 { index += 1 }
                guard let byte = current, (48...57).contains(byte) else { throw issue("Expected an exponent digit.", path: path) }
                digits()
            }
        }

        mutating func digits() {
            while let byte = current, (48...57).contains(byte) { index += 1 }
        }

        mutating func hexUnit(path: String) throws -> UInt32 {
            var unit: UInt32 = 0
            for _ in 0..<4 {
                guard let byte = current else { throw issue("Incomplete Unicode escape.", path: path) }
                let digit: UInt32
                switch byte {
                case 48...57: digit = UInt32(byte - 48)
                case 65...70: digit = UInt32(byte - 55)
                case 97...102: digit = UInt32(byte - 87)
                default: throw issue("Invalid Unicode escape.", path: path)
                }
                unit = unit * 16 + digit
                index += 1
            }
            return unit
        }

        mutating func string(path: String, capture: Bool) throws -> [UInt8] {
            index += 1
            var decoded: [UInt8] = []
            while let byte = current {
                if consume(34) { return decoded }
                guard byte >= 32 else { throw issue("Unescaped control character in string.", path: path) }
                if consume(92) {
                    guard let escape = current else { throw issue("Incomplete string escape.", path: path) }
                    index += 1
                    let escaped: UInt8
                    switch escape {
                    case 34, 92, 47: escaped = escape
                    case 98: escaped = 8
                    case 102: escaped = 12
                    case 110: escaped = 10
                    case 114: escaped = 13
                    case 116: escaped = 9
                    case 117:
                        var scalar = try hexUnit(path: path)
                        if (0xD800...0xDBFF).contains(scalar) {
                            guard consume(92), consume(117) else { throw issue("Missing low Unicode surrogate.", path: path) }
                            let low = try hexUnit(path: path)
                            guard (0xDC00...0xDFFF).contains(low) else { throw issue("Invalid low Unicode surrogate.", path: path, offset: index - 4) }
                            scalar = 0x10000 + ((scalar - 0xD800) << 10) + low - 0xDC00
                        }
                        guard let unicode = Unicode.Scalar(scalar) else { throw issue("Invalid Unicode scalar.", path: path, offset: index - 4) }
                        if capture { decoded.append(contentsOf: String(unicode).utf8) }
                        continue
                    default: throw issue("Invalid string escape.", path: path, offset: index - 1)
                    }
                    if capture { decoded.append(escaped) }
                    continue
                }
                if byte < 128 {
                    if capture { decoded.append(byte) }
                    index += 1
                    continue
                }
                let length: Int
                switch byte {
                case 0xC2...0xDF: length = 2
                case 0xE0...0xEF: length = 3
                case 0xF0...0xF4: length = 4
                default: throw issue("Invalid UTF-8.", path: path)
                }
                guard index + length <= bytes.count else { throw issue("Incomplete UTF-8 sequence.", path: path) }
                for offset in 1..<length {
                    let continuation = bytes[index + offset]
                    guard (0x80...0xBF).contains(continuation),
                          !(offset == 1 && ((byte == 0xE0 && continuation < 0xA0) || (byte == 0xED && continuation > 0x9F) || (byte == 0xF0 && continuation < 0x90) || (byte == 0xF4 && continuation > 0x8F))) else {
                        throw issue("Invalid UTF-8 sequence.", path: path, offset: index + offset)
                    }
                }
                if capture { decoded.append(contentsOf: bytes[index..<(index + length)]) }
                index += length
            }
            throw issue("Unterminated string.", path: path)
        }
    }
}
