import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct GestureTests {
    @Test func roundsGesturePointsAndVectors() {
        #expect(Gestures.point(CGPoint(x: 1.23456, y: -2.5)) == ["x": 1.23, "y": -2.5])
        #expect(Gestures.vector(CGSize(width: 10, height: 0.005)) == ["x": 10, "y": 0.01])
        #expect(Gestures.rounded(3.14159) == 3.14)
    }

    @Test func reportsHoverPhasesWithAndWithoutALocation() {
        let enter = Gestures.hover("enter", CGPoint(x: 4.5, y: 2))
        #expect(enter == ["phase": "enter", "location": ["x": 4.5, "y": 2]])
        #expect(Gestures.hover("exit", nil) == ["phase": "exit"])
    }
}
