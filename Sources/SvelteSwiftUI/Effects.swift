import SwiftUI

enum Effects {
    static func blendMode(_ name: String?) -> BlendMode? {
        switch name {
        case "normal": .normal
        case "multiply": .multiply
        case "screen": .screen
        case "overlay": .overlay
        case "darken": .darken
        case "lighten": .lighten
        case "color-dodge": .colorDodge
        case "color-burn": .colorBurn
        case "soft-light": .softLight
        case "hard-light": .hardLight
        case "difference": .difference
        case "exclusion": .exclusion
        case "hue": .hue
        case "saturation": .saturation
        case "color": .color
        case "luminosity": .luminosity
        case "plus-lighter": .plusLighter
        case "plus-darker": .plusDarker
        default: nil
        }
    }

    static func shape(_ value: JSONValue?) -> AnyShape? {
        switch value {
        case .string("rectangle"): AnyShape(Rectangle())
        case .string("circle"): AnyShape(Circle())
        case .string("capsule"): AnyShape(Capsule(style: .continuous))
        case .string("ellipse"): AnyShape(Ellipse())
        case let .number(radius): AnyShape(RoundedRectangle(cornerRadius: max(radius, 0), style: .continuous))
        case let .object(options): shape(options)
        default: nil
        }
    }

    static func cornerStyle(_ value: JSONValue?) -> RoundedCornerStyle {
        value?.string == "circular" ? .circular : .continuous
    }

    private static func shape(_ options: [String: JSONValue]) -> AnyShape? {
        if let data = options["d"]?.string {
            return AnyShape(SVGShape(path: SVGPathCache.path(data), viewBox: SVGShape.viewBox(options["viewbox"]?.string)))
        }
        if let radius = options["cornerradius"]?.number {
            return AnyShape(RoundedRectangle(cornerRadius: max(radius, 0), style: .continuous))
        }
        let corners = ["topleading", "bottomleading", "bottomtrailing", "toptrailing"].map { max(options[$0]?.number ?? 0, 0) }
        guard corners.contains(where: { $0 > 0 }) else { return nil }
        return AnyShape(
            UnevenRoundedRectangle(
                cornerRadii: RectangleCornerRadii(
                    topLeading: corners[0], bottomLeading: corners[1], bottomTrailing: corners[2], topTrailing: corners[3]
                ),
                style: .continuous
            ))
    }

    struct Border {
        let style: AnyShapeStyle
        let widths: EdgeInsets
    }

    struct Ring {
        let style: AnyShapeStyle
        let width: CGFloat
    }

    static func ring(_ value: JSONValue?) -> Ring? {
        guard case let .object(options) = value, let width = options["width"]?.number, width > 0 else { return nil }
        return Ring(style: Palette.style(options["color"]) ?? AnyShapeStyle(.foreground), width: CGFloat(width))
    }

    static func border(_ value: JSONValue?) -> Border? {
        switch value {
        case .string:
            return Palette.style(value).map { Border(style: $0, widths: uniform(1)) }
        case let .object(options):
            let style = Palette.style(options["color"]) ?? AnyShapeStyle(.separator)
            return Border(style: style, widths: widths(options["width"]))
        default:
            return nil
        }
    }

    private static func widths(_ value: JSONValue?) -> EdgeInsets {
        guard case let .object(edges) = value else { return uniform(max(CGFloat(value?.number ?? 1), 0)) }
        func width(_ name: String) -> CGFloat { max(CGFloat(edges[name]?.number ?? 0), 0) }
        return EdgeInsets(top: width("top"), leading: width("leading"), bottom: width("bottom"), trailing: width("trailing"))
    }

    private static func uniform(_ width: CGFloat) -> EdgeInsets {
        EdgeInsets(top: width, leading: width, bottom: width, trailing: width)
    }

