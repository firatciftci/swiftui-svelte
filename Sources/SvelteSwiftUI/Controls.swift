import SwiftUI

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
                Choices.label(choice).tag(choice.attributes["value"] ?? .null)
            }
        } label: {
            if let label = node.attachment("label") {
                Children(node: label)
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
            Slider(value: value, in: bounds, step: step, label: { Children(node: node) }, onEditingChanged: editingChanged)
        } else {
            Slider(value: value, in: bounds, label: { Children(node: node) }, onEditingChanged: editingChanged)
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
            Children(node: node)
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
            Children(node: node)
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
                ProgressView(value: min(value, total), total: total) { Children(node: node) }
            }
        } else if node.renderedChildren.isEmpty {
            ProgressView()
        } else {
            ProgressView { Children(node: node) }
        }
    }
}

enum Choices {
    static func title(_ choice: Node) -> String {
        Whitespace.normal.collapsed(choice.children.filter { $0.kind == .text }.map(\.text).joined())
    }

    static func label(_ choice: Node) -> some View {
        Group {
            if let symbol = choice.attributes["symbol"]?.string {
                Label(title(choice), systemImage: symbol)
            } else {
                Text(title(choice))
            }
        }
    }

    static func toggled(_ value: JSONValue, in selection: Array<JSONValue>, order choices: Array<Node>) -> Array<JSONValue> {
        let isSelected = selection.contains(value)
        let known = choices.compactMap { $0.attributes["value"] }
        let kept = known.filter { $0 == value ? !isSelected : selection.contains($0) }
        let unknown = selection.filter { !known.contains($0) }
        return kept + unknown
    }
}

struct MultiPickerControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let choices = node.renderedChildren.filter { $0.name == "choice" }
        switch node.attributes["variant"]?.string {
        case "menu":
            Menu {
                ForEach(choices) { choice in
                    Toggle(isOn: isOn(choice, choices: choices)) { Choices.label(choice) }
                }
            } label: {
                LabeledContent {
                    Text(summary(choices))
                } label: {
                    label
                }
            }
            #if !os(macOS)
                .menuActionDismissBehavior(.disabled)
            #endif
        case "navigation":
            NavigationLink {
                List { rows(choices) }
                    .navigationTitle(node.attributes["label"]?.string ?? "")
            } label: {
                LabeledContent {
                    Text(summary(choices))
                } label: {
                    label
                }
            }
        default:
            if node.attachment("label") != nil || node.attributes["label"] != nil {
                Section {
                    rows(choices)
                } header: {
                    label
                }
            } else {
                rows(choices)
            }
        }
    }

    private var selection: Array<JSONValue> {
        if case let .array(values) = node.attributes["value"] { values } else { [] }
    }

    @ViewBuilder private var label: some View {
        if let label = node.attachment("label") {
            Children(node: label)
        } else {
            Text(node.attributes["label"]?.string ?? "")
        }
    }

    private func summary(_ choices: Array<Node>) -> String {
        let selection = selection
        return choices.filter { selection.contains($0.attributes["value"] ?? .null) }.map(Choices.title).formatted(.list(type: .and))
    }

    private func rows(_ choices: Array<Node>) -> some View {
        ForEach(choices) { choice in
            let isSelected = selection.contains(choice.attributes["value"] ?? .null)
            Button {
                toggle(choice, choices: choices)
            } label: {
                HStack {
                    Choices.label(choice).foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                        .opacity(isSelected ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private func isOn(_ choice: Node, choices: Array<Node>) -> Binding<Bool> {
        Binding {
            selection.contains(choice.attributes["value"] ?? .null)
        } set: { _ in
            toggle(choice, choices: choices)
        }
    }

    private func toggle(_ choice: Node, choices: Array<Node>) {
        let values = Choices.toggled(choice.attributes["value"] ?? .null, in: selection, order: choices)
        runtime.edit(node, "value", to: .array(values), event: "change", payload: values.map(\.object))
    }
}

enum Days {
    private static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    static func date(_ day: String) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10 else { return nil }
        let expected = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
            gregorian.dateComponents([.year, .month, .day], from: date) == expected
        else { return nil }
        return date
    }

    static func components(_ day: String, in calendar: Calendar) -> DateComponents? {
        date(day).map { calendar.dateComponents([.calendar, .era, .year, .month, .day], from: $0) }
    }

    static func day(_ components: DateComponents, in calendar: Calendar) -> String? {
        guard let date = (components.calendar ?? calendar).date(from: components) else { return nil }
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func bound(_ value: JSONValue?) -> Date? {
        guard let string = value?.string else { return nil }
        return date(string) ?? value?.date
    }
}

struct MultiDatePickerControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    @Environment(\.calendar) private var calendar

    var body: some View {
        let selection = Binding<Set<DateComponents>> {
            guard case let .array(values) = node.attributes["value"] else { return [] }
            return Set(values.compactMap { $0.string.flatMap { Days.components($0, in: calendar) } })
        } set: { components in
            let days = components.compactMap { Days.day($0, in: calendar) }.sorted()
            runtime.edit(node, "value", to: .array(days.map(JSONValue.string)), event: "change", payload: days)
        }
        #if os(macOS)
            Text("<multidatepicker> isn't available on macOS").foregroundStyle(.red)
        #else
            let lower = Days.bound(node.attributes["min"]).map { calendar.startOfDay(for: $0) }
            let upper = Days.bound(node.attributes["max"]).flatMap {
                calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: $0))
            }
            switch (lower, upper) {
            case let (lower?, upper?):
                MultiDatePicker(selection: selection, in: lower..<max(lower, upper)) { Children(node: node) }
            case let (lower?, nil):
                MultiDatePicker(selection: selection, in: lower...) { Children(node: node) }
            case let (nil, upper?):
                MultiDatePicker(selection: selection, in: ..<upper) { Children(node: node) }
            case (nil, nil):
                MultiDatePicker(selection: selection) { Children(node: node) }
            }
        #endif
    }
}

struct ColorPickerControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime
    @Environment(\.self) private var environment

    var body: some View {
        ColorPicker(
            selection: Binding {
                Palette.color(node.attributes["value"]?.string) ?? .black
            } set: { color in
                let hex = Palette.hex(color.resolve(in: environment))
                guard hex != node.attributes["value"]?.string else { return }
                runtime.edit(node, "value", to: .string(hex), event: "change", payload: hex)
            },
            supportsOpacity: node.attributes["supportsopacity"]?.isTrue ?? true
        ) {
            Children(node: node)
        }
    }
}
