import SwiftUI

@main
struct SvelteHostApp: App {
  @State private var runtime = Runtime()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(runtime)
        .task { runtime.start() }
    }
  }
}

private struct RootView: View {
  @Environment(Runtime.self) private var runtime

  var body: some View {
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
  }
}
