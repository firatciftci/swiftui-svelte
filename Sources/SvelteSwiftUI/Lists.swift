import SwiftUI

enum Lists {
    enum Selection {
        case disabled, single, multiple
    }

    static func selection(of node: Node) -> Selection {
        if node.attributes["multiple"]?.isTrue == true { return .multiple }
        if node.attributes["selection"] != nil || node.listens(to: "selectionchange") { return .single }
        return .disabled
    }

    static func tags(in node: Node) -> Array<JSONValue> {
        var tags: Array<JSONValue> = []
        for child in node.children where child.kind == .element {
            if let tag = child.attributes["tag"] { tags.append(tag) }
            tags.append(contentsOf: Self.tags(in: child))
        }
        return tags
    }
}

struct ListElement: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        styled
            .modifier(Scrollable(node: node))
            .modifier(ScrollOptions(node: node))
            .modifier(SectionIndex(visibility: Bars.visibility(node.attributes["sectionindex"])))
            .modifier(Editing(node: node))
    }

    @ViewBuilder private var styled: some View {
        switch node.attributes["variant"]?.string {
        case "plain": list.listStyle(.plain)
        case "inset": list.listStyle(.inset)
        case "sidebar": list.listStyle(.sidebar)
        #if !os(macOS)
            case "grouped": list.listStyle(.grouped)
            case "insetGrouped": list.listStyle(.insetGrouped)
        #endif
        default: list
        }
    }

    @ViewBuilder private var list: some View {
        switch Lists.selection(of: node) {
        case .multiple: List(selection: multipleSelection) { Rows(node: node) }
        case .single: List(selection: singleSelection) { Rows(node: node) }
        case .disabled: List { Rows(node: node) }
        }
    }

    private var singleSelection: Binding<JSONValue?> {
        Binding {
            node.attributes["selection"].flatMap { $0 == .null ? nil : $0 }
        } set: { value in
            let value = value ?? .null
            runtime.edit(node, "selection", to: value, event: "selectionchange", payload: value.object)
        }
    }

    private var multipleSelection: Binding<Set<JSONValue>> {
        Binding {
            guard case let .array(values) = node.attributes["selection"] else { return [] }
            return Set(values)
        } set: { values in
            let value = JSONValue.array(Lists.tags(in: node).filter(values.contains))
            runtime.edit(node, "selection", to: value, event: "selectionchange", payload: value.object)
        }
    }
}

struct Rows: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        if node.hasMultiViewChild {
            editable(ForEach(node.renderedChildren) { NodeView(node: $0) })
        } else {
            editable(ForEach(node.renderedChildren) { SingleNodeView(node: $0) })
        }
    }

    private func editable(_ rows: some DynamicViewContent) -> some View {
        let id = node.id
        return
            rows
            .onDelete(
                perform: node.listens(to: "delete")
                    ? { offsets in runtime.dispatch(id, "delete", Array(offsets)) } : nil
            )
            .onMove(
                perform: node.listens(to: "move")
                    ? { source, destination in
                        runtime.dispatch(id, "move", ["from": Array(source), "to": destination] as [String: Any])
                    } : nil
            )
    }
}

struct RowOptions: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(attributes["tag"]) { $0.tag($1) }
            .ifLet(Geometry.insets(attributes["rowinsets"])) { $0.listRowInsets($1) }
            .ifLet(Bars.visibility(attributes["rowseparator"])) { $0.listRowSeparator($1) }
            .ifLet(Palette.color(attributes["rowseparatortint"]?.string)) { $0.listRowSeparatorTint($1) }
            .ifLet(Palette.style(attributes["rowbackground"])) { $0.listRowBackground(Rectangle().fill($1)) }
            .ifLet(attributes["deletedisabled"]) { $0.deleteDisabled($1.isTrue) }
            .ifLet(attributes["movedisabled"]) { $0.moveDisabled($1.isTrue) }
    }
}

struct SectionIndexLabel: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        #if os(iOS) || os(visionOS)
            if let label, #available(iOS 26, visionOS 26, *) {
                content.sectionIndexLabel(Text(label))
            } else {
                content
            }
        #else
            content
        #endif
    }
}

private struct SectionIndex: ViewModifier {
    let visibility: Visibility?

    func body(content: Content) -> some View {
        #if os(iOS) || os(visionOS)
            if let visibility, #available(iOS 26, visionOS 26, *) {
                content.listSectionIndexVisibility(visibility)
            } else {
                content
            }
        #else
            content
        #endif
    }
}

private struct Editing: ViewModifier {
    let node: Node
    #if os(iOS) || os(visionOS)
        @Environment(SvelteRuntime.self) private var runtime
        @State private var mode: EditMode

        init(node: Node) {
            self.node = node
            _mode = State(initialValue: node.attributes["editing"]?.isTrue == true ? .active : .inactive)
        }
    #endif

    func body(content: Content) -> some View {
        #if os(iOS) || os(visionOS)
            let isEditing = node.attributes["editing"]?.isTrue == true
            content
                .environment(\.editMode, $mode)
                .onChange(of: isEditing) { _, isEditing in
                    guard isEditing != (mode == .active) else { return }
                    withAnimation { mode = isEditing ? .active : .inactive }
                }
                .onChange(of: mode) { _, mode in
                    let isActive = mode == .active
                    guard mode != .transient, isActive != isEditing else { return }
                    runtime.edit(node, "editing", to: .bool(isActive), event: "editingchange", payload: isActive)
                }
        #else
            content
        #endif
    }
}
