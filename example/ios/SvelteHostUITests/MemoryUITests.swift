import XCTest

extension SvelteHostUITests {
    func testLongListsKeepMemoryFlatWhileScrolling() {
        tab("Playground")
        let section = app.buttons["Navigation"]
        scroll(to: section)
        section.tap()
        for title in ["Open 10,000 rows in a list", "Open 10,000 rows in a lazy stack"] {
            let open = app.buttons[title]
            scroll(to: open)
            open.tap()
            let label = app.staticTexts.matching(NSPredicate(format: "label == 'Not measured' OR label ENDSWITH ' MB'")).firstMatch
            if !label.waitForExistence(timeout: 60) {
                print(app.debugDescription)
                XCTFail("The memory label never appeared")
                return
            }
            app.buttons["Scroll through 3,000 rows"].tap()
            let measured = NSPredicate { _, _ in label.label.contains("→") }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: measured, object: nil)], timeout: 120), .completed)
            let values = label.label.dropLast(3).components(separatedBy: " → ").compactMap(Double.init)
            attachScreenshot("\(title) after scrolling")
            XCTAssertTrue(app.staticTexts["Row 3000"].exists, "\(title) didn't scroll")
            XCTAssertEqual(values.count, 3)
            if values.count == 3 {
                XCTAssertLessThan(values[0], 500, "\(title) took \(values[0]) MB to open")
                XCTAssertLessThan(values[2] - values[1], 80, "\(title) grew from \(values[1]) MB to \(values[2]) MB")
            }
            app.navigationBars.buttons["Playground"].tap()
            waitFor(section)
        }
    }
}
