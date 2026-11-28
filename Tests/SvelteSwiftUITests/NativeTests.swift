import Foundation
import Testing

@testable import SvelteSwiftUI

struct NativeTests {
    private struct Point: Codable, Equatable {
        let x: Double
        let y: Double
    }

    private let mount = """
        __nativeCommit(JSON.stringify([0, 1, 3, 0, 7, "txt", 1, 1, 0, 2, 0, 0, 0]));
        let names = 1;
        const attr = (id, name, value) => __nativeCommit(JSON.stringify([7, name, 4, id, names++, value]));
        globalThis.__svelteNativeReply = (id, error, json) => attr(2, `reply${id}`, { error, json });
        globalThis.__svelteNativeEvent = (module, event, json) => attr(2, `${module}.${event}`, json);

        """

    private func reply(_ runtime: SvelteRuntime, _ id: Int) async throws -> [String: JSONValue]? {
        for _ in 0..<200 where runtime.store.node(2)?.attributes["reply\(id)"] == nil {
            runtime.settle()
            try await Task.sleep(for: .milliseconds(5))
        }
        guard case let .object(reply) = runtime.store.node(2)?.attributes["reply\(id)"] else { return nil }
        return reply
    }

    private var geometry: NativeModule {
        NativeModule("geometry")
            .function("add") { (a: Double, b: Double) -> Double in a + b }
            .function("mirror") { (point: Point) -> Point in Point(x: -point.x, y: point.y) }
            .function("origin") { () -> Point in Point(x: 0, y: 0) }
            .function("greet") { (name: String?) -> String in "Hello, \(name ?? "you")" }
            .function("fail") { () async throws in
                try await Task.sleep(for: .milliseconds(5))
                throw NativeModuleError(code: "nope", message: "It failed")
            }
    }

    @Test func callsModuleFunctionsWithTypedArgumentsAndResults() async throws {
        let runtime = try runtime(
            mount + """
                __nativeCall(1, "geometry", "add", "[2, 3.5]");
                __nativeCall(2, "geometry", "mirror", '[{"x": 4, "y": 1}]');
                __nativeCall(3, "geometry", "origin", "[]");
                __nativeCall(4, "geometry", "greet", "[]");
                """,
            modules: [geometry])
        #expect(try await reply(runtime, 1) == ["error": .null, "json": .string("5.5")])
        let mirrored = try await reply(runtime, 2)?["json"]?.string.flatMap { Data($0.utf8) }
        #expect(try mirrored.map { try JSONDecoder().decode(Point.self, from: $0) } == Point(x: -4, y: 1))
        #expect(try await reply(runtime, 3)?["error"] == .null)
        #expect(try await reply(runtime, 4)?["json"] == .string("\"Hello, you\""))
    }

    @Test func repliesWithErrorsForThrowsBadArgumentsAndUnknownFunctions() async throws {
        let runtime = try runtime(
            mount + """
                __nativeCall(1, "geometry", "fail", "[]");
                __nativeCall(2, "geometry", "add", '["two", 3]');
                __nativeCall(3, "geometry", "subtract", "[]");
                __nativeCall(4, "nowhere", "add", "[]");
                """,
            modules: [geometry])
        func code(_ id: Int) async throws -> String? {
            guard let error = try await reply(runtime, id)?["error"]?.string,
                case let .object(object) = try JSONValue(parsing: error)
            else { return nil }
            return object["code"]?.string
        }
        #expect(try await code(1) == "nope")
        #expect(try await code(2) == "invalidArguments")
        #expect(try await code(3) == "unknownFunction")
        #expect(try await code(4) == "unknownModule")
    }

    @Test func emitsModuleEventsToJavaScript() throws {
        let runtime = try runtime(mount, modules: [])
        runtime.emit("moved", from: "geometry", Point(x: 1, y: 2))
        runtime.emit("reset", from: "geometry")
        runtime.settle()
        #expect(runtime.store.node(2)?.attributes["geometry.moved"] == .string(#"{"x":1,"y":2}"#))
        #expect(runtime.store.node(2)?.attributes["geometry.reset"] == nil)
    }

    @Test func keepsFilesInsideTheAppContainer() throws {
        #expect(throws: NativeModuleError.self) { try AppFiles.url(for: "../secrets") }
        #expect(throws: NativeModuleError.self) { try AppFiles.url(for: "/etc/hosts") }
        #expect(throws: NativeModuleError.self) { try AppFiles.url(for: "notes/./a.txt") }
        #expect(try AppFiles.url(for: "notes/today.txt") == AppFiles.root.appending(path: "notes").appending(path: "today.txt"))
    }

    @Test func roundTripsFilesInADirectoryWhosePathHasSpaces() async throws {
        let files = BuiltInModules.files
        func run(_ name: String, _ arguments: String) async throws -> String? {
            let handler = try #require(files.functions[name])
            return try await handler(Data(arguments.utf8)).flatMap { String(bytes: $0, encoding: .utf8) }
        }
        let folder = "tests \(UUID().uuidString)"
        #expect(AppFiles.root.path(percentEncoded: false).contains(" "))
        #expect(try await run("exists", #"["\#(folder)/a b.txt"]"#) == "false")
        _ = try await run("writeText", #"["\#(folder)/a b.txt", "Hello"]"#)
        #expect(try await run("exists", #"["\#(folder)/a b.txt"]"#) == "true")
        #expect(try await run("readText", #"["\#(folder)/a b.txt"]"#) == #""Hello""#)
        #expect(try await run("list", #"["\#(folder)"]"#) == #"["a b.txt"]"#)
        _ = try await run("delete", #"["\#(folder)/a b.txt"]"#)
        #expect(try await run("readText", #"["\#(folder)/a b.txt"]"#) == "null")
        try FileManager.default.removeItem(at: try AppFiles.url(for: folder))
    }

    @Test func registersTheBuiltInModules() {
        let runtime = SvelteRuntime(source: URL(filePath: "/dev/null"))
        for name in ["haptics", "clipboard", "share", "links", "secureStorage", "files"] {
            #expect(runtime.modules[name] != nil, "\(name)")
        }
        #expect(runtime.modules["files"]?.functions["writeText"] != nil)
    }
}
