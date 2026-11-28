import Foundation
import Testing

@testable import SvelteSwiftUI

struct TeardownTests {
    private func busy(socket port: UInt16) -> String {
        mountScript + """
            let ticks = 0;
            setInterval(() => attr(2, "ticks", ++ticks), 5);
            __nativeWebSocketOpen(1, "ws://127.0.0.1:\(port)/ws", "[]", {
              open: () => attr(2, "socket", "open"), message: () => {}, error: () => {}, close: () => {}, sent: () => {},
            });
            __nativeRequestFrame();

            """
    }

    @Test func releasesARuntimeAndStopsItsTimersSocketsAndFrames() async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        weak var released: SvelteRuntime?
        weak var monitor: FrameMonitor?
        var engine: ScriptEngine?
        do {
            let runtime = try runtime(busy(socket: port))
            released = runtime
            monitor = runtime.frames
            engine = runtime.engine
            try await eventually { runtime.store.node(2)?.attributes["socket"] == .string("open") }
            try await eventually { (runtime.store.node(2)?.attributes["ticks"]?.number ?? 0) > 2 }
            #expect(server.openSockets == 1)
            #expect(runtime.frames.link != nil)
        }
        try await eventually { released == nil }
        #expect(monitor == nil)
        let stopped = try #require(engine)
        #expect(stopped.sync { $0.context == nil })
        try await Task.sleep(for: .milliseconds(50))
        #expect(stopped.takeMessages().isEmpty)
        try await eventually { server.openSockets == 0 }
    }

    @Test func stopsARuntimeThatIsStillReferenced() async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        let runtime = try runtime(busy(socket: port))
        try await eventually { runtime.store.node(2)?.attributes["socket"] == .string("open") }
        runtime.stop()
        #expect(runtime.frames.link == nil)
        #expect(runtime.engine.sync { $0.context == nil })
        let ticks = runtime.store.node(2)?.attributes["ticks"]
        try await Task.sleep(for: .milliseconds(50))
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["ticks"] == ticks)
        try await eventually { server.openSockets == 0 }
    }

    @Test func startsAgainWhenAStoppedRuntimeMounts() throws {
        let runtime = try runtime(
            #"globalThis.__svelteMount = (id) => __nativeCommit(JSON.stringify([0, 1, 3, id, 7, "txt", 1, 1, 0, 2, 0, 0, 0]));"#)
        runtime.stop()
        let id = runtime.mount("default", props: "{}", actions: [:])
        #expect(runtime.store.root(for: id)?.children.first?.name == "txt")
    }
}
