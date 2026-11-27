import SwiftUI

struct VectorGraphic: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let tree = Vector.Item(node)
        let viewBox = SVGShape.viewBox(attributes["viewBox"]?.string)
        let preservesAspectRatio = attributes["preserveAspectRatio"]?.string != "none"
        let canvas = Canvas { context, size in
            if let viewBox { context.concatenate(Vector.fit(viewBox, in: size, preservingAspectRatio: preservesAspectRatio)) }
            Vector.draw(tree.children, in: context, style: Vector.Style())
        }
        let aspect = viewBox.map { $0.width / max($0.height, 1) }
        let width = Vector.length(attributes["width"])
        let height = Vector.length(attributes["height"])
        Group {
            switch (width, height) {
            case let (width?, height?): canvas.frame(width: width, height: height)
            case let (width?, nil): canvas.frame(width: width, height: width / (aspect ?? 2))
            case let (nil, height?): canvas.frame(width: height * (aspect ?? 2), height: height)
            case (nil, nil) where aspect == nil: canvas.frame(width: 300, height: 150)
            case (nil, nil): canvas.aspectRatio(aspect, contentMode: .fit).frame(maxWidth: .infinity)
            }
        }
        .modifier(VectorAccessibility(attributes: attributes, title: tree.title))
    }
}

private struct VectorAccessibility: ViewModifier {
    let attributes: [String: JSONValue]
    let title: String?

    func body(content: Content) -> some View {
        if attributes["aria-hidden"]?.string == "true" {
            content.accessibilityHidden(true)
        } else if let label = attributes["aria-label"]?.string ?? title {
            content.accessibilityElement(children: .ignore).accessibilityLabel(label).accessibilityAddTraits(.isImage)
        } else {
            content
        }
    }
}

enum Vector {
    struct Item {
        let name: String
        let attributes: [String: String]
        let text: String
        let children: Array<Self>

