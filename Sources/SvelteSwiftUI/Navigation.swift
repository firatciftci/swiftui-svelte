import SwiftUI

enum Bars {
    static func visibility(_ value: JSONValue?) -> Visibility? {
        switch value {
        case .bool(false), .string("hidden"), .string("false"): .hidden
        case .bool(true), .string("visible"), .string("true"), .string(""): .visible
        case .string("automatic"): .automatic
        default: nil
        }
    }

    static func placement(_ name: String?) -> ToolbarItemPlacement {
        switch name {
        case "principal": return .principal
        case "primaryAction": return .primaryAction
        case "secondaryAction": return .secondaryAction
        case "confirmationAction": return .confirmationAction
        case "cancellationAction": return .cancellationAction
        case "destructiveAction": return .destructiveAction
        case "navigation": return .navigation
        case "status": return .status
        case "automatic": return .automatic
        default: break
        }
        #if os(macOS)
            switch name {
            case "leading": return .navigation
            case "bottom", "keyboard": return .automatic
            default: return .primaryAction
            }
        #else
            switch name {
            case "leading": return .topBarLeading
            case "bottom": return .bottomBar
            case "keyboard": return .keyboard
            default: return .topBarTrailing
            }
        #endif
    }

    #if os(iOS)
        static func titleDisplayMode(_ name: String?) -> NavigationBarItem.TitleDisplayMode? {
            switch name {
            case "automatic": .automatic
            case "inline": .inline
            case "large": .large
            default: nil
            }
        }
    #endif
}

