import type { Component } from "svelte";
import { SvelteSet, SvelteURL } from "svelte/reactivity";
import { matchers, root, routes } from "virtual:swiftui-svelte/routes";
import type { AnimationOptions } from "../elements.ts";
import type { Params } from "./match.ts";
import type {
  AfterNavigate,
  AppError,
  BeforeNavigate,
  Data,
  LayoutLoad,
  LayoutProps,
  Level,
  Navigation,
  NavigationTarget,
  NavigationType,
  OnNavigate,
  PageProps,
  RouteDefinition,
  Screen,
} from "./types.ts";
import { onOpenURL, restorable, routePath } from "../app.ts";
import { withAnimation } from "../renderer.ts";
import { isHttpError, isRedirect, Redirect } from "./errors.ts";
import { resolveRoute } from "./match.ts";

const origin = "http://localhost";

export const hooks = {
  before: new SvelteSet<(navigation: BeforeNavigate) => void>(),
  after: new SvelteSet<(navigation: AfterNavigate) => void>(),
  onNavigate: new SvelteSet<(navigation: OnNavigate) => void | Promise<void>>(),
};

export type Layer =
  | {
      kind: "layout";
      component: Component<LayoutProps>;
      data: Data;
      params: Params;
    }
  | {
      kind: "page";
      component: Component<PageProps>;
      data: Data;
      params: Params;
    }
  | {
      kind: "error";
      component: Component<Record<string, never>> | undefined;
      status: number;
      message: string;
    };

type View = {
  status: number;
  error: AppError | null;
  steps: Array<Data>;
  chain: Array<Layer>;
};

const emptyView: View = { status: 200, error: null, steps: [], chain: [] };

const saved = restorable<Array<string>>(
  "swiftui-svelte.routes",
  [],
  (value): value is Array<string> =>
    Array.isArray(value) && value.every((item) => typeof item === "string"),
);

export class Entry {
  readonly key: number;
  readonly url: URL;
  readonly route: RouteDefinition | null;
  readonly params: Params;
  readonly screen: Screen = $state({
    title: "",
    subtitle: "",
    backButtonHidden: false,
  });
  view: View = $state.raw(emptyView);
  deps = new SvelteSet<string>();

  constructor(
    key: number,
    url: URL,
    route: RouteDefinition | null,
    params: Params,
  ) {
    this.key = key;
    this.url = url;
    this.route = route;
    this.params = params;
  }
}

function isSameLocation(left: URL, right: URL): boolean {
  return left.pathname === right.pathname && left.search === right.search;
}

class Router {
  stack: Array<Entry> = $state.raw([]);
  sheet: Entry | null = $state.raw(null);
  rootData: Data = $state.raw({});
  navigating: Navigation | null = $state.raw(null);
  rootDeps = new SvelteSet<string>();
  animation: AnimationOptions = true;

  #save(): void {
    saved.value = this.stack
      .slice(1)
      .map((entry) => entry.url.pathname + entry.url.search);
  }

  #popTo(depth: number): void {
    if (depth < 0 || depth >= this.stack.length - 1) return;
    const from = this.target(this.top);
    withAnimation(() => {
      this.stack = this.stack.slice(0, depth + 1);
      this.#save();
    }, this.animation);
    const to = this.target(this.top);
    if (from == null || to == null) return;
    for (const callback of hooks.after) {
      callback({ from, to, type: "popstate", willUnload: false });
    }
  }

  get top(): Entry | null {
    return this.sheet ?? this.stack.at(-1) ?? null;
  }

  visits(): Array<Entry> {
    return this.sheet == null ? this.stack : [...this.stack, this.sheet];
  }

  target(entry: Entry | null): NavigationTarget | null {
    if (entry == null) return null;
    return {
      url: entry.url,
      params: entry.params,
      route: { id: entry.route?.id ?? null },
    };
  }

  commit(entry: Entry, shouldReplace: boolean): void {
    withAnimation(() => {
      if (entry.route?.page.presentation === "sheet") {
        this.sheet = entry;
        return;
      }
      const last = this.stack.at(-1);
      const isReplaces =
        last != null && (shouldReplace || isSameLocation(last.url, entry.url));
      this.sheet = null;
      this.stack = isReplaces
        ? [...this.stack.slice(0, -1), entry]
        : [...this.stack, entry];
      this.#save();
    }, this.animation);
  }

  pop(depth: number): void {
    this.sheet = null;
    this.stack = this.stack.slice(0, depth + 1);
    this.#save();
  }

  dismiss(): void {
    this.sheet = null;
  }

  back(): void {
    if (this.sheet != null) {
      this.sheet = null;
      return;
    }
    this.#popTo(this.stack.length - 2);
  }

  popToRoot(): void {
    this.sheet = null;
    this.#popTo(0);
  }
}

