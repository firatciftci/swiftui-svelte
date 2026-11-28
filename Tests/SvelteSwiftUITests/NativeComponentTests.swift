import SwiftUI
import Testing

@testable import SvelteSwiftUI

@MainActor
struct NativeComponentTests {
    @Test func hidesOwnedAttributesAndEventsFromTheModifierChain() {
        let node = Node(id: 1, kind: .element, name: "probe", text: "")
        node.owned = ["color", "hover"]
        node.setOwnAttributes([
            "color": .string("red"), "padding": .number(8), "listens": .array([.string("hover"), .string("tap")]),
        ])
        #expect(node.attributes["color"] == nil)
        #expect(node.attributes["padding"] == .number(8))
        #expect(node.attributes["listens"] == .array([.string("tap")]))
        #expect(!node.listens(to: "hover"))
        #expect(node.listens(to: "tap"))
    }

    @Test func keepsEveryAttributeAndEventForTheNativeComponent() {
        let node = Node(id: 1, kind: .element, name: "probe", text: "")
        node.owned = ["color", "hover"]
        node.setOwnAttributes(["color": .string("red"), "listens": .array([.string("hover")])])
        #expect(node.nativeAttributes["color"] == .string("red"))
        #expect(node.nativeAttributes["listens"] == .array([.string("hover")]))
    }

    @Test func tellsBuiltInElementNamesFromNativeComponentNames() {
        for name in ["toggle", "txt", "sheet", "overlay", "textfield", "vstack"] { #expect(NodeShape.isBuiltIn(name), "\(name)") }
        for name in ["mapview", "probe", "chart"] { #expect(!NodeShape.isBuiltIn(name), "\(name)") }
    }

    @Test func declaresOwnedNamesFromItsAttributesAndEvents() {
        let component = NativeComponent("probe", attributes: ["color"], events: ["hover"]) { _ in EmptyView() }
        #expect(component.owned == ["color", "hover"])
    }
}
