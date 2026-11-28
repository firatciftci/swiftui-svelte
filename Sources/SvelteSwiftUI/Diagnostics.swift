import Foundation
import Synchronization
import os

nonisolated struct Diagnostic: Hashable, Sendable, Decodable {
    var element: String?
    var attribute: String?
    var value: String?
    var location: String?
    let message: String

    var description: String {
        guard let location else { return message }
        return "\(message) (\(location))"
    }
}

nonisolated final class Diagnostics: Sendable {
    static let logger = Logger(subsystem: "swiftui-svelte", category: "diagnostics")
    static let javascript = Logger(subsystem: "swiftui-svelte", category: "javascript")
    static let signposter = OSSignposter(subsystem: "swiftui-svelte", category: .pointsOfInterest)

    static func log(_ message: String, level: String) {
        switch level {
        case "error": javascript.error("\(message, privacy: .public)")
        case "warn": javascript.warning("\(message, privacy: .public)")
        case "debug": javascript.debug("\(message, privacy: .public)")
        case "info": javascript.info("\(message, privacy: .public)")
        default: javascript.notice("\(message, privacy: .public)")
        }
    }

    private struct Key: Hashable {
        let element: String?
        let attribute: String?
        let value: String?
        let message: String?

        init(_ diagnostic: Diagnostic) {
            element = diagnostic.element
            attribute = diagnostic.attribute
            value = diagnostic.value
            message = diagnostic.element == nil ? diagnostic.message : nil
        }
    }

    private struct State {
        var generation = 0
        var seen: Set<Key> = []
    }

    private let state = Mutex(State())
    private let handler = Mutex<(@Sendable (Diagnostic, Int) -> Void)?>(nil)

    init(onReport: (@Sendable (Diagnostic, Int) -> Void)? = nil) {
        handler.withLock { $0 = onReport }
    }

    func onReport(_ onReport: @escaping @Sendable (Diagnostic, Int) -> Void) {
        handler.withLock { $0 = onReport }
    }

    var generation: Int { state.withLock { $0.generation } }

    @discardableResult
    func report(_ diagnostic: Diagnostic) -> Bool {
        let generation: Int? = state.withLock { state in
            state.seen.insert(Key(diagnostic)).inserted ? state.generation : nil
        }
        guard let generation else { return false }
        Self.logger.warning("\(diagnostic.description, privacy: .public)")
        handler.withLock { $0 }?(diagnostic, generation)
        return true
    }

    @discardableResult
    func report(
        _ message: String, element: String? = nil, attribute: String? = nil, value: String? = nil, location: String? = nil
    ) -> Bool {
        report(Diagnostic(element: element, attribute: attribute, value: value, location: location, message: message))
    }

    @discardableResult
    func report(json: String) -> Bool {
        guard let diagnostic = try? JSONDecoder().decode(Diagnostic.self, from: Data(json.utf8)) else {
            return report("A development warning from JavaScript couldn't be read: \(json)")
        }
        return report(diagnostic)
    }

    func reset() {
        state.withLock { state in
            state.generation += 1
            state.seen = []
        }
    }
}
