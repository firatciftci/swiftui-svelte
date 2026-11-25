import XCTest

final class SvelteHostUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["-resetStorage"]
        app.launch()
    }

    private func tab(_ title: String) {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            app.tabBars.buttons[title].tap()
            return
        }
        let cell = app.cells.containing(.staticText, identifier: title).firstMatch
        if !cell.exists || !cell.isHittable { app.buttons["ToggleSideBar"].firstMatch.tap() }
        cell.tap()
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

    func testKeepsTheKeyboardUpAndScrollsToNewTodos() {
        let field = app.textFields["new-todo"]
        waitFor(field)
        field.tap()
        let cleared = NSPredicate(format: "value == 'New to-do'")
        for index in 1...10 {
            field.typeText("Errand \(index)\n")
            let submitted = XCTNSPredicateExpectation(predicate: cleared, object: field)
            XCTAssertEqual(XCTWaiter.wait(for: [submitted], timeout: 5), .completed, "Errand \(index) wasn't added")
        }
        waitFor(app.switches["Errand 1"])
        XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true)

        field.typeText("Errand 11")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let last = app.switches["Errand 11"]
        waitFor(last)
        let deadline = Date().addingTimeInterval(5)
        while !last.isHittable, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.2)) }
        XCTAssertTrue(last.isHittable)
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

    func testOpensDeepLinksAndNoticesReturns() throws {
        tab("Playground")
        waitFor(app.staticTexts["Counter"])
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        waitFor(app.staticTexts["Welcome back. You've come back once."])

        app.open(try XCTUnwrap(URL(string: "sveltehost://todos/2")))
        waitFor(app.navigationBars["Render Svelte with SwiftUI"])
        XCTAssertTrue(app.tabBars.buttons["To-dos"].isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        waitFor(app.switches["Render Svelte with SwiftUI"])

        app.terminate()
        app.open(try XCTUnwrap(URL(string: "sveltehost://todos/2")))
        waitFor(app.navigationBars["Render Svelte with SwiftUI"])
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
        XCTAssertEqual(app.progressIndicators.firstMatch.value as? String, "10%")
        attachScreenshot("playground")

        let name = app.textFields["Your name"]
        name.tap()
        name.typeText("Ada")
        waitFor(app.staticTexts["Hello, Ada!"])
        waitFor(app.staticTexts.matching(NSPredicate(format: "label MATCHES 'Keyboard: [1-9][0-9]* pt'")).firstMatch)
        name.typeText(" Lovelace, Countess")
        waitFor(app.staticTexts["Hello, Ada Lovelace!"])
        XCTAssertEqual(name.value as? String, "Ada Lovelace")
        app.buttons["Done editing"].tap()
        XCTAssertTrue(app.buttons["Done editing"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))

        XCTAssertTrue(app.images["Verified"].exists)
        app.buttons["Show a sheet"].tap()
        waitFor(app.staticTexts["Hello from a sheet"])
        XCTAssertTrue(app.staticTexts["The counter is at 1."].exists)
        XCTAssertTrue(app.staticTexts["Rendered by Svelte as native SwiftUI."].exists)
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

        app.swipeUp()
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

        app.swipeUp()
        waitFor(app.staticTexts["This device"])
        XCTAssertTrue(app.staticTexts["large"].exists)
        XCTAssertTrue(app.staticTexts["light"].exists)
        XCTAssertTrue(app.staticTexts["leftToRight"].exists)
        XCTAssertTrue(app.staticTexts["compact"].exists)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label MATCHES '[1-9][0-9]* pt top, [1-9][0-9]* pt bottom'")).firstMatch.exists)
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label MATCHES '[1-9][0-9]* × [1-9][0-9]* pt'")).firstMatch.exists)

        tab("To-dos")
        waitFor(app.switches["Render Svelte with SwiftUI"])
        XCTAssertTrue(app.tabBars.buttons["To-dos"].isSelected)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFollowsTheDeviceLanguageAndDirection() {
        app.terminate()
        app.launchArguments = ["-resetStorage", "-AppleLanguages", "(ar)", "-AppleLocale", "ar_EG"]
        app.launch()
        tab("الإعدادات")
        waitFor(app.staticTexts["3 مهام في اليوم"])
        let label = app.staticTexts["3 مهام في اليوم"]
        let stepper = app.steppers.firstMatch
        XCTAssertGreaterThan(label.frame.minX, stepper.buttons.firstMatch.frame.minX)
        attachScreenshot("device-arabic")
        app.swipeUp()
        app.swipeUp()
        waitFor(app.staticTexts["rightToLeft"])
        XCTAssertTrue(app.staticTexts["ar-EG"].exists)
    }

    func testSwitchesLanguageInTheApp() {
        tab("Settings")
        let stepper = app.steppers.firstMatch
        waitFor(app.staticTexts["3 to-dos a day"])
        XCTAssertLessThan(app.staticTexts["3 to-dos a day"].frame.minX, stepper.buttons.firstMatch.frame.minX)

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Language'")).firstMatch.tap()
        app.buttons["العربية"].tap()
        waitFor(app.tabBars.buttons["الإعدادات"])
        let label = app.staticTexts["3 مهام في اليوم"]
        waitFor(label)
        XCTAssertGreaterThan(label.frame.minX, stepper.buttons.firstMatch.frame.minX)
        attachScreenshot("in-app-arabic")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'اللغة'")).firstMatch.tap()
        app.buttons["لغة الجهاز"].tap()
        waitFor(app.tabBars.buttons["Settings"])
        waitFor(app.staticTexts["3 to-dos a day"])
    }

    func testExpandsLayouts() {
        tab("Playground")
        app.swipeUp()
        let layouts = app.buttons["Layouts"]
        waitFor(layouts)
        XCTAssertFalse(app.staticTexts["lazyvstack"].exists)
        layouts.tap()
        waitFor(app.staticTexts["lazyvstack"])
        app.swipeUp()
        for number in 1...10 { XCTAssertTrue(app.staticTexts["\(number)"].exists, "swatch \(number)") }
        XCTAssertTrue(app.staticTexts["Content inside a GroupBox."].exists)
        let long = app.staticTexts["This whole sentence shows when it fits on one line."]
        let short = app.staticTexts["A shorter fallback"]
        XCTAssertNotEqual(long.exists, short.exists)
        let eager = app.staticTexts["vstack"].frame
        let lazy = app.staticTexts["lazyvstack"].frame
        XCTAssertEqual(eager.midY, lazy.midY, accuracy: 1)
        XCTAssertLessThan(eager.maxX, lazy.minX)

        let caption = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Scrolled'")).firstMatch
        waitFor(caption)
        XCTAssertTrue(caption.label.hasPrefix("Scrolled 0 pt across a "))
        XCTAssertFalse(caption.label.hasSuffix(" 0 pt carousel"))
        app.staticTexts["Card 2"].swipeLeft()
        let scrolled = NSPredicate(format: "NOT (label BEGINSWITH 'Scrolled 0 pt')")
        expectation(for: scrolled, evaluatedWith: caption)
        waitForExpectations(timeout: 5)
        attachScreenshot("layouts")
    }

    func testShowsImagesSymbolsAndLinks() {
        tab("Playground")
        app.swipeUp()
        let content = app.buttons["Content"]
        waitFor(content)
        content.tap()
        waitFor(app.images["swiftui-svelte logo"])
        app.swipeUp()
        XCTAssertTrue(app.images["Wi-Fi at half strength"].exists)
        XCTAssertTrue(app.images["Bell"].exists)
        app.buttons["Ring the bell"].tap()
        XCTAssertTrue(app.staticTexts["Inbox"].exists)
        XCTAssertTrue(app.links["Svelte docs"].exists)
        XCTAssertTrue(app.buttons["Share this project"].exists)
        app.swipeUp()
        attachScreenshot("content")
        let caption = app.staticTexts["The image didn't load, so its failure view is showing."]
        XCTAssertTrue(caption.waitForExistence(timeout: 15), "the failure caption never appeared")
        XCTAssertTrue(app.images["Image failed to load"].exists)
    }
}

extension SvelteHostUITests {
    func testEditsInputs() {
        tab("Playground")
        let inputs = app.buttons["Inputs"]
        for _ in 0..<6 where !inputs.isHittable { app.swipeUp() }
        inputs.tap()
        let repeatButton = app.buttons["Hold to repeat"]
        for _ in 0..<6 where !repeatButton.isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["Glass"].exists)
        XCTAssertTrue(app.buttons["Prominent glass"].exists)
        repeatButton.press(forDuration: 2)
        attachScreenshot("buttons")
        let repeats = app.staticTexts["repeats"].label
        let count = Int(repeats.split(separator: " ")[1]) ?? 0
        XCTAssertGreaterThan(count, 2, repeats)
        let favorite = app.switches["favorite"]
        XCTAssertEqual(favorite.value as? String, "0")
        favorite.staticTexts["Favorite"].tap()
        XCTAssertEqual(favorite.value as? String, "1")
        XCTAssertTrue(app.images["star.fill"].exists)
        let email = app.textFields["email"]
        email.tap()
        email.typeText("ada@example.com\n")
        XCTAssertEqual(email.value as? String, "ada@example.com")
        let password = app.secureTextFields["password"]
        password.tap()
        password.typeText("hunter2\n")
        XCTAssertNotEqual(password.value as? String, "hunter2")
        XCTAssertEqual((password.value as? String)?.count, 7)
        let price = app.textFields["price"]
        price.tap()
        price.typeText("12.5\n")
        XCTAssertTrue(app.staticTexts["Price: 12.5"].waitForExistence(timeout: 3))
        for _ in 0..<3 where !app.textViews["journal"].isHittable { app.swipeUp() }
        let journal = app.textViews["journal"]
        journal.tap()
        journal.typeText("Hello")
        XCTAssertTrue(app.staticTexts["5 characters"].waitForExistence(timeout: 3))
        attachScreenshot("inputs")
    }

    private func dismissSheet(from element: XCUIElement? = nil) {
        let start =
            element?.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
            ?? app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
    }

    private func scroll(to element: XCUIElement, attempts: Int = 8) {
        for _ in 0..<attempts where !element.isHittable { app.swipeUp() }
    }

    func testPicksAndOpensMenus() {
        tab("Playground")
        let section = app.buttons["Pickers and menus"]
        scroll(to: section)
        section.tap()
        let toppings = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Toppings'")).firstMatch
        scroll(to: toppings, attempts: 3)
        toppings.tap()
        let olives = app.buttons["Olives"]
        waitFor(olives)
        XCTAssertTrue(app.buttons["Cheese"].isSelected)
        XCTAssertFalse(olives.isSelected)
        olives.tap()
        XCTAssertTrue(olives.isSelected)
        attachScreenshot("multiple selection")
        app.navigationBars.buttons.firstMatch.tap()
        waitFor(app.staticTexts["Cheese and Olives"])

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sides'")).firstMatch.tap()
        waitFor(app.buttons["Salad"])
        app.buttons["Salad"].tap()
        app.buttons["Soup"].tap()
        attachScreenshot("menu selection")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        waitFor(app.staticTexts["Salad and Soup"])

        let actions = app.buttons["actions-menu"]
        scroll(to: actions, attempts: 3)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '1.0.0'")).firstMatch.exists)
        actions.tap()
        waitFor(app.buttons["Copy"])
        attachScreenshot("menu")
        app.buttons["Copy"].tap()
        waitFor(app.staticTexts["Last action: Copy"])
        actions.tap()
        app.buttons["Share"].tap()
        waitFor(app.buttons["Mail"])
        app.buttons["Mail"].tap()
        waitFor(app.staticTexts["Last action: Mail"])

        let add = app.buttons["Add"]
        add.tap()
        waitFor(app.staticTexts["Last action: Add"])
        add.press(forDuration: 1)
        waitFor(app.buttons["Photo"])
        app.buttons["Photo"].tap()
        waitFor(app.staticTexts["Last action: Photo"])

        let day = app.buttons.matching(NSPredicate(format: "label CONTAINS ' 15'")).firstMatch
        scroll(to: day, attempts: 4)
        day.tap()
        XCTAssertTrue(day.isSelected)
        let browse = app.buttons["Browse items"]
        scroll(to: browse, attempts: 4)
        XCTAssertEqual(app.staticTexts["delivery-days"].label, "1 day picked")
        XCTAssertTrue(app.staticTexts["No favorites"].exists)
        attachScreenshot("pickers and menus")
    }

    func testShowsEveryPresentation() {
        tab("Playground")
        let section = app.buttons["Presentations"]
        scroll(to: section)
        section.tap()
        let coverButton = app.buttons["Show a full-screen cover"]
        scroll(to: app.buttons["Show a short sheet"], attempts: 3)

        coverButton.tap()
        let coverTitle = app.staticTexts["A full-screen cover"]
        waitFor(coverTitle)
        coverTitle.swipeDown()
        XCTAssertTrue(coverTitle.exists, "a swipe closed the full-screen cover")
        attachScreenshot("full-screen cover")
        app.buttons["Close"].tap()
        XCTAssertTrue(coverTitle.waitForNonExistence(timeout: 5))

        app.buttons["Show a popover"].tap()
        let popoverText = app.staticTexts["Popovers point at the button that opened them."]
        waitFor(popoverText)
        attachScreenshot("popover")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(popoverText.waitForNonExistence(timeout: 5))
        app.buttons["Show a popover"].tap()
        waitFor(popoverText)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(popoverText.waitForNonExistence(timeout: 5))

        app.buttons["Show the inspector"].tap()
        let inspectorText = app.staticTexts["On iPad, this opens as a column beside the content."]
        waitFor(inspectorText)
        attachScreenshot("inspector")
        dismissSheet()
        XCTAssertTrue(inspectorText.waitForNonExistence(timeout: 5))

        app.buttons["Delete all photos"].tap()
        let delete = app.buttons["Delete"]
        waitFor(delete)
        attachScreenshot("confirmation dialog")
        delete.tap()
        waitFor(app.staticTexts["Photos deleted"])

        app.buttons["Show a short sheet"].tap()
        let sheetText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Drag the handle'")).firstMatch
        waitFor(sheetText)
        XCTAssertTrue(sheetText.label.hasSuffix("You can still use the list behind it."), sheetText.label)
        attachScreenshot("short sheet")
        XCTAssertTrue(app.buttons["Show a full-screen cover"].isHittable, "the list behind the short sheet isn't usable")
        dismissSheet(from: sheetText)
        XCTAssertTrue(sheetText.waitForNonExistence(timeout: 5))
    }

    func testNavigatesWithToolbarsAndPages() {
        XCTAssertEqual(app.tabBars.buttons["To-dos"].value as? String, "1 item")
        tab("Playground")
        let section = app.buttons["Navigation"]
        scroll(to: section)
        section.tap()
        let open = app.buttons["Open a screen with toolbars"]
        let carousel = app.collectionViews["carousel"]
        scroll(to: carousel, attempts: 3)
        waitFor(carousel.staticTexts["First"])
        carousel.swipeLeft()
        XCTAssertTrue(app.pageIndicators["carousel"].waitForExistence(timeout: 5))
        XCTAssertTrue(carousel.staticTexts["Second"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.pageIndicators["carousel"].value as? String, "page 2 of 3")
        attachScreenshot("page carousel")
        carousel.swipeLeft()
        XCTAssertTrue(carousel.staticTexts["Third"].waitForExistence(timeout: 5))
        carousel.swipeRight()
        carousel.swipeRight()
        XCTAssertTrue(carousel.staticTexts["First"].waitForExistence(timeout: 5))

        open.tap()
        let page = app.staticTexts["page"]
        waitFor(page)
        XCTAssertTrue(app.navigationBars["Toolbars"].staticTexts["Items in every placement"].exists)
        XCTAssertFalse(app.tabBars.buttons["Playground"].isHittable, "the tab bar covers the bottom toolbar")
        app.buttons["Next page"].tap()
        app.buttons["Next page"].tap()
        app.buttons["Next page"].tap()
        XCTAssertEqual(page.label, "Page 3 of 3")
        app.buttons["Previous page"].tap()
        XCTAssertEqual(page.label, "Page 2 of 3")

        let action = app.staticTexts["bar-action"]
        app.buttons["toolbar-menu"].tap()
        app.buttons["Rename"].tap()
        XCTAssertEqual(action.label, "Last action: Rename")
        app.buttons.matching(NSPredicate(format: "identifier ENDSWITH %@", "OverflowBarButtonItem")).firstMatch.tap()
        app.buttons["Pin"].tap()
        XCTAssertEqual(action.label, "Last action: Pin")
        attachScreenshot("toolbars")

        app.switches["Hide the navigation bar"].switches.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Toolbars"].waitForNonExistence(timeout: 5))
        attachScreenshot("hidden navigation bar")
        app.switches["Hide the navigation bar"].switches.firstMatch.tap()
        waitFor(app.navigationBars["Toolbars"])
        app.switches["Hide the back button"].switches.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Toolbars"].buttons["BackButton"].waitForNonExistence(timeout: 5))
        app.switches["Color the navigation bar"].switches.firstMatch.tap()
        attachScreenshot("colored navigation bar without a back button")
        app.switches["Hide the back button"].switches.firstMatch.tap()
        waitFor(app.navigationBars["Toolbars"].buttons["BackButton"])
        app.switches["Hide the tab bar"].switches.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Playground"].waitForHittable())

        app.navigationBars["Toolbars"].buttons["BackButton"].tap()
        waitFor(open)
        XCTAssertFalse(app.navigationBars["Toolbars"].exists)
    }

    private func cancelSearch() {
        app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancel", "Close"])).firstMatch.tap()
    }

    func testSearchesTodosWithScopes() {
        let search = app.searchFields["Search to-dos"]
        waitFor(search)
        search.tap()
        search.typeText("svelte")
        let open = app.switches["Render Svelte with SwiftUI"]
        let done = app.switches["Read the custom renderer docs"]
        waitFor(open)
        XCTAssertTrue(done.waitForNonExistence(timeout: 5))
        attachScreenshot("search with scopes")
        search.buttons["Clear text"].tap()
        waitFor(done)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(open.waitForNonExistence(timeout: 5))
        XCTAssertTrue(done.exists)
        search.typeText("zzz")
        waitFor(app.staticTexts["No Results for “zzz”"])
        attachScreenshot("no results")
        cancelSearch()
        waitFor(open)
        XCTAssertTrue(done.exists)
    }

    func testSearchesWithTokensAndSuggestions() {
        tab("Playground")
        let section = app.buttons["Navigation"]
        scroll(to: section)
        section.tap()
        let open = app.buttons["Open a search screen"]
        scroll(to: open)
        open.tap()
        let state = app.staticTexts["search-state"]
        waitFor(state)
        XCTAssertEqual(state.label, "Not searching · No search yet")
        let search = app.searchFields["Fruits and vegetables"]
        search.tap()
        XCTAssertTrue(state.label.hasPrefix("Searching"), state.label)
        attachScreenshot("suggested tokens")
        app.buttons["Vegetable"].firstMatch.tap()
        waitFor(app.staticTexts["Carrot"])
        XCTAssertEqual(state.label, "Searching · Last search: Vegetable", "picking a suggestion submits the search")
        XCTAssertFalse(app.staticTexts["Apple"].exists)
        search.typeText("le")
        attachScreenshot("completions")
        app.buttons["Lettuce"].firstMatch.tap()
        XCTAssertTrue((search.value as? String)?.hasSuffix("Lettuce") == true, "\(search.value ?? "")")
        search.typeText("\n")
        XCTAssertEqual(state.label, "Searching · Last search: Vegetable Lettuce")
        attachScreenshot("submitted search")
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Lettuce".count + 1))
        waitFor(app.staticTexts["Apple"])
        XCTAssertEqual(search.value as? String, "Fruits and vegetables")
        cancelSearch()
        XCTAssertTrue(state.waitForLabel("Not searching · Last search: Vegetable Lettuce"), state.label)
    }

    func testShowsTabSectionsInTheSidebar() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "the sidebar only shows on iPad")
        let tabBar = app.otherElements.containing(.button, identifier: "ToggleSideBar").firstMatch
        waitFor(tabBar.buttons["Examples"])
        attachScreenshot("tab bar with a section")
        app.buttons["ToggleSideBar"].firstMatch.tap()
        let playground = app.cells.containing(.staticText, identifier: "Playground").firstMatch
        waitFor(playground)
        XCTAssertTrue(app.staticTexts["Examples"].exists)
        attachScreenshot("sidebar")
        playground.tap()
        waitFor(app.navigationBars["Playground"])
        XCTAssertTrue(tabBar.buttons["Examples"].firstMatch.isSelected)
    }

    func testBrowsesASplitView() {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        tab("Playground")
        let section = app.buttons["Navigation"]
        scroll(to: section)
        section.tap()
        let open = app.buttons["Open a split view"]
        scroll(to: open, attempts: 3)
        open.tap()

        let showSidebar = app.buttons["Show Sidebar"]
        if isPad {
            waitFor(app.staticTexts["No mailbox selected"])
            XCTAssertEqual(app.staticTexts["split-state"].label, "doubleColumn sidebar")
            attachScreenshot("split view")
            showSidebar.tap()
        }
        waitFor(app.navigationBars["Mailboxes"])
        attachScreenshot("split view sidebar")
        app.buttons["Inbox"].tap()
        waitFor(app.navigationBars["Inbox"])
        if isPad {
            app.staticTexts["No message selected"].tap()
            XCTAssertTrue(app.navigationBars["Mailboxes"].waitForNonExistence(timeout: 5))
        }
        app.buttons["Lunch on Friday?"].tap()
        let body = app.staticTexts["message-body"]
        waitFor(body)
        XCTAssertEqual(body.label, "There's a new place by the park. Want to try it at noon?")
        attachScreenshot("split view message")

        if isPad {
            XCTAssertTrue(app.navigationBars["Inbox"].exists, "the message hid its mailbox")
            if !app.buttons["Archive"].isHittable { showSidebar.tap() }
        } else {
            app.navigationBars["Lunch on Friday?"].buttons["BackButton"].tap()
            waitFor(app.buttons["Your order has shipped"])
            app.navigationBars["Inbox"].buttons["BackButton"].tap()
            waitFor(app.buttons["Archive"])
        }
        app.buttons["Archive"].tap()
        waitFor(app.buttons["Trip photos"])
        if isPad {
            if !app.buttons["Done"].isHittable { showSidebar.tap() }
        } else {
            app.navigationBars["Archive"].buttons["BackButton"].tap()
            waitFor(app.navigationBars["Mailboxes"])
        }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Mailboxes"].waitForNonExistence(timeout: 5))
        waitFor(open)
    }
}

extension XCUIElement {
    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while self.label != label, Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return self.label == label
    }

    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !isHittable, Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return isHittable
    }
}
