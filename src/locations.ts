import MagicString from "magic-string";
import path from "node:path";
import { parse } from "svelte/compiler";
import { isMarkup } from "./dev.ts";
import { modifiers } from "./known.ts";

type Located = {
  type: string;
  name: string;
  name_loc: {
    start: { line: number; column: number };
    end: { character: number };
  };
  attributes: Array<{ type: string; name?: string; value?: unknown }>;
};

function isLocated(value: object): value is Located {
  return "type" in value && value.type === "RegularElement";
}

function elementsIn(node: unknown, found: Array<Located>): Array<Located> {
  if (node == null || typeof node !== "object") return found;
  if (Array.isArray(node)) {
    for (const child of node) elementsIn(child, found);
    return found;
  }
  if (isLocated(node) && !isMarkup(node.name)) found.push(node);
  for (const [key, value] of Object.entries(node)) {
    if (key !== "loc" && key !== "name_loc") elementsIn(value, found);
  }
  return found;
}

function isExpression(value: unknown): boolean {
  if (
    value == null ||
    typeof value !== "object" ||
    !("type" in value) ||
    value.type !== "ExpressionTag"
  )
    return false;
  const expression = "expression" in value ? value.expression : null;
  return !(
    expression != null &&
    typeof expression === "object" &&
    "type" in expression &&
    expression.type === "Literal"
  );
}

function isDynamic(value: unknown): boolean {
  return Array.isArray(value)
    ? value.some((part) => isExpression(part))
    : isExpression(value);
}

function field(node: object, name: string): unknown {
  const value: unknown = Object.getOwnPropertyDescriptor(node, name)?.value;
  return value;
}

function written(node: object): string | null {
  const type = field(node, "type");
  const value = field(node, "value");
  if (type === "Literal") return typeof value === "string" ? value : null;
  if (type === "Text") {
    const data = field(node, "data");
    return typeof data === "string" ? data : null;
  }
  if (
    type === "TemplateElement" &&
    value != null &&
    typeof value === "object"
  ) {
    const cooked = field(value, "cooked");
    return typeof cooked === "string" ? cooked : null;
  }
  if (type !== "Property" || field(node, "computed") !== false) return null;
  const key = field(node, "key");
  const name =
    key != null && typeof key === "object" ? field(key, "name") : null;
  return typeof name === "string" ? name : null;
}

function strings(node: unknown, found: Array<string>): Array<string> {
  if (node == null || typeof node !== "object") return found;
  if (Array.isArray(node)) {
    for (const child of node) strings(child, found);
    return found;
  }
  const text = written(node);
  if (text != null) found.push(text);
  for (const [key, child] of Object.entries(node)) {
    if (key !== "loc") strings(child, found);
  }
  return found;
}

function declared(element: Located): {
  names: Array<string>;
  classes: Array<string>;
} {
  const names: Array<string> = [];
  const classes: Array<string> = [];
  for (const { type, name, value } of element.attributes) {
    if (type === "ClassDirective" && name != null) classes.push(name);
    if (type !== "Attribute" || name == null || !isDynamic(value)) continue;
    if (name === "class") strings(value, classes);
    else if (modifiers.has(name)) names.push(name);
  }
  return { names, classes };
}

function escaped(text: string): string {
  return text.replaceAll(
    /[&"{}]/g,
    (character) => `&#${character.codePointAt(0)};`,
  );
}

export function annotate(
  content: string,
  filename: string,
  root: string,
  { stamps }: { stamps: boolean },
): { code: string; map: ReturnType<MagicString["generateMap"]> } | null {
  let fragment: unknown;
  try {
    fragment = parse(content, { modern: true, filename }).fragment;
  } catch {
    return null;
  }
  const elements = elementsIn(fragment, []);
  if (elements.length === 0) return null;
  const file = escaped(path.relative(root, filename).split(path.sep).join("/"));
  const code = new MagicString(content);
  for (const element of elements) {
    const { start, end } = element.name_loc;
    const { names, classes } = declared(element);
    const tokens = [...new Set(classes.join(" ").split(/\s+/))]
      .join(" ")
      .trim();
    const annotation =
      (stamps ? ` data-loc="${file}:${start.line}:${start.column}"` : "") +
      (names.length > 0 ? ` data-declare="${names.join(" ")}"` : "") +
      (tokens !== "" ? ` data-declare-classes="${escaped(tokens)}"` : "");
    if (annotation !== "") code.appendLeft(end.character, annotation);
  }
  if (!code.hasChanged()) return null;
  return {
    code: code.toString(),
    map: code.generateMap({ hires: true, source: filename }),
  };
}
