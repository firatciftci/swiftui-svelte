import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct ListTests {
    private func element(_ name: String, _ attributes: [String: JSONValue] = [:], _ children: Array<Node> = []) -> Node {
        let node = Node(id: 0, kind: .element, name: name, text: "")
        node.attributes = attributes
        node.children = children
        return node
    }

    @Test func collectsTagsInRowOrder() {
        let list = element(
            "list", [:],
            [
                element("sectionview", [:], [element("txt", ["tag": .string("b")]), element("txt", ["tag": .number(3)])]),
                element("hstack", ["tag": .string("a")], [element("txt", ["tag": .string("nested")])]),
                element("txt"),
            ])
        #expect(Lists.tags(in: list) == [.string("b"), .number(3), .string("a"), .string("nested")])
    }
}
