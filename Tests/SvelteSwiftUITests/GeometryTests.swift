import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct GeometryTests {
    @Test func readsInsetsForEachEdge() {
        #expect(Geometry.insets(.number(8)) == EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        #expect(Geometry.insets(.bool(true)) == EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        #expect(Geometry.insets(.number(-4)) == EdgeInsets(top: -4, leading: -4, bottom: -4, trailing: -4))
        let edges = Geometry.insets(.object(["horizontal": .number(20), "top": .number(4), "vertical": .number(2)]))
        #expect(edges == EdgeInsets(top: 4, leading: 20, bottom: 2, trailing: 20))
        #expect(Geometry.insets(.object(["leading": .number(12), "horizontal": .number(20)]))?.leading == 12)
        #expect(Geometry.insets(.object(["vertical": .bool(true)])) == EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
        #expect(Geometry.insets(nil) == nil)
    }

    @Test func readsLengthsPointsAndScales() {
        #expect(Geometry.length(.number(40)) == 40)
        #expect(Geometry.length(.number(-1)) == 0)
        #expect(Geometry.length(.string("infinity")) == .infinity)
        #expect(Geometry.length(.string("wide")) == nil)
        #expect(Geometry.point(.object(["x": .number(4)])) == CGPoint(x: 4, y: 0))
        #expect(Geometry.point(.object([:])) == nil)
        #expect(Geometry.point(.number(3)) == nil)
        #expect(Geometry.scale(.number(2)) == CGSize(width: 2, height: 2))
        #expect(Geometry.scale(.object(["y": .number(0.5)])) == CGSize(width: 1, height: 0.5))
        #expect(Geometry.scale(nil) == nil)
    }

    @Test func sizesBorderBoxElementsAroundTheirBorderAndPadding() {
        func rendered(_ attributes: [String: JSONValue]) -> CGSize? {
            let node = Node(id: 1, kind: .element, name: "vstack", text: "")
            node.setOwnAttributes(attributes)
            let renderer = ImageRenderer(content: AnyView(NodeShape.view(of: node)))
            renderer.scale = 1
            return renderer.cgImage.map { CGSize(width: $0.width, height: $0.height) }
        }
        let border: JSONValue = .object(["width": .number(2)])
        let box: JSONValue = .string("border-box")
        #expect(
            rendered(["width": .number(160), "height": .number(40), "border": border, "boxsizing": box]) == CGSize(width: 160, height: 40))
        #expect(
            rendered(["width": .number(160), "height": .number(40), "padding": .number(4), "boxsizing": box])
                == CGSize(width: 160, height: 40))
        #expect(rendered(["width": .number(160), "height": .number(40), "border": border]) == CGSize(width: 164, height: 44))
    }

    @Test func readsMarginEdgesAndAutoAlignment() {
        let margin = Margin(.object(["top": .number(-4), "trailing": .string("auto")]))
        #expect(margin.insets == EdgeInsets(top: -4, leading: 0, bottom: 0, trailing: 0))
        #expect(margin.horizontal == .leading)
        #expect(margin.vertical == nil)
        #expect(Margin(.object(["leading": .string("auto"), "trailing": .string("auto")])).horizontal == .center)
        #expect(Margin(.object(["bottom": .string("auto")])).vertical == .top)
        #expect(Margin(nil).insets == EdgeInsets())
    }

    @Test func readsMarginShorthandsAsPaddingDoes() {
        #expect(Margin(.number(16)).insets == EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        let horizontal = Margin(.object(["horizontal": .number(16)]))
        #expect(horizontal.insets == EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        let vertical = Margin(.object(["vertical": .string("auto"), "top": .number(8)]))
        #expect(vertical.insets == EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
        #expect(vertical.vertical == .top)
        let centered = Margin(.string("auto"))
        #expect(centered.horizontal == .center)
        #expect(centered.vertical == .center)
        #expect(centered.insets == EdgeInsets())
    }
}
