export type Attributes = Record<string, unknown>;
export type Rule = {
  when?: Array<string>;
  only?: Array<string>;
  important?: boolean;
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
  reduceMotion: boolean;
  rtl: boolean;
  disabled: boolean;
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

function isSatisfied(condition: string, state: State): boolean {
  if (condition === "dark") return state.dark;
  if (condition === "reduce-motion") return state.reduceMotion;
  if (condition === "motion") return !state.reduceMotion;
  if (condition === "rtl") return state.rtl;
  if (condition === "ltr") return !state.rtl;
  if (condition === "disabled") return state.disabled;
  const threshold = Number(condition.slice(2));
  return condition.startsWith(">=")
    ? state.width >= threshold
    : state.width < threshold;
}

function isPlain(value: unknown): value is Attributes {
  return typeof value === "object" && value != null && !Array.isArray(value);
}

function deepMerge(base: Attributes, extra: Attributes): Attributes {
  const merged: Attributes = { ...base };
  for (const [key, value] of Object.entries(extra)) {
    const current = merged[key];
    merged[key] =
      isPlain(current) && isPlain(value) ? deepMerge(current, value) : value;
  }
  return merged;
}

function apply(target: Attributes, attrs: Attributes): void {
  for (const [key, value] of Object.entries(attrs)) {
    if (value === null) Reflect.deleteProperty(target, key);
    else
      target[key] =
        isPlain(value) && isPlain(target[key])
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

function finish(output: Attributes): Attributes {
  const {
    $borderWidth,
    $borderColor,
    $shadowColor,
    $stop,
    $direction,
    $duration,
    ...rest
  } = output;
  const result: Attributes = rest;
  if (typeof $borderWidth === "number") {
    const border: Attributes = { width: $borderWidth };
    if (typeof $borderColor === "string") border.color = $borderColor;
    result.border = $borderWidth === 0 ? null : border;
  }
  if (typeof $shadowColor === "string" && isPlain(result.shadow))
    result.shadow = { ...result.shadow, color: $shadowColor };
  if (isPlain($stop) && isPlain($direction)) {
    const gradient = gradientOf($stop, $direction);
    if (gradient != null) result.background = gradient;
  }
  if (typeof $duration === "number") animate(result, $duration);
  return result;
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
  const active: Array<Rule> = [];
  const unmatched: Array<string> = [];
  const misplaced: Array<string> = [];
  let isReactive = false;
  for (const token of value.split(/\s+/)) {
    if (token === "") continue;
    const rules = next.tokens[token];
    if (rules == null) {
      unmatched.push(token);
      continue;
    }
    const applicable = rules.filter(
      (rule) => rule.only == null || rule.only.includes(tag),
    );
    if (applicable.length === 0) misplaced.push(token);
    isReactive ||= applicable.some((rule) => rule.when != null);
    active.push(
      ...applicable.filter(
        (rule) =>
          rule.when == null ||
          rule.when.every((condition) => isSatisfied(condition, state)),
      ),
    );
  }
  active.sort(
    (a, b) =>
      Number(a.important ?? false) - Number(b.important ?? false) ||
      a.order - b.order,
  );
  const output: Attributes = {};
  for (const rule of active) apply(output, rule.attrs);
  return { attrs: finish(output), reactive: isReactive, unmatched, misplaced };
}

export function resolveWith(
  tag: string,
  value: string,
  state: State,
): Resolution {
  return resolveClasses(registry.table, tag, value, state);
}
