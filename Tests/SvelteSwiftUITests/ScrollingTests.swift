import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct ScrollingTests {
    @Test func readsWhichEventsAnElementListensFor() {
        let node = Node(id: 0, kind: .element, name: "scrollview", text: "")
        #expect(!node.listens(to: "scroll"))
        node.setOwnAttribute("listens", .array([.string("scroll")]))
        #expect(node.listens(to: "scroll"))
        #expect(!node.listens(to: "resize"))
        node.setOwnAttribute("listens", .string("scroll"))
        #expect(!node.listens(to: "scroll"))
    }

    @Test func readsScrollIndicatorsAndBounce() {
        #expect(ScrollOptions.indicators(.bool(false)) == .hidden)
        #expect(ScrollOptions.indicators(.string("hidden")) == .hidden)
        #expect(ScrollOptions.indicators(.string("never")) == .never)
        #expect(ScrollOptions.indicators(.string("visible")) == .visible)
        #expect(ScrollOptions.indicators(.bool(true)) == .automatic)
        #expect(ScrollOptions.indicators(nil) == .automatic)
        #expect(ScrollOptions.bounce("basedOnSize") != nil)
        #expect(ScrollOptions.bounce(nil) == nil)
        #expect(ScrollOptions.phase(.decelerating) == "decelerating")
        #expect(ScrollOptions.phase(.idle) == "idle")
    }
}
