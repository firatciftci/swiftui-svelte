import Foundation

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
        return [
            "colorScheme": isDark ? "dark" : "light",
            "reduceMotion": reduceMotion,
            "reduceTransparency": reduceTransparency,
            "increaseContrast": increaseContrast,
            "languages": languages,
            "onLine": true,
            "userAgent": "swiftui-svelte (\(platform) \(system))",
        ]
    }
}
