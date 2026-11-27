import { elements, modifiers } from "./known.ts";
import { textContainers } from "./markup.ts";

const warned = new Set<string>();
const markupOnly = "hr img ol table tbody tfoot thead tr ul";
const vectorOnly = "svg g path rect circle ellipse line polyline polygon title";

export function isMarkup(name: string): boolean {
  if (name === "txt") return false;
  return (
    textContainers.has(name) ||
    `${markupOnly} ${vectorOnly}`.split(" ").includes(name)
  );
}

function distance(a: string, b: string): number {
  let previous = Array.from({ length: b.length + 1 }, (_, index) => index);
  for (const [row, left] of [...a].entries()) {
    const current = [row + 1];
    for (const [column, right] of [...b].entries()) {
      current.push(
        Math.min(
          (previous[column + 1] ?? 0) + 1,
          (current[column] ?? 0) + 1,
          (previous[column] ?? 0) + (left === right ? 0 : 1),
        ),
      );
    }
    previous = current;
  }
  return previous[b.length] ?? 0;
}

function closest(
  name: string,
  candidates: Iterable<string>,
  limit: number,
): string | null {
  let best: string | null = null;
  let bestDistance = limit + 1;
  for (const candidate of candidates) {
    const gap = distance(name, candidate);
    if (gap >= bestDistance) continue;
    best = candidate;
    bestDistance = gap;
  }
  return best;
}

export function warnOnce(key: string, message: string): void {
  if (warned.has(key)) return;
  warned.add(key);
  console.warn(message);
}

export function checkElement(name: string): void {
  if (Object.hasOwn(elements, name) || isMarkup(name)) return;
  const suggestion = closest(name, Object.keys(elements), 1);
  if (suggestion == null) return;
  warnOnce(
    `<${name}>`,
    `There's no element named <${name}>. Did you mean <${suggestion}>? If <${name}> is a native component, register it with SvelteView(components:).`,
  );
}

export function checkAttribute(element: string, name: string): void {
  if (element === "label") {
    warnOnce(
      `<label> ${name}`,
      `<label> only holds the custom label of the element around it, so its "${name}" attribute does nothing. Put the attribute on an element inside the <label>.`,
    );
    return;
  }
  const own = elements[element];
  if (own == null || modifiers.has(name) || own.includes(name)) return;
  const suggestion = closest(
    name,
    [...modifiers, ...own],
    Math.max(2, Math.floor(name.length / 3)),
  );
  warnOnce(
    `<${element}> ${name}`,
    `<${element}> doesn't have an attribute named "${name}".${suggestion == null ? "" : ` Did you mean "${suggestion}"?`}`,
  );
}
