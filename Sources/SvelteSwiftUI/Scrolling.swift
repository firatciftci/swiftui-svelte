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
        content
            .scrollIndicators(Self.indicators(attributes["indicators"]))
            .ifLet(Self.bounce(attributes["bounce"]?.string)) { $0.scrollBounceBehavior($1) }
            .ifLet(UnitPoint(anchor: attributes["anchor"]?.string)) { $0.defaultScrollAnchor($1) }
            .modifier(SnapBehavior(snap: attributes["snap"]?.string))
            .modifier(Refreshing(node: node))
            .ifLet(node.listens(to: "scroll") ? node.id : nil) { view, id in
                view.onScrollGeometryChange(
                    for: ScrollPayload.self,
                    of: ScrollPayload.init,
                    action: { _, payload in runtime.dispatch(id, "scroll", payload.dictionary, waits: false) }
                )
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

    var dictionary: [String: Double] {
        ["x": x, "y": y, "width": width, "height": height, "contentWidth": contentWidth, "contentHeight": contentHeight]
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
        if node.listens(to: "resize") {
            let id = node.id
            content.onGeometryChange(
                for: CGSize.self,
                of: { $0.size },
                action: { size in
                    runtime.dispatch(id, "resize", ["width": points(size.width), "height": points(size.height)], waits: false)
                }
            )
        } else {
            content
        }
    }
}
