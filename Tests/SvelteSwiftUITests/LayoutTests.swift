import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct LayoutTests {
    private func describe(_ item: GridItem) -> String {
        switch item.size {
        case let .fixed(length): "fixed \(length)"
        case let .flexible(minimum, maximum): "flexible \(minimum) \(maximum)"
        case let .adaptive(minimum, maximum): "adaptive \(minimum) \(maximum)"
        @unknown default: "unknown"
        }
    }

    @Test func readsAColumnCountAsFlexibleColumns() {
        let items = Layout.gridItems(.number(3))
        #expect(items.map(describe) == Array(repeating: "flexible 10.0 inf", count: 3))
        #expect(Layout.gridItems(nil).map(describe) == ["flexible 10.0 inf"])
        #expect(Layout.gridItems(.number(0)).count == 1)
        #expect(Layout.gridItems(.array([])).count == 1)
    }

    @Test func readsFixedFlexibleAndAdaptiveItems() {
        let items = Layout.gridItems(
            .array([
                .number(44),
                .object(["fixed": .number(60), "spacing": .number(4), "alignment": .string("leading")]),
                .object(["adaptive": .number(80), "max": .number(120)]),
                .object(["min": .number(50)]),
                .number(-5),
            ]))
        #expect(items.map(describe) == ["fixed 44.0", "fixed 60.0", "adaptive 80.0 120.0", "flexible 50.0 inf", "fixed 0.0"])
        #expect(items[1].spacing == 4)
        #expect(items[1].alignment == .leading)
        #expect(items[0].spacing == nil)
        #expect(items[0].alignment == nil)
    }

    @Test func readsPinnedViewsAndAxes() {
        #expect(Layout.pinnedViews(.string("headers")) == .sectionHeaders)
        #expect(Layout.pinnedViews(.string("both")) == [.sectionHeaders, .sectionFooters])
        #expect(Layout.pinnedViews(nil).isEmpty)
        #expect(Layout.axes(.string("vertical")) == .vertical)
        #expect(Layout.axes(nil) == [.horizontal, .vertical])
    }

    @Test func keepsLabelsOutOfGroupContent() {
        let label = Node(id: 1, kind: .element, name: "label", text: "")
        let row = Node(id: 2, kind: .element, name: "txt", text: "")
        for name in ["groupbox", "controlgroup", "disclosuregroup"] {
            let group = Node(id: 0, kind: .element, name: name, text: "")
            group.children = [label, row]
            #expect(group.renderedChildren.map(\.id) == [2])
            #expect(group.attachment("label") === label)
        }
    }
}
