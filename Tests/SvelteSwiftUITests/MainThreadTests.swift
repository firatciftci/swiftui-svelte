import Foundation
import QuartzCore
import Testing

@testable import SvelteSwiftUI

private func milliseconds(_ body: () -> Void) -> Double {
    let start = CACurrentMediaTime()
    body()
    return (CACurrentMediaTime() - start) * 1000
}

private let busy = "const busy = (ms) => { const end = Date.now() + ms; while (Date.now() < end) {} };\n"

struct MainThreadTests {
    @Test func startsWithoutWaitingForTheBundleToEvaluate() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try (busy + "busy(300);\n" + mountScript).write(to: url, atomically: true, encoding: .utf8)
        let runtime = SvelteRuntime(source: url)
        let blocked = milliseconds { _ = runtime.mount("default", props: "{}", actions: [:]) }
        #expect(blocked < 100, "start blocked the main thread for \(blocked)ms")
        #expect(runtime.store.node(2) == nil)
        try await eventually { runtime.store.node(2) != nil && runtime.loads == 1 }
    }

    @Test func dispatchesLifecycleEventsWithoutWaitingForJavaScript() async throws {
        let runtime = try runtime(
            busy + mountScript + """
                globalThis.__svelteDispatch = (id, type) => { busy(100); attr(id, type, true); };
                """)
        let node = try #require(runtime.store.node(2))
        let blocked = milliseconds {
            runtime.dispatch(2, "appear")
            runtime.dispatch(2, "disappear")
        }
        #expect(blocked < 50, "appear and disappear blocked the main thread for \(blocked)ms")
        try await eventually { node.attributes["appear"] == .bool(true) && node.attributes["disappear"] == .bool(true) }
    }

    @Test func sendsEventsFromTheFirstTreeBeforeTheBundleFinishesEvaluating() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try (busy + mountScript + "globalThis.__svelteDispatch = (id, type) => attr(id, type, true);\nbusy(1000);\n")
            .write(to: url, atomically: true, encoding: .utf8)
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        for _ in 0..<100 where runtime.store.node(2) == nil {
            usleep(5000)
            runtime.drain()
        }
        #expect(runtime.store.node(2) != nil)
        #expect(runtime.loads == 0)
        runtime.dispatch(2, "appear")
        try await eventually { runtime.store.node(2)?.attributes["appear"] == .bool(true) }
    }

    @Test func runsFinalizersOnTheJavaScriptThread() async throws {
        let runtime = try runtime(
            mountScript + """
                let finalized = 0;
                const registry = new FinalizationRegistry(() => { finalized++; });
                const fill = () => { for (let index = 0; index < 2000; index++) registry.register({ index }, index); };
                fill();
                globalThis.__svelteDispatch = () => { fill(); __nativeGC(); attr(2, "finalized", finalized > 0); };
                """)
        let node = try #require(runtime.store.node(2))
        for _ in 0..<40 where node.attributes["finalized"] != .bool(true) {
            runtime.dispatch(2, "tick")
            try await eventually { node.attributes["finalized"] != nil }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(node.attributes["finalized"] == .bool(true))
    }

    @Test func runsQueuedEventsBeforeAnEventThatWaits() throws {
        let runtime = try runtime(
            mountScript + """
                const seen = [];
                globalThis.__svelteDispatch = (id, type) => { seen.push(type); attr(id, "seen", seen.join(" ")); };
                """)
        let node = try #require(runtime.store.node(2))
        runtime.dispatch(2, "appear")
        runtime.dispatch(2, "tap")
        runtime.edit(node, "value", to: .string("typed"), event: "input")
        #expect(node.attributes["seen"] == .string("appear tap input"))
    }

    @Test func keepsTheOldTreeAndIgnoresItsEventsWhileReloading() async throws {
        let runtime = try runtime(
            busy + mountScript + """
                busy(150);
                globalThis.__svelteDispatch = (id, type) => attr(id, type, true);
                """)
        let root = try #require(runtime.store.node(2))
        runtime.reload()
        #expect(runtime.store.node(2) === root)
        runtime.dispatch(2, "tap")
        try await eventually { runtime.loads == 2 }
        let reloaded = try #require(runtime.store.node(2))
        #expect(reloaded !== root)
        runtime.settle()
        #expect(reloaded.attributes["tap"] == nil)
    }
}

@Suite(.enabled(if: ProcessInfo.processInfo.environment["CI"] == nil, "Main-thread timings are recorded on a laptop"))
struct MainThreadBenchmarks {
    @Test func recordsMainThreadTimeToStartTheFixtureApp() async throws {
        let url = try #require(Bundle.module.url(forResource: "app", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        var id = 0
        let blocked = milliseconds { id = runtime.mount("Table", props: "{}", actions: [:]) }
        try await eventually { runtime.store.root(for: id) != nil }
        print("main thread blocked \(String(format: "%.1f", blocked))ms starting the fixture app")
        #expect(blocked < 20)
    }

    @Test func recordsMainThreadTimeForAThousandAppearEvents() throws {
        let url = try #require(Bundle.module.url(forResource: "app", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        let id = runtime.mount("Table", props: "{}", actions: [:])
        runtime.settle()
        let root = try #require(runtime.store.root(for: id))
        let blocked = milliseconds {
            for _ in 0..<1000 { runtime.dispatch(root.id, "appear") }
        }
        runtime.settle()
        print("main thread blocked \(String(format: "%.1f", blocked))ms dispatching 1,000 appear events")
        #expect(blocked < 5)
    }

    @Test func recordsMainThreadTimeForAThousandEditsThatWait() throws {
        let runtime = try runtime(mountScript)
        let node = try #require(runtime.store.node(2))
        let blocked = milliseconds {
            for index in 0..<1000 { runtime.edit(node, "value", to: .number(Double(index)), event: "input") }
        }
        print("main thread blocked \(String(format: "%.1f", blocked))ms for 1,000 edits that wait")
        #expect(node.attributes["input"] == .number(999))
    }
}
