import SwiftUI

struct Lifecycle: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let id = node.id
        let taskID = node.listens(to: "task") ? node.attributes["taskid"] ?? .null : nil
        content
            .onAppear { if node.listens(to: "appear") { runtime.dispatch(id, "appear") } }
            .onDisappear { if node.listens(to: "disappear") { runtime.dispatch(id, "disappear") } }
            .task(id: taskID) { if taskID != nil { await runtime.dispatchAndWait(id, "task") } }
    }
}
