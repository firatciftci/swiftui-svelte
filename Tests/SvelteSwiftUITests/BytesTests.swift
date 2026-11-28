import JavaScriptCore
import Testing

@testable import SvelteSwiftUI

struct BytesTests {
    @Test(arguments: ["", "Row 1", "Satır İğdır", "家 🌍👩‍👩‍👧", "a\u{0}b", String(repeating: "ğ", count: 100_000)])
    func readsAJavaScriptStringAsNativeUTF8(text: String) throws {
        let context = try #require(JSContext())
        let value = try #require(JSValue(object: text, in: context))
        var string = try #require(value.utf8String)
        #expect(string == text)
        #expect(string.utf8.withContiguousStorageIfAvailable { _ in true } == true)
        string.withUTF8 { #expect($0.count == text.utf8.count) }
    }

    @Test func readsAValueThatIsNotAStringAsItsText() throws {
        let context = try #require(JSContext())
        #expect(context.evaluateScript("[1, 2]")?.utf8String == "1,2")
        #expect(context.evaluateScript("({ toString() { throw new Error('no') } })")?.utf8String == nil)
    }
}
