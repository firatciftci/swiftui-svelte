import XCTest

final class SvelteHostUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-resetStorage"]
        app.launch()
    }

    private func tab(_ title: String) {
        app.tabBars.buttons[title].tap()
    }

    private func waitFor(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) never appeared", file: file, line: line)
    }

    func testAddsTogglesAndDeletesATodo() {
        let field = app.textFields["new-todo"]
        waitFor(field)
        field.tap()
        field.typeText("Buy milk")
        app.buttons["Add"].tap()
        let row = app.switches["Buy milk"]
        waitFor(row)
        XCTAssertEqual(field.value as? String, "New to-do")

        XCTAssertEqual(row.value as? String, "0")
        row.switches.firstMatch.tap()
        XCTAssertEqual(row.value as? String, "1")

        row.swipeLeft()
        app.buttons["Delete"].tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 5))
    }

    func testNavigatesToADetailScreenAndBack() {
        waitFor(app.switches["Render Svelte with SwiftUI"])
        app.buttons.matching(identifier: "Details").element(boundBy: 1).tap()
        waitFor(app.navigationBars["Render Svelte with SwiftUI"])
        let title = app.textFields["Title"]
        title.tap()
        title.typeText("!")
        app.navigationBars.buttons.firstMatch.tap()
        waitFor(app.switches["Render Svelte with SwiftUI!"])
    }

    func testClearsFinishedTodosAfterConfirming() {
        waitFor(app.switches["Read the custom renderer docs"])
        app.buttons["Clear done"].tap()
        let alert = app.alerts["Clear finished to-dos?"]
        waitFor(alert)
        XCTAssertTrue(alert.staticTexts["1 to-do will be removed."].exists)
        alert.buttons["Clear"].tap()
        XCTAssertTrue(app.switches["Read the custom renderer docs"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Clear done"].exists)
    }

    func testCountsGreetsAndPresentsASheet() {
        tab("Playground")
        waitFor(app.staticTexts["0"])
        app.buttons["Increase"].tap()
        app.buttons["Increase"].tap()
        app.buttons["Decrease"].tap()
        waitFor(app.staticTexts["1"])

        let name = app.textFields["Your name"]
        name.tap()
        name.typeText("Ada")
        waitFor(app.staticTexts["Hello, Ada!"])
        name.typeText(" Lovelace, Countess")
        waitFor(app.staticTexts["Hello, Ada Lovelace!"])
        XCTAssertEqual(name.value as? String, "Ada Lovelace")

        app.buttons["Show a sheet"].tap()
        waitFor(app.staticTexts["Hello from a sheet"])
        XCTAssertTrue(app.staticTexts["The counter is at 1."].exists)
        app.buttons["Celebrate"].tap()
        waitFor(app.images["Party popper"])
        app.buttons["Calm down"].tap()
        XCTAssertTrue(app.images["Party popper"].waitForNonExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Hello from a sheet"].waitForNonExistence(timeout: 5))
    }

    func testDrivesEveryFormControl() {
        tab("Settings")
        waitFor(app.staticTexts["3 to-dos a day"])

        app.buttons["Orange"].tap()
        XCTAssertTrue(app.buttons["Orange"].isSelected)

        let stepper = app.steppers.firstMatch
        stepper.buttons["Increment"].tap()
        stepper.buttons["Increment"].tap()
        waitFor(app.staticTexts["5 to-dos a day"])
        stepper.buttons["Decrement"].tap()
        waitFor(app.staticTexts["4 to-dos a day"])
        waitFor(app.staticTexts["1 of 4 done"])

        let slider = app.sliders.firstMatch
        slider.adjust(toNormalizedSliderPosition: 0.2)
        XCTAssertNotEqual(slider.value as? String, "60%")

        let reminder = app.switches["Remind me"]
        reminder.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Repeat"].waitForNonExistence(timeout: 5))
        reminder.switches.firstMatch.tap()
        waitFor(app.staticTexts["Repeat"])

        let repeatMenu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Repeat'")).firstMatch
        XCTAssertEqual(repeatMenu.label, "Repeat, Every day")
        repeatMenu.tap()
        app.buttons["Weekdays"].tap()
        waitFor(app.buttons["Repeat, Weekdays"])

        app.swipeUp()
        app.buttons["Tone"].tap()
        app.buttons["Glass"].tap()
        waitFor(app.buttons["Tone"])
        XCTAssertEqual(app.buttons["Tone"].value as? String, "Glass")

        tab("To-dos")
        waitFor(app.switches["Render Svelte with SwiftUI"])
        XCTAssertTrue(app.tabBars.buttons["To-dos"].isSelected)
    }
}
