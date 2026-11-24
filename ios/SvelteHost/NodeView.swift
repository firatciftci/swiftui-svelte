import SwiftUI

struct NodeView: View {
  let node: Node
  @Environment(Runtime.self) private var runtime

  var body: some View {
    switch node.kind {
    case .text:
      Text(node.text)
    case .element:
      element.modifier(NodeModifiers(node: node))
    case .fragment:
      children
    case .comment:
      EmptyView()
    }
  }

  private var children: some View {
    ForEach(node.renderedChildren) { NodeView(node: $0) }
  }

  @ViewBuilder private var element: some View {
    switch node.name {
    case "navstack":
      NavStack(node: node)
    case "screen":
      Group { children }.navigationTitle(node.attributes["title"]?.string ?? "")
    case "vstack":
      VStack(alignment: horizontalAlignment, spacing: spacing) { children }
    case "hstack":
      HStack(alignment: verticalAlignment, spacing: spacing) { children }
    case "zstack":
      ZStack { children }
    case "scrollview":
      ScrollView { children }
    case "list":
      List { children }
    case "spacer":
      Spacer()
    case "divider":
      Divider()
    case "txt":
      Text(node.children.filter { $0.kind == .text }.map(\.text).joined())
    case "sfsymbol":
      Image(systemName: node.attributes["name"]?.string ?? "questionmark")
    case "btn":
      let button = Button {
        runtime.dispatch(node.id, "click")
      } label: {
        children
      }
      switch node.attributes["variant"]?.string {
      case "bordered": button.buttonStyle(.bordered)
      case "prominent": button.buttonStyle(.borderedProminent)
      default: button.buttonStyle(.borderless)
      }
    case "textfield":
      TextField(
        node.attributes["placeholder"]?.string ?? "",
        text: Binding {
          node.attributes["value"]?.string ?? ""
        } set: { value in
          node.attributes["value"] = .string(value)
          runtime.dispatch(node.id, "input", value)
        }
      )
      .onSubmit { runtime.dispatch(node.id, "submit") }
    case "toggle":
      Toggle(
        isOn: Binding {
          switch node.attributes["checked"] {
          case let .bool(checked): checked
          case nil, .null: false
          default: true
          }
        } set: { value in
          node.attributes["checked"] = .bool(value)
          runtime.dispatch(node.id, "change", value)
        }
      ) {
        children
      }
    default:
      Text("Unknown element <\(node.name)>").foregroundStyle(.red)
    }
  }

  private var spacing: CGFloat? {
    node.attributes["spacing"]?.number.map { CGFloat($0) }
  }

  private var horizontalAlignment: HorizontalAlignment {
    switch node.attributes["alignment"]?.string {
    case "leading": .leading
    case "trailing": .trailing
    default: .center
    }
  }

  private var verticalAlignment: VerticalAlignment {
    switch node.attributes["alignment"]?.string {
    case "top": .top
    case "bottom": .bottom
    default: .center
    }
  }
}

private struct NavStack: View {
  let node: Node
  @Environment(Runtime.self) private var runtime

  var body: some View {
    NavigationStack(
      path: Binding {
        node.renderedChildren.dropFirst().map(\.id)
      } set: { path in
        if path.count < node.renderedChildren.count - 1 {
          runtime.dispatch(node.id, "pop", path.count)
        }
      }
    ) {
      Group {
        if let root = node.renderedChildren.first { NodeView(node: root) }
      }
      .navigationDestination(for: Int.self) { id in
        if let screen = runtime.store.node(id) { NodeView(node: screen) }
      }
    }
  }
}

private struct NodeModifiers: ViewModifier {
  let node: Node

  func body(content: Content) -> some View {
    let attributes = node.attributes
    content
      .padding(padding(attributes["padding"]))
      .font(font(attributes["font"]?.string))
      .fontWeight(weight(attributes["weight"]?.string))
      .ifLet(color(attributes["color"]?.string)) { $0.foregroundStyle($1) }
      .background(color(attributes["background"]?.string) ?? .clear)
      .ifLet(attributes["radius"]?.number) { $0.clipShape(.rect(cornerRadius: $1)) }
      .opacity(attributes["opacity"]?.number ?? 1)
  }

  private func padding(_ value: JSONValue?) -> CGFloat {
    switch value {
    case let .number(length): length
    case .bool(true): 16
    default: 0
    }
  }

  private func font(_ name: String?) -> Font? {
    switch name {
    case "largeTitle": .largeTitle
    case "title": .title
    case "title2": .title2
    case "title3": .title3
    case "headline": .headline
    case "subheadline": .subheadline
    case "body": .body
    case "callout": .callout
    case "footnote": .footnote
    case "caption": .caption
    case "caption2": .caption2
    default: nil
    }
  }

  private func weight(_ name: String?) -> Font.Weight? {
    switch name {
    case "regular": .regular
    case "medium": .medium
    case "semibold": .semibold
    case "bold": .bold
    case "heavy": .heavy
    default: nil
    }
  }

  private func color(_ name: String?) -> Color? {
    switch name {
    case "primary": .primary
    case "secondary": .secondary
    case "accent": .accentColor
    case "red": .red
    case "orange": .orange
    case "yellow": .yellow
    case "green": .green
    case "mint": .mint
    case "teal": .teal
    case "cyan": .cyan
    case "blue": .blue
    case "indigo": .indigo
    case "purple": .purple
    case "pink": .pink
    case "brown": .brown
    case "gray": .gray
    case "white": .white
    case "black": .black
    default: nil
    }
  }
}

extension View {
  @ViewBuilder
  fileprivate func ifLet<Value, Modified: View>(
    _ value: Value?, _ transform: (Self, Value) -> Modified
  ) -> some View {
    if let value { transform(self, value) } else { self }
  }
}
