import SwiftUI

struct NodeView: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        switch node.kind {
        case .text:
            Text(node.text)
        case .element:
            element.modifier(NodeModifiers(node: node))
                .layoutPriority(node.name == "spacer" ? -1 : 0)
        case .fragment:
            children
        }
    }

    private var children: some View {
        ForEach(node.renderedChildren) { Self(node: $0) }
    }

    @ViewBuilder private var element: some View {
        switch node.name {
        case "navstack":
            NavStack(node: node)
        case "screen":
            Screen(node: node)
        case "sheet", "swipeactions", "tab", "toolbar":
            Group { children }
        case "tabview":
            Tabs(node: node)
        case "vstack":
            VStack(alignment: Styles.horizontalAlignment(alignment), spacing: spacing) { children }
        case "hstack":
            HStack(alignment: Styles.verticalAlignment(alignment), spacing: spacing) { children }
        case "lazyvstack", "lazyhstack", "lazyvgrid", "lazyhgrid", "grid", "gridrow", "viewthatfits", "group", "groupbox",
            "controlgroup", "disclosuregroup":
            Container(node: node)
        case "rectangle", "roundedrectangle", "unevenroundedrectangle", "circleshape", "ellipseshape", "capsule", "pathshape":
            ShapeElement(node: node)
        case "zstack":
            ZStack(alignment: Styles.alignment(alignment)) { children }
        case "scrollview":
            ScrollView(Self.axes(node.attributes["axes"]?.string)) {
                if node.attributes["snap"]?.string == "view" {
                    children.scrollTargetLayout()
                } else {
                    children
                }
            }
            .modifier(Scrollable())
            .modifier(ScrollOptions(node: node))
        case "list":
            List { children }.modifier(Scrollable()).modifier(ScrollOptions(node: node))
        case "formview":
            Form { children }
        case "sectionview":
            Section {
                children
            } header: {
                if let header = node.attachment("header") {
                    Slot(node: header)
                } else if let header = node.attributes["header"]?.string {
                    Text(header)
                }
            } footer: {
                if let footer = node.attachment("footer") {
                    Slot(node: footer)
                } else if let footer = node.attributes["footer"]?.string {
                    Text(footer)
                }
            }
        case "spacer":
            Spacer(minLength: node.attributes["minlength"]?.number.map { CGFloat($0) })
        case "divider":
            Divider()
        case "txt":
            TextView(node: node)
        case "asyncimage":
            RemoteImage(node: node)
        case "imageview":
            ImageElement(node: node)
        case "labelview":
            LabelElement(node: node)
        case "linkview":
            LinkElement(node: node)
        case "sharelink":
            ShareElement(node: node)
        case "sfsymbol":
            Symbol(node: node)
        case "btn":
            let button = Button(role: buttonRole(node)) {
                runtime.dispatch(node.id, "click", waits: false)
            } label: {
                children
            }
            switch node.attributes["variant"]?.string {
            case "automatic": button
            case "bordered": button.buttonStyle(.bordered)
            case "prominent": button.buttonStyle(.borderedProminent)
            default: button.buttonStyle(.borderless)
            }
        case "textfield":
            TextFieldControl(node: node)
        case "toggle":
            Toggle(
                isOn: Binding {
                    node.attributes["checked"]?.isTrue ?? false
                } set: { value in
                    runtime.edit(node, "checked", to: .bool(value), event: "change", payload: value)
                }
            ) {
                children
            }
        case "picker":
            PickerControl(node: node)
        case "slider":
            SliderControl(node: node)
        case "stepper":
            StepperControl(node: node)
        case "datepicker":
            DatePickerControl(node: node)
        case "progressview":
            ProgressControl(node: node)
        default:
            Text("Unknown element <\(node.name)>").foregroundStyle(.red)
        }
    }

    private var spacing: CGFloat? {
        node.attributes["spacing"]?.number.map { CGFloat($0) }
    }

    private static func axes(_ name: String?) -> Axis.Set {
        switch name {
        case "horizontal": .horizontal
        case "both": [.horizontal, .vertical]
        default: .vertical
        }
    }

    private var alignment: String? {
        node.attributes["alignment"]?.string
    }
}

private struct Tabs: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let tabs = node.renderedChildren
        TabView(
            selection: Binding {
                node.attributes["selection"] ?? tabs.first.map { Self.value(of: $0, in: tabs) } ?? .null
            } set: { value in
                runtime.edit(node, "selection", to: value, event: "change", payload: value.object)
            }
        ) {
            ForEach(tabs) { tab in
                NodeView(node: tab)
                    .tabItem {
                        Label(
                            tab.attributes["title"]?.string ?? "",
                            systemImage: tab.attributes["symbol"]?.string ?? "circle")
                    }
                    .tag(Self.value(of: tab, in: tabs))
            }
        }
    }

    private static func value(of tab: Node, in tabs: Array<Node>) -> JSONValue {
        tab.attributes["value"] ?? .number(Double(tabs.firstIndex { $0 === tab } ?? 0))
    }
}

private struct NavStack: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        NavigationStack(
            path: Binding {
                node.renderedChildren.dropFirst().map(\.id)
            } set: { path in
                if path.count < node.renderedChildren.count - 1 {
                    runtime.dispatch(node.id, "pop", path.count)
                }
            }
        ) {
            Group {
                if let root = node.renderedChildren.first { NodeView(node: root) }
            }
            .navigationDestination(for: Int.self) { id in
                if let screen = runtime.store.node(id) { NodeView(node: screen) }
            }
        }
    }
}

