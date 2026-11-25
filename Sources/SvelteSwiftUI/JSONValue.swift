import Foundation

enum JSONValue: Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array(Array<Self>)
    case object([String: Self])

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
        return (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string))
            ?? (try? Date.ISO8601FormatStyle().parse(string))
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
