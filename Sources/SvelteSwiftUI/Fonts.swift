import SwiftUI

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

enum Fonts {
    static let textStyleSizes: [String: Double] = [
        "largeTitle": 34, "title": 28, "title2": 22, "title3": 20, "headline": 17, "subheadline": 15, "body": 17,
        "callout": 16, "footnote": 13, "caption": 12, "caption2": 11,
    ]

    static func custom(_ name: String, size: Double?, style: String?, fallbacks: Array<String>) -> Font {
        guard !fallbacks.isEmpty else {
            guard let style, let textStyle = Styles.textStyle(style) else {
                return size.map { .custom(name, fixedSize: CGFloat($0)) } ?? .custom(name, size: 17, relativeTo: .body)
            }
            return .custom(name, size: CGFloat(size ?? textStyleSizes[style, default: 17]), relativeTo: textStyle)
        }
        let base = CGFloat(size ?? textStyleSizes[style ?? "body", default: 17])
        let font = cascade(name, size: base, fallbacks: fallbacks)
        #if canImport(UIKit)
            if let scaling = uiTextStyle(style ?? (size == nil ? "body" : nil)) {
                return Font(UIFontMetrics(forTextStyle: scaling).scaledFont(for: font))
            }
            return Font(font)
        #else
            return Font(font)
        #endif
    }

    static func descriptor(_ name: String, size: CGFloat, fallbacks: Array<String>) -> PlatformFontDescriptor {
        #if canImport(UIKit)
            UIFontDescriptor(name: name, size: size).addingAttributes([
                .cascadeList: fallbacks.map { UIFontDescriptor(name: $0, size: size) }
            ])
        #else
            NSFontDescriptor(name: name, size: size).addingAttributes([
                .cascadeList: fallbacks.map { NSFontDescriptor(name: $0, size: size) }
            ])
        #endif
    }

    static func cascade(_ name: String, size: CGFloat, fallbacks: Array<String>) -> PlatformFont {
        let descriptor = descriptor(name, size: size, fallbacks: fallbacks)
        #if canImport(UIKit)
            return UIFont(descriptor: descriptor, size: size)
        #else
            return NSFont(descriptor: descriptor, size: size) ?? .systemFont(ofSize: size)
        #endif
    }

    #if canImport(UIKit)
        private static func uiTextStyle(_ name: String?) -> UIFont.TextStyle? {
            switch name {
            case "largeTitle": .largeTitle
            case "title": .title1
            case "title2": .title2
            case "title3": .title3
            case "headline": .headline
            case "subheadline": .subheadline
            case "body": .body
            case "callout": .callout
            case "footnote": .footnote
            case "caption": .caption1
            case "caption2": .caption2
            default: nil
            }
        }
    #endif
}

#if canImport(UIKit)
    typealias PlatformFont = UIFont
    typealias PlatformFontDescriptor = UIFontDescriptor
#else
    typealias PlatformFont = NSFont
    typealias PlatformFontDescriptor = NSFontDescriptor
#endif
