import type { Component } from "svelte";
import { mountApp } from "swiftui-svelte";
import { opcodes, protocol } from "swiftui-svelte/protocol";
import { createStorage } from "swiftui-svelte/web/storage";

type Kind = "fragment" | "element" | "text";
type MirrorNode = {
  id: number;
  kind: Kind;
  name: string;
  text: string;
  attributes: Map<string, unknown>;
  children: Array<MirrorNode>;
  parent: MirrorNode | null;
};
type NodeRecord = {
  id: number;
  kind: "element" | "text";
  name: string;
  text: string;
  attributes: Array<[string, unknown]>;
  children: Array<NodeRecord>;
};
type Op =
  | { op: "root"; id: number; protocol: number; mount: number }
  | { op: "insert"; parent: number; before: number; node: NodeRecord }
  | { op: "move"; parent: number; before: number; id: number }
  | { op: "remove"; id: number }
  | { op: "attr"; id: number; name: string; value: unknown }
  | { op: "unattr"; id: number; name: string }
  | { op: "text"; id: number; text: string }
  | { op: "name"; name: string };

const nodes = new Map<number, MirrorNode>();
const names: Array<string> = [];
export const commits: Array<string> = [];
export const animations: Array<string | undefined> = [];
export const invocations: Array<{
  id: number;
  method: string;
  options: Record<string, unknown>;
  afterCommit: number;
  known: boolean;
}> = [];
export const ops: Array<Op> = [];
export const native = {
  root: null as MirrorNode | null,
  roots: new Map<number, MirrorNode>(),
  frameRequests: 0,
  actions: [] as Array<{ mountId: number; name: string; payload: unknown }>,
};

class Cursor {
  index = 0;
  readonly tokens: Array<unknown>;

  constructor(tokens: Array<unknown>) {
    this.tokens = tokens;
  }

  get isDone(): boolean {
    return this.index >= this.tokens.length;
  }

  value(): unknown {
    if (this.isDone) throw new RangeError("truncated batch");
    return this.tokens[this.index++];
  }

  int(): number {
    const value = this.value();
    if (typeof value !== "number" || !Number.isSafeInteger(value))
      throw new TypeError(`expected an integer, got ${JSON.stringify(value)}`);
    return value;
  }

  string(): string {
    const value = this.value();
    if (typeof value !== "string")
      throw new TypeError(`expected a string, got ${JSON.stringify(value)}`);
    return value;
  }

  name(): string {
    const ref = this.int();
    const name = names[ref];
    if (name == null) throw new RangeError(`unknown name ${ref}`);
    return name;
  }

  record(): NodeRecord {
    const id = this.int();
    if (id < 0) {
      return {
        id: -id,
        kind: "text",
        name: "",
        text: this.string(),
        attributes: [],
        children: [],
      };
    }
    const name = this.name();
    const attributes: Array<[string, unknown]> = [];
    const attributeCount = this.int();
    for (let index = 0; index < attributeCount; index++)
      attributes.push([this.name(), this.value()]);
    const children: Array<NodeRecord> = [];
    const childCount = this.int();
    for (let index = 0; index < childCount; index++)
      children.push(this.record());
    return { id, kind: "element", name, text: "", attributes, children };
  }

  op(): Op {
    const opcode = this.int();
    switch (opcode) {
      case opcodes.root: {
        return {
          op: "root",
          id: this.int(),
          protocol: this.int(),
          mount: this.int(),
        };
      }
      case opcodes.insert: {
        return {
          op: "insert",
          parent: this.int(),
          before: this.int(),
          node: this.record(),
        };
      }
      case opcodes.move: {
        return {
          op: "move",
          parent: this.int(),
          before: this.int(),
          id: this.int(),
        };
      }
      case opcodes.remove: {
        return { op: "remove", id: this.int() };
      }
      case opcodes.attr: {
        return {
          op: "attr",
          id: this.int(),
          name: this.name(),
          value: this.value(),
        };
      }
      case opcodes.unattr: {
        return { op: "unattr", id: this.int(), name: this.name() };
      }
      case opcodes.text: {
        return { op: "text", id: this.int(), text: this.string() };
      }
      case opcodes.name: {
        const name = this.string();
        names.push(name);
        return { op: "name", name };
      }
      default: {
        throw new RangeError(`unknown opcode ${opcode}`);
      }
    }
  }
}

function build(record: NodeRecord): MirrorNode {
  if (nodes.has(record.id)) throw new Error(`node ${record.id} sent twice`);
  const node: MirrorNode = {
    id: record.id,
    kind: record.kind,
    name: record.name,
    text: record.text,
    attributes: new Map(
      record.attributes.filter(([, value]) => value !== null),
    ),
    children: [],
    parent: null,
  };
  nodes.set(node.id, node);
  for (const child of record.children) {
    const built = build(child);
    built.parent = node;
    node.children.push(built);
  }
  return node;
}

function forget(node: MirrorNode): void {
  nodes.delete(node.id);
  for (const child of node.children) forget(child);
}

function detach(node: MirrorNode): void {
  const { parent } = node;
  if (parent == null) return;
  parent.children.splice(parent.children.indexOf(node), 1);
  node.parent = null;
}

function existing(id: number): MirrorNode {
  const node = nodes.get(id);
  if (node == null) throw new Error(`unknown node ${id}`);
  return node;
}

function place(parent: MirrorNode, node: MirrorNode, before: number): void {
  detach(node);
  const index =
    before === 0
      ? parent.children.length
      : parent.children.indexOf(existing(before));
  if (index === -1) throw new Error(`anchor ${before} not in parent`);
  parent.children.splice(index, 0, node);
  node.parent = parent;
}

