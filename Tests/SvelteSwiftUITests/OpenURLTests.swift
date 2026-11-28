import Foundation
import Testing

@testable import SvelteSwiftUI

@MainActor
private func recorder() throws -> SvelteRuntime {
    try runtime(
        mountScript + """
            let opened = [];
            globalThis.__svelteAppEvent = (type, payload) => { opened.push(payload); attr(2, "opened", opened.join(" ")); };
            """)
}

@MainActor
private func opened(_ runtime: SvelteRuntime) -> JSONValue? {
    runtime.settle()
    return runtime.store.node(2)?.attributes["opened"]
}

struct OpenURLTests {
    let link = URL(string: "sveltehost://todos/2")!

    @Test func sendsALinkOnlyToTheViewThatAppearedFirst() throws {
        let router = URLRouter()
        let first = try recorder()
        let second = try recorder()
        let firstView = router.nextAppearance()
        let secondView = router.nextAppearance()
        router.offer(link, to: second, appearance: secondView, handling: .automatic)
        router.offer(link, to: first, appearance: firstView, handling: .automatic)
        router.route()
        #expect(opened(first) == .string("sveltehost://todos/2"))
        #expect(opened(second) == nil)
    }

    @Test func prefersTheViewMarkedPreferred() throws {
        let router = URLRouter()
        let first = try recorder()
        let preferred = try recorder()
        router.offer(link, to: first, appearance: router.nextAppearance(), handling: .automatic)
        router.offer(link, to: preferred, appearance: router.nextAppearance(), handling: .preferred)
        router.route()
        #expect(opened(first) == nil)
        #expect(opened(preferred) == .string("sveltehost://todos/2"))
    }

    @Test func skipsViewsThatNeverHandleLinks() throws {
        let router = URLRouter()
        let ignoring = try recorder()
        let handling = try recorder()
        router.offer(link, to: ignoring, appearance: router.nextAppearance(), handling: .never)
        router.offer(link, to: handling, appearance: router.nextAppearance(), handling: .automatic)
        router.route()
        #expect(opened(ignoring) == nil)
        #expect(opened(handling) == .string("sveltehost://todos/2"))
    }

    @Test func opensALinkOnceForViewsThatShareARuntime() throws {
        let router = URLRouter()
        let shared = try recorder()
        router.offer(link, to: shared, appearance: router.nextAppearance(), handling: .automatic)
        router.offer(link, to: shared, appearance: router.nextAppearance(), handling: .automatic)
        router.route()
        #expect(opened(shared) == .string("sveltehost://todos/2"))
    }

    @Test func opensEachLinkAndEachLaterArrival() throws {
        let router = URLRouter()
        let runtime = try recorder()
        let view = router.nextAppearance()
        let other = try #require(URL(string: "sveltehost://todos/3"))
        router.offer(link, to: runtime, appearance: view, handling: .automatic)
        router.offer(other, to: runtime, appearance: view, handling: .automatic)
        router.route()
        router.offer(link, to: runtime, appearance: view, handling: .automatic)
        router.route()
        #expect(opened(runtime) == .string("sveltehost://todos/2 sveltehost://todos/3 sveltehost://todos/2"))
    }

    @Test func routesOnTheNextMainLoopTurnWithoutBeingAsked() async throws {
        let router = URLRouter()
        let runtime = try recorder()
        router.offer(link, to: runtime, appearance: router.nextAppearance(), handling: .automatic)
        #expect(opened(runtime) == nil)
        try await eventually { opened(runtime) == .string("sveltehost://todos/2") }
    }
}
