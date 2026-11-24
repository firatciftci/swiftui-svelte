import SwiftUI

public struct SvelteView: View {
    @State private var runtime: Runtime

    public init(source: URL, reloadsOnChange: Bool = false) {
        _runtime = State(initialValue: Runtime(source: source, reloadsOnChange: reloadsOnChange))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let root = runtime.store.root {
                NodeView(node: root)
            } else {
                ProgressView()
            }
        }
        .overlay(alignment: .bottom) {
            if let error = runtime.error {
                Text(error)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .padding()
                    .background(.red, in: .rect(cornerRadius: 12))
                    .padding()
            }
        }
        .environment(runtime)
        .task { runtime.start() }
    }
}
