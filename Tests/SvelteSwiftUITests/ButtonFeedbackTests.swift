import SwiftUI
import Testing

@testable import SvelteSwiftUI

private func batch(_ tokens: Array<Any>) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: tokens)) ?? Data()
    return String(bytes: data, encoding: .utf8) ?? ""
}

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

    @Test func turnsOffTheAnimationWhenItIsFalse() {
        #expect(ButtonFeedback(.object(["scale": .number(0.95), "animation": .bool(false)]))?.animation == nil)
    }

    @Test func ignoresValuesThatAreNotObjects() {
        #expect(ButtonFeedback(nil) == nil)
        #expect(ButtonFeedback(.string("pressed")) == nil)
    }

    @Test func overridesTheLabelsAttributesOnlyWhileActive() {
        let node = Node(id: 1, kind: .element, name: "txt", text: "")
        node.setOwnAttributes(["background": .string("red"), "radius": .number(8), "shadow": .number(4)])
        node.feedback.label = ["background": .string("blue"), "shadow": .bool(false)]
        #expect(node.attributes["background"] == .string("blue"))
        #expect(node.attributes["radius"] == .number(8))
        #expect(node.attributes["shadow"] == .bool(false))
        node.feedback.label = [:]
        #expect(node.attributes["background"] == .string("red"))
        #expect(node.attributes["shadow"] == .number(4))
    }

    @Test func stateFeedbackOverridesLabelFeedback() {
        let node = Node(id: 1, kind: .element, name: "rectangle", text: "")
        node.setOwnAttributes(["opacity": .number(0)])
        node.feedback.label = ["opacity": .number(0.5)]
        node.feedback.state = ["opacity": .number(1)]
        #expect(node.attributes["opacity"] == .number(1))
        node.feedback.state = [:]
        #expect(node.attributes["opacity"] == .number(0.5))
    }

    @Test func tracksPressesOnElementsWithTapLongPressOrDragHandlersAndFeedback() throws {
        for type in ["tap", "longpress", "drag"] {
            let store = NodeStore()
            store.apply(
                batch([
                    0, 1, NodeStore.protocolVersion, 0, 7, "vstack", 7, "txt", 7, "listens", 7, "hovered",
                    1, 1, 0, 2, 0, 1, 2, [type], 1, 3, 1, 0, 0,
                ]))
            let card = try #require(store.node(2))
            #expect(!card.tracksPresses)
            store.apply(batch([4, 3, 3, ["opacity": 0.5]]))
            #expect(card.tracksPresses, "\(type)")
        }
        let store = NodeStore()
        store.apply(
            batch([
                0, 1, NodeStore.protocolVersion, 0, 7, "btn", 7, "vstack", 7, "listens", 7, "pressed",
                1, 1, 0, 2, 0, 2, 2, ["tap"], 3, ["scale": 0.9], 0,
                1, 1, 0, 3, 1, 2, 2, ["scroll"], 3, ["scale": 0.9], 0,
            ]))
        #expect(store.node(2)?.hasButtonFeedback == true)
        #expect(store.node(2)?.tracksPresses == false)
        #expect(store.node(3)?.hasButtonFeedback == true)
        #expect(store.node(3)?.tracksPresses == false)
    }

    @Test func findsFeedbackOnAnyDescendantIncludingAttachments() {
        let store = NodeStore()
        store.apply(
            batch([
                0, 1, NodeStore.protocolVersion, 0, 7, "btn", 7, "hstack", 7, "txt", 7, "background", 7, "pressed",
                1, 1, 0, 2, 0, 0, 1, 3, 1, 0, 1, 4, 2, 0, 1, 5, 3, 1, 4, ["shadow": false], 0,
            ]))
        #expect(store.node(2)?.hasButtonFeedback == true)
        #expect(store.node(3)?.ownsButtonFeedback == false)
        #expect(!Node(id: 6, kind: .element, name: "txt", text: "").hasButtonFeedback)
    }
}
