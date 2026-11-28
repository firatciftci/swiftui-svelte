import SwiftUI

private struct SharedNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var sharedNamespace: Namespace.ID? {
        get { self[SharedNamespaceKey.self] }
        set { self[SharedNamespaceKey.self] = newValue }
    }
}

struct SharedNamespace: ViewModifier {
    let node: Node
    @Namespace private var namespace

    func body(content: Content) -> some View {
        content.overriding(\.sharedNamespace, with: node.attributes["namespace"]?.isTrue == true ? namespace : nil)
    }
}

struct MatchedGeometry: ViewModifier {
    let node: Node
    @Environment(\.sharedNamespace) private var namespace
    @Namespace private var unmatched

    func body(content: Content) -> some View {
        let id = node.attributes["matchedid"]?.string
        content.matchedGeometryEffect(id: id ?? "", in: id != nil ? namespace ?? unmatched : unmatched)
    }
}
