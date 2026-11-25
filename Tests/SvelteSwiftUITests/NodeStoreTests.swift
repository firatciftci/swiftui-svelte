import Foundation
import Testing

@testable import SvelteSwiftUI

struct NodeStoreTests {
    private func json(_ ops: Array<[String: Any]>) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: ops)) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    private func store(_ ops: Array<[String: Any]>) -> NodeStore {
        let store = NodeStore()
        store.apply(json(ops))
        return store
    }

    private let base: Array<[String: Any]> = [
        ["op": "create", "id": 1, "kind": "fragment"],
        ["op": "root", "id": 1],
        ["op": "create", "id": 2, "kind": "element", "name": "vstack"],
        ["op": "insert", "parent": 1, "id": 2, "before": NSNull()],
        ["op": "create", "id": 3, "kind": "text", "text": "a"],
        ["op": "create", "id": 4, "kind": "text", "text": "b"],
        ["op": "create", "id": 5, "kind": "text", "text": "c"],
        ["op": "insert", "parent": 2, "id": 3, "before": NSNull()],
        ["op": "insert", "parent": 2, "id": 4, "before": NSNull()],
        ["op": "insert", "parent": 2, "id": 5, "before": NSNull()],
    ]

    private func texts(_ store: NodeStore, _ id: Int = 2) -> Array<String> {
        store.node(id)?.children.map(\.text) ?? []
    }

    @Test func buildsATree() {
        let store = store(base)
        #expect(store.root?.id == 1)
        #expect(texts(store) == ["a", "b", "c"])
        #expect(store.nodeCount == 5)
    }

    @Test func insertsBeforeAnAnchor() {
        let store = store(
            base + [["op": "create", "id": 6, "kind": "text", "text": "x"], ["op": "insert", "parent": 2, "id": 6, "before": 4]])
        #expect(texts(store) == ["a", "x", "b", "c"])
    }

    @Test func movesAnExistingNode() {
        let store = store(base + [["op": "insert", "parent": 2, "id": 5, "before": 3]])
        #expect(texts(store) == ["c", "a", "b"])
    }

    @Test func movesANodeToAnotherParent() {
        let store = store(
            base + [
                ["op": "create", "id": 6, "kind": "element", "name": "hstack"],
                ["op": "insert", "parent": 1, "id": 6, "before": NSNull()],
                ["op": "insert", "parent": 6, "id": 4, "before": NSNull()],
            ])
        #expect(texts(store) == ["a", "c"])
        #expect(texts(store, 6) == ["b"])
    }

    @Test func removesAndReleases() {
        let store = store(base + [["op": "remove", "id": 3], ["op": "release", "id": 4]])
        #expect(texts(store) == ["c"])
        #expect(store.node(3) != nil)
        #expect(store.node(4) == nil)
        #expect(store.nodeCount == 4)
    }

    @Test func setsAndRemovesAttributes() {
        let store = store(
            base + [
                ["op": "attr", "id": 2, "name": "spacing", "value": 8],
                ["op": "attr", "id": 2, "name": "label", "value": "x"],
                ["op": "unattr", "id": 2, "name": "label"],
                ["op": "attr", "id": 2, "name": "empty"],
            ])
        #expect(store.node(2)?.attributes == ["spacing": .number(8), "empty": .null])
    }

    @Test func updatesText() {
        let store = store(base + [["op": "text", "id": 3, "text": "z"]])
        #expect(texts(store) == ["z", "b", "c"])
    }

    @Test func ignoresOpsForUnknownNodes() {
        let store = store(
            base + [
                ["op": "insert", "parent": 99, "id": 3, "before": NSNull()],
                ["op": "insert", "parent": 2, "id": 98, "before": NSNull()],
                ["op": "attr", "id": 97, "name": "a", "value": 1],
                ["op": "remove", "id": 96],
                ["op": "release", "id": 95],
            ])
        #expect(texts(store) == ["a", "b", "c"])
    }

    @Test func keepsTheTreeWhenABatchIsMalformed() {
        let store = store(base)
        store.apply("not json")
        store.apply("[{\"op\":\"bogus\",\"id\":1}]")
        #expect(texts(store) == ["a", "b", "c"])
    }

    @Test func rendersOnlyMeaningfulChildren() {
        let store = store(
            base + [
                ["op": "create", "id": 6, "kind": "text", "text": "  \n"],
                ["op": "create", "id": 7, "kind": "comment", "text": ""],
                ["op": "create", "id": 8, "kind": "element", "name": "sheet"],
                ["op": "insert", "parent": 2, "id": 6, "before": NSNull()],
                ["op": "insert", "parent": 2, "id": 7, "before": NSNull()],
                ["op": "insert", "parent": 2, "id": 8, "before": NSNull()],
            ])
        let node = store.node(2)
        #expect(node?.renderedChildren.map(\.id) == [3, 4, 5])
        #expect(node?.attachment("sheet")?.id == 8)
    }
}

