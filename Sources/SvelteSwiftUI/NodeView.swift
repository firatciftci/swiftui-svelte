import SwiftUI

struct NodeView: View {
    let node: Node

    static let multiple: Set<String> = [
        "sheet", "fullscreencover", "popover", "inspector", "swipeactions", "tab", "toolbar", "sectionview", "group",
    ]

    var body: some View {
        NodeContent(node: node, element: ElementView(node: node), isRow: false)
    }
}

struct RowView: View {
    let node: Node

    static func wraps(_ children: Array<Node>) -> Bool {
        children.allSatisfy { $0.kind != .element || !(NodeView.multiple.contains($0.name) || $0.name == "disclosuregroup") }
    }

    var body: some View {
        ZStack { NodeContent(node: node, element: SingleElement(node: node), isRow: true) }
            .modifier(RowTraits(node: node))
    }
}

private struct NodeContent<Element: View>: View {
    let node: Node
    let element: Element
    let isRow: Bool

    var body: some View {
        switch node.kind {
        case .text:
            Text(Whitespace.normal.collapsed(node.text))
        case .element:
            element.modifier(NodeModifiers(node: node, isRow: isRow))
                .gated(node.name == "spacer") { $0.layoutPriority(-1) }
        case .fragment:
            VStack(spacing: 0) { ForEach(node.renderedChildren) { NodeView(node: $0) } }
                .modifier(Presentations(node: node))
        }
    }
}

private struct ElementView: View {
    let node: Node

    var body: some View {
        if NodeView.multiple.contains(node.name) {
            MultipleElement(node: node)
        } else {
            SingleElement(node: node)
        }
    }
}

private struct MultipleElement: View {
    let node: Node

    var body: some View {
        if node.name == "sectionview" {
            Section {
                Rows(node: node)
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
            .modifier(SectionIndexLabel(label: node.attributes["indexlabel"]?.string))
        } else {
            Group { ForEach(node.renderedChildren) { NodeView(node: $0) } }
        }
    }
}

private struct SingleElement: View {
    let node: Node

    var body: some View {
        element
    }

    private var children: some View {
        ForEach(node.renderedChildren) { NodeView(node: $0) }
    }

    @ViewBuilder private var element: some View {
        switch node.name {
        case "navstack":
            NavStack(node: node)
        case "screen":
            Screen(node: node)
        case "tabview":
            Tabs(node: node)
        case "navsplitview":
            SplitView(node: node)
        case "vstack":
            VStack(alignment: Styles.horizontalAlignment(alignment), spacing: spacing) { children }
        case "hstack":
            HStack(alignment: Styles.verticalAlignment(alignment), spacing: spacing) { children }
        case "lazyvstack", "lazyhstack", "lazyvgrid", "lazyhgrid", "grid", "gridrow", "viewthatfits", "groupbox",
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
            ListElement(node: node)
        case "glasseffectcontainer":
            GlassContainer(node: node)
        case "formview":
            Form { children }
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
            ButtonElement(node: node)
        case "textfield" where node.attributes["format"] != nil:
            NumberFieldControl(node: node)
        case "textfield", "securefield", "texteditor":
            TextInputControl(node: node)
        case "toggle":
            ToggleElement(node: node)
        case "picker" where node.attributes["multiple"]?.isTrue == true:
            MultiPickerControl(node: node)
        case "picker":
            PickerControl(node: node)
        case "multidatepicker":
            MultiDatePickerControl(node: node)
        case "colorpicker":
            ColorPickerControl(node: node)
        case "gauge":
            GaugeElement(node: node)
        case "labeledcontent":
            LabeledContentElement(node: node)
        case "contentunavailableview":
            UnavailableElement(node: node)
        case "menuview":
            MenuElement(node: node)
        case "slider":
            SliderControl(node: node)
        case "stepper":
            StepperControl(node: node)
        case "datepicker":
            DatePickerControl(node: node)
        case "progressview":
            ProgressControl(node: node)
        default:
            CustomElement(node: node)
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
    let isRow: Bool

    func body(content: Content) -> some View {
        let modifiers = isRow ? node.modifiers.subtracting(.rowTraits) : node.modifiers
        if modifiers.isEmpty, !node.hostsPresentations {
            content
        } else {
            content
                .modifier(Shaping(node: node, modifiers: modifiers))
                .modifier(Behaving(node: node, modifiers: modifiers))
                .modifier(Hosting(node: node, modifiers: modifiers))
        }
    }
}

private struct Shaping: ViewModifier {
    let node: Node
    let modifiers: ModifierSet

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .gated(modifiers.contains(.safeArea)) { $0.modifier(SafeAreaInsets(node: node)) }
            .gated(modifiers.contains(.framing)) { $0.modifier(Framing(attributes: attributes)) }
            .gated(modifiers.contains(.typography)) { $0.modifier(Typography(attributes: attributes)) }
            .gated(modifiers.contains(.appearance)) { $0.modifier(Appearance(attributes: attributes)) }
            .gated(modifiers.contains(.decorations)) { $0.modifier(Decorations(node: node)) }
            .gated(modifiers.contains(.glass)) { $0.modifier(GlassSurface(attributes: attributes)) }
            .gated(modifiers.contains(.transforms)) { $0.modifier(Transforms(attributes: attributes)) }
            .gated(modifiers.contains(.layers)) { $0.modifier(Layers(node: node)) }
    }
}

private struct Behaving: ViewModifier {
    let node: Node
    let modifiers: ModifierSet

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .gated(modifiers.contains(.accessible)) { $0.modifier(Accessible(node: node)) }
            .gated(modifiers.contains(.lifecycle)) { $0.modifier(Lifecycle(node: node)) }
            .gated(modifiers.contains(.gestures)) { $0.modifier(GestureHandlers(node: node)) }
            .gated(modifiers.contains(.pointer)) { $0.modifier(PointerEvents(node: node)) }
            .gated(modifiers.contains(.measured)) { $0.modifier(Measured(node: node)) }
            .gated(modifiers.contains(.gridCell)) { $0.modifier(GridCell(attributes: attributes)) }
            .gated(modifiers.contains(.resizing)) { $0.modifier(Resizing(node: node)) }
            .gated(modifiers.contains(.localized)) { $0.modifier(Localized(attributes: attributes)) }
            .gated(modifiers.contains(.preferences)) { $0.modifier(Preferences(attributes: attributes)) }
            .gated(modifiers.contains(.availability)) { $0.modifier(Availability(node: node)) }
    }
}

private struct Hosting: ViewModifier {
    let node: Node
    let modifiers: ModifierSet

