import Foundation
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

    @Test func tellsBuiltInElementNamesFromNativeComponentNames() throws {
        for name in ["toggle", "txt", "sheet", "overlay", "textfield", "vstack", "label", "header"] {
            #expect(NodeShape.isBuiltIn(name), "\(name)")
        }
        for name in ["mapview", "probe", "chart"] { #expect(!NodeShape.isBuiltIn(name), "\(name)") }
        let known = try String(
            contentsOf: URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../src/known.ts"), encoding: .utf8)
        let start = try #require(known.range(of: "export const elements"))
        let end = try #require(known.range(of: "export const modifierValues"))
        let vocabulary = known[start.upperBound..<end.lowerBound].matches(of: /\n  "?([a-z0-9]+)"?: \[/).map { String($0.output.1) }
        #expect(vocabulary.count > 70)
        let missing = vocabulary.filter { !NodeShape.isBuiltIn($0) }
        #expect(missing.isEmpty, "\(missing)")
    }

    @Test func declaresOwnedNamesFromItsAttributesAndEvents() {
        let component = NativeComponent("probe", attributes: ["color"], events: ["hover"]) { _ in EmptyView() }
        #expect(component.owned == ["color", "hover"])
    }
}
