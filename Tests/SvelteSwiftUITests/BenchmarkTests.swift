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

@Suite(.serialized)
struct NodeMemoryTests {
    private let rows = 4000
    private let budget = 380.0

    private func allocated() -> Int {
        var statistics = malloc_statistics_t()
        malloc_zone_statistics(nil, &statistics)
        return statistics.size_in_use
    }

    private func batch(rows: Int) -> String {
        var tokens = ["0,1,\(NodeStore.protocolVersion),0", "7,\"list\",7,\"hstack\",7,\"txt\",7,\"btn\",7,\"weight\"", "1,1,0,2,0,0,0"]
        for row in 0..<rows {
            let id = 3 + row * 5
            tokens.append("1,2,0,\(id),1,0,2,\(id + 1),2,1,4,\"regular\",1,-\(id + 2),\"Row \(row)\",\(id + 3),3,0,1,-\(id + 4),\"Select\"")
        }
        return "[\(tokens.joined(separator: ","))]"
    }

    @Test func keepsEachNativeNodeWithinBudget() {
        let json = batch(rows: rows)
        var samples: Array<Double> = []
        for _ in 0..<3 {
            let store = NodeStore()
            let before = allocated()
            store.apply(json)
            let after = allocated()
            #expect(store.nodeCount == 2 + rows * 5)
            samples.append(Double(after - before) / Double(rows * 5))
            withExtendedLifetime(store) {}
        }
        let perNode = samples.min() ?? 0
        #expect(perNode <= budget, "\(perNode) bytes per node")
    }
}
