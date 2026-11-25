import Foundation

struct BridgeError: Error, CustomStringConvertible {
    let description: String
}

struct BridgeReader {
    private let bytes: UnsafeBufferPointer<UInt8>
    private var index = 0

    init(_ bytes: UnsafeBufferPointer<UInt8>) {
        self.bytes = bytes
    }

    private func fail(_ message: String) -> BridgeError {
        BridgeError(description: "\(message) at byte \(index)")
    }

    private func text(_ range: Range<Int>) -> String {
        String(unsafeUninitializedCapacity: range.count) { buffer in
            _ = buffer.initialize(fromContentsOf: bytes[range])
            return range.count
        }
    }

    private var current: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private mutating func skipWhitespace() {
        while let byte = current, byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09 {
            index += 1
        }
    }

    private mutating func expect(_ byte: UInt8) throws(BridgeError) {
        skipWhitespace()
        guard current == byte else { throw fail("Expected \(Character(Unicode.Scalar(byte)))") }
        index += 1
    }

    private mutating func separator() {
        skipWhitespace()
        if current == UInt8(ascii: ",") {
            index += 1
            skipWhitespace()
        }
    }

    mutating func open() throws(BridgeError) {
        try expect(UInt8(ascii: "["))
    }

    mutating func isAtEnd() throws(BridgeError) -> Bool {
        separator()
        guard let byte = current else { throw fail("Unterminated batch") }
        guard byte == UInt8(ascii: "]") else { return false }
        index += 1
        return true
    }

    mutating func int() throws(BridgeError) -> Int {
        separator()
        let isNegative = current == UInt8(ascii: "-")
        if isNegative { index += 1 }
        let start = index
        var value = 0
        while let byte = current, byte >= 0x30, byte <= 0x39 {
            value = value &* 10 &+ Int(byte &- 0x30)
            index += 1
        }
        guard index > start else { throw fail("Expected an integer") }
        return isNegative ? -value : value
    }

    mutating func string() throws(BridgeError) -> String {
        separator()
        guard current == UInt8(ascii: "\"") else { throw fail("Expected a string") }
        index += 1
        let start = index
        while let byte = current, byte != UInt8(ascii: "\""), byte != UInt8(ascii: "\\") {
            index += 1
        }
        guard let byte = current else { throw fail("Unterminated string") }
        if byte == UInt8(ascii: "\"") {
            index += 1
            return text(start..<index - 1)
        }
        var scalars = String.UnicodeScalarView()
        var runStart = start
        while true {
            guard let byte = current else { throw fail("Unterminated string") }
            if byte == UInt8(ascii: "\"") || byte == UInt8(ascii: "\\") {
                if runStart < index {
                    scalars.append(
                        contentsOf: text(runStart..<index)
                            .unicodeScalars)
                }
                index += 1
                if byte == UInt8(ascii: "\"") { return String(scalars) }
                scalars.append(try escape())
                runStart = index
            } else {
                index += 1
            }
        }
    }

    private mutating func escape() throws(BridgeError) -> Unicode.Scalar {
        guard let byte = current else { throw fail("Unterminated escape") }
        index += 1
        switch byte {
        case UInt8(ascii: "\""): return "\""
        case UInt8(ascii: "\\"): return "\\"
        case UInt8(ascii: "/"): return "/"
        case UInt8(ascii: "b"): return "\u{08}"
        case UInt8(ascii: "f"): return "\u{0C}"
        case UInt8(ascii: "n"): return "\n"
        case UInt8(ascii: "r"): return "\r"
        case UInt8(ascii: "t"): return "\t"
        case UInt8(ascii: "u"):
            let high = try hex()
            if (0xD800..<0xDC00).contains(high), current == UInt8(ascii: "\\"),
                index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "u")
            {
                let mark = index
                index += 2
                let low = try hex()
                if (0xDC00..<0xE000).contains(low),
                    let scalar = Unicode.Scalar(0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00))
                {
                    return scalar
                }
                index = mark
            }
            return Unicode.Scalar(high) ?? "\u{FFFD}"
        default:
            throw fail("Invalid escape")
        }
    }

    private mutating func hex() throws(BridgeError) -> UInt32 {
        guard index + 4 <= bytes.count else { throw fail("Truncated unicode escape") }
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = bytes[index]
            let digit: UInt8
            switch byte {
            case 0x30...0x39: digit = byte - 0x30
            case 0x41...0x46: digit = byte - 0x37
            case 0x61...0x66: digit = byte - 0x57
            default: throw fail("Invalid unicode escape")
            }
            value = value << 4 | UInt32(digit)
            index += 1
        }
        return value
    }

    private mutating func literal(_ word: StaticString, _ value: JSONValue) throws(BridgeError) -> JSONValue {
        let count = word.utf8CodeUnitCount
        guard index + count <= bytes.count,
            word.withUTF8Buffer({ word in (0..<count).allSatisfy { bytes[index + $0] == word[$0] } })
        else { throw fail("Unexpected token") }
        index += count
        return value
    }

    private mutating func number() throws(BridgeError) -> JSONValue {
        let start = index
        while let byte = current,
            (0x30...0x39).contains(byte) || byte == UInt8(ascii: "-") || byte == UInt8(ascii: "+")
                || byte == UInt8(ascii: ".") || byte == UInt8(ascii: "e") || byte == UInt8(ascii: "E")
        {
            index += 1
        }
        let text = text(start..<index)
        guard let value = Double(text) else { throw fail("Invalid number") }
        return .number(value)
    }

    mutating func value() throws(BridgeError) -> JSONValue {
        separator()
        guard let byte = current else { throw fail("Expected a value") }
        switch byte {
        case UInt8(ascii: "\""):
            return .string(try string())
        case UInt8(ascii: "n"):
            return try literal("null", .null)
        case UInt8(ascii: "t"):
            return try literal("true", .bool(true))
        case UInt8(ascii: "f"):
            return try literal("false", .bool(false))
        case UInt8(ascii: "["):
            index += 1
            var values: Array<JSONValue> = []
            while try !isAtEnd() { values.append(try value()) }
            return .array(values)
        case UInt8(ascii: "{"):
            index += 1
            var values: [String: JSONValue] = [:]
            while true {
                separator()
                if current == UInt8(ascii: "}") {
                    index += 1
                    return .object(values)
                }
                let key = try string()
                try expect(UInt8(ascii: ":"))
                values[key] = try value()
            }
        default:
            return try number()
        }
    }

    mutating func finish() throws(BridgeError) {
        skipWhitespace()
        guard current == nil else { throw fail("Trailing data") }
    }
}

extension JSONValue {
    init(parsing json: String) throws(BridgeError) {
        var json = json
        let result: Result<Self, BridgeError> = json.withUTF8 { bytes in
            var reader = BridgeReader(bytes)
            return Result { () throws(BridgeError) -> Self in
                let value = try reader.value()
                try reader.finish()
                return value
            }
        }
        self = try result.get()
    }
}
