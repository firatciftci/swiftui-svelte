export type Attributes = Record<string, unknown>;
export type Operator =
  | "+"
  | "-"
  | "*"
  | "/"
  | "min"
  | "max"
  | "clamp"
  | "round"
  | "roundToNearestPixel"
  | "fontScale"
  | "pixelRatio"
  | "hairlineWidth"
  | "viewportWidth"
  | "viewportHeight"
  | "insetTop"
  | "insetRight"
  | "insetBottom"
  | "insetLeft";
export type Call = { op: Operator; args: Array<Expression> };
export type Expression = number | Call;
export type Rule = {
  when?: Array<string>;
  only?: Array<string>;
  important?: boolean;
  dynamic?: boolean;
  order: number;
  attrs: Attributes;
};
export type ClassTable = {
  tokens: Record<string, Array<Rule>>;
  statics: Record<string, Attributes>;
  breakpoints: Array<number>;
};
export type State = {
  dark: boolean;
  width: number;
  height: number;
  reduceMotion: boolean;
  rtl: boolean;
  disabled: boolean;
  platform: string;
  idiom: string;
  increaseContrast: boolean;
  insets: Record<"top" | "right" | "bottom" | "left", number>;
  pixelRatio: number;
  fontScale: number;
  containers: Record<string, number>;
};
export type Resolution = {
  attrs: Attributes;
  reactive: boolean;
  unmatched: Array<string>;
  misplaced: Array<string>;
};

const EMPTY: ClassTable = { tokens: {}, statics: {}, breakpoints: [] };

const registry: { table: ClassTable } = { table: EMPTY };

export function registerClasses(next: ClassTable): void {
  registry.table = next;
}

export function classKey(tag: string, value: string): string {
  return `${tag} ${value}`;
}

const RUNTIME_OPERATORS: ReadonlySet<Operator> = new Set([
  "roundToNearestPixel",
  "fontScale",
  "pixelRatio",
  "hairlineWidth",
  "viewportWidth",
  "viewportHeight",
  "insetTop",
  "insetRight",
  "insetBottom",
  "insetLeft",
]);

function isExpression(value: unknown): value is Call {
  return (
    isPlain(value) && typeof value.op === "string" && Array.isArray(value.args)
  );
}

function isDynamic(expression: Expression): boolean {
  if (typeof expression === "number") return false;
  return (
    RUNTIME_OPERATORS.has(expression.op) ||
    expression.args.some((arg) => isDynamic(arg))
  );
}

export function hasDynamic(value: unknown): boolean {
  if (isExpression(value)) return isDynamic(value);
  if (Array.isArray(value)) return value.some((item) => hasDynamic(item));
  return (
    isPlain(value) && Object.values(value).some((item) => hasDynamic(item))
  );
}

export function arithmetic(op: Operator, values: Array<number>): number {
  const [first = 0, second = 0, third = 0] = values;
  switch (op) {
    case "+": {
      return first + second;
    }
    case "-": {
      return first - second;
    }
    case "*": {
      return first * second;
    }
    case "/": {
      return first / second;
    }
    case "min": {
      return Math.min(...values);
    }
    case "max": {
      return Math.max(...values);
    }
    case "clamp": {
      return Math.max(first, Math.min(second, third));
    }
    case "round": {
      return second !== 0 && values.length > 1
        ? Math.round(first / second) * second
        : Math.round(first);
    }
    default: {
      throw new Error(`${op} isn't arithmetic`);
    }
  }
}

const NAMED: Record<string, (state: State) => boolean> = {
  dark: (state) => state.dark,
  "reduce-motion": (state) => state.reduceMotion,
  motion: (state) => !state.reduceMotion,
  rtl: (state) => state.rtl,
  ltr: (state) => !state.rtl,
  disabled: (state) => state.disabled,
  native: () => true,
  web: () => false,
  "contrast:more": (state) => state.increaseContrast,
  "contrast:less": () => false,
  "orientation:landscape": (state) => state.width > state.height,
  "orientation:portrait": (state) => state.width <= state.height,
};

function isContainerSatisfied(condition: string, state: State): boolean {
  const [, name = "", test = ""] = condition.split(":", 3);
  const width = state.containers[name];
  if (width == null) return false;
  if (test.startsWith(">=")) return width >= Number(test.slice(2));
  return width < Number(test.slice(1));
}

