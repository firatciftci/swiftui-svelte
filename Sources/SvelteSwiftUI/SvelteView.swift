import SwiftUI

public struct SvelteView: View {
    @State private var owner = RuntimeOwner()
    private let runtime: RuntimeSource
    private let component: String
    private let props: String
    private let actions: [String: @MainActor (JSONValue) -> Void]
    var urlHandling = URLHandling.automatic

    public init(
        source: URL,
        component: String = "default",
        props: [String: JSONValue] = [:],
        actions: [String: @MainActor (JSONValue) -> Void] = [:],
        reloadsOnChange: Bool = false,
        storage: String? = nil,
        modules: Array<NativeModule> = [],
        components: Array<NativeComponent> = [],
        onError: (@MainActor (ScriptError) -> Void)? = nil
    ) {
        runtime = .owned(
            RuntimeConfiguration(
                source: source, reloadsOnChange: reloadsOnChange, storage: storage, modules: modules,
                components: components, onError: onError))
        self.component = component
        self.props = Self.json(props)
        self.actions = actions
    }

    public init(
        runtime: SvelteRuntime,
        component: String = "default",
        props: [String: JSONValue] = [:],
        actions: [String: @MainActor (JSONValue) -> Void] = [:]
    ) {
        self.runtime = .shared(runtime)
        self.component = component
        self.props = Self.json(props)
        self.actions = actions
    }

    public var body: some View {
        let runtime = owner.runtime(for: runtime)
        MountedView(runtime: runtime, component: component, props: props, actions: actions, urlHandling: urlHandling)
            .id(ObjectIdentifier(runtime))
    }

    static func json(_ props: [String: JSONValue]) -> String {
        (try? BridgeJSON.encoder().encode(props)).flatMap { String(bytes: $0, encoding: .utf8) } ?? "{}"
    }
}

