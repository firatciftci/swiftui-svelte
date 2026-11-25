import Foundation
import Testing

@testable import SvelteSwiftUI

#if canImport(UIKit)
    import UIKit
#endif

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

    @Test func appliesAnimatedCommitsWhateverTheAnimationSays() throws {
        let runtime = try runtime(
            mount + """
                __nativeCommit(JSON.stringify([7, "a", 4, 2, names++, 1]), JSON.stringify({ type: "bouncy", duration: 300 }));
                __nativeCommit(JSON.stringify([7, "b", 4, 2, names++, 2]), "false");
                __nativeCommit(JSON.stringify([7, "c", 4, 2, names++, 3]), "{not json");
                __nativeCommit(JSON.stringify([7, "d", 4, 2, names++, 4]), 42);
                """)
        let attributes = runtime.store.node(2)?.attributes
        #expect(attributes?["a"] == .number(1))
        #expect(attributes?["b"] == .number(2))
        #expect(attributes?["c"] == .number(3))
        #expect(attributes?["d"] == .number(4))
        #expect(runtime.error == nil)
    }

    @Test func passesMemoryWarningsToJavaScript() throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteAppEvent = (type, payload) => attr(2, type, payload);
                """)
        runtime.receiveMemoryWarning()
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["memorywarning"] == .null)
    }

    #if canImport(UIKit)
        @Test func listensForSystemMemoryWarnings() throws {
            let runtime = try runtime(
                mount + """
                    globalThis.__svelteAppEvent = (type) => attr(2, type, true);
                    """)
            NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
            runtime.settle()
            #expect(runtime.store.node(2)?.attributes["memorywarning"] == .bool(true))
        }
    #endif

    @Test func holdsURLsThatArriveBeforeTheRuntimeStarts() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try
            (mount + """
                let opened = 0;
                globalThis.__svelteAppEvent = (type, payload) => attr(2, type, [++opened, payload]);
                """).write(to: url, atomically: true, encoding: .utf8)
        let runtime = SvelteRuntime(source: url, reloadsOnChange: false)
        let link = try #require(URL(string: "sveltehost://todos/2"))
        runtime.open(link, from: nil)
        runtime.open(link, from: nil)
        runtime.start()
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["openurl"] == .array([.number(1), .string("sveltehost://todos/2")]))
    }

    @Test func opensEachURLOnceWhenSeveralViewsReceiveIt() throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteMount = () => {};
                let opened = 0;
                globalThis.__svelteAppEvent = (type, payload) => attr(2, type, [++opened, payload]);
                """)
        let first = runtime.mount("First", props: "{}", actions: [:])
        let second = runtime.mount("Second", props: "{}", actions: [:])
        let url = try #require(URL(string: "sveltehost://todos/4"))
        runtime.open(url, from: second)
        runtime.open(url, from: first)
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["openurl"] == .array([.number(1), .string("sveltehost://todos/4")]))
        runtime.unmount(first)
        runtime.open(url, from: second)
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["openurl"] == .array([.number(2), .string("sveltehost://todos/4")]))
        runtime.open(url)
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["openurl"] == .array([.number(3), .string("sveltehost://todos/4")]))
    }

    @Test func answersMeasurementsOnceTheElementIsLaidOut() throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteReply = (request, rect) => attr(2, `reply${request}`, rect);
                __nativeInvoke(2, "measure", JSON.stringify({ request: 1 }));
                __nativeInvoke(99, "measure", JSON.stringify({ request: 2 }));
                """)
        runtime.settle()
        let node = try #require(runtime.store.node(2))
        #expect(node.isMeasured)
        #expect(node.attributes["reply1"] == nil)
        #expect(node.attributes["reply2"] == .null)
        runtime.measured(node, frame: .zero)
        runtime.settle()
        #expect(node.attributes["reply1"] == nil)
        runtime.measured(node, frame: CGRect(x: 16, y: 120, width: 370, height: 44))
        runtime.settle()
        let rect: JSONValue = .object(["x": .number(16), "y": .number(120), "width": .number(370), "height": .number(44)])
        #expect(node.attributes["reply1"] == rect)
        _ = runtime.evaluate { $0.evaluateScript(#"__nativeInvoke(2, "measure", JSON.stringify({ request: 3 }))"#) }
        runtime.settle()
        #expect(node.attributes["reply3"] == rect)
    }

    @Test func answersPendingMeasurementsWithNullWhenTheElementIsRemoved() throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteReply = (request, rect) => { globalThis.replied = [request, rect]; };
                __nativeInvoke(2, "measure", JSON.stringify({ request: 5 }));
                """)
        runtime.settle()
        _ = runtime.evaluate { $0.evaluateScript("__nativeCommit(JSON.stringify([3, 2]))") }
        runtime.settle()
        let replied = runtime.evaluate { $0.evaluateScript("JSON.stringify(globalThis.replied)")?.toString() }
        #expect(replied == "[5,null]")
    }

    @Test func turnsFocusAndScrollCallsIntoRequests() throws {
        let runtime = try runtime(
            mount + """
                __nativeCommit(JSON.stringify([1, 2, 0, 8, 0, 0, 0, 1, 2, 0, 9, 0, 0, 0]));
                __nativeInvoke(2, "focus", "{}");
                """)
        runtime.settle()
        let node = try #require(runtime.store.node(2))
        #expect(node.focusRequest.isFocused)
        _ = runtime.evaluate {
            $0.evaluateScript(
                #"__nativeInvoke(2, "blur", "{}"); __nativeInvoke(2, "scrollTo", JSON.stringify({ edge: "bottom", animated: false }))"#)
        }
        runtime.settle()
        #expect(!node.focusRequest.isFocused)
        #expect(runtime.scrollRequest?.target == 9)
        #expect(runtime.scrollRequest?.anchor == .bottom)
        #expect(runtime.scrollRequest?.isAnimated == false)
        _ = runtime.evaluate { $0.evaluateScript(#"__nativeInvoke(8, "scrollIntoView", JSON.stringify({ anchor: "center" }))"#) }
        runtime.settle()
        #expect(runtime.scrollRequest?.target == 8)
        #expect(runtime.scrollRequest?.anchor == .center)
        #expect(runtime.scrollRequest?.isAnimated == true)
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

    @Test func waitsForAnAwaitedDispatchToSettle() async throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteDispatch = (id, type, payload, request) => {
                  attr(id, type, request ?? null);
                  setTimeout(() => {
                    attr(id, "done", true);
                    __nativeInvoke(id, "settled", JSON.stringify({ request }));
                  }, 30);
                };
                """)
        let start = ContinuousClock.now
        await runtime.dispatchAndWait(2, "refresh")
        #expect(ContinuousClock.now - start >= .milliseconds(25))
        #expect(runtime.store.node(2)?.attributes["done"] == .bool(true))
        #expect(runtime.store.node(2)?.attributes["refresh"]?.number != nil)
    }

    @Test func endsAwaitedDispatchesWhenTheBundleRestarts() async throws {
        let runtime = try runtime(mount + "globalThis.__svelteDispatch = () => {};")
        var isDone = false
        let task = Task {
            await runtime.dispatchAndWait(2, "refresh")
            isDone = true
        }
        try await Task.sleep(for: .milliseconds(20))
        #expect(!isDone)
        runtime.restart()
        await task.value
        #expect(isDone)
    }

    @Test func runsSlowHandlersWithoutBlockingTheMainThread() throws {
        let runtime = try runtime(
            mount + """
                globalThis.__svelteDispatch = (id, type) => {
                  const end = __nativeNow() + 300;
                  while (__nativeNow() < end) {}
                  attr(id, type, true);
                };
                """)
        let start = ContinuousClock.now
        runtime.dispatch(2, "click", waits: false)
        #expect(ContinuousClock.now - start < .milliseconds(100))
        #expect(runtime.store.node(2)?.attributes["click"] == nil)
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["click"] == .bool(true))
    }

    @Test func convertsDelaysLikeBrowsers() async throws {
        let runtime = try runtime(
            mount + """
                let fired = 0;
                for (const delay of [NaN, undefined, "soon", "10", -5, Infinity, 2 ** 32]) {
                  setTimeout(() => attr(2, "fired", ++fired), delay);
                }
                setTimeout(() => attr(2, "late", true), 2 ** 31 - 1);
                setTimeout((a, b) => attr(2, "sum", a + b), 0, 2, 3);
                """)
        try await eventually { runtime.store.node(2)?.attributes["fired"] == .number(7) }
        #expect(runtime.store.node(2)?.attributes["sum"] == .number(5))
        #expect(runtime.store.node(2)?.attributes["late"] == nil)
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
