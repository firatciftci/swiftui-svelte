import SwiftUI

struct TextBase: Equatable {
    var font: String?
    var fontName: String?
    var fontFallbacks: Array<String> = []
    var size: Double?
    var design: Font.Design?

    static let keys = ["font", "fontname", "fontfallbacks", "size", "design"]

    func merged(_ attributes: [String: JSONValue]) -> Self {
        var base = self
        let font = attributes["font"]?.string
        let size = attributes["size"]?.number
        if font != nil || size != nil {
            base.font = font ?? base.font
            base.size = size
        }
        base.fontName = attributes["fontname"]?.string ?? base.fontName
        let fallbacks = Styles.names(attributes["fontfallbacks"])
        if !fallbacks.isEmpty { base.fontFallbacks = fallbacks }
        base.design = Styles.design(attributes["design"]?.string) ?? base.design
        return base
    }
}

extension EnvironmentValues {
    @Entry var textBase = TextBase()
}

struct Span {
    var font: String?
    var fontName: String?
    var fontFallbacks: Array<String> = []
    var size: Double?
    var design: Font.Design?
    var hasFont = false
    var weight: Font.Weight?
    var isItalic = false
    var color: Color?
    var background: Color?
    var isUnderlined = false
    var underlinePattern: Text.LineStyle.Pattern?
    var underlineColor: Color?
    var isMonospacedDigit = false
    var baselineOffset: Double?
    var isStruckThrough = false
    var kerning: Double?
    var tracking: Double?
    var link: URL?
    var language: String?

    init(root attributes: [String: JSONValue], base: TextBase = TextBase()) {
        let inherited = base.merged(attributes)
        font = inherited.font
        fontName = inherited.fontName
        fontFallbacks = inherited.fontFallbacks
        size = inherited.size
        design = inherited.design
        kerning = attributes["kerning"]?.number
        tracking = attributes["tracking"]?.number
        language = attributes["lang"]?.string
        apply(decorations: attributes)
    }

    func merged(_ attributes: [String: JSONValue]) -> Self {
        var span = self
        let font = attributes["font"]?.string
        let fontName = attributes["fontname"]?.string
        let size = attributes["size"]?.number
        span.fontName = fontName ?? span.fontName
        let fallbacks = Styles.names(attributes["fontfallbacks"])
        if !fallbacks.isEmpty { span.fontFallbacks = fallbacks }
        if font != nil || size != nil {
            span.font = font ?? span.font
            span.size = size
            span.hasFont = true
        }
        if fontName != nil || !fallbacks.isEmpty { span.hasFont = true }
        if let design = Styles.design(attributes["design"]?.string) {
            span.design = design
            span.hasFont = true
        }
        span.weight = Styles.weight(attributes["weight"]?.string) ?? weight
        span.color = Palette.color(attributes["color"]?.string) ?? color
        span.background = Palette.color(attributes["background"]?.string) ?? background
        span.kerning = attributes["kerning"]?.number ?? kerning
        span.tracking = attributes["tracking"]?.number ?? tracking
        span.language = attributes["lang"]?.string ?? span.language
        span.apply(decorations: attributes)
        return span
    }

    private mutating func apply(decorations attributes: [String: JSONValue]) {
        if let italic = attributes["italic"] { isItalic = italic.isTrue }
        if let underline = attributes["underline"] { isUnderlined = underline.isTrue }
        if let pattern = attributes["underlinestyle"]?.string { underlinePattern = Self.pattern(pattern) }
        if let color = Palette.color(attributes["underlinecolor"]?.string) { underlineColor = color }
        if let monospaced = attributes["monospaceddigit"] { isMonospacedDigit = monospaced.isTrue }
        if let baseline = attributes["baselineoffset"]?.number { baselineOffset = baseline }
        if let strikethrough = attributes["strikethrough"] { isStruckThrough = strikethrough.isTrue }
        if let href = attributes["href"]?.string { link = URL(string: href) }
    }

    private static func pattern(_ name: String) -> Text.LineStyle.Pattern? {
        switch name {
        case "solid": .solid
        case "dotted": .dot
        case "dashed": .dash
        default: nil
        }
    }

    private var resolvedFont: Font {
        if let fontName { return Fonts.custom(fontName, size: size, style: font, fallbacks: fontFallbacks) }
        if let size { return .system(size: size, design: design) }
        if let design { return .system(Styles.textStyle(font) ?? .body, design: design) }
        return Styles.font(font) ?? .body
    }

