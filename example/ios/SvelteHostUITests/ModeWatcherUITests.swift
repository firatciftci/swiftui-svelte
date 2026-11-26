import XCTest

extension SvelteHostUITests {
    func testSystemModeFollowsTheDeviceWhileTheAppOverridesIt() {
        let device = ProcessInfo.processInfo.environment["DEVICE_APPEARANCE"] ?? "light"
        app.terminate()
        app.launchArguments = ["-resetStorage", "-catalog", "mode-watcher"]
        app.launch()

        app.buttons["Dark"].tap()
        waitFor(app.staticTexts["The app is showing dark mode."])
        waitFor(app.staticTexts["The device is set to \(device) mode."])

        app.buttons["System"].tap()
        waitFor(app.staticTexts["The app is showing \(device) mode."])
        waitFor(app.staticTexts["The device is set to \(device) mode."])

        let opposite = device == "dark" ? "light" : "dark"
        app.buttons[opposite.capitalized].tap()
        waitFor(app.staticTexts["The app is showing \(opposite) mode."])
        waitFor(app.staticTexts["The device is set to \(device) mode."])
    }
}
