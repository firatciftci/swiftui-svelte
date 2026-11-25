type Op =
  | { op: "root"; id: number }
  | { op: "create"; id: number; kind: Kind; name?: string; text?: string }
  | { op: "insert"; parent: number; id: number; before: number | null }
  | { op: "remove"; id: number }
  | { op: "attr"; id: number; name: string; value: unknown }
  | { op: "unattr"; id: number; name: string }
  | { op: "text"; id: number; text: string }
  | { op: "release"; id: number };
type Kind = "fragment" | "element" | "text" | "comment";
type MirrorNode = {
  id: number;
  kind: Kind;
  name: string;
  text: string;
  attributes: Map<string, unknown>;
  children: Array<MirrorNode>;
  parent: MirrorNode | null;
};

const nodes = new Map<number, MirrorNode>();
export const commits: Array<string> = [];
export const native = { root: null as MirrorNode | null };

function detach(node: MirrorNode): void {
  const { parent } = node;
  if (parent == null) return;
  parent.children.splice(parent.children.indexOf(node), 1);
  node.parent = null;
}

function apply(op: Op): void {
  switch (op.op) {
    case "root": {
      native.root = nodes.get(op.id) ?? null;
      break;
    }
    case "create": {
      nodes.set(op.id, {
        id: op.id,
        kind: op.kind,
        name: op.name ?? "",
        text: op.text ?? "",
        attributes: new Map(),
        children: [],
        parent: null,
      });
      break;
    }
    case "insert": {
      const parent = nodes.get(op.parent);
      const node = nodes.get(op.id);
      if (parent == null || node == null) throw new Error(`insert ${op.id}`);
      detach(node);
      const before = op.before == null ? null : nodes.get(op.before);
      const index =
        before == null
          ? parent.children.length
          : parent.children.indexOf(before);
      if (index === -1) throw new Error(`anchor ${op.before} not in parent`);
      parent.children.splice(index, 0, node);
      node.parent = parent;
      break;
    }
    case "remove": {
      const node = nodes.get(op.id);
      if (node != null) detach(node);
      break;
    }
    case "attr": {
      nodes.get(op.id)?.attributes.set(op.name, op.value);
      break;
    }
    case "unattr": {
      nodes.get(op.id)?.attributes.delete(op.name);
      break;
    }
    case "text": {
      const node = nodes.get(op.id);
      if (node != null) node.text = op.text;
      break;
    }
    case "release": {
      const node = nodes.get(op.id);
      if (node != null) detach(node);
      nodes.delete(op.id);
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

export function installBridge(): void {
  Object.assign(globalThis, {
    __nativeCommit(json: string): void {
      commits.push(json);
      for (const op of JSON.parse(json) as Array<Op>) apply(op);
    },
    __nativeNow: (): number => performance.now(),
  });
}
