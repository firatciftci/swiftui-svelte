import Foundation
import JavaScriptCore
import Observation
import QuartzCore

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
        .compactMap { $0 }
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

    context.setObject(commit, forKeyedSubscript: "__nativeCommit" as NSString)
    context.setObject(log, forKeyedSubscript: "__nativeLog" as NSString)
    context.setObject(setTimeout, forKeyedSubscript: "setTimeout" as NSString)
    context.setObject(setInterval, forKeyedSubscript: "setInterval" as NSString)
    context.setObject(clearTimer, forKeyedSubscript: "clearTimeout" as NSString)
    context.setObject(clearTimer, forKeyedSubscript: "clearInterval" as NSString)
    context.setObject(now, forKeyedSubscript: "__nativeNow" as NSString)
    context.setObject(collectGarbage, forKeyedSubscript: "__nativeGC" as NSString)
    context.setObject(stats, forKeyedSubscript: "__nativeStats" as NSString)
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
    let link = CADisplayLink(target: self, selector: #selector(tick))
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
