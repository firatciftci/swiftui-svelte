#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

enum AttributeChecks {
    static let styles: Set<String> = [
        "background", "border", "color", "colormultiply", "fill", "navbarbackground", "placeholdercolor",
        "presentationbackground", "rowbackground", "rowseparatortint", "shadow", "stroke", "strokeborder", "tint",
        "underlinecolor",
    ]

    private static let vector: Set<String> = [
        "svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "title",
    ]

    private static var knownSymbols: Set<String> = []
    private static var knownFonts: Set<String> = []

    static func check(_ name: String, _ value: JSONValue, on node: Node, diagnostics: Diagnostics) {
        guard case let .string(text) = value, !text.isEmpty, !vector.contains(node.name) else {
            if name == "fontfallbacks", case let .array(fonts) = value {
                for case let .string(font) in fonts { checkFont(font, attribute: name, on: node, diagnostics: diagnostics) }
            }
            return
        }
        if styles.contains(name) {
            guard Palette.style(value) == nil else { return }
            report(
                "isn't a color or style, so it has no effect. Use a color name such as \"blue\", a system color such as \"systemGray4\", or a CSS color such as \"#3366ff\" or \"rgb(51 102 255)\".",
                name, text, on: node, diagnostics: diagnostics)
        } else if name == "symbol" || (name == "name" && node.name == "sfsymbol") {
            guard !isSymbol(text) else { return }
            report(
                "isn't an SF Symbol on this OS version, so nothing shows. Check the name in the SF Symbols app, which also lists the OS version each symbol needs.",
                name, text, on: node, diagnostics: diagnostics)
        } else if name == "fontname" {
            checkFont(text, attribute: name, on: node, diagnostics: diagnostics)
        }
    }

    private static func checkFont(_ font: String, attribute: String, on node: Node, diagnostics: Diagnostics) {
        guard !isFont(font) else { return }
        report(
            "isn't a font this app has, so it uses the system font instead. Add the font file to the app target, list it under UIAppFonts in Info.plist, and use the font's PostScript name, which Font Book shows.",
            attribute, font, on: node, diagnostics: diagnostics)
    }

    private static func report(_ problem: String, _ attribute: String, _ value: String, on node: Node, diagnostics: Diagnostics) {
        diagnostics.report(
            "<\(node.name)> \(attribute)=\"\(value)\" \(problem)", element: node.name, attribute: attribute, value: value,
            location: node.location)
    }

    private static func isSymbol(_ name: String) -> Bool {
        if knownSymbols.contains(name) { return true }
        #if canImport(UIKit)
            let exists = UIImage(systemName: name) != nil
        #else
            let exists = NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
        #endif
        if exists { knownSymbols.insert(name) }
        return exists
    }

    private static func isFont(_ name: String) -> Bool {
        if knownFonts.contains(name) { return true }
        #if canImport(UIKit)
            let exists = UIFont(name: name, size: 17) != nil
        #else
            let exists = NSFont(name: name, size: 17) != nil
        #endif
        if exists { knownFonts.insert(name) }
        return exists
    }
}
