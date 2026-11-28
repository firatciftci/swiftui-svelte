import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct PresentationTests {
    @Test func readsDetents() {
        #expect(Presenting.detents([:]) == [.large])
        #expect(
            Presenting.detents([
                "detents": .array([.string("medium"), .object(["fraction": .number(0.25)]), .object(["points": .number(300)])])
            ])
                == [.medium, .fraction(0.25), .height(300)])
        #expect(Presenting.detents(["detents": .array([.string("tiny"), .number(0.5), .object(["points": .number(-1)])])]) == [.large])
        #expect(Presenting.detent(.object(["fraction": .number(1)])) == .fraction(1))
        #expect(Presenting.detent(.object(["points": .number(1)])) == .height(1))
        #expect(Presenting.detent(.object(["fraction": .number(1.5)])) == nil)
        #expect(Presenting.detent(.object(["fraction": .number(0)])) == nil)
    }

    @Test func readsVisibilityOptions() {
        #expect(Bars.visibility(.string("visible")) == .visible)
        #expect(Bars.visibility(.bool(false)) == .hidden)
        #expect(Bars.visibility(.string("automatic")) == .automatic)
        #expect(Bars.visibility(.string("bogus")) == nil)
        #expect(Bars.visibility(nil) == nil)
    }

    @Test func readsBackgroundInteraction() {
        let describe = { (value: JSONValue?) in String(describing: Presenting.backgroundInteraction(value)) }
        #expect(describe(.bool(true)) == String(describing: PresentationBackgroundInteraction.enabled))
        #expect(describe(.string("disabled")) == String(describing: PresentationBackgroundInteraction.disabled))
        #expect(describe(.string("")) == String(describing: PresentationBackgroundInteraction.enabled))
        #expect(describe(.string("false")) == String(describing: PresentationBackgroundInteraction.disabled))
        #expect(describe(.string("medium")) == String(describing: PresentationBackgroundInteraction.enabled(upThrough: .medium)))
        #expect(describe(nil) == String(describing: PresentationBackgroundInteraction.automatic))
        #expect(describe(.bool(true)) != describe(.bool(false)))
        #expect(describe(.string("medium")) != describe(.string("large")))
    }

    @Test func readsAdaptationsAndEdges() {
        for name in ["automatic", "none", "popover", "sheet", "fullScreenCover"] {
            #expect(Presenting.adaptation(name) != nil)
        }
        #expect(Presenting.adaptation("bogus") == nil)
        #expect(Presenting.edge("top") == .top)
        #expect(Presenting.edge("trailing") == .trailing)
        #expect(Presenting.edge(nil) == nil)
    }

    @Test func hostsPopoversOnceAChildNeedsOne() {
        let row = Node(id: 0, kind: .element, name: "btn", text: "")
        #expect(!row.hostsPresentations)
        let popover = Node(id: 1, kind: .element, name: "popover", text: "")
        row.children = [popover]
        #expect(row.hostsPresentations)
        #expect(row.renderedChildren.isEmpty)
        #expect(row.attachment("popover") === popover)
        row.children = []
        #expect(row.hostsPresentations)
        for name in ["screen", "tab", "sheet", "fullscreencover", "popover", "inspector"] {
            #expect(Node(id: 2, kind: .element, name: name, text: "").hostsPresentations)
        }
        #expect(Node(id: 3, kind: .fragment, name: "", text: "").hostsPresentations)
        let button = Node(id: 4, kind: .element, name: "btn", text: "")
        button.children = [Node(id: 5, kind: .element, name: "confirmationdialog", text: "")]
        #expect(button.hostsPresentations)
        let stack = Node(id: 6, kind: .element, name: "vstack", text: "")
        stack.children = [Node(id: 7, kind: .element, name: "sheet", text: "")]
        #expect(!stack.hostsPresentations)
    }

    @Test func hostsTheInspectorOnceOneIsPresented() {
        let host = Node(id: 0, kind: .element, name: "sheet", text: "")
        #expect(!host.hostsInspector)
        host.presented = [Node(id: 1, kind: .element, name: "alert", text: "")]
        #expect(!host.hostsInspector)
        host.presented = [Node(id: 2, kind: .element, name: "inspector", text: "")]
        host.presented = []
        #expect(host.hostsInspector)
        #expect(Node(id: 3, kind: .element, name: "screen", text: "").hostsInspector)
    }

    @Test func queuesSiblingPresentationsOfOneKindInOrder() {
        let element = { (id: Int, name: String) in Node(id: id, kind: .element, name: name, text: "") }
        let first = element(1, "sheet")
        let alert = element(2, "alert")
        let second = element(3, "sheet")
        let third = element(4, "sheet")
        let cover = element(5, "fullscreencover")
        #expect(Presenting.waiting([first, alert, second, third, cover]).map(\.id) == [3, 4])
        #expect(Presenting.waiting([alert, second, third]).map(\.id) == [4])
        #expect(Presenting.waiting([first, alert, cover]).isEmpty)
    }

    @Test func joinsMessageText() {
        let dialog = Node(id: 0, kind: .element, name: "confirmationdialog", text: "")
        let first = Node(id: 1, kind: .element, name: "txt", text: "")
        first.children = [Node(id: 2, kind: .text, name: "", text: "This can't\n   be undone.")]
        let second = Node(id: 3, kind: .element, name: "txt", text: "")
        second.children = [Node(id: 4, kind: .text, name: "", text: "Really?")]
        dialog.children = [first, Node(id: 5, kind: .element, name: "btn", text: ""), second]
        #expect(Presenting.message(dialog) == "This can't be undone.\nReally?")
    }
}
