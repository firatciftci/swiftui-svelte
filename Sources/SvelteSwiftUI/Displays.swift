import SwiftUI

struct GaugeElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let lower = attributes["min"]?.number ?? 0
        let upper = max(lower, attributes["max"]?.number ?? 1)
        let value = min(max(attributes["value"]?.number ?? lower, lower), upper)
        let gauge = Gauge(value: value, in: lower...upper) {
            Children(node: node)
        } currentValueLabel: {
            if let current = attributes["current"]?.string { Text(current) }
        } minimumValueLabel: {
            if let minimum = attributes["minlabel"]?.string { Text(minimum) }
        } maximumValueLabel: {
            if let maximum = attributes["maxlabel"]?.string { Text(maximum) }
        }
        switch attributes["variant"]?.string {
        case "circular": gauge.gaugeStyle(.accessoryCircular)
        case "circularCapacity": gauge.gaugeStyle(.accessoryCircularCapacity)
        case "linear": gauge.gaugeStyle(.accessoryLinear)
        case "linearCapacity": gauge.gaugeStyle(.accessoryLinearCapacity)
        default: gauge
        }
    }
}

struct LabeledContentElement: View {
    let node: Node

    var body: some View {
        if let value = node.attributes["value"]?.string {
            LabeledContent {
                Text(value)
            } label: {
                Title(node: node)
            }
        } else {
            LabeledContent {
                Children(node: node)
            } label: {
                Title(node: node)
            }
        }
    }
}

struct UnavailableElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        if attributes["variant"]?.string == "search" {
            if let query = attributes["query"]?.string, !query.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ContentUnavailableView.search
            }
        } else {
            ContentUnavailableView {
                if let label = node.attachment("label") {
                    Children(node: label)
                } else if let symbol = attributes["symbol"]?.string {
                    Label(attributes["title"]?.string ?? "", systemImage: symbol)
                } else {
                    Text(attributes["title"]?.string ?? "")
                }
            } description: {
                if let description = attributes["description"]?.string { Text(description) }
            } actions: {
                Children(node: node)
            }
        }
    }
}

struct MenuElement: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let menu = Group {
            if node.listens(to: "primaryaction") {
                Menu {
                    items
                } label: {
                    label
                } primaryAction: {
                    runtime.dispatch(node.id, "primaryaction", waits: false)
                }
            } else {
                Menu {
                    items
                } label: {
                    label
                }
            }
        }
        .ifLet(Self.order(node.attributes["order"]?.string)) { $0.menuOrder($1) }
        switch node.attributes["variant"]?.string {
        case "button": menu.menuStyle(.button)
        case "borderlessButton":
            #if os(macOS)
                menu.menuStyle(.borderlessButton)
            #else
                menu.menuStyle(.button).buttonStyle(.borderless)
            #endif
        default: menu
        }
    }

    private var items: some View {
        ForEach(node.renderedChildren) { MenuItem(node: $0) }
    }

    @ViewBuilder private var label: some View {
        let attributes = node.attributes
        if let label = node.attachment("label") {
            Children(node: label)
        } else if let symbol = attributes["symbol"]?.string {
            Label(attributes["title"]?.string ?? "", systemImage: symbol)
        } else {
            Text(attributes["title"]?.string ?? "")
        }
    }

    static func order(_ name: String?) -> MenuOrder? {
        switch name {
        case "automatic": return .automatic
        case "fixed": return .fixed
        #if !os(macOS)
            case "priority": return .priority
        #endif
        default: return nil
        }
    }
}

struct MenuItem: View {
    let node: Node

    var body: some View {
        switch node.name {
        case "btn": ActionButton(node: node)
        case "toggle": MenuToggle(node: node)
        case "picker": PickerControl(node: node)
        case "divider": Divider()
        case "menuview": MenuElement(node: node)
        case "sectionview":
            Section {
                ForEach(node.renderedChildren) { Self(node: $0) }
            } header: {
                if let header = node.attributes["header"]?.string { Text(header) }
            }
        default: NodeView(node: node)
        }
    }
}

struct ContextMenu: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        if let preview = node.attachment("preview") {
            content.contextMenu {
                items
            } preview: {
                Children(node: preview).environment(runtime)
            }
        } else {
            content.contextMenu { items }
        }
    }

    private var items: some View {
        ForEach(node.renderedChildren) { MenuItem(node: $0) }.environment(runtime)
    }
}

private struct MenuToggle: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        Toggle(
            isOn: Binding {
                node.attributes["checked"]?.isTrue ?? false
            } set: { value in
                runtime.edit(node, "checked", to: .bool(value), event: "change", payload: value)
            }
        ) {
            PlainLabel(node: node)
        }
    }
}

struct PlainLabel: View {
    let node: Node

    var body: some View {
        ForEach(node.renderedChildren) { child in
            switch child.name {
            case "sfsymbol": Symbol(node: child)
            case "txt": Styles.text(child)
            case "labelview": LabelElement(node: child)
            default: Text(Whitespace.normal.collapsed(child.text))
            }
        }
    }
}
