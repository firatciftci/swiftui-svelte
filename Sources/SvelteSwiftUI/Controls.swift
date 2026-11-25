import SwiftUI

struct TextFieldControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    @State private var text: String
    @State private var pending: Task<Void, Never>?

    init(node: Node) {
        self.node = node
        _text = State(initialValue: node.attributes["value"]?.string ?? "")
    }

    var body: some View {
        let value = node.attributes["value"]?.string
        TextField(node.attributes["placeholder"]?.string ?? "", text: $text)
            .onSubmit {
                if pending != nil { send() }
                runtime.dispatch(node.id, "submit")
            }
            .onChange(of: text) { _, typed in
                guard typed != node.attributes["value"]?.string else { return }
                node.attributes["value"] = .string(typed)
                pending?.cancel()
                guard let delay = node.attributes["debounce"]?.number, delay > 0 else { return send() }
                pending = Task {
                    try? await Task.sleep(for: .milliseconds(delay))
                    if !Task.isCancelled { send() }
                }
            }
            .onChange(of: value) { _, value in
                if let value, value != text { text = value }
            }
            .modifier(Focusable(node: node))
    }

    private func send() {
        pending?.cancel()
        pending = nil
        runtime.dispatch(node.id, "input", text)
        if let settled = node.attributes["value"]?.string, settled != text { text = settled }
    }
}

struct PickerControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let picker = Picker(
            selection: Binding {
                node.attributes["value"] ?? .null
            } set: { value in
                runtime.edit(node, "value", to: value, event: "change", payload: value.object)
            }
        ) {
            ForEach(node.renderedChildren.filter { $0.name == "choice" }) { choice in
                let title = choice.children.filter { $0.kind == .text }.map(\.text).joined()
                Group {
                    if let symbol = choice.attributes["symbol"]?.string {
                        Label(title, systemImage: symbol)
                    } else {
                        Text(title)
                    }
                }
                .tag(choice.attributes["value"] ?? .null)
            }
        } label: {
            if let label = node.attachment("label") {
                Slot(node: label)
            } else {
                Text(node.attributes["label"]?.string ?? "")
            }
        }
        switch node.attributes["variant"]?.string {
        case "menu": picker.pickerStyle(.menu)
        case "segmented": picker.pickerStyle(.segmented)
        case "inline": picker.pickerStyle(.inline)
        #if !os(macOS)
            case "wheel": picker.pickerStyle(.wheel)
            case "navigation": picker.pickerStyle(.navigationLink)
        #endif
        default: picker
        }
    }
}

struct SliderControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let lower = node.attributes["min"]?.number ?? 0
        let bounds = lower...max(lower, node.attributes["max"]?.number ?? 1)
        let value = Binding {
            node.attributes["value"]?.number ?? bounds.lowerBound
        } set: { value in
            runtime.edit(node, "value", to: .number(value), event: "input", payload: value)
        }
        if let step = node.attributes["step"]?.number {
            Slider(value: value, in: bounds, step: step, label: { Slot(node: node) }, onEditingChanged: editingChanged)
        } else {
            Slider(value: value, in: bounds, label: { Slot(node: node) }, onEditingChanged: editingChanged)
        }
    }

    private func editingChanged(_ editing: Bool) {
        if !editing {
            runtime.dispatch(node.id, "change", node.attributes["value"]?.number ?? 0)
        }
    }
}

struct StepperControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let lower = node.attributes["min"]?.number ?? -.infinity
        Stepper(
            value: Binding {
                node.attributes["value"]?.number ?? 0
            } set: { value in
                runtime.edit(node, "value", to: .number(value), event: "change", payload: value)
            },
            in: lower...max(lower, node.attributes["max"]?.number ?? .infinity),
            step: node.attributes["step"]?.number ?? 1
        ) {
            Slot(node: node)
        }
    }
}

struct DatePickerControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let lower = node.attributes["min"]?.date ?? .distantPast
        let picker = DatePicker(
            selection: Binding {
                node.attributes["value"]?.date ?? .now
            } set: { date in
                let value = JSONValue.string(date.ISO8601Format(.init(includingFractionalSeconds: true)))
                runtime.edit(node, "value", to: value, event: "change", payload: date)
            },
            in: lower...max(lower, node.attributes["max"]?.date ?? .distantFuture),
            displayedComponents: components
        ) {
            Slot(node: node)
        }
        switch node.attributes["variant"]?.string {
        case "compact": picker.datePickerStyle(.compact)
        case "graphical": picker.datePickerStyle(.graphical)
        #if !os(macOS)
            case "wheel": picker.datePickerStyle(.wheel)
        #endif
        default: picker
        }
    }

    private var components: DatePickerComponents {
        switch node.attributes["components"]?.string {
        case "date": .date
        case "time": .hourAndMinute
        default: [.date, .hourAndMinute]
        }
    }
}

struct ProgressControl: View {
    let node: Node

    var body: some View {
        if let value = node.attributes["value"]?.number {
            let total = node.attributes["total"]?.number ?? 1
            if node.renderedChildren.isEmpty {
                ProgressView(value: min(value, total), total: total)
            } else {
                ProgressView(value: min(value, total), total: total) { Slot(node: node) }
            }
        } else if node.renderedChildren.isEmpty {
            ProgressView()
        } else {
            ProgressView { Slot(node: node) }
        }
    }
}
