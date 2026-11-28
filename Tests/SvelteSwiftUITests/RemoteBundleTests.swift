import Foundation
import Testing

@testable import SvelteSwiftUI

struct RemoteBundleTests {
    private func script(_ text: String) -> String {
        #"__nativeCommit(JSON.stringify([0, 1, 3, 0, 7, "txt", 1, 1, 0, 2, 0, 0, 1, -3, "\#(text)"]));"#
    }

    private func text(_ runtime: SvelteRuntime) -> String? {
        runtime.store.root?.children.first?.children.first?.text
    }

    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(30)
        while !condition(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(condition())
    }

    @Test func loadsABundleFromADevServerAndReloadsWhenItChanges() async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        server.serve(script("first"), at: "/app.js")
        let source = try #require(URL(string: "http://127.0.0.1:\(port)/app.js"))
        let runtime = SvelteRuntime(source: source, reloadsOnChange: true)
        runtime.start()
        try await eventually { text(runtime) == "first" }
        server.serve(script("second"), at: "/app.js")
        try await eventually { text(runtime) == "second" }
        #expect(runtime.error == nil)
    }

    @Test(arguments: ["/etag/app.js", "/dated/app.js", "/plain/app.js"])
    func pollsWithOneConditionalRequestAndReloadsWhenTheBundleChanges(path: String) async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        server.serve(script("first"), at: path)
        let source = try #require(URL(string: "http://127.0.0.1:\(port)\(path)"))
        let runtime = SvelteRuntime(source: source, reloadsOnChange: true)
        runtime.start()
        try await eventually { text(runtime) == "first" }
        let generation = runtime.generation
        let before = server.requests.count
        try await Task.sleep(for: .seconds(1.2))
        #expect(runtime.generation == generation)
        let polls = server.requests.dropFirst(before).filter {
            $0.hasPrefix("HEAD") || $0 == "GET \(path)" || $0 == "GET \(path) conditional"
        }
        #expect(polls.count >= 1)
        #expect(polls.count <= 3)
        let expected = path.hasPrefix("/plain/") ? "GET \(path)" : "GET \(path) conditional"
        #expect(polls.allSatisfy { $0 == expected }, "\(polls)")
        server.serve(script("second"), at: path)
        try await eventually { text(runtime) == "second" }
        #expect(runtime.error == nil)
    }

    @Test func reportsABundleThatTheServerDoesNotHave() async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        let source = try #require(URL(string: "http://127.0.0.1:\(port)/missing.js"))
        let runtime = SvelteRuntime(source: source)
        runtime.start()
        try await eventually { runtime.error != nil }
        #expect(runtime.error?.message == "Couldn't load \(source.absoluteString): the server answered 404.")
    }
}
