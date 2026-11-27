import SvelteSwiftUI
import SwiftUI

@main
struct SvelteHostApp: App {
    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetStorage") {
            UserDefaults.standard.removeObject(forKey: "SvelteSwiftUI.localStorage")
        }
    }

    private static let modules = [CameraModule.module, DiagnosticsModule.module]
    private static let components = [NativeComponent("mapview") { MapElement(element: $0) }]

    private static var source: URL {
        #if DEBUG
            if let address = ProcessInfo.processInfo.environment["SVELTE_SOURCE"], let url = URL(string: address) {
                return url
            }
        #endif
        #if targetEnvironment(simulator)
            return URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Resources/app.js")
        #else
            return Bundle.main.bundleURL.appending(path: "app.js")
        #endif
    }

    private static var props: [String: JSONValue] {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-catalog"), arguments.indices.contains(index + 1) {
                return ["catalog": .string(arguments[index + 1])]
            }
        #endif
        return [:]
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
            if ProcessInfo.processInfo.arguments.contains("-NativeBench") {
                NativeBench()
            } else {
                SvelteView(
                    source: Self.source, props: Self.props, reloadsOnChange: Self.reloadsOnChange,
                    modules: Self.modules, components: Self.components)
            }
        }
    }
}
