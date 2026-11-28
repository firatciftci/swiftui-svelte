import SwiftUI

struct Lifecycle: ViewModifier {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    func body(content: Content) -> some View {
        let id = node.id
        content
            .ifLet(node.listens(to: "appear") ? id : nil) { view, id in
                view.onAppear { runtime.dispatch(id, "appear") }
            }
            .ifLet(node.listens(to: "disappear") ? id : nil) { view, id in
                view.onDisappear { runtime.dispatch(id, "disappear") }
            }
            .ifLet(node.listens(to: "task") ? node.attributes["taskid"] ?? .null : nil) { view, taskID in
                view.task(id: taskID) { await runtime.dispatchAndWait(id, "task") }
            }
    }
}
