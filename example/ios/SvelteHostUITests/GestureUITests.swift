import XCTest

extension SvelteHostUITests {
    func testHandlesTapsPressesDragsPinchesAndRotations() {
        tab("Playground")
        let section = app.buttons["Gestures"]
        scroll(to: section, attempts: 12)
        section.tap()
        let card = app.descendants(matching: .any)["gesture-card"].firstMatch
        let caption = app.staticTexts["last-gesture"]
        scroll(to: caption)
        waitFor(card)
        XCTAssertEqual(caption.label, "Last gesture: none yet")

        func expectGesture(_ prefix: String) {
            let predicate = NSPredicate(format: "label BEGINSWITH %@", "Last gesture: \(prefix)")
            expectation(for: predicate, evaluatedWith: caption)
            waitForExpectations(timeout: 5)
        }

        card.doubleTap()
        expectGesture("double tap at ")
        card.press(forDuration: 1.2)
        expectGesture("long press")
        let center = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.1, thenDragTo: card.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        expectGesture("drag by ")
        card.pinch(withScale: 2, velocity: 1)
        expectGesture("pinch to ")
        card.rotate(.pi / 4, withVelocity: 1)
        expectGesture("rotation by ")
        attachScreenshot("gestures")
    }
}
