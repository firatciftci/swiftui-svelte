import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct AccessibilityTests {
    @Test func readsTraitNames() {
        #expect(Accessibility.traits(.string("header")) == .isHeader)
        #expect(Accessibility.traits(.array([.string("button"), .string("selected")])) == [.isButton, .isSelected])
        #expect(Accessibility.traits(.array([.string("toggle"), .string("sparkly")])) == .isToggle)
        #expect(Accessibility.traits(.string("sparkly")) == nil)
        #expect(Accessibility.traits(nil) == nil)
    }

    @Test func readsChildBehaviorsHeadingsAndNames() {
        #expect(Accessibility.children("combine") == .combine)
        #expect(Accessibility.children("contain") == .contain)
        #expect(Accessibility.children("ignore") == .ignore)
        #expect(Accessibility.children("merge") == nil)
        #expect(Accessibility.heading(.number(1)) == .h1)
        #expect(Accessibility.heading(.number(6)) == .h6)
        #expect(Accessibility.heading(.bool(true)) == .unspecified)
        #expect(Accessibility.heading(.string("")) == .unspecified)
        #expect(Accessibility.heading(.string("false")) == nil)
        #expect(Accessibility.heading(.string("unspecified")) == nil)
        #expect(Accessibility.heading(.number(7)) == nil)
        #expect(Accessibility.names(.array([.string("Reset"), .string(""), .number(2)])) == ["Reset", "2"])
        #expect(Accessibility.names(.string("Reset")) == ["Reset"])
        #expect(Accessibility.names(.string("")).isEmpty)
    }

    @Test func reportsAccessibilitySettingsInTheEnvironment() {
        var snapshot = EnvironmentSnapshot()
        snapshot.accessibility = AccessibilitySettings(voiceOver: true, boldText: true)
        let dictionary = snapshot.dictionary
        #expect(dictionary["voiceOver"] == true)
        #expect(dictionary["boldText"] == true)
        #expect(dictionary["switchControl"] == false)
        #expect(dictionary["buttonShapes"] == false)
    }
}
