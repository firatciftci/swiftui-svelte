import Foundation
import Testing

@testable import SvelteSwiftUI

struct RuntimeTests {
    private func runtime(_ script: String) throws -> Runtime {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try script.write(to: url, atomically: true, encoding: .utf8)
        let runtime = Runtime(source: url, reloadsOnChange: false)
        runtime.start()
        return runtime
    }

    private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    private let mount = """
        __nativeCommit(JSON.stringify([
          { op: "create", id: 1, kind: "fragment" },
          { op: "root", id: 1 },
          { op: "create", id: 2, kind: "element", name: "txt" },
          { op: "insert", parent: 1, id: 2, before: null },
        ]));
        globalThis.__svelteDispatch = (id, type, payload) => {
          __nativeCommit(JSON.stringify([{ op: "attr", id, name: type, value: payload }]));
        };
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

    @Test func runsTimers() async throws {
        let runtime = try runtime(
            mount + """
                let ticks = 0;
                const interval = setInterval(() => {
                  ticks++;
                  if (ticks === 3) {
                    clearInterval(interval);
                    __nativeCommit(JSON.stringify([{ op: "attr", id: 2, name: "ticks", value: ticks }]));
                  }
                }, 5);
                const canceled = setTimeout(() => {
                  __nativeCommit(JSON.stringify([{ op: "attr", id: 2, name: "canceled", value: true }]));
                }, 5);
                clearTimeout(canceled);
                """)
        try await eventually { runtime.store.node(2)?.attributes["ticks"] == .number(3) }
        try await Task.sleep(for: .milliseconds(50))
        #expect(runtime.store.node(2)?.attributes["ticks"] == .number(3))
        #expect(runtime.store.node(2)?.attributes["canceled"] == nil)
    }

    @Test func reportsExceptions() throws {
        let runtime = try runtime("throw new Error('boom')")
        #expect(runtime.error?.contains("boom") == true)
    }

    @Test func reportsAMissingBundle() {
        let runtime = Runtime(source: URL(filePath: "/nonexistent/app.js"), reloadsOnChange: false)
        runtime.start()
        #expect(runtime.error?.contains("Couldn't load") == true)
    }
}
