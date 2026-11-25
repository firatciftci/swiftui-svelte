import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct InputTests {
    @Test func readsButtonRoles() {
        #expect(Inputs.role("destructive") == .destructive)
        #expect(Inputs.role("cancel") == .cancel)
        #expect(Inputs.role("bogus") == nil)
        #expect(Inputs.role(nil) == nil)
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            #expect(Inputs.role("confirm") == .confirm)
            #expect(Inputs.role("close") == .close)
        }
    }

    @Test func readsControlSizes() {
        #expect(Inputs.controlSize("mini") == .mini)
        #expect(Inputs.controlSize("small") == .small)
        #expect(Inputs.controlSize("regular") == .regular)
        #expect(Inputs.controlSize("large") == .large)
        #expect(Inputs.controlSize("extraLarge") == .extraLarge)
        #expect(Inputs.controlSize("huge") == nil)
    }

    @Test func readsBorderShapes() {
        #expect(Inputs.borderShape(.string("capsule")) != nil)
        #expect(Inputs.borderShape(.string("circle")) != nil)
        #expect(Inputs.borderShape(.string("roundedRectangle")) != nil)
        #expect(Inputs.borderShape(.string("automatic")) != nil)
        #expect(Inputs.borderShape(.number(12)) != nil)
        #expect(Inputs.borderShape(.string("hexagon")) == nil)
        #expect(Inputs.borderShape(nil) == nil)
    }

    @Test func readsSubmitLabels() {
        for name in ["done", "go", "send", "join", "route", "search", "return", "next", "continue"] {
            #expect(Inputs.submitLabel(name) != nil)
        }
        #expect(Inputs.submitLabel("bogus") == nil)
    }

    @Test func readsLineLimits() {
        #expect(Inputs.lineLimit(.number(4)) == 1...4)
        #expect(Inputs.lineLimit(.array([.number(2), .number(5)])) == 2...5)
        #expect(Inputs.lineLimit(.array([.number(5), .number(2)])) == 5...5)
        #expect(Inputs.lineLimit(.number(0)) == nil)
        #expect(Inputs.lineLimit(.array([.number(1)])) == nil)
        #expect(Inputs.lineLimit(.array([.number(0), .number(3)])) == nil)
        #expect(Inputs.lineLimit(.string("many")) == nil)
        #expect(Inputs.lineLimit(nil) == nil)
    }

    #if os(iOS) || os(visionOS)
        @Test func readsKeyboardTypes() {
            #expect(Inputs.keyboardType("email") == .emailAddress)
            #expect(Inputs.keyboardType("decimal") == .decimalPad)
            #expect(Inputs.keyboardType("number") == .numberPad)
            #expect(Inputs.keyboardType("url") == .URL)
            #expect(Inputs.keyboardType("phone") == .phonePad)
            #expect(Inputs.keyboardType("numbersAndPunctuation") == .numbersAndPunctuation)
            #expect(Inputs.keyboardType("bogus") == nil)
        }

        @Test func readsContentTypes() {
            #expect(Inputs.contentType("email") == .emailAddress)
            #expect(Inputs.contentType("password") == .password)
            #expect(Inputs.contentType("newPassword") == .newPassword)
            #expect(Inputs.contentType("oneTimeCode") == .oneTimeCode)
            #expect(Inputs.contentType("postalCode") == .postalCode)
            #expect(Inputs.contentType("bogus") == nil)
        }

        @Test func readsAutocapitalization() {
            for name in ["never", "words", "sentences", "characters"] {
                #expect(Inputs.autocapitalization(name) != nil)
            }
            #expect(Inputs.autocapitalization("shout") == nil)
        }
    #endif
}