    var container: AttributeContainer {
        var container = AttributeContainer()
        var intent: InlinePresentationIntent = []
        if hasFont || (isMonospacedDigit && (fontName != nil || size != nil || font != nil)) || (weight != nil && weight != .bold) {
            var resolved = resolvedFont
            if let weight { resolved = resolved.weight(weight) }
            if isItalic { resolved = resolved.italic() }
            if isMonospacedDigit { resolved = resolved.monospacedDigit() }
            container.swiftUI.font = resolved
        } else {
            if weight == .bold { intent.insert(.stronglyEmphasized) }
            if isItalic { intent.insert(.emphasized) }
        }
        if !intent.isEmpty { container.inlinePresentationIntent = intent }
        if let color { container.swiftUI.foregroundColor = color }
        if let background { container.swiftUI.backgroundColor = background }
        if isUnderlined { container.swiftUI.underlineStyle = Text.LineStyle(pattern: underlinePattern ?? .solid, color: underlineColor) }
        if let baselineOffset { container.baselineOffset = baselineOffset }
        if isStruckThrough { container.swiftUI.strikethroughStyle = .single }
        if let kerning { container.swiftUI.kern = kerning }
        if let tracking { container.swiftUI.tracking = tracking }
        if let link { container.link = link }
        if let language { container.languageIdentifier = language }
        return container
    }
}

struct TextView: View {
    let node: Node
    @Environment(\.textBase) private var base

    var body: some View {
        let attributes = node.attributes
        Styles.text(node, base: base)
            .gated(attributes["monospaceddigit"]?.isTrue == true) { $0.monospacedDigit() }
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
    private static let spanAttributes = [
        "kerning", "tracking", "italic", "underline", "underlinestyle", "underlinecolor", "monospaceddigit", "baselineoffset",
        "strikethrough", "href",
    ]

    @MainActor static func text(_ node: Node, base: TextBase = TextBase()) -> Text {
        if let plain = plainText(node) { return Text(plain) }
        return Text(attributedString(node, base: base))
    }

    private static func plainText(_ node: Node) -> String? {
        let attributes = node.attributes
        guard markdown(node) == nil, !spanAttributes.contains(where: { (attributes[$0] ?? .null) != .null }) else { return nil }
        let whitespace = Whitespace(attributes["whitespace"]?.string)
        var isAfterSpace = true
        var result = ""
        for child in node.children {
            switch child.kind {
            case .text: result += whitespace.collapse(child.text, isAfterSpace: &isAfterSpace)
            case .element where child.name == "txt": return nil
            case .element, .fragment: continue
            }
        }
        if whitespace != .pre, result.last == " " { result.removeLast() }
        return result
    }

    static func attributedString(_ node: Node, base: TextBase = TextBase()) -> AttributedString {
        let span = Span(root: node.attributes, base: base)
        let whitespace = Whitespace(node.attributes["whitespace"]?.string)
        guard let source = markdown(node) else {
            var isAfterSpace = true
            var result = runs(node, span, whitespace: whitespace, isAfterSpace: &isAfterSpace)
            if whitespace != .pre, let last = result.characters.indices.last, result.characters[last] == " " {
                result.characters.remove(at: last)
            }
            return result
        }
        var parsed =
            (try? AttributedString(
                markdown: whitespace.collapsed(source), options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(whitespace.collapsed(source))
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

    private static func runs(_ node: Node, _ span: Span, whitespace: Whitespace, isAfterSpace: inout Bool) -> AttributedString {
        var result = AttributedString()
        for child in node.children {
            switch child.kind {
            case .text:
                result.append(AttributedString(whitespace.collapse(child.text, isAfterSpace: &isAfterSpace), attributes: span.container))
            case .element where child.name == "txt":
                let nested = child.attributes["whitespace"].map { Whitespace($0.string) } ?? whitespace
                result.append(runs(child, span.merged(child.attributes), whitespace: nested, isAfterSpace: &isAfterSpace))
            case .element, .fragment:
                continue
            }
        }
        return result
    }
}

enum Whitespace {
    case normal
    case preLine
    case pre

    init(_ name: String?) {
        switch name {
        case "pre": self = .pre
        case "pre-line": self = .preLine
        default: self = .normal
        }
    }

    func collapsed(_ text: String) -> String {
        var isAfterSpace = true
        let collapsed = collapse(text, isAfterSpace: &isAfterSpace)
        return self == .pre || !collapsed.hasSuffix(" ") ? collapsed : String(collapsed.dropLast())
    }

    func collapse(_ text: String, isAfterSpace: inout Bool) -> String {
        guard self != .pre else { return text }
        var result = ""
        for character in text {
            if self == .preLine, character.isNewline {
                if result.last == " " { result.removeLast() }
                result.append("\n")
                isAfterSpace = true
            } else if character.isWhitespace {
                if !isAfterSpace { result.append(" ") }
                isAfterSpace = true
            } else {
                result.append(character)
                isAfterSpace = false
            }
        }
        return result
    }
}
