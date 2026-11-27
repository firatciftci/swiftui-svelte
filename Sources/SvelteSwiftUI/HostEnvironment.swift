import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

enum HostEnvironment {
    static var current: [String: Any] {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let system = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #if os(iOS) || os(visionOS)
            let platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
            let isDark = UITraitCollection.current.userInterfaceStyle == .dark
            let reduceMotion = UIAccessibility.isReduceMotionEnabled
            let reduceTransparency = UIAccessibility.isReduceTransparencyEnabled
            let increaseContrast = UIAccessibility.isDarkerSystemColorsEnabled
        #elseif os(macOS)
            let platform = "macOS"
            let isDark = NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            let increaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #else
            let platform = "Apple"
            let isDark = false
            let reduceMotion = false
            let reduceTransparency = false
            let increaseContrast = false
        #endif
        let languages = Locale.preferredLanguages.isEmpty ? ["en-US"] : Locale.preferredLanguages
        let localization = Locale.Language(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        var snapshot = EnvironmentSnapshot()
        snapshot.colorScheme = isDark ? .dark : .light
        snapshot.systemColorScheme = snapshot.colorScheme
        snapshot.reduceMotion = reduceMotion
        snapshot.reduceTransparency = reduceTransparency
        snapshot.increaseContrast = increaseContrast
        snapshot.locale = .current
        snapshot.timeZone = .current
        snapshot.layoutDirection = localization.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
        return snapshot.dictionary.merging([
            "languages": languages,
            "onLine": true,
            "userAgent": "swiftui-svelte (\(platform) \(system))",
        ]) { _, host in host }
    }
}

struct AccessibilitySettings: Equatable {
    var voiceOver = false
    var switchControl = false
    var differentiateWithoutColor = false
    var invertColors = false
    var boldText = false
    var buttonShapes = false
}

struct EnvironmentSnapshot: Equatable {
    var colorScheme = ColorScheme.light
    var systemColorScheme = ColorScheme.light
    var increaseContrast = false
    var reduceMotion = false
    var reduceTransparency = false
    var accessibility = AccessibilitySettings()
    var dynamicTypeSize = DynamicTypeSize.large
    var locale = Locale(identifier: "en_US")
    var timeZone = TimeZone(identifier: "UTC") ?? .current
    var layoutDirection = LayoutDirection.leftToRight
    var horizontalSizeClass: String?
    var verticalSizeClass: String?
    var scenePhase = ScenePhase.active
    var safeAreaInsets = EdgeInsets()
    var keyboardHeight = 0.0
    var viewportWidth: CGFloat = 0
    var viewportHeight: CGFloat = 0
    var pixelRatio: CGFloat = 1
    var fontScale: CGFloat = 1

    static var supportsLiquidGlass: Bool {
        guard Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool != true else { return false }
        if #available(iOS 26, macOS 26, visionOS 26, *) { return true }
        return false
    }

    var dictionary: [String: Any] {
        [
            "colorScheme": colorScheme == .dark ? "dark" : "light",
            "systemColorScheme": systemColorScheme == .dark ? "dark" : "light",
            "liquidGlass": Self.supportsLiquidGlass,
            "increaseContrast": increaseContrast,
            "reduceMotion": reduceMotion,
            "reduceTransparency": reduceTransparency,
            "voiceOver": accessibility.voiceOver,
            "switchControl": accessibility.switchControl,
            "differentiateWithoutColor": accessibility.differentiateWithoutColor,
            "invertColors": accessibility.invertColors,
            "boldText": accessibility.boldText,
            "buttonShapes": accessibility.buttonShapes,
            "dynamicTypeSize": Self.name(of: dynamicTypeSize),
            "locale": locale.identifier(.bcp47),
            "timeZone": timeZone.identifier,
            "layoutDirection": layoutDirection == .rightToLeft ? "rightToLeft" : "leftToRight",
            "horizontalSizeClass": horizontalSizeClass ?? NSNull(),
            "verticalSizeClass": verticalSizeClass ?? NSNull(),
            "scenePhase": Self.name(of: scenePhase),
            "safeAreaInsets": [
                "top": Self.points(safeAreaInsets.top),
                "leading": Self.points(safeAreaInsets.leading),
                "bottom": Self.points(safeAreaInsets.bottom),
                "trailing": Self.points(safeAreaInsets.trailing),
            ],
            "keyboardHeight": Self.points(keyboardHeight),
            "viewportWidth": Self.points(viewportWidth),
            "viewportHeight": Self.points(viewportHeight),
            "pixelRatio": Double(pixelRatio),
            "fontScale": Double(fontScale),
            "platform": Self.platformName,
            "idiom": Self.idiomName,
        ]
    }

    private static func points(_ value: CGFloat) -> Double {
        (Double(value) * 100).rounded() / 100
    }

    static var platformName: String {
        #if os(macOS)
            "macos"
        #elseif os(visionOS)
            "visionos"
        #else
            "ios"
        #endif
    }

    static var currentFontScale: CGFloat {
        #if canImport(UIKit)
            fontScale(compatibleWith: nil)
        #else
            1
        #endif
    }

    #if canImport(UIKit)
        static func fontScale(compatibleWith traits: UITraitCollection?) -> CGFloat {
            UIFontMetrics.default.scaledValue(for: 17, compatibleWith: traits) / 17
        }
    #endif

    static var idiomName: String {
        #if os(macOS)
            "mac"
        #else
            switch UIDevice.current.userInterfaceIdiom {
            case .pad: "pad"
            case .tv: "tv"
            case .mac: "mac"
            case .vision: "vision"
            default: "phone"
            }
        #endif
    }

    static func name(of size: DynamicTypeSize) -> String {
        switch size {
        case .xSmall: "xSmall"
        case .small: "small"
        case .medium: "medium"
        case .large: "large"
        case .xLarge: "xLarge"
        case .xxLarge: "xxLarge"
        case .xxxLarge: "xxxLarge"
        case .accessibility1: "accessibility1"
        case .accessibility2: "accessibility2"
        case .accessibility3: "accessibility3"
        case .accessibility4: "accessibility4"
        case .accessibility5: "accessibility5"
        @unknown default: "large"
        }
    }

    static func name(of phase: ScenePhase) -> String {
        switch phase {
        case .active: "active"
        case .inactive: "inactive"
        case .background: "background"
        @unknown default: "active"
        }
    }

    #if os(iOS) || os(visionOS)
        static func name(of sizeClass: UserInterfaceSizeClass?) -> String? {
            switch sizeClass {
            case .compact: "compact"
            case .regular: "regular"
            case nil: nil
            @unknown default: nil
            }
        }
    #endif
}