private struct SplitMix: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

struct NodeStoreRandomTests {
    private struct Model {
        var children: [Int: Array<Int>] = [:]
        var parent: [Int: Int] = [:]
        var live: Set<Int> = []

        mutating func detach(_ id: Int) {
            guard let parentID = parent.removeValue(forKey: id) else { return }
            children[parentID]?.removeAll { $0 == id }
        }

        func isAncestor(_ id: Int, of other: Int) -> Bool {
            var current: Int? = other
            while let node = current {
                if node == id { return true }
                current = parent[node]
            }
            return false
        }
    }

    @Test(arguments: 1...8)
    func matchesAReferenceModel(seed: UInt64) throws {
        var random = SplitMix(state: seed)
        var model = Model()
        let store = NodeStore()
        var nextID = 1
        for _ in 0..<150 {
            var ops: Array<[String: Any]> = []
            for _ in 0..<Int.random(in: 1...12, using: &random) {
                let roll = Double.random(in: 0..<1, using: &random)
                let live = model.live.sorted()
                if roll < 0.3 || live.count < 3 {
                    let id = nextID
                    nextID += 1
                    ops.append(["op": "create", "id": id, "kind": "element", "name": "e\(id)"])
                    model.live.insert(id)
                    model.children[id] = []
                } else if roll < 0.75, let node = live.randomElement(using: &random),
                    let parent = live.filter({ !model.isAncestor(node, of: $0) }).randomElement(using: &random)
                {
                    model.detach(node)
                    let siblings = model.children[parent] ?? []
                    let before = siblings.isEmpty || Bool.random(using: &random) ? nil : siblings.randomElement(using: &random)
                    ops.append(["op": "insert", "parent": parent, "id": node, "before": before.map { $0 as Any } ?? NSNull()])
                    let index = before.flatMap { siblings.firstIndex(of: $0) } ?? siblings.count
                    model.children[parent, default: []].insert(node, at: index)
                    model.parent[node] = parent
                } else if roll < 0.9, let node = live.randomElement(using: &random) {
                    ops.append(["op": "remove", "id": node])
                    model.detach(node)
                } else if let node = live.randomElement(using: &random) {
                    ops.append(["op": "release", "id": node])
                    model.detach(node)
                    for child in model.children[node] ?? [] { model.parent[child] = nil }
                    model.children[node] = nil
                    model.live.remove(node)
                }
            }
            let data = try JSONSerialization.data(withJSONObject: ops)
            store.apply(String(bytes: data, encoding: .utf8) ?? "")
            for id in model.live {
                let actual = store.node(id)?.children.map(\.id) ?? []
                let expected = model.children[id] ?? []
                if actual != expected {
                    Issue.record("seed \(seed): children of \(id) are \(actual), expected \(expected)")
                    return
                }
            }
        }
        #expect(store.nodeCount == model.live.count)
    }
}
