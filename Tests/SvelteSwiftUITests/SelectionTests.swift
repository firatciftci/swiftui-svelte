import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct SelectionTests {
    private func choices(_ values: Array<JSONValue>) -> Array<Node> {
        values.enumerated().map { index, value in
            let choice = Node(id: index, kind: .element, name: "choice", text: "")
            choice.attributes["value"] = value
            return choice
        }
    }

    @Test func togglesChoicesInTheirOrder() {
        let options = choices([.string("a"), .string("b"), .number(3)])
        #expect(Choices.toggled(.string("b"), in: [], order: options) == [.string("b")])
        #expect(Choices.toggled(.string("a"), in: [.number(3)], order: options) == [.string("a"), .number(3)])
        #expect(Choices.toggled(.number(3), in: [.string("a"), .number(3)], order: options) == [.string("a")])
        #expect(
            Choices.toggled(.string("a"), in: [.string("zz"), .string("b")], order: options) == [.string("a"), .string("b"), .string("zz")])
    }

    @Test func readsChoiceTitles() {
        let choice = Node(id: 0, kind: .element, name: "choice", text: "")
        choice.children = [Node(id: 1, kind: .text, name: "", text: "Ol"), Node(id: 2, kind: .text, name: "", text: "ives")]
        #expect(Choices.title(choice) == "Olives")
    }

    @Test func roundTripsDaysInAnyCalendar() throws {
        for identifier in [Calendar.Identifier.gregorian, .islamicUmmAlQura, .hebrew, .japanese] {
            let calendar = Calendar(identifier: identifier)
            let components = try #require(Days.components("2026-11-25", in: calendar))
            #expect(components.calendar?.identifier == identifier)
            #expect(Days.day(components, in: calendar) == "2026-11-25")
        }
    }

    @Test func rejectsMalformedDays() {
        #expect(Days.date("2026-02-30") == nil)
        #expect(Days.date("2026-1-5") == nil)
        #expect(Days.date("tomorrow") == nil)
        #expect(Days.date("2026-02-28") != nil)
    }

    @Test func readsDayAndTimestampBounds() {
        #expect(Days.bound(.string("2026-11-25")) == Days.date("2026-11-25"))
        #expect(Days.bound(.string("2026-11-25T10:00:00Z")) != nil)
        #expect(Days.bound(nil) == nil)
    }

    @Test func writesHexColors() {
        let environment = EnvironmentValues()
        #expect(Palette.hex(Color(.sRGB, red: 1, green: 0, blue: 0).resolve(in: environment)) == "#FF0000")
        #expect(Palette.hex(Color(.sRGB, red: 0, green: 0.5, blue: 1, opacity: 0.5).resolve(in: environment)) == "#0080FF80")
        let color = Palette.color("#12AB34")
        #expect(color.map { Palette.hex($0.resolve(in: environment)) } == "#12AB34")
    }

    @Test func readsMenuOrders() {
        #expect(MenuElement.order("fixed") == .fixed)
        #expect(MenuElement.order("automatic") == .automatic)
        #expect(MenuElement.order("bogus") == nil)
    }

    @Test func keepsLabelSlotsOutOfTheContent() {
        for name in ["labeledcontent", "menuview", "contentunavailableview"] {
            let label = Node(id: 1, kind: .element, name: "label", text: "")
            let content = Node(id: 2, kind: .element, name: "txt", text: "")
            let parent = Node(id: 0, kind: .element, name: name, text: "")
            parent.children = [label, content]
            #expect(parent.renderedChildren.map(\.id) == [2])
            #expect(parent.attachment("label") === label)
        }
    }
}
