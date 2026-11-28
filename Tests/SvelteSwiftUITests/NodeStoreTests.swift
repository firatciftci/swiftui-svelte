import Foundation
import Observation
import Synchronization
import Testing

@testable import SvelteSwiftUI

private func batch(_ tokens: Array<Any>) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: tokens)) ?? Data()
    return String(bytes: data, encoding: .utf8) ?? ""
}

struct NodeStoreTests {
    private func store(_ tokens: Array<Any>) -> NodeStore {
        let store = NodeStore()
        store.apply(batch(base))
        store.apply(batch(tokens))
        return store
    }

    private let base: Array<Any> = [
        0, 1, NodeStore.protocolVersion, 0,
        7, "vstack", 7, "spacing", 7, "label", 7, "sheet", 7, "hstack",
        1, 1, 0, 2, 0, 0, 3, -3, "a", -4, "b", -5, "c",
    ]

    private func texts(_ store: NodeStore, _ id: Int = 2) -> Array<String> {
        store.node(id)?.children.map(\.text) ?? []
    }

    @Test func buildsATree() {
        let store = store([])
        #expect(store.root?.id == 1)
        #expect(store.root?.kind == .fragment)
        #expect(store.node(2)?.name == "vstack")
        #expect(store.node(3)?.kind == .text)
        #expect(texts(store) == ["a", "b", "c"])
        #expect(store.nodeCount == 5)
        #expect(store.error == nil)
    }

    @Test(arguments: [2, 4])
    func refusesAnIncompatibleBundle(version: Int) {
        let store = NodeStore()
        store.apply(batch([0, 1, version, 7, "vstack", 1, 1, 0, 2, 0, 0, 0]))
        #expect(store.root == nil)
        #expect(!store.isCompatible)
        #expect(store.bundleProtocolVersion == version)
        #expect(store.error == nil)
        #expect(store.node(2) == nil)
    }

    @Test func acceptsTheCurrentProtocol() {
        let store = store([])
        #expect(store.isCompatible)
        #expect(store.bundleProtocolVersion == NodeStore.protocolVersion)
    }

    @Test func insertsBeforeAnAnchor() {
        #expect(texts(store([1, 2, 4, -6, "x"])) == ["a", "x", "b", "c"])
    }

    @Test func appendsWhenTheAnchorBelongsToAnotherParent() {
        let store = store([1, 1, 0, 6, 4, 0, 0, 2, 6, 3, 5])
        #expect(texts(store) == ["a", "b"])
        #expect(texts(store, 6) == ["c"])
    }

    @Test func movesAnExistingNode() {
        #expect(texts(store([2, 2, 3, 5])) == ["c", "a", "b"])
    }

    @Test func movesANodeToAnotherParent() throws {
        let store = store([1, 1, 0, 6, 4, 0, 0])
        let moved = try #require(store.node(4))
        store.apply(batch([2, 6, 0, 4]))
        #expect(texts(store) == ["a", "c"])
        #expect(texts(store, 6) == ["b"])
        #expect(store.root?.children.map(\.id) == [2, 6])
        #expect(store.node(4) === moved)
        #expect(store.node(6)?.children.first === moved)
    }

    @Test func insertsANestedSubtree() {
        let store = store([1, 1, 2, 6, 4, 2, 1, 8, 2, "x", 2, 7, 0, 0, 1, -8, "deep", -9, "tail"])
        let node = store.node(6)
        #expect(store.root?.children.map(\.id) == [6, 2])
        #expect(node?.attributes == ["spacing": .number(8), "label": .string("x")])
        #expect(node?.children.map(\.id) == [7, 9])
        #expect(texts(store, 7) == ["deep"])
        #expect(store.nodeCount == 9)
        let moved = self.store([1, 1, 0, 6, 4, 0, 2, -7, "x", -8, "y", 2, 6, 7, 3])
        #expect(texts(moved, 6) == ["a", "x", "y"])
        #expect(texts(moved) == ["b", "c"])
    }

