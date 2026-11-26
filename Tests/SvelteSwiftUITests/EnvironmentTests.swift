import SwiftUI
import Testing

@testable import SvelteSwiftUI

struct EnvironmentTests {
    @Test func reportsTheSystemColorSchemeSeparatelyFromTheAppearance() {
        var snapshot = EnvironmentSnapshot(colorScheme: .dark, systemColorScheme: .light)
        let dictionary = snapshot.dictionary
        #expect(dictionary["colorScheme"] as? String == "dark")
        #expect(dictionary["systemColorScheme"] as? String == "light")
        #expect(dictionary["liquidGlass"] as? Bool == EnvironmentSnapshot.supportsLiquidGlass)
        snapshot.systemColorScheme = .dark
        #expect(snapshot.dictionary["systemColorScheme"] as? String == "dark")
    }

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
        #expect(dictionary["viewportHeight"] as? Double == 844)
        #expect(dictionary["pixelRatio"] as? Double == 3)
        #expect(dictionary["fontScale"] as? Double == 1.5)
        #expect(dictionary["colorScheme"] as? String == "dark")
        #expect(dictionary["increaseContrast"] as? Bool == true)
        #expect(dictionary["reduceMotion"] as? Bool == false)
        #expect(dictionary["dynamicTypeSize"] as? String == "accessibility3")
        #expect(dictionary["locale"] as? String == "ar-EG")
        #expect(dictionary["timeZone"] as? String == "Africa/Cairo")
        #expect(dictionary["layoutDirection"] as? String == "rightToLeft")
        #expect(dictionary["horizontalSizeClass"] as? String == "regular")
        #expect(dictionary["verticalSizeClass"] is NSNull)
        #expect(dictionary["scenePhase"] as? String == "background")
        #expect(dictionary["platform"] as? String == EnvironmentSnapshot.platformName)
        #expect(dictionary["idiom"] as? String == "phone")
        #expect(dictionary["keyboardHeight"] as? Double == 336)
        let insets = try #require(dictionary["safeAreaInsets"] as? [String: Double])
        #expect(insets == ["top": 59, "leading": 0, "bottom": 34.33, "trailing": 0])
        #expect(JSONSerialization.isValidJSONObject(dictionary))
    }

    @Test func startsWithTheDeviceLocaleTimeZoneAndDirection() {
        let current = HostEnvironment.current
        #expect(current["locale"] as? String == Locale.current.identifier(.bcp47))
        #expect(current["timeZone"] as? String == TimeZone.current.identifier)
        #expect(current["layoutDirection"] as? String == "leftToRight")
        #expect(JSONSerialization.isValidJSONObject(current))
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