    func body(content: Content) -> some View {
        content
            .gated(node.hostsPresentations) { $0.modifier(Presentations(node: node)) }
            .gated(modifiers.contains(.animated)) { $0.modifier(AnimatedChildren(node: node)) }
            .gated(modifiers.contains(.attachments)) { $0.modifier(Attachments(node: node)) }
            .gated(modifiers.contains(.rowTraits)) { $0.modifier(RowTraits(node: node)) }
    }
}

private struct AnimatedChildren: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        let animation = (MotionCurve(attributes["animation"]) ?? MotionCurve()).animation
        content
            .ifLet(attributes["animated"]?.isTrue == true ? node.children.map(\.id) : nil) { $0.animation(animation, value: $1) }
            .gated(attributes["disablesanimations"]?.isTrue == true) { view in
                view.transaction { $0.disablesAnimations = true }
            }
    }
}

private struct RowTraits: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .ifLet(MotionTransition.transition(for: attributes)) { $0.transition($1) }
            .ifLet(attributes["zindex"]?.number) { $0.zIndex($1) }
            .ifLet(node.attachment("swipeactions")) { view, actions in
                view.swipeActions(edge: actions.attributes["edge"]?.string == "leading" ? .leading : .trailing) {
                    ForEach(actions.renderedChildren) { ActionButton(node: $0) }
                }
            }
            .modifier(RowOptions(attributes: attributes))
    }
}

private struct Typography: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(Styles.font(attributes)) { $0.font($1) }
            .gated(attributes["italic"]?.isTrue == true) { $0.italic() }
            .ifLet(Styles.design(attributes["design"]?.string)) { $0.fontDesign($1) }
            .ifLet(Styles.weight(attributes["weight"]?.string)) { $0.fontWeight($1) }
            .ifLet(Palette.style(attributes["color"])) { $0.foregroundStyle($1) }
            .ifLet(Palette.color(attributes["tint"]?.string)) { $0.tint($1) }
            .ifLet(Inputs.controlSize(attributes["controlsize"]?.string)) { $0.controlSize($1) }
    }
}

private struct Appearance: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(Palette.style(attributes["background"])) { $0.background($1) }
            .ifLet(attributes["radius"]?.number) { $0.clipShape(.rect(cornerRadius: $1)) }
            .opacity(attributes["opacity"]?.number ?? 1)
    }
}

private struct Localized: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(attributes["lang"]?.string.flatMap { $0.isEmpty ? nil : Locale(identifier: $0) }) {
                $0.environment(\.locale, $1)
            }
            .ifLet(Styles.layoutDirection(attributes["dir"]?.string)) { $0.environment(\.layoutDirection, $1) }
    }
}

private struct Attachments: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        content
            .ifLet(node.attachment("searchable")) { $0.modifier(Searching(node: $1)) }
            .ifLet(node.attachment("contextmenu")) { $0.modifier(ContextMenu(node: $1)) }
    }
}

struct ActionButton: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        Button(role: Inputs.role(node.attributes["role"]?.string)) {
            runtime.dispatch(node.id, "click", waits: false)
        } label: {
            PlainLabel(node: node)
        }
        .tint(Palette.color(node.attributes["tint"]?.string))
    }
}

extension View {
    @ViewBuilder
    func gated<Modified: View>(_ isOn: Bool, _ transform: (Self) -> Modified) -> some View {
        if isOn { transform(self) } else { self }
    }

    @ViewBuilder
    func ifLet<Value, Modified: View>(
        _ value: Value?, _ transform: (Self, Value) -> Modified
    ) -> some View {
        if let value { transform(self, value) } else { self }
    }
}
