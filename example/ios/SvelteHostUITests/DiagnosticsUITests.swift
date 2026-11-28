import XCTest

extension SvelteHostUITests {
    func testListsDevelopmentWarningsInATrayUntilDismissed() {
        app.terminate()
        app.launchArguments = ["-catalog", "btn"]
        app.launch()
        let tray = app.buttons["svelte-diagnostics"]
        waitFor(tray)
        XCTAssertTrue(tray.label.hasSuffix("warning") || tray.label.hasSuffix("warnings"), tray.label)
        tray.tap()
        let message = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "A <txt> has pressed styles that never apply")
        ).firstMatch
        waitFor(message)
        app.buttons["Hide"].firstMatch.tap()
        XCTAssertTrue(message.disappears())
        tray.tap()
        waitFor(message)
        app.buttons["Dismiss"].firstMatch.tap()
        XCTAssertTrue(tray.disappears())
    }
}