export const router = new Router();

const counters = { serial: 0, keys: 0 };
const lifecycle = { started: false };
const ready = Promise.withResolvers<void>();

function merge(base: Data, steps: Array<Data>): Data {
  const merged: Data = { ...base };
  for (const step of steps) Object.assign(merged, step);
  return merged;
}

async function loadSteps(
  steps: Array<{ load?: LayoutLoad }>,
  base: Data,
  url: URL,
  params: Params,
  routeId: string,
  deps: Set<string>,
): Promise<{
  data: Array<Data>;
  failure: { step: number; cause: unknown } | null;
}> {
  const data: Array<Data> = [];
  for (const [step, { load }] of steps.entries()) {
    try {
      const result = await load?.({
        params,
        url,
        route: { id: routeId },
        fetch,
        parent: async () => merge(base, data),
        depends: (...keys) => {
          for (const key of keys) deps.add(key);
        },
      });
      data.push(result ?? {});
    } catch (error) {
      return { data, failure: { step, cause: error } };
    }
  }
  return { data, failure: null };
}

function layouts(
  levels: Array<Level>,
  steps: Array<Data>,
  params: Params,
): Array<Layer> {
  const layers: Array<Layer> = [];
  for (const [index, level] of levels.entries()) {
    if (level.layout == null) continue;
    layers.push({
      kind: "layout",
      component: level.layout,
      data: steps[index] ?? {},
      params,
    });
  }
  return layers;
}

function successView(
  route: RouteDefinition,
  params: Params,
  steps: Array<Data>,
): View {
  return {
    status: 200,
    error: null,
    steps,
    chain: [
      ...layouts(route.levels, steps, params),
      {
        kind: "page",
        component: route.page.component,
        data: steps[route.levels.length] ?? {},
        params,
      },
    ],
  };
}

function failureView(
  route: RouteDefinition | null,
  step: number,
  status: number,
  message: string,
  steps: Array<Data>,
  params: Params,
): View {
  const levels = route?.levels ?? [];
  const boundary = levels.findLastIndex(
    (level, index) => index <= step && level.error != null,
  );
  const component = boundary === -1 ? root.error : levels[boundary]?.error;
  return {
    status,
    error: { message },
    steps,
    chain: [
      ...layouts(levels.slice(0, Math.max(boundary, 0)), steps, params),
      { kind: "error", component, status, message },
    ],
  };
}

async function assemble(
  route: RouteDefinition | null,
  url: URL,
  params: Params,
  deps: Set<string>,
  rootData: Data,
): Promise<View | Redirect> {
  if (route == null) {
    return failureView(null, -1, 404, "Not Found", [], params);
  }
  const { data, failure } = await loadSteps(
    [...route.levels, route.page],
    rootData,
    url,
    params,
    route.id,
    deps,
  );
  if (failure == null) return successView(route, params, data);
  if (isRedirect(failure.cause)) return failure.cause;
  if (isHttpError(failure.cause)) {
    return failureView(
      route,
      failure.step,
      failure.cause.status,
      failure.cause.body.message,
      data,
      params,
    );
  }
  console.warn(failure.cause);
  return failureView(route, failure.step, 500, "Internal Error", data, params);
}

