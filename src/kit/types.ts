import type { Component, Snippet } from "svelte";
import type { Matchers, Params, Segment } from "./match.ts";

export type Data = Record<string, unknown>;

export type AppError = { message: string };

type MaybePromise<T> = T | Promise<T>;

export type LoadEvent<P extends Params = Params> = {
  params: P;
  url: URL;
  route: { id: string };
  fetch: typeof globalThis.fetch;
  parent: () => Promise<Data>;
  depends: (...keys: Array<string>) => void;
};

export type PageLoadEvent<P extends Params = Params> = LoadEvent<P>;

export type LayoutLoadEvent<P extends Params = Params> = LoadEvent<P>;

export type PageLoad<P extends Params = Params> = (
  event: PageLoadEvent<P>,
) => MaybePromise<Data | void>;

export type LayoutLoad<P extends Params = Params> = (
  event: LayoutLoadEvent<P>,
) => MaybePromise<Data | void>;

export type PageProps<P extends Params = Params, D extends Data = Data> = {
  data: D;
  params: P;
};

export type LayoutProps<
  P extends Params = Params,
  D extends Data = Data,
> = PageProps<P, D> & { children: Snippet };

export type Screen = {
  title: string;
  subtitle: string;
  backButtonHidden: boolean;
};

export type Level = {
  id: string;
  layout?: Component<LayoutProps>;
  load?: LayoutLoad;
  error?: Component<Record<string, never>>;
};

export type PageDefinition = {
  component: Component<PageProps>;
  load?: PageLoad;
  presentation: "page" | "sheet";
};

export type RouteDefinition = {
  id: string;
  segments: Array<Segment>;
  levels: Array<Level>;
  page: PageDefinition;
};

export type Definitions = {
  root: Level;
  routes: Array<RouteDefinition>;
  matchers: Matchers;
};

export type NavigationType = "enter" | "goto" | "link" | "popstate";

export type NavigationTarget = {
  url: URL;
  params: Params;
  route: { id: string | null };
};

export type Navigation = {
  from: NavigationTarget | null;
  to: NavigationTarget | null;
  type: NavigationType;
  willUnload: boolean;
  complete: Promise<void>;
};

export type BeforeNavigate = {
  from: NavigationTarget | null;
  to: NavigationTarget;
  type: NavigationType;
  willUnload: boolean;
  cancel: () => void;
};

export type AfterNavigate = {
  from: NavigationTarget | null;
  to: NavigationTarget;
  type: NavigationType;
  willUnload: boolean;
};

export type OnNavigate = AfterNavigate;

export type Page = {
  url: URL;
  params: Params;
  route: { id: string | null };
  status: number;
  error: AppError | null;
  data: Data;
  state: Data;
};

export { type Matchers, type Params, type Segment } from "./match.ts";
