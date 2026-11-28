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

    @Test func exposesTheNativeCryptoAndProtocolGlobalsWithTheirErrors() throws {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        func thrown(_ call: String) -> String? {
            evaluate(runtime, "(() => { try { \(call); return 'none'; } catch (error) { return error.message; } })()")
        }
        #expect(evaluate(runtime, "JSON.stringify(__nativeProtocols)") == "[\(NodeStore.protocolVersion)]")
        #expect(
            evaluate(runtime, "Array.from(__nativeDigest('SHA-256', new Uint8Array([97, 98, 99])).slice(0, 4)).join()")
                == "186,120,22,191"
        )
        #expect(thrown("__nativeDigest('MD5', new Uint8Array(1))") == "Unsupported digest algorithm MD5.")
        #expect(thrown("__nativeDigest('SHA-256', [1, 2])") == "The data must be a TypedArray.")
        #expect(thrown("__nativeRandomFill({ length: 4 })") == "The argument must be a TypedArray.")
        #expect(evaluate(runtime, "(() => { const a = new Uint8Array(4096); __nativeRandomFill(a); return a.some(Boolean); })()") == "true")
        #expect(evaluate(runtime, "(() => { const a = new Uint8Array(0); __nativeRandomFill(a); return a.length; })()") == "0")
    }

    @Test func sendsEachEnvironmentFieldWhenItsJSONValueChanges() throws {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        runtime.start()
        _ = evaluate(runtime, "globalThis.sent = []; globalThis.__svelteEnvironment = (json) => sent.push(json); ''")
        runtime.updateEnvironment(["probe": 1, "insets": ["top": 1]])
        runtime.updateEnvironment(["probe": 1, "insets": ["top": 1]])
        runtime.updateEnvironment(["probe": true, "insets": ["top": 1]])
        runtime.updateEnvironment(["probe": true, "insets": ["top": 2]])
        runtime.settle()
        #expect(
            evaluate(runtime, "JSON.stringify(sent)")
                == #"["{\"insets\":{\"top\":1},\"probe\":1}","{\"probe\":true}","{\"insets\":{\"top\":2}}"]"#)
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
        runtime.reload()
        #expect(evaluate(runtime, query) == "true")
    }

    private func storageRuntime(_ name: String) throws -> SvelteRuntime {
        let url = try #require(Bundle.module.url(forResource: "web", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url, storage: name)
        runtime.start()
        return runtime
    }

    private func saved(_ name: String) -> [String: String] {
        let domain = UserDefaults.standard.persistentDomain(forName: "SvelteSwiftUI.localStorage.\(name)") ?? [:]
        return domain.compactMapValues { $0 as? String }
    }

    @Test func persistsLocalStorageInUserDefaults() async throws {
        let name = "test-\(UUID().uuidString)"
        defer { SvelteRuntime.clearStorage(name) }
        let first = try storageRuntime(name)
        _ = evaluate(first, "localStorage.setItem('kept', 'yes'); localStorage.setItem('gone', 'soon')")
        try await Task.sleep(for: .milliseconds(20))
        #expect(saved(name) == ["kept": "yes", "gone": "soon"])
        let second = try storageRuntime(name)
        #expect(evaluate(second, "localStorage.getItem('kept')") == "yes")
        _ = evaluate(second, "localStorage.setItem('count', 2); localStorage.removeItem('gone')")
        try await Task.sleep(for: .milliseconds(20))
        #expect(saved(name) == ["kept": "yes", "count": "2"])
    }

    @Test func keepsTheKeysThatOtherRuntimesWrite() async throws {
        let name = "test-\(UUID().uuidString)"
        defer { SvelteRuntime.clearStorage(name) }
        let first = try storageRuntime(name)
        let second = try storageRuntime(name)
        _ = evaluate(first, "localStorage.setItem('first', '1')")
        _ = evaluate(second, "localStorage.setItem('second', '2')")
        try await Task.sleep(for: .milliseconds(20))
        #expect(saved(name) == ["first": "1", "second": "2"])
        _ = evaluate(first, "localStorage.clear()")
        try await Task.sleep(for: .milliseconds(20))
        #expect(saved(name) == ["second": "2"])
        let third = try storageRuntime(name)
        #expect(evaluate(third, "JSON.stringify(Object.keys(localStorage))") == #"["second"]"#)
    }

    @Test func separatesLocalStorageByName() async throws {
        let one = "test-\(UUID().uuidString)"
        let other = "test-\(UUID().uuidString)"
        defer {
            SvelteRuntime.clearStorage(one)
            SvelteRuntime.clearStorage(other)
        }
        _ = evaluate(try storageRuntime(one), "localStorage.setItem('mine', 'yes')")
        try await Task.sleep(for: .milliseconds(20))
        #expect(evaluate(try storageRuntime(other), "String(localStorage.getItem('mine'))") == "null")
        #expect(saved(other).isEmpty)
    }

    @Test func namesLocalStorageAfterTheBundleByDefault() throws {
        #expect(SvelteRuntime.storageName(for: URL(filePath: "/app/Resources/app.js")) == "app")
        #expect(SvelteRuntime.storageName(for: try #require(URL(string: "http://localhost:5173/app.js?t=1"))) == "app")
        #expect(SvelteRuntime.storageName(for: URL(filePath: "/app/Resources/settings.js")) == "settings")
    }

    @Test func sendsCookiesOnlyAsTheCredentialsModeAllows() throws {
        let api = try #require(URL(string: "https://api.example.com/v1/me"))
        let other = try #require(URL(string: "https://other.example.com/v1/me"))
        let origin = NetworkClient.origin(of: try #require(URL(string: "https://API.example.com:443/app.js")))
        #expect(origin == "https://api.example.com:443")
        #expect(NetworkClient.origin(of: try #require(URL(string: "file:///app/app.js"))) == nil)
        #expect(NetworkClient.sendsCookies("same-origin", to: api, from: origin))
        #expect(!NetworkClient.sendsCookies("same-origin", to: other, from: origin))
        #expect(!NetworkClient.sendsCookies("same-origin", to: api, from: nil))
        #expect(!NetworkClient.sendsCookies("omit", to: api, from: origin))
        #expect(NetworkClient.sendsCookies("include", to: other, from: nil))
    }

    @Test func namesURLErrorsSoAppsCanTellOfflineFromOtherFailures() {
        func name(_ error: any Error) -> JSONValue? {
            guard case let .object(fields) = NetworkClient.failure(error) else { return nil }
            return fields["name"]
        }
        guard case let .object(refused) = NetworkClient.failure(URLError(.cannotConnectToHost)) else {
            Issue.record("The failure isn't an object")
            return
        }
        #expect(refused["name"] == "cannotConnectToHost")
        #expect(refused["code"] == .number(Double(URLError.cannotConnectToHost.rawValue)))
        #expect(name(URLError(.notConnectedToInternet)) == "notConnectedToInternet")
        #expect(name(URLError(.dnsLookupFailed)) == "dnsLookupFailed")
        #expect(name(URLError(.badURL)) == "unknown")
        #expect(name(CocoaError(.fileNoSuchFile)) == "unknown")
    }
}
