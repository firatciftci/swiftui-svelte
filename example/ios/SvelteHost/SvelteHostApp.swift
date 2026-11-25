import SvelteSwiftUI
import SwiftUI

@main
struct SvelteHostApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetStorage") {
            UserDefaults.standard.removeObject(forKey: "SvelteSwiftUI.localStorage")
        }
    }

    var body: some Scene {
        WindowGroup {
            #if targetEnvironment(simulator)
                SvelteView(
                    source: URL(filePath: #filePath).deletingLastPathComponent()
                        .appending(path: "Resources/app.js"),
                    reloadsOnChange: true)
            #else
                SvelteView(source: Bundle.main.bundleURL.appending(path: "app.js"))
            #endif
        }
    }
}
