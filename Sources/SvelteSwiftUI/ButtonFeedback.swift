import SwiftUI

struct ButtonFeedback {
    let overrides: [String: JSONValue]
    let animation: Animation

    init?(_ value: JSONValue?) {
        guard case let .object(options) = value else { return nil }
        overrides = options.filter { $0.key != "animation" }
        animation = (MotionCurve(options["animation"]) ?? MotionCurve()).animation
    }
}

struct ButtonPress: Equatable {
    var isPressed = false
    var isHovered = false
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
            let isPressed = configuration.isPressed
            let active = isPressed ? pressed : (isHovered ? hovered : nil)
            let overrides = active?.overrides ?? [:]
            let animation = active?.animation ?? .easeInOut(duration: 0.2)
            configuration.label
                .environment(\.buttonPress, ButtonPress(isPressed: isPressed, isHovered: isHovered))
                .onChange(of: overrides, initial: true) { _, overrides in
                    withAnimation(animation) {
                        for label in labels { label.labelFeedback = overrides }
                    }
                }
                .onHover { isHovered = $0 }
        }
    }
}

struct StateFeedback: ViewModifier {
    let node: Node
    @Environment(\.buttonPress) private var press

    func body(content: Content) -> some View {
        content.onChange(of: press, initial: true) { _, press in
            let active =
                press.isPressed
                ? ButtonFeedback(node.attributes["pressed"])
                : (press.isHovered ? ButtonFeedback(node.attributes["hovered"]) : nil)
            withAnimation(active?.animation ?? .easeInOut(duration: 0.2)) {
                node.stateFeedback = active?.overrides ?? [:]
            }
        }
    }
}
