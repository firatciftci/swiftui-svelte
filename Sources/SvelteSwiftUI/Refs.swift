import SwiftUI

struct FocusRequest: Equatable {
    var isFocused = false
    var serial = 0
}

struct ScrollRequest: Equatable {
    let target: Int
    let anchor: UnitPoint?
    let isAnimated: Bool
    let serial: Int
}

extension UnitPoint {
    init?(anchor name: String?) {
        switch name {
        case "top": self = .top
        case "center": self = .center
        case "bottom": self = .bottom
        case "leading": self = .leading
        case "trailing": self = .trailing
        case "topLeading": self = .topLeading
        case "topTrailing": self = .topTrailing
        case "bottomLeading": self = .bottomLeading
        case "bottomTrailing": self = .bottomTrailing
        default: return nil
        }
    }
}

struct Focusable: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .onChange(of: node.focusRequest) { _, request in
                isFocused = request.isFocused
            }
            .onChange(of: node.attributes["focused"], initial: true) { _, value in
                guard case let .bool(focused) = value, focused != isFocused else { return }
                DispatchQueue.main.async { isFocused = focused }
            }
            .onChange(of: isFocused) { _, focused in
                runtime.dispatch(node.id, focused ? "focus" : "blur", waits: false)
            }
    }
}

struct Measured: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        content.background {
            if node.isMeasured {
                Color.clear.onGeometryChange(
                    for: CGRect.self,
                    of: { $0.frame(in: .global) },
                    action: { runtime.measured(node, frame: $0) }
                )
            }
        }
    }
}

struct Scrollable: ViewModifier {
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onChange(of: runtime.scrollRequest) { _, request in
                guard let request else { return }
                DispatchQueue.main.async {
                    if request.isAnimated {
                        withAnimation { proxy.scrollTo(request.target, anchor: request.anchor) }
                    } else {
                        proxy.scrollTo(request.target, anchor: request.anchor)
                    }
                }
            }
        }
    }
}