private struct MountedView: View {
    let runtime: SvelteRuntime
    let component: String
    let props: String
    let actions: [String: @MainActor (JSONValue) -> Void]
    let urlHandling: SvelteView.URLHandling
    @State private var handle: MountHandle?
    @State private var appearance: Int?
    @State private var safeAreaInsets = EdgeInsets()
    @State private var keyboardHeight = 0.0
    @State private var viewportSize = CGSize.zero
    @State private var systemScheme = ColorScheme.light
    @State private var isOverdue = false
    @State private var actionBox = ActionBox()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControl
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityInvertColors) private var invertColors
    @Environment(\.accessibilityShowButtonShapes) private var buttonShapes
    @Environment(\.legibilityWeight) private var legibilityWeight
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.displayScale) private var displayScale
    #if os(iOS) || os(visionOS)
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass
    #endif

    private static let appLanguage = Bundle.main.preferredLocalizations.first.map { Locale.Language(identifier: $0) }

    var body: some View {
        let phase = runtime.phase(of: handle?.id, isOverdue: isOverdue)
        let box = actionBox.holding(actions)
        VStack(spacing: 0) {
            switch phase {
            case let .mounted(root):
                NodeView(node: root)
                    .ifLet(Self.appLanguage) { $0.typesettingLanguage($1) }
            case .incompatible:
                ContentUnavailableView(
                    "Version mismatch",
                    systemImage: "exclamationmark.triangle",
                    description: Text(mismatchDescription)
                )
            case let .failed(error):
                ContentUnavailableView {
                    Label("This screen couldn't load", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.message)
                } actions: {
                    Button("Reload", action: runtime.reload)
                }
                .accessibilityIdentifier("svelte-failed")
            case .unresponsive:
                ContentUnavailableView {
                    Label("The app didn't start", systemImage: "hourglass")
                } description: {
                    Text(unresponsiveDescription)
                } actions: {
                    Button("Reload", action: runtime.reload)
                }
                .accessibilityIdentifier("svelte-unresponsive")
            case .loading:
                LaunchView()
            }
        }
        #if !canImport(UIKit)
            .preferredColorScheme(runtime.appearance)
        #endif
        #if DEBUG
            .overlay(alignment: .bottom) {
                if case .mounted = phase, let error = runtime.currentError {
                    ErrorOverlay(error: error, dismiss: runtime.dismissError, reload: runtime.reload)
                }
            }
            .overlay(alignment: .leading) {
                if case .mounted = phase, !runtime.diagnostics.isEmpty {
                    DiagnosticTray(diagnostics: runtime.diagnostics, dismiss: runtime.dismissDiagnostics)
                }
            }
        #endif
        .task(id: runtime.loads) {
            isOverdue = false
            guard runtime.loads > 0 else { return }
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { isOverdue = true }
        }
        .background {
            Color.clear
                .onGeometryChange(for: EdgeInsets.self, of: \.safeAreaInsets) { safeAreaInsets = $0 }
                .onGeometryChange(for: CGSize.self, of: \.size) { viewportSize = $0 }
                .ignoresSafeArea(.keyboard)
            SystemColorSchemeObserver(appearance: runtime.appearance) { systemScheme = $0 }
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
        .onOpenURL { url in
            let order = appearance ?? URLRouter.shared.nextAppearance()
            appearance = order
            URLRouter.shared.offer(url, to: runtime, appearance: order, handling: urlHandling)
        }
        .onAppear {
            if appearance == nil { appearance = URLRouter.shared.nextAppearance() }
            runtime.updateEnvironment(environment.dictionary)
            if handle == nil {
                let id = runtime.mount(component, props: props, actions: box.forwarding)
                handle = MountHandle(runtime: runtime, id: id)
            }
        }
        .onChange(of: props) { _, props in
            if let handle { runtime.update(handle.id, props: props, actions: box.forwarding) }
        }
        .onChange(of: box.names) {
            if let handle { runtime.update(handle.id, props: props, actions: box.forwarding) }
        }
        .onChange(of: environment) { _, environment in
            runtime.updateEnvironment(environment.dictionary)
        }
    }

    private var hostDescription: String {
        "This app's SvelteSwiftUI package is version \(SvelteRuntime.version) and uses protocol \(NodeStore.protocolVersion). Install the same release of swiftui-svelte from npm and SvelteSwiftUI from Swift Package Manager, then rebuild the bundle."
    }

    private var mismatchDescription: String {
        let bundle =
            if let identity = runtime.bundleIdentity {
                "The JavaScript bundle comes from swiftui-svelte \(identity.version) and uses bridge protocol \(identity.protocolVersion)."
            } else {
                "The JavaScript bundle uses bridge protocol \(runtime.store.bundleProtocolVersion.map(String.init) ?? "none")."
            }
        return "\(bundle) \(hostDescription)"
    }

    private var unresponsiveDescription: String {
        let bundle =
            if let identity = runtime.bundleIdentity {
                "The bundle comes from swiftui-svelte \(identity.version) and uses bridge protocol \(identity.protocolVersion)."
            } else {
                "The bundle doesn't say which swiftui-svelte release built it."
            }
        return
            "The JavaScript bundle didn't show \"\(component)\" within two seconds. \(bundle) This app's SvelteSwiftUI package is version \(SvelteRuntime.version) and uses bridge protocol \(NodeStore.protocolVersion). Install the same release of swiftui-svelte from npm and SvelteSwiftUI from Swift Package Manager, then rebuild the bundle."
    }

    private var environment: EnvironmentSnapshot {
        var snapshot = EnvironmentSnapshot(
            colorScheme: runtime.appearance ?? colorScheme,
            systemColorScheme: systemScheme,
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
        snapshot.viewportWidth = viewportSize.width
        snapshot.viewportHeight = viewportSize.height
        snapshot.pixelRatio = displayScale
        snapshot.fontScale = EnvironmentSnapshot.currentFontScale
        snapshot.accessibility = AccessibilitySettings(
            voiceOver: voiceOver,
            switchControl: switchControl,
            differentiateWithoutColor: differentiateWithoutColor,
            invertColors: invertColors,
            boldText: legibilityWeight == .bold,
            buttonShapes: buttonShapes
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
}

private nonisolated struct RuntimeKey: Equatable {
    let source: URL
    let reloadsOnChange: Bool
    let storage: String?
    let modules: Array<String>
    let components: Array<String>
}

private struct RuntimeConfiguration {
    let source: URL
    let reloadsOnChange: Bool
    let storage: String?
    let modules: Array<NativeModule>
    let components: Array<NativeComponent>
    let onError: (@MainActor (ScriptError) -> Void)?

    var key: RuntimeKey {
        RuntimeKey(
            source: source, reloadsOnChange: reloadsOnChange, storage: storage, modules: modules.map(\.name),
            components: components.map(\.name))
    }
}

private enum RuntimeSource {
    case owned(RuntimeConfiguration)
    case shared(SvelteRuntime)
}

private final class RuntimeOwner {
    private var owned: (key: RuntimeKey, runtime: SvelteRuntime)?

    func runtime(for source: RuntimeSource) -> SvelteRuntime {
        switch source {
        case let .shared(runtime):
            owned = nil
            return runtime
        case let .owned(configuration):
            let key = configuration.key
            if let owned, owned.key == key {
                owned.runtime.onError = configuration.onError
                return owned.runtime
            }
            let runtime = SvelteRuntime(
                source: configuration.source, reloadsOnChange: configuration.reloadsOnChange, storage: configuration.storage,
                modules: configuration.modules, components: configuration.components, onError: configuration.onError)
            owned = (key, runtime)
            return runtime
        }
    }
}

final class ActionBox {
    var actions: [String: @MainActor (JSONValue) -> Void] = [:]

    var names: Array<String> { actions.keys.sorted() }

    func holding(_ actions: [String: @MainActor (JSONValue) -> Void]) -> ActionBox {
        self.actions = actions
        return self
    }

    var forwarding: [String: @MainActor (JSONValue) -> Void] {
        var forwarding: [String: @MainActor (JSONValue) -> Void] = [:]
        for name in actions.keys {
            forwarding[name] = { [weak self] value in self?.actions[name]?(value) }
        }
        return forwarding
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

#if DEBUG
    private struct DiagnosticTray: View {
        let diagnostics: Array<Diagnostic>
        let dismiss: () -> Void
        @State private var isExpanded = false

        var body: some View {
            if isExpanded {
                list
            } else {
                Button {
                    withAnimation(.snappy) { isExpanded = true }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(diagnostics.count, format: .number)
                    }
                    .font(.caption2.bold())
                    .foregroundStyle(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 5)
                    .background(
                        .yellow, in: .rect(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: 10, topTrailingRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(diagnostics.count == 1 ? "1 warning" : "\(diagnostics.count) warnings")
                .accessibilityIdentifier("svelte-diagnostics")
                .ignoresSafeArea(edges: .leading)
                .transition(.move(edge: .leading))
            }
        }

        private var list: some View {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(diagnostic.message)
                                    .font(.caption.monospaced())
                                if let location = diagnostic.location {
                                    Text(location)
                                        .font(.caption2.monospaced())
                                        .opacity(0.7)
                                }
                            }
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 240)
                .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Dismiss", action: dismiss)
                    Spacer()
                    Button("Hide") { withAnimation(.snappy) { isExpanded = false } }
                }
                .font(.caption.bold())
                .buttonStyle(.borderless)
                .tint(.black)
            }
            .foregroundStyle(.black)
            .padding(14)
            .background(.yellow.gradient, in: .rect(cornerRadius: 16))
            .padding(.horizontal)
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .leading)))
        }
    }
#endif

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

private struct LaunchView: View {
    @State private var isShown = false

    var body: some View {
        ProgressView()
            .opacity(isShown ? 1 : 0)
            .task {
                try? await Task.sleep(for: .milliseconds(400))
                isShown = true
            }
    }
}
