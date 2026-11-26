import type { AtRule, Container, Root, Rule } from "postcss";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import postcss from "postcss";
import { compile } from "tailwindcss";
import type {
  Attributes,
  ClassTable,
  State,
  Rule as TableRule,
} from "./runtime.ts";
import type { Declaration, Patch } from "./utilities.ts";
import type { Lookup } from "./values.ts";
import { classKey, hasDynamic, resolveClasses } from "./runtime.ts";
import { mapCandidate } from "./utilities.ts";
import { fixedPixels } from "./values.ts";

export type BuildOptions = {
  root: string;
  css: string;
  sources: Array<string>;
  fonts: Record<string, string>;
  ignore?: Array<string>;
};

export type BuildResult = {
  table: ClassTable;
  warnings: Array<string>;
  files: Array<string>;
};

type Context = { tag?: string; text: string; file: string };
type Entry = { declaration: Declaration; wraps: Array<AtRule> };
type Group = {
  candidate: string;
  when: Array<string>;
  target?: "hovered" | "pressed";
  order: number;
  important: boolean;
  declarations: Array<Declaration>;
  problems: Set<string>;
};

const EXTENSIONS = new Set([".svelte", ".ts", ".js", ".tsx", ".jsx", ".html"]);
const STRING = /(["'`])((?:\\.|(?!\1)[^\\\n])*)\1/g;
const STATIC_CLASS = /<([a-z][\w-]*)\b[^>]*?\sclass=(?:"([^"]*)"|'([^']*)')/g;
const EXPRESSION_CLASS = /\bclass=\{([^{}]*)\}/g;
const CLASS_CALL = /\b(?:cn|clsx|cx|twMerge|twJoin|tv|cva)\(([^()]*)\)/g;
const CLASS_NAME = /\.((?:\\[0-9a-f]{1,6}\s?|\\[^0-9a-f\n]|[\w-])+)/gi;
const ROOT_SELECTOR = /^:(?:root|host)(?:\s*,\s*:(?:root|host))*$/;
const DEFAULTS: Record<string, string> = {
  "--tw-ring-offset-width": "0px",
  "--tw-ring-offset-shadow": "0 0 #0000",
  "--tw-ring-shadow": "0 0 #0000",
  "--tw-inset-shadow": "0 0 #0000",
  "--tw-inset-ring-shadow": "0 0 #0000",
  "--tw-shadow": "0 0 #0000",
  "--tw-gradient-position": "to bottom",
};
const PSEUDO_ALLOWED = new Set([
  "where",
  "is",
  "not",
  "hover",
  "active",
  "disabled",
]);
const NEUTRAL: State = {
  dark: false,
  width: 0,
  height: 0,
  reduceMotion: false,
  rtl: false,
  disabled: false,
  platform: "unknown",
  idiom: "phone",
  increaseContrast: false,
  insets: { top: 0, right: 0, bottom: 0, left: 0 },
  pixelRatio: 1,
  fontScale: 1,
  containers: {},
};

function sourceFiles(directories: Array<string>): Array<string> {
  const found: Array<string> = [];
  const walk = (directory: string): void => {
    for (const entry of readdirSync(directory)) {
      if (entry === "node_modules" || entry.startsWith(".")) continue;
      const full = path.join(directory, entry);
      if (statSync(full).isDirectory()) walk(full);
      else if (EXTENSIONS.has(path.extname(entry))) found.push(full);
    }
  };
  for (const directory of directories) walk(directory);
  return found;
}

function unescapeName(name: string): string {
  return name.replaceAll(
    /\\([0-9a-f]{1,6})\s?|\\(.)/gi,
    (_, hex: string | undefined, char: string | undefined = "") =>
      hex != null ? String.fromCodePoint(Number.parseInt(hex, 16)) : char,
  );
}

function stringsIn(text: string): Array<string> {
  return Array.from(text.matchAll(STRING), (match) => match[2] ?? "");
}

function valuesOf(text: string, pattern: RegExp): Array<string> {
  const values: Array<string> = [];
  for (const match of text.matchAll(pattern))
    values.push(...stringsIn(match[1] ?? ""));
  return values;
}

function contextsOf(
  file: string,
  text: string,
): { contexts: Array<Context>; words: Array<string> } {
  const contexts: Array<Context> = Array.from(
    text.matchAll(STATIC_CLASS),
    (match) => ({ tag: match[1], text: match[2] ?? match[3] ?? "", file }),
  );
  for (const pattern of [EXPRESSION_CLASS, CLASS_CALL])
    contexts.push(
      ...valuesOf(text, pattern).map((value) => ({ text: value, file })),
    );
  const words = [
    ...stringsIn(text),
    ...contexts.map((context) => context.text),
  ].flatMap((value) => value.split(/\s+/));
  return { contexts, words: words.filter((word) => word !== "") };
}

function stylesheetLoader(
  root: string,
): (
  id: string,
  from: string,
) => Promise<{ path: string; base: string; content: string }> {
  const requireFrom = createRequire(path.join(root, "package.json"));
  return async (id, from) => {
    const resolved =
      id.startsWith(".") || id.startsWith("/")
        ? path.resolve(from, id)
        : stylesheetPath(requireFrom, id);
    return {
      path: resolved,
      base: path.dirname(resolved),
      content: readFileSync(resolved, "utf8"),
    };
  };
}

function stylesheetPath(requireFrom: NodeJS.Require, id: string): string {
  if (id === "tailwindcss") return requireFrom.resolve("tailwindcss/index.css");
  try {
    const found = requireFrom.resolve(id);
    if (found.endsWith(".css")) return found;
  } catch {
    return requireFrom.resolve(`${id}/index.css`);
  }
  return requireFrom.resolve(`${id}/index.css`);
}

function environmentOf(content: string): { when: string } | null {
  const contrast = /^prefers-contrast:\s*(more|less)$/.exec(content);
  if (contrast != null) return { when: `contrast:${contrast[1]}` };
  const orientation = /^orientation:\s*(portrait|landscape)$/.exec(content);
  if (orientation != null) return { when: `orientation:${orientation[1]}` };
  if (/^(?:ios|android)$/.test(content)) return { when: `platform:${content}` };
  if (content === "native") return { when: "native" };
  if (/^display-mode:\s*tv$/.test(content)) return { when: "idiom:tv" };
  return null;
}

function conditionOf(
  content: string,
  isNegated: boolean,
): { when?: string; threshold?: number } | null {
  if (/^(?:hover|any-hover|pointer|any-pointer)\b/.test(content)) return {};
  const motion = /^prefers-reduced-motion:\s*(reduce|no-preference)$/.exec(
    content,
  );
  if (motion != null)
    return {
      when: (motion[1] === "reduce") !== isNegated ? "reduce-motion" : "motion",
    };
  if (!isNegated && /^prefers-color-scheme:\s*dark$/.test(content))
    return { when: "dark" };
  if (!isNegated) {
    const environment = environmentOf(content);
    if (environment != null) return environment;
  }
  const minimum = /^(?:width\s*>=|min-width:)\s*([\d.]+(?:rem|px|em))$/.exec(
    content,
  );
  const maximum = /^(?:width\s*<|max-width:)\s*([\d.]+(?:rem|px|em))$/.exec(
    content,
  );
  const limit = minimum?.[1] ?? maximum?.[1];
  if (limit == null) return null;
  const threshold = fixedPixels(limit, 16);
  const isAtLeast = (minimum != null) !== isNegated;
  return { when: `${isAtLeast ? ">=" : "<"}${threshold}`, threshold };
}

function wrapConditions(wrap: AtRule): {
  when: Array<string>;
  thresholds: Array<number>;
  problem?: string;
} {
  let params = wrap.params.trim();
  const isNegated = params.startsWith("not all and ");
  if (isNegated) params = params.slice("not all and ".length);
  const when: Array<string> = [];
  const thresholds: Array<number> = [];
  for (const term of params.split(/\s+and\s+/)) {
    const content = term
      .trim()
      .replace(/^\((.*)\)$/, "$1")
      .trim();
    const condition = conditionOf(content, isNegated);
    if (condition == null)
      return {
        when,
        thresholds,
        problem: `the media query "${wrap.params.trim()}" isn't supported`,
      };
    if (condition.when != null) when.push(condition.when);
    if (condition.threshold != null) thresholds.push(condition.threshold);
  }
  return { when, thresholds };
}

function containerConditionOf(wrap: AtRule): string | null {
  const match =
    /^(?:([\w-]+)\s+)?\(\s*width\s*(>=|<)\s*([\d.]+(?:rem|px|em))\s*\)$/.exec(
      wrap.params.trim(),
    );
  if (match == null) return null;
  const [, name = "", operator = ">=", limit = "0"] = match;
  return `container:${name}:${operator}${fixedPixels(limit, 16)}`;
}

function wrapOf(wrap: AtRule): {
  when: Array<string>;
  thresholds: Array<number>;
  problem?: string;
} {
  const name = wrap.name.toLowerCase();
  if (name === "supports")
    return {
      when: wrap.params.trim() === "selector(div > div)" ? ["web"] : [],
      thresholds: [],
    };
  if (name === "layer") return { when: [], thresholds: [] };
  if (name === "container") {
    const condition = containerConditionOf(wrap);
    if (condition == null)
      return {
        when: [],
        thresholds: [],
        problem: `the container query "${wrap.params.trim()}" isn't supported`,
      };
    return { when: [condition], thresholds: [] };
  }
  if (name !== "media")
    return { when: [], thresholds: [], problem: `@${name} isn't supported` };
  return wrapConditions(wrap);
}

function conditionsOf(wraps: Array<AtRule>): {
  when: Array<string>;
  thresholds: Array<number>;
  problem?: string;
} {
  const when: Array<string> = [];
  const thresholds: Array<number> = [];
  for (const wrap of wraps) {
    const found = wrapOf(wrap);
    when.push(...found.when);
    thresholds.push(...found.thresholds);
    if (found.problem != null)
      return { when, thresholds, problem: found.problem };
  }
  return { when, thresholds };
}

function stateOf(selector: string): {
  when: Array<string>;
  target?: "hovered" | "pressed";
  problems: Array<string>;
  ignored: boolean;
} {
  if (
    selector.includes("-webkit-scrollbar") ||
    /:focus(?:-visible|-within)?\b/.test(selector)
  )
    return { when: [], problems: [], ignored: true };
  const when: Array<string> = [];
  const problems: Array<string> = [];
  let target: "hovered" | "pressed" | undefined;
  if (/:where\(\.group\)\s*:hover/.test(selector)) target = "hovered";
  else if (/:where\(\.group\)\s*:active/.test(selector)) target = "pressed";
  else if (/:hover\b/.test(selector)) target = "hovered";
  else if (/:active\b/.test(selector)) target = "pressed";
  if (/:disabled\b/.test(selector)) when.push("disabled");
  if (/\.dark\s+\*/.test(selector)) when.push("dark");
  const direction = /:dir\((rtl|ltr)\)|\[dir=["']?(rtl|ltr)["']?\]/.exec(
    selector,
  );
  const found = direction?.[1] ?? direction?.[2];
  if (found != null) when.push(found);
  const bare = selector
    .replaceAll(/\\./g, "")
    .replaceAll(/:dir\((?:rtl|ltr)\)|\[dir=["']?(?:rtl|ltr)["']?\]/g, "")
    .replaceAll(":not(:last-child)", "");
  if (bare.includes("::"))
    problems.push("pseudo-elements don't exist in SwiftUI");
  if (bare.includes("["))
    problems.push("attribute selectors don't exist in SwiftUI");
  for (const match of bare.matchAll(/:([a-z-]+)/g)) {
    const name = match[1] ?? "";
    if (!PSEUDO_ALLOWED.has(name))
      problems.push(`the :${name} state has no native equivalent`);
  }
  return { when, target, problems, ignored: false };
}

function declarationsOf(node: Container, wraps: Array<AtRule>): Array<Entry> {
  const entries: Array<Entry> = [];
  const children = node.nodes ?? [];
  for (const child of children) {
    if (child.type === "decl")
      entries.push({
        declaration: {
          property: child.prop,
          value: child.value,
          important: child.important ?? false,
        },
        wraps,
      });
    else if (child.type === "atrule")
      entries.push(...declarationsOf(child, [...wraps, child]));
  }
  return entries;
}

function eachRule(
  container: Container,
  wraps: Array<AtRule>,
  visit: (rule: Rule, wraps: Array<AtRule>) => void,
): void {
  const children = container.nodes ?? [];
  for (const child of children) {
    if (child.type === "rule") visit(child, wraps);
    else if (child.type === "atrule") eachRule(child, [...wraps, child], visit);
  }
}

function candidateOf(
  selector: string,
  candidates: ReadonlySet<string>,
): string | undefined {
  let best: string | undefined;
  for (const match of selector.matchAll(CLASS_NAME)) {
    const name = unescapeName(match[1] ?? "");
    if (candidates.has(name) && (best == null || name.length > best.length))
      best = name;
  }
  return best;
}

function initialValueOf(atRule: AtRule): string | undefined {
  const initial = (atRule.nodes ?? []).find(
    (node) => node.type === "decl" && node.prop === "initial-value",
  );
  return initial?.type === "decl" ? initial.value : undefined;
}

function addRootVariables(rule: Rule, globals: Map<string, string>): void {
  for (const declaration of rule.nodes) {
    if (declaration.type === "decl" && declaration.prop.startsWith("--"))
      globals.set(declaration.prop, declaration.value);
  }
}

function collectGlobals(root: Container): Map<string, string> {
  const globals = new Map<string, string>();
  const walkRoot = (container: Container): void => {
    const children = container.nodes ?? [];
    for (const child of children) {
      if (child.type === "rule" && ROOT_SELECTOR.test(child.selector.trim()))
        addRootVariables(child, globals);
      else if (child.type === "atrule") {
        if (child.name === "property") {
          const initial = initialValueOf(child);
          if (initial != null) globals.set(child.params.trim(), initial);
        }
        walkRoot(child);
      }
    }
  };
  walkRoot(root);
  return globals;
}

function lookupFor(
  globals: ReadonlyMap<string, string>,
): (name: string) => string | undefined {
  return (name) => globals.get(name) ?? DEFAULTS[name];
}

function tableRules(group: Group, patch: Patch, sink: Array<TableRule>): void {
  let attrs: Attributes = patch.attrs;
  if (group.target != null) {
    if (Object.keys(attrs).some((key) => key.startsWith("$"))) {
      group.problems.add(
        "borders, gradients, and shadow colors don't work in a hover or active state",
      );
      return;
    }
    if (Object.keys(attrs).length === 0) return;
    attrs = { [group.target]: attrs };
  }
  const rule: TableRule = { order: group.order, attrs };
  const when = [...group.when, ...(patch.when ?? [])];
  if (when.length > 0) rule.when = when;
  if (hasDynamic(attrs)) rule.dynamic = true;
  if (patch.only != null) rule.only = patch.only;
  if (group.important) rule.important = true;
  sink.push(rule);
}

type StateInfo = ReturnType<typeof stateOf>;

function scanSources(
  sourceList: Array<string>,
  root: string,
): { contexts: Array<Context>; universe: Set<string> } {
  const contexts: Array<Context> = [];
  const universe = new Set<string>();
  for (const file of sourceList) {
    const found = contextsOf(
      path.relative(root, file),
      readFileSync(file, "utf8"),
    );
    contexts.push(...found.contexts);
    for (const word of found.words) universe.add(word);
  }
  return { contexts, universe };
}

async function compileStyles(
  cssPath: string,
  root: string,
  universe: ReadonlySet<string>,
): Promise<Root> {
  const compiler = await compile(readFileSync(cssPath, "utf8"), {
    base: path.dirname(cssPath),
    loadStylesheet: stylesheetLoader(root),
  });
  return postcss.parse(compiler.build([...universe]));
}

function addEntry(
  groups: Map<string, Group>,
  problems: Map<string, Set<string>>,
  candidate: string,
  position: number,
  state: StateInfo,
  entry: Entry,
): void {
  const conditions = conditionsOf(entry.wraps);
  if (conditions.problem != null) {
    addProblem(problems, candidate, conditions.problem);
    return;
  }
  const when = [...state.when, ...conditions.when];
  const key = `${candidate}\0${when.join(",")}\0${state.target ?? ""}`;
  let group = groups.get(key);
  if (group == null) {
    group = {
      candidate,
      when,
      target: state.target,
      order: position,
      important: false,
      declarations: [],
      problems: new Set(),
    };
    groups.set(key, group);
  }
  group.declarations.push(entry.declaration);
  if (entry.declaration.important) group.important = true;
}

function groupRules(
  root: Root,
  candidates: ReadonlySet<string>,
  problems: Map<string, Set<string>>,
): { groups: Map<string, Group>; seen: Set<string>; silent: Set<string> } {
  const seen = new Set<string>();
  const silent = new Set<string>();
  const groups = new Map<string, Group>();
  let order = 0;
  eachRule(root, [], (rule, wraps) => {
    const candidate = candidateOf(rule.selector, candidates);
    if (candidate == null) return;
    seen.add(candidate);
    const position = order++;
    const state = stateOf(rule.selector);
    if (state.ignored) {
      silent.add(candidate);
      return;
    }
    for (const problem of state.problems)
      addProblem(problems, candidate, problem);
    for (const entry of declarationsOf(rule, wraps))
      addEntry(groups, problems, candidate, position, state, entry);
  });
  return { groups, seen, silent };
}

function tokensFor(
  groups: Map<string, Group>,
  globals: Lookup,
  fonts: Record<string, string>,
  problems: Map<string, Set<string>>,
): { tokens: Record<string, Array<TableRule>>; breakpoints: Set<number> } {
  const tokens: Record<string, Array<TableRule>> = {};
  const breakpoints = new Set<number>();
  for (const group of groups.values()) {
    const mapping = mapCandidate(
      group.candidate,
      group.declarations,
      globals,
      new Map(Object.entries(fonts)),
    );
    for (const problem of mapping.problems)
      addProblem(problems, group.candidate, problem);
    for (const patch of mapping.patches) {
      const rules = (tokens[group.candidate] ??= []);
      tableRules(group, patch, rules);
    }
    for (const condition of group.when) {
      const threshold = /^[<>=]+(\d+)$/.exec(condition)?.[1];
      if (threshold != null) breakpoints.add(Number(threshold));
    }
  }
  for (const rules of Object.values(tokens))
    rules.sort(
      (a, b) =>
        Number(a.important ?? false) - Number(b.important ?? false) ||
        a.order - b.order,
    );
  return { tokens, breakpoints };
}

function warningsFor(
  contexts: Array<Context>,
  candidates: ReadonlySet<string>,
  seen: ReadonlySet<string>,
  problems: ReadonlyMap<string, ReadonlySet<string>>,
  isIgnored: (token: string) => boolean,
): Array<string> {
  const warnings: Array<string> = [];
  for (const context of contexts) {
    const words = context.text.split(/\s+/).filter((word) => word !== "");
    for (const token of words) {
      if (!candidates.has(token) || isIgnored(token)) continue;
      const messages = problems.get(token) ?? [];
      for (const problem of messages)
        warnings.push(
          `Tailwind class "${token}" in ${context.file} isn't supported by swiftui-svelte: ${problem}.`,
        );
      if (!seen.has(token))
        warnings.push(
          `"${token}" in ${context.file} isn't a Tailwind utility.`,
        );
    }
  }
  return warnings;
}

function ignoredBy(patterns: Array<string>): (token: string) => boolean {
  const expressions = patterns.map(
    (pattern) =>
      new RegExp(
        `^${pattern.replaceAll(/[.+?^${}()|[\]\\]/g, String.raw`\$&`).replaceAll("*", ".*")}$`,
      ),
  );
  return (token) => expressions.some((expression) => expression.test(token));
}

function addStatics(table: ClassTable, contexts: Array<Context>): void {
  for (const context of contexts) {
    if (context.tag == null) continue;
    const resolution = resolveClasses(
      table,
      context.tag,
      context.text,
      NEUTRAL,
    );
    if (!resolution.reactive)
      table.statics[classKey(context.tag, context.text)] = resolution.attrs;
  }
}

export async function buildClassTable(
  options: BuildOptions,
): Promise<BuildResult> {
  const cssPath = path.resolve(options.root, options.css);
  const directories = options.sources.map((directory) =>
    path.resolve(options.root, directory),
  );
  const sourceList = sourceFiles(directories);
  const { contexts, universe } = scanSources(sourceList, options.root);
  const root = await compileStyles(cssPath, options.root, universe);
  const globals = lookupFor(collectGlobals(root));
  const problems = new Map<string, Set<string>>();
  const { groups, seen, silent } = groupRules(root, universe, problems);
  const { tokens, breakpoints } = tokensFor(
    groups,
    globals,
    options.fonts,
    problems,
  );
  const isIgnored = ignoredBy(options.ignore ?? []);
  for (const token of silent) tokens[token] ??= [{ order: 0, attrs: {} }];
  for (const token of universe)
    if (isIgnored(token)) tokens[token] = [{ order: 0, attrs: {} }];
  const table: ClassTable = {
    tokens,
    statics: {},
    breakpoints: [...breakpoints].toSorted((a, b) => a - b),
  };
  addStatics(table, contexts);
  return {
    table,
    warnings: [
      ...new Set(warningsFor(contexts, universe, seen, problems, isIgnored)),
    ],
    files: [cssPath, ...directories, ...sourceList],
  };
}

function addProblem(
  problems: Map<string, Set<string>>,
  candidate: string,
  problem: string,
): void {
  const set = problems.get(candidate) ?? new Set<string>();
  set.add(problem);
  problems.set(candidate, set);
}
