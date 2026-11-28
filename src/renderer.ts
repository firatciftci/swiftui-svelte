import "./host.ts";
import type { Component } from "svelte";
import { flushSync, mount, unmount } from "svelte";
import { SvelteMap } from "svelte/reactivity";
import { createRenderer } from "svelte/renderer";
import type { AnimationOptions } from "./elements.ts";
import type {
  Attributes,
  State as ClassState,
  Resolution,
} from "./tailwind/runtime.ts";
import type { HostEnvironment } from "./web/environment.ts";
import { checkAttribute, checkElement, isMarkup, warnOnce } from "./dev.ts";
import { textContainers } from "./markup.ts";
import { opcodes, protocol } from "./protocol.ts";
import { resolveWith } from "./tailwind/runtime.ts";
import { environment, observeEnvironment } from "./web/environment.ts";

export { protocol } from "./protocol.ts";
export { registerClasses } from "./tailwind/runtime.ts";

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
type Classes = { value: string; derived: Attributes; reactive: boolean };
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

class ElementNode implements Container, Linked {
  readonly kind = "element";
  parent: ParentNode | null = null;
  prev: ChildNode | null = null;
  next: ChildNode | null = null;
  state: NodeState = State.Local;
  first: ChildNode | null = null;
  last: ChildNode | null = null;
  attributes: Attributes | null = null;
  listeners: Array<string | Handler> | null = null;
  classes: Classes | null = null;
  readonly id: number;
  readonly name: string;

  constructor(id: number, name: string) {
    this.id = id;
    this.name = name;
  }
}

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
const scheduler = {
  nextId: 1,
  nextRequest: 1,
  isScheduled: false,
  requiresWire: false,
};
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

function requiresWire(value: unknown): boolean {
  if (typeof value === "bigint") return true;
  if (typeof value !== "object" || value == null) return false;
  if (value instanceof Map || value instanceof Set) return true;
  const items = Array.isArray(value) ? value : Object.values(value);
  return items.some((item) => requiresWire(item));
}

function sendable(value: unknown): unknown {
  if (
    !scheduler.requiresWire &&
    (typeof value === "object" || typeof value === "bigint")
  )
    scheduler.requiresWire = requiresWire(value);
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
  if (node.kind !== "text" || node.data === "") return false;
  if (node.data.trim() !== "") return true;
  const parent = node.parent;
  return parent?.kind === "element" && textContainers.has(parent.name);
}

function anchorId(node: ChildNode): number {
  let next = node.next;
  while (next != null && next.state !== State.Native) next = next.next;
  return next?.id ?? 0;
}

const noAttributes: Attributes = {};

function isSent(value: unknown): boolean {
  return value !== undefined && typeof value !== "function";
}

function encodeAttributes(node: ElementNode, record: Array<unknown>): void {
  const count = record.length;
  record.push(0);
  const attributes = node.attributes ?? noAttributes;
  for (const [name, value] of Object.entries(attributes)) {
    if (!isSent(value)) continue;
    record.push(nameRef(name), sendable(value));
    (record[count] as number)++;
  }
  const derived = node.classes?.derived ?? noAttributes;
  for (const [name, value] of Object.entries(derived)) {
    if (!isSent(value) || hasOwnAttribute(node, name)) continue;
    record.push(nameRef(name), sendable(value));
    (record[count] as number)++;
  }
}

function encode(node: ChildNode, record: Array<unknown>): void {
  node.state = State.Native;
  if (node.kind !== "element") {
    record.push(-node.id, node.data);
    return;
  }
  record.push(node.id, nameRef(node.name));
  encodeAttributes(node, record);
  const childCount = record.length;
  record.push(0);
  for (let child = node.first; child != null; child = child.next) {
    if (!isMaterial(child)) continue;
    encode(child, record);
    (record[childCount] as number)++;
  }
}

function hasOwnAttribute(element: ElementNode, name: string): boolean {
  return element.attributes != null && Object.hasOwn(element.attributes, name);
}

function derivedAttribute(element: ElementNode, name: string): unknown {
  const derived = element.classes?.derived;
  return derived != null && Object.hasOwn(derived, name)
    ? derived[name]
    : undefined;
}

function effective(element: ElementNode, name: string): unknown {
  return hasOwnAttribute(element, name)
    ? element.attributes?.[name]
    : derivedAttribute(element, name);
}

