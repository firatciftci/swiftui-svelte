import SwiftUI

enum Styles {
    static func font(_ name: String?) -> Font? {
        switch name {
        case "largeTitle": .largeTitle
        case "title": .title
        case "title2": .title2
        case "title3": .title3
        case "headline": .headline
        case "subheadline": .subheadline
        case "body": .body
        case "callout": .callout
        case "footnote": .footnote
        case "caption": .caption
        case "caption2": .caption2
        default: nil
        }
    }

    static func font(_ attributes: [String: JSONValue]) -> Font? {
        if let size = attributes["size"]?.number {
            return .system(size: size, design: design(attributes["design"]?.string))
        }
        return font(attributes["font"]?.string)
    }

    static func textStyle(_ name: String?) -> Font.TextStyle? {
        switch name {
        case "largeTitle": .largeTitle
        case "title": .title
        case "title2": .title2
        case "title3": .title3
        case "headline": .headline
        case "subheadline": .subheadline
        case "body": .body
        case "callout": .callout
        case "footnote": .footnote
        case "caption": .caption
        case "caption2": .caption2
        default: nil
        }
    }

    static func design(_ name: String?) -> Font.Design? {
        switch name {
        case "default": .default
        case "rounded": .rounded
        case "serif": .serif
        case "monospaced": .monospaced
        default: nil
        }
    }

    static func weight(_ name: String?) -> Font.Weight? {
        switch name {
        case "ultraLight": .ultraLight
        case "thin": .thin
        case "light": .light
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
        case "black": .black
        default: nil
        }
    }

    static func color(_ name: String?) -> Color? {
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
        default: nil
        }
    }

    static func layoutDirection(_ name: String?) -> LayoutDirection? {
        switch name {
        case "ltr": .leftToRight
        case "rtl": .rightToLeft
        default: nil
        }
    }

    static func alignment(_ name: String?) -> Alignment {
        switch name {
        case "top": .top
        case "bottom": .bottom
        case "leading": .leading
        case "trailing": .trailing
        case "topLeading": .topLeading
        case "topTrailing": .topTrailing
        case "bottomLeading": .bottomLeading
        case "bottomTrailing": .bottomTrailing
        case "leadingFirstTextBaseline": .leadingFirstTextBaseline
        case "centerFirstTextBaseline": .centerFirstTextBaseline
        case "trailingFirstTextBaseline": .trailingFirstTextBaseline
        case "leadingLastTextBaseline": .leadingLastTextBaseline
        case "centerLastTextBaseline": .centerLastTextBaseline
        case "trailingLastTextBaseline": .trailingLastTextBaseline
        default: .center
        }
    }

    static func horizontalAlignment(_ name: String?) -> HorizontalAlignment {
        switch name {
        case "leading": .leading
        case "trailing": .trailing
        case "listRowSeparatorLeading": .listRowSeparatorLeading
        case "listRowSeparatorTrailing": .listRowSeparatorTrailing
        default: .center
        }
    }

    static func verticalAlignment(_ name: String?) -> VerticalAlignment {
        switch name {
        case "top": .top
        case "bottom": .bottom
        case "firstTextBaseline": .firstTextBaseline
        case "lastTextBaseline": .lastTextBaseline
        default: .center
        }
    }

    static func truncationMode(_ name: String?) -> Text.TruncationMode? {
        switch name {
        case "head": .head
        case "middle": .middle
        case "tail": .tail
        default: nil
        }
    }
}
