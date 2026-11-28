import Foundation

public enum JSONValue: Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array(Array<Self>)
    case object([String: Self])

    public init(_ value: some BinaryInteger) {
        self = .number(Double(value))
    }

    public init(_ value: some BinaryFloatingPoint) {
        self = .number(Double(value))
    }

    public init(_ date: Date) {
        self = .string(BridgeJSON.format(date))
    }

    public init(_ url: URL) {
        self = .string(url.absoluteString)
    }

    public func decode<T: Decodable>(_: T.Type) throws -> T {
        try BridgeJSON.decoder().decode(T.self, from: BridgeJSON.encoder().encode(self))
    }

    var string: String? {
        switch self {
        case let .string(value): value
        case let .number(value):
            if value.rounded() == value, abs(value) < 1e15 { String(Int(value)) } else { String(value) }
        case let .bool(value): String(value)
        case .null, .array, .object: nil
        }
    }

    var number: Double? {
        switch self {
        case let .number(value): value
        case let .string(value): Double(value.trimmingCharacters(in: .whitespaces))
        case .null, .bool, .array, .object: nil
        }
    }

    var isTrue: Bool {
        switch self {
        case let .bool(value): value
        case let .number(value): value != 0
        case let .string(value): value != "false"
        case .null: false
        case .array, .object: true
        }
    }

    var date: Date? {
        guard case let .string(string) = self else { return nil }
        return BridgeJSON.date(from: string)
    }

    var object: Any {
        switch self {
        case .null: NSNull()
        case let .bool(value): value
        case let .number(value): value
        case let .string(value): value
        case let .array(values): values.map(\.object)
        case let .object(values): values.mapValues(\.object)
        }
    }
}

extension JSONValue: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Array<Self>.self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: Self].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case let .bool(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .string(value): try container.encode(value)
        case let .array(values): try container.encode(values)
        case let .object(values): try container.encode(values)
        }
    }
}

extension JSONValue: ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral, ExpressibleByStringLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral
{
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: Self...) { self = .array(elements) }

    public init(dictionaryLiteral elements: (String, Self)...) {
        self = .object(Dictionary(elements, uniquingKeysWith: { _, last in last }))
    }
}

nonisolated enum BridgeJSON {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(format(date))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let milliseconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: milliseconds / 1000)
            }
            let text = try container.decode(String.self)
            guard let date = date(from: text) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Expected an ISO 8601 date, but found \"\(text)\".")
            }
            return date
        }
        return decoder
    }

    static func format(_ date: Date) -> String {
        date.ISO8601Format(.init(includingFractionalSeconds: true))
    }

    static func date(from text: String) -> Date? {
        (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
            ?? (try? Date.ISO8601FormatStyle().parse(text))
    }
}