function apply(op: Op): void {
  switch (op.op) {
    case "root": {
      if (op.protocol !== protocol) throw new Error(`protocol ${op.protocol}`);
      const root: MirrorNode = {
        id: op.id,
        kind: "fragment",
        name: "",
        text: "",
        attributes: new Map(),
        children: [],
        parent: null,
      };
      nodes.set(op.id, root);
      native.roots.set(op.mount, root);
      native.root = root;
      break;
    }
    case "insert": {
      place(existing(op.parent), build(op.node), op.before);
      break;
    }
    case "move": {
      place(existing(op.parent), existing(op.id), op.before);
      break;
    }
    case "remove": {
      const node = existing(op.id);
      detach(node);
      forget(node);
      for (const [mount, root] of native.roots) {
        if (root === node) native.roots.delete(mount);
      }
      if (native.root === node) native.root = null;
      break;
    }
    case "attr": {
      existing(op.id).attributes.set(op.name, op.value);
      break;
    }
    case "unattr": {
      existing(op.id).attributes.delete(op.name);
      break;
    }
    case "text": {
      existing(op.id).text = op.text;
      break;
    }
    case "name": {
      break;
    }
  }
}

function canonical(value: unknown): string {
  if (Array.isArray(value))
    return `[${value.map((item) => canonical(item)).join(",")}]`;
  if (value != null && typeof value === "object") {
    const entries = Object.entries(value).toSorted(([a], [b]) =>
      a < b ? -1 : 1,
    );
    return `{${entries.map(([key, item]) => `${JSON.stringify(key)}:${canonical(item)}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

export function serialize(
  node: MirrorNode | null = native.root,
  depth = 0,
): string {
  if (node == null) return "";
  const indent = "  ".repeat(depth);
  let line: string;
  if (node.kind === "element") {
    const attributes = [...node.attributes]
      .toSorted(([a], [b]) => (a < b ? -1 : 1))
      .map(([key, value]) => ` ${key}=${canonical(value)}`)
      .join("");
    line = `${indent}<${node.name}${attributes}>`;
  } else if (node.kind === "fragment") {
    line = `${indent}#fragment`;
  } else {
    line = `${indent}#${node.kind} ${JSON.stringify(node.text)}`;
  }
  return [
    line,
    ...node.children.map((child) => serialize(child, depth + 1)),
  ].join("\n");
}

export function find(
  name: string,
  node: MirrorNode | null = native.root,
): MirrorNode | undefined {
  if (node == null) return undefined;
  if (node.kind === "element" && node.name === name) return node;
  for (const child of node.children) {
    const found = find(name, child);
    if (found != null) return found;
  }
  return undefined;
}

export function findAll(
  name: string,
  node: MirrorNode | null = native.root,
): Array<MirrorNode> {
  if (node == null) return [];
  const own = node.kind === "element" && node.name === name ? [node] : [];
  return [...own, ...node.children.flatMap((child) => findAll(name, child))];
}

export function reset(): void {
  commits.length = 0;
  animations.length = 0;
  invocations.length = 0;
  ops.length = 0;
}

export async function settle(): Promise<void> {
  for (let index = 0; index < 3; index++) await Promise.resolve();
}

export function dispatch(
  node: MirrorNode | undefined,
  type: string,
  payload: unknown = null,
): void {
  if (node == null) throw new Error(`no node to dispatch ${type}`);
  globalThis.__svelteDispatch(node.id, type, payload);
}

export function edit(
  node: MirrorNode | undefined,
  type: string,
  name: string,
  value: unknown,
): void {
  node?.attributes.set(name, value);
  dispatch(node, type, value);
}

export function byTestId(id: string): MirrorNode | undefined {
  const search = (node: MirrorNode): MirrorNode | undefined => {
    if (node.attributes.get("testid") === id) return node;
    for (const child of node.children) {
      const found = search(child);
      if (found != null) return found;
    }
    return undefined;
  };
  return native.root == null ? undefined : search(native.root);
}

export function frame(time: number): void {
  globalThis.__svelteFrame(time);
}

let nextMount = 1;

export function mountComponent(
  component: Component<never>,
  props: Record<string, unknown> = {},
  actions: Array<string> = [],
): () => void {
  const id = nextMount++;
  const name = `component${id}`;
  mountApp({ [name]: component });
  globalThis.__svelteMount(id, name, JSON.stringify({ props, actions }));
  return () => globalThis.__svelteUnmount(id);
}

export function lastMount(): number {
  return nextMount - 1;
}

export function installBridge(): void {
  Object.assign(globalThis, {
    localStorage: createStorage([]),
    __nativeCommit(json: string, animation?: string): void {
      commits.push(json);
      animations.push(animation);
      const cursor = new Cursor(JSON.parse(json) as Array<unknown>);
      while (!cursor.isDone) {
        const op = cursor.op();
        ops.push(op);
        apply(op);
      }
    },
    __nativeNow: (): number => performance.now(),
    __nativeAction(mountId: number, name: string, json: string): void {
      native.actions.push({ mountId, name, payload: JSON.parse(json) });
    },
    __nativeRequestFrame(): void {
      native.frameRequests++;
    },
    __nativeInvoke(id: number, method: string, json: string): void {
      invocations.push({
        id,
        method,
        options: JSON.parse(json) as Record<string, unknown>,
        afterCommit: commits.length,
        known: nodes.has(id),
      });
    },
  });
}