function flushAttributes(): void {
  for (const [element, changed] of changedAttributes) {
    if (element.state !== State.Native) continue;
    for (const name of changed) {
      const value = effective(element, name);
      const ref = nameRef(name);
      if (!isSent(value)) {
        send(opcodes.unattr, element.id, ref);
      } else {
        send(opcodes.attr, element.id, ref, sendable(value));
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
  const json = JSON.stringify(batch, scheduler.requiresWire ? wire : undefined);
  batch.length = 0;
  scheduler.requiresWire = false;
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
  return node instanceof ElementNode;
}

function index(element: ElementNode): void {
  if (elements.get(element.id)?.deref() !== element)
    elements.set(element.id, new WeakRef(element));
}

const target = Symbol("element");
type Attached = Ref & { [target]: ElementNode | null };

async function measure(element: ElementNode | null): Promise<Rect | null> {
  if (element == null) return null;
  const request = scheduler.nextRequest++;
  const rect = new Promise<Rect | null>((resolve) =>
    replies.set(request, resolve),
  );
  invoke(element, "measure", { request });
  return rect;
}

const refMethods: object = Object.create(Function.prototype, {
  focus: {
    get(this: Attached) {
      return () => invoke(this[target], "focus");
    },
  },
  blur: {
    get(this: Attached) {
      return () => invoke(this[target], "blur");
    },
  },
  scrollIntoView: {
    get(this: Attached) {
      return (options: ScrollOptions = {}) =>
        invoke(this[target], "scrollIntoView", options);
    },
  },
  scrollTo: {
    get(this: Attached) {
      return (
        edge: "top" | "bottom" | { x?: number; y?: number },
        options: Omit<ScrollOptions, "anchor"> = {},
      ) =>
        invoke(
          this[target],
          "scrollTo",
          typeof edge === "string"
            ? { ...options, edge }
            : { ...options, ...edge },
        );
    },
  },
  measure: {
    get(this: Attached) {
      return async () => measure(this[target]);
    },
  },
}) as object;

export function ref(): Ref {
  const attach = ((node: unknown): (() => void) => {
    if (isElement(node)) attach[target] = node;
    return () => {
      if (attach[target] === node) attach[target] = null;
    };
  }) as Attached;
  Object.setPrototypeOf(attach, refMethods);
  attach[target] = null;
  return attach;
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

const animating = { isApplying: false, later: [] as Array<() => void> };

export function withAnimation<T>(
  fn: () => T,
  animation: AnimationOptions = true,
): T | undefined {
  if (animating.isApplying) {
    animating.later.push(() => withAnimation(fn, animation));
    return undefined;
  }
  flushSync();
  commit();
  animating.isApplying = true;
  let result: T;
  try {
    result = flushSync(fn);
  } finally {
    animating.isApplying = false;
  }
  commit(animation);
  while (animating.later.length > 0) animating.later.shift()?.();
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

function handlersOf(element: ElementNode, type: string): Array<Handler> {
  const found: Array<Handler> = [];
  const { listeners } = element;
  if (listeners == null) return found;
  for (let index = 0; index < listeners.length; index += 2) {
    const handler = listeners[index + 1];
    if (typeof handler === "function" && listeners[index] === type)
      found.push(handler);
  }
  return found;
}

function listenerIndex(
  element: ElementNode,
  type: string,
  handler?: Handler,
): number {
  const { listeners } = element;
  if (listeners == null) return -1;
  for (let index = 0; index < listeners.length; index += 2) {
    if (
      listeners[index] === type &&
      (handler == null || listeners[index + 1] === handler)
    )
      return index;
  }
  return -1;
}

function setOwnAttribute(
  element: ElementNode,
  name: string,
  value: unknown,
): void {
  element.attributes ??= Object.create(null) as Attributes;
  element.attributes[name] = value;
}

function deleteOwnAttribute(element: ElementNode, name: string): void {
  if (element.attributes != null)
    Reflect.deleteProperty(element.attributes, name);
}

function updateListens(element: ElementNode): void {
  const types: Array<string> = [];
  for (const type of observedEvents) {
    if (listenerIndex(element, type) !== -1) types.push(type);
  }
  if (types.length > 0) setOwnAttribute(element, "listens", types);
  else deleteOwnAttribute(element, "listens");
  changeAttribute(element, "listens");
}

const reactiveElements = new Map<number, WeakRef<ElementNode>>();
const containerWidths = new WeakMap<ElementNode, number>();
const noClasses: Resolution = {
  attrs: {},
  reactive: false,
  unmatched: [],
  misplaced: [],
};

function containersOf(element: ElementNode): Record<string, number> {
  const widths: Record<string, number> = {};
  const seen = new Set<string>();
  let node: ParentNode | null = element.parent;
  while (node != null && isElement(node)) {
    const name = effective(node, "container");
    if (typeof name === "string" && !seen.has(name)) {
      seen.add(name);
      const width = containerWidths.get(node);
      if (width != null) widths[name] = width;
    }
    node = node.parent;
  }
  if (!seen.has("")) widths[""] = environment.viewportWidth;
  return widths;
}

function classState(element: ElementNode): ClassState {
  const disabled = element.attributes?.disabled;
  const isRtl = environment.layoutDirection === "rightToLeft";
  const { top, bottom, leading, trailing } = environment.safeAreaInsets;
  let containers: Record<string, number> | null = null;
  return {
    dark: environment.colorScheme === "dark",
    width: environment.viewportWidth,
    height: environment.viewportHeight,
    reduceMotion: environment.reduceMotion,
    rtl: isRtl,
    disabled: disabled != null && disabled !== false,
    platform: environment.platform,
    idiom: environment.idiom,
    increaseContrast: environment.increaseContrast,
    insets: {
      top,
      bottom,
      left: isRtl ? trailing : leading,
      right: isRtl ? leading : trailing,
    },
    pixelRatio: environment.pixelRatio,
    fontScale: environment.fontScale,
    get containers() {
      containers ??= containersOf(element);
      return containers;
    },
  };
}

function classInputs(value: HostEnvironment): string {
  return JSON.stringify([
    value.colorScheme,
    value.viewportWidth,
    value.viewportHeight,
    value.reduceMotion,
    value.layoutDirection,
    value.increaseContrast,
    value.safeAreaInsets,
    value.pixelRatio,
    value.fontScale,
  ]);
}

function reportClass(tag: string, resolution: Resolution): void {
  for (const token of resolution.unmatched) {
    warnOnce(
      `class ${token}`,
      `class "${token}" isn't a Tailwind utility in this build. Add the file that uses it to tailwind({ sources }), or check the spelling.`,
    );
  }
  for (const token of resolution.misplaced) {
    warnOnce(
      `<${tag}> class ${token}`,
      `class "${token}" has no effect on <${tag}>.`,
    );
  }
}

function reportResolution(name: string, resolution: Resolution): void {
  reportClass(name, resolution);
  for (const key of Object.keys(resolution.attrs)) checkAttribute(name, key);
}

function applyClass(element: ElementNode, value: string | null): void {
  const resolution =
    value == null || value === ""
      ? noClasses
      : resolveWith(element.name, value, classState(element));
  if (isDevelopment && value != null && !isMarkup(element.name))
    reportResolution(element.name, resolution);
  if (resolution.reactive)
    reactiveElements.set(element.id, new WeakRef(element));
  else reactiveElements.delete(element.id);
  if (resolution.attrs.container !== undefined) index(element);
  const previous = element.classes?.derived ?? noAttributes;
  element.classes =
    value == null
      ? null
      : { value, derived: resolution.attrs, reactive: resolution.reactive };
  updateDerived(element, previous, resolution.attrs);
}

function updateDerived(
  element: ElementNode,
  previous: Attributes,
  next: Attributes,
): void {
  if (previous === next) return;
  const changed: Array<string> = [];
  for (const [key, value] of Object.entries(previous)) {
    if (value !== undefined && derivedAttribute(element, key) !== value)
      changed.push(key);
  }
  for (const [key, value] of Object.entries(next)) {
    if (
      value !== undefined &&
      (Object.hasOwn(previous, key) ? previous[key] : undefined) !== value
    )
      changed.push(key);
  }
  for (const key of changed)
    if (!hasOwnAttribute(element, key)) changeAttribute(element, key);
}

function isDescendant(element: ElementNode, ancestor: ElementNode): boolean {
  for (
    let node: ParentNode | null = element.parent;
    node != null && isElement(node);
    node = node.parent
  )
    if (node === ancestor) return true;
  return false;
}

function reapplyReactive(container?: ElementNode): void {
  for (const [id, reference] of reactiveElements) {
    const element = reference.deref();
    if (element?.classes?.reactive !== true) reactiveElements.delete(id);
    else if (container == null || isDescendant(element, container))
      applyClass(element, element.classes.value);
  }
}

observeEnvironment((previous) => {
  if (classInputs(previous) === classInputs(environment)) return;
  reapplyReactive();
});

function containerResized(element: ElementNode, payload: unknown): void {
  if (
    typeof payload !== "object" ||
    payload == null ||
    !("width" in payload) ||
    typeof payload.width !== "number" ||
    containerWidths.get(element) === payload.width
  )
    return;
  containerWidths.set(element, payload.width);
  reapplyReactive(element);
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
    return track(new ElementNode(scheduler.nextId++, name));
  },
  createText(data) {
    return track({
      parent: null,
      prev: null,
      next: null,
      state: State.Local,
      kind: "text",
      id: scheduler.nextId++,
      data,
    });
  },
  createComment(data) {
    return track({
      parent: null,
      prev: null,
      next: null,
      state: State.Local,
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
    if (name === "class") return element.classes?.value ?? null;
    const value = element.attributes?.[name];
    return value == null ? null : String(value);
  },
  setAttribute(element, name, value: unknown) {
    if (name === "class") {
      applyClass(element, value == null ? null : String(value));
      return;
    }
    if (isDevelopment) checkAttribute(element.name, name);
    if (name === "container") index(element);
    setOwnAttribute(element, name, value);
    changeAttribute(element, name);
    if (name === "disabled" && element.classes?.reactive === true)
      applyClass(element, element.classes.value);
  },
  removeAttribute(element, name) {
    if (name === "class") {
      applyClass(element, null);
      return;
    }
    deleteOwnAttribute(element, name);
    changeAttribute(element, name);
    if (name === "disabled" && element.classes?.reactive === true)
      applyClass(element, element.classes.value);
  },
  hasAttribute(element, name) {
    return name === "class"
      ? element.classes != null
      : hasOwnAttribute(element, name);
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
    if (listenerIndex(element, type, handler) !== -1) return;
    index(element);
    const isFirst = listenerIndex(element, type) === -1;
    if (element.listeners == null) element.listeners = [type, handler];
    else element.listeners.push(type, handler);
    if (isFirst && observedEvents.has(type)) updateListens(element);
  },
  removeEventListener(element, type, handler: Handler) {
    const index = listenerIndex(element, type, handler);
    if (index === -1 || element.listeners == null) return;
    if (element.listeners.length === 2) element.listeners = null;
    else element.listeners.splice(index, 2);
    if (observedEvents.has(type) && listenerIndex(element, type) === -1)
      updateListens(element);
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
        report(outcome.reason);
      }
    }
    invoke(element, "settled", { request });
  });
}

function report(error: unknown): void {
  setTimeout(() => {
    throw error;
  }, 0);
}

function run(
  handlers: Array<Handler>,
  argument: unknown,
  request: number | undefined,
): Array<unknown> {
  const results: Array<unknown> = [];
  for (const handler of handlers) {
    try {
      results.push(handler(argument));
    } catch (error) {
      if (request == null) report(error);
      else results.push(Promise.reject(error));
    }
  }
  return results;
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
  if (
    type === "resize" &&
    element != null &&
    effective(element, "container") != null
  )
    containerResized(element, payload);
  const handlers = element == null ? [] : handlersOf(element, type);
  if (element == null || handlers.length === 0) {
    if (request != null) {
      __nativeInvoke(id, "settled", JSON.stringify({ request }));
    }
    return;
  }
  const argument = type === "task" ? startTask(request) : payload;
  const results = run(handlers, argument, request);
  if (request != null) awaitHandlers(element, request, results);
  const name =
    controlledAttributes.get(element.name)?.[type] ??
    (type === "input" || type === "change" ? "value" : undefined);
  if (name == null) return;
  if (name === "checked" || hasOwnAttribute(element, name)) {
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
  const supported =
    typeof __nativeProtocols === "undefined" ? [3] : __nativeProtocols;
  if (!supported.includes(protocol)) {
    console.warn(
      `This bundle uses bridge protocol ${protocol}, but the app's SvelteSwiftUI package supports protocol ${supported.join(" and ")}. Install the same release of swiftui-svelte from npm and SvelteSwiftUI from Swift Package Manager, then rebuild the bundle.`,
    );
    return;
  }
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
