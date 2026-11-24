globalThis.queueMicrotask ??= (task) => void Promise.resolve().then(task);

function format(value: unknown) {
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
      __nativeLog(level, args.map(format).join(" "));
  }
}

if (typeof __nativeStorageLoad === "function") {
  const loaded: unknown = JSON.parse(__nativeStorageLoad());
  const items = new Map<string, string>();
  if (loaded != null && typeof loaded === "object") {
    for (const [key, value] of Object.entries(loaded)) {
      if (typeof value === "string") items.set(key, value);
    }
  }
  let saving = false;
  const save = () => {
    if (saving) return;
    saving = true;
    queueMicrotask(() => {
      saving = false;
      __nativeStorageSave(JSON.stringify(Object.fromEntries(items)));
    });
  };
  const storage: Storage = {
    get length() {
      return items.size;
    },
    key: (index) => [...items.keys()][index] ?? null,
    getItem: (key) => items.get(String(key)) ?? null,
    setItem(key, value) {
      items.set(String(key), String(value));
      save();
    },
    removeItem(key) {
      items.delete(String(key));
      save();
    },
    clear() {
      items.clear();
      save();
    },
  };
  globalThis.localStorage ??= storage;
}

if (typeof __nativeFetch === "function") {
  class NativeHeaders {
    #values: Map<string, string>;
    constructor(values: Record<string, string>) {
      this.#values = new Map(
        Object.entries(values).map(([name, value]) => [
          name.toLowerCase(),
          value,
        ]),
      );
    }
    get(name: string) {
      return this.#values.get(name.toLowerCase()) ?? null;
    }
    has(name: string) {
      return this.#values.has(name.toLowerCase());
    }
    entries() {
      return this.#values.entries();
    }
  }

  class NativeResponse {
    readonly ok: boolean;
    readonly status: number;
    readonly url: string;
    readonly headers: NativeHeaders;
    #body: string;
    constructor(response: NativeFetchResponse) {
      this.status = response.status;
      this.ok = response.status >= 200 && response.status < 300;
      this.url = response.url;
      this.headers = new NativeHeaders(response.headers);
      this.#body = response.body;
    }
    async text() {
      return this.#body;
    }
    async json(): Promise<unknown> {
      return JSON.parse(this.#body);
    }
  }

  const nativeFetch = (
    input: string | URL,
    init?: { method?: string; headers?: Record<string, string>; body?: string },
  ) =>
    new Promise<NativeResponse>((resolve, reject) => {
      __nativeFetch(
        JSON.stringify({
          url: String(input),
          method: init?.method,
          headers: init?.headers,
          body: init?.body,
        }),
        (error, response) => {
          if (response != null) resolve(new NativeResponse(response));
          else reject(new TypeError(error ?? "Network request failed"));
        },
      );
    });
  globalThis.fetch ??= nativeFetch as unknown as typeof fetch;
}
