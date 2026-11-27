import Observation
import SwiftUI

@Observable
final class Node: Identifiable {
    enum Kind {
        case fragment, element, text
    }

    private final class Extras {
        var owned: Set<String> = []
        var labelFeedback: [String: JSONValue] = [:]
        var stateFeedback: [String: JSONValue] = [:]
        var presented: Array<Node> = []
        var focusRequest = FocusRequest()
        var frame: CGRect?
    }

    let id: Int
    let name: String
    var text: String {
        didSet {
            let isBlank = text.allSatisfy(\.isWhitespace)
            if isBlank != self.isBlank { self.isBlank = isBlank }
        }
    }
    private(set) var ownAttributes: [String: JSONValue] = [:] {
        didSet { enable(ModifierSet(attributes: ownAttributes)) }
    }
    var children: Array<Node> = [] {
        didSet {
            var attached: ModifierSet = []
            for child in children where child.kind == .element {
                if let set = ModifierSet.byAttachment[child.name] { attached.formUnion(set) }
                if !hostsPresentations, Presenting.anchored.contains(child.name) { hostsPresentations = true }
                if !hasMultiViewChild, Self.multiViewChildren.contains(child.name) { hasMultiViewChild = true }
            }
            enable(attached)
        }
    }
    @ObservationIgnored private var extras: Extras?
    @ObservationIgnored private var parent = 0
    @ObservationIgnored private var previous = 0
    @ObservationIgnored private var next = 0
    @ObservationIgnored private var first = 0
    @ObservationIgnored private var last = 0
    private(set) var modifiers: ModifierSet = []
    let kind: Kind
    private(set) var isBlank: Bool
    var hostsPresentations: Bool
    private(set) var hasMultiViewChild = false
    var hostsInspector: Bool
    var isMeasured = false {
        didSet { if isMeasured { enable(.measured) } }
    }

    var nativeAttributes: [String: JSONValue] {
        guard !labelFeedback.isEmpty || !stateFeedback.isEmpty else { return ownAttributes }
        return ownAttributes.merging(labelFeedback) { _, override in override }
            .merging(stateFeedback) { _, override in override }
    }
    var ownsButtonFeedback: Bool {
        ButtonFeedback(attributes["pressed"]) != nil || ButtonFeedback(attributes["hovered"]) != nil
    }
    var hasButtonFeedback: Bool {
        ownsButtonFeedback || children.contains(where: \.hasButtonFeedback)
    }
    var attributes: [String: JSONValue] {
        get {
            guard !owned.isEmpty else { return nativeAttributes }
            var visible = nativeAttributes.filter { !owned.contains($0.key) }
            if case let .array(events) = nativeAttributes["listens"] {
                visible["listens"] = .array(events.filter { !owned.contains($0.string ?? "") })
            }
            return visible
        }
        set { ownAttributes = newValue }
    }
    var owned: Set<String> {
        get {
            access(keyPath: \.owned)
            return extras?.owned ?? []
        }
        set {
            guard newValue != extras?.owned ?? [] else { return }
            withMutation(keyPath: \.owned) { extended().owned = newValue }
        }
    }
    var labelFeedback: [String: JSONValue] {
        get {
            access(keyPath: \.labelFeedback)
            return extras?.labelFeedback ?? [:]
        }
        set {
            guard newValue != extras?.labelFeedback ?? [:] else { return }
            withMutation(keyPath: \.labelFeedback) { extended().labelFeedback = newValue }
            enable(ModifierSet(attributes: newValue))
        }
    }
    var stateFeedback: [String: JSONValue] {
        get {
            access(keyPath: \.stateFeedback)
            return extras?.stateFeedback ?? [:]
        }
        set {
            guard newValue != extras?.stateFeedback ?? [:] else { return }
            withMutation(keyPath: \.stateFeedback) { extended().stateFeedback = newValue }
            enable(ModifierSet(attributes: newValue))
        }
    }
    var presented: Array<Node> {
        get {
            access(keyPath: \.presented)
            return extras?.presented ?? []
        }
        set {
            withMutation(keyPath: \.presented) { extended().presented = newValue }
            if !hostsInspector, newValue.contains(where: { $0.name == "inspector" }) { hostsInspector = true }
        }
    }
    var focusRequest: FocusRequest {
        get {
            access(keyPath: \.focusRequest)
            return extras?.focusRequest ?? FocusRequest()
        }
        set { withMutation(keyPath: \.focusRequest) { extended().focusRequest = newValue } }
    }
    var frame: CGRect? {
        get { extras?.frame }
        set { if newValue != nil || extras != nil { extended().frame = newValue } }
    }
    var parentID: Int? {
        get { Self.link(parent) }
        set { parent = newValue ?? 0 }
    }
    var previousID: Int? {
        get { Self.link(previous) }
        set { previous = newValue ?? 0 }
    }
    var nextID: Int? {
        get { Self.link(next) }
        set { next = newValue ?? 0 }
    }
    var firstID: Int? {
        get { Self.link(first) }
        set { first = newValue ?? 0 }
    }
    var lastID: Int? {
        get { Self.link(last) }
        set { last = newValue ?? 0 }
    }

