import Foundation
import JavaScriptCore
import Observation
import QuartzCore

#if os(macOS)
    import AppKit
#endif

@Observable
final class Runtime {
    private(set) var store = NodeStore()
    private(set) var error: String?

    @ObservationIgnored private var context: JSContext?
    @ObservationIgnored private var timers: [Int: Task<Void, Never>] = [:]
    @ObservationIgnored private var nextTimerID = 1
    @ObservationIgnored private var loadedVersion: Date?
    @ObservationIgnored private var watcher: Task<Void, Never>?
    @ObservationIgnored private let frames = FrameMonitor()
    @ObservationIgnored private let source: URL
    @ObservationIgnored private let reloadsOnChange: Bool

    init(source: URL, reloadsOnChange: Bool) {
        self.source = source
        self.reloadsOnChange = reloadsOnChange
    }

    private var bundleVersion: Date? {
        try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    func start() {
        guard context == nil else { return }
        frames.start()
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

    func dispatch(_ id: Int, _ type: String, _ payload: Any = NSNull()) {
        context?.objectForKeyedSubscript("__svelteDispatch")?
            .call(withArguments: [id, type, payload])
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

    private func reload() {
        for timer in timers.values { timer.cancel() }
        timers = [:]
        store = NodeStore()
        error = nil
        loadedVersion = bundleVersion

        guard let script = try? String(contentsOf: source, encoding: .utf8),
            let context = JSContext()
        else {
            error = "Couldn't load \(source.path())."
            return
        }

        #if DEBUG
            context.isInspectable = true
        #endif
        context.exceptionHandler = { [weak self] _, exception in
            let message = [exception?.toString(), exception?.objectForKeyedSubscript("stack")?.toString()]
                .compactMap(\.self)
                .joined(separator: "\n")
            print("[js:exception] \(message)")
            self?.error = message
        }
        install(into: context)
        self.context = context
        context.evaluateScript(script, withSourceURL: source)
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
        context.globalObject.setValue(stats, forProperty: "__nativeStats")

        let storageKey = "SvelteSwiftUI.localStorage"
        let loadStorage: @convention(block) () -> String = {
            UserDefaults.standard.string(forKey: storageKey) ?? "{}"
        }
        let saveStorage: @convention(block) (String) -> Void = { json in
            UserDefaults.standard.set(json, forKey: storageKey)
        }
        let fetch: @convention(block) (String, JSValue) -> Void = { json, callback in
            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(for: Self.request(from: json))
                    var headers: [String: String] = [:]
                    for (name, value) in (response as? HTTPURLResponse)?.allHeaderFields ?? [:] {
                        headers[String(describing: name).lowercased()] = String(describing: value)
                    }
                    let result: [String: Any] = [
                        "status": (response as? HTTPURLResponse)?.statusCode ?? 200,
                        "url": response.url?.absoluteString ?? "",
                        "headers": headers,
                        "body": String(bytes: data, encoding: .utf8) ?? "",
                    ]
                    callback.call(withArguments: [NSNull(), result])
                } catch {
                    callback.call(withArguments: [error.localizedDescription])
                }
            }
        }
        context.globalObject.setValue(loadStorage, forProperty: "__nativeStorageLoad")
        context.globalObject.setValue(saveStorage, forProperty: "__nativeStorageSave")
        context.globalObject.setValue(fetch, forProperty: "__nativeFetch")
    }

    private struct FetchRequest: Decodable {
        let url: String
        let method: String?
        let headers: [String: String]?
        let body: String?
    }

    private static func request(from json: String) throws -> URLRequest {
        let fetch = try JSONDecoder().decode(FetchRequest.self, from: Data(json.utf8))
        guard let url = URL(string: fetch.url) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = fetch.method ?? "GET"
        for (name, value) in fetch.headers ?? [:] {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.httpBody = fetch.body.map { Data($0.utf8) }
        return request
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

    func start() {
        guard link == nil else { return }
        #if os(macOS)
            guard let link = NSScreen.main?.displayLink(target: self, selector: #selector(tick)) else { return }
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
    }
}
