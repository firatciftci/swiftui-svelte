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

    static func weight(_ name: String?) -> Font.Weight? {
        switch name {
        case "regular": .regular
        case "medium": .medium
        case "semibold": .semibold
        case "bold": .bold
        case "heavy": .heavy
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
}
