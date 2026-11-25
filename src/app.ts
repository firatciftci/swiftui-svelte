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
    emit(urls, new URL(payload));
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
  return subscribe(urls, listener);
}
