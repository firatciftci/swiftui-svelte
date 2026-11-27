import XCTest

extension SvelteHostUITests {
    func testDescribesElementsToAccessibility() {
        tab("Playground")
        let section = app.buttons["Accessibility"]
        scroll(to: section, attempts: 12)
        section.tap()

        let rating = app.descendants(matching: .any)["rating"]
        scroll(to: rating)
        waitFor(rating)
        XCTAssertEqual(rating.label, "Rating")
        XCTAssertEqual(rating.value as? String, "3 of 5 stars")

        let grouped = app.otherElements["grouped"]
        scroll(to: app.buttons["grouped-second"])
        waitFor(grouped)
        XCTAssertEqual(grouped.label, "Grouped controls")
        XCTAssertTrue(grouped.buttons["grouped-first"].exists)
        XCTAssertTrue(grouped.buttons["grouped-second"].exists)
        XCTAssertTrue(grouped.staticTexts["Grouped controls"].exists)
        attachScreenshot("accessibility")
    }
}

extension SvelteHostUITests {
    func testRunsATaskWhileTheElementIsVisible() {
        tab("Playground")
        let section = app.buttons["Lifecycle"]
        scroll(to: section, attempts: 12)
        section.tap()
        let toggle = app.switches["Show the ticker"]
        scroll(to: toggle)
        flip(toggle)
        let ticker = app.staticTexts["ticker"]
        waitFor(ticker)
        let ticking = NSPredicate(format: "label MATCHES 'Ticked ([2-9]|[1-9][0-9]+) times in run 1'")
        expectation(for: ticking, evaluatedWith: ticker)
        waitForExpectations(timeout: 5)

        flip(toggle)
        let status = app.staticTexts["ticker-status"]
        let stopped = NSPredicate(format: "label BEGINSWITH 'Run 1 stopped after'")
        expectation(for: stopped, evaluatedWith: status)
        waitForExpectations(timeout: 5)
        XCTAssertFalse(ticker.exists)

        flip(toggle)
        waitFor(ticker)
        expectation(for: NSPredicate(format: "label ENDSWITH 'in run 2'"), evaluatedWith: ticker)
        waitForExpectations(timeout: 5)
    }
}

extension SvelteHostUITests {
    func testOverridesTheEnvironmentForASubtree() {
        tab("Playground")
        let section = app.buttons["Environment"]
        scroll(to: section, attempts: 12)
        section.tap()
        let large = app.staticTexts["large-text"]
        scroll(to: large)
        waitFor(large)
        XCTAssertGreaterThan(large.frame.height, app.staticTexts["regular-text"].frame.height * 1.5)
        XCTAssertTrue(app.staticTexts["This card always uses dark mode"].exists)
        let glass = app.images["glass-eraser"]
        scroll(to: glass)
        XCTAssertTrue(glass.exists)
        app.buttons["Tap for a success haptic"].tap()
        attachScreenshot("environment")
    }
}
