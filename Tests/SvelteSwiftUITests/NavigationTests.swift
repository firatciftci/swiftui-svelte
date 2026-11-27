import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct NavigationTests {
    @Test func readsBarVisibility() {
        #expect(Bars.visibility(.bool(false)) == .hidden)
        #expect(Bars.visibility(.string("hidden")) == .hidden)
        #expect(Bars.visibility(.string("")) == .visible)
        #expect(Bars.visibility(.bool(true)) == .visible)
        #expect(Bars.visibility(.string("automatic")) == .automatic)
        #expect(Bars.visibility(.string("bogus")) == nil)
        #expect(Bars.visibility(nil) == nil)
    }

    @Test func readsToolbarPlacements() {
        let describe = { (name: String?) in String(describing: Bars.placement(name)) }
        #expect(describe("principal") == String(describing: ToolbarItemPlacement.principal))
        #expect(describe("secondaryAction") == String(describing: ToolbarItemPlacement.secondaryAction))
        #expect(describe("cancellationAction") == String(describing: ToolbarItemPlacement.cancellationAction))
        #expect(describe("status") == String(describing: ToolbarItemPlacement.status))
        #expect(describe("principal") != describe("status"))
        #if os(macOS)
            #expect(describe(nil) == String(describing: ToolbarItemPlacement.primaryAction))
            #expect(describe("leading") == String(describing: ToolbarItemPlacement.navigation))
        #else
            #expect(describe(nil) == String(describing: ToolbarItemPlacement.topBarTrailing))
            #expect(describe("leading") == String(describing: ToolbarItemPlacement.topBarLeading))
            #expect(describe("bottom") == String(describing: ToolbarItemPlacement.bottomBar))
            #expect(describe("keyboard") == String(describing: ToolbarItemPlacement.keyboard))
        #endif
    }

    #if os(iOS)
        @Test func readsTitleDisplayModes() {
            #expect(Bars.titleDisplayMode("inline") == .inline)
            #expect(Bars.titleDisplayMode("large") == .large)
            #expect(Bars.titleDisplayMode("automatic") == .automatic)
            #expect(Bars.titleDisplayMode("bogus") == nil)
        }

        @Test func readsPageIndexDisplay() {
            let describe = { (value: JSONValue?) in String(describing: Tabs.indexDisplayMode(value)) }
            #expect(describe(.string("visible")) == String(describing: PageTabViewStyle.IndexDisplayMode.always))
            #expect(describe(.bool(true)) == String(describing: PageTabViewStyle.IndexDisplayMode.always))
            #expect(describe(.string("hidden")) == String(describing: PageTabViewStyle.IndexDisplayMode.never))
            #expect(describe(nil) == String(describing: PageTabViewStyle.IndexDisplayMode.automatic))
        }
    #endif

    @Test func flattensTabSections() {
        let tab = { (id: Int) in Node(id: id, kind: .element, name: "tab", text: "") }
        let first = tab(1)
        let section = Node(id: 2, kind: .element, name: "tabsection", text: "")
        let second = tab(3)
        let third = tab(4)
        third.attributes["value"] = .string("search")
        section.children = [second, third]
        let tabs = Tabs.tabs(in: [first, section])
        #expect(tabs.map(\.id) == [1, 3, 4])
        #expect(Tabs.value(of: first, in: tabs) == .number(0))
        #expect(Tabs.value(of: second, in: tabs) == .number(1))
        #expect(Tabs.value(of: third, in: tabs) == .string("search"))
    }

    @Test func readsBadges() {
        #expect(Tabs.badge(.number(3)) != nil)
        #expect(Tabs.badge(.string("New")) != nil)
        #expect(Tabs.badge(.number(0)) == nil)
        #expect(Tabs.badge(.string("")) == nil)
        #expect(Tabs.badge(.null) == nil)
        #expect(Tabs.badge(nil) == nil)
    }

    @Test func roundTripsSplitViewColumns() {
        for name in ["all", "doubleColumn", "detailOnly", "automatic"] {
            #expect(SplitView.name(of: SplitView.visibility(name)) == name)
        }
        #expect(SplitView.visibility("bogus") == .automatic)
        #expect(SplitView.visibility(nil) == .automatic)
        for name in ["sidebar", "content", "detail"] {
            #expect(SplitView.name(of: SplitView.column(name, count: 3)) == name)
        }
        #expect(SplitView.column("content", count: 2) == .sidebar)
        #expect(SplitView.column(nil, count: 3) == .sidebar)
    }
}
