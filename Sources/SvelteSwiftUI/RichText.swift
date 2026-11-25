import SwiftUI

struct Span {
    var font: String?
    var size: Double?
    var design: Font.Design?
    var hasFont = false
    var weight: Font.Weight?
    var isItalic = false
    var color: Color?
    var background: Color?
    var isUnderlined = false
    var isStruckThrough = false
    var kerning: Double?
    var tracking: Double?
    var link: URL?

    init(root attributes: [String: JSONValue]) {
        font = attributes["font"]?.string
        size = attributes["size"]?.number
        design = Styles.design(attributes["design"]?.string)
        kerning = attributes["kerning"]?.number
        tracking = attributes["tracking"]?.number
        apply(decorations: attributes)
    }

    func merged(_ attributes: [String: JSONValue]) -> Self {
        var span = self
        let font = attributes["font"]?.string
        let size = attributes["size"]?.number
        if font != nil || size != nil {
            span.font = font ?? span.font
            span.size = size
            span.hasFont = true
        }
        if let design = Styles.design(attributes["design"]?.string) {
            span.design = design
            span.hasFont = true
        }
        span.weight = Styles.weight(attributes["weight"]?.string) ?? weight
        span.color = Styles.color(attributes["color"]?.string) ?? color
        span.background = Styles.color(attributes["background"]?.string) ?? background
        span.kerning = attributes["kerning"]?.number ?? kerning
        span.tracking = attributes["tracking"]?.number ?? tracking
        span.apply(decorations: attributes)
        return span
    }

    private mutating func apply(decorations attributes: [String: JSONValue]) {
        if let italic = attributes["italic"] { isItalic = italic.isTrue }
        if let underline = attributes["underline"] { isUnderlined = underline.isTrue }
        if let strikethrough = attributes["strikethrough"] { isStruckThrough = strikethrough.isTrue }
        if let href = attributes["href"]?.string { link = URL(string: href) }
    }

    private var resolvedFont: Font {
        if let size { return .system(size: size, design: design) }
        if let design { return .system(Styles.textStyle(font) ?? .body, design: design) }
        return Styles.font(font) ?? .body
    }

    var container: AttributeContainer {
        var container = AttributeContainer()
        var intent: InlinePresentationIntent = []
        if hasFont || (weight != nil && weight != .bold) {
            var resolved = resolvedFont
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
        if let kerning { container.swiftUI.kern = kerning }
        if let tracking { container.swiftUI.tracking = tracking }
        if let link { container.link = link }
        return container
    }
}

struct TextView: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        Styles.text(node)
            .lineLimit(attributes["lines"]?.number.map { Int($0) })
            .multilineTextAlignment(Self.alignment(attributes["align"]?.string))
            .ifLet(attributes["linespacing"]?.number) { $0.lineSpacing($1) }
            .ifLet(Styles.truncationMode(attributes["truncation"]?.string)) { $0.truncationMode($1) }
            .ifLet(attributes["minscale"]?.number) { $0.minimumScaleFactor($1) }
            .ifLet(attributes["selectable"]?.isTrue == true ? true : nil) { view, _ in view.textSelection(.enabled) }
    }

    private static func alignment(_ name: String?) -> TextAlignment {
        switch name {
        case "center": .center
        case "trailing": .trailing
        default: .leading
        }
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