    init(id: Int, kind: Kind, name: String, text: String) {
        self.id = id
        self.kind = kind
        self.name = name
        self.text = text
        isBlank = text.allSatisfy(\.isWhitespace)
        hostsPresentations = kind == .fragment || Presenting.hosts.contains(name)
        hostsInspector = name == "screen"
    }

    static let attachments: Set<String> = Presenting.names.union([
        "background", "contextmenu", "maskview", "overlay", "safeareainset", "searchable", "swipeactions", "toolbar",
        "toolbarspacer",
    ])
    private static let multiViewChildren = NodeView.multiView.subtracting(attachments)
    private static let slots: [String: Set<String>] = [
        "asyncimage": ["placeholder", "failure"], "contextmenu": ["preview"], "controlgroup": ["label"], "labelview": ["icon"],
        "disclosuregroup": ["label"],
        "groupbox": ["label"], "picker": ["label"], "labeledcontent": ["label"], "menuview": ["label"],
        "contentunavailableview": ["label"],
        "sectionview": ["header", "footer"],
    ]

    func setOwnAttribute(_ name: String, _ value: JSONValue?) {
        guard ownAttributes[name] != value else { return }
        ownAttributes[name] = value
    }

    private static func link(_ id: Int) -> Int? {
        id == 0 ? nil : id
    }

    private func extended() -> Extras {
        if let extras { return extras }
        let extras = Extras()
        self.extras = extras
        return extras
    }

    private func enable(_ set: ModifierSet) {
        if !modifiers.isSuperset(of: set) { modifiers.formUnion(set) }
    }

    func attachment(_ name: String) -> Node? {
        children.first { $0.kind == .element && $0.name == name }
    }

    var renderedChildren: Array<Node> {
        let slots = Self.slots[name] ?? []
        return children.filter { child in
            switch child.kind {
            case .element: !Self.attachments.contains(child.name) && !slots.contains(child.name)
            case .text: !child.isBlank
            case .fragment: false
            }
        }
    }
}

@Observable
final class NodeStore {
    static let protocolVersion = 3

    private(set) var roots: [Int: Node] = [:]
    private(set) var bundleProtocolVersion: Int?
    private(set) var isCompatible = true
    private(set) var error: String?
    @ObservationIgnored private var nodes: [Int: Node] = [:]
    @ObservationIgnored private var names: Array<String> = []
    @ObservationIgnored private var dirty: Set<Int> = []
    @ObservationIgnored private var transitions: [Int: MotionCurve] = [:]
    @ObservationIgnored private var presentationIDs: Set<Int> = []
    @ObservationIgnored private var hostIDs: Set<Int> = []
    @ObservationIgnored private var needsHosting = false
    @ObservationIgnored private var ownedNames: [String: Set<String>] = [:]

    var nodeCount: Int { nodes.count }

    func node(_ id: Int) -> Node? { nodes[id] }

    func root(for mount: Int?) -> Node? { mount.flatMap { roots[$0] } }

    func dismissError() {
        error = nil
    }

    func reset(ownedNames: [String: Set<String>]) {
        roots = [:]
        bundleProtocolVersion = nil
        isCompatible = true
        nodes = [:]
        names = []
        dirty = []
        transitions = [:]
        presentationIDs = []
        hostIDs = []
        needsHosting = false
        self.ownedNames = ownedNames
    }

