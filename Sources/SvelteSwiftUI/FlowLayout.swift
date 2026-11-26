import SwiftUI

struct FlowLayout: SwiftUI.Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat
    var fraction: CGFloat

    struct Row {
        var indices: Array<Int> = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout ()) -> CGSize {
        let rows = rows(in: subviews, width: proposal.width ?? .infinity)
        var width: CGFloat = 0
        var height = CGFloat(max(rows.count - 1, 0)) * lineSpacing
        for row in rows {
            width = max(width, row.width)
            height += row.height
        }
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout ()) {
        var y = bounds.minY
        for row in rows(in: subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) * fraction
            for index in row.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(in subviews: SwiftUI.Layout.Subviews, width: CGFloat) -> Array<Row> {
        var rows: Array<Row> = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: width.isFinite ? width : nil, height: nil))
            if !current.indices.isEmpty, current.width + spacing + size.width > width {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

struct FlowElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let spacing = CGFloat(attributes["spacing"]?.number ?? 8)
        FlowLayout(
            spacing: spacing,
            lineSpacing: CGFloat(attributes["linespacing"]?.number ?? Double(spacing)),
            fraction: Self.fraction(attributes["alignment"]?.string)
        ) {
            Children(node: node)
        }
    }

    private static func fraction(_ name: String?) -> CGFloat {
        switch name {
        case "center": 0.5
        case "trailing": 1
        default: 0
        }
    }
}

struct ReflowLayout: SwiftUI.Layout {
    var spacing: CGFloat
    var anchor: UnitPoint

    func sizeThatFits(proposal: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout ()) -> CGSize {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let width = rowWidth(ideals)
        guard width > (proposal.width ?? .infinity) else {
            return CGSize(width: width, height: ideals.map(\.height).max() ?? 0)
        }
        var size = CGSize(width: 0, height: spacing * CGFloat(max(ideals.count - 1, 0)))
        for (subview, ideal) in zip(subviews, ideals) {
            let fitted = subview.sizeThatFits(ProposedViewSize(width: min(ideal.width, proposal.width ?? ideal.width), height: nil))
            size.width = max(size.width, fitted.width)
            size.height += fitted.height
        }
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: SwiftUI.Layout.Subviews, cache _: inout ()) {
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        if rowWidth(ideals) <= bounds.width + 0.5 {
            var x = bounds.minX
            for (subview, ideal) in zip(subviews, ideals) {
                let y = bounds.minY + bounds.height * anchor.y
                subview.place(at: CGPoint(x: x, y: y), anchor: UnitPoint(x: 0, y: anchor.y), proposal: ProposedViewSize(ideal))
                x += ideal.width + spacing
            }
        } else {
            var y = bounds.minY
            for (subview, ideal) in zip(subviews, ideals) {
                let proposal = ProposedViewSize(width: min(ideal.width, bounds.width), height: nil)
                let x = bounds.minX + bounds.width * anchor.x
                subview.place(at: CGPoint(x: x, y: y), anchor: UnitPoint(x: anchor.x, y: 0), proposal: proposal)
                y += subview.sizeThatFits(proposal).height + spacing
            }
        }
    }

    private func rowWidth(_ ideals: Array<CGSize>) -> CGFloat {
        var width = spacing * CGFloat(max(ideals.count - 1, 0))
        for ideal in ideals { width += ideal.width }
        return width
    }
}

struct ReflowElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        ReflowLayout(spacing: CGFloat(attributes["spacing"]?.number ?? 8), anchor: Self.anchor(attributes["alignment"]?.string)) {
            Children(node: node)
        }
    }

    private static func anchor(_ name: String?) -> UnitPoint {
        let name = name?.lowercased() ?? ""
        let x: CGFloat = name.contains("leading") ? 0 : (name.contains("trailing") ? 1 : 0.5)
        let y: CGFloat = name.hasPrefix("top") ? 0 : (name.hasPrefix("bottom") ? 1 : 0.5)
        return UnitPoint(x: x, y: y)
    }
}
