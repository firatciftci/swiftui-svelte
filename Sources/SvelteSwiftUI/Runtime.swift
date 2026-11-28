import Foundation
import JavaScriptCore
import Network
import Observation
import QuartzCore
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

@Observable
public final class SvelteRuntime {
    private struct Mount {
        let component: String
        var props: String
        var actions: [String: @MainActor (JSONValue) -> Void]
    }

    private(set) var store = NodeStore()
    private(set) var error: ScriptError?
    private(set) var appearance: ColorScheme?
    private(set) var scrollRequest: ScrollRequest?
    private(set) var scrollOffsetRequest: ScrollOffsetRequest?
    private(set) var bundleIdentity: BundleIdentity?
    private(set) var loads = 0

    @ObservationIgnored let engine: ScriptEngine
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isFrameRequested = false
    @ObservationIgnored private var inbox: Array<Inbound> = []
    @ObservationIgnored private var isDraining = false
    @ObservationIgnored var inputs = PendingInputs()
    @ObservationIgnored private var watchesFramesUntil: CFTimeInterval = 0
    @ObservationIgnored private var mounts: [Int: Mount] = [:]
    @ObservationIgnored private var nextMountID = 1
    @ObservationIgnored private var loadedVersion: String?
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var isRecovering = false
    @ObservationIgnored private var isDownloading = false
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored let frames = FrameMonitor()
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var memoryObserver: (any NSObjectProtocol)?
    @ObservationIgnored private var pendingURLs: Array<URL> = []
    @ObservationIgnored private var measureRequests: [Int: Array<Int>] = [:]
    @ObservationIgnored private var requestSerial = 0
    @ObservationIgnored private var settlements: [Int: CheckedContinuation<Void, Never>] = [:]
    @ObservationIgnored private var environment = HostEnvironment.current
    @ObservationIgnored private let source: URL
    @ObservationIgnored private(set) var modules: [String: NativeModule] = [:]
    @ObservationIgnored private(set) var components: [String: NativeComponent] = [:]
    private var ownedNames: [String: Set<String>] { components.mapValues(\.owned) }
    @ObservationIgnored private(set) var generation = 0
    @ObservationIgnored private let reloadsOnChange: Bool
    @ObservationIgnored public var onError: (@MainActor (ScriptError) -> Void)?

    public init(
        source: URL,
        reloadsOnChange: Bool = false,
        storage: String? = nil,
        modules: Array<NativeModule> = [],
        components: Array<NativeComponent> = [],
        onError: (@MainActor (ScriptError) -> Void)? = nil
    ) {
        self.source = source
        self.reloadsOnChange = reloadsOnChange
        self.onError = onError
        for module in BuiltInModules.all { self.modules[module.name] = module }
        for module in modules {
            if self.modules[module.name] != nil {
                print("[svelte] The native module \(module.name) replaces another module with that name.")
            }
            self.modules[module.name] = module
        }
        for component in components {
            if NodeShape.isBuiltIn(component.name) {
                print("[svelte] The native component \(component.name) never renders, because <\(component.name)> is a built-in element.")
            }
            self.components[component.name] = component
        }
        let drain = Unchecked(value: WeakBox<SvelteRuntime>())
        engine = ScriptEngine(storage: LocalStorage(name: storage ?? Self.storageName(for: source))) {
            DispatchQueue.main.async { MainActor.assumeIsolated { drain.value.object?.drain() } }
        }
        drain.value.object = self
    }

