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
        let width: CGFloat
    }

    static func border(_ value: JSONValue?) -> Border? {
        switch value {
        case .string:
            return Palette.style(value).map { Border(style: $0, width: 1) }
        case let .object(options):
            let style = Palette.style(options["color"]) ?? AnyShapeStyle(.separator)
            return Border(style: style, width: max(options["width"]?.number ?? 1, 0))
        default:
            return nil
        }
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
            .ifLet(Effects.border(attributes["border"])) { $0.border($1.style, width: $1.width) }
            .ifLet(Effects.shadow(attributes["shadow"])) { $0.shadow(color: $1.color, radius: $1.radius, x: $1.x, y: $1.y) }
            .ifLet(attributes["blur"]?.number) { $0.blur(radius: max($1, 0)) }
            .ifLet(node.attachment("maskview")) { view, mask in
                view.mask(alignment: Styles.alignment(mask.attributes["alignment"]?.string)) { Slot(node: mask) }
            }
            .ifLet(Effects.shape(attributes["contentshape"])) { $0.contentShape($1) }
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
                view.safeAreaInset(edge: .top, alignment: horizontal(inset), spacing: spacing(inset)) { Slot(node: inset) }
            }
            .ifLet(inset("bottom")) { view, inset in
                view.safeAreaInset(edge: .bottom, alignment: horizontal(inset), spacing: spacing(inset)) { Slot(node: inset) }
            }
            .ifLet(inset("leading")) { view, inset in
                view.safeAreaInset(edge: .leading, alignment: vertical(inset), spacing: spacing(inset)) { Slot(node: inset) }
            }
            .ifLet(inset("trailing")) { view, inset in
                view.safeAreaInset(edge: .trailing, alignment: vertical(inset), spacing: spacing(inset)) { Slot(node: inset) }
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
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            Canvas { context, size in
                let path = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: CGRect(origin: .zero, size: size))
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
