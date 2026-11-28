#if canImport(AppKit)
    import AppKit
    import Foundation
    import SwiftUI
    import Testing

    @testable import SvelteSwiftUI

    @Observable private final class Parent {
        var count = 0
        var source: URL
        var runtime: SvelteRuntime?

        init(source: URL) {
            self.source = source
        }
    }

    private struct ParentView: View {
        let parent: Parent

        var body: some View {
            VStack {
                Text("\(parent.count)")
                if let runtime = parent.runtime {
                    SvelteView(runtime: runtime, props: ["count": JSONValue(parent.count)])
                } else {
                    SvelteView(source: parent.source, props: ["count": JSONValue(parent.count)])
                }
            }
        }
    }

    private let mountingScript = """
        let names = 1;
        const attr = (id, name, value) => __nativeCommit(JSON.stringify([7, name, 4, id, names++, value]));
        globalThis.__svelteMount = (id) => __nativeCommit(JSON.stringify([0, 1, 3, id, 7, "txt", 1, 1, 0, 2, 0, 0, 0]));
        globalThis.__svelteUnmount = () => attr(2, "unmounted", true);
        """

    @MainActor
    struct SvelteViewTests {
        private func script() throws -> URL {
            let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
            try mountingScript.write(to: url, atomically: true, encoding: .utf8)
            return url
        }

        private func render(_ parent: Parent) -> NSHostingView<ParentView> {
            let host = NSHostingView(rootView: ParentView(parent: parent))
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 320, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderBack(nil)
            host.layoutSubtreeIfNeeded()
            pumpRunLoop()
            return host
        }

        private func update(_ host: NSHostingView<ParentView>) {
            pumpRunLoop()
            host.layoutSubtreeIfNeeded()
        }

        @Test func createsOneRuntimeAcrossAHundredParentRenders() throws {
            let parent = Parent(source: try script())
            let before = SvelteRuntime.created
            let host = render(parent)
            for count in 1...100 {
                parent.count = count
                update(host)
            }
            #expect(SvelteRuntime.created - before == 1, "\(SvelteRuntime.created - before) runtimes")
        }

        @Test func startsAnotherRuntimeWhenTheSourceChanges() throws {
            let parent = Parent(source: try script())
            let host = render(parent)
            let before = SvelteRuntime.created
            parent.source = try script()
            update(host)
            parent.count = 1
            update(host)
            #expect(SvelteRuntime.created - before == 1, "\(SvelteRuntime.created - before) runtimes")
        }

        @Test func mountsOnARuntimeThatReplacesTheOneItWasGiven() async throws {
            let first = SvelteRuntime(source: try script())
            let parent = Parent(source: try script())
            parent.runtime = first
            let host = render(parent)
            try await eventually { first.store.node(2) != nil }
            let second = SvelteRuntime(source: try script())
            parent.runtime = second
            update(host)
            try await eventually { second.store.node(2) != nil && first.store.node(2)?.attributes["unmounted"] == .bool(true) }
        }
    }
#endif