    isolated deinit {
        stop()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        generation += 1
        watcher?.cancel()
        watcher = nil
        pathMonitor?.cancel()
        pathMonitor = nil
        if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) }
        memoryObserver = nil
        frames.stop()
        isFrameRequested = false
        for continuation in settlements.values { continuation.resume() }
        settlements.removeAll()
        measureRequests.removeAll()
        inbox.removeAll()
        let engine = engine
        engine.queue.sync { engine.stop() }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        frames.onFrame = { [weak self] timestamp, gap in self?.frame(timestamp, gap: gap) ?? false }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in self?.updateEnvironment(["onLine": isOnline]) }
        }
        monitor.start(queue: .main)
        pathMonitor = monitor
        #if canImport(UIKit) && !os(watchOS)
            memoryObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.receiveMemoryWarning() }
            }
        #endif
        #if DEBUG
            if let route = Self.launchRoute { pendingURLs.insert(route, at: 0) }
        #endif
        loadSource()
        guard reloadsOnChange else { return }
        let source = source
        let initial = loadedVersion
        watcher = Task.detached { [weak self] in
            var seen = initial
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let version = await BundleLoader.version(of: source, after: seen), version != seen else { continue }
                seen = version
                await self?.reload(ifNewerThan: version)
            }
        }
    }

    func mount(_ component: String, props: String, actions: [String: @MainActor (JSONValue) -> Void]) -> Int {
        let id = nextMountID
        nextMountID += 1
        mounts[id] = Mount(component: component, props: props, actions: actions)
        if isStarted { call("__svelteMount", arguments(for: id)) } else { start() }
        return id
    }

    func update(_ id: Int, props: String, actions: [String: @MainActor (JSONValue) -> Void]) {
        guard let mount = mounts[id] else { return }
        mounts[id]?.actions = actions
        let names = actions.keys.sorted()
        let namesChanged = names != mount.actions.keys.sorted()
        guard mount.props != props || namesChanged else { return }
        mounts[id]?.props = props
        flushInputs(waits: true)
        call("__svelteProps", namesChanged ? [id, props, Self.json(names)] : [id, props])
    }

    func unmount(_ id: Int) {
        guard mounts.removeValue(forKey: id) != nil else { return }
        call("__svelteUnmount", [id], waits: false)
    }

    private func arguments(for id: Int) -> Array<Any> {
        guard let mount = mounts[id] else { return [] }
        return [id, mount.component, "{\"props\":\(mount.props),\"actions\":\(Self.json(mount.actions.keys.sorted()))}"]
    }

    func dispatch(_ id: Int, _ type: String, _ payload: Any = NSNull(), waits: Bool = true) {
        flushInputs(waits: waits)
        call("__svelteDispatch", [id, type, payload], waits: waits)
    }

    func dispatchAndWait(_ id: Int, _ type: String, _ payload: Any = NSNull()) async {
        flushInputs(waits: true)
        requestSerial += 1
        let request = requestSerial
        await withCheckedContinuation { continuation in
            settlements[request] = continuation
            call("__svelteDispatch", [id, type, payload, request])
        }
    }

    func runTask(_ id: Int) async {
        flushInputs(waits: true)
        requestSerial += 1
        let request = requestSerial
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                settlements[request] = continuation
                call("__svelteDispatch", [id, "task", NSNull(), request])
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelTask(request, of: id) }
        }
    }

    private func cancelTask(_ request: Int, of id: Int) {
        guard let continuation = settlements.removeValue(forKey: request) else { return }
        call("__svelteDispatch", [id, "taskcancel", request, NSNull()])
        continuation.resume()
    }

    func call(_ function: String, _ arguments: Array<Any>, waits: Bool = true) {
        let engine = engine
        let arguments = Unchecked(value: arguments)
        if waits {
            engine.queue.sync { engine.call(function, arguments) }
            drain()
        } else {
            engine.queue.async { engine.call(function, arguments) }
        }
    }

    func drain() {
        receive(isInitial: false)
        guard !isDraining, !inbox.isEmpty else { return }
        isDraining = true
        defer { isDraining = false }
        let start = CACurrentMediaTime()
        var isStopped = false
        var index = 0
        while index < inbox.count {
            let inbound = inbox[index]
            index += 1
            guard inbound.generation == generation else { continue }
            switch inbound.message {
            case let .commit(json, animation) where !isStopped:
                if store.apply(json, animation: animation) {
                    if !inbound.isInitial { isRecovering = false }
                } else {
                    onError?(ScriptError(kind: .bridge, message: store.error ?? "The bundle sent a malformed batch.", frames: []))
                    if isRecovering {
                        stopEngine()
                        isStopped = true
                    } else {
                        isRecovering = true
                        loadSource()
                    }
                }
            case let .action(mount, name, json) where !isStopped: perform(mount, name, json)
            case let .invoke(id, method, json) where !isStopped: invoke(id, method, json)
            case let .nativeCall(id, module, method, json) where !isStopped: callModule(id, module, method, json)
            case .requestFrame where !isStopped:
                isFrameRequested = true
                frames.resume()
            case .watchFrames:
                watchesFramesUntil = CACurrentMediaTime() + 2
                frames.resume()
            case let .error(error): report(error)
            default: break
            }
        }
        inbox.removeAll()
        for id in measureRequests.keys where store.node(id) == nil {
            for request in measureRequests.removeValue(forKey: id) ?? [] { reply(request, frame: nil) }
        }
        let nodes = store.nodeCount
        let elapsed = (CACurrentMediaTime() - start) * 1000
        engine.stats.withLock { stats in
            stats.nodes = nodes
            stats.applyTime += elapsed
        }
    }

    private func invoke(_ id: Int, _ method: String, _ json: String) {
        let options =
            (try? JSONValue(parsing: json)).flatMap { value -> [String: JSONValue]? in
                if case let .object(options) = value { options } else { nil }
            } ?? [:]
        let request = options["request"]?.number.map { Int($0) }
        if method == "settled" {
            if let request { settlements.removeValue(forKey: request)?.resume() }
            return
        }
        if method == "announce" {
            Accessibility.announce(options["message"]?.string, priority: options["priority"]?.string)
            return
        }
        if method == "colorScheme" {
            appearance =
                switch options["value"]?.string {
                case "light": .light
                case "dark": .dark
                default: nil
                }
            return
        }
        guard let node = store.node(id) else {
            if let request { reply(request, frame: nil) }
            return
        }
        requestSerial += 1
        switch method {
        case "focus", "blur":
            node.focusRequest = FocusRequest(isFocused: method == "focus", serial: requestSerial)
        case "scrollIntoView":
            scroll(to: id, anchor: UnitPoint(anchor: options["anchor"]?.string), options)
        case "scrollTo" where options["edge"] == nil:
            scrollOffsetRequest = ScrollOffsetRequest(
                container: id, x: options["x"]?.number, y: options["y"]?.number, isAnimated: isAnimated(options), serial: requestSerial)
        case "scrollTo":
            let isBottom = options["edge"]?.string == "bottom"
            let children = node.renderedChildren
            guard let target = isBottom ? children.last : children.first else { return }
            scroll(to: target.id, anchor: isBottom ? .bottom : .top, options)
        case "measure":
            guard let request else { return }
            if let frame = node.frame, frame.size != .zero {
                reply(request, frame: frame)
            } else {
                measureRequests[id, default: []].append(request)
                node.isMeasured = true
            }
        default:
            break
        }
    }

    private func scroll(to target: Int, anchor: UnitPoint?, _ options: [String: JSONValue]) {
        scrollRequest = ScrollRequest(target: target, anchor: anchor, isAnimated: isAnimated(options), serial: requestSerial)
    }

    private func isAnimated(_ options: [String: JSONValue]) -> Bool {
        options["animated"].map { $0 != .bool(false) } ?? true
    }

    func measured(_ node: Node, frame: CGRect) {
        node.frame = frame
        guard frame.size != .zero else { return }
        for request in measureRequests.removeValue(forKey: node.id) ?? [] { reply(request, frame: frame) }
    }

    private func reply(_ request: Int, frame: CGRect?) {
        var rect: Any = NSNull()
        if let frame, frame.size != .zero {
            rect = ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
        }
        call("__svelteReply", [request, rect], waits: false)
    }

    private func stopEngine() {
        let engine = engine
        engine.queue.sync { engine.stop() }
    }

    private func perform(_ mount: Int, _ name: String, _ json: String) {
        guard let action = mounts[mount]?.actions[name] else { return }
        action((try? JSONValue(parsing: json)) ?? .null)
    }

    private func frame(_ timestamp: CFTimeInterval, gap: Double) -> Bool {
        engine.stats.withLock { $0.maxFrameGap = max($0.maxFrameGap, gap) }
        guard isFrameRequested else { return timestamp < watchesFramesUntil }
        isFrameRequested = false
        call("__svelteFrame", [timestamp * 1000], waits: false)
        return true
    }

    func edit(_ node: Node, _ name: String, to value: JSONValue, event: String, payload: Any) {
        node.setOwnAttribute(name, value)
        dispatch(node.id, event, payload)
        let settled = node.ownAttributes[name]
        guard settled != value else { return }
        node.setOwnAttribute(name, value)
        Task { @MainActor in
            if node.ownAttributes[name] == value { node.setOwnAttribute(name, settled) }
        }
    }

    func receiveMemoryWarning() {
        guard isStarted else { return }
        call("__svelteAppEvent", ["memorywarning", NSNull()], waits: false)
        let engine = engine
        engine.queue.async { engine.collectGarbage() }
    }

    #if DEBUG
        static var launchRoute: URL? {
            guard let index = CommandLine.arguments.firstIndex(of: "-route"), CommandLine.arguments.indices.contains(index + 1) else {
                return nil
            }
            return URL(string: "route:" + CommandLine.arguments[index + 1])
        }
    #endif

    private func receive(isInitial: Bool) {
        let generation = generation
        for message in engine.takeMessages() { inbox.append(Inbound(generation: generation, isInitial: isInitial, message: message)) }
    }
}

