import Foundation
import Synchronization

nonisolated final class JavaScriptThread: SerialExecutor {
    private final class Call<Value: Sendable>: Sendable {
        private let body: Mutex<(@Sendable () -> Value)?>
        let value = Mutex<Value?>(nil)

        init(_ body: @escaping @Sendable () -> Value) {
            self.body = Mutex(body)
        }

        func run() {
            guard let body = body.withLock({ $0.take() }) else { return }
            let result = body()
            value.withLock { $0 = result }
        }
    }

    private let runLoop = Mutex<CFRunLoop?>(nil)

    init(name: String) {
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            runLoop.withLock { $0 = CFRunLoopGetCurrent() }
            RunLoop.current.add(Port(), forMode: .default)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = name
        thread.qualityOfService = .userInteractive
        thread.stackSize = 8 << 20
        thread.start()
        ready.wait()
    }

    var isCurrent: Bool {
        runLoop.withLock { loop in loop.map { CFEqual($0, CFRunLoopGetCurrent()) } ?? false }
    }

    @discardableResult
    func perform(_ block: @escaping @Sendable () -> Void) -> Bool {
        runLoop.withLock { loop in
            guard let loop else { return false }
            CFRunLoopPerformBlock(loop, CFRunLoopMode.commonModes.rawValue) { autoreleasepool(invoking: block) }
            CFRunLoopWakeUp(loop)
            return true
        }
    }

    func performAndWait<T: Sendable>(_ body: @Sendable () -> T) -> T {
        if isCurrent { return body() }
        return withoutActuallyEscaping(body) { body in
            let call = Call(body)
            let done = DispatchSemaphore(value: 0)
            let isScheduled = perform {
                call.run()
                done.signal()
            }
            guard isScheduled else { preconditionFailure("The JavaScript thread stopped before it ran a call.") }
            done.wait()
            guard let value = call.value.withLock({ $0.take() }) else {
                preconditionFailure("The JavaScript thread finished a call without a result.")
            }
            return value
        }
    }

    func stop() {
        runLoop.withLock { loop in
            guard let current = loop else { return }
            CFRunLoopStop(current)
            loop = nil
        }
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let job = UnownedJob(job)
        let executor = asUnownedSerialExecutor()
        perform { job.runSynchronously(on: executor) }
    }

    func checkIsolated() {
        precondition(isCurrent, "Expected to be on the JavaScript thread.")
    }
}
