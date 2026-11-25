import SwiftUI

enum Inputs {
    static func role(_ name: String?) -> ButtonRole? {
        switch name {
        case "destructive": return .destructive
        case "cancel": return .cancel
        case "confirm", "close":
            if #available(iOS 26, macOS 26, visionOS 26, *) { return name == "confirm" ? .confirm : .close }
            return nil
        default: return nil
        }
    }

    static func controlSize(_ name: String?) -> ControlSize? {
        switch name {
        case "mini": .mini
        case "small": .small
        case "regular": .regular
        case "large": .large
        case "extraLarge": .extraLarge
        default: nil
        }
    }

    static func borderShape(_ value: JSONValue?) -> ButtonBorderShape? {
        switch value {
        case let .number(radius): .roundedRectangle(radius: max(radius, 0))
        case .string("automatic"): .automatic
        case .string("capsule"): .capsule
        case .string("roundedRectangle"): .roundedRectangle
        case .string("circle"): .circle
        default: nil
        }
    }

    static func submitLabel(_ name: String?) -> SubmitLabel? {
        switch name {
        case "done": .done
        case "go": .go
        case "send": .send
        case "join": .join
        case "route": .route
        case "search": .search
        case "return": .return
        case "next": .next
        case "continue": .continue
        default: nil
        }
    }

    static func lineLimit(_ value: JSONValue?) -> ClosedRange<Int>? {
        let bounds: Array<Double> =
            switch value {
            case let .number(lines): [1, lines]
            case let .array(items) where items.count == 2: items.compactMap(\.number)
            default: []
            }
        guard bounds.count == 2, bounds[0] >= 1, bounds[1] >= 1 else { return nil }
        return Int(bounds[0])...max(Int(bounds[0]), Int(bounds[1]))
    }

    #if os(iOS) || os(visionOS)
        static func keyboardType(_ name: String?) -> UIKeyboardType? {
            switch name {
            case "default": .default
            case "ascii": .asciiCapable
            case "numbersAndPunctuation": .numbersAndPunctuation
            case "url": .URL
            case "number": .numberPad
            case "phone": .phonePad
            case "namePhone": .namePhonePad
            case "email": .emailAddress
            case "decimal": .decimalPad
            case "twitter": .twitter
            case "webSearch": .webSearch
            case "asciiNumber": .asciiCapableNumberPad
            default: nil
            }
        }

        static func contentType(_ name: String?) -> UITextContentType? {
            switch name {
            case "name": .name
            case "givenName": .givenName
            case "middleName": .middleName
            case "familyName": .familyName
            case "nickname": .nickname
            case "jobTitle": .jobTitle
            case "organization": .organizationName
            case "email": .emailAddress
            case "phone": .telephoneNumber
            case "url": .URL
            case "username": .username
            case "password": .password
            case "newPassword": .newPassword
            case "oneTimeCode": .oneTimeCode
            case "streetAddress": .fullStreetAddress
            case "addressLine1": .streetAddressLine1
            case "addressLine2": .streetAddressLine2
            case "city": .addressCity
            case "state": .addressState
            case "postalCode": .postalCode
            case "country": .countryName
            case "creditCardNumber": .creditCardNumber
            case "location": .location
            case "birthdate": .birthdate
            default: nil
            }
        }

        static func autocapitalization(_ name: String?) -> TextInputAutocapitalization? {
            switch name {
            case "never": .never
            case "words": .words
            case "sentences": .sentences
            case "characters": .characters
            default: nil
            }
        }
    #endif
}

struct ButtonElement: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let attributes = node.attributes
        styled(
            Button(role: Inputs.role(attributes["role"]?.string)) {
                runtime.dispatch(node.id, "click", waits: false)
            } label: {
                ForEach(node.renderedChildren) { NodeView(node: $0) }
            }
        )
        .ifLet(Inputs.borderShape(attributes["bordershape"])) { $0.buttonBorderShape($1) }
        .buttonRepeatBehavior(attributes["repeat"]?.isTrue == true ? .enabled : .automatic)
    }

    @ViewBuilder private func styled(_ button: some View) -> some View {
        switch node.attributes["variant"]?.string {
        case "automatic": button
        case "plain": button.buttonStyle(.plain)
        case "bordered": button.buttonStyle(.bordered)
        case "prominent": button.buttonStyle(.borderedProminent)
        case "glass":
            if #available(iOS 26, macOS 26, visionOS 26, *) {
                button.buttonStyle(.glass)
            } else {
                button.buttonStyle(.bordered)
            }
        case "glassProminent":
            if #available(iOS 26, macOS 26, visionOS 26, *) {
                button.buttonStyle(.glassProminent)
            } else {
                button.buttonStyle(.borderedProminent)
            }
        default: button.buttonStyle(.borderless)
        }
    }
}

