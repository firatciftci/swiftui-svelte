import SwiftUI

struct ShapeElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let corners: RoundedCornerStyle = attributes["corners"]?.string == "circular" ? .circular : .continuous
        switch node.name {
        case "roundedrectangle":
            draw(RoundedRectangle(cornerRadius: attributes["cornerradius"]?.number ?? 8, style: corners))
        case "unevenroundedrectangle":
            draw(
                UnevenRoundedRectangle(
                    cornerRadii: RectangleCornerRadii(
                        topLeading: attributes["topleading"]?.number ?? 0,
                        bottomLeading: attributes["bottomleading"]?.number ?? 0,
                        bottomTrailing: attributes["bottomtrailing"]?.number ?? 0,
                        topTrailing: attributes["toptrailing"]?.number ?? 0
                    ),
                    style: corners
                ))
        case "circleshape":
            draw(Circle())
        case "ellipseshape":
            draw(Ellipse())
        case "capsule":
            draw(Capsule(style: corners))
        case "pathshape":
            draw(
                SVGShape(
                    path: SVGPathCache.path(attributes["d"]?.string ?? ""),
                    viewBox: SVGShape.viewBox(attributes["viewbox"]?.string)
                ))
        default:
            draw(Rectangle())
        }
    }

    @ViewBuilder private func draw(_ shape: some Shape) -> some View {
        let attributes = node.attributes
        let fillStyle = FillStyle(eoFill: attributes["fillrule"]?.string == "evenodd")
        let fill = Palette.style(attributes["fill"])
        if let stroke = Palette.style(attributes["stroke"]) {
            let strokeStyle = Self.strokeStyle(attributes)
            if let fill {
                shape.fill(fill, style: fillStyle).stroke(stroke, style: strokeStyle)
            } else {
                shape.stroke(stroke, style: strokeStyle)
            }
        } else if let fill {
            shape.fill(fill, style: fillStyle)
        } else {
            shape.fill(style: fillStyle)
        }
    }

    static func strokeStyle(_ attributes: [String: JSONValue]) -> StrokeStyle {
        var dash: Array<CGFloat> = []
        if case let .array(values) = attributes["dash"] {
            for value in values { if let length = value.number { dash.append(CGFloat(length)) } }
        }
        let cap: CGLineCap =
            switch attributes["linecap"]?.string {
            case "round": .round
            case "square": .square
            default: .butt
            }
        let join: CGLineJoin =
            switch attributes["linejoin"]?.string {
            case "round": .round
            case "bevel": .bevel
            default: .miter
            }
        return StrokeStyle(
            lineWidth: attributes["linewidth"]?.number ?? 1,
            lineCap: cap,
            lineJoin: join,
            dash: dash,
            dashPhase: attributes["dashphase"]?.number ?? 0
        )
    }
}

nonisolated struct SVGShape: Shape {
    let path: Path
    let viewBox: CGRect?

    func path(in rect: CGRect) -> Path {
        guard let viewBox, viewBox.width > 0, viewBox.height > 0 else { return path }
        let scale = min(rect.width / viewBox.width, rect.height / viewBox.height)
        let transform = CGAffineTransform(
            translationX: rect.minX + (rect.width - viewBox.width * scale) / 2 - viewBox.minX * scale,
            y: rect.minY + (rect.height - viewBox.height * scale) / 2 - viewBox.minY * scale
        )
        .scaledBy(x: scale, y: scale)
        return path.applying(transform)
    }

    static func viewBox(_ value: String?) -> CGRect? {
        guard let value else { return nil }
        let numbers = value.split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
        guard numbers.count == 4 else { return nil }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }
}

@MainActor enum SVGPathCache {
    private static var paths: [String: Path] = [:]

    static func path(_ data: String) -> Path {
        if let path = paths[data] { return path }
        let path = SVGPath.parse(data)
        if paths.count >= 256 { paths.removeAll() }
        paths[data] = path
        return path
    }
}

enum SVGPath {
    private struct Reader {
        let bytes: Array<UInt8>
        var index = 0