    struct Shadow: Equatable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static func shadow(_ value: JSONValue?) -> Shadow? {
        let fallback = Color.black.opacity(0.33)
        switch value {
        case let .number(radius):
            return Shadow(color: fallback, radius: max(radius, 0), x: 0, y: 0)
        case let .string(name):
            return Palette.color(name).map { Shadow(color: $0, radius: 4, x: 0, y: 0) }
        case let .object(options):
            return Shadow(
                color: Palette.color(options["color"]?.string) ?? fallback,
                radius: max(options["radius"]?.number ?? 4, 0),
                x: options["x"]?.number ?? 0,
                y: options["y"]?.number ?? 0
            )
        default:
            return nil
        }
    }

    static func edges(_ value: JSONValue?) -> Edge.Set? {
        switch value {
        case let .string(name): edge(name)
        case let .array(names):
            union(names.compactMap { $0.string.flatMap(edge) })
        default: nil
        }
    }

    private static func union(_ sets: Array<Edge.Set>) -> Edge.Set? {
        guard !sets.isEmpty else { return nil }
        var edges = Edge.Set()
        for set in sets { edges.formUnion(set) }
        return edges
    }

    private static func edge(_ name: String) -> Edge.Set? {
        switch name {
        case "all": .all
        case "top": .top
        case "bottom": .bottom
        case "leading": .leading
        case "trailing": .trailing
        case "horizontal": .horizontal
        case "vertical": .vertical
        default: nil
        }
    }

    struct SafeArea: Equatable {
        let regions: SafeAreaRegions
        let edges: Edge.Set
    }

    static func ignoredSafeArea(_ value: JSONValue?) -> SafeArea? {
        func regions(_ name: String?) -> SafeAreaRegions? {
            switch name {
            case "all": .all
            case "container": .container
            case "keyboard": .keyboard
            default: nil
            }
        }
        switch value {
        case .bool(true), .string(""): return SafeArea(regions: .all, edges: .all)
        case let .string(name) where name != "all" && regions(name) != nil:
            return SafeArea(regions: regions(name) ?? .all, edges: .all)
        case .string, .array:
            return edges(value).map { SafeArea(regions: .all, edges: $0) }
        case let .object(options):
            return SafeArea(regions: regions(options["regions"]?.string) ?? .all, edges: edges(options["edges"]) ?? .all)
        default:
            return nil
        }
    }
}

struct Decorations: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .ifLet(Effects.shape(attributes["clipshape"])) { $0.clipShape($1) }
            .ifLet(Effects.shadow(attributes["shadow"])) { $0.shadow(color: $1.color, radius: $1.radius, x: $1.x, y: $1.y) }
            .ifLet(attributes["blur"]?.number) { $0.blur(radius: max($1, 0)) }
            .ifLet(node.attachment("maskview")) { view, mask in
                view.mask(alignment: Styles.alignment(mask.attributes["alignment"]?.string)) { Children(node: mask) }
            }
            .ifLet(Effects.shape(attributes["contentshape"])) { $0.contentShape($1) }
            .ifLet(Effects.ring(attributes["ring"])) { view, ring in
                view.overlay {
                    RingStroke(
                        width: ring.width, radius: max(CGFloat(attributes["radius"]?.number ?? 0), 0),
                        style: Effects.cornerStyle(attributes["cornerstyle"])
                    )
                    .stroke(ring.style, lineWidth: ring.width)
                    .allowsHitTesting(false)
                }
            }
    }
}

struct Availability: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .ifLet(attributes["disabled"]) { $0.disabled($1.isTrue) }
            .ifLet(attributes["hidden"]?.isTrue == true ? true : nil) { view, _ in view.hidden() }
            .ifLet(attributes["allowshittesting"].map(\.isTrue)) { $0.allowsHitTesting($1) }
            .ifLet(Effects.ignoredSafeArea(attributes["ignoressafearea"])) { $0.ignoresSafeArea($1.regions, edges: $1.edges) }
    }
}

struct SafeAreaInsets: ViewModifier {
    let node: Node

    private var insets: Array<Node> {
        node.children.filter { $0.kind == .element && $0.name == "safeareainset" }
    }

