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

    @ObservationIgnored private let engine: ScriptEngine
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isFrameRequested = false
    @ObservationIgnored private var mounts: [Int: Mount] = [:]
    @ObservationIgnored private var nextMountID = 1
    @ObservationIgnored private var loadedVersion: Date?
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private let frames = FrameMonitor()
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var environment = HostEnvironment.current
    @ObservationIgnored private let source: URL
    @ObservationIgnored private let reloadsOnChange: Bool

    public init(source: URL, reloadsOnChange: Bool = false) {
        self.source = source
        self.reloadsOnChange = reloadsOnChange
        let drain = Unchecked(value: WeakBox<SvelteRuntime>())
        engine = ScriptEngine {
            DispatchQueue.main.async { MainActor.assumeIsolated { drain.value.object?.drain() } }
        }
        drain.value.object = self
    }

    private var bundleVersion: Date? {
        try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        frames.onFrame = { [weak self] timestamp, gap in self?.frame(timestamp, gap: gap) }
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
        if isStarted { call("__svelteMount", arguments(for: id)) } else { start() }
        return id
    }

    func update(_ id: Int, props: String, actions: [String: @MainActor (Any) -> Void]) {
        guard let mount = mounts[id] else { return }
        mounts[id]?.actions = actions
        guard mount.props != props else { return }
        mounts[id]?.props = props
        call("__svelteProps", [id, props])
    }

    func unmount(_ id: Int) {
        guard mounts.removeValue(forKey: id) != nil else { return }
        call("__svelteUnmount", [id], waits: false)
    }

    private func arguments(for id: Int) -> Array<Any> {
        guard let mount = mounts[id] else { return [] }
        let actions = mount.actions.keys.sorted().map { "\"\($0)\"" }.joined(separator: ",")
        return [id, mount.component, "{\"props\":\(mount.props),\"actions\":[\(actions)]}"]
    }

    func dispatch(_ id: Int, _ type: String, _ payload: Any = NSNull(), waits: Bool = true) {
        call("__svelteDispatch", [id, type, payload], waits: waits)
    }

    private func call(_ function: String, _ arguments: Array<Any>, waits: Bool = true) {
        let engine = engine
        let arguments = Unchecked(value: arguments)
        if waits {
            engine.queue.sync { engine.call(function, arguments) }
            drain()
        } else {
            engine.queue.async { engine.call(function, arguments) }
        }
    }

    func settle() {
        engine.queue.sync {}
        drain()
    }

    func evaluate<Result>(_ body: (JSContext) -> Result) -> Result? {
        let engine = engine
        let result = engine.queue.sync { engine.evaluate(body) }
        drain()
        return result
    }

    private func drain() {
        let messages = engine.takeMessages()
        guard !messages.isEmpty else { return }
        let start = CACurrentMediaTime()
        for message in messages {
            switch message {
            case let .commit(json): store.apply(json)
            case let .action(mount, name, json): perform(mount, name, json)
            case let .error(error): report(error)
            case .requestFrame: isFrameRequested = true
            }
        }
        let nodes = store.nodeCount
        let elapsed = (CACurrentMediaTime() - start) * 1000
        engine.stats.withLock { stats in
            stats.nodes = nodes
            stats.applyTime += elapsed
        }
    }

    private func perform(_ mount: Int, _ name: String, _ json: String) {
        guard let action = mounts[mount]?.actions[name] else { return }
        let value = (try? JSONValue(parsing: json)) ?? .null
        action(value.object)
    }

    private func frame(_ timestamp: CFTimeInterval, gap: Double) {
        engine.stats.withLock { $0.maxFrameGap = max($0.maxFrameGap, gap) }
        guard isFrameRequested else { return }
        isFrameRequested = false
        call("__svelteFrame", [timestamp * 1000], waits: false)
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
        guard !changed.isEmpty, isStarted else { return }
        call("__svelteEnvironment", [Self.json(changed)], waits: false)
    }

    private static func json(_ value: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys) else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
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
        isFrameRequested = false
        store = NodeStore()
        error = nil
        loadedVersion = bundleVersion
        let engine = engine
        guard let script = try? String(contentsOf: source, encoding: .utf8) else {
            engine.queue.sync { engine.stop() }
            _ = engine.takeMessages()
            report(ScriptError(message: "Couldn't load \(source.path()).", frames: []))
            return
        }
        let map = (try? Data(contentsOf: source.appendingPathExtension("map"))).flatMap { try? SourceMap(json: $0) }
        let mounts = self.mounts.keys.sorted().map { Unchecked(value: arguments(for: $0)) }
        let environment = Self.json(environment)
        let source = source
        engine.queue.sync {
            engine.load(script: script, source: source, map: map, environment: environment, mounts: mounts)
        }
        drain()
    }
}

nonisolated private final class WeakBox<Object: AnyObject> {
    weak var object: Object?
}

private final class FrameMonitor: NSObject {
    private var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    var onFrame: ((CFTimeInterval, Double) -> Void)?

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

    @objc private func tick(_ link: CADisplayLink) {
        let gap = lastTimestamp > 0 ? (link.timestamp - lastTimestamp) * 1000 : 0
        lastTimestamp = link.timestamp
        onFrame?(link.timestamp, gap)
    }
}

nonisolated struct ScriptError: Equatable, Sendable, CustomStringConvertible {
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

nonisolated extension ScriptError {
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
