import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct Symbol: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let name = attributes["name"]?.string ?? "questionmark"
        let image = Image(systemName: name, variableValue: attributes["value"]?.number)
        image
            .symbolVariant(Self.variants(attributes["variant"]?.string))
            .ifLet(Self.rendering(attributes["rendering"]?.string)) { $0.symbolRenderingMode($1) }
            .modifier(Palette3(colors: Self.colors(attributes["colors"])))
            .modifier(SymbolEffect(effect: attributes["effect"]?.string, trigger: attributes["trigger"], attributes: attributes))
            .ifLet(attributes["label"]?.string) { $0.accessibilityLabel($1) }
    }

    static func variants(_ value: String?) -> SymbolVariants {
        var variants = SymbolVariants.none
        for token in (value ?? "").split(separator: " ") {
            switch token {
            case "fill": variants = variants.fill
            case "slash": variants = variants.slash
            case "circle": variants = variants.circle
            case "square": variants = variants.square
            case "rectangle": variants = variants.rectangle
            default: continue
            }
        }
        return variants
    }

    static func rendering(_ name: String?) -> SymbolRenderingMode? {
        switch name {
        case "monochrome": .monochrome
        case "hierarchical": .hierarchical
        case "palette": .palette
        case "multicolor": .multicolor
        default: nil
        }
    }

    static func colors(_ value: JSONValue?) -> Array<Color> {
        guard case let .array(items) = value else { return [] }
        return items.compactMap { Palette.color($0.string) }
    }
}

private struct Palette3: ViewModifier {
    let colors: Array<Color>

    func body(content: Content) -> some View {
        switch colors.count {
        case 0: content
        case 1: content.foregroundStyle(colors[0])
        case 2: content.foregroundStyle(colors[0], colors[1])
        default: content.foregroundStyle(colors[0], colors[1], colors[2])
        }
    }
}

enum SymbolAnimation: String {
    case bounce, pulse, variableColor, breathe, rotate, wiggle, scale

    init?(_ name: String?) {
        guard let name, let animation = Self(rawValue: name) else { return nil }
        self = animation
    }
}

private struct SymbolEffect: ViewModifier {
    let effect: String?
    let trigger: JSONValue?
    let attributes: [String: JSONValue]
    @State private var isScaled = false

    func body(content: Content) -> some View {
        if let animation = SymbolAnimation(effect) {
            if let trigger {
                triggered(content, animation, trigger)
            } else {
                repeating(content, animation, isActive: attributes["active"]?.isTrue ?? true)
            }
        } else {
            content
        }
    }

    @ViewBuilder private func triggered(_ content: Content, _ animation: SymbolAnimation, _ trigger: JSONValue) -> some View {
        switch animation {
        case .bounce: content.symbolEffect(.bounce, value: trigger)
        case .pulse: content.symbolEffect(.pulse, value: trigger)
        case .variableColor: content.symbolEffect(.variableColor, value: trigger)
        case .breathe: content.symbolEffect(.breathe, value: trigger)
        case .rotate: content.symbolEffect(.rotate, value: trigger)
        case .wiggle: content.symbolEffect(.wiggle, value: trigger)
        case .scale:
            content
                .symbolEffect(.scale.up, isActive: isScaled)
                .task(id: isScaled) {
                    guard isScaled else { return }
                    try? await Task.sleep(for: .milliseconds(300))
                    isScaled = false
                }
                .onChange(of: trigger) { isScaled = true }
        }
    }

    @ViewBuilder private func repeating(_ content: Content, _ animation: SymbolAnimation, isActive: Bool) -> some View {
        switch animation {
        case .bounce: content.symbolEffect(.bounce, isActive: isActive)
        case .pulse: content.symbolEffect(.pulse, isActive: isActive)
        case .variableColor: content.symbolEffect(.variableColor, isActive: isActive)
        case .breathe: content.symbolEffect(.breathe, isActive: isActive)
        case .rotate: content.symbolEffect(.rotate, isActive: isActive)
        case .wiggle: content.symbolEffect(.wiggle, isActive: isActive)
        case .scale: content.symbolEffect(.scale.up, isActive: isActive)
        }
    }
}

@MainActor enum BundleImages {
    #if canImport(UIKit)
        typealias PlatformImage = UIImage
    #else
        typealias PlatformImage = NSImage
    #endif

    private static var images: [String: PlatformImage] = [:]

    static func image(_ file: String, in bundle: Bundle = .main) -> Image? {
        let key = "\(bundle.bundlePath)/\(file)"
        if let image = images[key] { return Image(platform: image) }
        guard let url = bundle.resourceURL?.appendingPathComponent(file), let image = load(url) else { return nil }
        if images.count >= 64 { images.removeAll() }
        images[key] = image
        return Image(platform: image)
    }

    private static func load(_ url: URL) -> PlatformImage? {
        #if canImport(UIKit)
            UIImage(contentsOfFile: url.path)
        #else
            NSImage(contentsOf: url)
        #endif
    }
}

extension Image {
    init(platform image: BundleImages.PlatformImage) {
        #if canImport(UIKit)
            self.init(uiImage: image)
        #else
            self.init(nsImage: image)
        #endif
    }
}

