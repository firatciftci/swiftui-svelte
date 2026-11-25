import SwiftUI

struct Span {
    var font: Font?
    var fallbackFont: Font?
    var weight: Font.Weight?
    var isItalic = false
    var color: Color?
    var background: Color?
    var isUnderlined = false
    var isStruckThrough = false
    var link: URL?

    init(root attributes: [String: JSONValue]) {
        fallbackFont = Styles.font(attributes["font"]?.string)
        apply(decorations: attributes)
    }

    func merged(_ attributes: [String: JSONValue]) -> Self {
        var span = self
        if let font = Styles.font(attributes["font"]?.string) {
            span.font = font
            span.fallbackFont = font
        }
        span.weight = Styles.weight(attributes["weight"]?.string) ?? weight
        span.color = Styles.color(attributes["color"]?.string) ?? color
        span.background = Styles.color(attributes["background"]?.string) ?? background
        span.apply(decorations: attributes)
        return span
    }

    private mutating func apply(decorations attributes: [String: JSONValue]) {
        if let italic = attributes["italic"] { isItalic = italic.isTrue }
        if let underline = attributes["underline"] { isUnderlined = underline.isTrue }
        if let strikethrough = attributes["strikethrough"] { isStruckThrough = strikethrough.isTrue }
        if let href = attributes["href"]?.string { link = URL(string: href) }
    }

    var container: AttributeContainer {
        var container = AttributeContainer()
        var intent: InlinePresentationIntent = []
        if font != nil || (weight != nil && weight != .bold) {
            var resolved = (font ?? fallbackFont ?? .body)
            if let weight { resolved = resolved.weight(weight) }
            if isItalic { resolved = resolved.italic() }
            container.swiftUI.font = resolved
        } else {
            if weight == .bold { intent.insert(.stronglyEmphasized) }
            if isItalic { intent.insert(.emphasized) }
        }
        if !intent.isEmpty { container.inlinePresentationIntent = intent }
        if let color { container.swiftUI.foregroundColor = color }
        if let background { container.swiftUI.backgroundColor = background }
        if isUnderlined { container.swiftUI.underlineStyle = .single }
        if isStruckThrough { container.swiftUI.strikethroughStyle = .single }
        if let link { container.link = link }
        return container
    }
}

extension Styles {
    static func text(_ node: Node) -> Text {
        Text(attributedString(node))
    }

    static func attributedString(_ node: Node) -> AttributedString {
        let span = Span(root: node.attributes)
        guard let source = markdown(node) else { return runs(node, span) }
        var parsed =
            (try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(source)
        parsed.mergeAttributes(span.container, mergePolicy: .keepCurrent)
        return parsed
    }

    private static func markdown(_ node: Node) -> String? {
        switch node.attributes["markdown"] {
        case let .string(source) where !source.isEmpty && source != "false": source
        case let value? where value.isTrue: node.children.filter { $0.kind == .text }.map(\.text).joined()
        default: nil
        }
    }

    private static func runs(_ node: Node, _ span: Span) -> AttributedString {
        var result = AttributedString()
        for child in node.children {
            switch child.kind {
            case .text:
                result.append(AttributedString(child.text, attributes: span.container))
            case .element where child.name == "txt":
                result.append(runs(child, span.merged(child.attributes)))
            case .element, .fragment:
                continue
            }
        }
        return result
    }
}
