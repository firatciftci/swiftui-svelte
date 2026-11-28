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
        var isFocused = false
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
    var tracksPresses: Bool {
        name != "btn" && ["tap", "longpress", "drag"].contains(where: listens(to:)) && hasButtonFeedback
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
    @ObservationIgnored var isFocused: Bool {
        get { extras?.isFocused ?? false }
        set { if newValue || extras != nil { extended().isFocused = newValue } }
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

    var location: String? { attributes["data-loc"]?.string }

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
    nonisolated static let protocolVersion = 3

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
    @ObservationIgnored let diagnostics: Diagnostics

    init(diagnostics: Diagnostics = Diagnostics()) {
        self.diagnostics = diagnostics
    }

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
        let batch: Batch
        switch decode(json) {
        case let .failure(failure):
            Diagnostics.logger.error("\(failure.description, privacy: .public)")
            error = failure.description
            return false
        case let .success(decoded):
            batch = decoded
        }
        if let version = batch.incompatibleVersion {
            bundleProtocolVersion = version
            isCompatible = false
            return true
        }
        if batch.hasRoot {
            bundleProtocolVersion = Self.protocolVersion
            isCompatible = true
        }
        perform(batch)
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

    private func decode(_ json: String) -> Result<Batch, BridgeError> {
        var json = json
        let names = names
        let nodes = nodes
        return json.withUTF8 { bytes in
            var reader = BridgeReader(bytes)
            var batch = Batch(names: names)
            var shadow = Shadow(nodes: nodes)
            return Result { () throws(BridgeError) -> Batch in
                try reader.open()
                while try !reader.isAtEnd() {
                    if let operation = try Self.operation(&reader, &batch, &shadow) {
                        batch.operations.append(operation)
                    }
                    if batch.incompatibleVersion != nil { return batch }
                }
                try reader.finish()
                return batch
            }
        }
    }

    private static func operation(
        _ reader: inout BridgeReader,
        _ batch: inout Batch,
        _ shadow: inout Shadow
    ) throws(BridgeError) -> Operation? {
        switch try reader.int() {
        case 0:
            let id = try reader.int()
            let version = try reader.int()
            guard version == protocolVersion else {
                batch.incompatibleVersion = version
                return nil
            }
            let mount = try reader.int()
            shadow.create(id)
            batch.hasRoot = true
            return .root(id: id, mount: mount)
        case 1:
            let parent = try reader.int()
            let before = try reader.int()
            let record = try record(&reader, batch.names)
            guard shadow.isAlive(parent) else { throw BridgeError(description: "Insert into unknown parent \(parent)") }
            try shadow.insert(record, under: parent)
            return .insert(parent: parent, before: before, record: record)
        case 2:
            let parent = try reader.int()
            let before = try reader.int()
            let id = try reader.int()
            guard shadow.isAlive(parent) else { throw BridgeError(description: "Move into unknown parent \(parent)") }
            try shadow.move(id, under: parent)
            return .move(parent: parent, before: before, id: id)
        case 3:
            let id = try reader.int()
            shadow.remove(id)
            return .remove(id)
        case 4:
            let id = try reader.int()
            let name = try name(try reader.int(), in: batch.names)
            let value = try reader.value()
            return .attribute(id: id, name: name, value: value == .null ? nil : value)
        case 5:
            let id = try reader.int()
            return .attribute(id: id, name: try name(try reader.int(), in: batch.names), value: nil)
        case 6:
            let id = try reader.int()
            return .text(id: id, text: try reader.string())
        case 7:
            batch.names.append(try reader.string())
            return nil
        case let opcode:
            throw BridgeError(description: "Unknown opcode \(opcode)")
        }
    }

    private static func name(_ ref: Int, in names: Array<String>) throws(BridgeError) -> String {
        guard names.indices.contains(ref) else { throw BridgeError(description: "Unknown name \(ref)") }
        return names[ref]
    }

    private static func record(_ reader: inout BridgeReader, _ names: Array<String>) throws(BridgeError) -> Record {
        let id = try reader.int()
        guard id != 0 else { throw BridgeError(description: "Node record with ID 0") }
        if id < 0 { return Record(id: -id, name: nil, text: try reader.string(), attributes: [:], children: []) }
        let name = try name(try reader.int(), in: names)
        var attributes: [String: JSONValue] = [:]
        for _ in 0..<max(0, try reader.int()) {
            let key = try Self.name(try reader.int(), in: names)
            let value = try reader.value()
            if value != .null { attributes[key] = value }
        }
        let count = max(0, try reader.int())
        var children: Array<Record> = []
        children.reserveCapacity(count)
        for _ in 0..<count { children.append(try record(&reader, names)) }
        return Record(id: id, name: name, text: "", attributes: attributes, children: children)
    }

    private func perform(_ batch: Batch) {
        names = batch.names
        for operation in batch.operations {
            switch operation {
            case let .root(id, mount):
                let root = nodes[id] ?? Node(id: id, kind: .fragment, name: "", text: "")
                nodes[id] = root
                roots[mount] = root
            case let .insert(parentID, beforeID, record):
                guard let parent = nodes[parentID] else { continue }
                let node = make(record)
                insert(node, into: parent, before: nodes[beforeID])
                if let curve = MotionTransition.curve(for: node.attributes) { transitions[parentID] = curve }
            case let .move(parentID, beforeID, id):
                guard let parent = nodes[parentID], let node = nodes[id] else { continue }
                insert(node, into: parent, before: nodes[beforeID])
            case let .remove(id):
                guard let node = nodes[id] else { continue }
                if let parentID = node.parentID, let curve = MotionTransition.curve(for: node.attributes) {
                    transitions[parentID] = curve
                }
                detach(node)
                forget(node)
                if !hostIDs.isEmpty { needsHosting = true }
                if node.kind == .fragment { roots = roots.filter { $0.value !== node } }
            case let .attribute(id, name, value):
                nodes[id]?.setOwnAttribute(name, value)
            case let .text(id, text):
                if let node = nodes[id], node.kind == .text, node.text != text { node.text = text }
            }
        }
    }

    private func make(_ record: Record) -> Node {
        guard let name = record.name else {
            let node = Node(id: record.id, kind: .text, name: "", text: record.text)
            nodes[record.id] = node
            return node
        }
        let node = Node(id: record.id, kind: .element, name: name, text: "")
        if let owned = ownedNames[name] { node.owned = owned }
        nodes[record.id] = node
        if Presenting.hoisted.contains(name) { presentationIDs.insert(record.id) }
        node.attributes = record.attributes
        guard !record.children.isEmpty else { return node }
        var children: Array<Node> = []
        children.reserveCapacity(record.children.count)
        for childRecord in record.children {
            let child = make(childRecord)
            child.parentID = record.id
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
            #if DEBUG
                warnAboutWaiting(presented, in: host)
            #endif
        }
        hostIDs = Set(assigned.keys)
    }

    #if DEBUG
        private func warnAboutWaiting(_ presented: Array<Node>, in host: Node) {
            let hostName = host.kind == .fragment ? "SvelteView" : host.name
            for node in Presenting.waiting(presented) {
                diagnostics.report(
                    "A <\(node.name)> is waiting because its <\(hostName)> already shows one, and SwiftUI shows one <\(node.name)> at a time from the same <\(hostName)>. It appears when the first one closes. To show both at once, put the second inside the first.",
                    element: node.name,
                    location: node.location
                )
            }
        }
    #endif
}

private struct Record {
    let id: Int
    let name: String?
    let text: String
    let attributes: [String: JSONValue]
    let children: Array<Record>
}

private enum Operation {
    case root(id: Int, mount: Int)
    case insert(parent: Int, before: Int, record: Record)
    case move(parent: Int, before: Int, id: Int)
    case remove(Int)
    case attribute(id: Int, name: String, value: JSONValue?)
    case text(id: Int, text: String)
}

private struct Batch {
    var names: Array<String>
    var operations: Array<Operation> = []
    var hasRoot = false
    var incompatibleVersion: Int?
}

private struct Shadow {
    let nodes: [Int: Node]
    private var parents: [Int: Int] = [:]
    private var created: Set<Int> = []
    private var recreated: Set<Int> = []
    private var removed: Set<Int> = []

    init(nodes: [Int: Node]) {
        self.nodes = nodes
    }

    func isAlive(_ id: Int) -> Bool {
        guard created.contains(id) || nodes[id] != nil else { return false }
        var current = id
        while !removed.contains(current) {
            if let parent = parents[current] {
                guard parent != 0 else { return true }
                current = parent
                continue
            }
            guard let parent = nodes[current]?.parentID else { return true }
            guard !recreated.contains(parent) else { return false }
            current = parent
        }
        return false
    }

    private func isAncestor(_ ancestor: Int, of id: Int) -> Bool {
        var current: Int? = id
        while let node = current {
            if node == ancestor { return true }
            if let parent = parents[node] {
                current = parent == 0 ? nil : parent
            } else {
                current = nodes[node]?.parentID
            }
        }
        return false
    }

    private mutating func revive(_ id: Int, under parent: Int) {
        if nodes[id] != nil { recreated.insert(id) }
        created.insert(id)
        removed.remove(id)
        parents[id] = parent
    }

    mutating func create(_ id: Int) {
        revive(id, under: 0)
    }

    mutating func insert(_ record: Record, under parent: Int) throws(BridgeError) {
        guard !isAlive(record.id) else {
            throw BridgeError(description: "Insert of node \(record.id), which already exists")
        }
        revive(record.id, under: parent)
        for child in record.children { try insert(child, under: record.id) }
    }

    mutating func move(_ id: Int, under parent: Int) throws(BridgeError) {
        guard isAlive(id) else { return }
        guard !isAncestor(id, of: parent) else {
            throw BridgeError(description: "Move of node \(id) into its own subtree")
        }
        parents[id] = parent
    }

    mutating func remove(_ id: Int) {
        removed.insert(id)
    }
}
