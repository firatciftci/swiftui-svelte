import XCTest

extension SvelteHostUITests {
    func testShowsABundleThatNeverMounts() throws {
        try launch(with: "globalThis.__svelteMount = () => {};")
        let view = app.descendants(matching: .any)["svelte-unresponsive"].firstMatch
        XCTAssertTrue(view.appears(timeout: 6), "The unresponsive view never appeared")
        XCTAssertTrue(app.staticTexts["The app didn't start"].exists)
        let description = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'within two seconds'")).firstMatch
        XCTAssertTrue(description.exists)
        XCTAssertTrue(description.label.contains("doesn't say which swiftui-svelte release built it"))
    }

    func testShowsABundleThatThrowsWhileMounting() throws {
        try launch(with: #"globalThis.__svelteMount = () => { throw new Error("The bundle is broken."); };"#)
        XCTAssertTrue(app.staticTexts["This screen couldn't load"].appears(timeout: 5))
        XCTAssertTrue(app.staticTexts["Error: The bundle is broken."].exists)
        XCTAssertTrue(app.buttons["Reload"].exists)
    }

    private func launch(with script: String) throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
        try script.write(to: url, atomically: true, encoding: .utf8)
        app.terminate()
        app.launchEnvironment["SVELTE_SOURCE"] = url.absoluteString
        app.launch()
    }
}