        init(_ node: Node) {
            name = node.name
            var attributes: [String: String] = [:]
            for (key, value) in node.attributes {
                switch value {
                case let .string(text): attributes[key] = text
                case let .number(number): attributes[key] = String(number)
                case let .bool(flag): attributes[key] = String(flag)
                default: continue
                }
            }
            if let style = attributes["style"] {
                for declaration in style.split(separator: ";") {
                    let parts = declaration.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2 else { continue }
                    attributes[parts[0].trimmingCharacters(in: .whitespaces)] = parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
            self.attributes = attributes
            text = node.kind == .text ? node.text : ""
            children = node.children.filter { $0.kind != .fragment }.map(Self.init)
        }

        var title: String? {
            children.first { $0.name == "title" }.map(\.content)
        }

        var content: String {
            guard name.isEmpty else { return children.map(\.content).joined() }
            return text
        }
    }

    enum Paint {
        case color(Color)
        case current
    }

    struct Style {
        var fill: Paint? = .color(.black)
        var stroke: Paint?
        var fillOpacity = 1.0
        var strokeOpacity = 1.0
        var strokeWidth = 1.0
        var lineCap: CGLineCap = .butt
        var lineJoin: CGLineJoin = .miter
        var dash: Array<CGFloat> = []
        var dashOffset = 0.0
        var isEvenOdd = false
        var fontSize = 16.0
        var fontWeight: Font.Weight = .regular
        var isMonospaced = false
        var textAnchor = "start"
        var baseline = "auto"

        func merged(_ attributes: [String: String]) -> Self {
            var style = self
            if let fill = attributes["fill"] { style.fill = Vector.paint(fill) }
            if let stroke = attributes["stroke"] { style.stroke = Vector.paint(stroke) }
            if let opacity = attributes["fill-opacity"].flatMap(Vector.number) { style.fillOpacity = opacity }
            if let opacity = attributes["stroke-opacity"].flatMap(Vector.number) { style.strokeOpacity = opacity }
            if let width = attributes["stroke-width"].flatMap(Vector.number) { style.strokeWidth = width }
            switch attributes["stroke-linecap"] {
            case "round": style.lineCap = .round
            case "square": style.lineCap = .square
            case "butt": style.lineCap = .butt
            default: break
            }
            switch attributes["stroke-linejoin"] {
            case "round": style.lineJoin = .round
            case "bevel": style.lineJoin = .bevel
            case "miter": style.lineJoin = .miter
            default: break
            }
            if let dash = attributes["stroke-dasharray"] {
                style.dash = dash == "none" ? [] : Vector.numbers(dash).map { CGFloat($0) }
            }
            if let offset = attributes["stroke-dashoffset"].flatMap(Vector.number) { style.dashOffset = offset }
            if let rule = attributes["fill-rule"] { style.isEvenOdd = rule == "evenodd" }
            if let size = attributes["font-size"] { style.fontSize = Vector.length(size, em: fontSize) ?? fontSize }
            if let weight = attributes["font-weight"] { style.fontWeight = Vector.weight(weight) ?? fontWeight }
            if let family = attributes["font-family"] { style.isMonospaced = family.contains("mono") }
            if let anchor = attributes["text-anchor"] { style.textAnchor = anchor }
            if let baseline = attributes["dominant-baseline"] { style.baseline = baseline }
            return style
        }
    }

    static func draw(_ items: Array<Item>, in context: GraphicsContext, style: Style) {
        for item in items where !item.name.isEmpty {
            let attributes = item.attributes
            guard attributes["display"] != "none", attributes["visibility"] != "hidden" else { continue }
            var context = context
            if let transform = attributes["transform"] { context.concatenate(Self.transform(transform)) }
            if let opacity = attributes["opacity"].flatMap(number) { context.opacity *= opacity }
            let style = style.merged(attributes)
            switch item.name {
            case "g", "a", "svg": draw(item.children, in: context, style: style)
            case "text": text(item, in: context, style: style)
            default:
                guard let path = path(item) else { continue }
                if item.name != "line", item.name != "polyline" || style.fill != nil, let fill = style.fill {
                    context.fill(path, with: shading(fill, opacity: style.fillOpacity), style: FillStyle(eoFill: style.isEvenOdd))
                }
                if let stroke = style.stroke, style.strokeWidth > 0 {
                    let strokeStyle = StrokeStyle(
                        lineWidth: style.strokeWidth, lineCap: style.lineCap, lineJoin: style.lineJoin, dash: style.dash,
                        dashPhase: style.dashOffset)
                    context.stroke(path, with: shading(stroke, opacity: style.strokeOpacity), style: strokeStyle)
                }
            }
        }
    }

    private static func path(_ item: Item) -> Path? {
        let value = { (key: String) in item.attributes[key].flatMap(number) ?? 0 }
        switch item.name {
        case "path":
            return item.attributes["d"].map { SVGPath.parse($0) }
        case "rect":
            let rect = CGRect(x: value("x"), y: value("y"), width: value("width"), height: value("height"))
            guard rect.width > 0, rect.height > 0 else { return nil }
            let rx = item.attributes["rx"].flatMap(number) ?? item.attributes["ry"].flatMap(number) ?? 0
            let ry = item.attributes["ry"].flatMap(number) ?? rx
            guard rx > 0 || ry > 0 else { return Path(rect) }
            return Path(roundedRect: rect, cornerSize: CGSize(width: min(rx, rect.width / 2), height: min(ry, rect.height / 2)))
        case "circle":
            let radius = value("r")
            return Path(ellipseIn: CGRect(x: value("cx") - radius, y: value("cy") - radius, width: radius * 2, height: radius * 2))
        case "ellipse":
            let rx = value("rx")
            let ry = value("ry")
            return Path(ellipseIn: CGRect(x: value("cx") - rx, y: value("cy") - ry, width: rx * 2, height: ry * 2))
        case "line":
            var path = Path()
            path.move(to: CGPoint(x: value("x1"), y: value("y1")))
            path.addLine(to: CGPoint(x: value("x2"), y: value("y2")))
            return path
        case "polyline", "polygon":
            let coordinates = numbers(item.attributes["points"] ?? "")
            var points: Array<CGPoint> = []
            for index in stride(from: 0, to: coordinates.count - 1, by: 2) {
                points.append(CGPoint(x: coordinates[index], y: coordinates[index + 1]))
            }
            guard !points.isEmpty else { return nil }
            var path = Path()
            path.addLines(points)
            if item.name == "polygon" { path.closeSubpath() }
            return path
        default:
            return nil
        }
    }

    private static func text(_ item: Item, in context: GraphicsContext, style: Style) {
        var isAfterSpace = true
        let string = Whitespace.normal.collapse(item.content, isAfterSpace: &isAfterSpace).trimmingCharacters(in: .whitespaces)
        guard !string.isEmpty, let fill = style.fill else { return }
        let font = Font.system(size: style.fontSize, weight: style.fontWeight, design: style.isMonospaced ? .monospaced : .default)
        let resolved = context.resolve(Text(string).font(font).foregroundStyle(paintStyle(fill, opacity: style.fillOpacity)))
        let size = resolved.measure(in: CGSize(width: CGFloat.infinity, height: .infinity))
        let first = { (key: String) in item.attributes[key].flatMap { numbers($0).first } ?? 0 }
        let offset = { (key: String) in item.attributes[key].flatMap { length($0, em: style.fontSize) } ?? 0 }
        var origin = CGPoint(x: first("x") + offset("dx"), y: first("y") + offset("dy"))
        switch style.textAnchor {
        case "middle": origin.x -= size.width / 2
        case "end": origin.x -= size.width
        default: break
        }
        switch style.baseline {
        case "middle", "central": origin.y -= size.height / 2
        case "hanging", "text-before-edge": break
        default: origin.y -= resolved.firstBaseline(in: size)
        }
        context.draw(resolved, in: CGRect(origin: origin, size: size))
    }

    private static func shading(_ paint: Paint, opacity: Double) -> GraphicsContext.Shading {
        .style(paintStyle(paint, opacity: opacity))
    }

    private static func paintStyle(_ paint: Paint, opacity: Double) -> AnyShapeStyle {
        switch paint {
        case let .color(color): AnyShapeStyle(color.opacity(opacity))
        case .current: AnyShapeStyle(.foreground.opacity(opacity))
        }
    }

    static func fit(_ viewBox: CGRect, in size: CGSize, preservingAspectRatio: Bool) -> CGAffineTransform {
        guard viewBox.width > 0, viewBox.height > 0 else { return .identity }
        var scaleX = size.width / viewBox.width
        var scaleY = size.height / viewBox.height
        if preservingAspectRatio {
            scaleX = min(scaleX, scaleY)
            scaleY = scaleX
        }
        return CGAffineTransform(
            translationX: (size.width - viewBox.width * scaleX) / 2 - viewBox.minX * scaleX,
            y: (size.height - viewBox.height * scaleY) / 2 - viewBox.minY * scaleY
        )
        .scaledBy(x: scaleX, y: scaleY)
    }

    static func transform(_ value: String) -> CGAffineTransform {
        var transform = CGAffineTransform.identity
        var rest = Substring(value)
        while let open = rest.firstIndex(of: "("), let close = rest[open...].firstIndex(of: ")") {
            let name = rest[..<open].trimmingCharacters(in: CharacterSet(charactersIn: " ,\n\t"))
            let arguments = numbers(String(rest[rest.index(after: open)..<close]))
            let argument = { (index: Int, fallback: Double) in arguments.indices.contains(index) ? arguments[index] : fallback }
            let next: CGAffineTransform =
                switch name {
                case "translate": CGAffineTransform(translationX: argument(0, 0), y: argument(1, 0))
                case "scale": CGAffineTransform(scaleX: argument(0, 1), y: argument(1, argument(0, 1)))
                case "rotate":
                    CGAffineTransform(translationX: argument(1, 0), y: argument(2, 0))
                        .rotated(by: argument(0, 0) * .pi / 180)
                        .translatedBy(x: -argument(1, 0), y: -argument(2, 0))
                case "skewX": CGAffineTransform(a: 1, b: 0, c: tan(argument(0, 0) * .pi / 180), d: 1, tx: 0, ty: 0)
                case "skewY": CGAffineTransform(a: 1, b: tan(argument(0, 0) * .pi / 180), c: 0, d: 1, tx: 0, ty: 0)
                case "matrix" where arguments.count == 6:
                    CGAffineTransform(
                        a: arguments[0], b: arguments[1], c: arguments[2], d: arguments[3], tx: arguments[4], ty: arguments[5])
                default: .identity
                }
            transform = next.concatenating(transform)
            rest = rest[rest.index(after: close)...]
        }
        return transform
    }

    static func paint(_ value: String) -> Paint? {
        let value = value.trimmingCharacters(in: .whitespaces)
        switch value.lowercased() {
        case "none", "transparent": return nil
        case "currentcolor": return .current
        default:
            if let rgb = cssColors[value.lowercased()] {
                return .color(
                    Color(
                        .sRGB, red: Double(rgb >> 16 & 0xFF) / 255, green: Double(rgb >> 8 & 0xFF) / 255,
                        blue: Double(rgb & 0xFF) / 255))
            }
            return Palette.color(value).map(Paint.color)
        }
    }

    static func number(_ value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "px", with: ""))
    }

