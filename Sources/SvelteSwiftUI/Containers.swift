import SwiftUI

enum Layout {
    static func gridItems(_ value: JSONValue?) -> Array<GridItem> {
        switch value {
        case let .number(count) where count >= 1:
            Array(repeating: GridItem(.flexible()), count: Int(count))
        case let .array(items) where !items.isEmpty:
            items.map(gridItem)
        default:
            [GridItem(.flexible())]
        }
    }

    private static func gridItem(_ value: JSONValue) -> GridItem {
        guard case let .object(options) = value else {
            return GridItem(.fixed(max(value.number ?? 0, 0)))
        }
        let size: GridItem.Size =
            if let fixed = options["fixed"]?.number {
                .fixed(max(fixed, 0))
            } else if let minimum = options["adaptive"]?.number {
                .adaptive(minimum: max(minimum, 0), maximum: options["max"]?.number ?? .infinity)
            } else {
                .flexible(minimum: options["min"]?.number ?? 10, maximum: options["max"]?.number ?? .infinity)
            }
        return GridItem(
            size,
            spacing: options["spacing"]?.number.map { CGFloat($0) },
            alignment: options["alignment"]?.string.map(Styles.alignment)
        )
    }

    static func pinnedViews(_ value: JSONValue?) -> PinnedScrollableViews {
        switch value?.string {
        case "headers": .sectionHeaders
        case "footers": .sectionFooters
        case "both": [.sectionHeaders, .sectionFooters]
        default: []
        }
    }

    static func axes(_ value: JSONValue?) -> Axis.Set {
        switch value?.string {
        case "horizontal": .horizontal
        case "vertical": .vertical
        default: [.horizontal, .vertical]
        }
    }
}

struct Container: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let spacing = attributes["spacing"]?.number.map { CGFloat($0) }
        let alignment = attributes["alignment"]?.string
        let pinned = Layout.pinnedViews(attributes["pinned"])
        switch node.name {
        case "lazyvstack":
            LazyVStack(alignment: Styles.horizontalAlignment(alignment), spacing: spacing, pinnedViews: pinned) { children }
        case "lazyhstack":
            LazyHStack(alignment: Styles.verticalAlignment(alignment), spacing: spacing, pinnedViews: pinned) { children }
        case "lazyvgrid":
            LazyVGrid(
                columns: Layout.gridItems(attributes["columns"]),
                alignment: Styles.horizontalAlignment(alignment),
                spacing: spacing,
                pinnedViews: pinned
            ) { children }
        case "lazyhgrid":
            LazyHGrid(
                rows: Layout.gridItems(attributes["rows"]),
                alignment: Styles.verticalAlignment(alignment),
                spacing: spacing,
                pinnedViews: pinned
            ) { children }
        case "grid":
            Grid(
                alignment: Styles.alignment(alignment),
                horizontalSpacing: attributes["hspacing"]?.number.map { CGFloat($0) } ?? spacing,
                verticalSpacing: attributes["vspacing"]?.number.map { CGFloat($0) } ?? spacing
            ) { children }
        case "gridrow":
            GridRow(alignment: alignment.map(Styles.verticalAlignment)) { children }
        case "viewthatfits":
            ViewThatFits(in: Layout.axes(attributes["axes"])) { children }
        case "groupbox":
            GroupBox {
                children
            } label: {
                Title(node: node)
            }
        case "controlgroup":
            ControlGroup {
                children
            } label: {
                Title(node: node)
            }
        default:
            DisclosureControl(node: node)
        }
    }

    private var children: some View {
        Children(node: node)
    }
}

struct Title: View {
    let node: Node

    var body: some View {
        if let label = node.attachment("label") {
            Children(node: label)
        } else if let title = node.attributes["title"]?.string {
            Text(title)
        }
    }
}

private struct DisclosureControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        DisclosureGroup(
            isExpanded: Binding {
                node.attributes["expanded"]?.isTrue ?? false
            } set: { value in
                runtime.edit(node, "expanded", to: .bool(value), event: "toggle", payload: value)
            }
        ) {
            Children(node: node)
        } label: {
            Title(node: node)
        }
    }
}

struct GridCell: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(attributes["colspan"]?.number.flatMap { $0 >= 1 ? Int($0) : nil }) { $0.gridCellColumns($1) }
            .ifLet(attributes["columnalignment"]?.string.map(Styles.horizontalAlignment)) { $0.gridColumnAlignment($1) }
            .ifLet(UnitPoint(anchor: attributes["cellanchor"]?.string)) { $0.gridCellAnchor($1) }
    }
}
