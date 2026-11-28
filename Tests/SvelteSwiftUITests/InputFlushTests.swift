import Foundation
import Testing

@testable import SvelteSwiftUI

struct InputFlushTests {
    private let log =
        mountScript + """
            const events = [];
            globalThis.__svelteMount = () => {};
            globalThis.__svelteDispatch = (id, type, payload) => {
              events.push(`${id}:${type}:${payload}`);
              attr(1, "events", events.join(" "));
            };
            globalThis.__svelteNativeEvent = (module, event) => {
              events.push(`${module}.${event}`);
              attr(1, "events", events.join(" "));
            };
            globalThis.__svelteProps = () => {
              events.push("props");
              attr(1, "events", events.join(" "));
            };

            """

    private func events(_ runtime: SvelteRuntime) -> String? {
        runtime.settle()
        return runtime.store.node(1)?.attributes["events"]?.string
    }

    @Test func sendsPendingInputBeforeAButtonTap() throws {
        let runtime = try runtime(log)
        runtime.deferInput(2, "abc")
        runtime.dispatch(3, "click", waits: false)
        #expect(events(runtime) == "2:input:abc 3:click:null")
    }

    @Test func sendsPendingInputBeforeBlurAndSubmit() throws {
        let runtime = try runtime(log)
        runtime.deferInput(2, "draft")
        runtime.dispatch(2, "blur", waits: false)
        runtime.deferInput(2, "final")
        runtime.submit(2)
        #expect(events(runtime) == "2:input:draft 2:blur:null 2:input:final 2:submit:null")
    }

    @Test func showsWhatTheSubmitHandlerClearsBeforeTheNextKeystroke() throws {
        let runtime = try runtime(
            mountScript + #"globalThis.__svelteDispatch = (id, type) => { if (type === "submit") attr(id, "value", ""); };"#)
        let node = try #require(runtime.store.node(2))
        node.setOwnAttribute("value", .string("Errand 8"))
        runtime.submit(2)
        #expect(node.attributes["value"] == .string(""))
    }

    @Test func sendsPendingInputBeforeNativeEventsAndPropUpdates() throws {
        let runtime = try runtime(log)
        let mount = runtime.mount("default", props: "{}", actions: [:])
        runtime.deferInput(2, "a")
        runtime.emit("saved", from: "store")
        runtime.deferInput(2, "ab")
        runtime.update(mount, props: #"{"x":1}"#, actions: [:])
        #expect(events(runtime) == "2:input:a store.saved 2:input:ab props")
    }

    @Test func sendsPendingInputInTheOrderItWasTyped() throws {
        let runtime = try runtime(log)
        runtime.deferInput(4, "first")
        runtime.deferInput(2, "second")
        runtime.deferInput(4, "first again")
        runtime.sendInput(3, "now")
        #expect(events(runtime) == "4:input:first again 2:input:second 3:input:now")
    }

    @Test func flushesOneFieldOnlyWhenItHasPendingInput() throws {
        let runtime = try runtime(log)
        runtime.flushInput(2)
        #expect(events(runtime) == nil)
        runtime.deferInput(2, "x")
        runtime.flushInput(2)
        runtime.flushInput(2)
        #expect(events(runtime) == "2:input:x")
    }

    @Test func dropsDiscardedInput() throws {
        let runtime = try runtime(log)
        runtime.deferInput(2, "typed")
        runtime.inputs.discard(2)
        runtime.dispatch(3, "click")
        #expect(events(runtime) == "3:click:null")
    }

    @Test func recognizesAStaleEchoWhileNewerTextIsPending() throws {
        let runtime = try runtime(log)
        runtime.sendInput(2, "ab")
        #expect(!runtime.inputs.isStaleEcho("ab", of: 2))
        runtime.deferInput(2, "abc")
        #expect(runtime.inputs.isStaleEcho("ab", of: 2))
        #expect(!runtime.inputs.isStaleEcho("AB", of: 2))
        runtime.inputs.forget(2)
        #expect(!runtime.inputs.isStaleEcho("ab", of: 2))
    }
}
