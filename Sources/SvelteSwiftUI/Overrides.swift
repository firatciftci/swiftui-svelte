import SwiftUI

enum Overrides {
    static func feedback(_ value: JSONValue?) -> SensoryFeedback? {
        switch value {
        case let .string(name): named(name)
        case let .object(options): impact(options)
        default: nil
        }
    }

    private static func named(_ name: String) -> SensoryFeedback? {
        switch name {
        case "success": .success
        case "warning": .warning
        case "error": .error
        case "selection": .selection
        case "increase": .increase
        case "decrease": .decrease
        case "start": .start
        case "stop": .stop
        case "alignment": .alignment
        case "levelChange": .levelChange
        case "impact": .impact
        default: nil
        }
    }

    private static func impact(_ options: [String: JSONValue]) -> SensoryFeedback? {
        guard options["type"]?.string ?? "impact" == "impact" else { return named(options["type"]?.string ?? "") }
        let intensity = min(max(options["intensity"]?.number ?? 1, 0), 1)
        switch options["flexibility"]?.string {
        case "rigid": return .impact(flexibility: .rigid, intensity: intensity)
        case "solid": return .impact(flexibility: .solid, intensity: intensity)
        case "soft": return .impact(flexibility: .soft, intensity: intensity)
        default: break
        }
        switch options["weight"]?.string {
        case "light": return .impact(weight: .light, intensity: intensity)
        case "heavy": return .impact(weight: .heavy, intensity: intensity)
        default: return .impact(weight: .medium, intensity: intensity)
        }
    }

    static func colorScheme(_ name: String?) -> ColorScheme? {
        switch name {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    static func dynamicTypeSize(_ name: String?) -> DynamicTypeSize? {
        DynamicTypeSize.allCases.first { EnvironmentSnapshot.name(of: $0) == name }
    }

    static func dynamicTypeSizes(_ value: JSONValue?) -> ClosedRange<DynamicTypeSize>? {
        switch value {
        case let .object(options):
            let lower = dynamicTypeSize(options["min"]?.string) ?? DynamicTypeSize.allCases.first ?? .xSmall
            let upper = dynamicTypeSize(options["max"]?.string) ?? DynamicTypeSize.allCases.last ?? .accessibility5
            return lower <= upper ? lower...upper : nil
        default:
            return nil
        }
    }

    #if os(iOS) || os(visionOS)
        static func keyboardDismissal(_ name: String?) -> ScrollDismissesKeyboardMode? {
            switch name {
            case "automatic": .automatic
            case "immediately": .immediately
            case "interactively": .interactively
            case "never": .never
            default: nil
            }
        }
    #endif
}

struct Preferences: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        content
            .ifLet(Overrides.feedback(attributes["sensoryfeedback"])) {
                $0.sensoryFeedback($1, trigger: attributes["feedbacktrigger"] ?? .null)
            }
            .ifLet(Overrides.colorScheme(attributes["colorscheme"]?.string)) { $0.environment(\.colorScheme, $1) }
            .ifLet(Overrides.colorScheme(attributes["preferredcolorscheme"]?.string)) { $0.preferredColorScheme($1) }
            .modifier(TypeSize(value: attributes["dynamictypesize"]))
            .modifier(KeyboardDismissal(name: attributes["scrolldismisseskeyboard"]?.string))
    }
}

private struct KeyboardDismissal: ViewModifier {
    let name: String?

    func body(content: Content) -> some View {
        #if os(iOS) || os(visionOS)
            content.ifLet(Overrides.keyboardDismissal(name)) { $0.scrollDismissesKeyboard($1) }
        #else
            content
        #endif
    }
}

private struct TypeSize: ViewModifier {
    let value: JSONValue?
    @Environment(\.font) private var font

    func body(content: Content) -> some View {
        let size = Overrides.dynamicTypeSize(value?.string)
        let sizes = Overrides.dynamicTypeSizes(value)
        content
            .ifLet(font == nil && (size != nil || sizes != nil) ? Font.body : nil) { $0.font($1) }
            .ifLet(size) { $0.dynamicTypeSize($1) }
            .ifLet(sizes) { $0.dynamicTypeSize($1) }
    }
}
