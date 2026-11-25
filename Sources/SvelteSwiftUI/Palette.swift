import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

enum Palette {
    static func color(_ value: String?) -> Color? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let named = named(value) { return named }
        if value.hasPrefix("#") { return hex(value.dropFirst()) }
        if let system = system(value) { return system }
        return functional(value.lowercased())
    }

    static func style(_ value: JSONValue?) -> AnyShapeStyle? {
        switch value {
        case let .string(name):
            if let style = material(name) ?? hierarchical(name) { return style }
            if name.hasSuffix(".gradient"), let color = color(String(name.dropLast(9))) {
                return AnyShapeStyle(color.gradient)
            }
            return color(name).map { AnyShapeStyle($0) }
        case let .object(options):
            return gradient(options)
        default:
            return nil
        }
    }

    static func hex(_ color: Color.Resolved) -> String {
        let channels = [color.red, color.green, color.blue, color.opacity].map { Int((min(max($0, 0), 1) * 255).rounded()) }
        let digits = (channels[3] == 255 ? channels.prefix(3) : channels[...]).map { String(format: "%02X", $0) }
        return "#" + digits.joined()
    }

    private static func named(_ name: String) -> Color? {
        switch name {
        case "primary": .primary
        case "secondary": .secondary
        case "accent": .accentColor
        case "red": .red
        case "orange": .orange
        case "yellow": .yellow
        case "green": .green
        case "mint": .mint
        case "teal": .teal
        case "cyan": .cyan
        case "blue": .blue
        case "indigo": .indigo
        case "purple": .purple
        case "pink": .pink
        case "brown": .brown
        case "gray": .gray
        case "white": .white
        case "black": .black
        case "clear": .clear
        default: nil
        }
    }

    private static func hex(_ digits: Substring) -> Color? {
        guard [3, 4, 6, 8].contains(digits.count), let value = UInt64(digits, radix: 16) else { return nil }
        let isShort = digits.count <= 4
        let hasAlpha = digits.count == 4 || digits.count == 8
        let width: UInt64 = isShort ? 4 : 8
        let maximum = Double((1 << width) - 1)
        let count = hasAlpha ? 4 : 3
        var channels: Array<Double> = []
        for index in 0..<count {
            let shift = UInt64(count - 1 - index) * width
            channels.append(Double((value >> shift) & ((1 << width) - 1)) / maximum)
        }
        return Color(.sRGB, red: channels[0], green: channels[1], blue: channels[2], opacity: hasAlpha ? channels[3] : 1)
    }

    private static func functional(_ value: String) -> Color? {
        guard let open = value.firstIndex(of: "("), value.hasSuffix(")") else { return nil }
        let name = value[..<open].trimmingCharacters(in: .whitespaces)
        let arguments = value[value.index(after: open)..<value.index(before: value.endIndex)]
            .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "/" })
            .map(String.init)
        guard arguments.count == 3 || arguments.count == 4 else { return nil }
        let opacity = arguments.count == 4 ? fraction(arguments[3], scale: 1) : 1
        switch name {
        case "rgb", "rgba":
            guard let red = fraction(arguments[0], scale: 255), let green = fraction(arguments[1], scale: 255),
                let blue = fraction(arguments[2], scale: 255), let opacity
            else { return nil }
            return Color(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
        case "hsl", "hsla":
            guard let hue = Double(arguments[0].replacingOccurrences(of: "deg", with: "")),
                let saturation = fraction(arguments[1], scale: 100), let lightness = fraction(arguments[2], scale: 100),
                let opacity
            else { return nil }
            let channels = rgb(hue: hue, saturation: saturation, lightness: lightness)
            return Color(.sRGB, red: channels[0], green: channels[1], blue: channels[2], opacity: opacity)
        default:
            return nil
        }
    }

    private static func fraction(_ text: String, scale: Double) -> Double? {
        let value: Double? =
            if text.hasSuffix("%") { Double(text.dropLast()).map { $0 / 100 } } else { Double(text).map { $0 / scale } }
        return value.map { min(max($0, 0), 1) }
    }

    static func rgb(hue: Double, saturation: Double, lightness: Double) -> Array<Double> {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let channels: Array<Double> =
            switch Int(sector) {
            case 0: [chroma, second, 0]
            case 1: [second, chroma, 0]
            case 2: [0, chroma, second]
            case 3: [0, second, chroma]
            case 4: [second, 0, chroma]
            default: [chroma, 0, second]
            }
        let offset = lightness - chroma / 2
        return channels.map { $0 + offset }
    }

    private static func material(_ name: String) -> AnyShapeStyle? {
        switch name {
        case "ultraThinMaterial": AnyShapeStyle(.ultraThinMaterial)
        case "thinMaterial": AnyShapeStyle(.thinMaterial)
        case "regularMaterial": AnyShapeStyle(.regularMaterial)
        case "thickMaterial": AnyShapeStyle(.thickMaterial)
        case "ultraThickMaterial": AnyShapeStyle(.ultraThickMaterial)
        case "bar": AnyShapeStyle(.bar)
        default: nil
        }
    }

    private static func hierarchical(_ name: String) -> AnyShapeStyle? {
        switch name {
        case "primary": AnyShapeStyle(.primary)
        case "secondary": AnyShapeStyle(.secondary)
        case "tertiary": AnyShapeStyle(.tertiary)
        case "quaternary": AnyShapeStyle(.quaternary)
        case "quinary": AnyShapeStyle(.quinary)
        default: nil
        }
    }

    private static func gradient(_ options: [String: JSONValue]) -> AnyShapeStyle? {
        if let stops = options["linear"].flatMap(gradient) {
            return AnyShapeStyle(
                LinearGradient(
                    gradient: stops,
                    startPoint: UnitPoint(anchor: options["start"]?.string) ?? .top,
                    endPoint: UnitPoint(anchor: options["end"]?.string) ?? .bottom
                ))
        }
        if let stops = options["radial"].flatMap(gradient) {
            return AnyShapeStyle(
                RadialGradient(
                    gradient: stops,
                    center: UnitPoint(anchor: options["center"]?.string) ?? .center,
                    startRadius: options["startRadius"]?.number ?? 0,
                    endRadius: options["endRadius"]?.number ?? 100
                ))
        }
        if let stops = options["angular"].flatMap(gradient) {
            return AnyShapeStyle(
                AngularGradient(
                    gradient: stops,
                    center: UnitPoint(anchor: options["center"]?.string) ?? .center,
                    startAngle: .degrees(options["startAngle"]?.number ?? 0),
                    endAngle: .degrees(options["endAngle"]?.number ?? 360)
                ))
        }
        return nil
    }

    private static func gradient(_ value: JSONValue) -> Gradient? {
        guard case let .array(items) = value, !items.isEmpty else { return nil }
        var stops: Array<Gradient.Stop> = []
        for (index, item) in items.enumerated() {
            let fallback = items.count == 1 ? 0 : Double(index) / Double(items.count - 1)
            switch item {
            case let .string(name):
                guard let color = color(name) else { return nil }
                stops.append(Gradient.Stop(color: color, location: fallback))
            case let .object(stop):
                guard let color = color(stop["color"]?.string) else { return nil }
                stops.append(Gradient.Stop(color: color, location: stop["location"]?.number ?? fallback))
            default:
                return nil
            }
        }
        return Gradient(stops: stops)
    }

    private static func system(_ name: String) -> Color? {
        #if canImport(UIKit) && !os(watchOS)
            let color: UIColor? =
                switch name {
                case "systemBackground": .systemBackground
                case "secondarySystemBackground": .secondarySystemBackground
                case "tertiarySystemBackground": .tertiarySystemBackground
                case "systemGroupedBackground": .systemGroupedBackground
                case "secondarySystemGroupedBackground": .secondarySystemGroupedBackground
                case "tertiarySystemGroupedBackground": .tertiarySystemGroupedBackground
                case "label": .label
                case "secondaryLabel": .secondaryLabel
                case "tertiaryLabel": .tertiaryLabel
                case "quaternaryLabel": .quaternaryLabel
                case "placeholderText": .placeholderText
                case "separator": .separator
                case "opaqueSeparator": .opaqueSeparator
                case "link": .link
                case "systemFill": .systemFill
                case "secondarySystemFill": .secondarySystemFill
                case "tertiarySystemFill": .tertiarySystemFill
                case "quaternarySystemFill": .quaternarySystemFill
                case "systemGray": .systemGray
                case "systemGray2": .systemGray2
                case "systemGray3": .systemGray3
                case "systemGray4": .systemGray4
                case "systemGray5": .systemGray5
                case "systemGray6": .systemGray6
                default: nil
                }
        #elseif canImport(AppKit)
            let color: NSColor? =
                switch name {
                case "systemBackground", "systemGroupedBackground": .windowBackgroundColor
                case "secondarySystemBackground", "secondarySystemGroupedBackground", "tertiarySystemBackground",
                    "tertiarySystemGroupedBackground":
                    .controlBackgroundColor
                case "label": .labelColor
                case "secondaryLabel": .secondaryLabelColor
                case "tertiaryLabel": .tertiaryLabelColor
                case "quaternaryLabel": .quaternaryLabelColor
                case "placeholderText": .placeholderTextColor
                case "separator", "opaqueSeparator": .separatorColor
                case "link": .linkColor
                case "systemFill", "secondarySystemFill", "tertiarySystemFill", "quaternarySystemFill": .quaternaryLabelColor
                case "systemGray", "systemGray2", "systemGray3", "systemGray4", "systemGray5", "systemGray6": .systemGray
                default: nil
                }
        #else
            return nil
        #endif
        return color.map { Color($0) }
    }
}
