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
                .onChange(of: overrides, initial: true) { _, overrides in
                    withAnimation(animation) {
                        for label in labels { label.feedback = overrides }
                    }
                }
                .onHover { isHovered = $0 }
        }
    }
}
