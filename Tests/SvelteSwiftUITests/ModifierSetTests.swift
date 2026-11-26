import Foundation
import Testing

@testable import SvelteSwiftUI

struct ModifierSetTests {
    private static let groups: [String: ModifierSet] = [
        "Framing": .framing, "Typography": .typography, "Appearance": .appearance, "Decorations": .decorations,
        "GlassSurface": .glass, "Transforms": .transforms, "Layers": .layers, "Accessible": .accessible,
        "AccessibleDescription": .accessible, "AccessibleActions": .accessible, "Lifecycle": .lifecycle,
        "GestureHandlers": .gestures, "Taps": .gestures, "Drags": .gestures, "Pinches": .gestures, "GridCell": .gridCell,
        "Resizing": .resizing, "Localized": .localized, "Preferences": .preferences, "Availability": .availability,
        "AnimatedChildren": .animated, "Attachments": .attachments, "RowTraits": .rowTraits, "RowOptions": .rowTraits,
        "SafeAreaInsets": .safeArea,
    ]
    nonisolated private static let modifiers = [
        "Framing", "Typography", "Appearance", "Decorations", "GlassSurface", "Transforms", "Layers", "Accessible",
        "AccessibleDescription", "AccessibleActions", "Lifecycle", "GestureHandlers", "Taps", "Drags", "Pinches", "GridCell",
        "Resizing", "Localized", "Preferences", "Availability", "AnimatedChildren", "Attachments", "RowTraits", "RowOptions",
        "SafeAreaInsets",
    ]

    private static func source() throws -> String {
        let sources = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../Sources/SvelteSwiftUI")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
        return try files.filter { $0.pathExtension == "swift" }.map { try String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    private static func body(of name: String, in source: String) -> String? {
        guard let start = source.range(of: "struct \(name): ViewModifier {") else { return nil }
        var depth = 0
        for index in source[start.lowerBound...].indices {
            switch source[index] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return String(source[start.lowerBound...index]) }
            default: break
            }
        }
        return nil
    }

    private static func keys(_ pattern: String, in body: String) throws -> Set<String> {
        let regex = try Regex(pattern)
        return Set(body.matches(of: regex).compactMap { $0.output[1].substring.map(String.init) })
    }

    private static func attributes(in body: String) throws -> Set<String> {
        let regex = try Regex(#"(?:([\w?]+)\.)?attributes\["(\w+)"\]"#)
        return Set(
            body.matches(of: regex).compactMap { match in
                let receiver = match.output[1].substring
                return receiver == nil || receiver == "node" ? match.output[2].substring.map(String.init) : nil
            })
    }

    @Test(arguments: modifiers)
    func mapsEveryKeyAModifierReads(name: String) throws {
        let group = try #require(Self.groups[name])
        let body = try #require(Self.body(of: name, in: try Self.source()))
        for key in try Self.attributes(in: body) {
            #expect(ModifierSet.byAttribute[key]?.contains(group) == true, "\(name) reads \(key)")
        }
        for event in try Self.keys(#"listens\(to: "(\w+)"\)"#, in: body) {
            #expect(ModifierSet.byEvent[event]?.contains(group) == true, "\(name) listens to \(event)")
        }
        for attachment in try Self.keys(#"attachment\("(\w+)"\)"#, in: body) {
            #expect(ModifierSet.byAttachment[attachment]?.contains(group) == true, "\(name) reads the \(attachment) attachment")
        }
    }

    @Test func coversEveryGatedModifier() {
        #expect(Set(Self.modifiers) == Set(Self.groups.keys))
    }

    @Test func mapsTheKeysThatHelpersRead() {
        for key in ["font", "size", "design"] { #expect(ModifierSet.byAttribute[key]?.contains(.typography) == true) }
        for key in ["transition", "in", "out"] { #expect(ModifierSet.byAttribute[key]?.contains(.rowTraits) == true) }
    }

    @Test func leavesPlainNodesWithoutModifiers() {
        let node = Node(id: 1, kind: .element, name: "vstack", text: "")
        node.attributes = ["spacing": .number(4), "alignment": .string("leading")]
        node.children = [Node(id: 2, kind: .text, name: "", text: "a"), Node(id: 3, kind: .element, name: "txt", text: "")]
        #expect(node.modifiers.isEmpty)
    }

    @Test func enablesGroupsFromAttributesListenersAndAttachments() {
        let node = Node(id: 1, kind: .element, name: "vstack", text: "")
        node.attributes = ["padding": .null, "listens": .array([.string("tap"), .string("scroll")])]
        #expect(node.modifiers == [.framing, .gestures])
        node.children = [Node(id: 2, kind: .element, name: "overlay", text: ""), Node(id: 3, kind: .element, name: "maskview", text: "")]
        #expect(node.modifiers == [.framing, .gestures, .layers, .decorations])
        node.isMeasured = true
        #expect(node.modifiers.contains(.measured))
    }

    @Test func keepsGroupsOnAfterTheirAttributesGo() {
        let node = Node(id: 1, kind: .element, name: "txt", text: "")
        node.attributes = ["color": .string("red")]
        node.attributes = [:]
        node.children = []
        #expect(node.modifiers == .typography)
    }
}