extension SvelteRuntime {
    public func reload() {
        isRecovering = false
        loadSource()
    }

    private func reload(ifNewerThan version: String) {
        guard !isDownloading, version != loadedVersion else { return }
        isRecovering = false
        loadSource()
    }

    private func loadSource() {
        generation += 1
        isLoaded = false
        guard !source.isFileURL else {
            load(BundleLoader.load(source))
            return
        }
        let generation = generation
        let source = source
        isDownloading = true
        Task {
            let result = await BundleLoader.download(source)
            guard generation == self.generation else { return }
            isDownloading = false
            load(result)
        }
    }

    private func load(_ result: Result<BundleLoader.Bundle, BundleLoader.Failure>) {
        isFrameRequested = false
        for continuation in settlements.values { continuation.resume() }
        settlements.removeAll()
        for request in measureRequests.values.joined() { reply(request, frame: nil) }
        measureRequests.removeAll()
        store.reset(ownedNames: ownedNames)
        error = nil
        let engine = engine
        let bundle: BundleLoader.Bundle
        switch result {
        case let .success(loaded):
            bundle = loaded
        case let .failure(failure):
            engine.queue.sync { engine.stop() }
            bundleIdentity = nil
            loads += 1
            report(ScriptError(kind: .load, message: failure.message, frames: []))
            return
        }
        loadedVersion = bundle.version
        let map = bundle.map.flatMap { try? SourceMap(json: $0) }
        let mounts = self.mounts.keys.sorted().map { Unchecked(value: arguments(for: $0)) }
        let environment = Self.json(environment)
        let source = source
        let script = bundle.script
        bundleIdentity = engine.queue.sync {
            engine.load(script: script, source: source, map: map, environment: environment, mounts: mounts)
        }
        loads += 1
        receive(isInitial: true)
        isLoaded = true
        for url in pendingURLs { deliver(url) }
        pendingURLs.removeAll()
        drain()
    }
}

