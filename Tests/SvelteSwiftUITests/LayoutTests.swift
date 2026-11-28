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

    @Test func readsPadding() {
        #expect(Styles.padding(.string("")) == 16)
        #expect(Styles.padding(.bool(true)) == 16)
        #expect(Styles.padding(.number(8)) == 8)
        #expect(Styles.padding(.string("12")) == 12)
        #expect(Styles.padding(.string("false")) == 0)
        #expect(Styles.padding(.bool(false)) == 0)
        #expect(Styles.padding(.number(-4)) == -4)
        #expect(Styles.padding(nil) == 0)
    }

    @Test func readsTheAxisOfACSSStack() {
        let row = Node(id: 1, kind: .element, name: "hstack", text: "")
        #expect(!CSSStack.isColumn(row))
        row.setOwnAttributes(["axis": .string("vertical")])
        #expect(CSSStack.isColumn(row))
        let column = Node(id: 2, kind: .element, name: "vstack", text: "")
        #expect(CSSStack.isColumn(column))
        column.setOwnAttributes(["axis": .string("horizontal")])
        #expect(!CSSStack.isColumn(column))
        let child = Node(id: 3, kind: .element, name: "txt", text: "")
        row.setOwnAttribute("css", .bool(true))
        #expect(CSSPlacement.of(child, in: row) == .stretch(.horizontal))
    }

    @Test func sharesLeftoverSpaceAmongGrowingTracks() {
        let spaced = CSSTrack.sizes(300, ideal: [50, 40, 30], minimum: [10, 10, 10], grows: [false, true, true], spacing: 10)
        #expect(spaced == [50, 115, 115])
        #expect(CSSTrack.sizes(nil, ideal: [50, 40], minimum: [10, 10], grows: [false, true], spacing: 0) == [50, 40])
        #expect(CSSTrack.sizes(60, ideal: [50, 40], minimum: [10, 10], grows: [false, true], spacing: 0) == [50, 10])
        #expect(CSSTrack.sizes(100, ideal: [20, 20], minimum: [20, 20], grows: [false, true], spacing: 0) == [20, 80])
        #expect(CSSTrack.sizes(50, ideal: [40, 40], minimum: [0, 0], grows: [false, false], spacing: 0) == [25, 25])
    }

    @Test func placesCSSChildrenByTheirFlowAlignment() {
        let parent = Node(id: 1, kind: .element, name: "vstack", text: "")
        parent.setOwnAttributes(["css": .bool(true)])
        let child = Node(id: 2, kind: .element, name: "txt", text: "")
        #expect(CSSPlacement.of(child, in: parent) == .stretch(.horizontal))
        child.setOwnAttributes(["selfalign": .string("end")])
        #expect(CSSPlacement.of(child, in: parent) == .align(UnitPoint(x: 1, y: 0)))
        child.setOwnAttributes(["selfalign": .string("stretch")])
        #expect(CSSPlacement.of(child, in: parent) == .stretch(.horizontal))
        parent.setOwnAttribute("alignment", .string("center"))
        #expect(CSSPlacement.of(child, in: parent) == .stretch(.horizontal))
        child.setOwnAttributes([:])
        #expect(CSSPlacement.of(child, in: parent) == .align(UnitPoint(x: 0.5, y: 0)))
        let row = Node(id: 3, kind: .element, name: "hstack", text: "")
        row.setOwnAttributes(["css": .bool(true)])
        #expect(CSSPlacement.of(child, in: row) == .stretch(.vertical))
        parent.setOwnAttribute("css", nil)
        #expect(CSSPlacement.of(child, in: parent) == nil)
    }
}