async function reloadRoot(): Promise<void> {
  const deps = new SvelteSet<string>();
  const { data, failure } = await loadSteps(
    [root],
    {},
    router.top?.url ?? new SvelteURL(origin),
    {},
    "/",
    deps,
  );
  if (failure != null) {
    console.warn(failure.cause);
    return;
  }
  router.rootData = data[0] ?? {};
  router.rootDeps = deps;
}

export async function navigate(
  url: URL,
  type: NavigationType,
  shouldReplace: boolean,
  redirects = 0,
): Promise<void> {
  const current = ++counters.serial;
  const matched = resolveRoute(routes, routePath(url), matchers);
  const to: NavigationTarget = {
    url,
    params: matched?.params ?? {},
    route: { id: matched?.route.id ?? null },
  };
  const from = router.target(router.top);
  const cancellation = { isCanceled: false };
  for (const callback of hooks.before) {
    callback({
      from,
      to,
      type,
      willUnload: false,
      cancel: () => {
        cancellation.isCanceled = true;
      },
    });
  }
  if (cancellation.isCanceled) return;

  const pending: Array<Promise<void>> = [];
  for (const callback of hooks.onNavigate) {
    const result = callback({ from, to, type, willUnload: false });
    if (result instanceof Promise) pending.push(result);
  }
  await Promise.all(pending);

  const { promise: complete, resolve: finish } = Promise.withResolvers<void>();
  router.navigating = { from, to, type, willUnload: false, complete };

  const deps = new SvelteSet<string>();
  const view = await assemble(
    matched?.route ?? null,
    url,
    matched?.params ?? {},
    deps,
    router.rootData,
  );
  if (current !== counters.serial) {
    finish();
    return;
  }
  if (view instanceof Redirect) {
    finish();
    if (redirects < 10) {
      await navigate(
        new SvelteURL(view.location, url),
        type,
        true,
        redirects + 1,
      );
    } else {
      console.warn("Too many redirects");
    }
    return;
  }

  const entry = new Entry(
    ++counters.keys,
    url,
    matched?.route ?? null,
    matched?.params ?? {},
  );
  entry.deps = deps;
  entry.view = view;
  router.commit(entry, shouldReplace);
  router.navigating = null;
  finish();
  for (const callback of hooks.after) {
    callback({ from, to, type, willUnload: false });
  }
}

async function refresh(entry: Entry): Promise<void> {
  if (entry.route == null) return;
  const deps = new SvelteSet<string>();
  const view = await assemble(
    entry.route,
    entry.url,
    entry.params,
    deps,
    router.rootData,
  );
  if (view instanceof Redirect) {
    await navigate(new SvelteURL(view.location, entry.url), "goto", true);
    return;
  }
  entry.deps = deps;
  entry.view = view;
}

export async function invalidate(key: string): Promise<void> {
  const work: Array<Promise<void>> = [];
  for (const entry of router.visits()) {
    if (entry.deps.has(key)) work.push(refresh(entry));
  }
  if (router.rootDeps.has(key)) work.push(reloadRoot());
  await Promise.all(work);
}

export async function invalidateAll(): Promise<void> {
  await Promise.all([
    reloadRoot(),
    ...router.visits().map(async (entry) => refresh(entry)),
  ]);
}

export function resolveHref(href: string | URL): URL {
  return new SvelteURL(href, router.top?.url ?? origin);
}

export function start(hosts: () => ReadonlyArray<string> = () => []): void {
  if (lifecycle.started) return;
  lifecycle.started = true;
  const paths = [...saved.value];
  void reloadRoot()
    .then(async () => navigate(new SvelteURL("/", origin), "enter", false))
    .then(async () => {
      for (const path of paths) {
        await navigate(new SvelteURL(path, origin), "enter", false);
      }
    })
    .then(() => ready.resolve());
  onOpenURL((url) => {
    const isWeb = url.protocol === "http:" || url.protocol === "https:";
    if (isWeb && !hosts().includes(url.host)) return;
    void ready.promise.then(async () =>
      navigate(
        new SvelteURL(routePath(url) + url.search, origin),
        "goto",
        false,
      ),
    );
  });
}
