#if canImport(AppKit)
    import AppKit
    import Foundation
    import SwiftUI
    import Testing

    @testable import SvelteSwiftUI

    @MainActor private final class Identities {
        var seen: Array<UUID> = []
    }

    private struct Probe: View {
        let identities: Identities
        @State private var identity = UUID()

        var body: some View {
            Color.clear.frame(width: 10, height: 10).onAppear { identities.seen.append(identity) }
        }
    }

    private let samples: [String: String] = [
        "framealignment": "\"topLeading\"", "width": "100", "height": "50", "linebox": "20", "minwidth": "10", "idealwidth": "50",
        "maxwidth": "200", "minheight": "10", "idealheight": "20", "maxheight": "200", "aspectratio": "1", "contentmode": "\"fit\"",
        "padding": "8", "fixedsize": "true", "layoutpriority": "1", "boxsizing": "\"border-box\"", "border": "\"red\"",
        "margin": "8", "font": "\"title\"", "fontname": "\"Georgia\"", "fontfallbacks": "[\"Times\"]", "size": "20",
        "design": "\"serif\"", "weight": "\"bold\"", "italic": "true", "color": "\"red\"", "tint": "\"blue\"",
        "controlsize": "\"large\"", "background": "\"red\"", "opacity": "0.5", "radius": "8", "cornerstyle": "\"circular\"",
        "brightness": "0.2", "colormultiply": "\"red\"", "blendmode": "\"multiply\"", "compositinggroup": "true", "lighten": "0.2",
        "insetshadow": "true", "clipshape": "\"circle\"", "shadow": "4", "blur": "2", "contentshape": "\"circle\"",
        "ring": "{ width: 2 }", "glasseffect": "true", "glassid": "\"a\"", "glassunion": "\"u\"", "offset": "{ x: 4 }",
        "position": "{ x: 4, y: 4 }", "rotation": "10", "rotationanchor": "\"top\"", "scale": "2", "scaleanchor": "\"top\"",
        "a11ychildren": "\"combine\"", "a11yhidden": "true", "testid": "\"probe\"", "a11yheading": "1", "a11yhint": "\"Hint\"",
        "a11yinputlabels": "[\"Probe\"]", "a11ylabel": "\"Probe\"", "a11yremovetraits": "[\"button\"]", "a11ysortpriority": "1",
        "a11ytraits": "[\"header\"]", "a11yvalue": "\"Value\"", "a11yactions": "[\"Act\"]", "taskid": "1", "dragdistance": "5",
        "tapcount": "2", "longpressduration": "1", "cellanchor": "\"top\"", "colspan": "2", "columnalignment": "\"leading\"",
        "dir": "\"rtl\"", "lang": "\"tr\"", "colorscheme": "\"dark\"", "dynamictypesize": "\"large\"", "feedbacktrigger": "1",
        "preferredcolorscheme": "\"dark\"", "scrolldismisseskeyboard": "\"immediately\"", "sensoryfeedback": "\"success\"",
        "disabled": "true", "hidden": "true", "ignoressafearea": "true", "hittestable": "false", "animated": "true",
        "animation": "\"spring\"", "disablesanimations": "true", "visibilitythreshold": "0.5", "container": "true",
        "namespace": "\"ns\"", "matchedid": "\"m\"", "transition": "\"opacity\"", "in": "\"scale\"", "out": "\"slide\"",
        "zindex": "1", "deletedisabled": "true", "movedisabled": "true", "rowbackground": "\"red\"", "rowinsets": "4",
        "rowseparator": "\"hidden\"", "rowseparatortint": "\"red\"", "tag": "1",
    ]

    private let events = ModifierSet.byEvent.keys.sorted()

    private let restructuring: Set<String> = [
        "a11ychildren", "aspectratio", "cellanchor", "columnalignment", "compositinggroup", "contentmode", "contentshape",
        "hidden", "lighten", "linebox", "position", "tag", "listens a11yactivate", "listens a11yadjust", "listens a11yescape",
    ]

    private let restructuringOnce = Set(ModifierSet.byValue.keys)

    private let probeScript = """
        let names = 0;
        const named = new Map();
        const ops = [];
        const name = (text) => {
          if (!named.has(text)) { named.set(text, names++); ops.push(7, text); }
          return named.get(text);
        };
        const commit = () => __nativeCommit(JSON.stringify(ops.splice(0)));
        globalThis.change = (attribute, value) => { ops.push(4, 2, name(attribute), value); commit(); };
        globalThis.__svelteMount = (id) => {
          const declared = \(Array(samples.keys).sorted())
          ops.push(0, 1, 3, id);
          const stack = name("vstack"), probe = name("probe"), txt = name("txt");
          const attributes = declared.map((attribute) => [name(attribute), null]);
          attributes.push([name("listens"), \(events)]);
          ops.push(1, 1, 0, 2, stack, attributes.length, ...attributes.flat(), 2, 3, probe, 0, 0, 4, txt, 0, 0);
          commit();
        };
        """

    private func sceneScript(declaring: Bool) -> String {
        """
        let names = 0, ids = 2;
        const named = new Map();
        const ops = [];
        const name = (text) => {
          if (!named.has(text)) { named.set(text, names++); ops.push(7, text); }
          return named.get(text);
        };
        const declared = \(declaring ? Array(samples.keys).sorted() : []);
        const element = (tag, attributes, children = []) => {
          const record = [ids++, name(tag)];
          const pairs = Object.entries(attributes);
          for (const attribute of tag === "gridrow" ? [] : declared) if (!(attribute in attributes)) pairs.push([attribute, null]);
          record.push(pairs.length);
          for (const [key, value] of pairs) record.push(name(key), value);
          record.push(children.length);
          for (const child of children) record.push(...child);
          return record;
        };
        const text = (value) => [-(ids++), value];
        globalThis.__svelteMount = (id) => {
          ops.push(0, 1, 3, id);
          const scene = element("vstack", { font: "largeTitle", spacing: 8 }, [
            element("txt", {}, [text("Hello")]),
            element("btn", {}, [element("sfsymbol", { name: "star" })]),
            element("hstack", { weight: "bold", design: "serif" }, [element("txt", {}, [text("Bold")])]),
            element("grid", { alignment: "leading", hspacing: 16 }, [
              element("gridrow", {}, [
                element("circleshape", { fill: "teal", width: 12, height: 12 }),
                element("txt", {}, [text("Wrote the first published algorithm for a computing machine.")]),
              ]),
            ]),
          ]);
          ops.push(1, 1, 0, ...scene);
          __nativeCommit(JSON.stringify(ops.splice(0)));
        };
        """
    }

    @MainActor
    @Suite(.serialized)
    struct ViewIdentityTests {
        private func render(_ identities: Identities) async throws -> (SvelteRuntime, NSHostingView<SvelteView>) {
            let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
            try probeScript.write(to: url, atomically: true, encoding: .utf8)
            let probe = NativeComponent("probe") { _ in Probe(identities: identities) }
            let runtime = SvelteRuntime(source: url, components: [probe])
            let host = NSHostingView(rootView: SvelteView(runtime: runtime))
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 320, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderBack(nil)
            try await eventually {
                host.layoutSubtreeIfNeeded()
                return identities.seen.count == 1
            }
            return (runtime, host)
        }

        private func run(_ script: String, on runtime: SvelteRuntime, _ host: NSHostingView<SvelteView>) async {
            _ = runtime.evaluate { $0.evaluateScript(script) != nil }
            for _ in 0..<3 {
                pumpRunLoop()
                host.layoutSubtreeIfNeeded()
                await Task.yield()
            }
        }

        private func snapshot(declaring: Bool) async throws -> Data {
            let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).js")
            try sceneScript(declaring: declaring).write(to: url, atomically: true, encoding: .utf8)
            let runtime = SvelteRuntime(source: url)
            let host = NSHostingView(rootView: SvelteView(runtime: runtime))
            host.sizingOptions = []
            host.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 320, height: 480), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderBack(nil)
            try await eventually { runtime.store.node(2) != nil }
            let root = try #require(runtime.store.node(1))
            let renderer = ImageRenderer(
                content: NodeView(node: root).environment(runtime).frame(width: 320, height: 480).background(Color.white))
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            window.close()
            return try #require(image.dataProvider?.data as Data?)
        }

        @Test func rendersTheSameWhenEveryAttributeIsDeclared() async throws {
            let plain = try await snapshot(declaring: false)
            let declared = try await snapshot(declaring: true)
            #expect(Set(plain).count > 1)
            #expect(plain.count == declared.count)
            var differing = 0
            for pixel in stride(from: 0, to: min(plain.count, declared.count), by: 4)
            where (0..<4).contains(where: { abs(Int(plain[pixel + $0]) - Int(declared[pixel + $0])) > 8 }) {
                differing += 1
            }
            #expect(differing < plain.count / 4 / 1000, "\(differing) pixels differ")
        }

        @Test func coversEveryModifierAttribute() {
            #expect(Set(samples.keys) == Set(ModifierSet.byAttribute.keys))
        }

        @Test func keepsChildStateWhileItsParentsAttributesChange() async throws {
            let identities = Identities()
            let (runtime, host) = try await render(identities)
            func recreations() async -> Set<String> {
                var recreated: Set<String> = []
                for (attribute, value) in samples.sorted(by: { $0.key < $1.key }) {
                    let before = identities.seen.count
                    await run("change(\"\(attribute)\", \(value))", on: runtime, host)
                    await run("change(\"\(attribute)\", null)", on: runtime, host)
                    if identities.seen.count != before { recreated.insert(attribute) }
                }
                for event in events {
                    let before = identities.seen.count
                    await run("change(\"listens\", \(events.filter { $0 != event }))", on: runtime, host)
                    await run("change(\"listens\", \(events))", on: runtime, host)
                    if identities.seen.count != before { recreated.insert("listens \(event)") }
                }
                return recreated
            }
            let first = await recreations()
            #expect(first.isSubset(of: restructuring.union(restructuringOnce)), "Recreated the child: \(first.sorted())")
            let second = await recreations()
            #expect(second == restructuring, "Recreated the child: \(second.sorted())")
        }
    }
#endif
