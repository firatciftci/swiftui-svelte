import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct SearchTests {
    @Test func readsTokens() {
        let tokens = SearchToken.tokens(
            .array([
                .string("Fruit"),
                .object(["id": .number(2), "label": .string("Vegetable"), "symbol": .string("leaf")]),
                .object(["id": .string("fruit"), "label": .string("Fruit")]),
                .object(["symbol": .string("star")]),
                .number(4),
                .string("Fruit"),
            ]))
        #expect(tokens.map(\.id) == ["Fruit", "2", "fruit"])
        #expect(tokens.map(\.label) == ["Fruit", "Vegetable", "Fruit"])
        #expect(tokens[1].symbol == "leaf")
        #expect(tokens[1].value == .object(["id": .number(2), "label": .string("Vegetable"), "symbol": .string("leaf")]))
        #expect(SearchToken.tokens(.string("Fruit")).isEmpty)
        #expect(SearchToken.tokens(nil).isEmpty)
    }

    @Test func readsScopes() {
        let scopes = SearchScope.scopes(
            .array([
                .string("All"),
                .object(["value": .string("recent"), "title": .string("Recent")]),
                .object(["value": .string("saved")]),
                .object(["title": .string("Missing")]),
                .bool(true),
            ]))
        #expect(scopes.map(\.value) == ["All", "recent", "saved"])
        #expect(scopes.map(\.title) == ["All", "Recent", "saved"])
        #expect(SearchScope.scopes(nil).isEmpty)
    }

    @Test func readsPlacements() {
        let describe = { (name: String?, drawer: String?) in String(describing: Searches.placement(name, drawer: drawer)) }
        #expect(describe("toolbar", nil) == String(describing: SearchFieldPlacement.toolbar))
        #expect(describe("sidebar", nil) == String(describing: SearchFieldPlacement.sidebar))
        #expect(describe(nil, nil) == String(describing: SearchFieldPlacement.automatic))
        #expect(describe("toolbar", nil) != describe("sidebar", nil))
        #if os(iOS)
            #expect(
                describe("navigationBarDrawer", "always")
                    == String(describing: SearchFieldPlacement.navigationBarDrawer(displayMode: .always)))
            #expect(describe("navigationBarDrawer", "always") != describe("navigationBarDrawer", nil))
        #else
            #expect(describe("navigationBarDrawer", "always") == String(describing: SearchFieldPlacement.automatic))
        #endif
    }

    @Test func readsScopeActivation() {
        let describe = { (name: String?) in String(describing: Searches.activation(name)) }
        #expect(describe("onTextEntry") == String(describing: SearchScopeActivation.onTextEntry))
        #expect(describe("onSearchPresentation") == String(describing: SearchScopeActivation.onSearchPresentation))
        #expect(describe(nil) == String(describing: SearchScopeActivation.automatic))
        #expect(describe("onTextEntry") != describe("onSearchPresentation"))
    }
}