struct ImageElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let isDecorative = attributes["decorative"]?.isTrue ?? false
        let image: Image =
            if let name = attributes["name"]?.string, isDecorative {
                Image(decorative: name)
            } else if let name = attributes["name"]?.string {
                Image(name)
            } else if let file = attributes["file"]?.string, let image = BundleImages.image(file) {
                image
            } else {
                Image(systemName: "photo")
            }
        let rendered = image.renderingMode(Self.renderingMode(attributes["renderingmode"]?.string))
        Self.sized(
            Self.interpolation(attributes["interpolation"]?.string).map { rendered.interpolation($0) } ?? rendered,
            fit: attributes["fit"]?.string
        )
        .ifLet(attributes["label"]?.string) { $0.accessibilityLabel($1) }
        .gated(isDecorative) { $0.accessibilityHidden(true) }
    }

    @ViewBuilder static func sized(_ image: Image, fit: String?) -> some View {
        switch fit {
        case "fit": image.resizable().scaledToFit()
        case "fill": image.resizable().scaledToFill()
        case "stretch": image.resizable()
        case "tile": image.resizable(resizingMode: .tile)
        default: image
        }
    }

    static func interpolation(_ name: String?) -> Image.Interpolation? {
        switch name {
        case "none": Image.Interpolation.none
        case "low": .low
        case "medium": .medium
        case "high": .high
        default: nil
        }
    }

    static func renderingMode(_ name: String?) -> Image.TemplateRenderingMode? {
        switch name {
        case "original": .original
        case "template": .template
        default: nil
        }
    }
}

struct RemoteImage: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    static let invalidSource = "The image's src is empty or isn't a full URL, such as https://example.com/photo.png."

    static func url(_ src: JSONValue?) -> URL? {
        guard let text = src?.string, let url = URL(string: text), url.scheme?.isEmpty == false else { return nil }
        return url
    }

    var body: some View {
        let attributes = node.attributes
        if let url = Self.url(attributes["src"]) {
            let curve = MotionCurve(attributes["animation"]).map(\.animation)
            AsyncImage(url: url, transaction: Transaction(animation: curve)) { phase in
                switch phase {
                case let .success(image):
                    ImageElement.sized(image, fit: attributes["fit"]?.string ?? "fit")
                        .onAppear { runtime.dispatch(node.id, "load", waits: false) }
                case let .failure(error):
                    failure(error.localizedDescription)
                case .empty:
                    if let placeholder = node.attachment("placeholder") {
                        Children(node: placeholder)
                    } else {
                        ProgressView()
                    }
                @unknown default:
                    ProgressView()
                }
            }
        } else {
            failure(Self.invalidSource).id(attributes["src"])
        }
    }

    private func failure(_ message: String) -> some View {
        Group {
            if let failure = node.attachment("failure") {
                Children(node: failure)
            } else {
                Image(systemName: "photo").foregroundStyle(.tertiary)
            }
        }
        .onAppear { runtime.dispatch(node.id, "error", message, waits: false) }
    }
}

struct LabelElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let label = Label {
            if let title = attributes["title"]?.string {
                Text(title)
            } else {
                Children(node: node)
            }
        } icon: {
            if let icon = node.attachment("icon") {
                Children(node: icon)
            } else if let symbol = attributes["symbol"]?.string {
                Image(systemName: symbol)
            } else if let name = attributes["image"]?.string {
                Image(name)
            }
        }
        switch attributes["variant"]?.string {
        case "titleOnly": label.labelStyle(.titleOnly)
        case "iconOnly": label.labelStyle(.iconOnly)
        case "titleAndIcon": label.labelStyle(.titleAndIcon)
        default: label
        }
    }
}

struct LinkElement: View {
    let node: Node

    var body: some View {
        let title = node.attributes["title"]?.string
        if let url = node.attributes["href"]?.string.flatMap(URL.init(string:)) {
            Link(destination: url) {
                if let title { Text(title) } else { Children(node: node) }
            }
        } else if let title {
            Text(title)
        } else {
            Children(node: node)
        }
    }
}

struct ShareElement: View {
    let node: Node

    var body: some View {
        let attributes = node.attributes
        let item = attributes["item"]?.string ?? ""
        let subject = attributes["subject"]?.string.map { Text($0) }
        let message = attributes["message"]?.string.map { Text($0) }
        let hasLabel = attributes["title"] != nil || !node.renderedChildren.isEmpty
        if let url = URL(string: item), url.scheme != nil {
            if hasLabel {
                ShareLink(item: url, subject: subject, message: message) { label }
            } else {
                ShareLink(item: url, subject: subject, message: message)
            }
        } else if hasLabel {
            ShareLink(item: item, subject: subject, message: message) { label }
        } else {
            ShareLink(item: item, subject: subject, message: message)
        }
    }

    @ViewBuilder private var label: some View {
        if let title = node.attributes["title"]?.string {
            Label(title, systemImage: "square.and.arrow.up")
        } else {
            Children(node: node)
        }
    }
}
