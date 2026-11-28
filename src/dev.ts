import { elements, elementValues, modifiers, modifierValues } from "./known.ts";
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

export function warnOnce(
  key: string,
  message: string,
  context?: {
    element: string;
    attribute?: string;
    value?: string;
    location?: string;
  },
): void {
  if (warned.has(key)) return;
  warned.add(key);
  if (typeof __nativeDiagnostic === "function") {
    __nativeDiagnostic(JSON.stringify({ ...context, message }));
  } else {
    console.warn(message);
  }
}

export function checkElement(name: string, location?: string): void {
  if (Object.hasOwn(elements, name) || isMarkup(name)) return;
  const suggestion = closest(name, Object.keys(elements), 1);
  if (suggestion == null) return;
  warnOnce(
    `<${name}>`,
    `There's no element named <${name}>. Did you mean <${suggestion}>? If <${name}> is a native component, register it with SvelteView(components:).`,
    { element: name, location },
  );
}

export function checkAttribute(
  element: string,
  name: string,
  location?: string,
): void {
  if (element === "label") {
    warnOnce(
      `<label> ${name}`,
      `<label> only holds the custom label of the element around it, so its "${name}" attribute does nothing. Put the attribute on an element inside the <label>.`,
      { element, attribute: name, location },
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
    { element, attribute: name, location },
  );
}

export function checkFont(
  element: string,
  font: unknown,
  size: unknown,
  fontname: unknown,
  location?: string,
): void {
  if (font == null || size == null || fontname != null) return;
  warnOnce(
    `<${element}> font size`,
    `<${element}> has both font and size, so it ignores font="${String(font)}" and uses a fixed-size system font that doesn't follow Dynamic Type. Remove one of them, or set fontname to scale a custom font relative to that text style.`,
    { element, attribute: "font", value: String(font), location },
  );
}

function quotedList(values: ReadonlyArray<string>): string {
  const quoted = values.map((value) => `"${value}"`);
  if (quoted.length < 3) return quoted.join(" or ");
  return `${quoted.slice(0, -1).join(", ")}, or ${quoted.at(-1)}`;
}

export function checkValue(
  element: string,
  name: string,
  value: unknown,
  location?: string,
): void {
  if (typeof value !== "string" || value === "") return;
  const allowed = elementValues[element]?.[name] ?? modifierValues[name];
  if (allowed == null || allowed.includes(value)) return;
  const problem = `<${element}> ${name}="${value}" isn't a value ${name} accepts, so it has no effect.`;
  const suggestion = closest(
    value,
    allowed,
    Math.max(2, Math.floor(value.length / 3)),
  );
  let advice = "docs/reference.md lists the values it takes.";
  if (suggestion != null) advice = `Did you mean "${suggestion}"?`;
  else if (allowed.length <= 12) advice = `Use ${quotedList(allowed)}.`;
  warnOnce(`<${element}> ${name}=${value}`, `${problem} ${advice}`, {
    element,
    attribute: name,
    value,
    location,
  });
}
