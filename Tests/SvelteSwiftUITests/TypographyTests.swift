import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct TypographyTests {
    private func text(_ value: String) -> Node {
        Node(id: 0, kind: .text, name: "", text: value)
    }

    private func txt(_ attributes: [String: JSONValue] = [:], _ children: Array<Node>) -> Node {
        let node = Node(id: 0, kind: .element, name: "txt", text: "")
        node.attributes = attributes
        node.children = children
        return node
    }

    private func run(_ string: AttributedString, _ substring: String) -> AttributedString.Runs.Run? {
        string.runs.first { String(string[$0.range].characters) == substring }
    }

    @Test func fixesTheSizeOfAFontNameWithSize() {
        #expect(Styles.font(["fontname": .string("Georgia-Bold"), "size": .number(24)]) == .custom("Georgia-Bold", fixedSize: 24))
    }

    @Test func scalesAFontNameWithATextStyle() {
        #expect(Styles.font(["fontname": .string("Georgia"), "font": .string("body")]) == .custom("Georgia", size: 17, relativeTo: .body))
        #expect(
            Styles.font(["fontname": .string("Georgia"), "font": .string("title")]) == .custom("Georgia", size: 28, relativeTo: .title))
        #expect(
            Styles.font(["fontname": .string("Georgia"), "font": .string("title"), "size": .number(30)])
                == .custom("Georgia", size: 30, relativeTo: .title))
    }

    @Test func fallsBackToBodyForAFontNameAlone() {
        #expect(Styles.font(["fontname": .string("Georgia")]) == .custom("Georgia", size: 17, relativeTo: .body))
    }

    @Test func keepsSystemFontsWhenThereIsNoFontName() {
        #expect(Styles.font(["font": .string("headline")]) == .headline)
        #expect(Styles.font(["size": .number(20)]) == .system(size: 20))
    }

    @Test func passesTheFontNameDownToSpans() throws {
        let string = Styles.attributedString(
            txt(
                ["fontname": .string("Georgia"), "size": .number(20)],
                [text("A"), txt(["fontname": .string("Georgia-Italic")], [text("B")]), txt(["weight": .string("semibold")], [text("C")])]))
        #expect(String(string.characters) == "ABC")
        #expect(try #require(run(string, "B")).swiftUI.font == .custom("Georgia-Italic", fixedSize: 20))
        #expect(try #require(run(string, "C")).swiftUI.font == .custom("Georgia", fixedSize: 20).weight(.semibold))
        #expect(run(string, "A")?.swiftUI.font == nil)
    }

    @Test func keepsTheSpanSizeWhenOnlyTheFontNameChanges() throws {
        let string = Styles.attributedString(
            txt(
                ["size": .number(20)],
                [txt(["fontname": .string("Georgia")], [text("Named")]), txt(["font": .string("title")], [text("Title")])]))
        #expect(try #require(run(string, "Named")).swiftUI.font == .custom("Georgia", fixedSize: 20))
        #expect(try #require(run(string, "Title")).swiftUI.font == .title)
    }

    @Test func keepsTheInheritedFontNameWhenAContainerSetsOnlyASize() {
        var base = TextBase()
        base.fontName = "Georgia"
        base.size = 16
        #expect(Styles.font(["size": .number(24)], inheriting: base) == .custom("Georgia", fixedSize: 24))
        #expect(
            Styles.font(["size": .number(24), "fontname": .string("Georgia-Bold")], inheriting: base)
                == .custom("Georgia-Bold", fixedSize: 24))
        #expect(Styles.font(["weight": .string("bold")], inheriting: base) == nil)
        #expect(Styles.font(["size": .number(24)], inheriting: TextBase()) == .system(size: 24))
    }

    @Test func cascadesFallbackFontsInOrder() {
        let descriptor = Fonts.descriptor("Georgia", size: 20, fallbacks: ["GeezaPro", "Papyrus"])
        let cascade = descriptor.fontAttributes[.cascadeList] as? Array<PlatformFontDescriptor>
        #expect(cascade?.compactMap(\.postscriptName) == ["GeezaPro", "Papyrus"])
    }
}
