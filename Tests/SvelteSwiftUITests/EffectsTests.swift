import SwiftUI
import Testing

@testable import SvelteSwiftUI

@MainActor
struct EffectsTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

    private func bounds(_ value: JSONValue) -> CGRect? {
        Effects.shape(value)?.path(in: rect).boundingRect
    }

    @Test func readsClipShapes() {
        #expect(bounds(.string("rectangle")) == rect)
        #expect(bounds(.string("circle")) == CGRect(x: 25, y: 0, width: 50, height: 50))
        #expect(bounds(.string("capsule")) == rect)
        #expect(bounds(.string("ellipse")) == rect)
        #expect(bounds(.number(12)) == rect)
        #expect(bounds(.object(["cornerradius": .number(8)])) == rect)
        #expect(bounds(.object(["topleading": .number(10)])) == rect)
        #expect(
            bounds(.object(["d": .string("M0 0 L10 0 L10 10 Z"), "viewbox": .string("0 0 10 10")]))
                == CGRect(x: 25, y: 0, width: 50, height: 50))
        #expect(Effects.shape(.string("star")) == nil)
        #expect(Effects.shape(.object([:])) == nil)
        #expect(Effects.shape(nil) == nil)
    }

    @Test func readsBordersAndShadows() {
        #expect(Effects.border(.string("red"))?.widths == EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
        #expect(
            Effects.border(.object(["color": .string("blue"), "width": .number(3)]))?.widths
                == EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3))
        #expect(Effects.border(.object(["width": .number(-2)]))?.widths == EdgeInsets())
        #expect(Effects.border(.number(2)) == nil)
        let fallback = Color.black.opacity(0.33)
        #expect(Effects.shadow(.number(6)) == Effects.Shadow(color: fallback, radius: 6, x: 0, y: 0))
        #expect(Effects.shadow(.string("red")) == Effects.Shadow(color: .red, radius: 4, x: 0, y: 0))
        let offset = Effects.shadow(.object(["radius": .number(2), "y": .number(3)]))
        #expect(offset == Effects.Shadow(color: fallback, radius: 2, x: 0, y: 3))
        #expect(Effects.shadow(.bool(true)) == nil)
    }

    @Test func readsIgnoredSafeAreas() {
        #expect(Effects.ignoredSafeArea(.bool(true)) == Effects.SafeArea(regions: .all, edges: .all))
        #expect(Effects.ignoredSafeArea(.bool(false)) == nil)
        #expect(Effects.ignoredSafeArea(.string("keyboard")) == Effects.SafeArea(regions: .keyboard, edges: .all))
        #expect(Effects.ignoredSafeArea(.string("all")) == Effects.SafeArea(regions: .all, edges: .all))
        #expect(Effects.ignoredSafeArea(.string("top")) == Effects.SafeArea(regions: .all, edges: .top))
        let edges = Effects.ignoredSafeArea(.array([.string("top"), .string("horizontal")]))
        #expect(edges == Effects.SafeArea(regions: .all, edges: [.top, .horizontal]))
        let object = Effects.ignoredSafeArea(.object(["regions": .string("container"), "edges": .string("bottom")]))
        #expect(object == Effects.SafeArea(regions: .container, edges: .bottom))
        #expect(Effects.ignoredSafeArea(.array([.string("sideways")])) == nil)
        #expect(Effects.blendMode("multiply") == .multiply)
        #expect(Effects.blendMode("color-dodge") == .colorDodge)
        #expect(Effects.blendMode("plus-lighter") == .plusLighter)
        #expect(Effects.blendMode("sideways") == nil)
        #expect(Effects.blendMode(nil) == nil)
    }

    @Test func roundsTheInnerEdgeOfRoundedBorders() {
        let uniform = EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        let rounded = BorderRing(widths: uniform, radius: 10, style: .circular).path(in: rect)
        #expect(rounded.contains(CGPoint(x: 3.5, y: 3.5), eoFill: true))
        #expect(!rounded.contains(CGPoint(x: 0.5, y: 0.5), eoFill: true))
        let square = BorderRing(widths: uniform, radius: 0, style: .circular).path(in: rect)
        #expect(!square.contains(CGPoint(x: 3.5, y: 3.5), eoFill: true))
    }

    @Test func readsRingsAndDrawsThemOutsideTheirBounds() {
        #expect(Effects.ring(.object(["width": .number(2), "color": .string("red")]))?.width == 2)
        #expect(Effects.ring(.object(["width": .number(0)])) == nil)
        #expect(Effects.ring(.number(2)) == nil)
        let ring = RingStroke(width: 2, radius: 0, style: .continuous).path(in: rect).boundingRect
        #expect(ring == rect.insetBy(dx: -1, dy: -1))
    }

    @Test func readsBorderWidthsPerEdge() {
        let partial = Effects.border(.object(["width": .object(["top": .number(2), "leading": .number(-1)])]))
        #expect(partial?.widths == EdgeInsets(top: 2, leading: 0, bottom: 0, trailing: 0))
        #expect(Effects.border(.object(["color": .string("red")]))?.widths == EdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1))
    }
}
