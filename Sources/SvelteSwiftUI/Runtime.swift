import CryptoKit
import Foundation
import JavaScriptCore
import Network
import Observation
import QuartzCore

#if os(macOS)
    import AppKit
#endif

@Observable
public final class SvelteRuntime {
    private struct Mount {
        let component: String
        var props: String
        var actions: [String: @MainActor (Any) -> Void]
    }

    private(set) var store = NodeStore()
    private(set) var error: ScriptError?

    @ObservationIgnored private(set) var context: JSContext?
    @ObservationIgnored private var timers: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var nextTimerID = 1
    @ObservationIgnored private var isFrameRequested = false
    @ObservationIgnored private var sourceMap: SourceMap?
    @ObservationIgnored private var mounts: [Int: Mount] = [:]
    @ObservationIgnored private var nextMountID = 1
    @ObservationIgnored private var loadedVersion: Date?
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private let frames = FrameMonitor()
    @ObservationIgnored private let network = NetworkClient()
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var environment = HostEnvironment.current
    @ObservationIgnored private let source: URL
    @ObservationIgnored private let reloadsOnChange: Bool

    public init(source: URL, reloadsOnChange: Bool = false) {
        self.source = source
        self.reloadsOnChange = reloadsOnChange
    }

    private var bundleVersion: Date? {
        try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func start() {
        guard context == nil else { return }
        frames.onFrame = { [weak self] timestamp in self?.frame(timestamp) }
        frames.start()
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in self?.updateEnvironment(["onLine": isOnline]) }
        }
        monitor.start(queue: .main)
        pathMonitor = monitor
        reload()
        guard reloadsOnChange else { return }
        watcher = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, bundleVersion != loadedVersion else { continue }
                reload()
            }
        }
    }

    func mount(_ component: String, props: String, actions: [String: @MainActor (Any) -> Void]) -> Int {
        let id = nextMountID
        nextMountID += 1
        mounts[id] = Mount(component: component, props: props, actions: actions)
        if context == nil { start() } else { send(id) }
        return id
    }

    func update(_ id: Int, props: String, actions: [String: @MainActor (Any) -> Void]) {
        guard let mount = mounts[id] else { return }
        mounts[id]?.actions = actions
        guard mount.props != props else { return }
        mounts[id]?.props = props
        context?.objectForKeyedSubscript("__svelteProps")?.call(withArguments: [id, props])
    }

    func unmount(_ id: Int) {
        guard mounts.removeValue(forKey: id) != nil else { return }
        context?.objectForKeyedSubscript("__svelteUnmount")?.call(withArguments: [id])
    }

    private func send(_ id: Int) {
        guard let mount = mounts[id] else { return }
        let actions = mount.actions.keys.sorted().map { "\"\($0)\"" }.joined(separator: ",")
        context?.objectForKeyedSubscript("__svelteMount")?
            .call(withArguments: [id, mount.component, "{\"props\":\(mount.props),\"actions\":[\(actions)]}"])
    }

    private func perform(_ mount: Int, _ name: String, _ json: String) {
        guard let action = mounts[mount]?.actions[name] else { return }
        let value = (try? JSONValue(parsing: json)) ?? .null
        action(value.object)
    }

    func dispatch(_ id: Int, _ type: String, _ payload: Any = NSNull()) {
        context?.objectForKeyedSubscript("__svelteDispatch")?
            .call(withArguments: [id, type, payload])
    }

    private func frame(_ timestamp: CFTimeInterval) {
        guard isFrameRequested else { return }
        isFrameRequested = false
        context?.objectForKeyedSubscript("__svelteFrame")?.call(withArguments: [timestamp * 1000])
    }

    func edit(_ node: Node, _ name: String, to value: JSONValue, event: String, payload: Any) {
        node.attributes[name] = value
        dispatch(node.id, event, payload)
        let settled = node.attributes[name]
        guard settled != value else { return }
        node.attributes[name] = value
        Task { @MainActor in
            if node.attributes[name] == value { node.attributes[name] = settled }
        }
    }

    func updateEnvironment(_ changes: [String: Any]) {
        var changed: [String: Any] = [:]
        for (key, value) in changes where !((environment[key] as? NSObject)?.isEqual(value) ?? false) {
            environment[key] = value
            changed[key] = value
        }
        guard !changed.isEmpty, let data = try? JSONSerialization.data(withJSONObject: changed, options: .sortedKeys)
        else { return }
        context?.objectForKeyedSubscript("__svelteEnvironment")?.call(withArguments: [String(bytes: data, encoding: .utf8) ?? "{}"])
    }

    func report(_ error: ScriptError) {
        print("[js:exception] \(error)")
        self.error = error
    }

    func dismissError() {
        error = nil
        store.dismissError()
    }

    func restart() {
        reload()
    }

    private func reload() {
        for timer in timers.values { timer.cancel() }
        timers = [:]
        network.reset()
        isFrameRequested = false
        store = NodeStore()
        error = nil
        loadedVersion = bundleVersion

        guard let script = try? String(contentsOf: source, encoding: .utf8),
            let context = JSContext()
        else {
            report(ScriptError(message: "Couldn't load \(source.path()).", frames: []))
            return
        }

        #if DEBUG
            context.isInspectable = true
        #endif
        sourceMap = (try? Data(contentsOf: source.appendingPathExtension("map"))).flatMap { try? SourceMap(json: $0) }
        context.exceptionHandler = { [weak self] _, exception in
            guard let self, let exception else { return }
            report(ScriptError(exception: exception, source: source, map: sourceMap))
        }
        install(into: context)
        self.context = context
        context.evaluateScript(script, withSourceURL: source)
        for id in mounts.keys.sorted() { send(id) }
    }

    private func install(into context: JSContext) {
        let commit: @convention(block) (String) -> Void = { [weak self] json in
            self?.store.apply(json)
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
            self?.perform(mount, name, json)
        }
        let requestFrame: @convention(block) () -> Void = { [weak self] in
            self?.isFrameRequested = true
        }
        let collectGarbage: @convention(block) () -> Void = { [weak context] in
            if let context { JSGarbageCollect(context.jsGlobalContextRef) }
        }
        let stats: @convention(block) () -> [String: Double] = { [weak self] in
            guard let self else { return [:] }
            return ["nodes": Double(store.nodeCount), "maxFrameGapMs": frames.takeMaxGap()]
        }

        context.globalObject.setValue(commit, forProperty: "__nativeCommit")
        context.globalObject.setValue(log, forProperty: "__nativeLog")
        context.globalObject.setValue(setTimeout, forProperty: "setTimeout")
        context.globalObject.setValue(setInterval, forProperty: "setInterval")
        context.globalObject.setValue(clearTimer, forProperty: "clearTimeout")
        context.globalObject.setValue(clearTimer, forProperty: "clearInterval")
        context.globalObject.setValue(now, forProperty: "__nativeNow")
        context.globalObject.setValue(collectGarbage, forProperty: "__nativeGC")
        context.globalObject.setValue(requestFrame, forProperty: "__nativeRequestFrame")
        context.globalObject.setValue(action, forProperty: "__nativeAction")
        context.globalObject.setValue(stats, forProperty: "__nativeStats")

        let storageKey = "SvelteSwiftUI.localStorage"
        let loadStorage: @convention(block) () -> String = {
            UserDefaults.standard.string(forKey: storageKey) ?? "{}"
        }
        let saveStorage: @convention(block) (String) -> Void = { json in
            UserDefaults.standard.set(json, forKey: storageKey)
        }
        context.globalObject.setValue(loadStorage, forProperty: "__nativeStorageLoad")
        context.globalObject.setValue(saveStorage, forProperty: "__nativeStorageSave")
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
        let closeSocket: @convention(block) (Int, Int, String) -> Void = { [weak self] id, code, reason in
            self?.network.closeSocket(id: id, code: code, reason: reason)
        }
        let randomFill: @convention(block) (JSValue) -> Void = { bytes in
            _ = bytes.withBytes { buffer in
                guard let base = buffer.baseAddress else { return }
                _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, base)
            }
        }
        let digest: @convention(block) (String, JSValue) -> JSValue = { algorithm, value in
            let context = JSContext.current() ?? value.context
            let data = value.bytes ?? Data()
            let output: Data =
                switch algorithm {
                case "SHA-1": Data(Insecure.SHA1.hash(data: data))
                case "SHA-384": Data(SHA384.hash(data: data))
                case "SHA-512": Data(SHA512.hash(data: data))
                default: Data(SHA256.hash(data: data))
                }
            return context?.bytes(output) ?? JSValue()
        }
        let environment: @convention(block) () -> String = { [weak self] in
            let values = self?.environment ?? HostEnvironment.current
            guard let data = try? JSONSerialization.data(withJSONObject: values, options: .sortedKeys) else { return "{}" }
            return String(bytes: data, encoding: .utf8) ?? "{}"
        }
        context.globalObject.setValue(fetch, forProperty: "__nativeFetch")
        context.globalObject.setValue(cancelFetch, forProperty: "__nativeFetchCancel")
        context.globalObject.setValue(openSocket, forProperty: "__nativeWebSocketOpen")
        context.globalObject.setValue(sendSocket, forProperty: "__nativeWebSocketSend")
        context.globalObject.setValue(closeSocket, forProperty: "__nativeWebSocketClose")
        context.globalObject.setValue(randomFill, forProperty: "__nativeRandomFill")
        context.globalObject.setValue(digest, forProperty: "__nativeDigest")
        context.globalObject.setValue(environment, forProperty: "__nativeEnvironment")
    }

    private func schedule(_ callback: JSValue, after delay: JSValue, repeats: Bool) -> Int {
        let id = nextTimerID
        nextTimerID += 1
        let interval = Duration.milliseconds(delay.isNumber ? max(delay.toDouble(), 0) : 0)
        timers[id] = Task { [weak self] in
            repeat {
                try? await Task.sleep(for: interval)
                if Task.isCancelled { return }
                callback.call(withArguments: [])
            } while repeats
            self?.timers[id] = nil
        }
        return id
    }
}