    static func numbers(_ value: String) -> Array<Double> {
        var result: Array<Double> = []
        var token = ""
        for character in value {
            if character == "-", !token.isEmpty, token.last != "e" {
                if let number = Double(token) { result.append(number) }
                token = "-"
            } else if character.isNumber || character == "." || character == "e" || character == "-" || character == "+" {
                if character == ".", token.contains("."), !token.contains("e") {
                    if let number = Double(token) { result.append(number) }
                    token = "."
                } else {
                    token.append(character)
                }
            } else {
                if let number = Double(token) { result.append(number) }
                token = ""
            }
        }
        if let number = Double(token) { result.append(number) }
        return result
    }

    static func length(_ value: JSONValue?) -> Double? {
        switch value {
        case let .number(number): number
        case let .string(text): length(text, em: 16)
        default: nil
        }
    }

    static func length(_ value: String, em: Double) -> Double? {
        let value = value.trimmingCharacters(in: .whitespaces)
        if value.hasSuffix("%") { return nil }
        if value.hasSuffix("em") { return Double(value.dropLast(2)).map { $0 * em } }
        return number(value)
    }

    private static func weight(_ value: String) -> Font.Weight? {
        switch value {
        case "bold", "bolder": .bold
        case "normal", "lighter": .regular
        default:
            switch Int(value) ?? 0 {
            case 100: .ultraLight
            case 200: .thin
            case 300: .light
            case 400: .regular
            case 500: .medium
            case 600: .semibold
            case 700: .bold
            case 800: .heavy
            case 900: .black
            default: nil
            }
        }
    }

