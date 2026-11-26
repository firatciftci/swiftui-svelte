import SwiftUI

struct ButtonFeedback {
    let scale: CGFloat?
    let opacity: Double?
    let brightness: Double?
    let background: AnyShapeStyle?
    let color: AnyShapeStyle?
    let shadow: Effects.Shadow?
    let animation: Animation

    init?(_ value: JSONValue?) {
        guard case let .object(options) = value else { return nil }
        scale = options["scale"]?.number.map { CGFloat($0) }
        opacity = options["opacity"]?.number
        brightness = options["brightness"]?.number
        background = Palette.style(options["background"])
        color = Palette.style(options["color"])
        shadow = Effects.shadow(options["shadow"])
        animation = (MotionCurve(options["animation"]) ?? MotionCurve()).animation
    }
}

struct FeedbackButtonStyle: ButtonStyle {
    let pressed: ButtonFeedback?
    let hovered: ButtonFeedback?

    func makeBody(configuration: Configuration) -> some View {
        FeedbackBody(configuration: configuration, pressed: pressed, hovered: hovered)
    }

    private struct FeedbackBody: View {
        let configuration: Configuration
        let pressed: ButtonFeedback?
        let hovered: ButtonFeedback?
        @State private var isHovered = false

        var body: some View {
            let isPressed = configuration.isPressed
            let active = isPressed ? pressed : (isHovered ? hovered : nil)
            let phase = isPressed ? 2 : (isHovered ? 1 : 0)
            configuration.label
                .modifier(FeedbackEffects(feedback: active))
                .animation(active?.animation ?? .easeInOut(duration: 0.2), value: phase)
                .onHover { isHovered = $0 }
        }
    }
}

private struct FeedbackEffects: ViewModifier {
    let feedback: ButtonFeedback?

    func body(content: Content) -> some View {
        content
            .scaleEffect(feedback?.scale ?? 1)
            .opacity(feedback?.opacity ?? 1)
            .brightness(feedback?.brightness ?? 0)
            .background { Rectangle().fill(feedback?.background ?? AnyShapeStyle(.clear)) }
            .ifLet(feedback?.color) { $0.foregroundStyle($1) }
            .ifLet(feedback?.shadow) { $0.shadow(color: $1.color, radius: $1.radius, x: $1.x, y: $1.y) }
    }
}
