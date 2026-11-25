import SwiftUI

struct MotionCurve: Equatable {
    enum Kind: String {
        case `default`, linear, easeIn, easeOut, easeInOut, spring, bouncy, smooth, snappy
    }

    var kind = Kind.default
    var duration: Double?
    var bounce: Double?
    var delay = 0.0
    var speed = 1.0
    var repeatCount: Int?
    var autoreverses = true

    init() {}

    init?(_ value: JSONValue?) {
        switch value {
        case let .string(name):
            guard let kind = Kind(rawValue: name) else { return nil }
            self.kind = kind
        case let .object(options):
            if let name = options["type"]?.string {
                guard let kind = Kind(rawValue: name) else { return nil }
                self.kind = kind
            }
            duration = options["duration"]?.number.map { max($0, 0) / 1000 }
            bounce = options["bounce"]?.number.map { min(max($0, -1), 1) }
            delay = max(options["delay"]?.number ?? 0, 0) / 1000
            speed = options["speed"]?.number.flatMap { $0 > 0 ? $0 : nil } ?? 1
            switch options["repeat"] {
            case .bool(true): repeatCount = -1
            case let .number(count) where count >= 1: repeatCount = Int(count)
            default: break
            }
            autoreverses = options["autoreverses"]?.isTrue ?? true
        case .bool(true):
            break
        default:
            return nil
        }
    }

    var animation: Animation {
        var animation: Animation =
            switch kind {
            case .default: duration.map { .easeInOut(duration: $0) } ?? .default
            case .linear: .linear(duration: duration ?? 0.35)
            case .easeIn: .easeIn(duration: duration ?? 0.35)
            case .easeOut: .easeOut(duration: duration ?? 0.35)
            case .easeInOut: .easeInOut(duration: duration ?? 0.35)
            case .spring, .smooth: .spring(duration: duration ?? 0.5, bounce: bounce ?? 0)
            case .bouncy: .spring(duration: duration ?? 0.5, bounce: bounce ?? 0.3)
            case .snappy: .spring(duration: duration ?? 0.5, bounce: bounce ?? 0.15)
            }
        if delay > 0 { animation = animation.delay(delay) }
        if speed != 1 { animation = animation.speed(speed) }
        switch repeatCount {
        case -1: animation = animation.repeatForever(autoreverses: autoreverses)
        case let .some(count): animation = animation.repeatCount(count, autoreverses: autoreverses)
        case nil: break
        }
        return animation
    }
}

struct MotionTransition: Equatable {
    enum Part: Equatable {
        case opacity, scale, slide, blur
        case move(Edge)
        case push(Edge)
    }

    let parts: Array<Part>

    init?(_ value: JSONValue?) {
        guard let spec = value?.string else { return nil }
        var parts: Array<Part> = []
        for token in spec.split(whereSeparator: { $0 == " " || $0 == "+" || $0 == "," }) {
            let pieces = token.split(separator: "-", maxSplits: 1).map(String.init)
            let edge = pieces.count > 1 ? Self.edge(pieces[1]) : nil
            switch pieces[0] {
            case "opacity", "fade": parts.append(.opacity)
            case "scale": parts.append(.scale)
            case "slide": parts.append(.slide)
            case "blur": parts.append(.blur)
            case "move": parts.append(.move(edge ?? .bottom))
            case "push": parts.append(.push(edge ?? .trailing))
            default: continue
            }
        }
        guard !parts.isEmpty else { return nil }
        self.parts = parts
    }

    private static func edge(_ name: String) -> Edge? {
        switch name {
        case "top": .top
        case "bottom": .bottom
        case "leading": .leading
        case "trailing": .trailing
        default: nil
        }
    }

    var transition: AnyTransition {
        var result: AnyTransition?
        for part in parts {
            let next: AnyTransition =
                switch part {
                case .opacity: .opacity
                case .scale: .scale
                case .slide: .slide
                case .blur: AnyTransition(.blurReplace)
                case let .move(edge): .move(edge: edge)
                case let .push(edge): .push(from: edge)
                }
            result = result.map { $0.combined(with: next) } ?? next
        }
        return result ?? .identity
    }

    static func curve(for attributes: [String: JSONValue]) -> MotionCurve? {
        guard Self(attributes["transition"]) != nil || Self(attributes["in"]) != nil || Self(attributes["out"]) != nil
        else { return nil }
        return MotionCurve(attributes["animation"]) ?? MotionCurve()
    }

    static func transition(for attributes: [String: JSONValue]) -> AnyTransition? {
        let both = Self(attributes["transition"])
        let insertion = Self(attributes["in"]) ?? both
        let removal = Self(attributes["out"]) ?? both
        guard insertion != nil || removal != nil else { return nil }
        let curve = MotionCurve(attributes["animation"]) ?? MotionCurve()
        return AnyTransition.asymmetric(
            insertion: insertion?.transition ?? .identity,
            removal: removal?.transition ?? .identity
        )
        .animation(curve.animation)
    }
}
