import Foundation
import Testing

@testable import SvelteSwiftUI

nonisolated private let conformance = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../conformance")

nonisolated private func fixture<Value: Decodable>(_ name: String, as type: Value.Type) throws -> Value {
    try JSONDecoder().decode(type, from: Data(contentsOf: conformance.appending(path: name)))
}

nonisolated private struct Recording: Decodable {
    struct Step: Decodable {
        let label: String
        let commits: Array<String>
        let tree: String
    }

    let steps: Array<Step>
}

nonisolated struct ConformanceCases: Decodable, Sendable {
    struct Case: Decodable, Sendable, CustomTestStringConvertible {
        struct Batch: Decodable, Sendable {
            let commit: String
            let result: String
        }

        let label: String
        let rule: String
        let batches: Array<Batch>
        let tree: String

        var testDescription: String { label }
    }

    let `protocol`: Int
    let cases: Array<Case>
}

nonisolated private let cases = (try? fixture("batches.json", as: ConformanceCases.self).cases) ?? []

struct ConformanceTests {
    @Test func replaysTheRendererOpLog() throws {
        let recording = try fixture("renderer.json", as: Recording.self)
        #expect(recording.steps.count > 10)
        let store = NodeStore()
        for step in recording.steps {
            for commit in step.commits { store.apply(commit) }
            #expect(dump(store.root) == step.tree, "\(step.label)")
        }
    }

    @Test func coversTheProtocolThisHostImplements() throws {
        #expect(try fixture("batches.json", as: ConformanceCases.self).`protocol` == NodeStore.protocolVersion)
        #expect(cases.count > 20)
    }

    @Test(arguments: cases)
    func appliesOrRejectsEachBatch(_ fixture: ConformanceCases.Case) {
        let store = NodeStore()
        for (index, batch) in fixture.batches.enumerated() {
            let isApplied = store.apply(batch.commit)
            let result = !store.isCompatible ? "incompatible" : isApplied ? "applied" : "malformed"
            #expect(result == batch.result, "batch \(index) (\(fixture.rule))")
        }
        #expect(dump(store.root) == fixture.tree, "\(fixture.rule)")
    }
}
