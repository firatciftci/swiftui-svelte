import Foundation
import Testing

@testable import SvelteSwiftUI

struct RuntimeTests {
    private func runtime(_ script: String) throws -> SvelteRuntime {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try script.write(to: url, atomically: true, encoding: .utf8)
        let runtime = SvelteRuntime(source: url, reloadsOnChange: false)
        runtime.start()
        return runtime
    }

    private func pumpRunLoop() {
        CFRunLoopRunInMode(.defaultMode, 0.005, false)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            pumpRunLoop()
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition())
    }

    private let mount = """
        __nativeCommit(JSON.stringify([0, 1, 2, 0, 7, "txt", 1, 1, 0, 2, 0, 0, 0]));
        let names = 1;
        const attr = (id, name, value) => __nativeCommit(JSON.stringify([7, name, 4, id, names++, value]));
        globalThis.__svelteDispatch = (id, type, payload) => attr(id, type, payload);

        """

    @Test func appliesCommitsFromTheBundle() throws {
        let runtime = try runtime(mount)
        #expect(runtime.store.root?.children.first?.name == "txt")
        #expect(runtime.error == nil)
    }

    @Test func dispatchesEventsWithPayloads() throws {
        let runtime = try runtime(mount)
        runtime.dispatch(2, "input", "hello")
        runtime.dispatch(2, "change", 3.5)
        runtime.dispatch(2, "toggle", true)
        let attributes = runtime.store.node(2)?.attributes
        #expect(attributes?["input"] == .string("hello"))
        #expect(attributes?["change"] == .number(3.5))
        #expect(attributes?["toggle"] == .bool(true))
    }

    @Test func showsAnEditThenTheValueThatJavaScriptSettlesOn() async throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteDispatch = (id) => attr(id, "value", "kept");
                """)
        let node = try #require(runtime.store.node(2))
        runtime.edit(node, "value", to: .string("typed"), event: "input", payload: "typed")
        #expect(node.attributes["value"] == .string("typed"))
        try await eventually { node.attributes["value"] == .string("kept") }
    }

    @Test func keepsAnEditThatJavaScriptAccepts() throws {
        let runtime = try runtime(mount)
        let node = try #require(runtime.store.node(2))
        runtime.edit(node, "input", to: .string("typed"), event: "input", payload: "typed")
        #expect(node.attributes["input"] == .string("typed"))
    }

    @Test func callsBackOnceForEachRequestedFrame() async throws {
        let runtime = try runtime(
            mount + """
                let frames = 0;
                globalThis.__svelteFrame = (time) => {
                  frames++;
                  if (frames < 3) __nativeRequestFrame();
                  else attr(2, "frames", typeof time === "number" && time > 0 ? frames : -1);
                };
                __nativeRequestFrame();
                __nativeRequestFrame();
                """)
        try await eventually { runtime.store.node(2)?.attributes["frames"] == .number(3) }
    }

    @Test func runsTimers() async throws {
        let runtime = try runtime(
            mount + """
                let ticks = 0;
                const interval = setInterval(() => {
                  ticks++;
                  if (ticks === 3) {
                    clearInterval(interval);
                    attr(2, "ticks", ticks);
                  }
                }, 5);
                const canceled = setTimeout(() => {
                  attr(2, "canceled", true);
                }, 5);
                clearTimeout(canceled);
                """)
        try await eventually { runtime.store.node(2)?.attributes["ticks"] == .number(3) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(runtime.store.node(2)?.attributes["ticks"] == .number(3))
        #expect(runtime.store.node(2)?.attributes["canceled"] == nil)
    }

    @Test func reportsBridgeErrors() throws {
        let runtime = try runtime(mount + "__nativeCommit('[42]');")
        #expect(runtime.store.error?.contains("42") == true)
        #expect(runtime.store.root?.children.first?.name == "txt")
    }

    @Test func reportsExceptions() throws {
        let runtime = try runtime("throw new Error('boom')")
        #expect(runtime.error?.message.contains("boom") == true)
    }

    @Test func dismissesAndRestartsAfterAnError() throws {
        let runtime = try runtime(mount + "__nativeCommit('[42]'); throw new Error('boom');")
        #expect(runtime.error?.message.contains("boom") == true)
        #expect(runtime.store.error != nil)
        runtime.dismissError()
        #expect(runtime.error == nil)
        #expect(runtime.store.error == nil)
        #expect(runtime.store.root?.children.first?.name == "txt")
        runtime.restart()
        #expect(runtime.error?.message.contains("boom") == true)
        #expect(runtime.store.root?.children.first?.name == "txt")
    }

    @Test func reportsAMissingBundle() {
        let runtime = SvelteRuntime(source: URL(filePath: "/nonexistent/app.js"), reloadsOnChange: false)
        runtime.start()
        #expect(runtime.error?.message.contains("Couldn't load") == true)
    }
}
