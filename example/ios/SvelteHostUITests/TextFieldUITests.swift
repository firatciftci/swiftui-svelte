import XCTest

extension SvelteHostUITests {
    func testSavesDebouncedTextTypedJustBeforeATap() {
        app.terminate()
        app.launchArguments = ["-resetStorage", "-catalog", "textfield"]
        app.launch()
        let bio = app.textViews["Bio"].exists ? app.textViews["Bio"] : app.textFields["Bio"]
        waitFor(bio)
        bio.tap()
        bio.typeText("abc")
        app.buttons["Save bio"].tap()
        waitFor(app.staticTexts["Saved bio: abc"])
    }
}
