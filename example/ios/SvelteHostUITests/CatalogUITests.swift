import XCTest

extension SvelteHostUITests {
    func testOpensEveryCatalogExample() {
        tab("Catalog")
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'catalog-' AND identifier != 'catalog-close'"))
        waitFor(rows.firstMatch)
        let bar = app.tabBars.firstMatch
        let covered = bar.exists ? bar.frame : .null
        var opened = Set<String>()
        var stalled = 0
        while stalled < 2 {
            let next = rows.allElementsBoundByIndex.first {
                !opened.contains($0.identifier) && $0.isHittable && !$0.frame.intersects(covered)
            }
            guard let next else {
                let before = rows.allElementsBoundByIndex.map(\.identifier)
                let window = app.windows.firstMatch
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                    .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
                stalled = rows.allElementsBoundByIndex.map(\.identifier) == before ? stalled + 1 : 0
                continue
            }
            stalled = 0
            let identifier = next.identifier
            opened.insert(identifier)
            next.tap()
            open(identifier)
        }
        XCTAssertEqual(opened.count, 94, "Opened \(opened.sorted())")
    }

    private func open(_ identifier: String) {
        let close = app.buttons["catalog-close"]
        let back = app.navigationBars.buttons["Catalog"]
        let shown = NSPredicate { _, _ in close.exists || back.exists }
        expectation(for: shown, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(close.exists || back.exists, "\(identifier) didn't open")
        XCTAssertFalse(
            app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Unknown element'")).firstMatch.exists,
            "\(identifier) has an unknown element")
        if close.exists {
            close.tap()
        } else {
            back.tap()
        }
        XCTAssertTrue(app.navigationBars["Catalog"].waitForExistence(timeout: 5), "\(identifier) didn't close")
    }
}
