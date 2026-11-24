import Foundation
import Observation

enum JSONValue: Decodable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array(Array<Self>)
    case object([String: Self])

    init(from decoder: Decoder) throws {
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

    var string: String? {
        if case let .string(value) = self { value } else { nil }
    }

    var number: Double? {
        if case let .number(value) = self { value } else { nil }
    }
}

@Observable
final class Node: Identifiable {
    enum Kind: String, Decodable {
        case fragment, element, text, comment
    }

    let id: Int
    let kind: Kind
    let name: String
    var text: String
    var attributes: [String: JSONValue] = [:]
    var children: Array<Node> = []
    @ObservationIgnored var parentID: Int?
    @ObservationIgnored var previousID: Int?
    @ObservationIgnored var nextID: Int?
    @ObservationIgnored var firstID: Int?
    @ObservationIgnored var lastID: Int?

    init(id: Int, kind: Kind, name: String, text: String) {
        self.id = id
        self.kind = kind
        self.name = name
        self.text = text
    }

    private static let attachments: Set<String> = ["alert", "sheet", "swipeactions", "toolbar"]

    func attachment(_ name: String) -> Node? {
        children.first { $0.kind == .element && $0.name == name }
    }

    func attachments(_ name: String) -> Array<Node> {
        children.filter { $0.kind == .element && $0.name == name }
    }

    var renderedChildren: Array<Node> {
        children.filter { child in
            switch child.kind {
            case .element: !Self.attachments.contains(child.name)
            case .text: !child.text.allSatisfy(\.isWhitespace)
            case .fragment, .comment: false
            }
        }
    }
}

enum Op: Decodable {
    case root(id: Int)
    case create(id: Int, kind: Node.Kind, name: String?, text: String?)
    case insert(parent: Int, id: Int, before: Int?)
    case remove(id: Int)
    case attribute(id: Int, name: String, value: JSONValue)
    case removeAttribute(id: Int, name: String)
    case text(id: Int, text: String)
    case release(id: Int)

    private enum CodingKeys: String, CodingKey {
        case op, id, kind, name, text, parent, before, value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(Int.self, forKey: .id)
        switch try container.decode(String.self, forKey: .op) {
        case "root":
            self = .root(id: id)
        case "create":
            self = .create(
                id: id,
                kind: try container.decode(Node.Kind.self, forKey: .kind),
                name: try container.decodeIfPresent(String.self, forKey: .name),
                text: try container.decodeIfPresent(String.self, forKey: .text)
            )
        case "insert":
            self = .insert(
                parent: try container.decode(Int.self, forKey: .parent),
                id: id,
                before: try container.decodeIfPresent(Int.self, forKey: .before)
            )
        case "remove":
            self = .remove(id: id)
        case "attr":
            self = .attribute(
                id: id,
                name: try container.decode(String.self, forKey: .name),
                value: try container.decodeIfPresent(JSONValue.self, forKey: .value) ?? .null
            )
        case "unattr":
            self = .removeAttribute(id: id, name: try container.decode(String.self, forKey: .name))
        case "text":
            self = .text(id: id, text: try container.decode(String.self, forKey: .text))
        case "release":
            self = .release(id: id)
        case let op:
            throw DecodingError.dataCorruptedError(
                forKey: .op, in: container, debugDescription: "Unknown op \(op)")
        }
    }
}

@Observable
final class NodeStore {
    private(set) var root: Node?
    @ObservationIgnored private var nodes: [Int: Node] = [:]
    @ObservationIgnored private var dirty: Set<Int> = []

    var nodeCount: Int { nodes.count }

    func node(_ id: Int) -> Node? { nodes[id] }

    func apply(_ json: String) {
        let ops: Array<Op>
        do {
            ops = try JSONDecoder().decode(Array<Op>.self, from: Data(json.utf8))
        } catch {
            print("[bridge] \(error)")
            return
        }
        for op in ops { apply(op) }
        for id in dirty {
            guard let parent = nodes[id] else { continue }
            var children: Array<Node> = []
            var childID = parent.firstID
            while let id = childID, let child = nodes[id] {
                children.append(child)
                childID = child.nextID
            }
            parent.children = children
        }
        dirty.removeAll(keepingCapacity: true)
    }

    private func detach(_ node: Node) {
        guard let parentID = node.parentID, let parent = nodes[parentID] else { return }
        if let previousID = node.previousID {
            nodes[previousID]?.nextID = node.nextID
        } else {
            parent.firstID = node.nextID
        }
        if let nextID = node.nextID {
            nodes[nextID]?.previousID = node.previousID
        } else {
            parent.lastID = node.previousID
        }
        node.parentID = nil
        node.previousID = nil
        node.nextID = nil
        dirty.insert(parentID)
    }

    private func insert(_ node: Node, into parent: Node, before next: Node?) {
        detach(node)
        let previousID = next.map(\.previousID) ?? parent.lastID
        node.previousID = previousID
        node.nextID = next?.id
        if let previousID { nodes[previousID]?.nextID = node.id } else { parent.firstID = node.id }
        if let next { next.previousID = node.id } else { parent.lastID = node.id }
        node.parentID = parent.id
        dirty.insert(parent.id)
    }

    private func apply(_ op: Op) {
        switch op {
        case let .root(id):
            root = nodes[id]
        case let .create(id, kind, name, text):
            nodes[id] = Node(id: id, kind: kind, name: name ?? "", text: text ?? "")
        case let .insert(parentID, id, beforeID):
            guard let parent = nodes[parentID], let node = nodes[id] else { return }
            insert(node, into: parent, before: beforeID.flatMap { nodes[$0] })
        case let .remove(id):
            if let node = nodes[id] { detach(node) }
        case let .attribute(id, name, value):
            nodes[id]?.attributes[name] = value
        case let .removeAttribute(id, name):
            nodes[id]?.attributes[name] = nil
        case let .text(id, text):
            nodes[id]?.text = text
        case let .release(id):
            if let node = nodes[id] { detach(node) }
            nodes[id] = nil
        }
    }
}
