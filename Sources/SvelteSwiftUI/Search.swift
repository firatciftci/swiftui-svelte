import SwiftUI

struct SearchToken: Identifiable, Hashable {
    let value: JSONValue
    let id: String
    let label: String
    let symbol: String?

    init?(_ value: JSONValue) {
        switch value {
        case let .string(label):
            id = label
            self.label = label
            symbol = nil
        case let .object(options):
            guard let label = options["label"]?.string else { return nil }
            id = options["id"]?.string ?? label
            self.label = label
            symbol = options["symbol"]?.string
        default:
            return nil
        }
        self.value = value
    }

    static func tokens(_ value: JSONValue?) -> Array<Self> {
        guard case let .array(items) = value else { return [] }
        var seen: Set<String> = []
        return items.compactMap(Self.init).filter { seen.insert($0.id).inserted }
    }
}

struct SearchScope: Hashable {
    let value: String
    let title: String

    static func scopes(_ value: JSONValue?) -> Array<Self> {
        guard case let .array(items) = value else { return [] }
        return items.compactMap { item in
            switch item {
            case let .string(title): Self(value: title, title: title)
            case let .object(options):
                options["value"]?.string.map { Self(value: $0, title: options["title"]?.string ?? $0) }
            default: nil
            }
        }
    }
}

enum Searches {
    static func placement(_ name: String?, drawer: String?) -> SearchFieldPlacement {
        switch name {
        case "toolbar": .toolbar
        case "sidebar": .sidebar
        #if os(iOS)
            case "navigationBarDrawer": .navigationBarDrawer(displayMode: drawer == "always" ? .always : .automatic)
        #endif
        default: .automatic
        }
    }

    static func activation(_ name: String?) -> SearchScopeActivation {
        switch name {
        case "onTextEntry": .onTextEntry
        case "onSearchPresentation": .onSearchPresentation
        default: .automatic
        }
    }
}

struct Searching: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    @State private var text: String

    init(node: Node) {
        self.node = node
        _text = State(initialValue: node.attributes["value"]?.string ?? "")
    }

    func body(content: Content) -> some View {
        let attributes = node.attributes
        let scopes = SearchScope.scopes(attributes["scopes"])
        let suggestions = node.renderedChildren
        let value = attributes["value"]?.string
        content
            .searchable(
                text: $text,
                tokens: Binding {
                    SearchToken.tokens(node.attributes["tokens"])
                } set: { tokens in
                    let value = JSONValue.array(tokens.map(\.value))
                    runtime.edit(node, "tokens", to: value, event: "tokenschange", payload: value.object)
                },
                isPresented: Binding {
                    node.attributes["presented"]?.isTrue ?? false
                } set: { presented in
                    runtime.edit(node, "presented", to: .bool(presented), event: "presentedchange", payload: presented)
                },
                placement: Searches.placement(attributes["placement"]?.string, drawer: attributes["drawer"]?.string),
                prompt: attributes["prompt"]?.string.map { Text($0) }
            ) { TokenLabel(token: $0) }
            .searchSuggestions {
                ForEach(SearchToken.tokens(attributes["suggestedtokens"])) { TokenLabel(token: $0).searchCompletion($0) }
                ForEach(suggestions) { child in
                    NodeView(node: child).ifLet(child.attributes["completion"]?.string) { $0.searchCompletion($1) }
                }
            }
            .modifier(Scopes(node: node, scopes: scopes))
            .modifier(SearchMinimizing(isMinimized: attributes["minimize"]?.isTrue == true))
            .onSubmit(of: .search) { runtime.dispatch(node.id, "submit") }
            .onChange(of: text) { _, typed in
                guard typed != node.attributes["value"]?.string else { return }
                node.attributes["value"] = .string(typed)
                runtime.dispatch(node.id, "input", typed)
                if let settled = node.attributes["value"]?.string, settled != typed { text = settled }
            }
            .onChange(of: value) { _, value in
                if let value, value != text { text = value }
            }
    }
}

private struct TokenLabel: View {
    let token: SearchToken

    var body: some View {
        if let symbol = token.symbol {
            Label(token.label, systemImage: symbol)
        } else {
            Text(token.label)
        }
    }
}

private struct Scopes: ViewModifier {
    let node: Node
    let scopes: Array<SearchScope>
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        if scopes.isEmpty {
            content
        } else {
            content.searchScopes(
                Binding {
                    node.attributes["selectedscope"]?.string ?? scopes[0].value
                } set: { scope in
                    runtime.edit(node, "selectedscope", to: .string(scope), event: "scopechange", payload: scope)
                },
                activation: Searches.activation(node.attributes["scopeactivation"]?.string)
            ) {
                ForEach(scopes, id: \.value) { Text($0.title).tag($0.value) }
            }
        }
    }
}

private struct SearchMinimizing: ViewModifier {
    let isMinimized: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
            if isMinimized, #available(iOS 26, *) {
                content.searchToolbarBehavior(.minimize)
            } else {
                content
            }
        #else
            content
        #endif
    }
}
