import type { Data, Navigation, NavigationTarget, Page } from "./types.ts";
import { router } from "./router.svelte.ts";

const home = new URL("http://localhost/");

export const page: Page = {
  get url() {
    return router.top?.url ?? home;
  },
  get params() {
    return router.top?.params ?? {};
  },
  get route() {
    return { id: router.top?.route?.id ?? null };
  },
  get status() {
    return router.top?.view.status ?? 200;
  },
  get error() {
    return router.top?.view.error ?? null;
  },
  get data(): Data {
    return merged();
  },
  get state(): Data {
    return {};
  },
};

function merged(): Data {
  const data: Data = { ...router.rootData };
  const steps = router.top?.view.steps ?? [];
  for (const step of steps) Object.assign(data, step);
  return data;
}

export const navigating: {
  readonly from: NavigationTarget | null;
  readonly to: NavigationTarget | null;
  readonly type: Navigation["type"] | null;
  readonly willUnload: boolean;
  readonly complete: Promise<void> | null;
} = {
  get from() {
    return router.navigating?.from ?? null;
  },
  get to() {
    return router.navigating?.to ?? null;
  },
  get type() {
    return router.navigating?.type ?? null;
  },
  get willUnload() {
    return router.navigating?.willUnload ?? false;
  },
  get complete() {
    return router.navigating?.complete ?? null;
  },
};
