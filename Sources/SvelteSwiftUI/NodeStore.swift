import Observation

@Observable
final class Node: Identifiable {
    enum Kind {
        case fragment, element, text
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
            case .fragment: false
            }
        }
    }
}

@Observable
final class NodeStore {
    static let protocolVersion = 2

    private(set) var root: Node?
    private(set) var bundleProtocolVersion: Int?
    private(set) var isCompatible = true
    private(set) var error: String?
    @ObservationIgnored private var nodes: [Int: Node] = [:]
    @ObservationIgnored private var names: Array<String> = []
    @ObservationIgnored private var dirty: Set<Int> = []

    var nodeCount: Int { nodes.count }

    func node(_ id: Int) -> Node? { nodes[id] }

    func dismissError() {
        error = nil
    }

    func apply(_ json: String) {
        var json = json
        let failure: BridgeError? = json.withUTF8 { bytes in
            var reader = BridgeReader(bytes)
            do throws(BridgeError) {
                try reader.open()
                while try !reader.isAtEnd() {
                    try apply(&reader)
                    guard isCompatible else { return nil }
                }
                try reader.finish()
                return nil
            } catch {
                return error
            }
        }
        if let failure {
            print("[bridge] \(failure)")
            error = failure.description
        }
        for id in dirty {
            guard let parent = nodes[id] else { continue }
            parent.children = children(of: parent)
        }
        dirty.removeAll(keepingCapacity: true)
    }

    private func children(of parent: Node) -> Array<Node> {
        var children: Array<Node> = []
        var childID = parent.firstID
        while let id = childID, let child = nodes[id] {
            children.append(child)
            childID = child.nextID
        }
        return children
    }

    private func name(_ ref: Int) throws(BridgeError) -> String {
        guard names.indices.contains(ref) else { throw BridgeError(description: "Unknown name \(ref)") }
        return names[ref]
    }

    private func apply(_ reader: inout BridgeReader) throws(BridgeError) {
        switch try reader.int() {
        case 0:
            let id = try reader.int()
            let version = try reader.int()
            if nodes[id] == nil { nodes[id] = Node(id: id, kind: .fragment, name: "", text: "") }
            bundleProtocolVersion = version
            isCompatible = version == Self.protocolVersion
            root = isCompatible ? nodes[id] : nil
        case 1:
            let parentID = try reader.int()
            let beforeID = try reader.int()
            let node = try read(&reader)
            guard let parent = nodes[parentID] else {
                forget(node)
                return
            }
            insert(node, into: parent, before: nodes[beforeID])
        case 2:
            let parentID = try reader.int()
            let beforeID = try reader.int()
            let id = try reader.int()
            guard let parent = nodes[parentID], let node = nodes[id] else { return }
            insert(node, into: parent, before: nodes[beforeID])
        case 3:
            guard let node = nodes[try reader.int()] else { return }
            detach(node)
            forget(node)
        case 4:
            let id = try reader.int()
            let name = try name(try reader.int())
            let value = try reader.value()
            if let node = nodes[id], node.attributes[name] != value { node.attributes[name] = value }
        case 5:
            let id = try reader.int()
            let name = try name(try reader.int())
            if let node = nodes[id], node.attributes[name] != nil { node.attributes[name] = nil }
        case 6:
            let id = try reader.int()
            let text = try reader.string()
            if let node = nodes[id], node.text != text { node.text = text }
        case 7:
            names.append(try reader.string())
        case let opcode:
            throw BridgeError(description: "Unknown opcode \(opcode)")
        }
    }

    private func read(_ reader: inout BridgeReader) throws(BridgeError) -> Node {
        let id = try reader.int()
        if id < 0 {
            let node = Node(id: -id, kind: .text, name: "", text: try reader.string())
            nodes[-id] = node
            return node
        }
        let node = Node(id: id, kind: .element, name: try name(try reader.int()), text: "")
        nodes[id] = node
        var attributes: [String: JSONValue] = [:]
        for _ in 0..<max(0, try reader.int()) {
            let name = try name(try reader.int())
            attributes[name] = try reader.value()
        }
        node.attributes = attributes
        let count = try reader.int()
        guard count > 0 else { return node }
        var children: Array<Node> = []
        children.reserveCapacity(count)
        for _ in 0..<count {
            let child = try read(&reader)
            child.parentID = id
            child.previousID = children.last?.id
            children.last?.nextID = child.id
            children.append(child)
        }
        node.firstID = children.first?.id
        node.lastID = children.last?.id
        node.children = children
        return node
    }

    private func forget(_ node: Node) {
        nodes[node.id] = nil
        var childID = node.firstID
        while let id = childID, let child = nodes[id] {
            childID = child.nextID
            forget(child)
        }
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
        let next = next?.parentID == parent.id ? next : nil
        let previousID = next.map(\.previousID) ?? parent.lastID
        node.previousID = previousID
        node.nextID = next?.id
        if let previousID { nodes[previousID]?.nextID = node.id } else { parent.firstID = node.id }
        if let next { next.previousID = node.id } else { parent.lastID = node.id }
        node.parentID = parent.id
        dirty.insert(parent.id)
    }
}
