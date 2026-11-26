import "./host.ts";
import type { Component } from "svelte";
import { flushSync, mount, unmount } from "svelte";
import { SvelteMap } from "svelte/reactivity";
import { createRenderer } from "svelte/renderer";
import type { AnimationOptions } from "./elements.ts";
import { checkAttribute, checkElement } from "./dev.ts";

type Handler = (payload: unknown) => unknown;
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
type Rect = { x: number; y: number; width: number; height: number };
type ScrollOptions = {
  anchor?:
    | "top"
    | "center"
    | "bottom"
    | "leading"
    | "trailing"
    | "topLeading"
    | "topTrailing"
    | "bottomLeading"
    | "bottomTrailing";
  animated?: boolean;
};
export type Ref = ((node: unknown) => () => void) & {
  focus(): void;
  blur(): void;
  scrollIntoView(options?: ScrollOptions): void;
  scrollTo(
    edge: "top" | "bottom",
    options?: Omit<ScrollOptions, "anchor">,
  ): void;
  scrollTo(
    offset: { x?: number; y?: number },
    options?: Omit<ScrollOptions, "anchor">,
  ): void;
  measure(): Promise<Rect | null>;
};
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

declare const __SWIFTUI_SVELTE_DEV__: boolean | undefined;

const isDevelopment =
  typeof __SWIFTUI_SVELTE_DEV__ !== "undefined" && __SWIFTUI_SVELTE_DEV__;

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
const scheduler = { nextId: 1, nextRequest: 1, isScheduled: false };
const invocations: Array<
  [element: ElementNode, method: string, options: Record<string, unknown>]
> = [];
const replies = new Map<number, (rect: Rect | null) => void>();

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

function flushInvocations(): void {
  const waiting: typeof invocations = [];
  for (const invocation of invocations) {
    const [element, method, options] = invocation;
    if (method === "settled" || element.state === State.Native) {
      __nativeInvoke(element.id, method, JSON.stringify(options));
    } else if (element.state === State.Pending) {
      waiting.push(invocation);
    } else if (typeof options.request === "number") {
      settle(options.request, null);
    }
  }
  invocations.length = 0;
  for (const invocation of waiting) invocations.push(invocation);
}

function commit(animation?: AnimationOptions): void {
  scheduler.isScheduled = false;
  const start = __nativeNow();
  flushAttributes();
  flushTexts();
  flushInserts();
  if (batch.length === 0) {
    flushInvocations();
    return;
  }
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
  flushInvocations();
}

function settle(request: number, rect: Rect | null): void {
  const resolve = replies.get(request);
  replies.delete(request);
  resolve?.(rect);
}

function invoke(
  element: ElementNode | null,
  method: string,
  options: Record<string, unknown> = {},
): void {
  if (element == null) return;
  invocations.push([element, method, options]);
  schedule();
}

function isElement(node: unknown): node is ElementNode {
  return (
    typeof node === "object" &&
    node != null &&
    "kind" in node &&
    node.kind === "element" &&
    "id" in node &&
    typeof node.id === "number" &&
    elements.get(node.id)?.deref() === node
  );
}

export function ref(): Ref {
  let element: ElementNode | null = null;
  const attach = (node: unknown): (() => void) => {
    if (isElement(node)) element = node;
    return () => {
      if (element === node) element = null;
    };
  };
  return Object.assign(attach, {
    focus: () => invoke(element, "focus"),
    blur: () => invoke(element, "blur"),
    scrollIntoView: (options: ScrollOptions = {}) =>
      invoke(element, "scrollIntoView", options),
    scrollTo: (
      target: "top" | "bottom" | { x?: number; y?: number },
      options: Omit<ScrollOptions, "anchor"> = {},
    ) =>
      invoke(
        element,
        "scrollTo",
        typeof target === "string"
          ? { ...options, edge: target }
          : { ...options, ...target },
      ),
    measure: async (): Promise<Rect | null> => {
      if (element == null) return null;
      const request = scheduler.nextRequest++;
      const rect = new Promise<Rect | null>((resolve) =>
        replies.set(request, resolve),
      );
      invoke(element, "measure", { request });
      return rect;
    },
  });
}

