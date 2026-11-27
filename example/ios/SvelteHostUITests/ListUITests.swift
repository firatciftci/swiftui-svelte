import XCTest

extension SvelteHostUITests {
    func testOpensAContextMenuWithAPreview() {
        let row = app.switches["Render Svelte with SwiftUI"]
        waitFor(row)
        XCTAssertEqual(row.value as? String, "0")
        row.press(forDuration: 1.5)
        let markDone = app.buttons["Mark as done"]
        waitFor(markDone)
        XCTAssertTrue(app.buttons["Show details"].exists)
        XCTAssertTrue(app.staticTexts["Not done yet"].exists)
        attachScreenshot("context menu")
        markDone.tap()
        XCTAssertTrue(markDone.disappears(timeout: 5))
        XCTAssertEqual(row.value as? String, "1")
    }

    func testReordersAndDeletesTodosInEditMode() {
        let first = app.switches["Read the custom renderer docs"]
        let second = app.switches["Render Svelte with SwiftUI"]
        waitFor(second)
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
        app.buttons["Edit"].tap()
        let handle = app.buttons["Reorder Render Svelte with SwiftUI"]
        waitFor(handle)
        attachScreenshot("edit mode")
        let target = app.buttons["Reorder Read the custom renderer docs"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.8, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.5)
        let reordered = NSPredicate { _, _ in second.frame.minY < first.frame.minY }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: reordered, object: nil)], timeout: 5), .completed)
        attachScreenshot("reordered")

        app.images.matching(identifier: "minus.circle.fill").firstMatch.tap()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(second.disappears(timeout: 5))
        XCTAssertTrue(app.staticTexts["All done"].exists)
        app.buttons["Done"].tap()
        waitFor(app.buttons["Edit"])
        XCTAssertFalse(app.buttons["Reorder Read the custom renderer docs"].exists)
    }

    func testSelectsProduceAndShowsASectionIndex() {
        tab("Playground")
        let section = app.buttons["Navigation"]
        scroll(to: section)
        section.tap()
        let open = app.buttons["Open a search screen"]
        scroll(to: open)
        open.tap()
        let caption = app.staticTexts["selected-produce"]
        waitFor(caption)
        XCTAssertEqual(caption.label, "Tap a row to select it")
        app.staticTexts["Banana"].tap()
        XCTAssertTrue(caption.waitForLabel("Selected: Banana"), caption.label)
        XCTAssertTrue(app.otherElements["Section index"].exists)
        attachScreenshot("selection and section index")
    }

    func testPullsToRefreshAndWaitsForTheHandler() {
        tab("Playground")
        let label = app.staticTexts["refreshes"]
        waitFor(label)
        XCTAssertEqual(label.label, "Pull down to refresh")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertTrue(label.waitForLabel("Refreshed once", timeout: 10), label.label)
        sleep(1)
        attachScreenshot("after refresh")
        let title = app.navigationBars["Playground"].staticTexts["Playground"]
        XCTAssertGreaterThan(app.staticTexts["Counter"].frame.minY, title.frame.maxY)
    }

    func testRestoresTheTabAndTheOpenTodoAfterRelaunch() {
        waitFor(app.switches["Read the custom renderer docs"])
        app.buttons["Details"].firstMatch.tap()
        let detail = app.navigationBars["Read the custom renderer docs"]
        waitFor(detail)
        app.terminate()
        app.launchArguments = []
        app.launch()
        waitFor(detail)
        app.navigationBars.buttons.firstMatch.tap()
        tab("Settings")
        app.terminate()
        app.launch()
        let settings = app.tabBars.buttons["Settings"]
        waitFor(settings)
        XCTAssertTrue(settings.isSelected)
        tab("To-dos")
        XCTAssertFalse(detail.exists)
    }
}