struct ToggleElement: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let toggle = Toggle(
            isOn: Binding {
                node.attributes["checked"]?.isTrue ?? false
            } set: { value in
                runtime.edit(node, "checked", to: .bool(value), event: "change", payload: value)
            }
        ) {
            ForEach(node.renderedChildren) { NodeView(node: $0) }
        }
        switch node.attributes["variant"]?.string {
        case "switch": toggle.toggleStyle(.switch)
        case "button": toggle.toggleStyle(.button)
        #if os(macOS)
            case "checkbox": toggle.toggleStyle(.checkbox)
        #endif
        default: toggle
        }
    }
}

struct TextInputControl: View {
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
        field
            .modifier(TextInputTraits(attributes: node.attributes))
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

    @ViewBuilder private var field: some View {
        let attributes = node.attributes
        let placeholder = attributes["placeholder"]?.string ?? ""
        switch node.name {
        case "texteditor":
            TextEditor(text: $text)
        case "securefield":
            SecureField(placeholder, text: $text).modifier(FieldStyle(variant: attributes["variant"]?.string))
        default:
            if attributes["axis"]?.string == "vertical" {
                TextField(placeholder, text: $text, axis: .vertical)
                    .ifLet(Inputs.lineLimit(attributes["lines"])) { $0.lineLimit($1) }
                    .modifier(FieldStyle(variant: attributes["variant"]?.string))
            } else {
                TextField(placeholder, text: $text).modifier(FieldStyle(variant: attributes["variant"]?.string))
            }
        }
    }

    private func send() {
        pending?.cancel()
        pending = nil
        runtime.dispatch(node.id, "input", text)
        if let settled = node.attributes["value"]?.string, settled != text { text = settled }
    }
}

struct NumberFieldControl: View {
    let node: Node
    @Environment(SvelteRuntime.self) private var runtime

    var body: some View {
        let attributes = node.attributes
        let placeholder = attributes["placeholder"]?.string ?? ""
        let value = Binding<Double?> {
            node.attributes["value"]?.number
        } set: { number in
            let value = number.map(JSONValue.number) ?? .null
            runtime.edit(node, "value", to: value, event: "input", payload: value.object)
        }
        Group {
            switch attributes["format"] {
            case .string("integer"):
                TextField(placeholder, value: value, format: .number.precision(.fractionLength(0)))
            case .string("percent"):
                TextField(placeholder, value: value, format: .percent)
            case let .object(options):
                TextField(placeholder, value: value, format: .currency(code: options["currency"]?.string ?? "USD"))
            default:
                TextField(placeholder, value: value, format: .number)
            }
        }
        .modifier(FieldStyle(variant: attributes["variant"]?.string))
        .modifier(TextInputTraits(attributes: attributes, keyboard: "numbersAndPunctuation"))
        .onSubmit { runtime.dispatch(node.id, "submit") }
        .modifier(Focusable(node: node))
    }
}

private struct FieldStyle: ViewModifier {
    let variant: String?

    func body(content: Content) -> some View {
        switch variant {
        case "plain": content.textFieldStyle(.plain)
        case "roundedBorder": content.textFieldStyle(.roundedBorder)
        default: content
        }
    }
}

private struct TextInputTraits: ViewModifier {
    let attributes: [String: JSONValue]
    var keyboard: String?

    func body(content: Content) -> some View {
        content
            #if os(iOS) || os(visionOS)
                .ifLet(Inputs.keyboardType(attributes["keyboard"]?.string ?? keyboard)) { $0.keyboardType($1) }
                .ifLet(Inputs.contentType(attributes["contenttype"]?.string)) { $0.textContentType($1) }
                .ifLet(Inputs.autocapitalization(attributes["autocapitalize"]?.string)) {
                    $0.textInputAutocapitalization($1)
                }
            #endif
            .ifLet(attributes["autocorrect"]) { $0.autocorrectionDisabled(!$1.isTrue) }
            .ifLet(Inputs.submitLabel(attributes["submitlabel"]?.string)) { $0.submitLabel($1) }
    }
}
