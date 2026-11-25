import XCTest

extension SvelteHostUITests {
    func testRendersNativeComponentsAndCallsNativeModules() {
        tab("Playground")
        let section = app.buttons["Native"]
        scroll(to: section, attempts: 14)
        section.tap()

        let map = app.maps.firstMatch
        scroll(to: map)
        waitFor(map)
        let center = app.staticTexts["map-center"]
        scroll(to: center)
        expectation(for: NSPredicate(format: "label BEGINSWITH 'Map center: 41.7'"), evaluatedWith: center)
        waitForExpectations(timeout: 10)

        app.buttons["Go to Tokyo"].tap()
        expectation(for: NSPredicate(format: "label BEGINSWITH 'Map center: 35.6'"), evaluatedWith: center)
        waitForExpectations(timeout: 10)

        let note = app.buttons["Save a note"]
        scroll(to: note)
        note.tap()
        let saved = app.staticTexts["saved-note"]
        waitFor(saved)
        XCTAssertEqual(saved.label, "Hello from Svelte (hello.txt)")

        app.buttons["Take photo"].tap()
        let status = app.staticTexts["camera-status"]
        waitFor(status)
        XCTAssertEqual(status.label, "This device doesn't have a camera.")
        attachScreenshot("native")
    }
}
