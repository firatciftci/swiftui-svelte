import Foundation
import SwiftUI

public struct NativeModuleError: Error, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

@MainActor
public struct NativeModule {
    typealias Handler = @MainActor (Data) async throws -> Data?

    public let name: String
    private(set) var functions: [String: Handler] = [:]

    public init(_ name: String) {
        self.name = name
    }

    public func function(_ name: String, _ body: @escaping @MainActor () async throws -> Void) -> Self {
        adding(name) { _ in
            try await body()
            return nil
        }
    }

    public func function<Result: Encodable>(
        _ name: String, _ body: @escaping @MainActor () async throws -> Result
    ) -> Self {
        adding(name) { _ in try Self.encode(try await body()) }
    }

    public func function<A: Decodable>(_ name: String, _ body: @escaping @MainActor (A) async throws -> Void) -> Self {
        adding(name) { data in
            let arguments = try Self.decode(Arguments1<A>.self, from: data)
            try await body(arguments.first)
            return nil
        }
    }

    public func function<A: Decodable, Result: Encodable>(
        _ name: String, _ body: @escaping @MainActor (A) async throws -> Result
    ) -> Self {
        adding(name) { data in
            let arguments = try Self.decode(Arguments1<A>.self, from: data)
            return try Self.encode(try await body(arguments.first))
        }
    }

    public func function<A: Decodable, B: Decodable>(
        _ name: String, _ body: @escaping @MainActor (A, B) async throws -> Void
    ) -> Self {
        adding(name) { data in
            let arguments = try Self.decode(Arguments2<A, B>.self, from: data)
            try await body(arguments.first, arguments.second)
            return nil
        }
    }

    public func function<A: Decodable, B: Decodable, Result: Encodable>(
        _ name: String, _ body: @escaping @MainActor (A, B) async throws -> Result
    ) -> Self {
        adding(name) { data in
            let arguments = try Self.decode(Arguments2<A, B>.self, from: data)
            return try Self.encode(try await body(arguments.first, arguments.second))
        }
    }

    private func adding(_ name: String, _ handler: @escaping Handler) -> Self {
        var module = self
        module.functions[name] = handler
        return module
    }

    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NativeModuleError(code: "invalidArguments", message: Self.describe(error))
        }
    }

    private static func describe(_ error: any Error) -> String {
        switch error {
        case let DecodingError.typeMismatch(type, context), let DecodingError.valueNotFound(type, context):
            "Expected \(type) at \(path(context.codingPath)): \(context.debugDescription)"
        case let DecodingError.keyNotFound(key, context):
            "Missing \(key.stringValue) at \(path(context.codingPath))"
        case let DecodingError.dataCorrupted(context):
            context.debugDescription
        default:
            error.localizedDescription
        }
    }

    private static func path(_ keys: Array<any CodingKey>) -> String {
        let path = keys.map { $0.intValue.map { "argument \($0 + 1)" } ?? $0.stringValue }.joined(separator: ".")
        return path.isEmpty ? "the arguments" : path
    }
}

private struct Arguments1<A: Decodable>: Decodable {
    let first: A

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        first = try next(A.self, in: &container)
    }
}

private struct Arguments2<A: Decodable, B: Decodable>: Decodable {
    let first: A
    let second: B

    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        first = try next(A.self, in: &container)
        second = try next(B.self, in: &container)
    }
}

private func next<T: Decodable>(_ type: T.Type, in container: inout any UnkeyedDecodingContainer) throws -> T {
    if container.isAtEnd, let missing = try? JSONDecoder().decode(T.self, from: Data("null".utf8)) { return missing }
    return try container.decode(type)
}

@MainActor
public struct NativeElement {
    let node: Node
    let runtime: SvelteRuntime

    public var id: Int { node.id }

    public func value(_ name: String) -> JSONValue? {
        node.nativeAttributes[name]
    }

    public func string(_ name: String) -> String? {
        node.nativeAttributes[name]?.string
    }

    public func number(_ name: String) -> Double? {
        node.nativeAttributes[name]?.number
    }

    public func bool(_ name: String) -> Bool {
        node.nativeAttributes[name]?.isTrue ?? false
    }

    public func decode<T: Decodable>(_: T.Type, _ name: String) -> T? {
        try? node.nativeAttributes[name]?.decode(T.self)
    }

    public var children: some View {
        children(excluding: [])
    }

    public func children(excluding names: Set<String>) -> some View {
        ForEach(node.renderedChildren.filter { !names.contains($0.name) }) { NodeView(node: $0) }
    }

    public func slot(_ name: String) -> AnyView? {
        node.attachment(name).map { AnyView(Children(node: $0)) }
    }

    public func send(_ event: String) {
        runtime.dispatch(node.id, event)
    }

    public func send(_ event: String, _ payload: some Encodable) {
        guard let data = try? JSONEncoder().encode([payload]),
            let values = try? JSONSerialization.jsonObject(with: data) as? Array<Any>,
            let value = values.first
        else { return }
        runtime.dispatch(node.id, event, value)
    }
}

@MainActor
public struct NativeComponent {
    public let name: String
    let owned: Set<String>
    let body: @MainActor (NativeElement) -> AnyView

    public init(
        _ name: String,
        attributes: Array<String> = [],
        events: Array<String> = [],
        @ViewBuilder body: @escaping @MainActor (NativeElement) -> some View
    ) {
        self.name = name
        owned = Set(attributes).union(events)
        self.body = { AnyView(body($0)) }
    }
}

struct CustomElement: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        if let component = runtime.components[node.name] {
            component.body(NativeElement(node: node, runtime: runtime))
        } else {
            Text("Unknown element <\(node.name)>").foregroundStyle(.red)
        }
    }
}

extension SvelteRuntime {
    func callModule(_ id: Int, _ module: String, _ method: String, _ json: String) {
        guard let registered = modules[module] else {
            let error = NativeModuleError(code: "unknownModule", message: "There's no native module named \(module).")
            replyToCall(id, error: error, result: nil)
            return
        }
        guard let handler = registered.functions[method] else {
            let error = NativeModuleError(code: "unknownFunction", message: "There's no native function \(module).\(method).")
            replyToCall(id, error: error, result: nil)
            return
        }
        let generation = generation
        Task {
            let outcome: Result<Data?, NativeModuleError>
            do {
                outcome = .success(try await handler(Data(json.utf8)))
            } catch let error as NativeModuleError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(NativeModuleError(code: "native", message: error.localizedDescription))
            }
            guard generation == self.generation else { return }
            switch outcome {
            case let .success(data): replyToCall(id, error: nil, result: data)
            case let .failure(error): replyToCall(id, error: error, result: nil)
            }
        }
    }

    private func replyToCall(_ id: Int, error: NativeModuleError?, result: Data?) {
        let errorJSON = error.map { error in
            (try? JSONEncoder().encode(["code": error.code, "message": error.message])).flatMap {
                String(bytes: $0, encoding: .utf8)
            } ?? #"{"code":"native","message":"The native error couldn't be encoded."}"#
        }
        let resultJSON = result.flatMap { String(bytes: $0, encoding: .utf8) }
        call("__svelteNativeReply", [id, errorJSON ?? NSNull(), resultJSON ?? NSNull()])
    }
}
