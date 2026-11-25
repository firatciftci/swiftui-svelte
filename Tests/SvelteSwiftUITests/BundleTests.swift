import Foundation
import Testing

@testable import SvelteSwiftUI

struct BundleTests {
    private func runtime() throws -> SvelteRuntime {
        let url = try #require(Bundle.module.url(forResource: "app", withExtension: "js", subdirectory: "Fixtures"))
        return SvelteRuntime(source: url)
    }

    private func greeting(_ text: String) -> String {
        "#fragment\n  <txt>\n    #text \(quoted(text))\n  <btn>\n    #text \"Save\""
    }

    @Test func mountsANamedComponentWithProps() throws {
        let runtime = try runtime()
        let id = runtime.mount("Greeting", props: #"{"name":"Ada","count":3}"#, actions: [:])
        #expect(runtime.error == nil)
        #expect(dump(runtime.store.root(for: id)) == greeting("Ada: 3"))
    }

    @Test func rendersNewPropsFromSwift() throws {
        let runtime = try runtime()
        let id = runtime.mount("Greeting", props: #"{"name":"Ada","count":3}"#, actions: [:])
        runtime.update(id, props: #"{"name":"Grace","count":4}"#, actions: [:])
        #expect(dump(runtime.store.root(for: id)) == greeting("Grace: 4"))
        runtime.update(id, props: #"{"name":"Grace"}"#, actions: [:])
        #expect(dump(runtime.store.root(for: id)) == greeting("Grace: 0"))
    }

    @Test func callsSwiftActionsWithJSONPayloads() throws {
        let runtime = try runtime()
        var received: Array<Any> = []
        let id = runtime.mount("Greeting", props: #"{"name":"Ada","count":3}"#, actions: ["onsave": { received.append($0) }])
        let button = try #require(runtime.store.root(for: id)?.children.last)
        runtime.dispatch(button.id, "click")
        let payload = try #require(received.first as? [String: Any])
        #expect(received.count == 1)
        #expect(payload["name"] as? String == "Ada")
        #expect(payload["count"] as? Double == 3)
        #expect(payload["at"] as? String == "1970-01-01T00:00:00.000Z")
    }

    @Test func runsSeveralMountsInOneContext() throws {
        let runtime = try runtime()
        let counter = runtime.mount("Counter", props: "{}", actions: [:])
        let greeting = runtime.mount("Greeting", props: #"{"name":"Lin"}"#, actions: [:])
        #expect(runtime.store.root(for: counter)?.children.first?.name == "vstack")
        #expect(dump(runtime.store.root(for: greeting)) == self.greeting("Lin: 0"))
        runtime.unmount(greeting)
        runtime.settle()
        #expect(runtime.store.root(for: greeting) == nil)
        #expect(runtime.store.root(for: counter)?.children.first?.name == "vstack")
        #expect(runtime.store.nodeCount < 20)
    }

    @Test func mountsAgainAfterAReload() throws {
        let runtime = try runtime()
        let id = runtime.mount("Greeting", props: #"{"name":"Ada"}"#, actions: [:])
        runtime.update(id, props: #"{"name":"Grace"}"#, actions: [:])
        runtime.restart()
        #expect(dump(runtime.store.root(for: id)) == greeting("Grace: 0"))
    }

    @Test func reportsAMissingComponent() throws {
        let runtime = try runtime()
        let id = runtime.mount("Missing", props: "{}", actions: [:])
        #expect(runtime.store.root(for: id) == nil)
        #expect(runtime.error?.message.contains(#"No component named "Missing""#) == true)
    }

    @Test func encodesPropsAsJSON() {
        let json = SvelteView.json([
            "name": "Ada",
            "count": 3,
            "on": true,
            "at": Date(timeIntervalSince1970: 0),
            "url": URL(string: "https://svelte.dev/docs")!,
            "nested": ["list": [1, "two"]],
        ])
        #expect(
            json
                == #"{"at":"1970-01-01T00:00:00.000Z","count":3,"name":"Ada","nested":{"list":[1,"two"]},"on":true,"url":"https://svelte.dev/docs"}"#
        )
        #expect(SvelteView.json(["bad": SvelteRuntime.self]) == "{}")
    }
}
