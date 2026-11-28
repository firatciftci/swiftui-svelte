import MagicString from "magic-string";
import path from "node:path";
import { parse } from "svelte/compiler";
import { isMarkup } from "./dev.ts";

type Located = {
  type: string;
  name: string;
  name_loc: {
    start: { line: number; column: number };
    end: { character: number };
  };
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

export function stampLocations(
  content: string,
  filename: string,
  root: string,
): { code: string; map: ReturnType<MagicString["generateMap"]> } | null {
  let fragment: unknown;
  try {
    fragment = parse(content, { modern: true, filename }).fragment;
  } catch {
    return null;
  }
  const elements = elementsIn(fragment, []);
  if (elements.length === 0) return null;
  const file = path
    .relative(root, filename)
    .split(path.sep)
    .join("/")
    .replaceAll(/[&"{}]/g, (character) => `&#${character.codePointAt(0)};`);
  const code = new MagicString(content);
  for (const element of elements) {
    const { start, end } = element.name_loc;
    code.appendLeft(
      end.character,
      ` data-loc="${file}:${start.line}:${start.column}"`,
    );
  }
  return {
    code: code.toString(),
    map: code.generateMap({ hires: true, source: filename }),
  };
}
