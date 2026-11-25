import Foundation

@testable import SvelteSwiftUI

func quoted(_ string: String) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    return (try? encoder.encode(string)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "\"\""
}

extension JSONValue {
    var canonical: String {
        switch self {
        case .null: "null"
        case let .bool(value): value ? "true" : "false"
        case let .number(value): value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : "\(value)"
        case let .string(value): quoted(value)
        case let .array(values): "[\(values.map(\.canonical).joined(separator: ","))]"
        case let .object(values):
            "{\(values.keys.sorted().map { "\(quoted($0)):\(values[$0]?.canonical ?? "null")" }.joined(separator: ","))}"
        }
    }
}

func dump(_ node: Node?, depth: Int = 0) -> String {
    guard let node else { return "" }
    let indent = String(repeating: "  ", count: depth)
    let line =
        switch node.kind {
        case .element:
            "\(indent)<\(node.name)\(node.attributes.keys.sorted().map { " \($0)=\(node.attributes[$0]?.canonical ?? "null")" }.joined())>"
        case .fragment: "\(indent)#fragment"
        case .text: "\(indent)#text \(quoted(node.text))"
        }
    return ([line] + node.children.map { dump($0, depth: depth + 1) }).joined(separator: "\n")
}

extension NodeStore {
    var root: Node? { roots.max { $0.key < $1.key }?.value }
}
