import Foundation
import Testing

@testable import SvelteSwiftUI

struct ConformanceTests {
    private struct Fixture: Decodable {
        struct Step: Decodable {
            let label: String
            let commits: Array<String>
            let tree: String
        }

        let steps: Array<Step>
    }

    @Test func replaysTheRendererOpLog() throws {
        let url = try #require(Bundle.module.url(forResource: "conformance", withExtension: "json", subdirectory: "Fixtures"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        #expect(fixture.steps.count > 10)
        let store = NodeStore()
        for step in fixture.steps {
            for commit in step.commits { store.apply(commit) }
            #expect(dump(store.root) == step.tree, "\(step.label)")
        }
    }
}