    private static let cssColors = colorTable()

    private static func colorTable() -> [String: UInt32] {
        let table = """
            aliceblue f0f8ff antiquewhite faebd7 aqua 00ffff aquamarine 7fffd4 azure f0ffff beige f5f5dc bisque ffe4c4
            black 000000 blanchedalmond ffebcd blue 0000ff blueviolet 8a2be2 brown a52a2a burlywood deb887 cadetblue 5f9ea0
            chartreuse 7fff00 chocolate d2691e coral ff7f50 cornflowerblue 6495ed cornsilk fff8dc crimson dc143c cyan 00ffff
            darkblue 00008b darkcyan 008b8b darkgoldenrod b8860b darkgray a9a9a9 darkgreen 006400 darkgrey a9a9a9
            darkkhaki bdb76b darkmagenta 8b008b darkolivegreen 556b2f darkorange ff8c00 darkorchid 9932cc darkred 8b0000
            darksalmon e9967a darkseagreen 8fbc8f darkslateblue 483d8b darkslategray 2f4f4f darkslategrey 2f4f4f
            darkturquoise 00ced1 darkviolet 9400d3 deeppink ff1493 deepskyblue 00bfff dimgray 696969 dimgrey 696969
            dodgerblue 1e90ff firebrick b22222 floralwhite fffaf0 forestgreen 228b22 fuchsia ff00ff gainsboro dcdcdc
            ghostwhite f8f8ff gold ffd700 goldenrod daa520 gray 808080 green 008000 greenyellow adff2f grey 808080
            honeydew f0fff0 hotpink ff69b4 indianred cd5c5c indigo 4b0082 ivory fffff0 khaki f0e68c lavender e6e6fa
            lavenderblush fff0f5 lawngreen 7cfc00 lemonchiffon fffacd lightblue add8e6 lightcoral f08080 lightcyan e0ffff
            lightgoldenrodyellow fafad2 lightgray d3d3d3 lightgreen 90ee90 lightgrey d3d3d3 lightpink ffb6c1
            lightsalmon ffa07a lightseagreen 20b2aa lightskyblue 87cefa lightslategray 778899 lightslategrey 778899
            lightsteelblue b0c4de lightyellow ffffe0 lime 00ff00 limegreen 32cd32 linen faf0e6 magenta ff00ff maroon 800000
            mediumaquamarine 66cdaa mediumblue 0000cd mediumorchid ba55d3 mediumpurple 9370db mediumseagreen 3cb371
            mediumslateblue 7b68ee mediumspringgreen 00fa9a mediumturquoise 48d1cc mediumvioletred c71585
            midnightblue 191970 mintcream f5fffa mistyrose ffe4e1 moccasin ffe4b5 navajowhite ffdead navy 000080
            oldlace fdf5e6 olive 808000 olivedrab 6b8e23 orange ffa500 orangered ff4500 orchid da70d6 palegoldenrod eee8aa
            palegreen 98fb98 paleturquoise afeeee palevioletred db7093 papayawhip ffefd5 peachpuff ffdab9 peru cd853f
            pink ffc0cb plum dda0dd powderblue b0e0e6 purple 800080 rebeccapurple 663399 red ff0000 rosybrown bc8f8f
            royalblue 4169e1 saddlebrown 8b4513 salmon fa8072 sandybrown f4a460 seagreen 2e8b57 seashell fff5ee
            sienna a0522d silver c0c0c0 skyblue 87ceeb slateblue 6a5acd slategray 708090 slategrey 708090 snow fffafa
            springgreen 00ff7f steelblue 4682b4 tan d2b48c teal 008080 thistle d8bfd8 tomato ff6347 turquoise 40e0d0
            violet ee82ee wheat f5deb3 white ffffff whitesmoke f5f5f5 yellow ffff00 yellowgreen 9acd32
            """
        let words = table.split(whereSeparator: \.isWhitespace)
        var colors: [String: UInt32] = [:]
        for index in stride(from: 0, to: words.count - 1, by: 2) {
            if let value = UInt32(words[index + 1], radix: 16) { colors[String(words[index])] = value }
        }
        return colors
    }
}
