import SwiftUI

public struct SvelteView: View {
    @State private var runtime: SvelteRuntime
    @State private var handle: MountHandle?
    @State private var safeAreaInsets = EdgeInsets()
    @State private var keyboardHeight = 0.0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS) || os(visionOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif
    private let component: String
    private let props: String
    private let actions: [String: @MainActor (Any) -> Void]

    public init(
        source: URL,
        component: String = "default",
        props: [String: Any] = [:],
        actions: [String: @MainActor (Any) -> Void] = [:],
        reloadsOnChange: Bool = false
    ) {
        self.init(
            runtime: SvelteRuntime(source: source, reloadsOnChange: reloadsOnChange),
            component: component,
            props: props,
            actions: actions)
    }

    public init(
        runtime: SvelteRuntime,
        component: String = "default",
        props: [String: Any] = [:],
        actions: [String: @MainActor (Any) -> Void] = [:]
    ) {
        _runtime = State(initialValue: runtime)
        self.component = component
        self.props = Self.json(props)
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            if !runtime.store.isCompatible {
                let bundle = runtime.store.bundleProtocolVersion.map(String.init) ?? "none"
                ContentUnavailableView(
                    "Version mismatch",
                    systemImage: "exclamationmark.triangle",
                    description: Text(
                        "The JavaScript bundle uses bridge protocol \(bundle), but this app's SvelteSwiftUI package uses protocol \(NodeStore.protocolVersion). Install the same release of swiftui-svelte from npm and SvelteSwiftUI from Swift Package Manager, then rebuild the bundle."
                    )
                )
            } else if let root = runtime.store.root(for: handle?.id) {
                NodeView(node: root)
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .bottom) {
            #if DEBUG
                if let error = runtime.error ?? runtime.store.error.map({ ScriptError(message: $0, frames: []) }) {
                    ErrorOverlay(error: error, dismiss: runtime.dismissError, reload: runtime.restart)
                }
            #endif
        }
        .background {
            Color.clear
                .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets) { safeAreaInsets = $0 }
                .ignoresSafeArea(.keyboard)
        }
        #if os(iOS)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) {
                keyboardHeight = Self.keyboardHeight($0)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
        #endif
        .environment(runtime)
        .onAppear {
            runtime.updateEnvironment(environment.dictionary)
            if handle == nil {
                handle = MountHandle(runtime: runtime, id: runtime.mount(component, props: props, actions: actions))
            }
        }
        .onChange(of: props) { _, props in
            if let handle { runtime.update(handle.id, props: props, actions: actions) }
        }
        .onChange(of: environment) { _, environment in
            runtime.updateEnvironment(environment.dictionary)
        }
    }

    private var environment: EnvironmentSnapshot {
        var snapshot = EnvironmentSnapshot(
            colorScheme: colorScheme,
            increaseContrast: contrast == .increased,
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            dynamicTypeSize: dynamicTypeSize,
            locale: locale,
            timeZone: timeZone,
            layoutDirection: layoutDirection,
            scenePhase: scenePhase,
            safeAreaInsets: safeAreaInsets,
            keyboardHeight: keyboardHeight
        )
        #if os(iOS) || os(visionOS)
            snapshot.horizontalSizeClass = EnvironmentSnapshot.name(of: horizontalSizeClass)
            snapshot.verticalSizeClass = EnvironmentSnapshot.name(of: verticalSizeClass)
        #endif
        return snapshot
    }

    #if os(iOS)
        private static func keyboardHeight(_ notification: Notification) -> Double {
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return 0 }
            let screenHeight = (notification.object as? UIScreen)?.bounds.height ?? frame.maxY
            return max(0, screenHeight - frame.minY)
        }
    #endif

    static func json(_ props: [String: Any]) -> String {
        let value = props.mapValues(jsonCompatible)
        guard JSONSerialization.isValidJSONObject(value),
            let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .withoutEscapingSlashes]),
            let json = String(bytes: data, encoding: .utf8)
        else {
            print("[svelte] Props must be JSON values: strings, numbers, booleans, dates, URLs, arrays, and dictionaries.")
            return "{}"
        }
        return json
    }

    private static func jsonCompatible(_ value: Any) -> Any {
        switch value {
        case let date as Date: date.ISO8601Format(.init(includingFractionalSeconds: true))
        case let url as URL: url.absoluteString
        case let array as Array<Any>: array.map(jsonCompatible)
        case let dictionary as [String: Any]: dictionary.mapValues(jsonCompatible)
        case Optional<Any>.none: NSNull()
        default: value
        }
    }
}

private final class MountHandle {
    let runtime: SvelteRuntime
    let id: Int

    init(runtime: SvelteRuntime, id: Int) {
        self.runtime = runtime
        self.id = id
    }

    deinit {
        let runtime = runtime
        let id = id
        Task { @MainActor in runtime.unmount(id) }
    }
}

private struct ErrorOverlay: View {
    let error: ScriptError
    let dismiss: () -> Void
    let reload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("JavaScript error", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(error.message)
                .font(.callout.monospaced())
                .textSelection(.enabled)
            if let frame = error.frames.first {
                Text(frame.location)
                    .font(.caption.monospaced())
                    .opacity(0.8)
            }
            if error.frames.count > 1 {
                DisclosureGroup("Stack trace") {
                    ScrollView {
                        Text(
                            error.frames.map { "\($0.function.isEmpty ? "<anonymous>" : $0.function)  \($0.location)" }.joined(
                                separator: "\n")
                        )
                        .font(.caption2.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
                .font(.caption)
            }
            HStack {
                Button("Dismiss", action: dismiss)
                Spacer()
                Button("Reload", action: reload)
                    .bold()
            }
            .buttonStyle(.borderless)
            .tint(.white)
        }
        .foregroundStyle(.white)
        .padding()
        .background(.red.gradient, in: .rect(cornerRadius: 16))
        .padding()
        .accessibilityIdentifier("svelte-error")
    }
}
