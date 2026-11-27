import { report } from "./web/events.ts";

type Unsubscribe = () => void;
type Method = (...args: Array<never>) => Promise<unknown>;
type Pending = {
  resolve: (value: unknown) => void;
  reject: (error: NativeError) => void;
};

export interface NativeModules {}

export interface NativeEvents {}

type EventsOf<Name extends string> = Name extends keyof NativeEvents
  ? NativeEvents[Name]
  : Record<string, unknown>;

type ModuleOf<Name extends string> = Name extends keyof NativeModules
  ? NativeModules[Name]
  : Record<string, Method>;

export type NativeModule<Name extends string> = ModuleOf<Name> & {
  on: <Event extends keyof EventsOf<Name> & string>(
    event: Event,
    listener: (payload: EventsOf<Name>[Event]) => void,
  ) => Unsubscribe;
};

export class NativeError extends Error {
  readonly code: string;

  constructor(message: string, code = "native") {
    super(message);
    this.name = "NativeError";
    this.code = code;
  }
}

const pending = new Map<number, Pending>();
const listeners = new Map<string, Set<(payload: unknown) => void>>();
const calls = { next: 1 };

function decode(json: string | null | undefined): unknown {
  if (json == null || json === "") return undefined;
  return JSON.parse(json) as unknown;
}

function readError(value: unknown): NativeError {
  if (typeof value === "object" && value != null) {
    const message =
      "message" in value && typeof value.message === "string"
        ? value.message
        : "The native call failed.";
    const code =
      "code" in value && typeof value.code === "string" ? value.code : "native";
    return new NativeError(message, code);
  }
  return new NativeError(String(value));
}

export async function call(
  module: string,
  method: string,
  ...args: Array<unknown>
): Promise<unknown> {
  if (typeof globalThis.__nativeCall !== "function") {
    throw new NativeError(
      `There's no native host to run ${module}.${method}.`,
      "unavailable",
    );
  }
  const id = calls.next;
  calls.next += 1;
  return new Promise((resolve, reject) => {
    pending.set(id, { resolve, reject });
    try {
      globalThis.__nativeCall(id, module, method, JSON.stringify(args));
    } catch (error) {
      pending.delete(id);
      reject(error);
    }
  });
}

function subscribe(
  module: string,
  event: string,
  listener: (payload: unknown) => void,
): Unsubscribe {
  const key = `${module}.${event}`;
  let set = listeners.get(key);
  if (set == null) {
    set = new Set();
    listeners.set(key, set);
  }
  set.add(listener);
  return () => void set.delete(listener);
}

export function nativeModule<Name extends string>(
  name: Name,
): NativeModule<Name> {
  const on = (
    event: string,
    listener: (payload: unknown) => void,
  ): Unsubscribe => subscribe(name, event, listener);
  return new Proxy(
    {},
    {
      get(_, method) {
        if (method === "on") return on;
        if (typeof method !== "string" || method === "then") return null;
        return async (...args: Array<unknown>): Promise<unknown> =>
          call(name, method, ...args);
      },
    },
  ) as NativeModule<Name>;
}

async function typed<T>(
  module: string,
  method: string,
  ...args: Array<unknown>
): Promise<T> {
  return (await call(module, method, ...args)) as T;
}

type ImpactStyle = "light" | "medium" | "heavy" | "soft" | "rigid";

export const haptics = {
  async impact(
    options: { style?: ImpactStyle; intensity?: number } = {},
  ): Promise<void> {
    await typed<void>("haptics", "impact", options);
  },
  async notification(type: "success" | "warning" | "error"): Promise<void> {
    await typed<void>("haptics", "notification", type);
  },
  async selection(): Promise<void> {
    await typed<void>("haptics", "selection");
  },
};

export const clipboard = {
  async readText(): Promise<string | null> {
    return typed<string | null>("clipboard", "readText");
  },
  async writeText(text: string): Promise<void> {
    await typed<void>("clipboard", "writeText", text);
  },
  async hasText(): Promise<boolean> {
    return typed<boolean>("clipboard", "hasText");
  },
};

export async function share(options: {
  text?: string;
  url?: string | URL;
  subject?: string;
}): Promise<{ completed: boolean }> {
  const isCompleted = await typed<boolean>("share", "share", {
    ...options,
    url: options.url?.toString(),
  });
  return { completed: isCompleted };
}

export const links = {
  async open(url: string | URL): Promise<boolean> {
    return typed<boolean>("links", "open", url.toString());
  },
  async canOpen(url: string | URL): Promise<boolean> {
    return typed<boolean>("links", "canOpen", url.toString());
  },
};

export const secureStorage = {
  async get(key: string): Promise<string | null> {
    return typed<string | null>("secureStorage", "get", key);
  },
  async set(key: string, value: string): Promise<void> {
    await typed<void>("secureStorage", "set", key, value);
  },
  async delete(key: string): Promise<void> {
    await typed<void>("secureStorage", "delete", key);
  },
};

export const files = {
  async readText(path: string): Promise<string | null> {
    return typed<string | null>("files", "readText", path);
  },
  async writeText(path: string, text: string): Promise<void> {
    await typed<void>("files", "writeText", path, text);
  },
  async delete(path: string): Promise<void> {
    await typed<void>("files", "delete", path);
  },
  async exists(path: string): Promise<boolean> {
    return typed<boolean>("files", "exists", path);
  },
  async list(path = ""): Promise<Array<string>> {
    return typed<Array<string>>("files", "list", path);
  },
};

const reply: typeof globalThis.__svelteNativeReply = (id, error, json) => {
  const call = pending.get(id);
  if (call == null) return;
  pending.delete(id);
  if (error == null) call.resolve(decode(json));
  else call.reject(readError(decode(error)));
};

const emit: typeof globalThis.__svelteNativeEvent = (module, event, json) => {
  const set = listeners.get(`${module}.${event}`);
  if (set == null) return;
  const payload = decode(json);
  const snapshot = new Set(set);
  for (const listener of snapshot) {
    try {
      listener(payload);
    } catch (error) {
      report(error);
    }
  }
};

Object.assign(globalThis, {
  __svelteNativeReply: reply,
  __svelteNativeEvent: emit,
});
