import SwiftUI

struct NodeView: View {
    let node: Node

    static let multiple: Set<String> = [
        "sheet", "fullscreencover", "popover", "inspector", "swipeactions", "tab", "toolbar", "sectionview", "group",
    ]
    static let multiView = multiple.union(["disclosuregroup", "gridrow"])

    var body: AnyView {
        AnyView(NodeShape.view(of: node))
    }
}

struct SingleNodeView: View {
    let node: Node

    var body: AnyView {
        AnyView(NodeShape.view(of: node))
    }

    nonisolated static func _viewListCount(inputs _: _ViewListCountInputs) -> Int? { 1 }
}

struct Children: View {
    let node: Node

    var body: some View {
        if node.hasMultiViewChild {
            ForEach(node.renderedChildren) { NodeView(node: $0) }
        } else {
            ForEach(node.renderedChildren) { SingleNodeView(node: $0) }
        }
    }
}

enum NodeShape {
    static func view(of node: Node) -> any View {
        switch node.kind {
        case .text:
            Text(Whitespace.normal.collapsed(node.text))
        case .fragment:
            VStack(spacing: 0) { Children(node: node) }.modifier(Presentations(node: node))
        case .element:
            traits(of: node, modified(element(of: node), node))
        }
    }

    private static func modified(_ element: any View, _ node: Node) -> any View {
        let modifiers = node.modifiers.subtracting(.traits)
        return hosted(behaved(shaped(element, node, modifiers), node, modifiers), node, modifiers)
    }

    private static func shaped(_ element: any View, _ node: Node, _ modifiers: ModifierSet) -> any View {
        let attributes = node.attributes
        var view = element
        if modifiers.contains(.safeArea) { view = view.applying(SafeAreaInsets(node: node)) }
        if modifiers.contains(.framing) { view = view.applying(Framing(attributes: attributes)).applying(Sizing(attributes: attributes)) }
        if modifiers.contains(.typography) { view = view.applying(Typography(attributes: attributes)) }
        if modifiers.contains(.appearance) { view = view.applying(Appearance(attributes: attributes)) }
        if modifiers.contains(.decorations) { view = view.applying(Decorations(node: node)) }
        if modifiers.contains(.glass) { view = view.applying(GlassSurface(attributes: attributes)) }
        if modifiers.contains(.layers) { view = view.applying(Layers(node: node)) }
        if modifiers.contains(.transforms) { view = view.applying(Transforms(attributes: attributes)) }
        if modifiers.contains(.appearance) { view = view.applying(Compositing(attributes: attributes)) }
        return view
    }

    private static func behaved(_ shaped: any View, _ node: Node, _ modifiers: ModifierSet) -> any View {
        let attributes = node.attributes
        var view = shaped
        if modifiers.contains(.accessible) { view = view.applying(Accessible(node: node)) }
        if modifiers.contains(.lifecycle) { view = view.applying(Lifecycle(node: node)) }
        if modifiers.contains(.gestures) { view = view.applying(GestureHandlers(node: node)) }
        if modifiers.contains(.pointer) { view = view.applying(PointerEvents(node: node)) }
        if modifiers.contains(.scrolling) { view = view.applying(ScrollVisibility(node: node)) }
        if modifiers.contains(.shared) { view = view.applying(SharedNamespace(node: node)).applying(MatchedGeometry(node: node)) }
        if modifiers.contains(.measured) { view = view.applying(Measured(node: node)) }
        if modifiers.contains(.resizing) { view = view.applying(Resizing(node: node)) }
        if modifiers.contains(.localized) { view = view.applying(Localized(attributes: attributes)) }
        if modifiers.contains(.preferences) { view = view.applying(Preferences(attributes: attributes)) }
        if modifiers.contains(.availability) { view = view.applying(Availability(node: node)) }
        return view
    }

    private static func hosted(_ behaved: any View, _ node: Node, _ modifiers: ModifierSet) -> any View {
        var view = behaved
        if node.hostsPresentations { view = view.applying(Presentations(node: node)) }
        if modifiers.contains(.animated) { view = view.applying(AnimatedChildren(node: node)) }
        if modifiers.contains(.attachments) { view = view.applying(Attachments(node: node)) }
        if node.ownsButtonFeedback { view = view.applying(StateFeedback(node: node)) }
        return view
    }

    private static func traits(of node: Node, _ content: any View) -> any View {
        var view = content
        if node.name == "spacer" { view = view.applying(SpacerPriority()) }
        if node.modifiers.contains(.framing) { view = view.applying(LayoutPriority(attributes: node.attributes)) }
        if node.modifiers.contains(.gridCell) { view = view.applying(GridCell(attributes: node.attributes)) }
        if node.modifiers.contains(.rowTraits) { view = view.applying(RowTraits(node: node)) }
        return view
    }