private final class FrameMonitor: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var maxGap: Double = 0
    var onFrame: ((CFTimeInterval) -> Void)?

    func start() {
        guard link == nil else { return }
        #if os(macOS)
            guard let link = (NSScreen.main ?? NSScreen.screens.first)?.displayLink(target: self, selector: #selector(tick)) else { return }
        #else
            let link = CADisplayLink(target: self, selector: #selector(tick))
        #endif
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func takeMaxGap() -> Double {
        defer { maxGap = 0 }
        return maxGap
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp > 0 {
            maxGap = max(maxGap, (link.timestamp - lastTimestamp) * 1000)
        }
        lastTimestamp = link.timestamp
        onFrame?(link.timestamp)
    }
}

struct ScriptError: Equatable, CustomStringConvertible {
    struct Frame: Equatable {
        let function: String
        let location: String
    }

    let message: String
    let frames: Array<Frame>

    var description: String {
        ([message] + frames.map { "  at \($0.function.isEmpty ? "<anonymous>" : $0.function) (\($0.location))" })
            .joined(separator: "\n")
    }
}

extension ScriptError {
    init(exception: JSValue, source: URL, map: SourceMap?) {
        let stack = exception.objectForKeyedSubscript("stack")
        let lines = stack?.isString == true ? stack?.toString().split(separator: "\n").map(String.init) ?? [] : []
        self.init(
            message: exception.toString() ?? "Unknown error",
            frames: lines.compactMap { Self.frame($0, source: source, map: map) })
    }

    static func frame(_ line: String, source: URL, map: SourceMap?) -> Frame? {
        guard let at = line.lastIndex(of: "@") else {
            return line == "[native code]" ? nil : Frame(function: line, location: "native")
        }
        let function = String(line[..<at])
        let parts = line[line.index(after: at)...].split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3, let lineNumber = Int(parts[parts.count - 2]), let column = Int(parts[parts.count - 1])
        else { return Frame(function: function, location: String(line[line.index(after: at)...])) }
        let file = parts.dropLast(2).joined(separator: ":")
        if file == source.absoluteString || file == source.path(), let mapped = map?.location(line: lineNumber, column: column) {
            return Frame(function: function, location: "\(clean(mapped.file)):\(mapped.line):\(mapped.column)")
        }
        let name = file.split(separator: "/").last.map(String.init) ?? file
        return Frame(function: function, location: "\(name):\(lineNumber):\(column)")
    }

    private static func clean(_ path: String) -> String {
        if let range = path.range(of: "node_modules/", options: .backwards) { return String(path[range.upperBound...]) }
        var path = Substring(path)
        while path.hasPrefix("../") || path.hasPrefix("./") {
            path = path.dropFirst(path.hasPrefix("../") ? 3 : 2)
        }
        return String(path)
    }
}
