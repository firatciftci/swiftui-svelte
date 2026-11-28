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

    private let mountsRoot = """
        globalThis.__svelteBundle = { version: "9.8.7", protocol: 3 };
        globalThis.__svelteMount = (id) => __nativeCommit(JSON.stringify([0, 1, 3, id, 7, "txt", 1, 1, 0, 2, 0, 0, 0]));
        """

    @Test func readsWhichReleaseBuiltTheBundle() throws {
        let runtime = try runtime(mountsRoot)
        #expect(runtime.bundleIdentity == BundleIdentity(version: "9.8.7", protocolVersion: 3))
        #expect(runtime.loads == 1)
        let unknown = try SvelteSwiftUITests.runtime("globalThis.__svelteBundle = { version: 1 };")
        #expect(unknown.bundleIdentity == nil)
    }

    @Test func showsAMountedRoot() throws {
        let runtime = try runtime(mountsRoot)
        let id = runtime.mount("default", props: "{}", actions: [:])
        guard case let .mounted(root) = runtime.phase(of: id, isOverdue: true) else {
            Issue.record("The mount has no root.")
            return
        }
        #expect(root.children.first?.name == "txt")
    }

    @Test func showsAMountThatThrowsAsFailed() throws {
        let runtime = try runtime(#"globalThis.__svelteMount = (id, name) => { throw new Error(`No component named "${name}".`); };"#)
        let id = runtime.mount("missing", props: "{}", actions: [:])
        guard case let .failed(error) = runtime.phase(of: id, isOverdue: false) else {
            Issue.record("The mount didn't fail.")
            return
        }
        #expect(error.message.contains("missing"))
    }

    @Test func showsABundleThatFailsToLoadAsFailed() {
        let runtime = SvelteRuntime(source: URL(filePath: "/nonexistent/app.js"))
        let id = runtime.mount("default", props: "{}", actions: [:])
        guard case .failed = runtime.phase(of: id, isOverdue: false) else {
            Issue.record("The missing bundle didn't fail.")
            return
        }
        #expect(runtime.loads == 1)
    }

    @Test func showsAMountWithoutARootAsUnresponsiveOnceOverdue() throws {
        let runtime = try runtime("globalThis.__svelteMount = () => {};")
        let id = runtime.mount("default", props: "{}", actions: [:])
        guard case .loading = runtime.phase(of: id, isOverdue: false) else {
            Issue.record("The mount isn't loading.")
            return
        }
        guard case .unresponsive = runtime.phase(of: id, isOverdue: true) else {
            Issue.record("The overdue mount isn't unresponsive.")
            return
        }
    }

    @Test func showsAProtocolMismatch() throws {
        let runtime = try runtime(#"globalThis.__svelteMount = (id) => __nativeCommit(JSON.stringify([0, 1, 2, id]));"#)
        let id = runtime.mount("default", props: "{}", actions: [:])
        guard case .incompatible = runtime.phase(of: id, isOverdue: true) else {
            Issue.record("The mismatch isn't shown.")
            return
        }
        #expect(runtime.store.bundleProtocolVersion == 2)
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
