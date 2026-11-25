import Darwin
import SvelteSwiftUI

@MainActor
enum DiagnosticsModule {
    static var module: NativeModule {
        NativeModule("diagnostics")
            .function("memory") { () throws -> Double in
                var info = task_vm_info_data_t()
                var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
                let result = withUnsafeMutablePointer(to: &info) { pointer in
                    pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                    }
                }
                guard result == KERN_SUCCESS else {
                    throw NativeModuleError(code: "memory", message: "Couldn't read the memory footprint.")
                }
                return Double(info.phys_footprint) / 1_048_576
            }
    }
}
