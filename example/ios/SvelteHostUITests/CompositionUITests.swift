import XCTest

extension SvelteHostUITests {
    func testComposesJapaneseInAFieldThatTransformsItsText() {
        let field = openCodeField(keyboards: "(\"ja_JP-Romaji@sw=QWERTY-Japanese;hw=Automatic\")")
        for letter in ["k", "a", "n", "a"] { key(letter).tap() }
        XCTAssertEqual(field.value as? String, "かな")
        app.keyboards.buttons["Return"].tap()
        XCTAssertEqual(field.value as? String, "かな")
        key("a").tap()
        app.keyboards.buttons["Return"].tap()
        XCTAssertEqual(field.value as? String, "かなあ")
    }

    func testTransformsTextTypedWithoutAnInputMethod() {
        let field = openCodeField(keyboards: "(\"en_US@sw=QWERTY;hw=Automatic\")")
        field.typeText("abc")
        XCTAssertEqual(field.value as? String, "ABC")
    }

    private func openCodeField(keyboards: String) -> XCUIElement {
        app.terminate()
        app.launchArguments = ["-resetStorage", "-catalog", "textfield", "-AppleKeyboards", keyboards, "-AppleKeyboardsExpanded", "1"]
        app.launch()
        let field = app.textFields["Code"]
        waitFor(field)
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.appears(timeout: 10), "The keyboard never appeared")
        return field
    }

    private func key(_ label: String) -> XCUIElement {
        app.keyboards.keys.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}
