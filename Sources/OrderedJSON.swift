import Foundation

/// JSON that writes back exactly what it read: members keep their order, and
/// numbers and strings keep their original text. The pad's keymap file and
/// T3 Code's shortcut file are edited through this, so a change touches only
/// the part it means to.
indirect enum JSONValue: Equatable {
    struct Member: Equatable {
        var key: String
        var value: JSONValue
    }

    case object([Member])
    case array([JSONValue])
    /// The text between the quotes, escapes included.
    case string(String)
    /// The number as written, such as 0.55 or 16711680.
    case number(String)
    case bool(Bool)
    case null

    struct ParseError: Error, CustomStringConvertible {
        let description: String
    }

    // MARK: Reading values

    subscript(key: String) -> JSONValue? {
        guard case let .object(members) = self else { return nil }
        return members.first { $0.key == key }?.value
    }

    var items: [JSONValue]? {
        if case let .array(values) = self { return values }
        return nil
    }

    /// The string with its escapes decoded.
    var text: String? {
        guard case let .string(raw) = self else { return nil }
        if !raw.contains("\\") { return raw }
        let decoded = try? JSONSerialization.jsonObject(with: Data("[\"\(raw)\"]".utf8)) as? [String]
        return decoded?.first
    }

    var int: Int? {
        if case let .number(raw) = self { return Int(raw) }
        return nil
    }

    static func text(_ value: String) -> JSONValue {
        var raw = ""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\"": raw += "\\\""
            case "\\": raw += "\\\\"
            case "\n": raw += "\\n"
            case "\r": raw += "\\r"
            case "\t": raw += "\\t"
            default:
                if scalar.value < 0x20 {
                    raw += String(format: "\\u%04x", scalar.value)
                } else {
                    raw.unicodeScalars.append(scalar)
                }
            }
        }
        return .string(raw)
    }

    /// The same object with one member replaced, or added at the end.
    func setting(_ key: String, to value: JSONValue) -> JSONValue {
        guard case var .object(members) = self else { return self }
        if let index = members.firstIndex(where: { $0.key == key }) {
            members[index].value = value
        } else {
            members.append(Member(key: key, value: value))
        }
        return .object(members)
    }

    // MARK: Parsing

    static func parse(_ data: Data) throws -> JSONValue {
        var parser = Parser(bytes: [UInt8](data))
        parser.skipSpace()
        let value = try parser.value()
        parser.skipSpace()
        guard parser.index == parser.bytes.count else { throw ParseError(description: "text after the end of the JSON value") }
        return value
    }

    private struct Parser {
        let bytes: [UInt8]
        var index = 0

        mutating func skipSpace() {
            while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
        }

        func fail(_ what: String) -> ParseError { ParseError(description: "\(what) at byte \(index)") }

        mutating func value() throws -> JSONValue {
            guard index < bytes.count else { throw fail("unexpected end") }
            switch bytes[index] {
            case UInt8(ascii: "{"): return try object()
            case UInt8(ascii: "["): return try array()
            case UInt8(ascii: "\""): return .string(try string())
            case UInt8(ascii: "t"): try word("true"); return .bool(true)
            case UInt8(ascii: "f"): try word("false"); return .bool(false)
            case UInt8(ascii: "n"): try word("null"); return .null
            default: return try number()
            }
        }

        mutating func word(_ text: String) throws {
            let wanted = [UInt8](text.utf8)
            guard index + wanted.count <= bytes.count, Array(bytes[index..<(index + wanted.count)]) == wanted else {
                throw fail("unknown word")
            }
            index += wanted.count
        }

        mutating func number() throws -> JSONValue {
            let start = index
            while index < bytes.count, "+-0123456789.eE".utf8.contains(bytes[index]) { index += 1 }
            let raw = String(decoding: bytes[start..<index], as: UTF8.self)
            guard !raw.isEmpty, Double(raw) != nil else { throw fail("not a JSON value") }
            return .number(raw)
        }

        mutating func string() throws -> String {
            index += 1
            let start = index
            while index < bytes.count, bytes[index] != UInt8(ascii: "\"") {
                index += bytes[index] == UInt8(ascii: "\\") ? 2 : 1
            }
            guard index < bytes.count else { throw fail("string without an end") }
            let raw = String(decoding: bytes[start..<index], as: UTF8.self)
            index += 1
            return raw
        }

        mutating func array() throws -> JSONValue {
            index += 1
            var values: [JSONValue] = []
            skipSpace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "]") { index += 1; return .array(values) }
            while true {
                skipSpace()
                values.append(try value())
                skipSpace()
                guard index < bytes.count else { throw fail("list without an end") }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "]") { index += 1; return .array(values) }
                throw fail("expected , or ]")
            }
        }

        mutating func object() throws -> JSONValue {
            index += 1
            var members: [Member] = []
            skipSpace()
            if index < bytes.count, bytes[index] == UInt8(ascii: "}") { index += 1; return .object(members) }
            while true {
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: "\"") else { throw fail("expected a member name") }
                let key = try string()
                skipSpace()
                guard index < bytes.count, bytes[index] == UInt8(ascii: ":") else { throw fail("expected :") }
                index += 1
                skipSpace()
                members.append(Member(key: key, value: try value()))
                skipSpace()
                guard index < bytes.count else { throw fail("object without an end") }
                if bytes[index] == UInt8(ascii: ",") { index += 1; continue }
                if bytes[index] == UInt8(ascii: "}") { index += 1; return .object(members) }
                throw fail("expected , or }")
            }
        }
    }

    // MARK: Writing

    /// One line, no spaces: the form the pad stores.
    var compact: String {
        switch self {
        case let .object(members): return "{" + members.map { "\"\($0.key)\":\($0.value.compact)" }.joined(separator: ",") + "}"
        case let .array(values): return "[" + values.map { $0.compact }.joined(separator: ",") + "]"
        case let .string(raw): return "\"\(raw)\""
        case let .number(raw): return raw
        case let .bool(value): return value ? "true" : "false"
        case .null: return "null"
        }
    }

    /// Two-space indentation: the form T3 Code writes its settings in.
    func pretty(_ depth: Int = 0) -> String {
        let pad = String(repeating: "  ", count: depth + 1)
        let end = String(repeating: "  ", count: depth)
        switch self {
        case let .object(members):
            if members.isEmpty { return "{}" }
            return "{\n" + members.map { "\(pad)\"\($0.key)\": \($0.value.pretty(depth + 1))" }.joined(separator: ",\n") + "\n\(end)}"
        case let .array(values):
            if values.isEmpty { return "[]" }
            return "[\n" + values.map { pad + $0.pretty(depth + 1) }.joined(separator: ",\n") + "\n\(end)]"
        default:
            return compact
        }
    }
}
