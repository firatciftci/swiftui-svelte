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

    private(set) var store: NodeStore
    private(set) var error: ScriptError?
    private(set) var diagnostics: Array<Diagnostic> = []
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
    @ObservationIgnored private(set) var queuedCalls: Array<(function: String, arguments: Array<ScriptArgument>)> = []
    @ObservationIgnored private var isFlushScheduled = false
    @ObservationIgnored var inputs = PendingInputs()
    @ObservationIgnored private var watchesFramesUntil: CFTimeInterval = 0
    @ObservationIgnored private var mounts: [Int: Mount] = [:]
    @ObservationIgnored private var nextMountID = 1
    @ObservationIgnored private var loadedVersion: String?
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var isRecovering = false
    @ObservationIgnored private var download: Task<Void, Never>?
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
    @ObservationIgnored private var renderedGeneration = 0
    var isCurrent: Bool { renderedGeneration == generation }
    @ObservationIgnored private var configurationWarnings: Array<String> = []
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
                configurationWarnings.append("The native module \(module.name) replaces another module with that name.")
            }
            self.modules[module.name] = module
        }
        for component in components {
            if NodeShape.isBuiltIn(component.name) {
                configurationWarnings.append(
                    "The native component \(component.name) never renders, because <\(component.name)> is a built-in element."
                )
            }
            self.components[component.name] = component
        }
        let diagnostics = Diagnostics()
        store = NodeStore(diagnostics: diagnostics)
        engine = ScriptEngine(storage: LocalStorage(name: storage ?? Self.storageName(for: source)), diagnostics: diagnostics)
        diagnostics.onReport { [weak self] diagnostic, generation in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.show(diagnostic, from: generation) } }
        }
        engine.onMessages { [weak self] in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.drain() } }
        }
        reportConfiguration()
    }

    isolated deinit {
        stop()
    }

    public func stop() {
        guard isStarted else { return }
        isStarted = false
        generation += 1
        download?.cancel()
        download = nil
        queuedCalls.removeAll()
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
        engine.sync { $0.stop() }
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
        queueInputs()
        let arguments: Array<JSONValue> = [JSONValue(id), .string(props)]
        call("__svelteProps", namesChanged ? arguments + [.string(Self.json(names))] : arguments)
    }

    func unmount(_ id: Int) {
        guard mounts.removeValue(forKey: id) != nil else { return }
        call("__svelteUnmount", [JSONValue(id)], waits: false)
    }

    private func arguments(for id: Int) -> Array<JSONValue> {
        guard let mount = mounts[id] else { return [] }
        return [
            JSONValue(id), .string(mount.component),
            .string("{\"props\":\(mount.props),\"actions\":\(Self.json(mount.actions.keys.sorted()))}"),
        ]
    }

    func drain() {
        receive()
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
            if renderedGeneration != generation {
                renderedGeneration = generation
                store.reset(ownedNames: ownedNames)
            }
            switch inbound.message {
            case let .commit(json, animation) where !isStopped:
                if store.apply(json, animation: animation) {
                    if isLoaded { isRecovering = false }
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
            case let .loaded(identity):
                bundleIdentity = identity
                loads += 1
                isLoaded = true
                for url in pendingURLs { deliver(url) }
                pendingURLs.removeAll()
            case let .failedToLoad(error):
                bundleIdentity = nil
                loads += 1
                report(error)
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
        var rect = JSONValue.null
        if let frame, frame.size != .zero {
            rect = [
                "x": JSONValue(frame.minX), "y": JSONValue(frame.minY), "width": JSONValue(frame.width), "height": JSONValue(frame.height),
            ]
        }
        call("__svelteReply", [JSONValue(request), rect], waits: false)
    }

    private func stopEngine() {
        engine.sync { $0.stop() }
    }

    private func perform(_ mount: Int, _ name: String, _ json: String) {
        guard let action = mounts[mount]?.actions[name] else { return }
        action((try? JSONValue(parsing: json)) ?? .null)
    }

    private func frame(_ timestamp: CFTimeInterval, gap: Double) -> Bool {
        engine.stats.withLock { $0.maxFrameGap = max($0.maxFrameGap, gap) }
        guard isFrameRequested else { return timestamp < watchesFramesUntil }
        isFrameRequested = false
        call("__svelteFrame", [JSONValue(timestamp * 1000)], waits: false)
        return true
    }

    func edit(_ node: Node, _ name: String, to value: JSONValue, event: String, payload: ScriptArgument? = nil) {
        node.setOwnAttribute(name, value)
        dispatch(node.id, event, argument: payload ?? .json(value), waits: true)
        let settled = node.ownAttributes[name]
        guard settled != value else { return }
        node.setOwnAttribute(name, value)
        Task { @MainActor in
            if node.ownAttributes[name] == value { node.setOwnAttribute(name, settled) }
        }
    }

    func receiveMemoryWarning() {
        guard isStarted else { return }
        call("__svelteAppEvent", ["memorywarning", .null], waits: false)
        let engine = engine
        engine.async { $0.collectGarbage() }
    }

    #if DEBUG
        static var launchRoute: URL? {
            guard let index = CommandLine.arguments.firstIndex(of: "-route"), CommandLine.arguments.indices.contains(index + 1) else {
                return nil
            }
            return URL(string: "route:" + CommandLine.arguments[index + 1])
        }
    #endif

    private func receive() {
        for (generation, message) in engine.takeMessages() { inbox.append(Inbound(generation: generation, message: message)) }
    }
}

extension SvelteRuntime {
    func dispatch(_ id: Int, _ type: String, _ payload: JSONValue = .null, waits: Bool = false) {
        dispatch(id, type, argument: .json(payload), waits: waits)
    }

    func dispatch(_ id: Int, _ type: String, argument: ScriptArgument, waits: Bool = false) {
        guard isCurrent else { return }
        queueInputs()
        call("__svelteDispatch", [.json(JSONValue(id)), .json(.string(type)), argument], waits: waits)
    }

    func submit(_ id: Int) {
        dispatch(id, "submit", waits: true)
    }

    func dispatchAndWait(_ id: Int, _ type: String) async {
        guard isCurrent else { return }
        queueInputs()
        requestSerial += 1
        let request = requestSerial
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                settlements[request] = continuation
                call("__svelteDispatch", [JSONValue(id), .string(type), .null, JSONValue(request)])
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelTask(request, of: id) }
        }
    }

    private func cancelTask(_ request: Int, of id: Int) {
        guard let continuation = settlements.removeValue(forKey: request) else { return }
        call("__svelteDispatch", [JSONValue(id), "taskcancel", JSONValue(request), .null])
        continuation.resume()
    }

    func call(_ function: String, _ arguments: Array<JSONValue>, waits: Bool = true) {
        call(function, arguments.map(ScriptArgument.json), waits: waits)
    }

    func call(_ function: String, _ arguments: Array<ScriptArgument>, waits: Bool = true) {
        queuedCalls.append((function, arguments))
        if waits, isCurrent {
            sendQueuedCalls()
        } else if !isFlushScheduled {
            isFlushScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                isFlushScheduled = false
                sendQueuedCalls(waits: false)
            }
        }
    }

    func sendQueuedCalls(waits: Bool = true) {
        guard !queuedCalls.isEmpty else { return }
        let calls = queuedCalls
        queuedCalls.removeAll()
        guard waits, isCurrent else {
            engine.async { engine in
                for call in calls { engine.call(call.function, call.arguments) }
            }
            return
        }
        engine.sync { engine in
            for call in calls { engine.call(call.function, call.arguments) }
        }
        drain()
    }
}

