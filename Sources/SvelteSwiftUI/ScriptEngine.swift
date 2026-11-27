import CryptoKit
import Foundation
import JavaScriptCore
import QuartzCore
import Synchronization

nonisolated struct Unchecked<Value>: @unchecked Sendable {
    let value: Value
}

nonisolated final class ScriptEngine: @unchecked Sendable {
    enum Message: Sendable {
        case commit(String, String?)
        case action(Int, String, String)
        case invoke(Int, String, String)
        case nativeCall(Int, String, String, String)
        case error(ScriptError)
        case requestFrame
        case watchFrames
    }

    struct Stats: Sendable {
        var nodes = 0
        var maxFrameGap = 0.0
        var applyTime = 0.0
    }

    let queue: DispatchQueue
    let stats = Mutex(Stats())
    private let outbox = Mutex<(messages: Array<Message>, isScheduled: Bool)>(([], false))
    private let deliver: @Sendable () -> Void
    private(set) var context: JSContext?
    private var timers: [Int: any DispatchSourceTimer] = [:]
    private var nextTimerID = 1
    private var environment = "{}"
    private let network: NetworkClient

    init(deliver: @escaping @Sendable () -> Void) {
        self.deliver = deliver
        queue = DispatchQueue(label: "SvelteSwiftUI.JavaScript", qos: .userInteractive)
        network = NetworkClient(queue: queue)
    }

    func takeMessages() -> Array<Message> {
        outbox.withLock { box in
            box.isScheduled = false
            defer { box.messages = [] }
            return box.messages
        }
    }

    private func post(_ message: Message) {
        let shouldSchedule = outbox.withLock { box in
            box.messages.append(message)
            defer { box.isScheduled = true }
            return !box.isScheduled
        }
        if shouldSchedule { deliver() }
    }

    func load(script: String, source: URL, map: SourceMap?, environment: String, mounts: Array<Unchecked<Array<Any>>>) {
        dispatchPrecondition(condition: .onQueue(queue))
        stop()
        self.environment = environment
        network.origin = NetworkClient.origin(of: source)
        guard let context = JSContext() else {
            post(.error(ScriptError(message: "Couldn't create a JavaScript context.", frames: [])))
            return
        }
        #if DEBUG
            context.isInspectable = true
        #endif
        context.name = "Svelte"
        context.exceptionHandler = { [weak self] _, exception in
            guard let exception else { return }
            self?.post(.error(ScriptError(exception: exception, source: source, map: map)))
        }
        install(into: context)
        self.context = context
        context.evaluateScript(script, withSourceURL: source)
        for mount in mounts { call("__svelteMount", mount) }
    }

    func stop() {
        dispatchPrecondition(condition: .onQueue(queue))
        for timer in timers.values { timer.cancel() }
        timers = [:]
        network.reset()
        context = nil
        outbox.withLock { $0.messages = [] }
    }

    func collectGarbage() {
        dispatchPrecondition(condition: .onQueue(queue))
        if let context { JSGarbageCollect(context.jsGlobalContextRef) }
    }

    func call(_ function: String, _ arguments: Unchecked<Array<Any>>) {
        dispatchPrecondition(condition: .onQueue(queue))
        guard let callee = context?.objectForKeyedSubscript(function), !callee.isUndefined else { return }
        callee.call(withArguments: arguments.value)
    }

    private func install(into context: JSContext) {
        let commit: @convention(block) (String, JSValue) -> Void = { [weak self] json, animation in
            self?.post(.commit(json, animation.isString ? animation.toString() : nil))
        }
        let log: @convention(block) (String, String) -> Void = { level, message in
            print("[js:\(level)] \(message)")
        }
        let setTimeout: @convention(block) (JSValue, JSValue) -> Int = { [weak self] callback, delay in
            self?.schedule(callback, after: delay, repeats: false) ?? 0
        }
        let setInterval: @convention(block) (JSValue, JSValue) -> Int = { [weak self] callback, delay in
            self?.schedule(callback, after: delay, repeats: true) ?? 0
        }
        let clearTimer: @convention(block) (Int) -> Void = { [weak self] id in
            self?.timers.removeValue(forKey: id)?.cancel()
        }
        let now: @convention(block) () -> Double = {
            CACurrentMediaTime() * 1000
        }
        let action: @convention(block) (Int, String, String) -> Void = { [weak self] mount, name, json in
            self?.post(.action(mount, name, json))
        }
        let invoke: @convention(block) (Int, String, String) -> Void = { [weak self] id, method, json in
            self?.post(.invoke(id, method, json))
        }
        let nativeCall: @convention(block) (Int, String, String, String) -> Void = { [weak self] id, module, method, json in
            self?.post(.nativeCall(id, module, method, json))
        }
        let requestFrame: @convention(block) () -> Void = { [weak self] in
            self?.post(.requestFrame)
        }
        let collectGarbage: @convention(block) () -> Void = { [weak context] in
            if let context { JSGarbageCollect(context.jsGlobalContextRef) }
        }
        let stats: @convention(block) () -> [String: Double] = { [weak self] in
            guard let self else { return [:] }
            post(.watchFrames)
            return self.stats.withLock { stats in
                defer {
                    stats.maxFrameGap = 0
                    stats.applyTime = 0
                }
                return ["nodes": Double(stats.nodes), "maxFrameGapMs": stats.maxFrameGap, "applyMs": stats.applyTime]
            }
        }
        let storageKey = "SvelteSwiftUI.localStorage"
        let loadStorage: @convention(block) () -> String = {
            UserDefaults.standard.string(forKey: storageKey) ?? "{}"
        }
        let saveStorage: @convention(block) (String) -> Void = { json in
            UserDefaults.standard.set(json, forKey: storageKey)
        }
        let environment: @convention(block) () -> String = { [weak self] in
            self?.environment ?? "{}"
        }
        let globals: [String: Any] = [
            "__nativeCommit": commit,
            "__nativeInvoke": invoke,
            "__nativeCall": nativeCall,
            "__nativeLog": log,
            "setTimeout": setTimeout,
            "setInterval": setInterval,
            "clearTimeout": clearTimer,
            "clearInterval": clearTimer,
            "__nativeNow": now,
            "__nativeGC": collectGarbage,
            "__nativeRequestFrame": requestFrame,
            "__nativeAction": action,
            "__nativeStats": stats,
            "__nativeStorageLoad": loadStorage,
            "__nativeStorageSave": saveStorage,
            "__nativeEnvironment": environment,
        ]
        for (name, value) in globals { context.globalObject.setValue(value, forProperty: name) }
        installHostAPIs(into: context)
    }

    private func installHostAPIs(into context: JSContext) {
        typealias Fetch = @convention(block) (Int, String, JSValue, JSValue, JSValue, JSValue) -> Void
        let fetch: Fetch = { [weak self] id, json, body, onResponse, onData, onEnd in
            let callbacks = NetworkClient.FetchCallbacks(onResponse: onResponse, onData: onData, onEnd: onEnd)
            self?.network.fetch(id: id, json: json, body: body, callbacks: callbacks)
        }
        let cancelFetch: @convention(block) (Int) -> Void = { [weak self] id in
            self?.network.cancelFetch(id: id)
        }
        let openSocket: @convention(block) (Int, String, String, JSValue) -> Void = { [weak self] id, url, protocols, handlers in
            self?.network.openSocket(id: id, url: url, protocols: protocols, handlers: handlers)
        }
        let sendSocket: @convention(block) (Int, JSValue) -> Void = { [weak self] id, data in
            self?.network.send(id: id, data: data)
        }
        let closeSocket: @convention(block) (Int, JSValue, String) -> Void = { [weak self] id, code, reason in
            self?.network.closeSocket(id: id, code: code.isNull ? nil : Int(code.toInt32()), reason: reason)
        }
        let randomFill: @convention(block) (JSValue) -> Void = { bytes in
            guard let context = JSContext.current() else { return }
            guard bytes.isTypedArray else {
                context.exception = JSValue(newErrorFromMessage: "The argument must be a TypedArray.", in: context)
                return
            }
            let status =
                bytes.withBytes { buffer -> OSStatus in
                    guard let base = buffer.baseAddress else { return errSecSuccess }
                    return SecRandomCopyBytes(kSecRandomDefault, buffer.count, base)
                } ?? errSecSuccess
            if status != errSecSuccess {
                context.exception = JSValue(newErrorFromMessage: "The platform's random source failed (\(status)).", in: context)
            }
        }
        let digest: @convention(block) (String, JSValue) -> JSValue = { algorithm, value in
            guard let context = JSContext.current() ?? value.context else { return JSValue() }
            guard value.isTypedArray else {
                context.exception = JSValue(newErrorFromMessage: "The data must be a TypedArray.", in: context)
                return JSValue(nullIn: context)
            }
            let data = value.bytes ?? Data()
            switch algorithm {
            case "SHA-1": return context.bytes(Data(Insecure.SHA1.hash(data: data)))
            case "SHA-256": return context.bytes(Data(SHA256.hash(data: data)))
            case "SHA-384": return context.bytes(Data(SHA384.hash(data: data)))
            case "SHA-512": return context.bytes(Data(SHA512.hash(data: data)))
            default:
                context.exception = JSValue(newErrorFromMessage: "Unsupported digest algorithm \(algorithm).", in: context)
                return JSValue(nullIn: context)
            }
        }
        let globals: [String: Any] = [
            "__nativeFetch": fetch,
            "__nativeFetchCancel": cancelFetch,
            "__nativeWebSocketOpen": openSocket,
            "__nativeWebSocketSend": sendSocket,
            "__nativeWebSocketClose": closeSocket,
            "__nativeRandomFill": randomFill,
            "__nativeDigest": digest,
        ]
        for (name, value) in globals { context.globalObject.setValue(value, forProperty: name) }
    }

    private func schedule(_ callback: JSValue, after delay: JSValue, repeats: Bool) -> Int {
        let id = nextTimerID
        nextTimerID += 1
        let milliseconds = delay.toDouble()
        let requested = milliseconds > 0 ? Int(min(milliseconds, Double(Int32.max))) : 0
        let interval = DispatchTimeInterval.milliseconds(max(requested, repeats ? 1 : 0))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: repeats ? interval : .never, leeway: .milliseconds(1))
        let extra = Array((JSContext.currentArguments() as? Array<JSValue> ?? []).dropFirst(2))
        let handler = Unchecked(value: (callback, extra))
        timer.setEventHandler { [weak self] in
            if !repeats { self?.timers[id] = nil }
            handler.value.0.call(withArguments: handler.value.1)
        }
        timers[id] = timer
        timer.resume()
        return id
    }
}