    @Test func removesASubtree() {
        let store = store([3, 2])
        #expect(store.root?.children.isEmpty == true)
        #expect(store.node(2) == nil)
        #expect(store.node(3) == nil)
        #expect(store.nodeCount == 1)
    }

    @Test func forgetsEveryNodeOfALargeRemovedSubtree() {
        var tokens: Array<Any> = [1, 1, 0, 100, 4, 0, 10_000]
        for index in 0..<10_000 { tokens += [101 + index * 2, 0, 0, 1, -(102 + index * 2), "row \(index)"] }
        let store = store(tokens)
        #expect(store.nodeCount == 20_006)
        store.apply(batch([3, 100]))
        #expect(store.nodeCount == 5)
        #expect(store.node(20_100) == nil)
    }

    @Test func setsAndRemovesAttributes() {
        let store = store([4, 2, 1, 8, 4, 2, 2, "x", 5, 2, 2, 4, 2, 3, NSNull(), 4, 2, 4, ["a": [1, true]]])
        #expect(
            store.node(2)?.attributes == [
                "spacing": .number(8), "hstack": .object(["a": .array([.number(1), .bool(true)])]),
            ])
    }

    @Test func leavesUnchangedValuesAlone() {
        let store = store([4, 2, 1, 8])
        let flag = Flag()
        withObservationTracking {
            _ = store.node(2)?.attributes
            _ = store.node(3)?.text
        } onChange: {
            flag.isSet = true
        }
        store.apply(batch([4, 2, 1, 8, 6, 3, "a", 5, 2, 2]))
        #expect(!flag.isSet)
        store.apply(batch([4, 2, 1, 9]))
        #expect(flag.isSet)
    }

    @Test func updatesText() {
        #expect(texts(store([6, 3, "z"])) == ["z", "b", "c"])
    }

    @Test func invalidatesTheParentOnlyWhenAChildTextTurnsBlank() {
        let store = store([])
        let flag = Flag()
        withObservationTracking {
            _ = store.node(2)?.renderedChildren
        } onChange: {
            flag.isSet = true
        }
        store.apply(batch([6, 3, "z", 6, 4, "b!"]))
        #expect(!flag.isSet)
        store.apply(batch([6, 5, " "]))
        #expect(flag.isSet)
        #expect(store.node(2)?.renderedChildren.map(\.text) == ["z", "b!"])
    }

    @Test func decodesEscapedText() {
        let store = store([])
        store.apply(#"[6,3,"line\nbreak \"q\" \\ \u00e9 \ud83d\ude00 \/ \t", 6,4,"\ud83d", 6,5,"plain ✨"]"#)
        #expect(texts(store) == ["line\nbreak \"q\" \\ é 😀 / \t", "\u{FFFD}", "plain ✨"])
        #expect(store.error == nil)
    }

    @Test func ignoresOpsForUnknownNodes() {
        let store = store([2, 2, 0, 98, 4, 97, 1, 1, 5, 97, 1, 3, 96, 6, 95, "t", 6, 2, "t"])
        #expect(texts(store) == ["a", "b", "c"])
        #expect(store.node(2)?.text.isEmpty == true)
        #expect(store.nodeCount == 5)
        #expect(store.error == nil)
    }

    @Test(arguments: [
        #"[6,3,"z",1,99,0,-9,"x"]"#,
        #"[6,3,"z",2,99,0,3]"#,
        #"[6,3,"z",1,2,0,-4,"again"]"#,
        #"[6,3,"z",1,2,0,9,0,0,2,-10,"x",-10,"y"]"#,
        #"[6,3,"z",2,2,0,1]"#,
        #"[6,3,"z",3,2,1,2,0,-9,"x"]"#,
        #"[6,3,"z",1,2,0,0,0,0,0]"#,
    ])
    func rejectsAStructurallyMalformedBatch(json: String) {
        let store = store([])
        store.apply(json)
        #expect(store.error != nil)
        #expect(texts(store) == ["a", "b", "c"])
        #expect(store.nodeCount == 5)
    }

    @Test func reinsertsANodeItRemovedInTheSameBatch() {
        let store = store([3, 2, 1, 1, 0, 2, 0, 0, 1, -3, "a"])
        #expect(store.error == nil)
        #expect(texts(store) == ["a"])
        #expect(store.node(4) == nil)
        #expect(store.nodeCount == 3)
    }

    @Test func treatsANullAttributeInARecordAsAbsent() {
        let store = store([1, 1, 0, 9, 0, 1, 1, NSNull(), 0])
        #expect(store.error == nil)
        #expect(store.node(9)?.attributes.isEmpty == true)
    }

    @Test(arguments: ["not json", "[99]", "[1,2", "[7]", "[4,2,50,1]", "[6,3,\"open]", "[6,3,\"\\x\"]", "[4,2,1,tru]", "[] x"])
    func reportsAMalformedBatch(json: String) {
        let store = store([])
        store.apply(json)
        #expect(store.error != nil)
        #expect(texts(store) == ["a", "b", "c"])
    }

    @Test func rejectsAMalformedBatchAsAWhole() {
        let store = store([])
        store.apply("[6,3,\"z\",1,2,0,-9,\"x\",7,\"new\",99]")
        #expect(texts(store) == ["a", "b", "c"])
        #expect(store.node(9) == nil)
        #expect(store.error?.contains("99") == true)
        store.apply(batch([7, "next", 4, 2, 5, 1]))
        #expect(store.error == nil)
        #expect(store.node(2)?.attributes["next"] == .number(1))
    }

    @Test func toleratesWhitespace() {
        let store = store([])
        store.apply(" [ 6 , 3 , \"z\" , 4 , 2 , 1 , { \"a\" : [ 1 , 2 ] } ] ")
        #expect(texts(store) == ["z", "b", "c"])
        #expect(store.node(2)?.attributes["spacing"] == .object(["a": .array([.number(1), .number(2)])]))
    }

    @Test func rendersOnlyMeaningfulChildren() {
        let store = store([1, 2, 0, -6, "  \n", 1, 2, 0, 7, 3, 0, 0])
        let node = store.node(2)
        #expect(node?.renderedChildren.map(\.id) == [3, 4, 5])
        #expect(node?.attachment("sheet")?.id == 7)
    }
}

