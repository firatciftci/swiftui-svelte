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
            ForEach(node.renderedChildren) { NodeView(node: $0) }
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
