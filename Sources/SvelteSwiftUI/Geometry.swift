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
        let axes = Self.fixedAxes(attributes["fixedsize"])
        content.fixedSize(horizontal: axes?.horizontal ?? false, vertical: axes?.vertical ?? false)
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
    let isBounded: Bool

    func body(content: Content) -> some View {
        let isBorderBox = attributes["boxsizing"]?.string == "border-box"
        let padding = Geometry.insets(attributes["padding"]) ?? EdgeInsets()
        let border = isBorderBox ? (Effects.border(attributes["border"])?.widths ?? EdgeInsets()) : EdgeInsets()
        let horizontal = isBorderBox ? padding.leading + padding.trailing + border.leading + border.trailing : 0
        let vertical = isBorderBox ? padding.top + padding.bottom + border.top + border.bottom : 0
        let width = inner(attributes, "width", inset: horizontal)
        let height = inner(attributes, "height", inset: vertical)
        let bounds: Array<CGFloat?> = [
            inner(attributes, "minwidth", inset: horizontal), inner(attributes, "idealwidth", inset: horizontal),
            inner(attributes, "maxwidth", inset: horizontal) ?? (width == .infinity ? .infinity : nil),
            inner(attributes, "minheight", inset: vertical), inner(attributes, "idealheight", inset: vertical),
            inner(attributes, "maxheight", inset: vertical) ?? (height == .infinity ? .infinity : nil),
        ]
        let frame = Frame(
            alignment: Styles.alignment(attributes["framealignment"]?.string),
            width: width.flatMap { $0.isFinite ? $0 : nil },
            height: height.flatMap { $0.isFinite ? $0 : nil },
            bounds: bounds,
            isBounded: isBounded
        )
        let ratio = attributes["aspectratio"]?.number.flatMap { $0 > 0 ? CGFloat($0) : nil }
        let mode: ContentMode? =
            switch attributes["contentmode"]?.string {
            case "fill": .fill
            case "fit": .fit
            default: ratio == nil ? nil : .fit
            }
        content
            .ifLet(attributes["linebox"]?.number) { view, height in LineBoxLayout(height: CGFloat(max(height, 0))) { view } }
            .ifLet(mode) { $0.aspectRatio(ratio, contentMode: $1) }
            .modifier(frame)
            .padding(padding)
            .padding(border)
    }
}

private func inner(_ attributes: [String: JSONValue], _ name: String, inset: CGFloat) -> CGFloat? {
    Geometry.length(attributes[name]).map { max($0 - inset, 0) }
}

private struct Frame: ViewModifier {
    let alignment: Alignment
    let width: CGFloat?
    let height: CGFloat?
    let bounds: Array<CGFloat?>
    let isBounded: Bool

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: height, alignment: alignment)
            .gated(isBounded) {
                $0.frame(
                    minWidth: bounds[0], idealWidth: bounds[1], maxWidth: bounds[2],
                    minHeight: bounds[3], idealHeight: bounds[4], maxHeight: bounds[5],
                    alignment: alignment
                )
            }
    }
}

struct Transforms: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        let offset = Geometry.point(attributes["offset"]) ?? .zero
        content
            .offset(x: offset.x, y: offset.y)
            .rotationEffect(
                .degrees(attributes["rotation"]?.number ?? 0), anchor: UnitPoint(anchor: attributes["rotationanchor"]?.string) ?? .center
            )
            .scaleEffect(
                Geometry.scale(attributes["scale"]) ?? CGSize(width: 1, height: 1),
                anchor: UnitPoint(anchor: attributes["scaleanchor"]?.string) ?? .center
            )
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

    var isCentered: Bool {
        horizontal != nil || vertical != nil
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
    let isCentered: Bool

    func body(content: Content) -> some View {
        let margin = Margin(attributes["margin"])
        content
            .padding(margin.insets)
            .gated(isCentered) {
                $0.frame(
                    maxWidth: margin.horizontal == nil ? nil : .infinity,
                    maxHeight: margin.vertical == nil ? nil : .infinity,
                    alignment: Alignment(horizontal: margin.horizontal ?? .center, vertical: margin.vertical ?? .center)
                )
            }
    }
}
