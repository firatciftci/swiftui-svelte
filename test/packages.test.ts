import type { RouterClient } from "@orpc/server";
import type { Server } from "node:http";
import type { AddressInfo } from "node:net";
import { createORPCClient } from "@orpc/client";
import { RPCLink } from "@orpc/client/fetch";
import { os } from "@orpc/server";
import { RPCHandler } from "@orpc/server/node";
import {
  focusManager,
  onlineManager,
  QueryClient,
  QueryObserver,
} from "@tanstack/svelte-query";
import {
  createTRPCClient,
  httpBatchLink,
  httpBatchStreamLink,
  httpLink,
  httpSubscriptionLink,
} from "@trpc/client";
import { initTRPC, tracked } from "@trpc/server";
import { createHTTPServer } from "@trpc/server/adapters/standalone";
import { betterAuth } from "better-auth";
import { toNodeHandler } from "better-auth/node";
import { createAuthClient } from "better-auth/svelte";
import { Buffer } from "node:buffer";
import { createServer } from "node:http";
import superjson from "superjson";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { onActive } from "swiftui-svelte/app";
import { connectQueryManagers } from "swiftui-svelte/query";
import {
  createNavigator,
  updateEnvironment,
} from "swiftui-svelte/web/environment";
import { createEventSource } from "swiftui-svelte/web/eventsource";
import { createFetch } from "swiftui-svelte/web/fetch";
import { installWebAPIs } from "swiftui-svelte/web/index";

async function listen(server: Server): Promise<string> {
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const { port } = server.address() as AddressInfo;
      resolve(`http://127.0.0.1:${String(port)}`);
    });
  });
}

const cookies = new Map<string, string>();

async function jarFetch(
  url: Parameters<typeof fetch>[0],
  init?: RequestInit,
): Promise<Response> {
  const headers = new Headers(init?.headers);
  if (cookies.size > 0)
    headers.set(
      "cookie",
      [...cookies].map(([name, value]) => `${name}=${value}`).join("; "),
    );
  const response = await fetch(url, { ...init, headers });
  for (const header of response.headers.getSetCookie()) {
    const [pair = "", ...attributes] = header.split(";");
    const [name = "", ...value] = pair.split("=");
    if (attributes.some((attribute) => /max-age=0$/i.test(attribute.trim())))
      cookies.delete(name);
    else cookies.set(name, value.join("="));
  }
  return response;
}

const nodeFetch = createFetch({
  start(id, json, body, onResponse, onData, onEnd) {
    const request = JSON.parse(json) as {
      url: string;
      method: string;
      headers: Array<[string, string]>;
      redirect: RequestRedirect;
    };
    void (async () => {
      const response = await fetch(request.url, {
        method: request.method,
        headers: request.headers,
        body: body == null ? undefined : Buffer.from(body),
        redirect: request.redirect,
      });
      onResponse(
        JSON.stringify({
          status: response.status,
          url: response.url,
          redirected: response.redirected,
          headers: [...response.headers],
        }),
      );
      if (response.body != null)
        for await (const chunk of response.body) onData(new Uint8Array(chunk));
      onEnd(null);
    })().catch((error: unknown) => onEnd({ message: String(error) }));
  },
  cancel() {},
});

const t = initTRPC.create({ transformer: superjson });
const trpcRouter = t.router({
  greet: t.procedure
    .input((value: unknown) => {
      if (typeof value !== "string") throw new TypeError("A name is required");
      return value;
    })
    .query(({ input }) => ({ message: `Hello, ${input}`, at: new Date(0) })),
  numbers: t.procedure.query(async function* () {
    yield 1;
    yield 2;
    yield 3;
  }),
  ticks: t.procedure.subscription(async function* () {
    yield tracked("a", 1);
    yield tracked("b", 2);
  }),
});

const orpcRouter = {
  echo: os.handler(({ input }) => input),
  ticker: os.handler(async function* () {
    yield 1;
    yield 2;
  }),
};

const sessionSecret = "swiftui-svelte-test-secret-0123456789";

