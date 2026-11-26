import SwiftUI

enum Geometry {
    static func insets(_ value: JSONValue?) -> EdgeInsets? {
        switch value {
        case .number, .bool, .string:
            let length = Styles.padding(value)
            return EdgeInsets(top: length, leading: length, bottom: length, trailing: length)
        case let .object(edges):
            func edge(_ name: String, _ axis: String) -> CGFloat {
                Styles.padding(edges[name] ?? edges[axis])
            }
            return EdgeInsets(
                top: edge("top", "vertical"),
                leading: edge("leading", "horizontal"),
                bottom: edge("bottom", "vertical"),
                trailing: edge("trailing", "horizontal")
            )
        default:
            return nil
        }
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
        let width = attributes["width"]?.number.map { CGFloat(max($0, 0)) }
        let height = attributes["height"]?.number.map { CGFloat(max($0, 0)) }
        let bounds = ["minwidth", "idealwidth", "maxwidth", "minheight", "idealheight", "maxheight"].map {
            Geometry.length(attributes[$0])
        }
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
            .ifLet(width != nil || height != nil ? alignment : nil) { $0.frame(width: width, height: height, alignment: $1) }
            .ifLet(bounds.contains { $0 != nil } ? alignment : nil) {
                $0.frame(
                    minWidth: bounds[0], idealWidth: bounds[1], maxWidth: bounds[2],
                    minHeight: bounds[3], idealHeight: bounds[4], maxHeight: bounds[5],
                    alignment: $1
                )
            }
            .padding(Geometry.insets(attributes["padding"]) ?? EdgeInsets())
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
        var edges: [String: JSONValue] = [:]
        if case let .object(object)? = value { edges = object }
        func points(_ name: String) -> CGFloat { CGFloat(edges[name]?.number ?? 0) }
        func isAuto(_ name: String) -> Bool { edges[name]?.string == "auto" }
        insets = EdgeInsets(top: points("top"), leading: points("leading"), bottom: points("bottom"), trailing: points("trailing"))
        horizontal =
            switch (isAuto("leading"), isAuto("trailing")) {
            case (true, true): .center
            case (true, false): .trailing
            case (false, true): .leading
            case (false, false): nil
            }
        vertical =
            switch (isAuto("top"), isAuto("bottom")) {
            case (true, true): .center
            case (true, false): .bottom
            case (false, true): .top
            case (false, false): nil
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
