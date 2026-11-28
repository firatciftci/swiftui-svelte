import XCTest

extension XCUIElement {
    func appears(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !exists, Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return exists
    }

    func disappears(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while exists, Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return !exists
    }

    func waitForLabel(_ label: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while self.label != label, Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return self.label == label
    }

    func waitForLabel(containing text: String, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !label.contains(text), Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return label.contains(text)
    }

    func waitForHittable(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while !isHittable, Date.now < deadline { RunLoop.current.run(until: .now.addingTimeInterval(0.1)) }
        return isHittable
    }
}
