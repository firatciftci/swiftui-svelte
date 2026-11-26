import type { AfterNavigate, BeforeNavigate, OnNavigate } from "./types.ts";
import {
  hooks,
  invalidateAll as invalidateEverything,
  invalidate as invalidateKey,
  navigate,
  resolveHref,
  router,
} from "./router.svelte.ts";

export async function goto(
  href: string | URL,
  options: { replaceState?: boolean } = {},
): Promise<void> {
  return navigate(resolveHref(href), "goto", options.replaceState ?? false);
}

export function back(): void {
  router.back();
}

export function beforeNavigate(
  callback: (navigation: BeforeNavigate) => void,
): void {
  hooks.before.add(callback);
}

export function afterNavigate(
  callback: (navigation: AfterNavigate) => void,
): void {
  hooks.after.add(callback);
}

export function onNavigate(
  callback: (navigation: OnNavigate) => void | Promise<void>,
): void {
  hooks.onNavigate.add(callback);
}

export async function invalidate(depends: string | URL): Promise<void> {
  return invalidateKey(String(depends));
}

export async function invalidateAll(): Promise<void> {
  return invalidateEverything();
}
