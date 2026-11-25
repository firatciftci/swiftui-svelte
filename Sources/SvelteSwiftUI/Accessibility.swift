import SwiftUI

enum Accessibility {
    static func names(_ value: JSONValue?) -> Array<String> {
        switch value {
        case let .string(name): name.isEmpty ? [] : [name]
        case let .array(values): values.compactMap(\.string).filter { !$0.isEmpty }
        default: []
        }
    }

    static func traits(_ value: JSONValue?) -> AccessibilityTraits? {
        let traits = names(value).compactMap(trait)
        guard !traits.isEmpty else { return nil }
        var union = AccessibilityTraits()
        for trait in traits { union.formUnion(trait) }
        return union
    }

    private static func trait(_ name: String) -> AccessibilityTraits? {
        switch name {
        case "button": .isButton
        case "header": .isHeader
        case "link": .isLink
        case "image": .isImage
        case "selected": .isSelected
        case "modal": .isModal
        case "toggle": .isToggle
        case "staticText": .isStaticText
        case "searchField": .isSearchField
        case "summaryElement": .isSummaryElement
        case "updatesFrequently": .updatesFrequently
        case "playsSound": .playsSound
        case "startsMediaSession": .startsMediaSession
        case "keyboardKey": .isKeyboardKey
        case "allowsDirectInteraction": .allowsDirectInteraction
        case "causesPageTurn": .causesPageTurn
        default: nil
        }
    }

    static func children(_ name: String?) -> AccessibilityChildBehavior? {
        switch name {
        case "combine": .combine
        case "contain": .contain
        case "ignore": .ignore
        default: nil
        }
    }

    static func announce(_ message: String?, priority: String?) {
        guard let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var text = AttributedString(message)
        switch priority {
        case "low": text.accessibilitySpeechAnnouncementPriority = .low
        case "high": text.accessibilitySpeechAnnouncementPriority = .high
        default: text.accessibilitySpeechAnnouncementPriority = .default
        }
        AccessibilityNotification.Announcement(text).post()
    }

    static func heading(_ value: JSONValue?) -> AccessibilityHeadingLevel? {
        switch value {
        case .bool(true), .string("unspecified"): .unspecified
        case .number(1): .h1
        case .number(2): .h2
        case .number(3): .h3
        case .number(4): .h4
        case .number(5): .h5
        case .number(6): .h6
        default: nil
        }
    }
}

struct Accessible: ViewModifier {
    let node: Node

    func body(content: Content) -> some View {
        let attributes = node.attributes
        content
            .ifLet(Accessibility.children(attributes["a11ychildren"]?.string)) { $0.accessibilityElement(children: $1) }
            .modifier(AccessibleDescription(attributes: attributes))
            .modifier(AccessibleActions(node: node))
            .ifLet(attributes["a11yhidden"]) { $0.accessibilityHidden($1.isTrue) }
            .ifLet(attributes["testid"]?.string) { $0.accessibilityIdentifier($1) }
    }
}

private struct AccessibleDescription: ViewModifier {
    let attributes: [String: JSONValue]

    func body(content: Content) -> some View {
        let inputLabels = Accessibility.names(attributes["a11yinputlabels"])
        content
            .ifLet(attributes["a11ylabel"]?.string) { $0.accessibilityLabel(Text($1)) }
            .ifLet(attributes["a11yvalue"]?.string) { $0.accessibilityValue(Text($1)) }
            .ifLet(attributes["a11yhint"]?.string) { $0.accessibilityHint(Text($1)) }
            .ifLet(inputLabels.isEmpty ? nil : inputLabels) { $0.accessibilityInputLabels($1.map { Text($0) }) }
            .ifLet(Accessibility.traits(attributes["a11ytraits"])) { $0.accessibilityAddTraits($1) }
            .ifLet(Accessibility.traits(attributes["a11yremovetraits"])) { $0.accessibilityRemoveTraits($1) }
            .ifLet(Accessibility.heading(attributes["a11yheading"])) { $0.accessibilityHeading($1) }
            .ifLet(attributes["a11ysortpriority"]?.number) { $0.accessibilitySortPriority($1) }
    }
}

private struct AccessibleActions: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let id = node.id
        let names = Accessibility.names(node.attributes["a11yactions"])
        content
            .ifLet(names.isEmpty ? nil : names) { view, names in
                view.accessibilityActions {
                    ForEach(names, id: \.self) { name in
                        Button(name) { runtime.dispatch(id, "a11yaction", name) }
                    }
                }
            }
            .ifLet(node.listens(to: "a11yactivate") ? id : nil) { view, id in
                view.accessibilityAction { runtime.dispatch(id, "a11yactivate") }
            }
            .ifLet(node.listens(to: "a11yescape") ? id : nil) { view, id in
                view.accessibilityAction(.escape) { runtime.dispatch(id, "a11yescape") }
            }
            .modifier(MagicTap(id: node.listens(to: "a11ymagictap") ? id : nil))
            .ifLet(node.listens(to: "a11yadjust") ? id : nil) { view, id in
                view.accessibilityAdjustableAction { direction in
                    runtime.dispatch(id, "a11yadjust", direction == .increment ? "increment" : "decrement")
                }
            }
    }
}

private struct MagicTap: ViewModifier {
    let id: Int?
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        #if os(macOS)
            content
        #else
            content.ifLet(id) { view, id in
                view.accessibilityAction(.magicTap) { runtime.dispatch(id, "a11ymagictap") }
            }
        #endif
    }
}
