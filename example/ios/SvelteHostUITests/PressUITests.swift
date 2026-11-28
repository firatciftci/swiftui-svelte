import XCTest

extension SvelteHostUITests {
    func testPressesATappableElementAndStillTapsIt() {
        app.terminate()
        app.launchArguments = ["-catalog", "gestures"]
        app.launch()
        let card = app.descendants(matching: .any)["press-card"].firstMatch
        let result = app.staticTexts["press-result"]
        waitFor(card)
        let resting = widest(in: result.label)
        XCTAssertGreaterThan(resting, 0, result.label)
        card.tap()
        XCTAssertTrue(result.waitForLabel(containing: "Taps: 1,"), result.label)
        card.press(forDuration: 1)
        XCTAssertTrue(result.waitForLabel(containing: "widest: \(resting + 80)"), result.label)
    }

    private func widest(in label: String) -> Int {
        Int(label.split(separator: " ").last ?? "") ?? 0
    }
}
