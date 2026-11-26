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
        if node.attributes["namespace"]?.isTrue == true {
            content.environment(\.sharedNamespace, namespace)
        } else {
            content
        }
    }
}

struct MatchedGeometry: ViewModifier {
    let node: Node
    @Environment(\.sharedNamespace) private var namespace

    func body(content: Content) -> some View {
        if let id = node.attributes["matchedid"]?.string, let namespace {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}
