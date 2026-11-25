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
  sent: boolean;
};
type FragmentNode = Container & { kind: "fragment"; id: number; sent: boolean };
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

export const protocol = 2;

export const opcodes = {
  root: 0,
  insert: 1,
  move: 2,
  remove: 3,
  attr: 4,
  unattr: 5,
  text: 6,
  name: 7,
} as const;

export const stats = {
  live: 0,
  commits: 0,
  ops: 0,
  bytes: 0,
  serializeMs: 0,
  nativeMs: 0,
  lastCommitEnd: 0,
};

const batch: Array<unknown> = [];
const names = new Map<string, number>();
const elements = new Map<number, WeakRef<ElementNode>>();
const finalizer = new FinalizationRegistry<number>((id) => {
  elements.delete(id);
  stats.live--;
});
const state = { nextId: 1, isScheduled: false };

function commit(): void {
  state.isScheduled = false;
  const start = __nativeNow();
  const json = JSON.stringify(batch);
  batch.length = 0;
  const serialized = __nativeNow();
  __nativeCommit(json);
  stats.lastCommitEnd = __nativeNow();
  stats.commits++;
  stats.bytes += json.length;
  stats.serializeMs += serialized - start;
  stats.nativeMs += stats.lastCommitEnd - serialized;
}

function send(...tokens: Array<unknown>): void {
  for (const token of tokens) batch.push(token);
  stats.ops++;
  if (state.isScheduled) return;
  state.isScheduled = true;
  queueMicrotask(commit);
}

function nameRef(name: string): number {
  let ref = names.get(name);
  if (ref == null) {
    ref = names.size;
    names.set(name, ref);
    send(opcodes.name, name);
  }
  return ref;
}

function isMaterial(node: ChildNode): boolean {
  if (node.kind === "element") return true;
  return node.kind === "text" && node.data.trim() !== "";
}

function anchorId(node: ChildNode): number {
  let next = node.next;
  while (next != null && !next.sent) next = next.next;
  return next?.id ?? 0;
}

function encode(node: ChildNode, record: Array<unknown>): void {
  node.sent = true;
  if (node.kind !== "element") {
    record.push(-node.id, node.data);
    return;
  }
  record.push(node.id, nameRef(node.name));
  const attributes = [...node.attributes].filter(
    ([, value]) => typeof value !== "function",
  );
  record.push(attributes.length);
  for (const [name, value] of attributes) record.push(nameRef(name), value);
  const children: Array<ChildNode> = [];
  for (let child = node.first; child != null; child = child.next) {
    if (isMaterial(child)) children.push(child);
  }
  record.push(children.length);
  for (const child of children) encode(child, record);
}

function materialize(parent: ParentNode, node: ChildNode): void {
  const record: Array<unknown> = [];
  encode(node, record);
  send(opcodes.insert, parent.id, anchorId(node));
  for (const token of record) batch.push(token);
}

function unmark(node: ChildNode): void {
  node.sent = false;
  if (node.kind !== "element") return;
  for (let child = node.first; child != null; child = child.next) {
    if (child.sent) unmark(child);
  }
}

function track<T extends FragmentNode | ChildNode>(node: T): T {
  finalizer.register(node, node.id);
  stats.live++;
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
  const wasSent = node.sent;
  detach(node);
  const prev = anchor == null ? parent.last : anchor.prev;
  node.parent = parent;
  node.prev = prev;
  node.next = anchor;
  if (prev == null) parent.first = node;
  else prev.next = node;
  if (anchor == null) parent.last = node;
  else anchor.prev = node;
  if (parent.sent) {
    if (wasSent) send(opcodes.move, parent.id, anchorId(node), node.id);
    else if (isMaterial(node)) materialize(parent, node);
  } else if (wasSent) {
    send(opcodes.remove, node.id);
    unmark(node);
  }
}

function linked(): Linked {
  return { parent: null, prev: null, next: null, sent: false };
}

const renderer = createRenderer<{
  fragment: FragmentNode;
  element: ElementNode;
  text: TextNode;
  comment: TextNode;
}>({
  createFragment() {
    return track({
      kind: "fragment",
      id: state.nextId++,
      first: null,
      last: null,
      sent: false,
    });
  },
  createElement(name) {
    const node: ElementNode = {
      ...linked(),
      kind: "element",
      id: state.nextId++,
      name,
      first: null,
      last: null,
      attributes: new Map(),
      listeners: new Map(),
    };
    elements.set(node.id, new WeakRef(node));
    return track(node);
  },
  createText(data) {
    return track({ ...linked(), kind: "text", id: state.nextId++, data });
  },
  createComment(data) {
    return track({ ...linked(), kind: "comment", id: state.nextId++, data });
  },

  getNodeType(node) {
    return node.kind;
  },
  getText(node) {
    return node.data;
  },
  setText(node, text) {
    node.data = text;
    if (node.sent) send(opcodes.text, node.id, text);
    else if (node.parent?.sent === true && isMaterial(node)) {
      materialize(node.parent, node);
    }
  },

  getAttribute(element, name) {
    const value = element.attributes.get(name);
    return value == null ? null : String(value);
  },
  setAttribute(element, name, value: unknown) {
    const previous = element.attributes.get(name);
    element.attributes.set(name, value);
    if (!element.sent) return;
    if (typeof value !== "function") {
      const ref = nameRef(name);
      send(opcodes.attr, element.id, ref, value);
    } else if (previous !== undefined && typeof previous !== "function") {
      send(opcodes.unattr, element.id, nameRef(name));
    }
  },
  removeAttribute(element, name) {
    element.attributes.delete(name);
    if (!element.sent) return;
    send(opcodes.unattr, element.id, nameRef(name));
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
    if (!node.sent) return;
    send(opcodes.remove, node.id);
    unmark(node);
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
  target.sent = true;
  send(opcodes.root, target.id, protocol);
  const instance = mount(component, { target, renderer });
  return () => void unmount(instance);
}

export default renderer;
