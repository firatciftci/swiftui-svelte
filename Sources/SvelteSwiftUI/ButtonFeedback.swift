import SwiftUI

struct ButtonFeedback {
    let overrides: [String: JSONValue]
    let animation: Animation?

    init?(_ value: JSONValue?) {
        guard case let .object(options) = value else { return nil }
        overrides = options.filter { $0.key != "animation" }
        animation = MotionCurve.from(options["animation"])?.animation
    }
}

struct ButtonPress: Equatable {
    var isPressed = false
    var isHovered = false
    var isTracked = false

    func active(pressed: ButtonFeedback?, hovered: ButtonFeedback?) -> ButtonFeedback? {
        isPressed ? pressed : (isHovered ? hovered : nil)
    }

    static func animation(from old: ButtonFeedback?, to new: ButtonFeedback?) -> Animation? {
        guard let feedback = new ?? old else { return .easeInOut(duration: 0.2) }
        return feedback.animation
    }
}

extension EnvironmentValues {
    @Entry var buttonPress = ButtonPress()
}

struct FeedbackButtonStyle: ButtonStyle {
    let pressed: ButtonFeedback?
    let hovered: ButtonFeedback?
    let labels: Array<Node>

    func makeBody(configuration: Configuration) -> some View {
        FeedbackBody(configuration: configuration, pressed: pressed, hovered: hovered, labels: labels)
    }

    private struct FeedbackBody: View {
        let configuration: Configuration
        let pressed: ButtonFeedback?
        let hovered: ButtonFeedback?
        let labels: Array<Node>
        @State private var isHovered = false

        var body: some View {
            let press = ButtonPress(isPressed: configuration.isPressed, isHovered: isHovered, isTracked: true)
            let overrides = press.active(pressed: pressed, hovered: hovered)?.overrides ?? [:]
            configuration.label
                .environment(\.buttonPress, press)
                .onChange(of: Change(press: press, overrides: overrides), initial: true) { old, new in
                    let left = old.press.active(pressed: pressed, hovered: hovered)
                    withAnimation(ButtonPress.animation(from: left, to: new.press.active(pressed: pressed, hovered: hovered))) {
                        for label in labels { label.feedback.label = new.overrides }
                    }
                }
                .onHover { isHovered = $0 }
        }

        private struct Change: Equatable {
            let press: ButtonPress
            let overrides: [String: JSONValue]
        }
    }
}

struct PressTracking: ViewModifier {
    let isDraggable: Bool
    @GestureState private var isPressing = false
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .environment(\.buttonPress, ButtonPress(isPressed: isPressing, isHovered: isHovered, isTracked: true))
            .onHover { isHovered = $0 }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: .infinity, maximumDistance: isDraggable ? .infinity : 10)
                    .updating($isPressing) { value, state, _ in state = value }
            )
    }
}

struct StateFeedback: ViewModifier {
    let node: Node
    @Environment(\.buttonPress) private var press
    @Environment(SvelteRuntime.self) private var runtime
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onChange(of: press.isTracked ? press : ButtonPress(isHovered: isHovered), initial: true) { old, new in
                let pressed = ButtonFeedback(node.attributes["pressed"])
                let hovered = ButtonFeedback(node.attributes["hovered"])
                let active = new.active(pressed: pressed, hovered: hovered)
                withAnimation(ButtonPress.animation(from: old.active(pressed: pressed, hovered: hovered), to: active)) {
                    node.feedback.state = active?.overrides ?? [:]
                }
            }
            .onHover { isHovered = $0 }
            #if DEBUG
                .onAppear { warnIfUntracked() }
            #endif
    }

    #if DEBUG
        private func warnIfUntracked() {
            guard !press.isTracked, ButtonFeedback(node.attributes["pressed"]) != nil else { return }
            runtime.store.diagnostics.report(
                "A <\(node.name)> has pressed styles that never apply, because nothing tracks presses on it. Put it inside a <btn>, or give it or an element around it an ontap, onlongpress, or ondrag handler.",
                element: node.name,
                attribute: "pressed",
                location: node.location
            )
        }
    #endif
}
