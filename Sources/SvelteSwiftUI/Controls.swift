import SwiftUI

private struct ControlLabel: View {
    let node: Node

    var body: some View {
        ForEach(node.renderedChildren) { NodeView(node: $0) }
    }
}

struct PickerControl: View {
    let node: Node
    @Environment(Runtime.self) private var runtime

    var body: some View {
        let picker = Picker(
            node.attributes["label"]?.string ?? "",
            selection: Binding {
                node.attributes["value"] ?? .null
            } set: { value in
                node.attributes["value"] = value
                runtime.dispatch(node.id, "change", value.object)
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
    @Environment(Runtime.self) private var runtime

    var body: some View {
        let lower = node.attributes["min"]?.number ?? 0
        let bounds = lower...max(lower, node.attributes["max"]?.number ?? 1)
        let value = Binding {
            node.attributes["value"]?.number ?? bounds.lowerBound
        } set: { value in
            node.attributes["value"] = .number(value)
            runtime.dispatch(node.id, "input", value)
        }
        if let step = node.attributes["step"]?.number {
            Slider(value: value, in: bounds, step: step, label: { ControlLabel(node: node) }, onEditingChanged: editingChanged)
        } else {
            Slider(value: value, in: bounds, label: { ControlLabel(node: node) }, onEditingChanged: editingChanged)
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
    @Environment(Runtime.self) private var runtime

    var body: some View {
        let lower = node.attributes["min"]?.number ?? -.infinity
        Stepper(
            value: Binding {
                node.attributes["value"]?.number ?? 0
            } set: { value in
                node.attributes["value"] = .number(value)
                runtime.dispatch(node.id, "change", value)
            },
            in: lower...max(lower, node.attributes["max"]?.number ?? .infinity),
            step: node.attributes["step"]?.number ?? 1
        ) {
            ControlLabel(node: node)
        }
    }
}

struct DatePickerControl: View {
    let node: Node
    @Environment(Runtime.self) private var runtime

    var body: some View {
        let lower = node.attributes["min"]?.date ?? .distantPast
        let picker = DatePicker(
            selection: Binding {
                node.attributes["value"]?.date ?? .now
            } set: { date in
                node.attributes["value"] = .string(date.ISO8601Format(.init(includingFractionalSeconds: true)))
                runtime.dispatch(node.id, "change", date)
            },
            in: lower...max(lower, node.attributes["max"]?.date ?? .distantFuture),
            displayedComponents: components
        ) {
            ControlLabel(node: node)
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
                ProgressView(value: min(value, total), total: total) { ControlLabel(node: node) }
            }
        } else if node.renderedChildren.isEmpty {
            ProgressView()
        } else {
            ProgressView { ControlLabel(node: node) }
        }
    }
}
