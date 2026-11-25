import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct SlotTests {
    private func element(_ name: String, _ children: Array<Node> = [], id: Int = 0) -> Node {
        let node = Node(id: id, kind: .element, name: name, text: "")
        node.children = children
        return node
    }

    private func names(_ node: Node) -> Array<String> {
        node.renderedChildren.map(\.name)
    }

    @Test func keepsSlotsOutOfTheContentOfTheirParents() {
        let slots = ["header", "footer", "label", "background", "overlay", "txt"]
        #expect(names(element("sectionview", slots.map { element($0) })) == ["label", "txt"])
        #expect(names(element("picker", slots.map { element($0) })) == ["header", "footer", "txt"])
        #expect(names(element("vstack", slots.map { element($0) })) == ["header", "footer", "label", "txt"])
    }

    @Test func findsEachSlotByName() {
        let header = element("header", id: 1)
        let overlay = element("overlay", id: 2)
        let section = element("sectionview", [element("txt"), header, overlay])
        #expect(section.attachment("header") === header)
        #expect(section.attachment("overlay") === overlay)
        #expect(section.attachment("footer") == nil)
    }

    @Test func alignsLayersLikeSwiftUI() {
        let names = ["top", "bottom", "leading", "trailing", "topLeading", "topTrailing", "bottomLeading", "bottomTrailing"]
        let alignments: Array<Alignment> = [.top, .bottom, .leading, .trailing, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
        for (name, alignment) in zip(names, alignments) {
            let layer = element("overlay")
            layer.attributes["alignment"] = .string(name)
            #expect(Alignment(slot: layer) == alignment)
        }
        #expect(Alignment(slot: nil) == .center)
        #expect(Alignment(slot: element("background")) == .center)
    }
}
