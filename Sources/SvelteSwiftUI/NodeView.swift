import SwiftUI

struct NodeView: View {
    let node: Node
    @Environment(Runtime.self) private var runtime

    var body: some View {
        switch node.kind {
        case .text:
            Text(node.text)
        case .element:
            element.modifier(NodeModifiers(node: node))
                .layoutPriority(node.name == "spacer" ? -1 : 0)
        case .fragment:
            children
        case .comment:
            EmptyView()
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
            TabView {
                ForEach(node.renderedChildren) { tab in
                    Self(node: tab).tabItem {
                        Label(
                            tab.attributes["title"]?.string ?? "",
                            systemImage: tab.attributes["symbol"]?.string ?? "circle")
                    }
                }
            }
        case "vstack":
            VStack(alignment: horizontalAlignment, spacing: spacing) { children }
        case "hstack":
            HStack(alignment: verticalAlignment, spacing: spacing) { children }
        case "zstack":
            ZStack { children }
        case "scrollview":
            ScrollView { children }
        case "list":
            List { children }
        case "spacer":
            Spacer()
        case "divider":
            Divider()
        case "txt":
            Text(node.children.filter { $0.kind == .text }.map(\.text).joined())
                .lineLimit(node.attributes["lines"]?.number.map { Int($0) })
                .multilineTextAlignment(textAlignment)
        case "asyncimage":
            AsyncImage(url: URL(string: node.attributes["src"]?.string ?? "")) { image in
                if node.attributes["fit"]?.string == "fill" {
                    image.resizable().scaledToFill()
                } else {
                    image.resizable().scaledToFit()
                }
            } placeholder: {
                ProgressView()
            }
        case "sfsymbol":
            Symbol(node: node)
        case "btn":
            let button = Button(role: buttonRole(node)) {
                runtime.dispatch(node.id, "click")
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
            TextField(
                node.attributes["placeholder"]?.string ?? "",
                text: Binding {
                    node.attributes["value"]?.string ?? ""
                } set: { value in
                    node.attributes["value"] = .string(value)
                    runtime.dispatch(node.id, "input", value)
                }
            )
            .onSubmit { runtime.dispatch(node.id, "submit") }
        case "toggle":
            Toggle(
                isOn: Binding {
                    switch node.attributes["checked"] {
                    case let .bool(checked): checked
                    case nil, .null: false
                    default: true
                    }
                } set: { value in
                    node.attributes["checked"] = .bool(value)
                    runtime.dispatch(node.id, "change", value)
                }
            ) {
                children
            }
        default:
            Text("Unknown element <\(node.name)>").foregroundStyle(.red)
        }
    }

    private var textAlignment: TextAlignment {
        switch node.attributes["align"]?.string {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
    }

    private var spacing: CGFloat? {
        node.attributes["spacing"]?.number.map { CGFloat($0) }
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch node.attributes["alignment"]?.string {
        case "leading": .leading
        case "trailing": .trailing
        default: .center
        }
    }

    private var verticalAlignment: VerticalAlignment {
        switch node.attributes["alignment"]?.string {
        case "top": .top
        case "bottom": .bottom
        default: .center
        }
    }
}

private struct NavStack: View {
    let node: Node
    @Environment(Runtime.self) private var runtime

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
        content
            .ifLet(frame(attributes)) { $0.frame(width: $1.width, height: $1.height) }
            .padding(padding(attributes["padding"]))
            .font(font(attributes["font"]?.string))
            .fontWeight(weight(attributes["weight"]?.string))
            .ifLet(color(attributes["color"]?.string)) { $0.foregroundStyle($1) }
            .ifLet(color(attributes["tint"]?.string)) { $0.tint($1) }
            .background(color(attributes["background"]?.string) ?? .clear)
            .ifLet(attributes["radius"]?.number) { $0.clipShape(.rect(cornerRadius: $1)) }
            .opacity(attributes["opacity"]?.number ?? 1)
            .ifLet(attributes["animated"] == .bool(true) ? node.children.map(\.id) : nil) {
                $0.animation(.default, value: $1)
            }
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

    private func font(_ name: String?) -> Font? {
        switch name {
        case "largeTitle": .largeTitle
        case "title": .title
        case "title2": .title2
        case "title3": .title3
        case "headline": .headline
        case "subheadline": .subheadline
        case "body": .body
        case "callout": .callout
        case "footnote": .footnote
        case "caption": .caption
        case "caption2": .caption2
        default: nil
        }
    }

    private func weight(_ name: String?) -> Font.Weight? {
        switch name {
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
        default: nil
        }
    }
}

private struct Screen: View {
    let node: Node
    @Environment(Runtime.self) private var runtime

    var body: some View {
        let alert = node.attachment("alert")
        Group {
            ForEach(node.renderedChildren) { NodeView(node: $0) }
        }
        .navigationTitle(node.attributes["title"]?.string ?? "")
        .toolbar {
            ForEach(node.attachments("toolbar")) { toolbar in
                ToolbarItemGroup(placement: placement(toolbar.attributes["placement"]?.string)) {
                    NodeView(node: toolbar)
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
        switch name {
        case "leading": .topBarLeading
        case "bottom": .bottomBar
        default: .topBarTrailing
        }
    }
}

private struct ActionButton: View {
    let node: Node
    @Environment(Runtime.self) private var runtime

    var body: some View {
        Button(role: buttonRole(node)) {
            runtime.dispatch(node.id, "click")
        } label: {
            ForEach(node.renderedChildren) { child in
                switch child.name {
                case "sfsymbol": Symbol(node: child)
                case "txt": Text(child.children.filter { $0.kind == .text }.map(\.text).joined())
                default: Text(child.text)
                }
            }
        }
        .tint(color(node.attributes["tint"]?.string))
    }
}

private struct Symbol: View {
    let node: Node

    private var name: String {
        node.attributes["name"]?.string ?? "questionmark"
    }

    var body: some View {
        if let label = node.attributes["label"]?.string {
            Image(systemName: name).accessibilityLabel(label)
        } else {
            Image(systemName: name)
        }
    }
}

private func buttonRole(_ node: Node) -> ButtonRole? {
    switch node.attributes["role"]?.string {
    case "destructive": .destructive
    case "cancel": .cancel
    default: nil
    }
}

private func color(_ name: String?) -> Color? {
    switch name {
    case "primary": .primary
    case "secondary": .secondary
    case "accent": .accentColor
    case "red": .red
    case "orange": .orange
    case "yellow": .yellow
    case "green": .green
    case "mint": .mint
    case "teal": .teal
    case "cyan": .cyan
    case "blue": .blue
    case "indigo": .indigo
    case "purple": .purple
    case "pink": .pink
    case "brown": .brown
    case "gray": .gray
    case "white": .white
    case "black": .black
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
