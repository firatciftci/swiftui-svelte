import Foundation
import Synchronization
import Testing

@testable import SvelteSwiftUI

struct DiagnosticsTests {
    @Test func reportsEachDiagnosticOnceWhereverItComesFrom() {
        let reported = Mutex<Array<Diagnostic>>([])
        let diagnostics = Diagnostics { diagnostic, _ in reported.withLock { $0.append(diagnostic) } }
        let unknown = Diagnostic(element: "txt", attribute: "paddng", message: "No paddng.")
        #expect(diagnostics.report(unknown))
        var elsewhere = unknown
        elsewhere.location = "src/App.svelte:4:3"
        #expect(!diagnostics.report(elsewhere))
        #expect(diagnostics.report("No paddng.", element: "vstack", attribute: "paddng"))
        #expect(reported.withLock { $0 } == [unknown, Diagnostic(element: "vstack", attribute: "paddng", message: "No paddng.")])
    }

    @Test func readsDiagnosticsFromJavaScriptAndReportsUnreadableOnes() {
        let reported = Mutex<Array<Diagnostic>>([])
        let diagnostics = Diagnostics { diagnostic, _ in reported.withLock { $0.append(diagnostic) } }
        diagnostics.report(json: #"{"element":"txt","attribute":"class","value":"p-x","message":"Unknown class."}"#)
        diagnostics.report(json: "not json")
        #expect(
            reported.withLock { $0 } == [
                Diagnostic(element: "txt", attribute: "class", value: "p-x", message: "Unknown class."),
                Diagnostic(message: "A development warning from JavaScript couldn't be read: not json"),
            ])
    }

    @Test func reportsAgainAfterAResetUnderANewGeneration() {
        let generations = Mutex<Array<Int>>([])
        let diagnostics = Diagnostics { _, generation in generations.withLock { $0.append(generation) } }
        diagnostics.report("Once.")
        diagnostics.reset()
        #expect(diagnostics.report("Once."))
        #expect(generations.withLock { $0 } == [0, 1])
        #expect(diagnostics.generation == 1)
    }

    @MainActor @Test func collectsTheRuntimesDiagnosticsForTheCurrentBundle() async throws {
        let duplicate = NativeModule("clipboard")
        let runtime = try runtime(
            mountScript + #"__nativeDiagnostic(JSON.stringify({ element: "txt", message: "From the bundle." }));"#,
            modules: [duplicate])
        let expected = [
            Diagnostic(message: "The native module clipboard replaces another module with that name."),
            Diagnostic(element: "txt", message: "From the bundle."),
        ]
        try await eventually { runtime.diagnostics == expected }
        runtime.reload()
        try await eventually { runtime.diagnostics == expected && runtime.loads == 2 }
        runtime.dismissDiagnostics()
        #expect(runtime.diagnostics.isEmpty)
    }
}
