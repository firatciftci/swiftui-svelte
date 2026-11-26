import SwiftUI

enum Presenting {
    static let names: Set<String> = hoisted.union(anchored)
    static let hoisted: Set<String> = ["alert", "fullscreencover", "inspector", "sheet"]
    static let anchored: Set<String> = ["confirmationdialog", "popover"]
    static let hosts: Set<String> = ["screen", "tab", "sheet", "fullscreencover", "popover", "inspector"]

    static func detents(_ attributes: [String: JSONValue]) -> Set<PresentationDetent> {
        guard case let .array(items) = attributes["detents"] else {
            return attributes["detent"]?.string == "medium" ? [.medium, .large] : [.large]
        }
        let detents = Set(items.compactMap(detent))
        return detents.isEmpty ? [.large] : detents
    }

    static func detent(_ value: JSONValue) -> PresentationDetent? {
        switch value {
        case .string("medium"): .medium
        case .string("large"): .large
        case let .number(size) where size > 0 && size <= 1: .fraction(size)
        case let .number(size) where size > 1: .height(size)
        default: nil
        }
    }

    static func dragIndicator(_ name: String?) -> Visibility {
        switch name {
        case "visible": .visible
        case "hidden": .hidden
        default: .automatic
        }
    }

    static func backgroundInteraction(_ value: JSONValue?) -> PresentationBackgroundInteraction {
        switch value {
        case .bool(true), .string("enabled"): .enabled
        case .bool(false), .string("disabled"): .disabled
        case let value?: detent(value).map { .enabled(upThrough: $0) } ?? .automatic
        case nil: .automatic
        }
    }

    static func adaptation(_ name: String?) -> PresentationAdaptation? {
        switch name {
        case "automatic": .automatic
        case "none": PresentationAdaptation.none
        case "popover": .popover
        case "sheet": .sheet
        case "fullScreenCover": .fullScreenCover
        default: nil
        }
    }

    static func titleVisibility(_ name: String?) -> Visibility {
        switch name {
        case "visible": .visible
        case "hidden": .hidden
        default: .automatic
        }
    }

    static func edge(_ name: String?) -> Edge? {
        switch name {
        case "top": .top
        case "bottom": .bottom
        case "leading": .leading
        case "trailing": .trailing
        default: nil
        }
    }

    static func message(_ node: Node) -> String {
        node.renderedChildren.filter { $0.name == "txt" }
            .map { String(Styles.attributedString($0).characters) }
            .joined(separator: "\n")
    }
}

struct Presentations: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    #if os(iOS)
        @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var hasAppeared = false

    private var showsInspectorColumn: Bool {
        #if os(iOS)
            sizeClass != .compact
        #else
            true
        #endif
    }

    func body(content: Content) -> some View {
        let alert = presentation("alert")
        let dialog = presentation("confirmationdialog")
        let popover = node.attachment("popover")
        content
            .sheet(item: presented(showsInspectorColumn ? ["sheet"] : ["sheet", "inspector"])) {
                NodeView(node: $0).modifier(SheetOptions(node: $0))
            }
            #if os(macOS)
                .sheet(item: presented(["fullscreencover"])) { NodeView(node: $0).modifier(SheetOptions(node: $0)) }
            #else
                .fullScreenCover(item: presented(["fullscreencover"])) { NodeView(node: $0).modifier(SheetOptions(node: $0)) }
            #endif
            .popover(item: presented(["popover"]), arrowEdge: Presenting.edge(popover?.attributes["arrowedge"]?.string)) { popover in
                NodeView(node: popover)
                    .modifier(SheetOptions(node: popover))
                    .ifLet(Presenting.adaptation(popover.attributes["adaptation"]?.string)) { $0.presentationCompactAdaptation($1) }
            }
            .modifier(InspectorHost(node: node, isColumn: showsInspectorColumn, isPresented: isPresented("inspector")))
            .alert(alert?.attributes["title"]?.string ?? "", isPresented: isPresented("alert"), presenting: alert) { alert in
                ForEach(alert.renderedChildren.filter { $0.name == "btn" }) { ActionButton(node: $0) }
            } message: { alert in
                Text(Presenting.message(alert))
            }
            .confirmationDialog(
                dialog?.attributes["title"]?.string ?? "",
                isPresented: isPresented("confirmationdialog"),
                titleVisibility: Presenting.titleVisibility(dialog?.attributes["titlevisibility"]?.string),
                presenting: dialog
            ) { dialog in
                ForEach(dialog.renderedChildren.filter { $0.name == "btn" }) { ActionButton(node: $0) }
            } message: { dialog in
                let message = Presenting.message(dialog)
                if !message.isEmpty { Text(message) }
            }
            .onAppear { hasAppeared = true }
    }

    private func presentation(_ name: String) -> Node? {
        guard hasAppeared else { return nil }
        return Presenting.anchored.contains(name) ? node.attachment(name) : node.presented.first { $0.name == name }
    }

    private func presented(_ names: Array<String>) -> Binding<Node?> {
        let current = { names.lazy.compactMap(presentation).first }
        return Binding {
            current()
        } set: { value in
            if value == nil, let current = current() { runtime.dispatch(current.id, "dismiss") }
        }
    }

    private func isPresented(_ name: String) -> Binding<Bool> {
        Binding {
            presentation(name) != nil
        } set: { presented in
            if !presented, let current = presentation(name) { runtime.dispatch(current.id, "dismiss") }
        }
    }
}

private struct InspectorHost: ViewModifier {
    let node: Node
    let isColumn: Bool
    let isPresented: Binding<Bool>

    func body(content: Content) -> some View {
        if node.hostsInspector, isColumn {
            content.inspector(isPresented: isPresented) {
                if let inspector = node.presented.first(where: { $0.name == "inspector" }) {
                    NodeView(node: inspector)
                        .modifier(SheetOptions(node: inspector))
                        .modifier(ColumnWidth(value: inspector.attributes["columnwidth"], isInspector: true))
                }
            }
        } else {
            content
        }
    }
}

private struct SheetOptions: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .presentationDetents(Presenting.detents(attributes))
            .presentationDragIndicator(Presenting.dragIndicator(attributes["dragindicator"]?.string))
            .presentationBackgroundInteraction(Presenting.backgroundInteraction(attributes["backgroundinteraction"]))
            .interactiveDismissDisabled(attributes["dismissible"].map { !$0.isTrue } ?? false)
            .ifLet(attributes["cornerradius"]?.number) { $0.presentationCornerRadius($1) }
            .modifier(PresentationBackdrop(value: attributes["presentationbackground"]))
    }
}

private struct PresentationBackdrop: ViewModifier {
    let value: JSONValue?

    @ViewBuilder func body(content: Content) -> some View {
        if value?.string == "clear" {
            content.presentationBackground(.clear)
        } else if case let .object(options)? = value {
            content.presentationBackground { GlassBackdrop(variant: options["glass"]?.string) }
        } else {
            content.ifLet(Palette.style(value)) { $0.presentationBackground($1) }
        }
    }
}

private struct GlassBackdrop: View {
    let variant: String?

    var body: some View {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            let glass: Glass = variant == "clear" ? .clear : .regular
            Color.clear.glassEffect(glass, in: .rect)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