function isSatisfied(condition: string, state: State): boolean {
  if (condition.startsWith("container:"))
    return isContainerSatisfied(condition, state);
  if (condition.startsWith("platform:"))
    return state.platform === condition.slice("platform:".length);
  if (condition.startsWith("idiom:"))
    return state.idiom === condition.slice("idiom:".length);
  if (condition.startsWith(">="))
    return state.width >= Number(condition.slice(2));
  if (condition.startsWith("<"))
    return state.width < Number(condition.slice(1));
  return NAMED[condition]?.(state) ?? false;
}

function evaluate(expression: Expression, state: State): number {
  if (typeof expression === "number") return expression;
  const values = expression.args.map((arg) => evaluate(arg, state));
  const [first = 0] = values;
  switch (expression.op) {
    case "fontScale": {
      return state.fontScale;
    }
    case "pixelRatio": {
      return state.pixelRatio;
    }
    case "hairlineWidth": {
      return 1 / state.pixelRatio;
    }
    case "viewportWidth": {
      return state.width;
    }
    case "viewportHeight": {
      return state.height;
    }
    case "insetTop": {
      return state.insets.top;
    }
    case "insetRight": {
      return state.insets.right;
    }
    case "insetBottom": {
      return state.insets.bottom;
    }
    case "insetLeft": {
      return state.insets.left;
    }
    case "roundToNearestPixel": {
      return Math.round(first * state.pixelRatio) / state.pixelRatio;
    }
    default: {
      return arithmetic(expression.op, values);
    }
  }
}

function isPlain(value: unknown): value is Attributes {
  return typeof value === "object" && value != null && !Array.isArray(value);
}

function settle(value: unknown, state: State): unknown {
  if (isExpression(value)) return evaluate(value, state);
  if (Array.isArray(value)) return value.map((item) => settle(item, state));
  if (isPlain(value))
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, settle(item, state)]),
    );
  return value;
}

function settleAll(attrs: Attributes, state: State): Attributes {
  return Object.fromEntries(
    Object.entries(attrs).map(([key, value]) => [key, settle(value, state)]),
  );
}

function isMergeable(value: unknown): value is Attributes {
  return isPlain(value) && !isExpression(value);
}

function deepMerge(base: Attributes, extra: Attributes): Attributes {
  const merged: Attributes = { ...base };
  for (const [key, value] of Object.entries(extra)) {
    const current = merged[key];
    merged[key] =
      isMergeable(current) && isMergeable(value)
        ? deepMerge(current, value)
        : value;
  }
  return merged;
}

function apply(target: Attributes, attrs: Attributes): void {
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null) Reflect.deleteProperty(target, key);
    else
      target[key] =
        isMergeable(value) && isMergeable(target[key])
          ? deepMerge(target[key], value)
          : value;
  }
}

const STOPS = ["from", "via", "to"] as const;
const DEFAULT_LOCATIONS: Record<string, number> = { from: 0, via: 0.5, to: 1 };

function gradientOf(
  stops: Attributes,
  direction: Attributes,
): Attributes | null {
  const linear: Array<{ color: string; location: number }> = [];
  for (const role of STOPS) {
    const stop = stops[role];
    if (!isPlain(stop) || typeof stop.color !== "string") continue;
    const location =
      typeof stop.location === "number"
        ? stop.location
        : (DEFAULT_LOCATIONS[role] ?? 0);
    linear.push({ color: stop.color, location });
  }
  return linear.length > 0
    ? { linear, start: direction.start, end: direction.end }
    : null;
}

function animate(result: Attributes, duration: number): void {
  for (const state of ["pressed", "hovered"] as const) {
    const feedback = result[state];
    if (isPlain(feedback))
      result[state] = { ...feedback, animation: { duration } };
  }
}

function borderOf(widths: Attributes, color: unknown): Attributes | null {
  const isDrawn = Object.values(widths).some((width) => width !== 0);
  if (!isDrawn) return null;
  const border: Attributes = { width: widths };
  if (typeof color === "string") border.color = color;
  return border;
}

