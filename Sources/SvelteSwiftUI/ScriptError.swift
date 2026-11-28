import Foundation
import JavaScriptCore

public nonisolated struct ScriptError: Error, Equatable, Sendable, CustomStringConvertible {
    public enum Kind: Sendable {
        case script
        case bridge
        case load
    }

    public struct Frame: Equatable, Sendable {
        public let function: String
        public let location: String
    }

    public let kind: Kind
    public let message: String
    public let frames: Array<Frame>

    init(kind: Kind = .script, message: String, frames: Array<Frame>) {
        self.kind = kind
        self.message = message
        self.frames = frames
    }

    public var description: String {
        ([message] + frames.map { "  at \($0.function.isEmpty ? "<anonymous>" : $0.function) (\($0.location))" })
            .joined(separator: "\n")
    }
}

nonisolated extension ScriptError {
    init(exception: JSValue, kind: Kind = .script, source: URL, map: SourceMap?) {
        let stack = exception.objectForKeyedSubscript("stack")
        let lines = stack?.isString == true ? stack?.toString().split(separator: "\n").map(String.init) ?? [] : []
        self.init(
            kind: kind,
            message: exception.toString() ?? "Unknown error",
            frames: lines.compactMap { Self.frame($0, source: source, map: map) })
    }

    static func frame(_ line: String, source: URL, map: SourceMap?) -> Frame? {
        guard let at = location(in: line) else {
            return line == "[native code]" ? nil : Frame(function: line, location: "native")
        }
        let function = String(line[..<at])
        let parts = line[line.index(after: at)...].split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, let lineNumber = Int(parts[parts.count - 2]), let column = Int(parts[parts.count - 1])
        else { return Frame(function: function, location: String(line[line.index(after: at)...])) }
        let file = parts.dropLast(2).joined(separator: ":")
        if file == source.absoluteString || file == source.path(percentEncoded: false),
            let mapped = map?.location(line: lineNumber, column: column)
        {
            return Frame(function: function, location: "\(clean(mapped.file)):\(mapped.line):\(mapped.column)")
        }
        let name = file.split(separator: "/").last.map(String.init) ?? file
        return Frame(function: function, location: "\(name):\(lineNumber):\(column)")
    }

    private static func location(in line: String) -> String.Index? {
        var candidate = line.firstIndex(of: "@")
        while let at = candidate {
            let rest = line[line.index(after: at)...]
            if rest.hasPrefix("/") || rest.hasPrefix("[native code]") { return at }
            if let colon = rest.firstIndex(of: ":"), rest[..<colon].first?.isLetter == true,
                rest[..<colon].allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) })
            {
                return at
            }
            candidate = rest.firstIndex(of: "@")
        }
        return line.lastIndex(of: "@")
    }

    private static func clean(_ path: String) -> String {
        if let range = path.range(of: "node_modules/", options: .backwards) { return String(path[range.upperBound...]) }
        var path = Substring(path)
        while path.hasPrefix("../") || path.hasPrefix("./") {
            path = path.dropFirst(path.hasPrefix("../") ? 3 : 2)
        }
        return String(path)
    }
}
