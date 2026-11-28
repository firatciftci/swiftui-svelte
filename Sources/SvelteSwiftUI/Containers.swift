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
                runtime.edit(node, "expanded", to: .bool(value), event: "toggle")
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

nonisolated enum CSSPlacement: Hashable {
    case stretch(Axis)
    case align(UnitPoint)

    var point: UnitPoint {
        switch self {
        case .stretch: .zero
        case let .align(point): point
        }
    }

    static func point(_ name: String, cross: Axis) -> UnitPoint {
        let factor: CGFloat =
            switch name {
            case "start", "leading", "top": 0
            case "end", "trailing", "bottom": 1
            default: 0.5
            }
        return cross == .horizontal ? UnitPoint(x: factor, y: 0) : UnitPoint(x: 0, y: factor)
    }
}

extension CSSPlacement {
    static func of(_ child: Node, in parent: Node) -> CSSPlacement? {
        guard parent.attributes["css"]?.isTrue == true else { return nil }
        let cross: Axis = CSSStack.isColumn(parent) ? .horizontal : .vertical
        let selfAlign = child.attributes["selfalign"]?.string
        if selfAlign == "stretch" { return .stretch(cross) }
        let explicit = selfAlign.flatMap { ["start", "center", "end"].contains($0) ? $0 : nil }
        guard let item = explicit ?? parent.attributes["alignment"]?.string else { return .stretch(cross) }
        return .align(point(item, cross: cross))
    }
}

nonisolated struct CSSPlacementKey: LayoutValueKey {
    static let defaultValue: CSSPlacement? = nil
}

nonisolated struct CSSGrowth: Hashable {
    var width = false
    var height = false
}

extension CSSGrowth {
    static func of(_ node: Node) -> CSSGrowth {
        CSSGrowth(
            width: Geometry.length(node.attributes["maxwidth"]) == .infinity,
            height: Geometry.length(node.attributes["maxheight"]) == .infinity
        )
    }
}

nonisolated struct CSSGrowthKey: LayoutValueKey {
    static let defaultValue = CSSGrowth()
}

struct StretchFrame: ViewModifier {
    let axis: Axis

    @ViewBuilder
    func body(content: Content) -> some View {
        if axis == .horizontal {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content.frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

struct CSSStack: View {
    let node: Node
    let placement: CSSPlacement?

    var body: some View {
        let spacing = CGFloat(node.attributes["spacing"]?.number ?? 0)
        let fills = placement == .stretch(.horizontal)
        if Self.isColumn(node) {
            let column = CSSColumn(spacing: spacing, fills: fills)
            column { Children(node: node) }
        } else {
            let row = CSSRow(spacing: spacing, fills: fills)
            row { Children(node: node) }
        }
    }

    static func isColumn(_ node: Node) -> Bool {
        switch node.attributes["axis"]?.string {
        case "vertical": true
        case "horizontal": false
        default: node.name == "vstack"
        }
    }
}

nonisolated enum CSSTrack {
    static func sizes(
        _ limit: CGFloat?, ideal: Array<CGFloat>, minimum: Array<CGFloat>, grows: Array<Bool>, spacing: CGFloat
    ) -> Array<CGFloat> {
        guard let limit else { return ideal }
        let gaps = spacing * CGFloat(max(ideal.count - 1, 0))
        let fixed = sum(zip(ideal, grows).filter { !$0.1 }.map(\.0))
        let growing = grows.count(where: \.self)
        if growing > 0, limit - gaps >= fixed {
            let share = (limit - gaps - fixed) / CGFloat(growing)
            return grows.indices.map { index in grows[index] ? max(minimum[index], share) : ideal[index] }
        }
        guard limit < sum(ideal) + gaps else { return ideal }
        let flex = sum(zip(ideal, minimum).map { $0 - $1 })
        let slack = max(limit - gaps - sum(minimum), 0)
        let ratio = flex > 0 ? min(slack / flex, 1) : 0
        return zip(ideal, minimum).map { $1 + ($0 - $1) * ratio }
    }

    static func sum(_ values: Array<CGFloat>) -> CGFloat {
        var total: CGFloat = 0
        for value in values { total += value }
        return total
    }
}

struct CSSColumn: SwiftUI.Layout {
    let spacing: CGFloat
    let fills: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout Void) -> CGSize {
        let content = subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = fills ? (proposal.width ?? content) : min(content, proposal.width ?? content)
        let heights = Self.heights(proposal.height, subviews, width: width, spacing: spacing)
        return CGSize(width: width, height: CSSTrack.sum(heights) + spacing * CGFloat(max(subviews.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout Void) {
        let heights = Self.heights(bounds.height, subviews, width: bounds.width, spacing: spacing)
        var y = bounds.minY
        for (subview, height) in zip(subviews, heights) {
            let grows = subview[CSSGrowthKey.self].height
            let proposal = ProposedViewSize(width: bounds.width, height: grows ? height : nil)
            let size = subview.sizeThatFits(proposal)
            let point = subview[CSSPlacementKey.self]?.point ?? .zero
            subview.place(
                at: CGPoint(x: bounds.minX + (bounds.width - size.width) * point.x, y: y), anchor: .topLeading, proposal: proposal)
            y += height + spacing
        }
    }

    private static func heights(_ limit: CGFloat?, _ subviews: SwiftUI.Layout.Subviews, width: CGFloat, spacing: CGFloat) -> Array<CGFloat>
    {
        var ideal: Array<CGFloat> = []
        var grows: Array<Bool> = []
        for subview in subviews {
            ideal.append(subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
            grows.append(subview[CSSGrowthKey.self].height)
        }
        return CSSTrack.sizes(limit, ideal: ideal, minimum: ideal, grows: grows, spacing: spacing)
    }
}

struct CSSRow: SwiftUI.Layout {
    let spacing: CGFloat
    let fills: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout Void) -> CGSize {
        let widths = Self.widths(proposal.width, subviews, spacing: spacing)
        let total = CSSTrack.sum(widths) + spacing * CGFloat(max(widths.count - 1, 0))
        let width = fills ? (proposal.width ?? total) : min(total, proposal.width ?? total)
        return CGSize(width: width, height: Self.height(widths, subviews))
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout Void) {
        let widths = Self.widths(bounds.width, subviews, spacing: spacing)
        let height = Self.height(widths, subviews)
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths) {
            let placement = subview[CSSPlacementKey.self]
            var proposal = ProposedViewSize(width: width, height: nil)
            if case .stretch? = placement { proposal.height = height }
            let size = subview.sizeThatFits(proposal)
            let y = bounds.minY + (height - size.height) * (placement?.point.y ?? 0)
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: proposal)
            x += width + spacing
        }
    }

    private static func widths(_ limit: CGFloat?, _ subviews: SwiftUI.Layout.Subviews, spacing: CGFloat) -> Array<CGFloat> {
        var ideal: Array<CGFloat> = []
        var minimum: Array<CGFloat> = []
        var grows: Array<Bool> = []
        for subview in subviews {
            ideal.append(subview.sizeThatFits(.unspecified).width)
            minimum.append(subview.sizeThatFits(ProposedViewSize(width: 0, height: nil)).width)
            grows.append(subview[CSSGrowthKey.self].width)
        }
        return CSSTrack.sizes(limit, ideal: ideal, minimum: minimum, grows: grows, spacing: spacing)
    }

    private static func height(_ widths: Array<CGFloat>, _ subviews: SwiftUI.Layout.Subviews) -> CGFloat {
        var height: CGFloat = 0
        for (subview, width) in zip(subviews, widths) {
            height = max(height, subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
        }
        return height
    }
}
