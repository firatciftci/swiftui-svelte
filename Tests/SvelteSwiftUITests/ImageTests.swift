import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct ImageTests {
    @Test func combinesSymbolVariants() {
        #expect(Symbol.variants("fill") == .fill)
        #expect(Symbol.variants("circle fill") == SymbolVariants.circle.fill)
        #expect(Symbol.variants("slash bogus") == .slash)
        #expect(Symbol.variants(nil) == .none)
    }

    @Test func readsSymbolRenderingAndColors() {
        #expect(Symbol.rendering("hierarchical") != nil)
        #expect(Symbol.rendering("multicolor") != nil)
        #expect(Symbol.rendering("bogus") == nil)
        #expect(
            Symbol.colors(.array([.string("red"), .string("#00f"), .string("nope")])) == [.red, Color(.sRGB, red: 0, green: 0, blue: 1)])
        #expect(Symbol.colors(.string("red")).isEmpty)
    }

    @Test func readsImageRenderingModes() {
        #expect(ImageElement.renderingMode("template") == .template)
        #expect(ImageElement.renderingMode("original") == .original)
        #expect(ImageElement.renderingMode(nil) == nil)
    }

    @Test func returnsNothingForMissingBundleFiles() {
        #expect(BundleImages.image("missing.png") == nil)
    }

    @Test func keepsImageSlotsOutOfTheContent() {
        let placeholder = Node(id: 1, kind: .element, name: "placeholder", text: "")
        let failure = Node(id: 2, kind: .element, name: "failure", text: "")
        let image = Node(id: 0, kind: .element, name: "asyncimage", text: "")
        image.children = [placeholder, failure]
        #expect(image.renderedChildren.isEmpty)
        #expect(image.attachment("failure") === failure)
        let icon = Node(id: 3, kind: .element, name: "icon", text: "")
        let title = Node(id: 4, kind: .text, name: "", text: "Inbox")
        let label = Node(id: 5, kind: .element, name: "labelview", text: "")
        label.children = [icon, title]
        #expect(label.renderedChildren.map(\.id) == [4])
    }
}
