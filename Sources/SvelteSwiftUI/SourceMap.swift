import Foundation

nonisolated struct MappedLocation: Equatable, Sendable {
    let file: String
    let line: Int
    let column: Int
}

nonisolated struct SourceMap: Sendable {
    private struct Segment {
        let column: Int
        let source: Int
        let line: Int
        let sourceColumn: Int
    }

    private struct Payload: Decodable {
        let sources: Array<String>
        let sourceRoot: String?
        let mappings: String
    }

    private let sources: Array<String>
    private let lines: Array<Array<Segment>>

    init(json: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: json)
        let root = payload.sourceRoot.map { $0.isEmpty || $0.hasSuffix("/") ? $0 : $0 + "/" } ?? ""
        sources = payload.sources.map { root + $0 }
        lines = try Self.decode(payload.mappings, sourceCount: sources.count)
    }

    private static let base64: Array<Int> = {
        var table = Array(repeating: -1, count: 128)
        for (index, character) in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8.enumerated() {
            table[Int(character)] = index
        }
        return table
    }()

    private static func decode(_ mappings: String, sourceCount: Int) throws -> Array<Array<Segment>> {
        var lines: Array<Array<Segment>> = [[]]
        var fields: Array<Int> = []
        var value = 0
        var shift = 0
        var source = 0
        var line = 0
        var sourceColumn = 0
        var column = 0

        func finishSegment() {
            if fields.count >= 4 {
                column += fields[0]
                source += fields[1]
                line += fields[2]
                sourceColumn += fields[3]
                if source >= 0, source < sourceCount {
                    lines[lines.count - 1].append(
                        Segment(column: column, source: source, line: line, sourceColumn: sourceColumn))
                }
            } else if let delta = fields.first {
                column += delta
            }
            fields.removeAll(keepingCapacity: true)
        }

        for byte in mappings.utf8 {
            switch byte {
            case UInt8(ascii: ","):
                finishSegment()
            case UInt8(ascii: ";"):
                finishSegment()
                lines.append([])
                column = 0
            default:
                let digit = byte < 128 ? base64[Int(byte)] : -1
                guard digit >= 0 else { throw BridgeError(description: "Invalid source map character") }
                guard shift <= 30 else { throw BridgeError(description: "Source map value too large") }
                value += (digit & 31) << shift
                guard value <= Int(UInt32.max) else { throw BridgeError(description: "Source map value too large") }
                if digit & 32 != 0 {
                    shift += 5
                } else {
                    fields.append(value & 1 == 1 ? -(value >> 1) : value >> 1)
                    value = 0
                    shift = 0
                }
            }
        }
        finishSegment()
        return lines
    }

    func location(line: Int, column: Int) -> MappedLocation? {
        guard line >= 1, line <= lines.count else { return nil }
        let segments = lines[line - 1]
        var low = 0
        var high = segments.count
        while low < high {
            let middle = (low + high) / 2
            if segments[middle].column <= column - 1 { low = middle + 1 } else { high = middle }
        }
        guard low > 0 else { return nil }
        let segment = segments[low - 1]
        return MappedLocation(file: sources[segment.source], line: segment.line + 1, column: segment.sourceColumn + 1)
    }
}
