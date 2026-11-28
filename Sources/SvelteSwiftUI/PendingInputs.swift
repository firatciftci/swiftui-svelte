struct PendingInputs {
    private var queue: Array<(id: Int, text: String)> = []
    private var sent: [Int: String] = [:]

    mutating func hold(_ text: String, for id: Int) {
        if let index = queue.firstIndex(where: { $0.id == id }) {
            queue[index].text = text
        } else {
            queue.append((id, text))
        }
    }

    func contains(_ id: Int) -> Bool {
        queue.contains { $0.id == id }
    }

    mutating func discard(_ id: Int) {
        queue.removeAll { $0.id == id }
    }

    mutating func forget(_ id: Int) {
        discard(id)
        sent[id] = nil
    }

    func isStaleEcho(_ value: String, of id: Int) -> Bool {
        contains(id) && sent[id] == value
    }

    mutating func next() -> (id: Int, text: String)? {
        guard !queue.isEmpty else { return nil }
        let input = queue.removeFirst()
        sent[input.id] = input.text
        return input
    }
}

extension SvelteRuntime {
    func deferInput(_ id: Int, _ text: String) {
        inputs.hold(text, for: id)
    }

    func sendInput(_ id: Int, _ text: String) {
        inputs.hold(text, for: id)
        flushInputs(waits: true)
    }

    func flushInput(_ id: Int) {
        if inputs.contains(id) { flushInputs(waits: true) }
    }

    func flushInputs(waits: Bool) {
        while let (id, text) = inputs.next() {
            call("__svelteDispatch", [JSONValue(id), "input", .string(text)], waits: waits)
        }
    }
}
