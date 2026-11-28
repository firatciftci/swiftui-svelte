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

    @Test func dedupesByElementAttributeAndValueOrByMessageWithoutAnElement() {
        let diagnostics = Diagnostics()
        #expect(diagnostics.report("Unknown <tx>, did you mean <txt>?", element: "tx"))
        #expect(!diagnostics.report("Unknown <tx>, shown as a red label.", element: "tx"))
        #expect(diagnostics.report("Bad pressed.", element: "tx", attribute: "pressed"))
        #expect(diagnostics.report("The module a replaces another."))
        #expect(diagnostics.report("The module b replaces another."))
        #expect(!diagnostics.report("The module b replaces another."))
    }

    @Test func readsTheSourceLocationThatDevelopmentBuildsStamp() {
        let node = Node(id: 1, kind: .element, name: "txt", text: "")
        #expect(node.location == nil)
        node.attributes = ["data-loc": .string("src/App.svelte:4:3")]
        #expect(node.location == "src/App.svelte:4:3")
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

    @MainActor @Test func reportsColorsSymbolsAndFontsThatTheHostCannotFind() async throws {
        let runtime = try runtime(
            mountScript + """
                attr(2, "color", "blue");
                attr(2, "background", "ultraThinMaterial");
                attr(2, "tint", "rgb(51 102 255)");
                attr(2, "color", "chartreuse-ish");
                attr(2, "symbol", "star.fill");
                attr(2, "symbol", "no.such.symbol");
                attr(2, "fontname", "Helvetica");
                attr(2, "fontname", "NoSuchFont-Regular");
                attr(2, "fontfallbacks", ["Helvetica", "NoSuchFallback"]);
                attr(2, "color", "");
                """)
        let expected = [
            Diagnostic(
                element: "txt", attribute: "color", value: "chartreuse-ish",
                message:
                    "<txt> color=\"chartreuse-ish\" isn't a color or style, so it has no effect. Use a color name such as \"blue\", a system color such as \"systemGray4\", or a CSS color such as \"#3366ff\" or \"rgb(51 102 255)\"."
            ),
            Diagnostic(
                element: "txt", attribute: "symbol", value: "no.such.symbol",
                message:
                    "<txt> symbol=\"no.such.symbol\" isn't an SF Symbol on this OS version, so nothing shows. Check the name in the SF Symbols app, which also lists the OS version each symbol needs."
            ),
            Diagnostic(
                element: "txt", attribute: "fontname", value: "NoSuchFont-Regular",
                message:
                    "<txt> fontname=\"NoSuchFont-Regular\" isn't a font this app has, so it uses the system font instead. Add the font file to the app target, list it under UIAppFonts in Info.plist, and use the font's PostScript name, which Font Book shows."
            ),
            Diagnostic(
                element: "txt", attribute: "fontfallbacks", value: "NoSuchFallback",
                message:
                    "<txt> fontfallbacks=\"NoSuchFallback\" isn't a font this app has, so it uses the system font instead. Add the font file to the app target, list it under UIAppFonts in Info.plist, and use the font's PostScript name, which Font Book shows."
            ),
        ]
        try await eventually { runtime.diagnostics == expected }
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
