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

    static func log(_ message: String, level: String) {
        switch level {
        case "error": javascript.error("\(message, privacy: .public)")
        case "warn": javascript.warning("\(message, privacy: .public)")
        case "debug": javascript.debug("\(message, privacy: .public)")
        case "info": javascript.info("\(message, privacy: .public)")
        default: javascript.notice("\(message, privacy: .public)")
        }
    }

    private struct State {
        var generation = 0
        var seen: Set<Diagnostic> = []
    }

    private let state = Mutex(State())
    private let onReport: @Sendable (Diagnostic, Int) -> Void

    init(onReport: @escaping @Sendable (Diagnostic, Int) -> Void = { _, _ in }) {
        self.onReport = onReport
    }

    var generation: Int { state.withLock { $0.generation } }

    @discardableResult
    func report(_ diagnostic: Diagnostic) -> Bool {
        var key = diagnostic
        key.location = nil
        let generation: Int? = state.withLock { state in
            state.seen.insert(key).inserted ? state.generation : nil
        }
        guard let generation else { return false }
        Self.logger.warning("\(diagnostic.description, privacy: .public)")
        onReport(diagnostic, generation)
        return true
    }

    @discardableResult
    func report(_ message: String, element: String? = nil, attribute: String? = nil, value: String? = nil) -> Bool {
        report(Diagnostic(element: element, attribute: attribute, value: value, message: message))
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
