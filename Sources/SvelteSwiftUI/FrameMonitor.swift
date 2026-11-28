import QuartzCore

#if os(macOS)
    import AppKit
#endif

final class FrameMonitor {
    private static let idleTicksBeforePausing = 30
    private(set) var link: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var idleTicks = 0
    var onFrame: ((CFTimeInterval, Double) -> Bool)?

    isolated deinit {
        link?.invalidate()
    }

    func resume() {
        idleTicks = 0
        if let link {
            link.isPaused = false
            return
        }
        let target = FrameTarget(monitor: self)
        #if os(macOS)
            guard let link = (NSScreen.main ?? NSScreen.screens.first)?.displayLink(target: target, selector: #selector(FrameTarget.tick))
            else { return }
        #else
            let link = CADisplayLink(target: target, selector: #selector(FrameTarget.tick))
        #endif
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        link?.invalidate()
        link = nil
        lastTimestamp = 0
        idleTicks = 0
    }

    func tick(_ link: CADisplayLink) {
        let gap = lastTimestamp > 0 ? (link.timestamp - lastTimestamp) * 1000 : 0
        lastTimestamp = link.timestamp
        if onFrame?(link.timestamp, gap) == true {
            idleTicks = 0
            return
        }
        idleTicks += 1
        guard idleTicks >= Self.idleTicksBeforePausing else { return }
        link.isPaused = true
        lastTimestamp = 0
    }
}

private final class FrameTarget: NSObject {
    private weak var monitor: FrameMonitor?

    init(monitor: FrameMonitor) {
        self.monitor = monitor
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let monitor else {
            link.invalidate()
            return
        }
        monitor.tick(link)
    }
}