extension SvelteRuntime {
    public func open(_ url: URL) {
        if isLoaded {
            deliver(url)
        } else if !pendingURLs.contains(url) {
            pendingURLs.append(url)
        }
    }

    func open(_ url: URL, from mount: Int?) {
        if let mount, let first = mounts.keys.min(), mount != first { return }
        open(url)
    }

    private func deliver(_ url: URL) {
        call("__svelteAppEvent", ["openurl", url.absoluteString], waits: false)
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

    private static func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys) else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }

    func report(_ error: ScriptError) {
        print("[js:exception] \(error)")
        self.error = error
        onError?(error)
    }

    func dismissError() {
        error = nil
        store.dismissError()
    }

    var currentError: ScriptError? {
        error ?? store.error.map { ScriptError(kind: .bridge, message: $0, frames: []) }
    }

    func phase(of mount: Int?, isOverdue: Bool) -> MountPhase {
        if !store.isCompatible { return .incompatible }
        if let root = store.root(for: mount) { return .mounted(root) }
        if let currentError { return .failed(currentError) }
        return isOverdue ? .unresponsive : .loading
    }

    public func emit(_ event: String, from module: String) {
        flushInputs(waits: true)
        call("__svelteNativeEvent", [module, event, NSNull()])
    }

    public func emit(_ event: String, from module: String, _ payload: some Encodable) {
        guard let data = try? NativeModule.encode(payload), let json = String(bytes: data, encoding: .utf8) else { return }
        flushInputs(waits: true)
        call("__svelteNativeEvent", [module, event, json])
    }
}

enum MountPhase {
    case loading
    case mounted(Node)
    case incompatible
    case failed(ScriptError)
    case unresponsive
}

private struct Inbound {
    let generation: Int
    let isInitial: Bool
    let message: ScriptEngine.Message
}

nonisolated private final class WeakBox<Object: AnyObject> {
    weak var object: Object?
}

public nonisolated struct ScriptError: Error, Equatable, Sendable, CustomStringConvertible {
    public enum Kind: Sendable {
        case script
        case bridge
        case load
    }

    public struct Frame: Equatable, Sendable {
        public let function: String
        public let location: String
    }

    public let kind: Kind
    public let message: String
    public let frames: Array<Frame>

    init(kind: Kind = .script, message: String, frames: Array<Frame>) {
        self.kind = kind
        self.message = message
        self.frames = frames
    }

    public var description: String {
        ([message] + frames.map { "  at \($0.function.isEmpty ? "<anonymous>" : $0.function) (\($0.location))" })
            .joined(separator: "\n")
    }
}

nonisolated extension ScriptError {
    init(exception: JSValue, kind: Kind = .script, source: URL, map: SourceMap?) {
        let stack = exception.objectForKeyedSubscript("stack")
        let lines = stack?.isString == true ? stack?.toString().split(separator: "\n").map(String.init) ?? [] : []
        self.init(
            kind: kind,
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
        if file == source.absoluteString || file == source.path(percentEncoded: false),
            let mapped = map?.location(line: lineNumber, column: column)
        {
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
