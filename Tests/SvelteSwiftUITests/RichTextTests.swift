import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct RichTextTests {
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

    @Test func joinsNestedSpansIntoOneString() throws {
        let string = Styles.attributedString(
            txt(
                [:],
                [
                    text("Hello "),
                    txt(
                        ["weight": .string("bold"), "color": .string("red")],
                        [text("bold "), txt(["color": .string("blue")], [text("blue")])]),
                    text("!"),
                ]))
        #expect(String(string.characters) == "Hello bold blue!")
        let bold = try #require(run(string, "bold "))
        #expect(bold.inlinePresentationIntent == .stronglyEmphasized)
        #expect(bold.swiftUI.foregroundColor == .red)
        let blue = try #require(run(string, "blue"))
        #expect(blue.inlinePresentationIntent == .stronglyEmphasized)
        #expect(blue.swiftUI.foregroundColor == .blue)
        #expect(run(string, "Hello ")?.inlinePresentationIntent == nil)
    }

    @Test func resolvesWeightsAgainstTheNearestFont() throws {
        let string = Styles.attributedString(
            txt(["font": .string("title")], [text("A"), txt(["weight": .string("semibold"), "italic": .bool(true)], [text("B")])]))
        let span = try #require(run(string, "B"))
        #expect(span.swiftUI.font == Font.title.weight(.semibold).italic())
        #expect(run(string, "A")?.swiftUI.font == nil)
    }

    @Test func decoratesWholeTextFromTheOuterElement() throws {
        let string = Styles.attributedString(
            txt(
                ["underline": .bool(true)],
                [text("Terms "), txt(["href": .string("https://svelte.dev"), "underline": .bool(false)], [text("link")])]))
        #expect(run(string, "Terms ")?.swiftUI.underlineStyle == .single)
        let link = try #require(run(string, "link"))
        #expect(link.link == URL(string: "https://svelte.dev"))
        #expect(link.swiftUI.underlineStyle == nil)
    }

    @Test func parsesInlineMarkdown() {
        let string = Styles.attributedString(
            txt(["markdown": .string("**Bold**, _soft_, and [docs](https://svelte.dev)"), "strikethrough": .bool(true)], []))
        #expect(String(string.characters) == "Bold, soft, and docs")
        #expect(run(string, "Bold")?.inlinePresentationIntent == .stronglyEmphasized)
        #expect(run(string, "soft")?.inlinePresentationIntent == .emphasized)
        #expect(run(string, "docs")?.link == URL(string: "https://svelte.dev"))
        #expect(string.runs.allSatisfy { $0.swiftUI.strikethroughStyle == .single })
    }

    @Test func readsMarkdownFromTheTextInside() {
        let string = Styles.attributedString(txt(["markdown": .bool(true)], [text("Use `ref()` **now**")]))
        #expect(String(string.characters) == "Use ref() now")
        #expect(string.runs.contains { $0.inlinePresentationIntent == .code })
    }

    @Test func treatsABareMarkdownAttributeAsTrue() {
        let bare = Styles.attributedString(txt(["markdown": .string("")], [text("**Hi**")]))
        #expect(String(bare.characters) == "Hi")
        let off = Styles.attributedString(txt(["markdown": .string("false")], [text("**Hi**")]))
        #expect(String(off.characters) == "**Hi**")
    }

    @Test func sizesAndDesignsSpans() throws {
        let string = Styles.attributedString(
            txt(
                ["font": .string("title"), "kerning": .number(2)],
                [
                    text("A"),
                    txt(["design": .string("rounded")], [text("B")]),
                    txt(["size": .number(12), "design": .string("monospaced"), "tracking": .number(1)], [text("C")]),
                ]))
        #expect(run(string, "A")?.swiftUI.font == nil)
        #expect(run(string, "A")?.swiftUI.kern == 2)
        #expect(run(string, "B")?.swiftUI.font == Font.system(.title, design: .rounded))
        let small = try #require(run(string, "C"))
        #expect(small.swiftUI.font == Font.system(size: 12, design: .monospaced))
        #expect(small.swiftUI.tracking == 1)
        #expect(small.swiftUI.kern == 2)
    }

    @Test func readsFontsLikeSwiftUI() {
        #expect(Styles.font(["size": .number(20), "font": .string("title")]) == Font.system(size: 20))
        #expect(Styles.font(["font": .string("title")]) == .title)
        #expect(Styles.font([:]) == nil)
        #expect(Styles.weight("black") == .black)
        #expect(Styles.weight("ultraLight") == .ultraLight)
        #expect(Styles.design("serif") == .serif)
        #expect(Styles.verticalAlignment("firstTextBaseline") == .firstTextBaseline)
        #expect(Styles.horizontalAlignment("listRowSeparatorLeading") == .listRowSeparatorLeading)
        #expect(Styles.truncationMode("middle") == .middle)
        #expect(Styles.truncationMode("none") == nil)
    }

    @Test func collapsesWhitespaceLikeTheWeb() {
        let wrapped = txt([:], [text("1"), text("\n    "), text("day picked\n  ")])
        #expect(String(Styles.attributedString(wrapped).characters) == "1 day picked")
        let nested = txt([:], [text("  Hello  "), txt(["weight": .string("bold")], [text("  big \t world ")]), text(" !")])
        #expect(String(Styles.attributedString(nested).characters) == "Hello big world !")
    }

    @Test func keepsLineBreaksWithPreLine() {
        let node = txt(["whitespace": .string("pre-line")], [text("First   line  \n   second\tline")])
        #expect(String(Styles.attributedString(node).characters) == "First line\nsecond line")
    }

    @Test func keepsEverythingWithPre() {
        let node = txt(["whitespace": .string("pre")], [text("  a\n   b  ")])
        #expect(String(Styles.attributedString(node).characters) == "  a\n   b  ")
        let mixed = txt([:], [text("a\n  "), txt(["whitespace": .string("pre")], [text("  b")])])
        #expect(String(Styles.attributedString(mixed).characters) == "a   b")
    }

    @Test func collapsesMarkdownSource() {
        let node = txt(["markdown": .string("**Bold**\n    and *more*")], [])
        #expect(String(Styles.attributedString(node).characters) == "Bold and more")
    }

    @Test func collapsesBareText() {
        #expect(Whitespace.normal.collapsed("\n  Save\n  changes ") == "Save changes")
        #expect(Whitespace.pre.collapsed(" a ") == " a ")
    }
}