nonisolated private final class Flag: @unchecked Sendable {
    var isSet = false
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
        var children: [Int: Array<Int>] = [1: []]
        var parent: [Int: Int] = [:]

        var live: Array<Int> { children.keys.sorted() }

        mutating func detach(_ id: Int) {
            guard let parentID = parent.removeValue(forKey: id) else { return }
            children[parentID]?.removeAll { $0 == id }
        }

        mutating func attach(_ id: Int, to parentID: Int, before: Int) {
            let siblings = children[parentID] ?? []
            children[parentID, default: []].insert(id, at: siblings.firstIndex(of: before) ?? siblings.count)
            parent[id] = parentID
        }

        mutating func forget(_ id: Int) {
            for child in children[id] ?? [] { forget(child) }
            children[id] = nil
            parent[id] = nil
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
    func matchesAReferenceModel(seed: UInt64) {
        var random = SplitMix(state: seed)
        var model = Model()
        let store = NodeStore()
        store.apply(batch([0, 1, NodeStore.protocolVersion, 0, 7, "e"]))
        var nextID = 2
        for _ in 0..<150 {
            var tokens: Array<Any> = []
            for _ in 0..<Int.random(in: 1...12, using: &random) {
                let roll = Double.random(in: 0..<1, using: &random)
                let live = model.live
                let movable = live.filter { $0 != 1 }
                if roll < 0.4 || movable.count < 3, let parent = live.randomElement(using: &random) {
                    let before = model.children[parent]?.randomElement(using: &random) ?? 0
                    let id = nextID
                    let childCount = Int.random(in: 0...2, using: &random)
                    tokens += [1, parent, before, id, 0, 0, childCount]
                    model.attach(id, to: parent, before: before)
                    model.children[id] = []
                    for offset in 1...max(1, childCount) where childCount > 0 {
                        tokens += [id + offset, 0, 0, 0]
                        model.children[id + offset] = []
                        model.attach(id + offset, to: id, before: 0)
                    }
                    nextID += 1 + childCount
                } else if roll < 0.8, let node = movable.randomElement(using: &random),
                    let parent = live.filter({ !model.isAncestor(node, of: $0) }).randomElement(using: &random)
                {
                    model.detach(node)
                    let before = model.children[parent]?.randomElement(using: &random) ?? 0
                    tokens += [2, parent, before, node]
                    model.attach(node, to: parent, before: before)
                } else if let node = movable.randomElement(using: &random) {
                    tokens += [3, node]
                    model.detach(node)
                    model.forget(node)
                }
            }
            store.apply(batch(tokens))
            for id in model.live {
                let actual = store.node(id)?.children.map(\.id) ?? []
                let expected = model.children[id] ?? []
                if actual != expected {
                    Issue.record("seed \(seed): children of \(id) are \(actual), expected \(expected)")
                    return
                }
            }
            #expect(store.nodeCount == model.live.count)
        }
        #expect(store.error == nil)
    }
}

extension NodeStoreTests {
    @Test func presentsFromTheNearestHost() {
        let store = self.store([
            7, "screen", 7, "vstack", 7, "alert",
            1, 2, 0, 10, 5, 0, 1, 11, 6, 0, 1, 12, 3, 0, 0,
            1, 2, 0, 13, 3, 0, 1, 14, 7, 0, 0,
        ])
        #expect(store.node(10)?.presented.map(\.id) == [12])
        #expect(store.node(13)?.presented.map(\.id) == [14])
        #expect(store.root?.presented.map(\.id) == [13])
        #expect(store.node(11)?.presented.isEmpty == true)
        #expect(store.node(11)?.renderedChildren.isEmpty == true)

        store.apply(batch([3, 12]))
        #expect(store.node(10)?.presented.isEmpty == true)
        store.apply(batch([2, 11, 0, 13]))
        #expect(store.node(10)?.presented.map(\.id) == [13])
        #expect(store.root?.presented.isEmpty == true)
        store.apply(batch([2, 1, 0, 13]))
        #expect(store.node(10)?.presented.isEmpty == true)
        #expect(store.root?.presented.map(\.id) == [13])
    }

    @Test func reassignsHostsOnlyWhenAPresentationCanChangeHost() {
        let store = self.store([
            7, "screen", 7, "vstack", 7, "alert",
            1, 1, 0, 10, 5, 0, 1, 11, 6, 0, 1, 12, 3, 0, 0,
        ])
        let passes = store.hostingPasses
        #expect(store.node(10)?.presented.map(\.id) == [12])

        store.apply(batch([1, 2, 0, 20, 4, 0, 1, -21, "row", 1, 11, 0, 22, 6, 0, 0]))
        store.apply(batch([4, 20, 1, 8, 6, 21, "changed", 3, 20, 3, 22]))
        #expect(store.hostingPasses == passes)

        store.apply(batch([1, 11, 0, 30, 7, 0, 0]))
        #expect(store.hostingPasses == passes + 1)
        #expect(store.node(10)?.presented.map(\.id) == [12, 30])

        store.apply(batch([2, 2, 0, 3]))
        #expect(store.hostingPasses == passes + 2)

        store.apply(batch([3, 30]))
        #expect(store.hostingPasses == passes + 3)
        #expect(store.node(10)?.presented.map(\.id) == [12])

        store.apply(batch([3, 11]))
        #expect(store.hostingPasses == passes + 4)
        #expect(store.node(10)?.presented.isEmpty == true)

        #expect(store.apply(batch([1, 2, 0, 40, 4, 0, 0, 2, 2, 0, 3, 3, 40])))
        #expect(store.hostingPasses == passes + 4)
        #expect(texts(store) == ["b", "c", "a"])
        #expect(store.error == nil)
    }

    @Test func rejectsAnInsertIntoAnUnknownParent() {
        let store = self.store([7, "screen", 1, 999, 0, 20, 3, 0, 0])
        #expect(store.node(20) == nil)
        #expect(store.root?.presented.isEmpty == true)
        #expect(store.error?.contains("999") == true)
    }

    @Test func keepsOwnedAttributesThroughJavaScriptEdits() {
        let store = NodeStore()
        store.reset(ownedNames: ["vstack": ["spacing"]])
        store.apply(batch(base))
        store.apply(batch([4, 2, 1, 8, 4, 2, 2, "x", 5, 2, 2, 4, 2, 2, NSNull()]))
        #expect(store.node(2)?.nativeAttributes["spacing"] == .number(8))
        #expect(store.node(2)?.attributes["label"] == nil)
        store.apply(batch([5, 2, 1]))
        #expect(store.node(2)?.nativeAttributes["spacing"] == nil)
    }

    @Test func leavesButtonFeedbackOutOfJavaScriptAttributes() {
        let store = self.store([])
        let node = store.node(2)
        node?.feedback.label = ["background": .string("blue")]
        store.apply(batch([4, 2, 2, "x"]))
        #expect(node?.ownAttributes["background"] == nil)
        #expect(node?.nativeAttributes["background"] == .string("blue"))
    }

    @Test func keepsFeedbackAndOwnedAttributesOutOfAnEditedValue() {
        let node = Node(id: 1, kind: .element, name: "probe", text: "")
        node.owned = ["color"]
        node.setOwnAttributes(["color": .string("red"), "value": .string("a")])
        node.feedback.state = ["opacity": .number(0.5)]
        node.setOwnAttribute("value", .string("b"))
        #expect(node.ownAttributes == ["color": .string("red"), "value": .string("b")])
        #expect(node.attributes == ["opacity": .number(0.5), "value": .string("b")])
    }

    @Test func updatesTheMergedAttributesWhenAnySourceChanges() {
        let node = Node(id: 1, kind: .element, name: "probe", text: "")
        node.owned = ["color"]
        node.setOwnAttributes(["color": .string("red"), "padding": .number(4)])
        node.feedback.label = ["opacity": .number(0.5)]
        #expect(node.attributes == ["padding": .number(4), "opacity": .number(0.5)])
        node.setOwnAttribute("padding", .number(8))
        #expect(node.attributes == ["padding": .number(8), "opacity": .number(0.5)])
        node.feedback.state = ["opacity": .number(1)]
        #expect(node.nativeAttributes == ["color": .string("red"), "padding": .number(8), "opacity": .number(1)])
        node.owned = []
        #expect(node.attributes["color"] == .string("red"))
        node.feedback = Node.Feedback()
        #expect(node.attributes == ["color": .string("red"), "padding": .number(8)])
    }

    @Test(arguments: [false, true])
    func notifiesReadersOfCachedAttributesWhenAnOwnAttributeChanges(isCached: Bool) {
        let node = Node(id: 1, kind: .element, name: "probe", text: "")
        node.owned = ["color"]
        node.setOwnAttributes(["padding": .number(4)])
        node.feedback.label = ["opacity": .number(0.5)]
        if isCached { _ = node.attributes }
        let changes = Mutex(0)
        withObservationTracking {
            _ = node.attributes
        } onChange: {
            changes.withLock { $0 += 1 }
        }
        node.setOwnAttribute("padding", .number(8))
        #expect(changes.withLock { $0 } == 1)
    }

    @Test func ignoresAMoveBeforeItself() {
        #expect(texts(store([2, 2, 3, 3])) == ["a", "b", "c"])
    }
}
