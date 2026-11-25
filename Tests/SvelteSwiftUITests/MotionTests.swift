import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct MotionTests {
    @Test func readsTransitionNamesAndCombinations() {
        #expect(MotionTransition(.string("opacity"))?.parts == [.opacity])
        #expect(MotionTransition(.string("fade scale"))?.parts == [.opacity, .scale])
        #expect(MotionTransition(.string("move-top+push-leading"))?.parts == [.move(.top), .push(.leading)])
        #expect(MotionTransition(.string("move push"))?.parts == [.move(.bottom), .push(.trailing)])
        #expect(MotionTransition(.string("slide blur"))?.parts == [.slide, .blur])
        #expect(MotionTransition(.string("wobble opacity"))?.parts == [.opacity])
        #expect(MotionTransition(.string("wobble")) == nil)
        #expect(MotionTransition(nil) == nil)
    }

    @Test func buildsTransitionsOnlyWhenOneIsSet() {
        #expect(MotionTransition.transition(for: [:]) == nil)
        #expect(MotionTransition.transition(for: ["in": .string("scale")]) != nil)
        #expect(MotionTransition.transition(for: ["out": .string("opacity")]) != nil)
        #expect(MotionTransition.transition(for: ["transition": .string("nonsense")]) == nil)
    }

    @Test func readsAnimationNames() {
        #expect(MotionCurve(.string("bouncy"))?.kind == .bouncy)
        #expect(MotionCurve(.bool(true))?.kind == .default)
        #expect(MotionCurve(.string("wobbly")) == nil)
        #expect(MotionCurve(.bool(false)) == nil)
        #expect(MotionCurve(nil) == nil)
    }

    @Test func readsAnimationOptionsInMilliseconds() throws {
        let curve = try #require(
            MotionCurve(
                .object([
                    "type": .string("spring"), "duration": .number(600), "bounce": .number(0.4),
                    "delay": .number(100), "speed": .number(2), "repeat": .number(3), "autoreverses": .bool(false),
                ])))
        #expect(curve.kind == .spring)
        #expect(curve.duration == 0.6)
        #expect(curve.bounce == 0.4)
        #expect(curve.delay == 0.1)
        #expect(curve.speed == 2)
        #expect(curve.repeatCount == 3)
        #expect(curve.autoreverses == false)
        #expect(MotionCurve(.object(["repeat": .bool(true)]))?.repeatCount == -1)
        #expect(MotionCurve(.object(["type": .string("wobbly")])) == nil)
    }

    @Test func clampsOutOfRangeOptions() throws {
        let curve = try #require(
            MotionCurve(
                .object([
                    "duration": .number(-5), "bounce": .number(4), "delay": .number(-1), "speed": .number(0),
                    "repeat": .number(0),
                ])))
        #expect(curve.duration == 0)
        #expect(curve.bounce == 1)
        #expect(curve.delay == 0)
        #expect(curve.speed == 1)
        #expect(curve.repeatCount == nil)
    }
}
