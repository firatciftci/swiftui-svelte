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
        #expect(MotionCurve.from(.bool(false)) == nil)
        #expect(MotionCurve.from(.bool(true)) == MotionCurve())
        #expect(MotionCurve.from(nil) == MotionCurve())
        #expect(MotionCurve.from(.string("")) == MotionCurve())
        #expect(MotionCurve.from(.string("false")) == nil)
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

    @Test func readsTimingCurvesFromControlPoints() throws {
        let curve = try #require(
            MotionCurve(
                .object([
                    "type": .string("timingCurve"),
                    "curve": .array([.number(0.4), .number(0), .number(0.2), .number(1)]), "duration": .number(300),
                ])))
        #expect(curve.kind == .timingCurve)
        #expect(curve.bezier == CubicBezier(x1: 0.4, y1: 0, x2: 0.2, y2: 1))
        #expect(curve.animation == Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.3))
        #expect(MotionCurve(.object(["type": .string("timingCurve")])) == nil)
        #expect(MotionCurve(.object(["type": .string("timingCurve"), "curve": .array([.number(0.4)])])) == nil)
        #expect(MotionCurve(.string("timingCurve")) == nil)
    }

    @Test func disablingAnimationsUsesTheAnimatedGroup() {
        #expect(ModifierSet(attribute: "disablesanimations", value: .bool(true)) == .animated)
    }
}
