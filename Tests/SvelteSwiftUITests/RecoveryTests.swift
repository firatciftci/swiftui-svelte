import Foundation
import Testing

@testable import SvelteSwiftUI

struct RecoveryTests {
    @Test func reportsBridgeErrors() throws {
        let runtime = try runtime(mountScript + "__nativeCommit('[42]');")
        #expect(runtime.store.error?.contains("42") == true)
        #expect(runtime.store.root?.children.first?.name == "txt")
    }

    private let echo = #"globalThis.__svelteDispatch = (id, type, payload) => __nativeCommit(payload);"#

    @Test func remountsAgainAfterTheRemountedAppCommitsCleanly() throws {
        let runtime = try runtime(mountScript + echo)
        runtime.dispatch(2, "x", "[42]")
        #expect(runtime.store.root?.children.first?.name == "txt")
        runtime.dispatch(2, "x", #"[4,2,0,"first"]"#)
        #expect(runtime.store.node(2)?.attributes["txt"] == .string("first"))
        runtime.dispatch(2, "x", "[42]")
        #expect(runtime.store.root?.children.first?.name == "txt")
        runtime.dispatch(2, "x", #"[4,2,0,"second"]"#)
        #expect(runtime.store.node(2)?.attributes["txt"] == .string("second"))
    }

    @Test func stopsWhenTheRemountedAppFailsBeforeItCommitsCleanly() throws {
        let runtime = try runtime(mountScript + echo)
        runtime.dispatch(2, "x", "[42]")
        runtime.dispatch(2, "x", "[42]")
        runtime.dispatch(2, "x", #"[4,2,0,"after"]"#)
        #expect(runtime.store.node(2)?.attributes["txt"] == nil)
        #expect(runtime.store.error?.contains("42") == true)
    }

    @Test func stopsWhenTheRemountedAppFailsRightAfterItMounts() async throws {
        let runtime = try runtime(
            mountScript + echo + #"setTimeout(() => __nativeCommit("[42]"), 0);"#)
        try await eventually { runtime.store.error != nil }
        runtime.dispatch(2, "x", #"[4,2,0,"after"]"#)
        #expect(runtime.store.node(2)?.attributes["txt"] == nil)
        #expect(runtime.store.error?.contains("42") == true)
    }

    @Test func reportsExceptions() throws {
        let runtime = try runtime("throw new Error('boom')")
        #expect(runtime.error?.message.contains("boom") == true)
    }

    @Test func reportsEveryKindOfErrorToTheApp() throws {
        final class Reports {
            var errors: Array<ScriptError> = []
        }
        let reports = Reports()
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try (mountScript + "__nativeCommit('[42]');")
            .write(to: url, atomically: true, encoding: .utf8)
        let runtime = SvelteRuntime(source: url) { reports.errors.append($0) }
        runtime.start()
        #expect(reports.errors.contains { $0.kind == .bridge && $0.message.contains("42") })
        #expect(runtime.error == nil)

        reports.errors = []
        try "throw new Error('boom')".write(to: url, atomically: true, encoding: .utf8)
        runtime.reload()
        #expect(reports.errors.map(\.kind) == [.script])
        #expect(reports.errors.first?.message == "Error: boom")
        #expect(reports.errors.first?.frames.isEmpty == false)

        reports.errors = []
        try FileManager.default.removeItem(at: url)
        runtime.reload()
        #expect(reports.errors.map(\.kind) == [.load])
    }

    @Test func dismissesAndRestartsAfterAnError() throws {
        let runtime = try runtime(mountScript + "__nativeCommit('[42]'); throw new Error('boom');")
        #expect(runtime.error?.message.contains("boom") == true)
        #expect(runtime.store.error != nil)
        runtime.dismissError()
        #expect(runtime.error == nil)
        #expect(runtime.store.error == nil)
        #expect(runtime.store.root?.children.first?.name == "txt")
        runtime.reload()
        #expect(runtime.error?.message.contains("boom") == true)
        #expect(runtime.store.root?.children.first?.name == "txt")
    }

    @Test func reportsAMissingBundle() {
        let runtime = SvelteRuntime(source: URL(filePath: "/nonexistent/app.js"), reloadsOnChange: false)
        runtime.start()
        #expect(runtime.error?.message.contains("Couldn't load") == true)
    }
}
