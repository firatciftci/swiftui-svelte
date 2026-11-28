import SwiftUI

extension Node {
    func listens(to type: String) -> Bool {
        guard case let .array(types) = attributes["listens"] else { return false }
        return types.contains(.string(type))
    }
}

private func points(_ value: CGFloat) -> Double {
    (Double(value) * 100).rounded() / 100
}

struct ScrollOptions: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let attributes = node.attributes
        let id = node.id
        content
            .scrollIndicators(Self.indicators(attributes["indicators"]))
            .scrollBounceBehavior(Self.bounce(attributes["bounce"]?.string) ?? .automatic)
            .defaultScrollAnchor(UnitPoint(anchor: attributes["anchor"]?.string))
            .scrollDisabled(attributes["scrolldisabled"]?.isTrue ?? false)
            .modifier(SnapBehavior(snap: attributes["snap"]?.string))
            .modifier(Refreshing(node: node))
            .onScrollGeometryChange(
                for: ScrollPayload?.self,
                of: { [scrolls = node.listens(to: "scroll")] in scrolls ? ScrollPayload($0) : nil },
                action: { _, payload in if let payload { runtime.dispatch(id, "scroll", payload.json) } }
            )
            .onScrollPhaseChange { _, phase in
                guard node.listens(to: "scrollphase") else { return }
                runtime.dispatch(id, "scrollphase", ["phase": .string(Self.phase(phase))])
            }
    }

    static func phase(_ phase: ScrollPhase) -> String {
        switch phase {
        case .idle: "idle"
        case .tracking: "tracking"
        case .interacting: "interacting"
        case .decelerating: "decelerating"
        case .animating: "animating"
        }
    }

    static func indicators(_ value: JSONValue?) -> ScrollIndicatorVisibility {
        switch value {
        case .bool(false), .string("hidden"), .string("false"): .hidden
        case .string("never"): .never
        case .string("visible"): .visible
        default: .automatic
        }
    }

    static func bounce(_ name: String?) -> ScrollBounceBehavior? {
        switch name {
        case "automatic": .automatic
        case "always": .always
        case "basedOnSize": .basedOnSize
        default: nil
        }
    }
}

private struct SnapBehavior: ViewModifier {
    let snap: String?

    func body(content: Content) -> some View {
        switch snap {
        case "paging": content.scrollTargetBehavior(.paging)
        case "view": content.scrollTargetBehavior(.viewAligned)
        default: content
        }
    }
}

struct ScrollVisibility: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let id = node.id
        let threshold = CGFloat(node.attributes["visibilitythreshold"]?.number ?? 0)
        content.onScrollVisibilityChange(threshold: threshold) { visible in
            if node.listens(to: "scrollvisibility") { runtime.dispatch(id, "scrollvisibility", ["visible": .bool(visible)]) }
        }
    }
}

struct ScrollPayload: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let contentWidth: Double
    let contentHeight: Double

    init(_ geometry: ScrollGeometry) {
        x = points(geometry.contentOffset.x + geometry.contentInsets.leading)
        y = points(geometry.contentOffset.y + geometry.contentInsets.top)
        width = points(geometry.containerSize.width)
        height = points(geometry.containerSize.height)
        contentWidth = points(geometry.contentSize.width)
        contentHeight = points(geometry.contentSize.height)
    }

    var json: JSONValue {
        [
            "x": .number(x), "y": .number(y), "width": .number(width), "height": .number(height),
            "contentWidth": .number(contentWidth), "contentHeight": .number(contentHeight),
        ]
    }
}

private struct Refreshing: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        if node.listens(to: "refresh") {
            let id = node.id
            content.refreshable { await runtime.dispatchAndWait(id, "refresh") }
        } else {
            content
        }
    }
}

struct Resizing: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let id = node.id
        let isMeasured = node.listens(to: "resize") || node.attributes["container"] != nil
        content.onGeometryChange(
            for: CGSize?.self,
            of: { isMeasured ? $0.size : nil },
            action: { size in
                guard let size else { return }
                runtime.dispatch(id, "resize", ["width": .number(points(size.width)), "height": .number(points(size.height))])
            }
        )
    }
}