    func body(content: Content) -> some View {
        content
            .ifLet(inset("top")) { view, inset in
                view.safeAreaInset(edge: .top, alignment: horizontal(inset), spacing: spacing(inset)) { Children(node: inset) }
            }
            .ifLet(inset("bottom")) { view, inset in
                view.safeAreaInset(edge: .bottom, alignment: horizontal(inset), spacing: spacing(inset)) { Children(node: inset) }
            }
            .ifLet(inset("leading")) { view, inset in
                view.safeAreaInset(edge: .leading, alignment: vertical(inset), spacing: spacing(inset)) { Children(node: inset) }
            }
            .ifLet(inset("trailing")) { view, inset in
                view.safeAreaInset(edge: .trailing, alignment: vertical(inset), spacing: spacing(inset)) { Children(node: inset) }
            }
    }

    private func inset(_ edge: String) -> Node? {
        insets.first { ($0.attributes["edge"]?.string ?? "bottom") == edge }
    }

    private func spacing(_ inset: Node) -> CGFloat? {
        inset.attributes["spacing"]?.number.map { CGFloat($0) }
    }

    private func horizontal(_ inset: Node) -> HorizontalAlignment {
        Styles.horizontalAlignment(inset.attributes["alignment"]?.string)
    }

    private func vertical(_ inset: Node) -> VerticalAlignment {
        Styles.verticalAlignment(inset.attributes["alignment"]?.string)
    }
}

struct InsetShadow: ViewModifier {
    let shape: AnyShape

    init(attributes: [String: JSONValue]) {
        shape =
            Effects.shape(attributes["clipshape"])
            ?? AnyShape(
                RoundedRectangle(
                    cornerRadius: attributes["radius"]?.number ?? 0,
                    style: Effects.cornerStyle(attributes["cornerstyle"])
                )
            )
    }

    func body(content: Content) -> some View {
        content.overlay {
            Canvas { context, size in
                let path = shape.path(in: CGRect(origin: .zero, size: size))
                context.clip(to: path)
                for step in (0..<6).reversed() {
                    let offset = CGFloat(1 << step)
                    var shadow = context
                    shadow.addFilter(.blur(radius: offset))
                    shadow.translateBy(x: 0, y: offset)
                    shadow.stroke(path, with: .color(.black.opacity(0.07)), lineWidth: offset * 2)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

struct Lightening: ViewModifier {
    let amount: Double

    func body(content: Content) -> some View {
        content.compositingGroup().overlay {
            content.compositingGroup().opacity(amount).blendMode(.plusLighter).allowsHitTesting(false)
        }
    }
}

struct BorderBand: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        let isBorderBox = attributes["boxsizing"]?.string == "border-box"
        content.ifLet(Effects.border(attributes["border"])) { view, border in
            view
                .gated(!isBorderBox) { $0.padding(border.widths) }
                .overlay {
                    BorderRing(
                        widths: border.widths, radius: max(CGFloat(attributes["radius"]?.number ?? 0), 0),
                        style: Effects.cornerStyle(attributes["cornerstyle"])
                    )
                    .fill(border.style, style: FillStyle(eoFill: true))
                    .allowsHitTesting(false)
                }
        }
    }
}

struct BorderRing: Shape {
    let widths: EdgeInsets
    let radius: CGFloat
    let style: RoundedCornerStyle

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerSize: CGSize(width: radius, height: radius), style: style)
        let inner = CGRect(
            x: rect.minX + widths.leading,
            y: rect.minY + widths.top,
            width: rect.width - widths.leading - widths.trailing,
            height: rect.height - widths.top - widths.bottom
        )
        let inset = CGSize(
            width: max(radius - max(widths.leading, widths.trailing), 0),
            height: max(radius - max(widths.top, widths.bottom), 0)
        )
        path.addPath(Path(roundedRect: inner, cornerSize: inset, style: style))
        return path
    }
}

struct RingStroke: Shape {
    let width: CGFloat
    let radius: CGFloat
    let style: RoundedCornerStyle

    nonisolated func path(in rect: CGRect) -> Path {
        Path(
            roundedRect: rect.insetBy(dx: -width / 2, dy: -width / 2),
            cornerSize: CGSize(width: radius + width / 2, height: radius + width / 2), style: style)
    }
}
