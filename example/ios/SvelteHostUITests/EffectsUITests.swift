import XCTest

extension SvelteHostUITests {
    func testAppliesEffectsAndSafeAreaInsets() {
        tab("Playground")
        app.swipeUp()
        let layouts = app.buttons["Layouts"]
        waitFor(layouts)
        settle(layouts)
        layouts.tap()
        let footer = app.staticTexts["Pinned below the rows"]
        scroll(to: footer)

        XCTAssertFalse(app.buttons["disabled-button"].isEnabled)
        let badge = app.staticTexts["badge"]
        waitFor(badge)
        let toggle = app.switches["Hide the badge"]
        flip(toggle)
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: badge)
        waitForExpectations(timeout: 5)

        let scroll = app.scrollViews["inset-scroll"]
        XCTAssertEqual(footer.frame.maxY, scroll.frame.maxY, accuracy: 1)
        let lastRow = app.staticTexts["Row 6"]
        XCTAssertGreaterThan(lastRow.frame.maxY, footer.frame.minY)
        let top = lastRow.frame.minY - scroll.frame.minY
        for _ in 0..<4 where lastRow.frame.maxY > footer.frame.minY + 1 {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(
                    forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.05)),
                    withVelocity: .slow, thenHoldForDuration: 0.2)
            settle(lastRow)
        }
        XCTAssertLessThan(lastRow.frame.minY - scroll.frame.minY, top - 20)
        XCTAssertEqual(footer.frame.maxY, scroll.frame.maxY, accuracy: 1)
        XCTAssertLessThanOrEqual(lastRow.frame.maxY, footer.frame.minY + 1)
        attachScreenshot("effects")
    }
}
