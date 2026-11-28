import Foundation
import Testing

@testable import SvelteSwiftUI

struct SourceMapTests {
    private func fixture(_ name: String) throws -> URL {
        try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    }

    private func map() throws -> SourceMap {
        try SourceMap(json: Data(contentsOf: fixture("sourcemap.js.map")))
    }

    @Test(arguments: [
        (6, 20, MappedLocation(file: "../src/app.ts", line: 4, column: 5)),
        (6, 26, MappedLocation(file: "../src/app.ts", line: 4, column: 11)),
        (6, 29, MappedLocation(file: "../src/app.ts", line: 4, column: 11)),
        (6, 30, MappedLocation(file: "../src/app.ts", line: 4, column: 15)),
        (4, 2, MappedLocation(file: "../src/app.ts", line: 1, column: 1)),
        (9, 2, MappedLocation(file: "../src/app.ts", line: 9, column: 1)),
    ])
    func mapsGeneratedPositions(line: Int, column: Int, expected: MappedLocation) throws {
        #expect(try map().location(line: line, column: column) == expected)
    }

    @Test(arguments: [(1, 1), (6, 1), (0, 5), (99, 1)])
    func returnsNothingOutsideTheMappings(line: Int, column: Int) throws {
        #expect(try map().location(line: line, column: column) == nil)
    }

    @Test func appliesTheSourceRoot() throws {
        let map = try SourceMap(json: Data(#"{"version":3,"sourceRoot":"root","sources":["a.ts"],"mappings":"AAAA"}"#.utf8))
        #expect(map.location(line: 1, column: 1) == MappedLocation(file: "root/a.ts", line: 1, column: 1))
    }

    @Test func rejectsInvalidMappings() {
        #expect(throws: (any Error).self) { try SourceMap(json: Data(#"{"version":3,"sources":[],"mappings":"!"}"#.utf8)) }
        #expect(throws: (any Error).self) { try SourceMap(json: Data("{}".utf8)) }
    }

    @Test func mapsStackFramesFromTheBundle() throws {
        let source = URL(filePath: "/app/app.js")
        let map = try map()
        #expect(
            ScriptError.frame("greet@file:///app/app.js:6:26", source: source, map: map)
                == .init(function: "greet", location: "src/app.ts:4:11"))
        #expect(
            ScriptError.frame("@file:///other/lib.js:3:4", source: source, map: map)
                == .init(function: "", location: "lib.js:3:4"))
        #expect(ScriptError.frame("[native code]", source: source, map: map) == nil)
        #expect(
            ScriptError.frame("forEach@[native code]", source: source, map: map) == .init(function: "forEach", location: "[native code]"))
    }

    @Test func mapsAnExceptionThrownByTheBundle() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appending(path: "app.js")
        try FileManager.default.copyItem(at: fixture("sourcemap.js"), to: source)
        try FileManager.default.copyItem(at: fixture("sourcemap.js.map"), to: directory.appending(path: "app.js.map"))
        let runtime = SvelteRuntime(source: source, reloadsOnChange: false)
        runtime.start()
        runtime.settle()
        let error = try #require(runtime.error)
        #expect(error.message == "Error: empty name")
        #expect(error.frames.first?.function == "greet")
        #expect(error.frames.first?.location.hasPrefix("src/app.ts:4:") == true)
    }
}
