import SwiftUI

enum Geometry {
    static func insets(_ value: JSONValue?) -> EdgeInsets? {
        guard let edges = Edges(value) else { return nil }
        return EdgeInsets(
            top: Styles.padding(edges.top),
            leading: Styles.padding(edges.leading),
            bottom: Styles.padding(edges.bottom),
            trailing: Styles.padding(edges.trailing)
        )
    }

    static func length(_ value: JSONValue?) -> CGFloat? {
        switch value {
        case let .number(length): max(CGFloat(length), 0)
        case .string("infinity"): .infinity
        default: nil
        }
    }

    static func point(_ value: JSONValue?) -> CGPoint? {
        guard case let .object(options) = value else { return nil }
        let x = options["x"]?.number
        let y = options["y"]?.number
        guard x != nil || y != nil else { return nil }
        return CGPoint(x: x ?? 0, y: y ?? 0)
    }

    static func scale(_ value: JSONValue?) -> CGSize? {
        switch value {
        case let .number(factor): CGSize(width: factor, height: factor)
        case let .object(options): CGSize(width: options["x"]?.number ?? 1, height: options["y"]?.number ?? 1)
        default: nil
        }
    }
}

struct Sizing: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(Self.fixedAxes(attributes["fixedsize"])) { $0.fixedSize(horizontal: $1.horizontal, vertical: $1.vertical) }
    }

    private static func fixedAxes(_ value: JSONValue?) -> (horizontal: Bool, vertical: Bool)? {
        switch value?.string {
        case "", "true", "both": (true, true)
        case "horizontal": (true, false)
        case "vertical": (false, true)
        default: nil
        }
    }
}

struct Framing: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        let alignment = Styles.alignment(attributes["framealignment"]?.string)
        let width = Geometry.length(attributes["width"])
        let height = Geometry.length(attributes["height"])
        let bounds: Array<CGFloat?> = [
            Geometry.length(attributes["minwidth"]), Geometry.length(attributes["idealwidth"]),
            Geometry.length(attributes["maxwidth"]) ?? (width == .infinity ? .infinity : nil),
            Geometry.length(attributes["minheight"]), Geometry.length(attributes["idealheight"]),
            Geometry.length(attributes["maxheight"]) ?? (height == .infinity ? .infinity : nil),
        ]
        let frame = Frame(
            alignment: alignment,
            width: width.flatMap { $0.isFinite ? $0 : nil },
            height: height.flatMap { $0.isFinite ? $0 : nil },
            bounds: bounds
        )
        let ratio = attributes["aspectratio"]?.number.flatMap { $0 > 0 ? CGFloat($0) : nil }
        let mode: ContentMode? =
            switch attributes["contentmode"]?.string {
            case "fill": .fill
            case "fit": .fit
            default: ratio == nil ? nil : .fit
            }
        let isBorderBox = attributes["boxsizing"]?.string == "border-box"
        let border = isBorderBox ? (Effects.border(attributes["border"])?.widths ?? EdgeInsets()) : EdgeInsets()
        content
            .ifLet(attributes["linebox"]?.number) { view, height in LineBoxLayout(height: CGFloat(max(height, 0))) { view } }
            .ifLet(mode) { $0.aspectRatio(ratio, contentMode: $1) }
            .gated(!isBorderBox) { $0.modifier(frame) }
            .padding(Geometry.insets(attributes["padding"]) ?? EdgeInsets())
            .gated(isBorderBox) { $0.padding(border).modifier(frame) }
    }
}

private struct Frame: ViewModifier {
    let alignment: Alignment
    let width: CGFloat?
    let height: CGFloat?
    let bounds: Array<CGFloat?>

    func body(content: Content) -> some View {
        content
            .ifLet(width != nil || height != nil ? alignment : nil) { $0.frame(width: width, height: height, alignment: $1) }
            .ifLet(bounds.contains { $0 != nil } ? alignment : nil) {
                $0.frame(
                    minWidth: bounds[0], idealWidth: bounds[1], maxWidth: bounds[2],
                    minHeight: bounds[3], idealHeight: bounds[4], maxHeight: bounds[5],
                    alignment: $1
                )
            }
    }
}

struct Transforms: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(Geometry.point(attributes["offset"])) { $0.offset(x: $1.x, y: $1.y) }
            .ifLet(attributes["rotation"]?.number) {
                $0.rotationEffect(.degrees($1), anchor: UnitPoint(anchor: attributes["rotationanchor"]?.string) ?? .center)
            }
            .ifLet(Geometry.scale(attributes["scale"])) {
                $0.scaleEffect($1, anchor: UnitPoint(anchor: attributes["scaleanchor"]?.string) ?? .center)
            }
            .ifLet(Geometry.point(attributes["position"])) { $0.position(x: $1.x, y: $1.y) }
    }
}

struct Margin {
    let insets: EdgeInsets
    let horizontal: HorizontalAlignment?
    let vertical: VerticalAlignment?

    init(_ value: JSONValue?) {
        let edges = Edges(value)
        func points(_ edge: JSONValue?) -> CGFloat { CGFloat(edge?.number ?? 0) }
        func isAuto(_ edge: JSONValue?) -> Bool { edge?.string == "auto" }
        insets = EdgeInsets(
            top: points(edges?.top), leading: points(edges?.leading), bottom: points(edges?.bottom), trailing: points(edges?.trailing))
        horizontal =
            switch (isAuto(edges?.leading), isAuto(edges?.trailing)) {
            case (true, true): .center
            case (true, false): .trailing
            case (false, true): .leading
            case (false, false): nil
            }
        vertical =
            switch (isAuto(edges?.top), isAuto(edges?.bottom)) {
            case (true, true): .center
            case (true, false): .bottom
            case (false, true): .top
            case (false, false): nil
            }
    }
}

struct Edges {
    let top: JSONValue?
    let leading: JSONValue?
    let bottom: JSONValue?
    let trailing: JSONValue?

    init?(_ value: JSONValue?) {
        switch value {
        case .number, .bool, .string:
            (top, leading, bottom, trailing) = (value, value, value, value)
        case let .object(edges):
            top = edges["top"] ?? edges["vertical"]
            leading = edges["leading"] ?? edges["horizontal"]
            bottom = edges["bottom"] ?? edges["vertical"]
            trailing = edges["trailing"] ?? edges["horizontal"]
        default:
            return nil
        }
    }
}

struct Margins: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        let margin = Margin(attributes["margin"])
        content
            .padding(margin.insets)
            .gated(margin.horizontal != nil || margin.vertical != nil) { view in
                view.frame(
                    maxWidth: margin.horizontal == nil ? nil : .infinity,
                    maxHeight: margin.vertical == nil ? nil : .infinity,
                    alignment: Alignment(horizontal: margin.horizontal ?? .center, vertical: margin.vertical ?? .center)
                )
            }
    }
}
