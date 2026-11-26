import Foundation
import Testing

@testable import SvelteSwiftUI

nonisolated private let isCI = ProcessInfo.processInfo.environment["CI"] != nil

#if targetEnvironment(simulator)
    nonisolated private let isTimed = !isCI
#else
    nonisolated private let isTimed = true
#endif

@Suite(.enabled(if: isTimed, "Timings in a CI simulator are too noisy; the macOS run checks the budgets"))
struct BenchmarkTests {
    private let budgets: KeyValuePairs<String, Double> = [
        "create": 40, "update": 1, "swap": 2, "reverse": 5, "clear": 10,
    ]
    private let slack: Double = isCI ? 3 : 1
    private let overhead: Double = isCI ? 5 : 0

    private func apply(_ runtime: SvelteRuntime, _ operation: String, _ count: Int) -> Double {
        let before = runtime.engine.stats.withLock(\.applyTime)
        _ = runtime.evaluate { $0.evaluateScript("__bench('\(operation)', \(count))") }
        runtime.settle()
        return runtime.engine.stats.withLock(\.applyTime) - before
    }

    @Test(arguments: [1000, 10_000])
    func appliesRowBatchesWithinBudget(count: Int) async throws {
        let url = try #require(Bundle.module.url(forResource: "app", withExtension: "js", subdirectory: "Fixtures"))
        let runtime = SvelteRuntime(source: url)
        let id = runtime.mount("Table", props: "{}", actions: [:])
        let rows = { runtime.store.root(for: id)?.children.first?.children.count ?? 0 }
        for (operation, milliseconds) in budgets {
            await Task.yield()
            let elapsed = apply(runtime, operation, count)
            #expect(elapsed <= overhead + milliseconds * slack * Double(count) / 1000, "\(operation) took \(elapsed)ms")
            #expect(rows() == (operation == "clear" ? 0 : count), "\(operation)")
        }
        #expect(runtime.error == nil)
    }
}
