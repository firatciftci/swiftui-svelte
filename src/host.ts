import { installWebAPIs } from "./web/index.ts";

const resolved = Promise.resolve();
globalThis.queueMicrotask ??= (task) => void resolved.then(task);

if (typeof requestAnimationFrame === "undefined") {
  let callbacks = new Map<number, FrameRequestCallback>();
  let nextFrameId = 1;
  globalThis.__svelteFrame = (time) => {
    const due = callbacks;
    callbacks = new Map();
    for (const callback of due.values()) callback(time);
  };
  globalThis.requestAnimationFrame = (callback) => {
    if (callbacks.size === 0) __nativeRequestFrame();
    const id = nextFrameId++;
    callbacks.set(id, callback);
    return id;
  };
  globalThis.cancelAnimationFrame = (id) => void callbacks.delete(id);
}

function format(value: unknown): string {
  if (typeof value === "string") return value;
  if (value instanceof Error) return value.stack ?? value.message;
  try {
    return JSON.stringify(value) ?? String(value);
  } catch {
    return String(value);
  }
}

if (typeof __nativeLog === "function") {
  for (const level of ["log", "info", "warn", "error", "debug"] as const) {
    console[level] = (...args: Array<unknown>) =>
      __nativeLog(level, args.map((arg) => format(arg)).join(" "));
  }
}

installWebAPIs();
