import "./host.ts";
import type { Component } from "svelte";
import { mount, unmount } from "svelte";
import { createRenderer } from "svelte/renderer";

type Handler = (payload: unknown) => void;
type Container = { first: ChildNode | null; last: ChildNode | null };
type Linked = {
  parent: ParentNode | null;
  prev: ChildNode | null;
  next: ChildNode | null;
};
type FragmentNode = Container & { kind: "fragment"; id: number };
type ElementNode = Container &
  Linked & {
    kind: "element";
    id: number;
    name: string;
    attributes: Map<string, unknown>;
    listeners: Map<string, Set<Handler>>;
  };
type TextNode = Linked & { kind: "text" | "comment"; id: number; data: string };
type ParentNode = FragmentNode | ElementNode;
type ChildNode = ElementNode | TextNode;

type Op =
  | { op: "root"; id: number }
  | { op: "create"; id: number; kind: "fragment" }
  | { op: "create"; id: number; kind: "element"; name: string }
  | { op: "create"; id: number; kind: "text" | "comment"; text: string }
  | { op: "insert"; parent: number; id: number; before: number | null }
  | { op: "remove"; id: number }
  | { op: "attr"; id: number; name: string; value: unknown }
  | { op: "unattr"; id: number; name: string }
  | { op: "text"; id: number; text: string }
  | { op: "release"; id: number };

export const stats = {
  live: 0,
  commits: 0,
  ops: 0,
  bytes: 0,
  serializeMs: 0,
  nativeMs: 0,
  lastCommitEnd: 0,
};

const queue: Array<Op> = [];
const elements = new Map<number, WeakRef<ElementNode>>();
const finalizer = new FinalizationRegistry<number>((id) => {
  elements.delete(id);
  stats.live--;
  send({ op: "release", id });
});
const state = { nextId: 1, isScheduled: false };

function send(op: Op): void {
  queue.push(op);
  if (state.isScheduled) return;
  state.isScheduled = true;
  queueMicrotask(() => {
    state.isScheduled = false;
    const ops = queue.splice(0);
    const start = __nativeNow();
    const json = JSON.stringify(ops);
    const serialized = __nativeNow();
    __nativeCommit(json);
    stats.lastCommitEnd = __nativeNow();
    stats.commits++;
    stats.ops += ops.length;
    stats.bytes += json.length;
    stats.serializeMs += serialized - start;
    stats.nativeMs += stats.lastCommitEnd - serialized;
  });
}

function track<T extends FragmentNode | ChildNode>(node: T, op: Op): T {
  finalizer.register(node, node.id);
  stats.live++;
  send(op);
  return node;
}

function detach(node: ChildNode): void {
  const { parent, prev, next } = node;
  if (parent == null) return;
  if (prev == null) parent.first = next;
  else prev.next = next;
  if (next == null) parent.last = prev;
  else next.prev = prev;
  node.parent = node.prev = node.next = null;
}

function insertChild(
  parent: ParentNode,
  node: ChildNode,
  anchor: ChildNode | null,
): void {
  detach(node);
  const prev = anchor == null ? parent.last : anchor.prev;
  node.parent = parent;
  node.prev = prev;
  node.next = anchor;
  if (prev == null) parent.first = node;
  else prev.next = node;
  if (anchor == null) parent.last = node;
  else anchor.prev = node;
  send({
    op: "insert",
    parent: parent.id,
    id: node.id,
    before: anchor?.id ?? null,
  });
}

const renderer = createRenderer<{
  fragment: FragmentNode;
  element: ElementNode;
  text: TextNode;
  comment: TextNode;
}>({
  createFragment() {
    const node: FragmentNode = {
      kind: "fragment",
      id: state.nextId++,
      first: null,
      last: null,
    };
    return track(node, { op: "create", id: node.id, kind: "fragment" });
  },
  createElement(name) {
    const node: ElementNode = {
      kind: "element",
      id: state.nextId++,
      name,
      parent: null,
      prev: null,
      next: null,
      first: null,
      last: null,
      attributes: new Map(),
      listeners: new Map(),
    };
    elements.set(node.id, new WeakRef(node));
    return track(node, { op: "create", id: node.id, kind: "element", name });
  },
  createText(data) {
    const node: TextNode = {
      kind: "text",
      id: state.nextId++,
      data,
      parent: null,
      prev: null,
      next: null,
    };
    return track(node, { op: "create", id: node.id, kind: "text", text: data });
  },
  createComment(data) {
    const node: TextNode = {
      kind: "comment",
      id: state.nextId++,
      data,
      parent: null,
      prev: null,
      next: null,
    };
    return track(node, {
      op: "create",
      id: node.id,
      kind: "comment",
      text: data,
    });
  },

  getNodeType(node) {
    return node.kind;
  },
  getText(node) {
    return node.data;
  },
  setText(node, text) {
    node.data = text;
    send({ op: "text", id: node.id, text });
  },

  getAttribute(element, name) {
    const value = element.attributes.get(name);
    return value == null ? null : String(value);
  },
  setAttribute(element, name, value: unknown) {
    element.attributes.set(name, value);
    if (typeof value !== "function") {
      send({ op: "attr", id: element.id, name, value });
    }
  },
  removeAttribute(element, name) {
    element.attributes.delete(name);
    send({ op: "unattr", id: element.id, name });
  },
  hasAttribute(element, name) {
    return element.attributes.has(name);
  },

  getFirstChild(node) {
    return node.first;
  },
  getLastChild(node) {
    return node.last;
  },
  getNextSibling(node) {
    return node.next;
  },
  getParent(node) {
    return node.parent;
  },

  insert(parent, node, anchor) {
    if (node.kind !== "fragment") {
      insertChild(parent, node, anchor);
      return;
    }
    let child = node.first;
    while (child != null) {
      const next = child.next;
      insertChild(parent, child, anchor);
      child = next;
    }
  },
  remove(node) {
    detach(node);
    send({ op: "remove", id: node.id });
  },

  addEventListener(element, type, handler: Handler) {
    let handlers = element.listeners.get(type);
    if (handlers == null) {
      handlers = new Set();
      element.listeners.set(type, handlers);
    }
    handlers.add(handler);
  },
  removeEventListener(element, type, handler: Handler) {
    element.listeners.get(type)?.delete(handler);
  },
});

globalThis.__svelteDispatch = (id, type, payload) => {
  const element = elements.get(id)?.deref();
  const handlers = element?.listeners.get(type) ?? [];
  for (const handler of handlers) handler(payload);
};

export function mountApp(component: Component): () => void {
  const target = renderer.createFragment();
  send({ op: "root", id: target.id });
  const instance = mount(component, { target, renderer });
  return () => void unmount(instance);
}

export default renderer;
