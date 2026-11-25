import SvelteSwiftUI
import SwiftUI

@main
struct MainApp: App {
    private static var source: URL {
        #if DEBUG
            if let address = ProcessInfo.processInfo.environment["SVELTE_SOURCE"], let url = URL(string: address) {
                return url
            }
        #endif
        #if DEBUG && targetEnvironment(simulator)
            return URL(filePath: #filePath).deletingLastPathComponent().appending(path: "JavaScript/app.js")
        #else
            return Bundle.main.bundleURL.appending(path: "JavaScript/app.js")
        #endif
    }

    private static var reloadsOnChange: Bool {
        #if DEBUG
            true
        #else
            false
        #endif
    }

    var body: some Scene {
        WindowGroup {
            SvelteView(source: Self.source, reloadsOnChange: Self.reloadsOnChange)
        }
    }
}