    @discardableResult
    func apply(_ json: String, animation: String? = nil) -> Bool {
        guard let animation, let value = try? JSONValue(parsing: animation) else { return commit(json) }
        var transaction = Transaction(animation: MotionCurve(value)?.animation)
        transaction.disablesAnimations = value == .bool(false)
        return withTransaction(transaction) { commit(json) }
    }

    private func commit(_ json: String) -> Bool {
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
            return false
        }
        if error != nil { error = nil }
        if needsHosting { assignHosts() }
        for id in dirty {
            guard let parent = nodes[id] else { continue }
            let children = children(of: parent)
            if let curve = transitions[id] {
                withAnimation(curve.animation) { parent.children = children }
            } else {
                parent.children = children
            }
        }
        dirty.removeAll(keepingCapacity: true)
        transitions.removeAll(keepingCapacity: true)
        return true
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
            bundleProtocolVersion = version
            isCompatible = version == Self.protocolVersion
            guard isCompatible else { return }
            let mount = try reader.int()
            let root = nodes[id] ?? Node(id: id, kind: .fragment, name: "", text: "")
            nodes[id] = root
            roots[mount] = root
        case 1:
            let parentID = try reader.int()
            let beforeID = try reader.int()
            let node = try read(&reader)
            guard let parent = nodes[parentID] else {
                forget(node)
                return
            }
            insert(node, into: parent, before: nodes[beforeID])
            if let curve = MotionTransition.curve(for: node.attributes) { transitions[parentID] = curve }
        case 2:
            let parentID = try reader.int()
            let beforeID = try reader.int()
            let id = try reader.int()
            guard let parent = nodes[parentID], let node = nodes[id] else { return }
            insert(node, into: parent, before: nodes[beforeID])
        case 3:
            guard let node = nodes[try reader.int()] else { return }
            if let parentID = node.parentID, let curve = MotionTransition.curve(for: node.attributes) {
                transitions[parentID] = curve
            }
            detach(node)
            forget(node)
            if !hostIDs.isEmpty { needsHosting = true }
            if node.kind == .fragment { roots = roots.filter { $0.value !== node } }
        case 4:
            let id = try reader.int()
            let name = try name(try reader.int())
            let value = try reader.value()
            nodes[id]?.setOwnAttribute(name, value == .null ? nil : value)
        case 5:
            let id = try reader.int()
            let name = try name(try reader.int())
            nodes[id]?.setOwnAttribute(name, nil)
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
        if let owned = ownedNames[node.name] { node.owned = owned }
        nodes[id] = node
        if Presenting.hoisted.contains(node.name) { presentationIDs.insert(id) }
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
        presentationIDs.remove(node.id)
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
        guard next !== node else { return }
        detach(node)
        let next = next?.parentID == parent.id ? next : nil
        let previousID = next.map(\.previousID) ?? parent.lastID
        node.previousID = previousID
        node.nextID = next?.id
        if let previousID { nodes[previousID]?.nextID = node.id } else { parent.firstID = node.id }
        if let next { next.previousID = node.id } else { parent.lastID = node.id }
        node.parentID = parent.id
        dirty.insert(parent.id)
        if !presentationIDs.isEmpty || !hostIDs.isEmpty { needsHosting = true }
    }

    private func host(of node: Node) -> Node? {
        var current = node
        while let parentID = current.parentID {
            guard let parent = nodes[parentID] else { return nil }
            if parent.kind == .fragment || Presenting.hosts.contains(parent.name) { return parent }
            current = parent
        }
        return nil
    }

    private func assignHosts() {
        needsHosting = false
        var assigned: [Int: Array<Node>] = [:]
        for id in presentationIDs.sorted() {
            guard let node = nodes[id], let host = host(of: node) else { continue }
            assigned[host.id, default: []].append(node)
        }
        for id in hostIDs.subtracting(assigned.keys) {
            if let host = nodes[id], !host.presented.isEmpty { host.presented = [] }
        }
        for (id, presented) in assigned {
            guard let host = nodes[id], host.presented.map(\.id) != presented.map(\.id) else { continue }
            host.presented = presented
        }
        hostIDs = Set(assigned.keys)
    }
}