globalThis.__svelteReply = (request, rect) => settle(request, rect);

export function move<T>(
  items: Array<T>,
  from: Array<number>,
  to: number,
): void {
  const indices = [...new Set(from)]
    .filter((index) => index >= 0 && index < items.length)
    .toSorted((a, b) => a - b);
  const moving = indices.map((index) => items[index] as T);
  const target = to - indices.filter((index) => index < to).length;
  for (const index of indices.toReversed()) items.splice(index, 1);
  items.splice(Math.min(Math.max(target, 0), items.length), 0, ...moving);
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

const observedEvents = new Set([
  "a11yactivate",
  "a11yadjust",
  "a11yescape",
  "a11ymagictap",
  "appear",
  "delete",
  "disappear",
  "drag",
  "hover",
  "longpress",
  "magnify",
  "move",
  "primaryaction",
  "refresh",
  "resize",
  "rotate",
  "scroll",
  "scrollphase",
  "scrollvisibility",
  "selectionchange",
  "tap",
  "task",
]);

function updateListens(element: ElementNode): void {
  const types: Array<string> = [];
  for (const type of observedEvents) {
    if ((element.listeners.get(type)?.size ?? 0) > 0) types.push(type);
  }
  if (types.length > 0) element.attributes.set("listens", types);
  else element.attributes.delete("listens");
  changeAttribute(element, "listens");
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
    if (isDevelopment) checkElement(name);
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
    if (isDevelopment) checkAttribute(element.name, name);
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
    if (observedEvents.has(type) && handlers.size === 1) updateListens(element);
  },
  removeEventListener(element, type, handler: Handler) {
    const handlers = element.listeners.get(type);
    if (handlers?.delete(handler) !== true) return;
    if (observedEvents.has(type) && handlers.size === 0) updateListens(element);
  },
});

const controlledAttributes = new Map<string, Record<string, string>>([
  ["toggle", { change: "checked" }],
  ["tabview", { change: "selection" }],
  ["list", { editingchange: "editing", selectionchange: "selection" }],
  [
    "searchable",
    {
      presentedchange: "presented",
      scopechange: "selectedscope",
      tokenschange: "tokens",
    },
  ],
  [
    "navsplitview",
    { visibilitychange: "visibility", compactcolumnchange: "compactcolumn" },
  ],
]);

const tasks = new Map<number, AbortController>();

function awaitHandlers(
  element: ElementNode,
  request: number,
  results: Array<unknown>,
): void {
  void Promise.allSettled(results).then((outcomes) => {
    const signal = tasks.get(request)?.signal;
    tasks.delete(request);
    for (const outcome of outcomes) {
      if (outcome.status === "rejected" && signal?.aborted !== true) {
        setTimeout(() => {
          throw outcome.reason;
        }, 0);
      }
    }
    invoke(element, "settled", { request });
  });
}

function startTask(request: number | undefined): AbortSignal {
  const controller = new AbortController();
  if (request != null) tasks.set(request, controller);
  return controller.signal;
}

globalThis.__svelteDispatch = (id, type, payload, request) => {
  if (type === "taskcancel") {
    if (typeof payload === "number") tasks.get(payload)?.abort();
    return;
  }
  const element = elements.get(id)?.deref();
  const handlers = element?.listeners.get(type);
  if (element == null || handlers == null || handlers.size === 0) {
    if (request != null) {
      __nativeInvoke(id, "settled", JSON.stringify({ request }));
    }
    return;
  }
  const argument = type === "task" ? startTask(request) : payload;
  const results = Array.from(handlers, (handler) => handler(argument));
  if (request != null) awaitHandlers(element, request, results);
  const name =
    controlledAttributes.get(element.name)?.[type] ??
    (type === "input" || type === "change" ? "value" : undefined);
  if (name == null) return;
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
