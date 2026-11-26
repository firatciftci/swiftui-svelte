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
        var actions: [String: @MainActor (Any) -> Void]
    }

    private(set) var store = NodeStore()
    private(set) var error: ScriptError?
    private(set) var appearance: ColorScheme?
    private(set) var scrollRequest: ScrollRequest?
    private(set) var scrollOffsetRequest: ScrollOffsetRequest?

    @ObservationIgnored let engine: ScriptEngine
    @ObservationIgnored private var isStarted = false
    @ObservationIgnored private var isFrameRequested = false
    @ObservationIgnored private var mounts: [Int: Mount] = [:]
    @ObservationIgnored private var nextMountID = 1
    @ObservationIgnored private var loadedVersion: String?
    @ObservationIgnored private var isLoaded = false
    @ObservationIgnored private var isRecovering = false
    @ObservationIgnored private var isDownloading = false
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private let frames = FrameMonitor()
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
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let reloadsOnChange: Bool

    public init(
        source: URL,
        reloadsOnChange: Bool = false,
        modules: Array<NativeModule> = [],
        components: Array<NativeComponent> = []
    ) {
        self.source = source
        self.reloadsOnChange = reloadsOnChange
        for module in BuiltInModules.all + modules { self.modules[module.name] = module }
        for component in components { self.components[component.name] = component }
        let drain = Unchecked(value: WeakBox<SvelteRuntime>())
        engine = ScriptEngine {
            DispatchQueue.main.async { MainActor.assumeIsolated { drain.value.object?.drain() } }
        }
        drain.value.object = self
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
        reload()
        guard reloadsOnChange else { return }
        let source = source
        let initial = loadedVersion
        watcher = Task.detached { [weak self] in
            var seen = initial
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let version = await BundleLoader.version(of: source), version != seen else { continue }
                seen = version
                await self?.reload(ifNewerThan: version)
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

    func dispatchAndWait(_ id: Int, _ type: String, _ payload: Any = NSNull()) async {
        requestSerial += 1
        let request = requestSerial
        await withCheckedContinuation { continuation in
            settlements[request] = continuation
            call("__svelteDispatch", [id, type, payload, request])
        }
    }

    func runTask(_ id: Int) async {
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

    func drain() {
        let messages = engine.takeMessages()
        guard !messages.isEmpty else { return }
        let start = CACurrentMediaTime()
        let generation = generation
        var isStopped = false
        for message in messages {
            guard generation == self.generation else { break }
            switch message {
            case let .commit(json, animation) where !isStopped:
                if !store.apply(json, animation: animation) {
                    if isRecovering {
                        stopEngine()
                        isStopped = true
                    } else {
                        isRecovering = true
                        reload()
                    }
                }
            case let .action(mount, name, json) where !isStopped: perform(mount, name, json)
            case let .invoke(id, method, json) where !isStopped: invoke(id, method, json)
            case let .nativeCall(id, module, method, json) where !isStopped: callModule(id, module, method, json)
            case .requestFrame where !isStopped: isFrameRequested = true
            case let .error(error): report(error)
            default: break
            }
        }
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
            if let frame = node.frame {
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

    public func emit(_ event: String, from module: String) {
        call("__svelteNativeEvent", [module, event, NSNull()])
    }

    public func emit(_ event: String, from module: String, _ payload: some Encodable) {
        guard let data = try? NativeModule.encode(payload), let json = String(bytes: data, encoding: .utf8) else { return }
        call("__svelteNativeEvent", [module, event, json])
    }

    private func callModule(_ id: Int, _ module: String, _ method: String, _ json: String) {
        guard let registered = modules[module] else {
            let error = NativeModuleError(code: "unknownModule", message: "There's no native module named \(module).")
            replyToCall(id, error: error, result: nil)
            return
        }
        guard let handler = registered.functions[method] else {
            let error = NativeModuleError(code: "unknownFunction", message: "There's no native function \(module).\(method).")
            replyToCall(id, error: error, result: nil)
            return
        }
        let generation = generation
        Task {
            let outcome: Result<Data?, NativeModuleError>
            do {
                outcome = .success(try await handler(Data(json.utf8)))
            } catch let error as NativeModuleError {
                outcome = .failure(error)
            } catch {
                outcome = .failure(NativeModuleError(code: "native", message: error.localizedDescription))
            }
            guard generation == self.generation else { return }
            switch outcome {
            case let .success(data): replyToCall(id, error: nil, result: data)
            case let .failure(error): replyToCall(id, error: error, result: nil)
            }
        }
    }

    private func replyToCall(_ id: Int, error: NativeModuleError?, result: Data?) {
        let errorJSON = error.map { error in
            (try? JSONEncoder().encode(["code": error.code, "message": error.message])).flatMap {
                String(bytes: $0, encoding: .utf8)
            } ?? #"{"code":"native","message":"The native error couldn't be encoded."}"#
        }
        let resultJSON = result.flatMap { String(bytes: $0, encoding: .utf8) }
        call("__svelteNativeReply", [id, errorJSON ?? NSNull(), resultJSON ?? NSNull()])
    }

    func restart() {
        isRecovering = false
        reload()
    }

    private func reload(ifNewerThan version: String) {
        guard !isDownloading, version != loadedVersion else { return }
        isRecovering = false
        reload()
    }

    private func reload() {
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
            report(ScriptError(message: failure.message, frames: []))
            return
        }
        loadedVersion = bundle.version
        let map = bundle.map.flatMap { try? SourceMap(json: $0) }
        let mounts = self.mounts.keys.sorted().map { Unchecked(value: arguments(for: $0)) }
        let environment = Self.json(environment)
        let source = source
        let script = bundle.script
        engine.queue.sync {
            engine.load(script: script, source: source, map: map, environment: environment, mounts: mounts)
        }
        isLoaded = true
        for url in pendingURLs { deliver(url) }
        pendingURLs.removeAll()
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
