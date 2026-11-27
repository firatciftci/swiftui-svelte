import SwiftUI

enum Markup {
    static let inline: Set<String> = [
        "txt", "a", "b", "br", "code", "del", "em", "i", "ins", "kbd", "mark", "s", "span", "strong", "sub", "sup", "u",
    ]

    static let blocks: Set<String> = [
        "p", "h1", "h2", "h3", "h4", "h5", "h6", "li", "td", "th", "blockquote", "pre", "thead", "tbody", "tfoot", "tr",
    ]

    static func attributes(of node: Node) -> [String: JSONValue] {
        implied(node.name).merging(node.attributes) { _, own in own }
    }

    private static func implied(_ name: String) -> [String: JSONValue] {
        switch name {
        case "strong", "b", "th": ["weight": .string("bold")]
        case "em", "i": ["italic": .bool(true)]
        case "code", "kbd": ["design": .string("monospaced")]
        case "del", "s": ["strikethrough": .bool(true)]
        case "ins", "u": ["underline": .bool(true)]
        case "mark": ["background": .string("yellow")]
        case "sup": ["baselineoffset": .number(6)]
        case "sub": ["baselineoffset": .number(-3)]
        case "h1": ["font": .string("title"), "weight": .string("bold")]
        case "h2": ["font": .string("title2"), "weight": .string("bold")]
        case "h3": ["font": .string("title3"), "weight": .string("bold")]
        case "h4": ["font": .string("headline")]
        case "h5": ["font": .string("subheadline"), "weight": .string("bold")]
        case "h6": ["font": .string("footnote"), "weight": .string("bold")]
        case "pre": ["design": .string("monospaced"), "whitespace": .string("pre")]
        default: [:]
        }
    }

    static func heading(_ name: String) -> AccessibilityHeadingLevel? {
        switch name {
        case "h1": .h1
        case "h2": .h2
        case "h3": .h3
        case "h4": .h4
        case "h5": .h5
        case "h6": .h6
        default: nil
        }
    }

    enum Piece: Identifiable {
        case inline(Array<Node>)
        case block(Node)

        var id: Int {
            switch self {
            case let .inline(nodes): -(nodes.first?.id ?? 0) - 1
            case let .block(node): node.id
            }
        }
    }

    static func pieces(of node: Node) -> Array<Piece> {
        if inline.contains(node.name) { return [.inline([node])] }
        var pieces: Array<Piece> = []
        var run: Array<Node> = []
        func flush() {
            if run.contains(where: { $0.kind == .element || !$0.isBlank }) { pieces.append(.inline(run)) }
            run = []
        }
        for child in node.children {
            switch child.kind {
            case .text: run.append(child)
            case .element where inline.contains(child.name): run.append(child)
            case .element where !Node.attachments.contains(child.name):
                flush()
                pieces.append(.block(child))
            case .element, .fragment: continue
            }
        }
        flush()
        return pieces
    }
}

struct MarkupFlow: View {
    let node: Node
    @Environment(\.textBase) private var base

    var body: some View {
        let isInline = Markup.inline.contains(node.name)
        let attributes = isInline ? [:] : Markup.attributes(of: node)
        let span = Span(root: [:], base: base).merged(attributes)
        let whitespace = Whitespace(attributes["whitespace"]?.string)
        let flow = VStack(alignment: .leading, spacing: 8) {
            ForEach(Markup.pieces(of: node)) { piece in
                switch piece {
                case let .inline(children): Text(Styles.flow(children, span, whitespace: whitespace))
                case let .block(child): NodeView(node: child)
                }
            }
        }
        .ifLet(Markup.heading(node.name)) { $0.accessibilityAddTraits(.isHeader).accessibilityHeading($1) }
        switch node.name {
        case "pre":
            ScrollView(.horizontal) { flow.padding(12) }
                .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                .frame(maxWidth: .infinity, alignment: .leading)
        case "blockquote":
            flow.foregroundStyle(.secondary)
                .padding(.leading, 15)
                .overlay(alignment: .leading) { Capsule().fill(.tertiary).frame(width: 3) }
                .frame(maxWidth: .infinity, alignment: .leading)
        case "p", "h1", "h2", "h3", "h4", "h5", "h6", "li": flow.frame(maxWidth: .infinity, alignment: .leading)
        default: flow
        }
    }
}

extension EnvironmentValues {
    @Entry var markupListDepth = 0
}

struct MarkupList: View {
    let node: Node
    @Environment(\.markupListDepth) private var depth

    var body: some View {
        let start = node.attributes["start"].flatMap { $0.number ?? $0.string.flatMap(Double.init) }.map { Int($0) } ?? 1
        let isOrdered = node.name == "ol"
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(node.renderedChildren.enumerated()), id: \.element.id) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if isOrdered {
                        Text("\(start + index).").monospacedDigit()
                    } else {
                        Text(["•", "◦", "▪"][depth % 3]).accessibilityHidden(true)
                    }
                    NodeView(node: item)
                }
            }
        }
        .environment(\.markupListDepth, depth + 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MarkupTable: View {
    let node: Node

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            ForEach(node.renderedChildren) { section in
                if section.name == "tr" {
                    MarkupRow(row: section)
                } else {
                    ForEach(section.renderedChildren) { MarkupRow(row: $0) }
                    if section.name == "thead" { Divider() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkupRow: View {
    let row: Node

    var body: some View {
        GridRow {
            ForEach(row.renderedChildren) { NodeView(node: $0) }
        }
    }
}

struct MarkupImage: View {
    let node: Node

    var body: some View {
        RemoteImage(node: node)
            .ifLet(node.attributes["alt"]?.string) { view, alt in
                view.accessibilityElement(children: .ignore).accessibilityLabel(alt).accessibilityAddTraits(.isImage)
            }
    }
}