describe("packages in a swiftui-svelte host", () => {
  let trpcUrl = "";
  let orpcUrl = "";
  let authUrl = "";
  const servers: Array<Server> = [];

  beforeAll(async () => {
    installWebAPIs();
    Object.defineProperties(globalThis, {
      navigator: { value: createNavigator(), configurable: true },
      EventSource: {
        value: createEventSource(nodeFetch),
        configurable: true,
        writable: true,
      },
    });
    connectQueryManagers({ focusManager, onlineManager });

    const trpc = createHTTPServer({
      router: trpcRouter,
      createContext: () => ({}),
    });
    servers.push(trpc);
    trpcUrl = await listen(trpc);

    const rpc = new RPCHandler(orpcRouter);
    const orpc = createServer((request, response) => {
      void rpc
        .handle(request, response, { prefix: "/rpc", context: {} })
        .then(({ matched }) => {
          if (matched) {
            return;
          }

          response.statusCode = 404;
          response.end();
        });
    });
    servers.push(orpc);
    orpcUrl = `${await listen(orpc)}/rpc`;

    const auth = createServer();
    servers.push(auth);
    const origin = await listen(auth);
    const handler = betterAuth({
      baseURL: origin,
      secret: sessionSecret,
      emailAndPassword: { enabled: true },
      advanced: { disableOriginCheck: false },
    });
    const handle = toNodeHandler(handler);
    auth.on("request", (request, response) => void handle(request, response));
    authUrl = origin;
  });

  afterAll(() => {
    for (const server of servers) server.close();
  });

  it("tRPC batches, streams, and superjson-encodes queries over fetch", async () => {
    let requests = 0;
    const batch = createTRPCClient<typeof trpcRouter>({
      links: [
        httpBatchLink({
          url: trpcUrl,
          transformer: superjson,
          fetch: async (input, init) => {
            requests++;
            return fetch(input, init);
          },
        }),
      ],
    });
    const [ada, lin] = await Promise.all([
      batch.greet.query("Ada"),
      batch.greet.query("Lin"),
    ]);
    expect(ada).toEqual({ message: "Hello, Ada", at: new Date(0) });
    expect(lin.message).toBe("Hello, Lin");
    expect(requests).toBe(1);

    const single = createTRPCClient<typeof trpcRouter>({
      links: [httpLink({ url: trpcUrl, transformer: superjson })],
    });
    const grace = await single.greet.query("Grace");
    expect(grace.message).toBe("Hello, Grace");

    const streamed = createTRPCClient<typeof trpcRouter>({
      links: [httpBatchStreamLink({ url: trpcUrl, transformer: superjson })],
    });
    const expected = [1, 2, 3];
    let index = 0;
    const stream = await streamed.numbers.query();
    for await (const value of stream) {
      expect(value).toBe(expected[index]);
      index += 1;
    }
    expect(index).toBe(expected.length);
  });

  it("tRPC subscriptions run over the host's EventSource", async () => {
    const subscriptions = createTRPCClient<typeof trpcRouter>({
      links: [httpSubscriptionLink({ url: trpcUrl, transformer: superjson })],
    });
    const received = await new Promise<Array<unknown>>((resolve, reject) => {
      const values: Array<unknown> = [];
      subscriptions.ticks.subscribe(undefined, {
        onData: (value) => {
          values.push(value);
        },
        onComplete: () => resolve(values),
        onError: reject,
      });
    });
    expect(received).toEqual([
      { id: "a", data: 1 },
      { id: "b", data: 2 },
    ]);
  });

  it("oRPC calls procedures and reads event iterators over fetch", async () => {
    const client = createORPCClient<RouterClient<typeof orpcRouter>>(
      new RPCLink({ url: orpcUrl }),
    );
    expect(await client.echo({ word: "hi" })).toEqual({ word: "hi" });
    const expected = [1, 2];
    let index = 0;
    const ticks = await client.ticker();
    for await (const value of ticks) {
      expect(value).toBe(expected[index]);
      index += 1;
    }
    expect(index).toBe(expected.length);
  });

  it("better Auth rejects POSTs without an Origin header, so the client sends one", async () => {
    cookies.clear();
    const email = "ada@example.com";
    const password = "correct horse battery staple";
    const bare = createAuthClient({
      baseURL: authUrl,
      fetchOptions: { customFetchImpl: jarFetch },
    });
    const rejected = await bare.signUp.email({ name: "Ada", email, password });
    expect(rejected.error?.status).toBe(403);
    expect(rejected.error?.code).toBe("MISSING_OR_NULL_ORIGIN");

    const native = createAuthClient({
      baseURL: authUrl,
      fetchOptions: { customFetchImpl: jarFetch, headers: { Origin: authUrl } },
    });
    const store = native.useSession();
    const created = await native.signUp.email({ name: "Ada", email, password });
    expect(created.error).toBeNull();
    const signedIn = await native.signIn.email({ email, password });
    expect(signedIn.error).toBeNull();
    expect(cookies.size).toBeGreaterThan(0);
    await vi.waitFor(() => expect(store.get().data?.user.email).toBe(email));

    const other = createAuthClient({
      baseURL: authUrl,
      fetchOptions: { customFetchImpl: jarFetch, headers: { Origin: authUrl } },
    });
    const leftBehind = await other.signOut();
    expect(leftBehind.error).toBeNull();
    expect(store.get().data?.user.email).toBe(email);
    const stopForeground = onActive(() => void store.get().refetch());
    updateEnvironment({ scenePhase: "background" });
    updateEnvironment({ scenePhase: "active" });
    await vi.waitFor(() => expect(store.get().data).toBeNull());
    stopForeground();
  });

  it("tanStack Query refetches stale queries when the app returns to the foreground", async () => {
    const client = new QueryClient();
    client.mount();
    let fetches = 0;
    const observer = new QueryObserver(client, {
      queryKey: ["count"],
      queryFn: () => ++fetches,
      staleTime: 0,
    });
    const unsubscribe = observer.subscribe(() => {});
    await vi.waitFor(() => expect(fetches).toBe(1));

    updateEnvironment({ scenePhase: "background" });
    expect(focusManager.isFocused()).toBe(false);
    updateEnvironment({ scenePhase: "active" });
    expect(focusManager.isFocused()).toBe(true);
    await vi.waitFor(() => expect(fetches).toBe(2));
    unsubscribe();
    client.unmount();
  });

  it("tanStack Query's online manager follows navigator.onLine and the online and offline events", () => {
    const unsubscribe = onlineManager.subscribe(() => {});
    updateEnvironment({ onLine: false });
    expect(onlineManager.isOnline()).toBe(false);
    updateEnvironment({ onLine: true });
    expect(onlineManager.isOnline()).toBe(true);
    unsubscribe();
  });
});
