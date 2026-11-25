import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct GeometryTests {
    @Test func readsInsetsForEachEdge() {
        #expect(Geometry.insets(.number(8)) == EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        #expect(Geometry.insets(.bool(true)) == EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
        #expect(Geometry.insets(.number(-4)) == EdgeInsets())
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
}