    private static func element(of node: Node) -> any View {
        if NodeView.multiple.contains(node.name) { return MultipleElement(node: node) }
        let attributes = node.attributes
        let alignment = attributes["alignment"]?.string
        let spacing = attributes["spacing"]?.number.map { CGFloat($0) }
        switch node.name {
        case "navstack": return NavStack(node: node)
        case "screen": return Screen(node: node)
        case "tabview": return Tabs(node: node)
        case "navsplitview": return SplitView(node: node)
        case "vstack": return VStack(alignment: Styles.horizontalAlignment(alignment), spacing: spacing) { Children(node: node) }
        case "hstack": return HStack(alignment: Styles.verticalAlignment(alignment), spacing: spacing) { Children(node: node) }
        case "zstack": return ZStack(alignment: Styles.alignment(alignment)) { Children(node: node) }
        case "lazyvstack", "lazyhstack", "lazyvgrid", "lazyhgrid", "grid", "gridrow", "viewthatfits", "groupbox",
            "controlgroup", "disclosuregroup":
            return Container(node: node)
        case "rectangle", "roundedrectangle", "unevenroundedrectangle", "circleshape", "ellipseshape", "capsule", "pathshape":
            return ShapeElement(node: node)
        case "flowstack": return FlowElement(node: node)
        case "scrollview": return ScrollElement(node: node)
        case "list": return ListElement(node: node)
        case "glasseffectcontainer": return GlassContainer(node: node)
        case "formview": return Form { Children(node: node) }
        case "spacer": return Spacer(minLength: attributes["minlength"]?.number.map { CGFloat($0) })
        case "divider": return Divider()
        case "txt": return TextView(node: node)
        case "asyncimage": return RemoteImage(node: node)
        case "imageview": return ImageElement(node: node)
        case "labelview": return LabelElement(node: node)
        case "linkview": return LinkElement(node: node)
        case "sharelink": return ShareElement(node: node)
        case "sfsymbol": return Symbol(node: node)
        case "btn": return ButtonElement(node: node)
        case "textfield" where attributes["format"] != nil: return NumberFieldControl(node: node)
        case "textfield", "securefield", "texteditor": return TextInputControl(node: node)
        case "toggle": return ToggleElement(node: node)
        case "picker" where attributes["multiple"]?.isTrue == true: return MultiPickerControl(node: node)
        case "picker": return PickerControl(node: node)
        case "multidatepicker": return MultiDatePickerControl(node: node)
        case "colorpicker": return ColorPickerControl(node: node)
        case "gauge": return GaugeElement(node: node)
        case "labeledcontent": return LabeledContentElement(node: node)
        case "contentunavailableview": return UnavailableElement(node: node)
        case "menuview": return MenuElement(node: node)
        case "slider": return SliderControl(node: node)
        case "stepper": return StepperControl(node: node)
        case "datepicker": return DatePickerControl(node: node)
        case "progressview": return ProgressControl(node: node)
        default: return CustomElement(node: node)
        }
    }
}

extension View {
    func applying(_ modifier: some ViewModifier) -> any View {
        self.modifier(modifier)
    }
}

private struct SpacerPriority: ViewModifier {
    func body(content: Content) -> some View {
        content.layoutPriority(-1)
    }
}

private struct LayoutPriority: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content.ifLet(attributes["layoutpriority"]?.number) { $0.layoutPriority($1) }
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
                    Children(node: header)
                } else if let header = node.attributes["header"]?.string {
                    Text(header)
                }
            } footer: {
                if let footer = node.attachment("footer") {
                    Children(node: footer)
                } else if let footer = node.attributes["footer"]?.string {
                    Text(footer)
                }
            }
            .modifier(SectionIndexLabel(label: node.attributes["indexlabel"]?.string))
        } else {
            Group { Children(node: node) }
        }
    }
}

private struct ScrollElement: View {
    let node: Node

    var body: some View {
        ScrollView(Self.axes(node.attributes["axes"]?.string)) {
            if node.attributes["snap"]?.string == "view" {
                Children(node: node).scrollTargetLayout()
            } else {
                Children(node: node)
            }
        }
        .modifier(Scrollable(node: node))
        .modifier(ScrollOptions(node: node))
    }

    private static func axes(_ name: String?) -> Axis.Set {
        switch name {
        case "horizontal": .horizontal
        case "both": [.horizontal, .vertical]
        default: .vertical
        }
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
            .gated(TextBase.keys.contains { (attributes[$0] ?? .null) != .null }) { view in
                view.transformEnvironment(\.textBase) { $0 = $0.merged(attributes) }
            }
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
            .gated(attributes["insetshadow"]?.isTrue == true) { $0.modifier(InsetShadow(radius: attributes["radius"]?.number ?? 0)) }
    }
}

private struct Compositing: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .opacity(attributes["opacity"]?.number ?? 1)
            .ifLet(attributes["brightness"]?.number) { $0.brightness($1) }
            .ifLet(Palette.color(attributes["colormultiply"]?.string)) { $0.colorMultiply($1) }
            .ifLet(Effects.blendMode(attributes["blendmode"]?.string)) { $0.blendMode($1) }
            .gated(attributes["compositinggroup"]?.isTrue == true) { $0.compositingGroup() }
            .ifLet(attributes["lighten"]?.number) { $0.modifier(Lightening(amount: $1)) }
    }
}

private struct Localized: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(attributes["lang"]?.string.flatMap { $0.isEmpty ? nil : Locale(identifier: $0) }) {
                $0.environment(\.locale, $1).typesettingLanguage($1.language)
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
            .gated(node.hasToolbarItems) { $0.modifier(Toolbars(node: node)) }
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
