import "./host.ts";
import type { Component } from "svelte";
import { flushSync, mount, unmount } from "svelte";
import { SvelteMap } from "svelte/reactivity";
import { createRenderer } from "svelte/renderer";
import type { AnimationOptions } from "./elements.ts";

type Handler = (payload: unknown) => void;
type Container = { first: ChildNode | null; last: ChildNode | null };
type Linked = {
  parent: ParentNode | null;
  prev: ChildNode | null;
  next: ChildNode | null;
  state: NodeState;
};
type FragmentNode = Container & {
  kind: "fragment";
  id: number;
  state: NodeState;
};
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

const State = { Local: 0, Pending: 1, Native: 2 } as const;
type NodeState = (typeof State)[keyof typeof State];

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
const pending: Array<ChildNode> = [];
const changedAttributes = new Map<ElementNode, Set<string>>();
const changedTexts = new Set<TextNode>();
const names = new Map<string, number>();
const elements = new Map<number, WeakRef<ElementNode>>();
const finalizer = new FinalizationRegistry<number>((id) => {
  elements.delete(id);
  stats.live--;
});
const scheduler = { nextId: 1, isScheduled: false };

function wire(_key: string, value: unknown): unknown {
  if (typeof value === "bigint") return Number(value);
  if (value instanceof Map) return Object.fromEntries(value);
  if (value instanceof Set) return [...value];
  return value;
}

function schedule(): void {
  if (scheduler.isScheduled) return;
  scheduler.isScheduled = true;
  queueMicrotask(commit);
}

function send(...tokens: Array<unknown>): void {
  for (const token of tokens) batch.push(token);
  stats.ops++;
  schedule();
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
  while (next != null && next.state !== State.Native) next = next.next;
  return next?.id ?? 0;
}

function encode(node: ChildNode, record: Array<unknown>): void {
  node.state = State.Native;
  if (node.kind !== "element") {
    record.push(-node.id, node.data);
    return;
  }
  record.push(node.id, nameRef(node.name));
  const attributeCount = record.length;
  record.push(0);
  for (const [name, value] of node.attributes) {
    if (typeof value === "function") continue;
    record.push(nameRef(name), value);
    (record[attributeCount] as number)++;
  }
  const childCount = record.length;
  record.push(0);
  for (let child = node.first; child != null; child = child.next) {
    if (!isMaterial(child)) continue;
    encode(child, record);
    (record[childCount] as number)++;
  }
}

function flushAttributes(): void {
  for (const [element, changed] of changedAttributes) {
    if (element.state !== State.Native) continue;
    for (const name of changed) {
      const value = element.attributes.get(name);
      const ref = nameRef(name);
      if (value === undefined || typeof value === "function") {
        send(opcodes.unattr, element.id, ref);
      } else {
        send(opcodes.attr, element.id, ref, value);
      }
    }
  }
  changedAttributes.clear();
}

function flushTexts(): void {
  for (const node of changedTexts) {
    if (node.state === State.Native) send(opcodes.text, node.id, node.data);
  }
  changedTexts.clear();
}

function flushInserts(): void {
  for (const node of pending) {
    if (node.state !== State.Pending || node.parent?.state !== State.Native) {
      continue;
    }
    if (!isMaterial(node)) {
      node.state = State.Local;
      continue;
    }
    const record: Array<unknown> = [];
    encode(node, record);
    send(opcodes.insert, node.parent.id, anchorId(node));
    for (const token of record) batch.push(token);
  }
  pending.length = 0;
}

function commit(animation?: AnimationOptions): void {
  scheduler.isScheduled = false;
  const start = __nativeNow();
  flushAttributes();
  flushTexts();
  flushInserts();
  if (batch.length === 0) return;
  const json = JSON.stringify(batch, wire);
  batch.length = 0;
  const serialized = __nativeNow();
  if (animation === undefined) __nativeCommit(json);
  else __nativeCommit(json, JSON.stringify(animation));
  stats.lastCommitEnd = __nativeNow();
  stats.commits++;
  stats.bytes += json.length;
  stats.serializeMs += serialized - start;
  stats.nativeMs += stats.lastCommitEnd - serialized;
}

export function withAnimation<T>(
  fn: () => T,
  animation: AnimationOptions = true,
): T {
  flushSync();
  commit();
  const result = flushSync(fn);
  commit(animation);
  return result;
}

function changeAttribute(element: ElementNode, name: string): void {
  if (element.state !== State.Native) return;
  let changed = changedAttributes.get(element);
  if (changed == null) {
    changed = new Set();
    changedAttributes.set(element, changed);
  }
  changed.add(name);
  schedule();
}

function materialize(node: ChildNode): void {
  node.state = State.Pending;
  pending.push(node);
  schedule();
}

function unmark(node: ChildNode): void {
  node.state = State.Local;
  if (node.kind !== "element") return;
  for (let child = node.first; child != null; child = child.next) {
    if (child.state !== State.Local) unmark(child);
  }
}

