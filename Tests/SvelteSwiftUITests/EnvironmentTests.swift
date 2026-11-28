import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct EnvironmentTests {
    @Test func reportsTheSystemColorSchemeSeparatelyFromTheAppearance() {
        var snapshot = EnvironmentSnapshot(colorScheme: .dark, systemColorScheme: .light)
        let dictionary = snapshot.dictionary
        #expect(dictionary["colorScheme"] == "dark")
        #expect(dictionary["systemColorScheme"] == "light")
        #expect(dictionary["liquidGlass"] == .bool(EnvironmentSnapshot.supportsLiquidGlass))
        snapshot.systemColorScheme = .dark
        #expect(snapshot.dictionary["systemColorScheme"] == "dark")
    }

    #if canImport(UIKit)
        @Test func scalesTheDefaultBodySizeLikeUIFontMetrics() {
            let traits = UITraitCollection(preferredContentSizeCategory: .extraLarge)
            let body = UIFontMetrics.default.scaledValue(for: 17, compatibleWith: traits)
            #expect(abs(EnvironmentSnapshot.fontScale(compatibleWith: traits) * 17 - body) < 0.001)
        }
    #endif

    @Test func describesTheSwiftUIEnvironmentForJavaScript() throws {
        var snapshot = EnvironmentSnapshot(
            colorScheme: .dark,
            increaseContrast: true,
            dynamicTypeSize: .accessibility3,
            locale: Locale(identifier: "ar_EG"),
            timeZone: try #require(TimeZone(identifier: "Africa/Cairo")),
            layoutDirection: .rightToLeft,
            horizontalSizeClass: "regular",
            scenePhase: .background,
            safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34.333_333, trailing: 0),
            keyboardHeight: 335.999_9
        )
        snapshot.viewportWidth = 390
        snapshot.viewportHeight = 844
        snapshot.pixelRatio = 3
        snapshot.fontScale = 1.5
        let dictionary = snapshot.dictionary
        #expect(dictionary["viewportHeight"] == 844)
        #expect(dictionary["pixelRatio"] == 3)
        #expect(dictionary["fontScale"] == 1.5)
        #expect(dictionary["colorScheme"] == "dark")
        #expect(dictionary["increaseContrast"] == true)
        #expect(dictionary["reduceMotion"] == false)
        #expect(dictionary["dynamicTypeSize"] == "accessibility3")
        #expect(dictionary["locale"] == "ar-EG")
        #expect(dictionary["timeZone"] == "Africa/Cairo")
        #expect(dictionary["layoutDirection"] == "rightToLeft")
        #expect(dictionary["horizontalSizeClass"] == "regular")
        #expect(dictionary["verticalSizeClass"] == .null)
        #expect(dictionary["scenePhase"] == "background")
        #expect(dictionary["platform"] == .string(EnvironmentSnapshot.platformName))
        #expect(dictionary["idiom"] == .string(EnvironmentSnapshot.idiomName))
        #expect(dictionary["keyboardHeight"] == 336)
        #expect(dictionary["safeAreaInsets"] == ["top": 59, "leading": 0, "bottom": 34.33, "trailing": 0])
    }

    @Test func startsWithTheDeviceLocaleTimeZoneAndDirection() {
        let current = HostEnvironment.current
        #expect(current["locale"] == .string(Locale.current.identifier(.bcp47)))
        #expect(current["timeZone"] == .string(TimeZone.current.identifier))
        #expect(current["layoutDirection"] == "leftToRight")
    }

    @Test func readsLayoutDirectionsLikeHTML() {
        #expect(Styles.layoutDirection("rtl") == .rightToLeft)
        #expect(Styles.layoutDirection("ltr") == .leftToRight)
        #expect(Styles.layoutDirection("auto") == nil)
        #expect(Styles.layoutDirection(nil) == nil)
    }

    @Test func namesEveryDynamicTypeSizeLikeSwiftUI() {
        for size in DynamicTypeSize.allCases {
            #expect(EnvironmentSnapshot.name(of: size) == String(describing: size))
        }
    }

    @Test func comparesSnapshotsByValue() {
        var snapshot = EnvironmentSnapshot()
        #expect(snapshot == EnvironmentSnapshot())
        snapshot.keyboardHeight = 300
        #expect(snapshot != EnvironmentSnapshot())
    }
}
