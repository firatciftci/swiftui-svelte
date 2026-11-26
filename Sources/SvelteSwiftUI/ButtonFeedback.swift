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

    func active(pressed: ButtonFeedback?, hovered: ButtonFeedback?) -> ButtonFeedback? {
        isPressed ? pressed : (isHovered ? hovered : nil)
    }

    static func animation(from old: ButtonFeedback?, to new: ButtonFeedback?) -> Animation {
        (new ?? old)?.animation ?? .easeInOut(duration: 0.2)
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
            let press = ButtonPress(isPressed: configuration.isPressed, isHovered: isHovered)
            let overrides = press.active(pressed: pressed, hovered: hovered)?.overrides ?? [:]
            configuration.label
                .environment(\.buttonPress, press)
                .onChange(of: Change(press: press, overrides: overrides), initial: true) { old, new in
                    let left = old.press.active(pressed: pressed, hovered: hovered)
                    withAnimation(ButtonPress.animation(from: left, to: new.press.active(pressed: pressed, hovered: hovered))) {
                        for label in labels { label.labelFeedback = new.overrides }
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

struct StateFeedback: ViewModifier {
    let node: Node
    @Environment(\.buttonPress) private var press

    func body(content: Content) -> some View {
        content.onChange(of: press, initial: true) { old, new in
            let pressed = ButtonFeedback(node.attributes["pressed"])
            let hovered = ButtonFeedback(node.attributes["hovered"])
            let active = new.active(pressed: pressed, hovered: hovered)
            withAnimation(ButtonPress.animation(from: old.active(pressed: pressed, hovered: hovered), to: active)) {
                node.stateFeedback = active?.overrides ?? [:]
            }
        }
    }
}
