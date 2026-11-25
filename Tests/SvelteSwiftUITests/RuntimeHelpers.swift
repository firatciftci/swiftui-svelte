import JavaScriptCore

@testable import SvelteSwiftUI

extension SvelteRuntime {
    func settle() {
        engine.queue.sync {}
        drain()
    }

    func evaluate<Result>(_ body: (JSContext) -> Result) -> Result? {
        let engine = engine
        let result = engine.queue.sync { engine.context.map(body) }
        drain()
        return result
    }
}
