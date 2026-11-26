import { onDestroy } from "svelte";
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

function register<T>(set: Set<T>, callback: T): void {
  set.add(callback);
  onDestroy(() => set.delete(callback));
}

export function beforeNavigate(
  callback: (navigation: BeforeNavigate) => void,
): void {
  register(hooks.before, callback);
}

export function afterNavigate(
  callback: (navigation: AfterNavigate) => void,
): void {
  register(hooks.after, callback);
}

export function onNavigate(
  callback: (navigation: OnNavigate) => void | Promise<void>,
): void {
  register(hooks.onNavigate, callback);
}

export async function invalidate(depends: string | URL): Promise<void> {
  return invalidateKey(String(depends));
}

export async function invalidateAll(): Promise<void> {
  return invalidateEverything();
}
