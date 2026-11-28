import CryptoKit
import Foundation
import JavaScriptCore
import QuartzCore
import Synchronization

nonisolated enum ScriptArgument: Sendable {
    case json(JSONValue)
    case date(Date)

    var bridged: Any {
        switch self {
        case let .json(value): value.object
        case let .date(date): date
        }
    }
}

actor ScriptEngine {
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

    private struct Timer {
        let source: any DispatchSourceTimer
        let callback: JSValue
        let arguments: Array<JSValue>
        let repeats: Bool
    }

    nonisolated let queue: DispatchSerialQueue
    nonisolated let stats = Mutex(Stats())
    private nonisolated let outbox = Mutex<(messages: Array<Message>, isScheduled: Bool)>(([], false))
    private nonisolated let deliver = Mutex<(@Sendable () -> Void)?>(nil)
    private(set) var context: JSContext?
    private var timers: [Int: Timer] = [:]
    private var nextTimerID = 1
    private var environment = "{}"
    let network: NetworkClient
    private let storage: LocalStorage
    private nonisolated let diagnostics: Diagnostics

    nonisolated var unownedExecutor: UnownedSerialExecutor { queue.asUnownedSerialExecutor() }

    init(storage: sending LocalStorage, diagnostics: Diagnostics = Diagnostics()) {
        let queue = DispatchSerialQueue(label: "SvelteSwiftUI.JavaScript", qos: .userInteractive)
        self.queue = queue
        self.storage = storage
        self.diagnostics = diagnostics
        network = NetworkClient(queue: queue)
        network.engine = self
    }

    nonisolated func onMessages(_ deliver: @escaping @Sendable () -> Void) {
        self.deliver.withLock { $0 = deliver }
    }

    nonisolated func sync<T: Sendable>(_ body: (isolated ScriptEngine) -> T) -> T {
        queue.sync { assumeIsolated(body) }
    }

    nonisolated func async(_ body: @escaping @Sendable (isolated ScriptEngine) -> Void) {
        queue.async { self.assumeIsolated(body) }
    }

    nonisolated func takeMessages() -> Array<Message> {
        outbox.withLock { box in
            box.isScheduled = false
            defer { box.messages = [] }
            return box.messages
        }
    }

    private nonisolated func post(_ message: Message) {
        let shouldSchedule = outbox.withLock { box in
            box.messages.append(message)
            defer { box.isScheduled = true }
            return !box.isScheduled
        }
        if shouldSchedule { deliver.withLock { $0 }?() }
    }

    func load(
        script: String, source: URL, map: SourceMap?, environment: String, mounts: Array<Array<ScriptArgument>>
    ) -> BundleIdentity? {
        stop()
        self.environment = environment
        network.origin = NetworkClient.origin(of: source)
        guard let context = JSContext() else {
            post(.error(ScriptError(message: "Couldn't create a JavaScript context.", frames: [])))
            return nil
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
        let identity = BundleIdentity(context.objectForKeyedSubscript("__svelteBundle"))
        for mount in mounts { call("__svelteMount", mount) }
        return identity
    }

    func stop() {
        for timer in timers.values { timer.source.cancel() }
        timers = [:]
        network.reset()
        context = nil
        outbox.withLock { $0.messages = [] }
    }

    func collectGarbage() {
        if let context { JSGarbageCollect(context.jsGlobalContextRef) }
    }

    func call(_ function: String, _ arguments: Array<ScriptArgument>) {
        guard let callee = context?.objectForKeyedSubscript(function), !callee.isUndefined else { return }
        callee.call(withArguments: arguments.map(\.bridged))
    }

    private func install(into context: JSContext) {
        let commit: @convention(block) (String, JSValue) -> Void = { [weak self] json, animation in
            self?.post(.commit(json, animation.isString ? animation.toString() : nil))
        }
        let log: @convention(block) (String, String) -> Void = { Diagnostics.log($1, level: $0) }
        let diagnostics = diagnostics
        let diagnostic: @convention(block) (String) -> Void = { diagnostics.report(json: $0) }
        let setTimeout: @convention(block) (JSValue, JSValue) -> Int = { callback, delay in
            self.schedule(callback, after: delay, repeats: false)
        }
        let setInterval: @convention(block) (JSValue, JSValue) -> Int = { callback, delay in
            self.schedule(callback, after: delay, repeats: true)
        }
        let clearTimer: @convention(block) (Int) -> Void = { id in
            self.timers.removeValue(forKey: id)?.source.cancel()
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
        let loadStorage: @convention(block) () -> String = { [weak context] in
            guard let context, self.context === context else { return "{}" }
            return self.storage.load()
        }
        let saveStorage: @convention(block) (String) -> Void = { [weak context] json in
            guard let context, self.context === context else { return }
            self.storage.save(json)
        }
        let environment: @convention(block) () -> String = {
            self.environment
        }
        let globals: [String: Any] = [
            "__nativeCommit": commit,
            "__nativeInvoke": invoke,
            "__nativeCall": nativeCall,
            "__nativeLog": log,
            "__nativeDiagnostic": diagnostic,
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
            "__nativeProtocols": Array([NodeStore.protocolVersion]),
        ]
        for (name, value) in globals { context.globalObject.setValue(value, forProperty: name) }
        installHostAPIs(into: context)
    }

    private func installHostAPIs(into context: JSContext) {
        typealias Fetch = @convention(block) (Int, String, JSValue, JSValue, JSValue, JSValue) -> Void
        let fetch: Fetch = { id, json, body, onResponse, onData, onEnd in
            let callbacks = NetworkClient.FetchCallbacks(onResponse: onResponse, onData: onData, onEnd: onEnd)
            self.network.fetch(id: id, json: json, body: body, callbacks: callbacks)
        }
        let cancelFetch: @convention(block) (Int) -> Void = { id in
            self.network.cancelFetch(id: id)
        }
        let openSocket: @convention(block) (Int, String, String, JSValue) -> Void = { id, url, protocols, handlers in
            self.network.openSocket(id: id, url: url, protocols: protocols, handlers: handlers)
        }
        let sendSocket: @convention(block) (Int, JSValue) -> Void = { id, data in
            self.network.send(id: id, data: data)
        }
        let closeSocket: @convention(block) (Int, JSValue, String) -> Void = { id, code, reason in
            self.network.closeSocket(id: id, code: code.isNull ? nil : Int(code.toInt32()), reason: reason)
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
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + interval, repeating: repeats ? interval : .never, leeway: .milliseconds(1))
        let extra = Array((JSContext.currentArguments() as? Array<JSValue> ?? []).dropFirst(2))
        source.setEventHandler { [weak self] in
            self?.assumeIsolated { $0.fire(id) }
        }
        timers[id] = Timer(source: source, callback: callback, arguments: extra, repeats: repeats)
        source.resume()
        return id
    }

    private func fire(_ id: Int) {
        guard let timer = timers[id] else { return }
        if !timer.repeats { timers[id] = nil }
        timer.callback.call(withArguments: timer.arguments)
    }
}

struct BundleIdentity: Equatable, Sendable {
    let version: String
    let protocolVersion: Int

    nonisolated init(version: String, protocolVersion: Int) {
        self.version = version
        self.protocolVersion = protocolVersion
    }

    nonisolated init?(_ value: JSValue?) {
        guard let value, value.isObject,
            let version = value.objectForKeyedSubscript("version"), version.isString,
            let protocolVersion = value.objectForKeyedSubscript("protocol"), protocolVersion.isNumber
        else { return nil }
        self.init(version: version.toString(), protocolVersion: Int(protocolVersion.toInt32()))
    }
}
