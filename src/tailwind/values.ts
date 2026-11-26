export type Lookup = (name: string) => string | undefined;
export type Rgba = { r: number; g: number; b: number; a: number };
export type Quantity = { value: number; unit: "" | "px" | "%" | "deg" };

export class Unsupported extends Error {}

const REM = 16;

export function substitute(value: string, lookup: Lookup, depth = 0): string {
  if (depth > 24)
    throw new Unsupported(`var() nesting is too deep in "${value}"`);
  let result = "";
  let index = 0;
  for (
    let start = value.indexOf("var(");
    start !== -1;
    start = value.indexOf("var(", index)
  ) {
    result += value.slice(index, start);
    const close = closingParen(value, start + 3);
    const inner = value.slice(start + 4, close);
    const comma = topLevel(inner, ",");
    const name = (comma === -1 ? inner : inner.slice(0, comma)).trim();
    const fallback = comma === -1 ? undefined : inner.slice(comma + 1).trim();
    const found = lookup(name);
    if (found !== undefined) result += substitute(found, lookup, depth + 1);
    else if (fallback !== undefined)
      result += substitute(fallback, lookup, depth + 1);
    else throw new Unsupported(`${name} isn't defined`);
    index = close + 1;
  }
  return result + value.slice(index);
}

function closingParen(text: string, open: number): number {
  let depth = 0;
  for (let index = open; index < text.length; index++) {
    if (text[index] === "(") depth++;
    else if (text[index] === ")") {
      depth--;
      if (depth === 0) return index;
    }
  }
  throw new Unsupported(`unbalanced parentheses in "${text}"`);
}

function topLevel(text: string, separator: string): number {
  let depth = 0;
  for (const [index, char] of text.split("").entries()) {
    if (char === "(") depth++;
    else if (char === ")") depth--;
    else if (depth === 0 && char === separator) return index;
  }
  return -1;
}

export function splitTopLevel(text: string, separator: RegExp): Array<string> {
  const parts: Array<string> = [];
  let depth = 0;
  let start = 0;
  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    if (char === "(") depth++;
    else if (char === ")") depth--;
    else if (depth === 0 && separator.test(char ?? "")) {
      if (index > start) parts.push(text.slice(start, index));
      start = index + 1;
    }
  }
  if (start < text.length) parts.push(text.slice(start));
  return parts;
}