private struct NodeModifiers: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        let animation = (MotionCurve(attributes["animation"]) ?? MotionCurve()).animation
        let childIDs = attributes["animated"]?.isTrue == true ? node.children.map(\.id) : nil
        let transition = MotionTransition.transition(for: attributes)
        let styled =
            content
            .ifLet(frame(attributes)) { $0.frame(width: $1.width, height: $1.height) }
            .padding(padding(attributes["padding"]))
            .font(Styles.font(attributes))
            .ifLet(Styles.design(attributes["design"]?.string)) { $0.fontDesign($1) }
            .fontWeight(Styles.weight(attributes["weight"]?.string))
            .ifLet(Palette.style(attributes["color"])) { $0.foregroundStyle($1) }
            .ifLet(Palette.color(attributes["tint"]?.string)) { $0.tint($1) }
            .ifLet(Palette.style(attributes["background"])) { $0.background($1) }
            .ifLet(attributes["radius"]?.number) { $0.clipShape(.rect(cornerRadius: $1)) }
            .opacity(attributes["opacity"]?.number ?? 1)
            .ifLet(attributes["testid"]?.string) { $0.accessibilityIdentifier($1) }
            .modifier(Layers(node: node))
            .modifier(Measured(node: node))
            .modifier(GridCell(attributes: attributes))
            .modifier(Resizing(node: node))
            .ifLet(attributes["lang"]?.string.flatMap { $0.isEmpty ? nil : Locale(identifier: $0) }) {
                $0.environment(\.locale, $1)
            }
            .ifLet(Styles.layoutDirection(attributes["dir"]?.string)) { $0.environment(\.layoutDirection, $1) }
        styled
            .ifLet(childIDs) { $0.animation(animation, value: $1) }
            .ifLet(transition) { $0.transition($1) }
            .ifLet(node.attachment("swipeactions")) { view, actions in
                view.swipeActions(edge: actions.attributes["edge"]?.string == "leading" ? .leading : .trailing) {
                    ForEach(actions.renderedChildren) { ActionButton(node: $0) }
                }
            }
    }

    private func frame(_ attributes: [String: JSONValue]) -> (width: CGFloat?, height: CGFloat?)? {
        let width = attributes["width"]?.number.map { CGFloat($0) }
        let height = attributes["height"]?.number.map { CGFloat($0) }
        return width == nil && height == nil ? nil : (width, height)
    }

    private func padding(_ value: JSONValue?) -> CGFloat {
        switch value {
        case let .number(length): length
        case .bool(true): 16
        default: 0
        }
    }
}

private struct Screen: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let alert = node.attachment("alert")
        Group {
            Slot(node: node)
        }
        .navigationTitle(node.attributes["title"]?.string ?? "")
        .toolbar {
            ForEach(node.attachments("toolbar")) { toolbar in
                ToolbarItemGroup(placement: placement(toolbar.attributes["placement"]?.string)) {
                    ForEach(toolbar.renderedChildren) { item in
                        if item.name == "btn" {
                            ActionButton(node: item)
                        } else {
                            NodeView(node: item)
                        }
                    }
                }
            }
        }
        .sheet(
            item: Binding {
                node.attachment("sheet")
            } set: { sheet in
                if sheet == nil, let current = node.attachment("sheet") {
                    runtime.dispatch(current.id, "dismiss")
                }
            }
        ) { sheet in
            NodeView(node: sheet)
                .presentationDetents(
                    sheet.attributes["detent"]?.string == "medium" ? [.medium, .large] : [.large])
        }
        .alert(
            alert?.attributes["title"]?.string ?? "",
            isPresented: Binding {
                node.attachment("alert") != nil
            } set: { presented in
                if !presented, let current = node.attachment("alert") {
                    runtime.dispatch(current.id, "dismiss")
                }
            },
            presenting: alert
        ) { alert in
            ForEach(alert.renderedChildren.filter { $0.name == "btn" }) { ActionButton(node: $0) }
        } message: { alert in
            Text(
                alert.renderedChildren.filter { $0.name == "txt" }
                    .map { $0.children.filter { $0.kind == .text }.map(\.text).joined() }
                    .joined(separator: "\n"))
        }
    }

    private func placement(_ name: String?) -> ToolbarItemPlacement {
        #if os(macOS)
            switch name {
            case "leading": .navigation
            case "bottom": .automatic
            default: .primaryAction
            }
        #else
            switch name {
            case "leading": .topBarLeading
            case "bottom": .bottomBar
            default: .topBarTrailing
            }
        #endif
    }
}

private struct ActionButton: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        Button(role: buttonRole(node)) {
            runtime.dispatch(node.id, "click", waits: false)
        } label: {
            ForEach(node.renderedChildren) { child in
                switch child.name {
                case "sfsymbol": Symbol(node: child)
                case "txt": Styles.text(child)
                default: Text(child.text)
                }
            }
        }
        .tint(Palette.color(node.attributes["tint"]?.string))
    }
}

private func buttonRole(_ node: Node) -> ButtonRole? {
    switch node.attributes["role"]?.string {
    case "destructive": .destructive
    case "cancel": .cancel
    default: nil
    }
}

extension View {
    @ViewBuilder
    func ifLet<Value, Modified: View>(
        _ value: Value?, _ transform: (Self, Value) -> Modified
    ) -> some View {
        if let value { transform(self, value) } else { self }
    }
}
