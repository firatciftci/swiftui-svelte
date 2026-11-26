import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct ButtonFeedbackTests {
    @Test func keepsEveryKeyExceptTheAnimationAsAnOverride() throws {
        let feedback = try #require(
            ButtonFeedback(
                .object([
                    "scale": .number(0.95), "shadow": .bool(false), "colormultiply": .string("#dddddd"),
                    "animation": .string("snappy"),
                ])))
        #expect(feedback.overrides == ["scale": .number(0.95), "shadow": .bool(false), "colormultiply": .string("#dddddd")])
        #expect(feedback.animation == (MotionCurve(.string("snappy")) ?? MotionCurve()).animation)
    }

    @Test func ignoresValuesThatAreNotObjects() {
        #expect(ButtonFeedback(nil) == nil)
        #expect(ButtonFeedback(.string("pressed")) == nil)
    }

    @Test func overridesTheLabelsAttributesOnlyWhileActive() {
        let node = Node(id: 1, kind: .element, name: "txt", text: "")
        node.attributes = ["background": .string("red"), "radius": .number(8), "shadow": .number(4)]
        node.feedback = ["background": .string("blue"), "shadow": .bool(false)]
        #expect(node.attributes["background"] == .string("blue"))
        #expect(node.attributes["radius"] == .number(8))
        #expect(node.attributes["shadow"] == .bool(false))
        node.feedback = [:]
        #expect(node.attributes["background"] == .string("red"))
        #expect(node.attributes["shadow"] == .number(4))
    }
}