const MATH = /(?:^|[^\w-])(calc|min|max|clamp)\(/;

export function reduceMath(value: string, fontSize: number): string {
  let result = value;
  for (
    let match = MATH.exec(result);
    match != null;
    match = MATH.exec(result)
  ) {
    const open = match.index + match[0].length - 1;
    const close = closingParen(result, open);
    const start = open - (match[1]?.length ?? 0);
    const quantity = quantityOf(result.slice(start, close + 1), fontSize);
    result =
      result.slice(0, start) + format(quantity) + result.slice(close + 1);
  }
  return result;
}

export function format(quantity: Quantity): string {
  if (!Number.isFinite(quantity.value)) return `9999${quantity.unit}`;
  return `${round(quantity.value)}${quantity.unit}`;
}

function round(value: number): number {
  return Number(value.toFixed(4));
}

const MATH_WORDS = new Set(["calc", "min", "max", "clamp"]);

export function quantityOf(text: string, fontSize: number): Quantity {
  const tokens = tokenize(text);
  let position = 0;
  const peek = (): Token | undefined => tokens[position];
  const next = (): Token => {
    const token = tokens[position];
    if (token == null) throw new Unsupported(`"${text}" ends too early`);
    position++;
    return token;
  };

  const expectClose = (): void => {
    const token = next();
    if (token.text !== ")") throw new Unsupported(`can't read ")"`);
  };

  const factor = (): Quantity => {
    const token = next();
    if (token.kind === "op" && token.text === "-") {
      const inner = factor();
      return { value: -inner.value, unit: inner.unit };
    }
    if (token.kind === "op" && token.text === "+") return factor();
    if (token.kind === "op" && token.text === "(") {
      const inner = sum();
      expectClose();
      return inner;
    }
    if (token.kind === "number")
      return unitOf(token.value, token.unit, fontSize);
    if (token.kind === "word" && token.text === "infinity")
      return { value: Infinity, unit: "" };
    if (
      token.kind === "word" &&
      MATH_WORDS.has(token.text) &&
      peek()?.text === "("
    ) {
      next();
      const args = [sum()];
      while (peek()?.text === ",") {
        next();
        args.push(sum());
      }
      expectClose();
      return combine(token.text, args);
    }
    throw new Unsupported(`can't read "${text}"`);
  };

  const term = (): Quantity => {
    let left = factor();
    while (peek()?.text === "*" || peek()?.text === "/") {
      const operator = next().text;
      const right = factor();
      left = operator === "*" ? multiply(left, right) : divide(left, right);
    }
    return left;
  };

  function sum(): Quantity {
    let left = term();
    while (peek()?.text === "+" || peek()?.text === "-") {
      const operator = next().text;
      const right = term();
      left = add(left, right, operator === "-" ? -1 : 1);
    }
    return left;
  }

  const checkEnd = (result: Quantity): Quantity => {
    if (position !== tokens.length)
      throw new Unsupported(`can't read "${text}"`);
    return result;
  };
  return checkEnd(sum());
}

type Token =
  | { kind: "number"; text: string; value: number; unit: string }
  | { kind: "word"; text: string }
  | { kind: "op"; text: string };

function tokenize(text: string): Array<Token> {
  const tokens: Array<Token> = [];
  const pattern =
    /\s*(?:(\d*\.?\d+(?:e[+-]?\d+)?)([a-z]*%?)|([a-z][\w-]*)|([-+*/(),]))/iy;
  let index = 0;
  while (index < text.length) {
    if (/\s/.test(text[index] ?? "")) {
      index++;
      continue;
    }
    pattern.lastIndex = index;
    const match = pattern.exec(text);
    if (match == null) throw new Unsupported(`can't read "${text}"`);
    index = pattern.lastIndex;
    if (match[1] != null)
      tokens.push({
        kind: "number",
        text: match[0].trim(),
        value: Number(match[1]),
        unit: match[2] ?? "",
      });
    else if (match[3] != null) tokens.push({ kind: "word", text: match[3] });
    else tokens.push({ kind: "op", text: match[4] ?? "" });
  }
  return tokens;
}

function unitOf(value: number, unit: string, fontSize: number): Quantity {
  switch (unit) {
    case "": {
      return { value, unit: "" };
    }
    case "px": {
      return { value, unit: "px" };
    }
    case "rem": {
      return { value: value * REM, unit: "px" };
    }
    case "em": {
      return { value: value * fontSize, unit: "px" };
    }
    case "%": {
      return { value, unit: "%" };
    }
    case "deg": {
      return { value, unit: "deg" };
    }
    default: {
      throw new Unsupported(`the ${unit} unit has no native equivalent`);
    }
  }
}

function add(left: Quantity, right: Quantity, sign: 1 | -1): Quantity {
  if (left.unit !== right.unit && left.unit !== "" && right.unit !== "")
    throw new Unsupported(`can't add ${left.unit} and ${right.unit}`);
  return {
    value: left.value + sign * right.value,
    unit: left.unit === "" ? right.unit : left.unit,
  };
}

function multiply(left: Quantity, right: Quantity): Quantity {
  if (left.unit !== "" && right.unit !== "")
    throw new Unsupported("can't multiply two lengths");
  return {
    value: left.value * right.value,
    unit: left.unit === "" ? right.unit : left.unit,
  };
}

function divide(left: Quantity, right: Quantity): Quantity {
  if (right.unit !== "") throw new Unsupported("can't divide by a length");
  return { value: left.value / right.value, unit: left.unit };
}

function combine(name: string, args: Array<Quantity>): Quantity {
  const unit = args[0]?.unit ?? "";
  if (args.some((arg) => arg.unit !== unit))
    throw new Unsupported(`${name}() mixes units`);
  const values = args.map((arg) => arg.value);
  if (name === "min") return { value: Math.min(...values), unit };
  if (name === "max") return { value: Math.max(...values), unit };
  if (name === "clamp" && values.length === 3) {
    const [low = 0, middle = 0, high = 0] = values;
    return { value: Math.min(Math.max(middle, low), high), unit };
  }
  if (name === "calc" && args.length === 1)
    return args[0] ?? { value: 0, unit: "" };
  throw new Unsupported(`${name}() has the wrong number of arguments`);
}

export function pixels(text: string, fontSize: number): number {
  const quantity = quantityOf(text, fontSize);
  if (quantity.unit !== "px" && quantity.unit !== "")
    throw new Unsupported(`"${text}" isn't a length`);
  return round(quantity.value);
}

export function numberOf(text: string): number {
  const trimmed = text.trim();
  if (trimmed.endsWith("%")) return round(Number(trimmed.slice(0, -1)) / 100);
  const value = Number(trimmed);
  if (Number.isNaN(value)) throw new Unsupported(`"${text}" isn't a number`);
  return round(value);
}

export function parseColor(text: string): Rgba | "currentcolor" {
  const value = text.trim();
  const lower = value.toLowerCase();
  if (lower === "transparent") return { r: 0, g: 0, b: 0, a: 0 };
  if (lower === "currentcolor") return "currentcolor";
  if (lower === "white") return { r: 1, g: 1, b: 1, a: 1 };
  if (lower === "black") return { r: 0, g: 0, b: 0, a: 1 };
  if (value.startsWith("#")) return hex(value.slice(1));
  const call = /^([a-z-]+)\((.*)\)$/i.exec(value);
  if (call == null)
    throw new Unsupported(`the color "${text}" isn't supported`);
  const [, name = "", inner = ""] = call;
  switch (name.toLowerCase()) {
    case "rgb":
    case "rgba": {
      return rgb(inner);
    }
    case "oklch": {
      return oklch(inner);
    }
    case "oklab": {
      return oklab(inner);
    }
    case "color-mix": {
      return colorMix(inner);
    }
    default: {
      throw new Unsupported(`the color function ${name}() isn't supported`);
    }
  }
}

function hex(digits: string): Rgba {
  const full =
    digits.length <= 4
      ? [...digits].map((char) => char + char).join("")
      : digits;
  if (!/^[0-9a-f]{6}(?:[0-9a-f]{2})?$/i.test(full))
    throw new Unsupported(`#${digits} isn't a color`);
  const channel = (start: number): number =>
    Number.parseInt(full.slice(start, start + 2), 16) / 255;
  return {
    r: channel(0),
    g: channel(2),
    b: channel(4),
    a: full.length === 8 ? channel(6) : 1,
  };
}

function components(inner: string): {
  values: Array<string>;
  alpha: string | undefined;
} {
  const [main = "", alpha] = inner.split("/").map((part) => part.trim());
  return { values: main.split(/[\s,]+/).filter((part) => part !== ""), alpha };
}

function rgb(inner: string): Rgba {
  const { values, alpha } = components(inner);
  const channel = (text: string | undefined): number => {
    if (text == null) throw new Unsupported(`rgb(${inner}) is incomplete`);
    return text.endsWith("%")
      ? Number(text.slice(0, -1)) / 100
      : Number(text) / 255;
  };
  return {
    r: channel(values[0]),
    g: channel(values[1]),
    b: channel(values[2]),
    a:
      alpha == null
        ? values[3] == null
          ? 1
          : numberOf(values[3])
        : numberOf(alpha),
  };
}

function oklch(inner: string): Rgba {
  const { values, alpha } = components(inner);
  const [lightness = "0", chroma = "0", hue = "0"] = values;
  const c = scaled(chroma, 0.4);
  const h =
    hue === "none" ? 0 : (Number(hue.replace(/deg$/, "")) * Math.PI) / 180;
  return oklabToRgba(
    scaled(lightness, 1),
    c * Math.cos(h),
    c * Math.sin(h),
    alpha == null ? 1 : numberOf(alpha),
  );
}

function oklab(inner: string): Rgba {
  const { values, alpha } = components(inner);
  const [lightness = "0", a = "0", b = "0"] = values;
  return oklabToRgba(
    scaled(lightness, 1),
    scaled(a, 0.4),
    scaled(b, 0.4),
    alpha == null ? 1 : numberOf(alpha),
  );
}

function scaled(text: string, percentBase: number): number {
  return text.endsWith("%")
    ? (Number(text.slice(0, -1)) / 100) * percentBase
    : Number(text);
}

function colorMix(inner: string): Rgba {
  const parts = splitTopLevel(inner, /,/).map((part) => part.trim());
  const space = /^in\s+(\S+)$/.exec(parts[0] ?? "")?.[1];
  if (space !== "oklab" && space !== "srgb")
    throw new Unsupported(`color-mix(in ${space}) isn't supported`);
  const [first, second] = parts.slice(1).map((part) => weighted(part));
  if (first == null || second == null)
    throw new Unsupported(`color-mix(${inner}) needs two colors`);
  const p1 = first.weight ?? (second.weight == null ? 0.5 : 1 - second.weight);
  const p2 = second.weight ?? 1 - p1;
  const total = p1 + p2;
  const w1 = p1 / total;
  const w2 = p2 / total;
  const a = first.color.a * w1 + second.color.a * w2;
  if (a === 0) return { r: 0, g: 0, b: 0, a: 0 };
  const left =
    space === "oklab"
      ? toOklab(first.color)
      : [first.color.r, first.color.g, first.color.b];
  const right =
    space === "oklab"
      ? toOklab(second.color)
      : [second.color.r, second.color.g, second.color.b];
  const mixed = left.map((value, index) => {
    const other = right[index] ?? 0;
    return (value * first.color.a * w1 + other * second.color.a * w2) / a;
  });
  const [x = 0, y = 0, z = 0] = mixed;
  const rgba = space === "oklab" ? fromOklab(x, y, z) : { r: x, g: y, b: z };
  return { ...rgba, a };
}

function weighted(text: string): { color: Rgba; weight: number | undefined } {
  const match = /^(.*\S)\s+(-?[\d.]+%)$/.exec(text.trim());
  const colorText = match?.[1] ?? text;
  const weight =
    match?.[2] == null ? undefined : Number(match[2].slice(0, -1)) / 100;
  const parsed = parseColor(colorText);
  if (parsed === "currentcolor")
    throw new Unsupported("currentcolor inside color-mix() isn't supported");
  return { color: parsed, weight };
}

function oklabToRgba(l: number, a: number, b: number, alpha: number): Rgba {
  const lp = l + 0.3963377774 * a + 0.2158037573 * b;
  const mp = l - 0.1055613458 * a - 0.0638541728 * b;
  const sp = l - 0.0894841775 * a - 1.291485548 * b;
  const L = lp ** 3;
  const M = mp ** 3;
  const S = sp ** 3;
  const r = 4.0767416621 * L - 3.3077115913 * M + 0.2309699292 * S;
  const g = -1.2684380046 * L + 2.6097574011 * M - 0.3413193965 * S;
  const bl = -0.0041960863 * L - 0.7034186147 * M + 1.707614701 * S;
  return {
    r: clamp(gamma(r)),
    g: clamp(gamma(g)),
    b: clamp(gamma(bl)),
    a: alpha,
  };
}

function fromOklab(
  l: number,
  a: number,
  b: number,
): { r: number; g: number; b: number } {
  const rgba = oklabToRgba(l, a, b, 1);
  return { r: rgba.r, g: rgba.g, b: rgba.b };
}

function toOklab(color: Rgba): Array<number> {
  const r = linear(color.r);
  const g = linear(color.g);
  const b = linear(color.b);
  const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return [
    0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s,
  ];
}

function linear(channel: number): number {
  return channel <= 0.04045
    ? channel / 12.92
    : ((channel + 0.055) / 1.055) ** 2.4;
}

function gamma(channel: number): number {
  return channel <= 0.0031308
    ? 12.92 * channel
    : 1.055 * channel ** (1 / 2.4) - 0.055;
}

function clamp(channel: number): number {
  return Math.min(1, Math.max(0, channel));
}

export function toHex(color: Rgba): `#${string}` {
  const byte = (channel: number): string =>
    Math.round(clamp(channel) * 255)
      .toString(16)
      .padStart(2, "0");
  const alpha = Math.round(clamp(color.a) * 255);
  const suffix = alpha === 255 ? "" : alpha.toString(16).padStart(2, "0");
  return `#${byte(color.r)}${byte(color.g)}${byte(color.b)}${suffix}`;
}
