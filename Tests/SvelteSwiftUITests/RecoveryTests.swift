import Foundation
import Testing

@testable import SvelteSwiftUI

struct RecoveryTests {
    @Test func reportsBridgeErrors() throws {
        let runtime = try runtime(mountScript + "__nativeCommit('[42]');")
        #expect(runtime.store.error?.contains("42") == true)
        #expect(runtime.store.root?.children.first?.name == "txt")
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
