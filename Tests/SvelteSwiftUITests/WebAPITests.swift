import Foundation
import JavaScriptCore
import Testing

@testable import SvelteSwiftUI

struct WebAPITests {
    private struct Outcome: Decodable {
        let name: String
        let error: String?
    }

    private final class Report {
        var json: String?
    }

    @Test func passesTheSharedWebSuiteInJavaScriptCore() async throws {
        let server = try TestServer()
        let port = try await server.start()
        defer { server.stop() }
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        let context = try #require(runtime.context)
        let report = Report()
        let callback: @convention(block) (String) -> Void = { report.json = $0 }
        context.globalObject.setValue(callback, forProperty: "__nativeReport")
        let endpoints = #"{"http":"http://127.0.0.1:\#(port)","ws":"ws://127.0.0.1:\#(port)"}"#
        context.objectForKeyedSubscript("__runWebSuite")?.call(withArguments: [endpoints])
        let deadline = ContinuousClock.now + .seconds(90)
        while report.json == nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(runtime.error == nil)
        let outcomes = try JSONDecoder().decode(Array<Outcome>.self, from: Data(try #require(report.json).utf8))
        #expect(outcomes.count >= 45)
        let failures = outcomes.compactMap { outcome in outcome.error.map { "\(outcome.name): \($0)" } }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    @Test func forwardsHostEnvironmentChangesToJavaScript() throws {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        let context = try #require(runtime.context)
        let query = "matchMedia('(prefers-color-scheme: dark)').matches"
        runtime.updateEnvironment(["colorScheme": "light", "reduceMotion": false])
        #expect(context.evaluateScript(query)?.toBool() == false)
        runtime.updateEnvironment(["colorScheme": "dark", "reduceMotion": true])
        #expect(context.evaluateScript(query)?.toBool() == true)
        #expect(context.evaluateScript("matchMedia('(prefers-reduced-motion: reduce)').matches")?.toBool() == true)
        #expect(context.evaluateScript("navigator.languages.length > 0")?.toBool() == true)
        #expect(context.evaluateScript("navigator.userAgent")?.toString().hasPrefix("swiftui-svelte (") == true)
        runtime.restart()
        #expect(runtime.context?.evaluateScript(query)?.toBool() == true)
    }

    @Test func persistsLocalStorageInUserDefaults() async throws {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let key = "SvelteSwiftUI.localStorage"
        let saved = UserDefaults.standard.string(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }
        UserDefaults.standard.set(#"{"kept":"yes"}"#, forKey: key)
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        let context = try #require(runtime.context)
        #expect(context.evaluateScript("localStorage.getItem('kept')")?.toString() == "yes")
        context.evaluateScript("localStorage.setItem('count', 2); localStorage.removeItem('kept')")
        try await Task.sleep(for: .milliseconds(20))
        #expect(UserDefaults.standard.string(forKey: key) == #"{"count":"2"}"#)
    }
}
