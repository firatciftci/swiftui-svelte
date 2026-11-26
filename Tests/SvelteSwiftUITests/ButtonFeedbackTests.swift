import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct ButtonFeedbackTests {
    @Test func readsOverridesFromAnObject() throws {
        let feedback = try #require(
            ButtonFeedback(
                .object([
                    "scale": .number(0.95), "opacity": .number(0.8), "brightness": .number(0.1), "color": .string("red"),
                    "animation": .string("snappy"),
                ])))
        #expect(feedback.scale == 0.95)
        #expect(feedback.opacity == 0.8)
        #expect(feedback.brightness == 0.1)
        #expect(feedback.color != nil)
        #expect(feedback.background == nil)
        #expect(feedback.shadow == nil)
        #expect(feedback.animation == (MotionCurve(.string("snappy")) ?? MotionCurve()).animation)
    }

    @Test func ignoresValuesThatAreNotObjects() {
        #expect(ButtonFeedback(nil) == nil)
        #expect(ButtonFeedback(.string("pressed")) == nil)
    }

    @Test func readsShadowsTheSameWayAsTheShadowModifier() {
        #expect(ButtonFeedback(.object(["shadow": .number(8)]))?.shadow == Effects.shadow(.number(8)))
    }
}
