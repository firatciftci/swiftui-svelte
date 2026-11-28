import XCTest

extension SvelteHostUITests {
    func testSettlesRefusedAndClampedEditsOnTheJavaScriptValue() {
        tab("Playground")
        let inputs = app.buttons["Inputs"]
        for _ in 0..<6 where !inputs.isHittable { app.swipeUp() }
        inputs.tap()
        let stepper = app.steppers["capped-guests"]
        for _ in 0..<8 where !stepper.isHittable { app.swipeUp() }
        let locked = app.switches["locked"]
        XCTAssertEqual(locked.value as? String, "0")
        locked.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        RunLoop.current.run(until: .now + 1)
        XCTAssertEqual(locked.value as? String, "0")
        let slider = app.sliders["capped-volume"]
        slider.adjust(toNormalizedSliderPosition: 1)
        XCTAssertTrue(app.staticTexts["Volume 80%"].appears(timeout: 3))
        RunLoop.current.run(until: .now + 1)
        XCTAssertEqual(slider.normalizedSliderPosition, 0.8, accuracy: 0.05)
        let increment = stepper.buttons.element(boundBy: 1)
        for _ in 0..<4 { increment.tap() }
        XCTAssertTrue(app.staticTexts["4 guests, up to 4"].appears(timeout: 3))
        RunLoop.current.run(until: .now + 1)
        XCTAssertTrue(app.staticTexts["4 guests, up to 4"].exists)
        attachScreenshot("limits")
    }
}
