import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct OverridesTests {
    @Test func readsSensoryFeedback() {
        #expect(Overrides.feedback(.string("success")) == .success)
        #expect(Overrides.feedback(.string("levelChange")) == .levelChange)
        #expect(Overrides.feedback(.string("buzz")) == nil)
        #expect(Overrides.feedback(.object(["weight": .string("heavy")])) == .impact(weight: .heavy, intensity: 1))
        let soft = Overrides.feedback(.object(["flexibility": .string("soft"), "intensity": .number(2)]))
        #expect(soft == .impact(flexibility: .soft, intensity: 1))
        #expect(Overrides.feedback(.object(["type": .string("warning")])) == .warning)
        #expect(Overrides.feedback(nil) == nil)
    }

    @Test func readsColorSchemesAndTypeSizes() {
        #expect(Overrides.colorScheme("dark") == .dark)
        #expect(Overrides.colorScheme("dim") == nil)
        #expect(Overrides.dynamicTypeSize("xLarge") == .xLarge)
        #expect(Overrides.dynamicTypeSizes(.string("xLarge")) == nil)
        let range = Overrides.dynamicTypeSizes(.object(["max": .string("accessibility2")]))
        #expect(range == .xSmall ... .accessibility2)
        #expect(Overrides.dynamicTypeSizes(.object(["min": .string("xxLarge"), "max": .string("small")])) == nil)
        #expect(Overrides.dynamicTypeSize("huge") == nil)
    }
}
