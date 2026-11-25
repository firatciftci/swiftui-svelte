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
}
