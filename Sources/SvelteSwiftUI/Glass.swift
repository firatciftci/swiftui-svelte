import SwiftUI

extension EnvironmentValues {
    @Entry var glassNamespace: Namespace.ID?
}

struct GlassContainer: View {
    let node: Node
    @Namespace private var namespace

    var body: some View {
        #if os(visionOS)
            Children(node: node)
        #else
            if #available(iOS 26, macOS 26, *) {
                GlassEffectContainer(spacing: node.attributes["spacing"]?.number.map { CGFloat($0) }) {
                    Children(node: node)
                }
                .environment(\.glassNamespace, namespace)
            } else {
                Children(node: node)
            }
        #endif
    }
}

struct GlassSurface: ViewModifier {
    let attributes: [String: JSONValue]
    @Environment(\.glassNamespace) private var namespace

    func body(content: Content) -> some View {
        #if os(visionOS)
            content
        #else
            if #available(iOS 26, macOS 26, *), let glass = Self.glass(attributes["glasseffect"]) {
                content
                    .glassEffect(glass, in: Self.shape(attributes["glasseffect"]))
                    .ifLet(namespace.flatMap { ns in attributes["glassid"]?.string.map { ($0, ns) } }) { $0.glassEffectID($1.0, in: $1.1) }
                    .ifLet(namespace.flatMap { ns in attributes["glassunion"]?.string.map { ($0, ns) } }) {
                        $0.glassEffectUnion(id: $1.0, namespace: $1.1)
                    }
            } else {
                content
            }
        #endif
    }

    #if !os(visionOS)
        @available(iOS 26, macOS 26, *)
        static func glass(_ value: JSONValue?) -> Glass? {
            let options: [String: JSONValue]
            switch value {
            case .bool(true), .string(""): options = [:]
            case let .string(variant): options = ["variant": .string(variant)]
            case let .object(object): options = object
            default: return nil
            }
            var glass: Glass
            switch options["variant"]?.string {
            case nil, "regular": glass = .regular
            case "clear": glass = .clear
            case "identity": glass = .identity
            default: return nil
            }
            if let tint = Palette.color(options["tint"]?.string) { glass = glass.tint(tint) }
            if options["interactive"]?.isTrue == true { glass = glass.interactive() }
            return glass
        }
    #endif

    static func shape(_ value: JSONValue?) -> AnyShape {
        guard case let .object(options) = value else { return AnyShape(Capsule()) }
        return Effects.shape(options["shape"]) ?? AnyShape(Capsule())
    }
}