        mutating func skipSeparators() {
            while index < bytes.count, [0x20, 0x2C, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
        }

        mutating func command() -> UInt8? {
            skipSeparators()
            guard index < bytes.count else { return nil }
            let byte = bytes[index]
            guard (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte), byte != 0x65, byte != 0x45 else { return nil }
            index += 1
            return byte
        }

        mutating func hasNumber() -> Bool {
            skipSeparators()
            guard index < bytes.count else { return false }
            let byte = bytes[index]
            return (0x30...0x39).contains(byte) || byte == 0x2E || byte == 0x2D || byte == 0x2B
        }

        mutating func number() -> CGFloat? {
            skipSeparators()
            let start = index
            if index < bytes.count, bytes[index] == 0x2D || bytes[index] == 0x2B { index += 1 }
            var digits = digitRun()
            if index < bytes.count, bytes[index] == 0x2E {
                index += 1
                digits += digitRun()
            }
            guard digits > 0 else {
                index = start
                return nil
            }
            if index < bytes.count, bytes[index] == 0x65 || bytes[index] == 0x45 {
                let mark = index
                index += 1
                if index < bytes.count, bytes[index] == 0x2D || bytes[index] == 0x2B { index += 1 }
                if digitRun() == 0 { index = mark }
            }
            return String(bytes: bytes[start..<index], encoding: .ascii).flatMap(Double.init).map { CGFloat($0) }
        }

        mutating func flag() -> Int? {
            skipSeparators()
            guard index < bytes.count, bytes[index] == 0x30 || bytes[index] == 0x31 else { return nil }
            index += 1
            return Int(bytes[index - 1] - 0x30)
        }

        private mutating func digitRun() -> Int {
            let start = index
            while index < bytes.count, (0x30...0x39).contains(bytes[index]) { index += 1 }
            return index - start
        }

        mutating func point(relativeTo origin: CGPoint?) -> CGPoint? {
            guard let x = number(), let y = number() else { return nil }
            return CGPoint(x: x + (origin?.x ?? 0), y: y + (origin?.y ?? 0))
        }
    }

    static func parse(_ data: String) -> Path {
        var reader = Reader(bytes: Array(data.utf8))
        var path = Path()
        var current = CGPoint.zero
        var start = CGPoint.zero
        var command: UInt8 = 0
        var previous: UInt8 = 0
        var lastControl = CGPoint.zero
        while true {
            if let next = reader.command() {
                command = next
            } else if command == 0 || !reader.hasNumber() {
                break
            }
            let upper = command & ~0x20
            let origin: CGPoint? = command == upper ? nil : current
            switch upper {
            case 0x4D:
                guard let point = reader.point(relativeTo: origin) else { return path }
                path.move(to: point)
                current = point
                start = point
                command = command == upper ? 0x4C : 0x6C
            case 0x4C:
                guard let point = reader.point(relativeTo: origin) else { return path }
                path.addLine(to: point)
                current = point
            case 0x48:
                guard let x = reader.number() else { return path }
                current = CGPoint(x: x + (origin?.x ?? 0), y: current.y)
                path.addLine(to: current)
            case 0x56:
                guard let y = reader.number() else { return path }
                current = CGPoint(x: current.x, y: y + (origin?.y ?? 0))
                path.addLine(to: current)
            case 0x43:
                guard let first = reader.point(relativeTo: origin), let second = reader.point(relativeTo: origin),
                    let end = reader.point(relativeTo: origin)
                else { return path }
                path.addCurve(to: end, control1: first, control2: second)
                lastControl = second
                current = end
            case 0x53:
                guard let second = reader.point(relativeTo: origin), let end = reader.point(relativeTo: origin) else {
                    return path
                }
                let first = previous == 0x43 || previous == 0x53 ? reflect(lastControl, around: current) : current
                path.addCurve(to: end, control1: first, control2: second)
                lastControl = second
                current = end
            case 0x51:
                guard let control = reader.point(relativeTo: origin), let end = reader.point(relativeTo: origin) else {
                    return path
                }
                path.addQuadCurve(to: end, control: control)
                lastControl = control
                current = end
            case 0x54:
                guard let end = reader.point(relativeTo: origin) else { return path }
                let control = previous == 0x51 || previous == 0x54 ? reflect(lastControl, around: current) : current
                path.addQuadCurve(to: end, control: control)
                lastControl = control
                current = end
            case 0x41:
                guard let radiusX = reader.number(), let radiusY = reader.number(), let rotation = reader.number(),
                    let large = reader.flag(), let sweep = reader.flag(), let end = reader.point(relativeTo: origin)
                else { return path }
                let arc = Arc(
                    radii: CGSize(width: radiusX, height: radiusY), rotation: rotation, isLarge: large == 1,
                    sweeps: sweep == 1)
                addArc(to: &path, from: current, to: end, arc: arc)
                current = end
            case 0x5A:
                path.closeSubpath()
                current = start
            default:
                return path
            }
            previous = upper
        }
        return path
    }

