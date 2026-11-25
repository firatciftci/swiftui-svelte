import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct PaletteTests {
    private func srgb(_ red: Double, _ green: Double, _ blue: Double, _ opacity: Double = 1) -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    @Test func readsNamedAndHexColors() {
        #expect(Palette.color("blue") == .blue)
        #expect(Palette.color(" clear ") == .clear)
        #expect(Palette.color("#ff0000") == srgb(1, 0, 0))
        #expect(Palette.color("#F00") == srgb(1, 0, 0))
        #expect(Palette.color("#0000ff80") == srgb(0, 0, 1, 128 / 255))
        #expect(Palette.color("#f008") == srgb(1, 0, 0, 8 / 15))
        #expect(Palette.color("#12345") == nil)
        #expect(Palette.color("#zzzzzz") == nil)
        #expect(Palette.color(nil) == nil)
        #expect(Palette.color("") == nil)
        #expect(Palette.color("chartreuse") == nil)
    }

    @Test func readsCSSColorFunctions() {
        #expect(Palette.color("rgb(255 0 0)") == srgb(1, 0, 0))
        #expect(Palette.color("rgba(0, 255, 0, 0.5)") == srgb(0, 1, 0, 0.5))
        #expect(Palette.color("rgb(0 0 255 / 25%)") == srgb(0, 0, 1, 0.25))
        #expect(Palette.color("RGB(100%, 0%, 0%)") == srgb(1, 0, 0))
        #expect(Palette.color("hsl(120 100% 50%)") == srgb(0, 1, 0))
        #expect(Palette.color("hsl(240deg, 100%, 50%, 0.5)") == srgb(0, 0, 1, 0.5))
        #expect(Palette.color("rgb(1 2)") == nil)
        #expect(Palette.color("lab(50 0 0)") == nil)
    }

    @Test func convertsHSLLikeCSS() {
        let channels = Palette.rgb(hue: 210, saturation: 1, lightness: 0.5)
        for (channel, expected) in zip(channels, [0, 0.5, 1]) { #expect(abs(channel - expected) < 0.0001) }
        #expect(Palette.rgb(hue: -30, saturation: 0, lightness: 0.25) == [0.25, 0.25, 0.25])
    }

    @Test func readsShapeStyles() {
        #expect(Palette.style(.string("regularMaterial")) != nil)
        #expect(Palette.style(.string("tertiary")) != nil)
        #expect(Palette.style(.string("blue.gradient")) != nil)
        #expect(Palette.style(.string("#00ff00")) != nil)
        #expect(Palette.style(.object(["linear": .array([.string("red"), .string("blue")])])) != nil)
        #expect(
            Palette.style(
                .object([
                    "radial": .array([.object(["color": .string("red"), "location": .number(0.2)]), .string("blue")]),
                    "endRadius": .number(40),
                ])) != nil)
        #expect(Palette.style(.object(["angular": .array([.string("red"), .string("nope")])])) == nil)
        #expect(Palette.style(.object(["linear": .array([])])) == nil)
        #expect(Palette.style(.string("nope")) == nil)
        #expect(Palette.style(.number(1)) == nil)
    }

    #if canImport(UIKit)
        @Test func readsSystemColors() {
            #expect(Palette.color("systemBackground") == Color(UIColor.systemBackground))
            #expect(Palette.color("secondaryLabel") == Color(UIColor.secondaryLabel))
        }
    #endif
}