function finish(output: Attributes): Attributes {
  const {
    $borderWidth,
    $borderColor,
    $ringWidth,
    $ringColor,
    $shadowColor,
    $stop,
    $direction,
    $duration,
    ...rest
  } = output;
  const result: Attributes = rest;
  if (isPlain($borderWidth))
    result.border = borderOf($borderWidth, $borderColor);
  if (typeof $ringWidth === "number" && $ringWidth > 0)
    result.ring =
      typeof $ringColor === "string"
        ? { width: $ringWidth, color: $ringColor }
        : { width: $ringWidth };
  if (typeof $shadowColor === "string" && isPlain(result.shadow))
    result.shadow = { ...result.shadow, color: $shadowColor };
  if (isPlain($stop) && isPlain($direction)) {
    const gradient = gradientOf($stop, $direction);
    if (gradient != null) result.background = gradient;
  }
  if (typeof $duration === "number") animate(result, $duration);
  return result;
}

type Parsed = Omit<Resolution, "attrs"> & {
  rules: Array<Rule>;
  outputs: Map<string, Attributes>;
};

const parsedTables = new WeakMap<ClassTable, Map<string, Parsed>>();

function parse(next: ClassTable, tag: string, value: string): Parsed {
  let cache = parsedTables.get(next);
  if (cache == null || cache.size > 1000) {
    cache = new Map();
    parsedTables.set(next, cache);
  }
  const key = classKey(tag, value);
  const cached = cache.get(key);
  if (cached != null) return cached;
  const parsed: Parsed = {
    rules: [],
    reactive: false,
    unmatched: [],
    misplaced: [],
    outputs: new Map(),
  };
  for (const token of value.split(/\s+/)) {
    if (token === "") continue;
    const rules = next.tokens[token];
    if (rules == null) {
      parsed.unmatched.push(token);
      continue;
    }
    const applicable = rules.filter(
      (rule) => rule.only == null || rule.only.includes(tag),
    );
    if (applicable.length === 0) parsed.misplaced.push(token);
    parsed.reactive ||= applicable.some(
      (rule) => rule.when != null || rule.dynamic === true,
    );
    parsed.rules.push(...applicable);
  }
  cache.set(key, parsed);
  return parsed;
}

export function resolveClasses(
  next: ClassTable,
  tag: string,
  value: string,
  state: State,
): Resolution {
  const statics = next.statics[classKey(tag, value)];
  if (statics != null)
    return { attrs: statics, reactive: false, unmatched: [], misplaced: [] };
  const parsed = parse(next, tag, value);
  const { reactive, unmatched, misplaced, outputs } = parsed;
  const active: Array<Rule> = [];
  let signature = "";
  for (const rule of parsed.rules) {
    const isActive =
      rule.when == null ||
      rule.when.every((condition) => isSatisfied(condition, state));
    signature += isActive ? "1" : "0";
    if (isActive) active.push(rule);
  }
  const isDynamic = active.some((rule) => rule.dynamic === true);
  const known = isDynamic ? undefined : outputs.get(signature);
  if (known != null) return { attrs: known, reactive, unmatched, misplaced };
  active.sort(
    (a, b) =>
      Number(a.important ?? false) - Number(b.important ?? false) ||
      a.order - b.order,
  );
  const output: Attributes = {};
  for (const rule of active) apply(output, rule.attrs);
  const attrs = finish(output);
  if (isDynamic)
    return { attrs: settleAll(attrs, state), reactive, unmatched, misplaced };
  outputs.set(signature, attrs);
  return { attrs, reactive, unmatched, misplaced };
}

const composed: Readonly<Record<string, string>> = {
  $borderWidth: "border",
  $borderColor: "border",
  $ringWidth: "ring",
  $ringColor: "ring",
  $shadowColor: "shadow",
  $stop: "background",
  $direction: "background",
};

export function attributesOf(tag: string, value: string): Set<string> {
  const names = new Set<string>();
  for (const rule of parse(registry.table, tag, value).rules) {
    for (const key of Object.keys(rule.attrs)) {
      const target = key.startsWith("$") ? composed[key] : key;
      if (target != null) names.add(target);
    }
  }
  return names;
}

export function resolveWith(
  tag: string,
  value: string,
  state: State,
): Resolution {
  return resolveClasses(registry.table, tag, value, state);
}