struct Screen: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        Group {
            Slot(node: node)
        }
        .navigationTitle(attributes["title"]?.string ?? "")
        .modifier(Subtitle(text: attributes["subtitle"]?.string))
        .navigationBarBackButtonHidden(attributes["backbuttonhidden"]?.isTrue ?? false)
        #if os(iOS)
            .ifLet(Bars.titleDisplayMode(attributes["titledisplaymode"]?.string)) { $0.navigationBarTitleDisplayMode($1) }
            .ifLet(Bars.visibility(attributes["navbarvisibility"])) { $0.toolbar($1, for: .navigationBar) }
            .ifLet(Bars.visibility(attributes["tabbarvisibility"])) { $0.toolbar($1, for: .tabBar) }
            .ifLet(Palette.style(attributes["navbarbackground"])) {
                $0.toolbarBackground($1, for: .navigationBar).toolbarBackgroundVisibility(.visible, for: .navigationBar)
            }
        #endif
        .toolbar {
            ForEach(node.children.filter { $0.name == "toolbar" || $0.name == "toolbarspacer" }) { item in
                if item.name == "toolbarspacer" {
                    ToolbarGap(node: item)
                } else {
                    ToolbarItemGroup(placement: Bars.placement(item.attributes["placement"]?.string)) {
                        ForEach(item.renderedChildren) { child in
                            if child.name == "btn" {
                                ActionButton(node: child)
                            } else {
                                NodeView(node: child)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ToolbarGap: ToolbarContent {
    let node: Node

    var body: some ToolbarContent {
        if #available(iOS 26, macOS 26, visionOS 26, *) {
            let placement = Bars.placement(node.attributes["placement"]?.string)
            if node.attributes["variant"]?.string == "fixed" {
                ToolbarSpacer(.fixed, placement: placement)
            } else {
                ToolbarSpacer(.flexible, placement: placement)
            }
        }
    }
}

private struct Subtitle: ViewModifier {
    let text: String?

    func body(content: Content) -> some View {
        if let text, #available(iOS 26, macOS 26, visionOS 26, *) {
            content.navigationSubtitle(text)
        } else {
            content
        }
    }
}

struct Tabs: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let entries = node.renderedChildren.filter { $0.name == "tab" || $0.name == "tabsection" }
        let tabs = Self.tabs(in: entries)
        let selection = Binding {
            node.attributes["selection"] ?? tabs.first.map { Self.value(of: $0, in: tabs) } ?? .null
        } set: { value in
            runtime.edit(node, "selection", to: value, event: "change", payload: value.object)
        }
        switch node.attributes["variant"]?.string {
        case "page":
            TabView(selection: selection) {
                ForEach(tabs) { NodeView(node: $0).tag(Self.value(of: $0, in: tabs)) }
            }
            #if !os(macOS)
                .tabViewStyle(.page(indexDisplayMode: Self.indexDisplayMode(node.attributes["indexdisplay"]?.string)))
            #endif
        case "sidebarAdaptable": tabView(entries, tabs, selection).tabViewStyle(.sidebarAdaptable)
        case "tabBarOnly": tabView(entries, tabs, selection).tabViewStyle(.tabBarOnly)
        default: tabView(entries, tabs, selection)
        }
    }

    private func tabView(_ entries: Array<Node>, _ tabs: Array<Node>, _ selection: Binding<JSONValue>) -> some View {
        TabView(selection: selection) {
            if entries.contains(where: { $0.name == "tabsection" }) {
                ForEach(entries) { entry in
                    if entry.name == "tabsection" {
                        TabSection(entry.attributes["title"]?.string ?? "") {
                            ForEach(entry.renderedChildren.filter { $0.name == "tab" }) { tab in
                                TabEntry(node: tab, value: Self.value(of: tab, in: tabs))
                            }
                        }
                    } else {
                        TabEntry(node: entry, value: Self.value(of: entry, in: tabs))
                    }
                }
            } else {
                ForEach(tabs) { TabEntry(node: $0, value: Self.value(of: $0, in: tabs)) }
            }
        }
        .modifier(TabBarMinimizing(name: node.attributes["minimize"]?.string))
    }

    static func tabs(in entries: Array<Node>) -> Array<Node> {
        var tabs: Array<Node> = []
        for entry in entries {
            if entry.name == "tabsection" {
                tabs.append(contentsOf: entry.renderedChildren.filter { $0.name == "tab" })
            } else {
                tabs.append(entry)
            }
        }
        return tabs
    }

    static func badge(_ value: JSONValue?) -> Text? {
        switch value {
        case let .number(count) where count != 0: Text(count, format: .number)
        case let .string(label) where !label.isEmpty: Text(label)
        default: nil
        }
    }

    static func value(of tab: Node, in tabs: Array<Node>) -> JSONValue {
        tab.attributes["value"] ?? .number(Double(tabs.firstIndex { $0 === tab } ?? 0))
    }

    #if !os(macOS)
        static func indexDisplayMode(_ name: String?) -> PageTabViewStyle.IndexDisplayMode {
            switch name {
            case "always": .always
            case "never": .never
            default: .automatic
            }
        }
    #endif
}

private struct TabEntry: @MainActor TabContent {
    let node: Node
    let value: JSONValue

    var body: some TabContent<JSONValue> {
        let attributes = node.attributes
        let isSearch = attributes["role"]?.string == "search"
        Tab(
            attributes["title"]?.string ?? "",
            systemImage: attributes["symbol"]?.string ?? (isSearch ? "magnifyingglass" : "circle"),
            value: value,
            role: isSearch ? .search : nil
        ) {
            NodeView(node: node)
        }
        .badge(Tabs.badge(attributes["badge"]))
    }
}

private struct TabBarMinimizing: ViewModifier {
    let name: String?

    func body(content: Content) -> some View {
        #if os(iOS)
            if #available(iOS 26, *), let behavior = Self.behavior(name) {
                content.tabBarMinimizeBehavior(behavior)
            } else {
                content
            }
        #else
            content
        #endif
    }

    #if os(iOS)
        @available(iOS 26, *)
        static func behavior(_ name: String?) -> TabBarMinimizeBehavior? {
            switch name {
            case "onScrollDown": .onScrollDown
            case "onScrollUp": .onScrollUp
            case "never": .never
            case "automatic": .automatic
            default: nil
            }
        }
    #endif
}