extension SvelteRuntime {
    public func reload() {
        isRecovering = false
        loadSource()
    }

    private func reload(ifNewerThan version: String) {
        guard download == nil, version != loadedVersion else { return }
        isRecovering = false
        loadSource()
    }

    private func loadSource() {
        download?.cancel()
        download = nil
        guard !source.isFileURL else {
            load(nil)
            return
        }
        let source = source
        download = Task {
            let result = await BundleLoader.download(source)
            guard !Task.isCancelled else { return }
            download = nil
            load(result)
        }
    }

    private func load(_ downloaded: Result<BundleLoader.Bundle, BundleLoader.Failure>?) {
        generation += 1
        isLoaded = false
        switch downloaded {
        case let .success(bundle): loadedVersion = bundle.version
        case .failure: break
        case nil: loadedVersion = BundleLoader.fileVersion(of: source)
        }
        isFrameRequested = false
        queuedCalls.removeAll()
        inputs = PendingInputs()
        for continuation in settlements.values { continuation.resume() }
        settlements.removeAll()
        measureRequests.removeAll()
        store.diagnostics.reset()
        diagnostics = []
        reportConfiguration()
        error = nil
        let mounts = self.mounts.keys.sorted().map { arguments(for: $0).map(ScriptArgument.json) }
        let environment = Self.json(environment)
        let source = source
        let generation = generation
        engine.async {
            $0.load(source, downloaded: downloaded, environment: environment, mounts: mounts, generation: generation)
        }
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
        call("__svelteAppEvent", ["openurl", .string(url.absoluteString)], waits: false)
    }

    func updateEnvironment(_ changes: [String: Any]) {
        var changed: [String: Any] = [:]
        for (key, value) in changes where !((environment[key] as? NSObject)?.isEqual(value) ?? false) {
            environment[key] = value
            changed[key] = value
        }
        guard !changed.isEmpty, isStarted else { return }
        call("__svelteEnvironment", [.string(Self.json(changed))], waits: false)
    }

    private static func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: .sortedKeys) else { return "{}" }
        return String(bytes: data, encoding: .utf8) ?? "{}"
    }

    private func reportConfiguration() {
        for warning in configurationWarnings { store.diagnostics.report(warning) }
    }

    private func show(_ diagnostic: Diagnostic, from generation: Int) {
        guard generation == store.diagnostics.generation else { return }
        diagnostics.append(diagnostic)
    }

    func dismissDiagnostics() {
        diagnostics = []
    }

    func report(_ error: ScriptError) {
        Diagnostics.javascript.error("\(String(describing: error), privacy: .public)")
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
        queueInputs()
        call("__svelteNativeEvent", [.string(module), .string(event), .null])
    }

    public func emit(_ event: String, from module: String, _ payload: some Encodable) {
        guard let data = try? NativeModule.encode(payload), let json = String(bytes: data, encoding: .utf8) else { return }
        queueInputs()
        call("__svelteNativeEvent", [.string(module), .string(event), .string(json)])
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
    let message: ScriptEngine.Message
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
