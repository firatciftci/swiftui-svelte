import XCTest

extension SvelteHostUITests {
    func testShowsTheFailureContentForAnEmptyImageSource() {
        app.terminate()
        app.launchArguments = ["-catalog", "asyncimage"]
        app.launch()
        let errors = app.staticTexts["image-errors"]
        waitFor(errors)
        waitFor(app.descendants(matching: .any)["image-failure"].firstMatch)
        XCTAssertTrue(errors.waitForLabel(containing: "Errors: 1"), errors.label)
        RunLoop.current.run(until: .now.addingTimeInterval(1))
        XCTAssertEqual(errors.label, "Errors: 1")
    }
}
