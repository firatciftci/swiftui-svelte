import XCTest

extension SvelteHostUITests {
    func testOpensTheFirstHalfOfTheCatalog() {
        openCatalog(from: 0, to: 48)
    }

    func testOpensTheSecondHalfOfTheCatalog() {
        openCatalog(from: 48)
    }

    private func openCatalog(from start: Int, to end: Int? = nil) {
        tab("Catalog")
        waitFor(app.navigationBars["Catalog"])
        var seen: Array<String> = []
        var opened = 0
        var stalled = 0
        while stalled < 2, end.map({ seen.count < $0 }) ?? true {
            let visible = visibleCatalogRows()
            let fresh = visible.filter { !seen.contains($0) }
            guard !fresh.isEmpty else {
                let window = app.windows.firstMatch
                window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                    .press(forDuration: 0.05, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
                stalled = visibleCatalogRows() == visible ? stalled + 1 : 0
                continue
            }
            stalled = 0
            for identifier in fresh {
                seen.append(identifier)
                guard seen.count > start, end.map({ seen.count <= $0 }) ?? true else { continue }
                app.buttons[identifier].tap()
                open(identifier)
                opened += 1
            }
        }
        if let end {
            XCTAssertEqual(opened, end - start, "Opened \(seen[start...])")
        } else {
            XCTAssertEqual(seen.count, 98, "Found \(seen)")
            XCTAssertEqual(opened, seen.count - start)
        }
    }

    private func visibleCatalogRows() -> Array<String> {
        guard let root = try? app.snapshot() else { return [] }
        var rows: Array<(identifier: String, frame: CGRect)> = []
        var bars: Array<CGRect> = []
        var pending = [root]
        while let node = pending.popLast() {
            switch node.elementType {
            case .navigationBar, .tabBar:
                bars.append(node.frame)
            case .button where node.identifier.hasPrefix("catalog-") && node.identifier != "catalog-close":
                rows.append((node.identifier, node.frame))
            default:
                break
            }
            pending.append(contentsOf: node.children)
        }
        return
            rows
            .filter { row in root.frame.contains(row.frame) && !bars.contains { $0.intersects(row.frame) } }
            .sorted { $0.frame.minY < $1.frame.minY }
            .map(\.identifier)
    }

    private func open(_ identifier: String) {
        let close = app.buttons["catalog-close"]
        let back = app.navigationBars.buttons["Catalog"]
        XCTAssertTrue(soon { close.exists || back.exists }, "\(identifier) didn't open")
        XCTAssertFalse(
            app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Unknown element'")).firstMatch.exists,
            "\(identifier) has an unknown element")
        if close.exists {
            close.tap()
        } else {
            back.tap()
        }
        XCTAssertTrue(app.navigationBars["Catalog"].appears(), "\(identifier) didn't close")
    }

    private func soon(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while !condition() {
            guard Date() < deadline else { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return true
    }
}
