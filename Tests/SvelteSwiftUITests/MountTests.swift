import Foundation
import Testing

@testable import SvelteSwiftUI

struct MountTests {
    private let script =
        mountScript + """
            globalThis.__svelteMount = (id, name, json) => attr(2, "mounted", JSON.parse(json).actions.join(","));
            let updates = 0;
            globalThis.__svelteProps = (id, json, actions) => attr(2, "update", `${++updates} ${json} ${actions ?? "same"}`);
            globalThis.__svelteDispatch = (id, type) => __nativeAction(1, type, "null");

            """

    @Test func sendsActionNamesWhenTheyChangeWithoutAPropChange() throws {
        let runtime = try runtime(script)
        let id = runtime.mount("default", props: "{}", actions: ["save": { _ in }])
        #expect(runtime.store.node(2)?.attributes["mounted"] == .string("save"))
        runtime.update(id, props: "{}", actions: ["save": { _ in }])
        #expect(runtime.store.node(2)?.attributes["update"] == nil)
        runtime.update(id, props: "{}", actions: ["save": { _ in }, "close": { _ in }])
        #expect(runtime.store.node(2)?.attributes["update"] == .string(#"1 {} ["close","save"]"#))
        runtime.update(id, props: #"{"a":1}"#, actions: ["close": { _ in }, "save": { _ in }])
        #expect(runtime.store.node(2)?.attributes["update"] == .string(#"2 {"a":1} same"#))
        runtime.update(id, props: #"{"a":1}"#, actions: [:])
        #expect(runtime.store.node(2)?.attributes["update"] == .string(#"3 {"a":1} []"#))
    }

    @Test func callsTheLatestClosureForAnAction() throws {
        let runtime = try runtime(script)
        let box = ActionBox()
        var calls: Array<String> = []
        box.actions = ["save": { _ in calls.append("first") }]
        let id = runtime.mount("default", props: "{}", actions: box.forwarding)
        runtime.dispatch(2, "save")
        box.actions = ["save": { _ in calls.append("second") }]
        runtime.dispatch(2, "save")
        #expect(calls == ["first", "second"])
        box.actions = [:]
        runtime.update(id, props: "{}", actions: box.forwarding)
        runtime.dispatch(2, "save")
        #expect(calls == ["first", "second"])
    }
}
