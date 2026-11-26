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
        node.labelFeedback = ["background": .string("blue"), "shadow": .bool(false)]
        #expect(node.attributes["background"] == .string("blue"))
        #expect(node.attributes["radius"] == .number(8))
        #expect(node.attributes["shadow"] == .bool(false))
        node.labelFeedback = [:]
        #expect(node.attributes["background"] == .string("red"))
        #expect(node.attributes["shadow"] == .number(4))
    }

    @Test func stateFeedbackOverridesLabelFeedback() {
        let node = Node(id: 1, kind: .element, name: "rectangle", text: "")
        node.attributes = ["opacity": .number(0)]
        node.labelFeedback = ["opacity": .number(0.5)]
        node.stateFeedback = ["opacity": .number(1)]
        #expect(node.attributes["opacity"] == .number(1))
        node.stateFeedback = [:]
        #expect(node.attributes["opacity"] == .number(0.5))
    }

    @Test func findsFeedbackOnAnyDescendantIncludingAttachments() {
        let button = Node(id: 1, kind: .element, name: "btn", text: "")
        let stack = Node(id: 2, kind: .element, name: "hstack", text: "")
        let text = Node(id: 3, kind: .element, name: "txt", text: "")
        let background = Node(id: 4, kind: .element, name: "background", text: "")
        background.attributes = ["pressed": .object(["shadow": .bool(false)])]
        text.children = [background]
        stack.children = [text]
        button.children = [stack]
        #expect(button.hasButtonFeedback)
        #expect(!stack.ownsButtonFeedback)
        #expect(!Node(id: 5, kind: .element, name: "txt", text: "").hasButtonFeedback)
    }
}
