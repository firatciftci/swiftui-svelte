import CoreFoundation
import Observation

@Observable
final class Node: Identifiable {
    enum Kind {
        case fragment, element, text
    }

    struct Feedback: Equatable {
        var label: [String: JSONValue] = [:]
        var state: [String: JSONValue] = [:]

        var isEmpty: Bool { label.isEmpty && state.isEmpty }
    }

    private final class Extras {
        var owned: Set<String> = []
        var feedback = Feedback()
        var native: [String: JSONValue]?
        var visible: [String: JSONValue]?
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
        didSet { invalidate() }
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
        let own = ownAttributes
        let feedback = feedback
        guard let extras, !feedback.isEmpty else { return own }
        if let native = extras.native { return native }
        let native = own.merging(feedback.label) { _, override in override }
            .merging(feedback.state) { _, override in override }
        extras.native = native
        return native
    }
    var ownsButtonFeedback: Bool {
        ButtonFeedback(attributes["pressed"]) != nil || ButtonFeedback(attributes["hovered"]) != nil
    }
    private(set) var hasButtonFeedback = false
    var tracksPresses: Bool {
        name != "btn" && ["tap", "longpress", "drag"].contains(where: listens(to:)) && hasButtonFeedback
    }
    var attributes: [String: JSONValue] {
        let owned = owned
        let native = nativeAttributes
        guard let extras, !owned.isEmpty else { return native }
        if let visible = extras.visible { return visible }
        var visible = native.filter { !owned.contains($0.key) }
        if case let .array(events) = native["listens"] {
            visible["listens"] = .array(events.filter { !owned.contains($0.string ?? "") })
        }
        extras.visible = visible
        return visible
    }
    var owned: Set<String> {
        get {
            access(keyPath: \.owned)
            return extras?.owned ?? []
        }
        set {
            guard newValue != extras?.owned ?? [] else { return }
            withMutation(keyPath: \.owned) { extended().owned = newValue }
            invalidate()
        }
    }
    var feedback: Feedback {
        get {
            access(keyPath: \.feedback)
            return extras?.feedback ?? Feedback()
        }
        set {
            guard newValue != extras?.feedback ?? Feedback() else { return }
            withMutation(keyPath: \.feedback) { extended().feedback = newValue }
            enable(ModifierSet(attributes: newValue.label))
            enable(ModifierSet(attributes: newValue.state))
            invalidate()
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
    static let childOnly = Set(slots.values.joined()).union(["choice", "tabsection"])

    func setOwnAttributes(_ attributes: [String: JSONValue]) {
        guard ownAttributes != attributes else { return }
        ownAttributes = attributes
        enable(ModifierSet(attributes: attributes))
    }

    func setOwnAttribute(_ name: String, _ value: JSONValue?) {
        guard ownAttributes[name] != value else { return }
        ownAttributes[name] = value
        if let value { enable(ModifierSet(attribute: name, value: value)) }
    }

    @discardableResult
    func refreshButtonFeedback() -> Bool {
        let hasFeedback = ownsButtonFeedback || children.contains(where: \.hasButtonFeedback)
        guard hasFeedback != hasButtonFeedback else { return false }
        hasButtonFeedback = hasFeedback
        return true
    }

    private func invalidate() {
        extras?.native = nil
        extras?.visible = nil
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

    func declare(_ names: Array<String>) {
        var declared: ModifierSet = []
        for name in names { declared.formUnion(ModifierSet.byAttribute[name] ?? []) }
        enable(declared)
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
