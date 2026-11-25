import type { HostEnvironment } from "./web/environment.ts";
import { environment, observeEnvironment } from "./web/environment.ts";
import { report } from "./web/events.ts";

type Phase = HostEnvironment["scenePhase"];
type Unsubscribe = () => void;

const phases = new Map<Phase, Set<() => void>>([
  ["active", new Set()],
  ["inactive", new Set()],
  ["background", new Set()],
]);
const memoryWarnings = new Set<() => void>();
const urls = new Set<(url: URL) => void>();
const unclaimed: Array<URL> = [];

function subscribe<T>(listeners: Set<T> | undefined, listener: T): Unsubscribe {
  listeners?.add(listener);
  return () => void listeners?.delete(listener);
}

function emit<T extends Array<unknown>>(
  listeners: Set<(...args: T) => void> | undefined,
  ...args: T
): void {
  const snapshot = new Set(listeners);
  for (const listener of snapshot) {
    try {
      listener(...args);
    } catch (error) {
      report(error);
    }
  }
}

const receive: typeof globalThis.__svelteAppEvent = (type, payload) => {
  if (type === "memorywarning") emit(memoryWarnings);
  else if (
    type === "openurl" &&
    typeof payload === "string" &&
    URL.canParse(payload)
  ) {
    const url = new URL(payload);
    if (urls.size === 0) unclaimed.push(url);
    else emit(urls, url);
  }
};

observeEnvironment((previous) => {
  if (previous.scenePhase !== environment.scenePhase) {
    emit(phases.get(environment.scenePhase));
  }
});

Object.assign(globalThis, { __svelteAppEvent: receive });

export function onActive(listener: () => void): Unsubscribe {
  return subscribe(phases.get("active"), listener);
}

export function onInactive(listener: () => void): Unsubscribe {
  return subscribe(phases.get("inactive"), listener);
}

export function onBackground(listener: () => void): Unsubscribe {
  return subscribe(phases.get("background"), listener);
}

export function onMemoryWarning(listener: () => void): Unsubscribe {
  return subscribe(memoryWarnings, listener);
}

export function onOpenURL(listener: (url: URL) => void): Unsubscribe {
  const unsubscribe = subscribe(urls, listener);
  if (unclaimed.length > 0) {
    const waiting = unclaimed.splice(0);
    queueMicrotask(() => {
      for (const url of waiting) emit(urls, url);
    });
  }
  return unsubscribe;
}

function decode(segment: string): string {
  try {
    return decodeURIComponent(segment);
  } catch {
    return segment;
  }
}

function segments(url: URL): Array<string> {
  const path = url.pathname.split("/").filter((segment) => segment !== "");
  const isWeb = url.protocol === "http:" || url.protocol === "https:";
  return (isWeb || url.host === "" ? path : [url.host, ...path]).map(
    (segment) => decode(segment),
  );
}

export function matchURL(
  pattern: string,
  url: URL | string,
): Record<string, string> | null {
  const target =
    typeof url === "string" ? (URL.canParse(url) ? new URL(url) : null) : url;
  if (target == null) return null;
  const actual = segments(target);
  const expected = pattern.split("/").filter((segment) => segment !== "");
  const params: Record<string, string> = {};
  for (const [index, segment] of expected.entries()) {
    if (segment === "*") {
      params["*"] = actual.slice(index).join("/");
      return params;
    }
    const value = actual[index];
    if (value == null) return null;
    if (segment.startsWith(":")) params[segment.slice(1)] = value;
    else if (segment !== value) return null;
  }
  return actual.length === expected.length ? params : null;
}

export { restorable } from "./restore.svelte.ts";
