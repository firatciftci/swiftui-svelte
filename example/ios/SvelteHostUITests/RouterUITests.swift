import XCTest

final class RouterUITests: XCTestCase {
    var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: Array<String> = []) {
        app.launchArguments = ["-resetStorage"] + arguments
        app.launch()
    }

    private func waitFor(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), file: file, line: line)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testPushesAScreenAndSwipesBackToTheList() {
        launch()
        let row = app.switches["Render Svelte with SwiftUI"]
        waitFor(row)
        app.buttons.matching(identifier: "Details").element(boundBy: 1).tap()
        waitFor(app.navigationBars["Render Svelte with SwiftUI"])
        attachScreenshot("pushed detail")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end)
        waitFor(row)
        XCTAssertFalse(app.navigationBars["Render Svelte with SwiftUI"].exists)
        attachScreenshot("after swipe back")
    }

    func testOpensADeepLinkedRouteAndPopsIt() {
        launch(["-route", "/todos/2"])
        waitFor(app.navigationBars["Render Svelte with SwiftUI"])
        app.navigationBars.buttons.firstMatch.tap()
        waitFor(app.switches["Render Svelte with SwiftUI"])
    }

    func testShowsTheErrorPageForAMissingTodo() {
        launch(["-route", "/todos/999"])
        waitFor(app.staticTexts["404"])
        waitFor(app.staticTexts["There's no to-do with that ID."])
        attachScreenshot("error page")
    }

    func testShowsADeepLinkedRouteInDarkMode() {
        launch(["-AppleInterfaceStyle", "Dark", "-route", "/todos/2"])
        waitFor(app.navigationBars["Render Svelte with SwiftUI"])
        attachScreenshot("detail dark")
    }
}
