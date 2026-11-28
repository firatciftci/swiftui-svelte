import SwiftUI

enum Gestures {
    static func point(_ point: CGPoint) -> JSONValue {
        ["x": .number(rounded(point.x)), "y": .number(rounded(point.y))]
    }

    static func vector(_ size: CGSize) -> JSONValue {
        ["x": .number(rounded(size.width)), "y": .number(rounded(size.height))]
    }

    static func rounded(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    static func drag(_ value: DragGesture.Value, phase: String) -> JSONValue {
        [
            "phase": .string(phase),
            "location": point(value.location),
            "start": point(value.startLocation),
            "translation": vector(value.translation),
            "velocity": vector(value.velocity),
            "predictedEnd": point(value.predictedEndLocation),
        ]
    }

    static func hover(_ phase: String, _ location: CGPoint?) -> JSONValue {
        guard let location else { return ["phase": .string(phase)] }
        return ["phase": .string(phase), "location": point(location)]
    }

    static func magnify(_ value: MagnifyGesture.Value, phase: String) -> JSONValue {
        ["phase": .string(phase), "magnification": .number(rounded(value.magnification)), "velocity": .number(rounded(value.velocity))]
    }

    static func rotate(_ value: RotateGesture.Value, phase: String) -> JSONValue {
        [
            "phase": .string(phase), "degrees": .number(rounded(value.rotation.degrees)),
            "velocity": .number(rounded(value.velocity.degrees)),
        ]
    }
}

struct GestureHandlers: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .modifier(Taps(node: node, count: max(Int(attributes["tapcount"]?.number ?? 1), 1)))
            .modifier(Drags(node: node, minimumDistance: max(attributes["dragdistance"]?.number ?? 10, 0)))
            .modifier(Pinches(node: node))
    }
}

private struct Taps: ViewModifier {
    let node: Node
    let count: Int
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let id = node.id
        let duration = max(node.attributes["longpressduration"]?.number ?? 500, 0) / 1000
        content
            .ifLet(node.listens(to: "longpress") ? id : nil) { view, id in
                view.onLongPressGesture(minimumDuration: duration) { runtime.dispatch(id, "longpress") }
            }
            .ifLet(node.listens(to: "tap") ? id : nil) { view, id in
                view.onTapGesture(count: count) { location in
                    runtime.dispatch(id, "tap", Gestures.point(location))
                }
            }
    }
}

private struct Drags: ViewModifier {
    let node: Node
    let minimumDistance: Double
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        content.ifLet(node.listens(to: "drag") ? node.id : nil) { view, id in
            view.simultaneousGesture(
                DragGesture(minimumDistance: minimumDistance)
                    .onChanged { runtime.dispatch(id, "drag", Gestures.drag($0, phase: "changed")) }
                    .onEnded { runtime.dispatch(id, "drag", Gestures.drag($0, phase: "ended")) }
            )
        }
    }
}

struct PointerEvents: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    @State private var isInside = false

    func body(content: Content) -> some View {
        content.ifLet(node.listens(to: "hover") ? node.id : nil) { view, id in
            view.onContinuousHover { phase in
                switch phase {
                case let .active(location):
                    runtime.dispatch(id, "hover", Gestures.hover(isInside ? "move" : "enter", location))
                    isInside = true
                case .ended:
                    runtime.dispatch(id, "hover", Gestures.hover("exit", nil))
                    isInside = false
                }
            }
        }
    }
}

private struct Pinches: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let magnifies = node.listens(to: "magnify")
        let rotates = node.listens(to: "rotate")
        content.ifLet(magnifies || rotates ? node.id : nil) { view, id in
            view.simultaneousGesture(
                MagnifyGesture().simultaneously(with: RotateGesture())
                    .onChanged { send($0, "changed", to: id, magnifies: magnifies, rotates: rotates) }
                    .onEnded { send($0, "ended", to: id, magnifies: magnifies, rotates: rotates) }
            )
        }
    }

    private func send(
        _ value: SimultaneousGesture<MagnifyGesture, RotateGesture>.Value, _ phase: String, to id: Int, magnifies: Bool,
        rotates: Bool
    ) {
        if magnifies, let magnify = value.first {
            runtime.dispatch(id, "magnify", Gestures.magnify(magnify, phase: phase))
        }
        if rotates, let rotate = value.second {
            runtime.dispatch(id, "rotate", Gestures.rotate(rotate, phase: phase))
        }
    }
}
