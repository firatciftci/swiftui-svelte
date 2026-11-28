import Darwin
import Foundation
import Testing

@testable import SvelteSwiftUI

nonisolated private let exampleBundle = URL(filePath: #filePath).deletingLastPathComponent()
    .appending(path: "../../example/ios/SvelteHost/Resources/app.js").standardized

@Suite(.enabled(if: FileManager.default.fileExists(atPath: exampleBundle.path), "Run nr build to build the example bundle"))
struct EngineCostTests {
    private struct Cost {
        var milliseconds: Array<Double> = []
        var megabytes: Array<Double> = []

        var summary: String {
            String(format: "%.0f ms, %.1f MB", median(milliseconds), median(megabytes))
        }

        func median(_ values: Array<Double>) -> Double {
            values.sorted()[values.count / 2]
        }
    }

    private func footprint() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return Double(info.phys_footprint) / 1_048_576
    }

    private func measure(_ cost: inout Cost, _ work: () -> Void) {
        let before = footprint()
        let start = ContinuousClock.now
        work()
        cost.milliseconds.append((ContinuousClock.now - start) / .milliseconds(1))
        cost.megabytes.append(footprint() - before)
    }

    @Test func costsLessToShowAnotherViewOnARuntimeThanToStartAnotherRuntime() {
        var runtimes: Array<SvelteRuntime> = []
        var started = Cost()
        var loaded = Cost()
        var shared = Cost()
        for round in 0..<6 {
            measure(&started) {
                let runtime = SvelteRuntime(source: exampleBundle)
                _ = runtime.mount("default", props: "{}", actions: [:])
                runtime.settle()
                runtimes.append(runtime)
            }
            if round == 0 { started = Cost() }
        }
        for _ in 0..<5 {
            measure(&loaded) {
                let runtime = SvelteRuntime(source: exampleBundle)
                runtime.start()
                runtime.settle()
                runtimes.append(runtime)
            }
        }
        for _ in 0..<5 {
            measure(&shared) {
                _ = runtimes[0].mount("default", props: "{}", actions: [:])
                runtimes[0].settle()
            }
        }
        #expect(runtimes.allSatisfy { $0.error == nil })
        print(
            "Another runtime: \(started.summary); loading the bundle alone: \(loaded.summary); another view on a shared runtime: \(shared.summary)"
        )
        #expect(shared.median(shared.milliseconds) * 3 < started.median(started.milliseconds))
    }
}
