import SwiftUI

public struct SvelteView: View {
    @State private var runtime: Runtime

    public init(source: URL, reloadsOnChange: Bool = false) {
        _runtime = State(initialValue: Runtime(source: source, reloadsOnChange: reloadsOnChange))
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
            } else if let root = runtime.store.root {
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
        .environment(runtime)
        .task { runtime.start() }
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
