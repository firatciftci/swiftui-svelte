import Foundation
import JavaScriptCore
import Testing

@testable import SvelteSwiftUI

extension SvelteRuntime {
    func settle() {
        engine.sync { _ in }
        drain()
    }

    func evaluate<Result: Sendable>(_ body: @Sendable (JSContext) -> Result) -> Result? {
        let result = engine.sync { $0.context.map(body) }
        drain()
        return result
    }
}

extension FrameMonitor {
    var isRunning: Bool { link.map { !$0.isPaused } ?? false }
}

let mountScript = """
    __nativeCommit(JSON.stringify([0, 1, 3, 0, 7, "txt", 1, 1, 0, 2, 0, 0, 0]));
    let names = 1;
    const attr = (id, name, value) => __nativeCommit(JSON.stringify([7, name, 4, id, names++, value]));
    globalThis.__svelteDispatch = (id, type, payload) => attr(id, type, payload);

    """

@MainActor
func runtime(_ script: String, modules: Array<NativeModule> = []) throws -> SvelteRuntime {
    let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
    try script.write(to: url, atomically: true, encoding: .utf8)
    let runtime = SvelteRuntime(source: url, modules: modules)
    runtime.start()
    return runtime
}

func pumpRunLoop() {
    CFRunLoopRunInMode(.defaultMode, 0.005, false)
}

func eventually(_ condition: () -> Bool) async throws {
    for _ in 0..<200 where !condition() {
        pumpRunLoop()
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(condition())
}