    private static func reflect(_ point: CGPoint, around center: CGPoint) -> CGPoint {
        CGPoint(x: 2 * center.x - point.x, y: 2 * center.y - point.y)
    }

    private struct Arc {
        let radii: CGSize
        let rotation: CGFloat
        let isLarge: Bool
        let sweeps: Bool
    }

    private static func addArc(to path: inout Path, from start: CGPoint, to end: CGPoint, arc: Arc) {
        guard start != end else { return }
        let rotation = arc.rotation
        let isLarge = arc.isLarge
        let sweeps = arc.sweeps
        var radiusX = abs(arc.radii.width)
        var radiusY = abs(arc.radii.height)
        guard radiusX > 0, radiusY > 0 else {
            path.addLine(to: end)
            return
        }
        let angle = rotation * .pi / 180
        let cosine = cos(angle)
        let sine = sin(angle)
        let halfX = (start.x - end.x) / 2
        let halfY = (start.y - end.y) / 2
        let primeX = cosine * halfX + sine * halfY
        let primeY = -sine * halfX + cosine * halfY
        let lambda = (primeX * primeX) / (radiusX * radiusX) + (primeY * primeY) / (radiusY * radiusY)
        if lambda > 1 {
            radiusX *= lambda.squareRoot()
            radiusY *= lambda.squareRoot()
        }
        let numerator =
            radiusX * radiusX * radiusY * radiusY - radiusX * radiusX * primeY * primeY - radiusY * radiusY * primeX * primeX
        let denominator = radiusX * radiusX * primeY * primeY + radiusY * radiusY * primeX * primeX
        var coefficient = denominator == 0 ? 0 : max(0, numerator / denominator).squareRoot()
        if isLarge == sweeps { coefficient = -coefficient }
        let centerPrimeX = coefficient * radiusX * primeY / radiusY
        let centerPrimeY = -coefficient * radiusY * primeX / radiusX
        let centerX = cosine * centerPrimeX - sine * centerPrimeY + (start.x + end.x) / 2
        let centerY = sine * centerPrimeX + cosine * centerPrimeY + (start.y + end.y) / 2

        func angleBetween(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }

        let startAngle = angleBetween(1, 0, (primeX - centerPrimeX) / radiusX, (primeY - centerPrimeY) / radiusY)
        var delta = angleBetween(
            (primeX - centerPrimeX) / radiusX, (primeY - centerPrimeY) / radiusY,
            (-primeX - centerPrimeX) / radiusX, (-primeY - centerPrimeY) / radiusY)
        if !sweeps, delta > 0 { delta -= 2 * .pi }
        if sweeps, delta < 0 { delta += 2 * .pi }

        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
            CGPoint(
                x: centerX + radiusX * unitX * cosine - radiusY * unitY * sine,
                y: centerY + radiusX * unitX * sine + radiusY * unitY * cosine)
        }

        let segments = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(segments)
        let handle = 4 / 3 * tan(step / 4)
        var theta = startAngle
        for segment in 0..<segments {
            let next = theta + step
            let control1 = point(cos(theta) - handle * sin(theta), sin(theta) + handle * cos(theta))
            let control2 = point(cos(next) + handle * sin(next), sin(next) - handle * cos(next))
            let target = segment == segments - 1 ? end : point(cos(next), sin(next))
            path.addCurve(to: target, control1: control1, control2: control2)
            theta = next
        }
    }
}