function discard(node: ChildNode): void {
  if (node.state === State.Native) send(opcodes.remove, node.id);
  unmark(node);
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

function place(parent: ParentNode, node: ChildNode): void {
  if (parent.state === State.Local) {
    if (node.state !== State.Local) discard(node);
    return;
  }
  if (node.state === State.Pending) return;
  if (node.state === State.Native) {
    if (parent.state === State.Native) {
      send(opcodes.move, parent.id, anchorId(node), node.id);
      return;
    }
    discard(node);
  }
  if (isMaterial(node)) materialize(node);
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
  place(parent, node);
}

function linked(): Linked {
  return { parent: null, prev: null, next: null, state: State.Local };
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
      id: scheduler.nextId++,
      first: null,
      last: null,
      state: State.Local,
    });
  },
  createElement(name) {
    const node: ElementNode = {
      ...linked(),
      kind: "element",
      id: scheduler.nextId++,
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
    return track({ ...linked(), kind: "text", id: scheduler.nextId++, data });
  },
  createComment(data) {
    return track({
      ...linked(),
      kind: "comment",
      id: scheduler.nextId++,
      data,
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
    if (node.state === State.Native) {
      changedTexts.add(node);
      schedule();
    } else if (node.state === State.Local && node.parent != null) {
      place(node.parent, node);
    }
  },

  getAttribute(element, name) {
    const value = element.attributes.get(name);
    return value == null ? null : String(value);
  },
  setAttribute(element, name, value: unknown) {
    element.attributes.set(name, value);
    changeAttribute(element, name);
  },
  removeAttribute(element, name) {
    element.attributes.delete(name);
    changeAttribute(element, name);
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
    discard(node);
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

const controlledAttributes = new Map([
  ["toggle", "checked"],
  ["tabview", "selection"],
]);

globalThis.__svelteDispatch = (id, type, payload) => {
  const element = elements.get(id)?.deref();
  const handlers = element?.listeners.get(type);
  if (element == null || handlers == null || handlers.size === 0) return;
  for (const handler of handlers) handler(payload);
  if (type !== "input" && type !== "change") return;
  const name = controlledAttributes.get(element.name) ?? "value";
  if (name === "checked" || element.attributes.has(name)) {
    changeAttribute(element, name);
  }
};

type Mounted = {
  instance: Record<string, unknown>;
  target: FragmentNode;
  props: SvelteMap<string, unknown>;
  actions: Set<string>;
};

const components = new Map<string, Component<never>>();
const mounted = new Map<number, Mounted>();

function reactiveProps(
  values: SvelteMap<string, unknown>,
): Record<string, unknown> {
  return new Proxy(
    {},
    {
      get: (_, key) => (typeof key === "string" ? values.get(key) : undefined),
      has: (_, key) => typeof key === "string" && values.has(key),
      ownKeys: () => {
        const keys: Array<string> = [];
        for (const key of values.keys()) keys.push(key);
        return keys;
      },
      getOwnPropertyDescriptor: (_, key) =>
        typeof key === "string" && values.has(key)
          ? { enumerable: true, configurable: true, value: values.get(key) }
          : undefined,
    },
  );
}

function update(entry: Mounted, values: Record<string, unknown>): void {
  for (const key of entry.props.keys()) {
    if (!entry.actions.has(key) && !Object.hasOwn(values, key)) {
      entry.props.delete(key);
    }
  }
  for (const [key, value] of Object.entries(values)) {
    if (!entry.actions.has(key)) entry.props.set(key, value);
  }
}

globalThis.__svelteMount = (mountId, name, json) => {
  const component = components.get(name);
  if (component == null) {
    throw new Error(`No component named "${name}". Pass it to mountApp().`);
  }
  const { props: values, actions } = JSON.parse(json) as {
    props: Record<string, unknown>;
    actions: Array<string>;
  };
  const props = new SvelteMap<string, unknown>();
  for (const action of actions) {
    props.set(action, (payload: unknown) =>
      __nativeAction(mountId, action, JSON.stringify(payload ?? null, wire)),
    );
  }
  const entry: Mounted = {
    instance: {},
    target: renderer.createFragment(),
    props,
    actions: new Set(actions),
  };
  update(entry, values);
  entry.target.state = State.Native;
  send(opcodes.root, entry.target.id, protocol, mountId);
  entry.instance = mount(component as Component<Record<string, unknown>>, {
    target: entry.target,
    renderer,
    props: reactiveProps(props),
  });
  mounted.set(mountId, entry);
};

globalThis.__svelteProps = (mountId, json) => {
  const entry = mounted.get(mountId);
  if (entry != null) update(entry, JSON.parse(json) as Record<string, unknown>);
};

globalThis.__svelteUnmount = (mountId) => {
  const entry = mounted.get(mountId);
  if (entry == null) return;
  mounted.delete(mountId);
  void unmount(entry.instance);
  send(opcodes.remove, entry.target.id);
};

export function mountApp(
  app: Component<never> | Record<string, Component<never>>,
): void {
  if (typeof app === "function") components.set("default", app);
  else
    for (const [name, component] of Object.entries(app))
      components.set(name, component);
}

export default renderer;
