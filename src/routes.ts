import {
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import path from "node:path";
import type { Segment } from "./kit/match.ts";
import { compareSegments, parseSegments } from "./kit/match.ts";

export const routesModuleId = "virtual:swiftui-svelte/routes";

const kit = path.join(import.meta.dirname, "kit");

export const appAliases = [
  {
    find: /^\$app\/(environment|navigation|paths|state)$/,
    replacement: `${kit}/$1`,
  },
];

type Directory = {
  path: string;
  url: string;
  segments: Array<Segment>;
  layout: string | undefined;
  layoutModule: string | undefined;
  error: string | undefined;
  page: string | undefined;
  pageModule: string | undefined;
};

type PageDirectory = Directory & { page: string };

type Scan = { directories: Array<Directory>; matchers: Map<string, string> };

function routesDirectory(source: string): string {
  return path.join(source, "routes");
}

function typesDirectory(root: string): string {
  return path.join(root, ".swiftui-svelte", "types");
}

function hasLoad(file: string | undefined): boolean {
  return (
    file != null &&
    /export\s+(?:const|let|function)\s+load\b/.test(readFileSync(file, "utf8"))
  );
}

function isSheet(file: string | undefined): boolean {
  return (
    file != null &&
    /export\s+const\s+presentation\s*=\s*["']sheet["']/.test(
      readFileSync(file, "utf8"),
    )
  );
}

function firstFile(
  directory: string,
  names: Array<string>,
): string | undefined {
  for (const name of names) {
    const file = path.join(directory, name);
    if (existsSync(file)) return file;
  }
  return undefined;
}

function scanDirectory(
  directory: string,
  url: string,
  found: Array<Directory>,
): void {
  const page = firstFile(directory, ["+page.svelte"]);
  const pageModule = firstFile(directory, ["+page.ts", "+page.js"]);
  if (pageModule != null && page == null) {
    throw new Error(`${pageModule} needs a +page.svelte next to it.`);
  }
  const layout = firstFile(directory, ["+layout.svelte"]);
  const layoutModule = firstFile(directory, ["+layout.ts", "+layout.js"]);
  if (layoutModule != null && layout == null) {
    throw new Error(`${layoutModule} needs a +layout.svelte next to it.`);
  }
  const error = firstFile(directory, ["+error.svelte"]);
  if (
    page != null ||
    layout != null ||
    error != null ||
    pageModule != null ||
    layoutModule != null
  ) {
    found.push({
      path: directory,
      url,
      segments: parseSegments(url),
      layout,
      layoutModule,
      error,
      page,
      pageModule,
    });
  }
  const children = readdirSync(directory, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .toSorted((left, right) => left.localeCompare(right, "en"));
  for (const name of children) {
    const isGroup = name.startsWith("(") && name.endsWith(")");
    const segment = isGroup ? "" : name;
    scanDirectory(
      path.join(directory, name),
      isGroup ? url : `${url === "/" ? "" : url}/${segment}`,
      found,
    );
  }
}

function scanMatchers(source: string): Map<string, string> {
  const directory = path.join(source, "params");
  const matchers = new Map<string, string>();
  if (!existsSync(directory)) return matchers;
  const names = readdirSync(directory).toSorted((left, right) =>
    left.localeCompare(right, "en"),
  );
  for (const name of names) {
    const match = /^(\w+)\.(?:ts|js)$/.exec(name);
    if (match?.[1] != null) matchers.set(match[1], path.join(directory, name));
  }
  return matchers;
}

function scan(source: string): Scan {
  const directories: Array<Directory> = [];
  const routes = routesDirectory(source);
  if (existsSync(routes)) scanDirectory(routes, "/", directories);
  return { directories, matchers: scanMatchers(source) };
}

function isAncestor(ancestor: Directory, directory: Directory): boolean {
  return (
    directory.path === ancestor.path ||
    directory.path.startsWith(`${ancestor.path}${path.sep}`)
  );
}

function vitePath(root: string, file: string): string {
  return `/${path.relative(root, file).split(path.sep).join("/")}`;
}

function shape(segments: Array<Segment>): string {
  return segments
    .map((segment) =>
      segment.kind === "static"
        ? segment.value
        : `[${segment.rest ? "..." : ""}${segment.optional ? "[" : ""}${segment.matcher ?? ""}]`,
    )
    .join("/");
}

export function routesModule(root: string, source: string): string {
  const { directories, matchers } = scan(source);
  const imports = new Map<string, string>();
  const reference = (file: string): string => {
    const existing = imports.get(file);
    if (existing != null) return existing;
    const name = `m${imports.size}`;
    imports.set(file, name);
    return name;
  };
  const routesRoot = routesDirectory(source);
  const rootDirectory = directories.find(
    (directory) => directory.path === routesRoot,
  );
  const routeDirectories = directories.filter(
    (directory): directory is PageDirectory => directory.page != null,
  );
  const levelsOf = (page: Directory): Array<string> =>
    directories
      .filter(
        (directory) =>
          directory.path !== routesRoot &&
          isAncestor(directory, page) &&
          (directory.layout != null || directory.error != null),
      )
      .map((directory) => {
        const layout = directory.layout;
        const layoutModule = directory.layoutModule;
        const error = directory.error;
        return [
          `{ id: ${JSON.stringify(directory.url)}`,
          layout == null ? "" : `layout: ${reference(layout)}.default`,
          hasLoad(layoutModule)
            ? `load: ${reference(layoutModule ?? "")}.load`
            : "",
          error == null ? "" : `error: ${reference(error)}.default`,
          "}",
        ]
          .filter((part) => part !== "")
          .join(", ");
      });
  const seen = new Map<string, string>();
  const routes = routeDirectories
    .toSorted((left, right) => compareSegments(left.segments, right.segments))
    .map((directory) => {
      const key = shape(directory.segments);
      const existing = seen.get(key);
      if (existing != null) {
        throw new Error(
          `Routes ${existing} and ${directory.url} conflict. Both match the same URLs.`,
        );
      }
      seen.set(key, directory.url);
      for (const segment of directory.segments) {
        if (
          segment.kind === "param" &&
          segment.matcher != null &&
          !matchers.has(segment.matcher)
        ) {
          throw new Error(
            `${directory.url} uses the matcher ${segment.matcher}, but params/${segment.matcher}.ts doesn't exist.`,
          );
        }
      }
      const { page, pageModule } = directory;
      return [
        "  {",
        `    id: ${JSON.stringify(directory.url)},`,
        `    segments: ${JSON.stringify(directory.segments)},`,
        `    levels: [${levelsOf(directory).join(", ")}],`,
        "    page: {",
        `      component: ${reference(page)}.default,`,
        hasLoad(pageModule)
          ? `      load: ${reference(pageModule ?? "")}.load,`
          : "",
        `      presentation: ${JSON.stringify(isSheet(page) ? "sheet" : "page")},`,
        "    },",
        "  },",
      ]
        .filter((line) => line !== "")
        .join("\n");
    });
  const matcherEntries = [...matchers].map(
    ([name, file]) => `  ${JSON.stringify(name)}: ${reference(file)}.match,`,
  );
  const rootLevel = [
    `{ id: "/"`,
    rootDirectory?.layout == null
      ? ""
      : `layout: ${reference(rootDirectory.layout)}.default`,
    rootDirectory?.layoutModule == null || !hasLoad(rootDirectory.layoutModule)
      ? ""
      : `load: ${reference(rootDirectory.layoutModule)}.load`,
    rootDirectory?.error == null
      ? ""
      : `error: ${reference(rootDirectory.error)}.default`,
    "}",
  ]
    .filter((part) => part !== "")
    .join(", ");
  const head = [...imports].map(
    ([file, name]) =>
      `import * as ${name} from ${JSON.stringify(vitePath(root, file))};`,
  );
  return [
    ...head,
    `export const root = ${rootLevel};`,
    "export const routes = [",
    ...routes,
    "];",
    "export const matchers = {",
    ...matcherEntries,
    "};",
    "",
  ].join("\n");
}

function importPath(from: string, to: string): string {
  const relative = path
    .relative(path.dirname(from), to)
    .replace(/\.(?:ts|js)$/, "")
    .split(path.sep)
    .join("/");
  return relative.startsWith(".") ? relative : `./${relative}`;
}

function paramsType(segments: Array<Segment>): string {
  const fields: Array<string> = [];
  for (const segment of segments) {
    if (segment.kind !== "static") {
      fields.push(`${segment.name}${segment.optional ? "?" : ""}: string;`);
    }
  }
  return fields.length === 0
    ? "Record<never, never>"
    : `{ ${fields.join(" ")} }`;
}

function typesFile(root: string, directory: Directory): string {
  const outputDirectory = path.join(
    typesDirectory(root),
    path.relative(root, directory.path),
  );
  const file = path.join(outputDirectory, "$types.d.ts");
  const hasLayout = directory.layout != null || directory.layoutModule != null;
  const hasPage = directory.page != null || directory.pageModule != null;
  const imports = ['import type * as Kit from "swiftui-svelte/kit";'];
  if (directory.layoutModule != null) {
    imports.push(
      `import type * as Layout from ${JSON.stringify(importPath(file, directory.layoutModule))};`,
    );
  }
  if (directory.pageModule != null) {
    imports.push(
      `import type * as Page from ${JSON.stringify(importPath(file, directory.pageModule))};`,
    );
  }
  const lines = [
    ...imports,
    "",
    `export type Params = ${paramsType(directory.segments)};`,
  ];
  if (hasLayout) {
    lines.push(
      `export type LayoutData = ${directory.layoutModule == null ? "Record<never, never>" : "Exclude<Awaited<ReturnType<NonNullable<typeof Layout.load>>>, void>"};`,
      "export type LayoutProps = Kit.LayoutProps<Params, LayoutData>;",
      "export type LayoutLoad = Kit.LayoutLoad<Params>;",
      "export type LayoutLoadEvent = Kit.LayoutLoadEvent<Params>;",
    );
  }
  if (hasPage) {
    lines.push(
      `export type PageData = ${directory.pageModule == null ? "Record<never, never>" : "Exclude<Awaited<ReturnType<NonNullable<typeof Page.load>>>, void>"};`,
      "export type PageProps = Kit.PageProps<Params, PageData>;",
      "export type PageLoad = Kit.PageLoad<Params>;",
      "export type PageLoadEvent = Kit.PageLoadEvent<Params>;",
    );
  }
  return `${lines.join("\n")}\n`;
}

const ambient = `declare module "virtual:swiftui-svelte/routes" {
  import type { Definitions } from "swiftui-svelte/kit";
  export const root: Definitions["root"];
  export const routes: Definitions["routes"];
  export const matchers: Definitions["matchers"];
}
declare module "$app/navigation" {
  export * from "swiftui-svelte/kit/navigation";
}
declare module "$app/state" {
  export * from "swiftui-svelte/kit/state";
}
declare module "$app/environment" {
  export * from "swiftui-svelte/kit/environment";
}
declare module "$app/paths" {
  export * from "swiftui-svelte/kit/paths";
}
`;

export function syncRoutes(root: string, source: string): void {
  const types = typesDirectory(root);
  rmSync(path.join(types, path.relative(root, source)), {
    recursive: true,
    force: true,
  });
  const { directories } = scan(source);
  for (const directory of directories) {
    const file = path.join(
      types,
      path.relative(root, directory.path),
      "$types.d.ts",
    );
    mkdirSync(path.dirname(file), { recursive: true });
    writeFileSync(file, typesFile(root, directory));
  }
  mkdirSync(types, { recursive: true });
  writeFileSync(path.join(types, "app.d.ts"), ambient);
}

export function routesWatchPath(source: string): string {
  return routesDirectory(source);
}
