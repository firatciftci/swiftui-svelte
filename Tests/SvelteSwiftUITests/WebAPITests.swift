import Foundation
import JavaScriptCore
import Synchronization
import Testing

@testable import SvelteSwiftUI

struct WebAPITests {
    private struct Outcome: Decodable {
        let name: String
        let error: String?
    }

    private func evaluate(_ runtime: SvelteRuntime, _ script: String) -> String? {
        runtime.evaluate { $0.evaluateScript(script)?.toString() }.flatMap(\.self)
    }

    @Test func passesTheSharedWebSuiteInJavaScriptCore() async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        let report = Mutex<String?>(nil)
        let callback: @convention(block) @Sendable (String) -> Void = { json in report.withLock { $0 = json } }
        let endpoints = #"{"http":"http://127.0.0.1:\#(port)","ws":"ws://127.0.0.1:\#(port)"}"#
        runtime.evaluate { context in
            context.globalObject.setValue(callback, forProperty: "__nativeReport")
            context.objectForKeyedSubscript("__runWebSuite")?.call(withArguments: [endpoints])
        }
        let deadline = ContinuousClock.now + .seconds(90)
        while report.withLock({ $0 }) == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(runtime.error == nil)
        let json = try #require(report.withLock { $0 })
        let outcomes = try JSONDecoder().decode(Array<Outcome>.self, from: Data(json.utf8))
        #expect(outcomes.count >= 45)
        let failures = outcomes.compactMap { outcome in outcome.error.map { "\(outcome.name): \($0)" } }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test func forwardsHostEnvironmentChangesToJavaScript() throws {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        let query = "matchMedia('(prefers-color-scheme: dark)').matches"
        runtime.updateEnvironment(["colorScheme": "light", "systemColorScheme": "light", "reduceMotion": false])
        #expect(evaluate(runtime, query) == "false")
        runtime.updateEnvironment(["colorScheme": "dark", "systemColorScheme": "dark", "reduceMotion": true])
        #expect(evaluate(runtime, query) == "true")
        #expect(evaluate(runtime, "matchMedia('(prefers-reduced-motion: reduce)').matches") == "true")
        #expect(evaluate(runtime, "navigator.languages.length > 0") == "true")
        #expect(evaluate(runtime, "navigator.userAgent")?.hasPrefix("swiftui-svelte (") == true)
        runtime.restart()
        #expect(evaluate(runtime, query) == "true")
    }

    @Test func persistsLocalStorageInUserDefaults() async throws {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let key = "SvelteSwiftUI.localStorage"
        let saved = UserDefaults.standard.string(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.set(#"{"kept":"yes"}"#, forKey: key)
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        #expect(evaluate(runtime, "localStorage.getItem('kept')") == "yes")
        _ = evaluate(runtime, "localStorage.setItem('count', 2); localStorage.removeItem('kept')")
        try await Task.sleep(for: .milliseconds(20))
        #expect(UserDefaults.standard.string(forKey: key) == #"{"count":"2"}"#)
    }

    @Test func namesURLErrorsSoAppsCanTellOfflineFromOtherFailures() {
        let refused = NetworkClient.failure(URLError(.cannotConnectToHost))
        #expect(refused["name"] as? String == "cannotConnectToHost")
        #expect(refused["code"] as? Int == URLError.cannotConnectToHost.rawValue)
        #expect(NetworkClient.failure(URLError(.notConnectedToInternet))["name"] as? String == "notConnectedToInternet")
        #expect(NetworkClient.failure(URLError(.dnsLookupFailed))["name"] as? String == "dnsLookupFailed")
        #expect(NetworkClient.failure(URLError(.badURL))["name"] as? String == "unknown")
        #expect(NetworkClient.failure(CocoaError(.fileNoSuchFile))["name"] as? String == "unknown")
    }
}
