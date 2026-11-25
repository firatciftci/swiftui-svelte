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

    @Test func keepsMasksAndSafeAreaInsetsOutOfTheContent() {
        let mask = element("maskview", id: 1)
        let card = element("zstack", [element("txt"), mask, element("safeareainset"), element("safeareainset")])
        #expect(names(card) == ["txt"])
        #expect(card.attachment("maskview") === mask)
    }

    @Test func keepsAContextMenuAndItsPreviewOutOfTheContent() {
        let preview = element("preview", id: 3)
        let menu = element("contextmenu", [element("btn"), element("divider"), preview], id: 2)
        let row = element("hstack", [element("toggle"), menu])
        #expect(names(row) == ["toggle"])
        #expect(row.attachment("contextmenu") === menu)
        #expect(names(menu) == ["btn", "divider"])
        #expect(menu.attachment("preview") === preview)
    }

    @Test func alignsLayersLikeSwiftUI() {
        let names = ["top", "bottom", "leading", "trailing", "topLeading", "topTrailing", "bottomLeading", "bottomTrailing"]
        let alignments: Array<Alignment> = [.top, .bottom, .leading, .trailing, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing]
        for (name, alignment) in zip(names, alignments) {
            #expect(Styles.alignment(name) == alignment)
        }
        #expect(Styles.alignment(nil) == .center)
        #expect(Styles.alignment("leadingFirstTextBaseline") == .leadingFirstTextBaseline)
        #expect(Styles.alignment("trailingLastTextBaseline") == .trailingLastTextBaseline)
    }
}
