import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct ShapeTests {
    private func bounds(_ data: String) -> CGRect {
        SVGPath.parse(data).boundingRect
    }

    private func expectClose(_ rect: CGRect, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
        let values = [rect.minX, rect.minY, rect.width, rect.height]
        let wanted = [expected.minX, expected.minY, expected.width, expected.height]
        for (value, target) in zip(values, wanted) {
            #expect(abs(value - target) < 0.5, "\(rect) is not \(expected)", sourceLocation: sourceLocation)
        }
    }

    @Test func parsesLinesAndClosesPaths() {
        expectClose(bounds("M0 0 L10 0 L10 10 Z"), CGRect(x: 0, y: 0, width: 10, height: 10))
        expectClose(bounds("m5 5 h10 v10 h-10 z"), CGRect(x: 5, y: 5, width: 10, height: 10))
        expectClose(bounds("M0,0L10-5l5,5"), CGRect(x: 0, y: -5, width: 15, height: 5))
        expectClose(bounds("M0 0 10 0 10 10"), CGRect(x: 0, y: 0, width: 10, height: 10))
        expectClose(bounds("M.5.5L1e1 1E1"), CGRect(x: 0.5, y: 0.5, width: 9.5, height: 9.5))
    }

    @Test func parsesCurves() {
        expectClose(bounds("M0 0 C0 10 10 10 10 0"), CGRect(x: 0, y: 0, width: 10, height: 7.5))
        expectClose(bounds("M0 0 C0 10 10 10 10 0 S20 -10 20 0"), CGRect(x: 0, y: -7.5, width: 20, height: 15))
        expectClose(bounds("M0 0 Q5 10 10 0 T20 0"), CGRect(x: 0, y: -5, width: 20, height: 10))
    }

    @Test func parsesArcs() {
        expectClose(bounds("M0 50 A50 50 0 0 1 100 50"), CGRect(x: 0, y: 0, width: 100, height: 50))
        expectClose(bounds("M0 50a50 50 0 01100 0"), CGRect(x: 0, y: 0, width: 100, height: 50))
        expectClose(bounds("M0 50 A50 50 0 0 0 100 50"), CGRect(x: 0, y: 50, width: 100, height: 50))
        expectClose(bounds("M0 0 A1 1 0 0 1 100 0"), CGRect(x: 0, y: -50, width: 100, height: 50))
        expectClose(bounds("M0 0 A0 5 0 0 1 10 0"), CGRect(x: 0, y: 0, width: 10, height: 0))
    }

    @Test func stopsAtInvalidData() {
        expectClose(bounds("M0 0 L10 10 X 50 50"), CGRect(x: 0, y: 0, width: 10, height: 10))
        expectClose(bounds("M0 0 L10"), .zero)
        #expect(SVGPath.parse("").isEmpty)
        #expect(SVGPath.parse("12 34").isEmpty)
    }

    @Test func fitsTheViewBoxIntoTheFrame() {
        let shape = SVGShape(path: SVGPath.parse("M0 0 H24 V24 H0 Z"), viewBox: SVGShape.viewBox("0 0 24 24"))
        expectClose(shape.path(in: CGRect(x: 0, y: 0, width: 48, height: 96)).boundingRect, CGRect(x: 0, y: 24, width: 48, height: 48))
        #expect(SVGShape.viewBox("0,0,24") == nil)
        #expect(SVGShape.viewBox(nil) == nil)
        let raw = SVGShape(path: SVGPath.parse("M2 2 H4"), viewBox: nil)
        expectClose(raw.path(in: CGRect(x: 0, y: 0, width: 100, height: 100)).boundingRect, CGRect(x: 2, y: 2, width: 2, height: 0))
    }

    @Test func readsStrokeStyles() {
        let style = ShapeElement.strokeStyle([
            "linewidth": .number(3), "linecap": .string("round"), "linejoin": .string("bevel"),
            "dash": .array([.number(4), .number(2)]), "dashphase": .number(1),
        ])
        #expect(style == StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .bevel, dash: [4, 2], dashPhase: 1))
        #expect(ShapeElement.strokeStyle([:]) == StrokeStyle(lineWidth: 1))
    }
}
