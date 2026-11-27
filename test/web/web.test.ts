import { Buffer } from "node:buffer";
import { createHash, webcrypto } from "node:crypto";
import { afterAll, beforeAll, describe, it } from "vitest";
import type { NativeFetchBridge } from "swiftui-svelte/web/fetch";
import type { NativeWebSocketBridge } from "swiftui-svelte/web/websocket";
import { AbortControllerShim, AbortSignalShim } from "swiftui-svelte/web/abort";
import { BlobShim, FileShim } from "swiftui-svelte/web/blob";
import { structuredCloneShim } from "swiftui-svelte/web/clone";
import { createCrypto } from "swiftui-svelte/web/crypto";
import {
  atobShim,
  btoaShim,
  TextDecoderShim,
  TextEncoderShim,
} from "swiftui-svelte/web/encoding";
import {
  createNavigator,
  environment,
  matchMediaShim,
  updateEnvironment,
} from "swiftui-svelte/web/environment";
import {
  CustomEventShim,
  DOMExceptionShim,
  EventShim,
  EventTargetShim,
} from "swiftui-svelte/web/events";
import { createEventSource } from "swiftui-svelte/web/eventsource";
import {
  createFetch,
  FormDataShim,
  HeadersShim,
  RequestShim,
  ResponseShim,
} from "swiftui-svelte/web/fetch";
import { createPerformance } from "swiftui-svelte/web/performance";
import { createStorage } from "swiftui-svelte/web/storage";
import {
  ByteLengthQueuingStrategy as ByteLengthQueuingStrategyShim,
  CountQueuingStrategy as CountQueuingStrategyShim,
  ReadableStream as ReadableStreamShim,
  TextDecoderStreamShim,
  TextEncoderStreamShim,
  TransformStream as TransformStreamShim,
  WritableStream as WritableStreamShim,
} from "swiftui-svelte/web/streams";
import { URLSearchParamsShim, URLShim } from "swiftui-svelte/web/url";
import { createWebSocket } from "swiftui-svelte/web/websocket";
import type { Server, Web } from "./suite.ts";
import { startServer } from "./server.ts";
import { cases, hostCases } from "./suite.ts";

const fetches = new Map<number, AbortController>();
const cookieJar = new Map<string, string>();
const fetchBridge: NativeFetchBridge = {
  start(id, json, body, onResponse, onData, onEnd) {
    const request = JSON.parse(json) as {
      url: string;
      method: string;
      headers: Array<[string, string]>;
      redirect: RequestRedirect;
      credentials: RequestCredentials;
    };
    const hasCredentials = request.credentials === "include";
    const controller = new AbortController();
    fetches.set(id, controller);
    void (async () => {
      try {
        const headers = [...request.headers];
        if (hasCredentials && cookieJar.size > 0)
          headers.push([
            "cookie",
            [...cookieJar]
              .map(([name, value]) => `${name}=${value}`)
              .join("; "),
          ]);
        const response = await fetch(request.url, {
          method: request.method,
          headers,
          body: body == null ? undefined : Buffer.from(body),
          redirect: request.redirect,
          signal: controller.signal,
        });
        if (
          request.redirect === "manual" &&
          response.status >= 300 &&
          response.status < 400
        ) {
          onResponse(
            JSON.stringify({
              status: 0,
              type: "opaqueredirect",
              url: request.url,
              redirected: false,
              headers: [],
            }),
          );
          onEnd(null);
          return;
        }
        const setCookies = hasCredentials
          ? response.headers.getSetCookie()
          : [];
        for (const header of setCookies) {
          const [pair = ""] = header.split(";", 1);
          const [name = "", ...value] = pair.split("=");
          cookieJar.set(name, value.join("="));
        }
        onResponse(
          JSON.stringify({
            status: response.status,
            url: response.url,
            redirected: response.redirected,
            headers: [...response.headers],
          }),
        );
        if (response.body != null)
          for await (const chunk of response.body)
            onData(new Uint8Array(chunk));
        onEnd(null);
      } catch (error) {
        if (!controller.signal.aborted) onEnd({ message: String(error) });
      } finally {
        fetches.delete(id);
      }
    })();
  },
  cancel: (id) => fetches.get(id)?.abort(),
};

const sockets = new Map<number, WebSocket>();
const socketBridge: NativeWebSocketBridge = {
  open(id, url, protocols, handlers) {
    const socket = new WebSocket(url, JSON.parse(protocols) as Array<string>);
    socket.binaryType = "arraybuffer";
    sockets.set(id, socket);
    socket.addEventListener("open", () => handlers.open(socket.protocol));
    socket.addEventListener(
      "message",
      (event: MessageEvent<string | ArrayBuffer>) =>
        handlers.message(
          typeof event.data === "string"
            ? event.data
            : new Uint8Array(event.data),
        ),
    );
    socket.addEventListener("error", () =>
      handlers.error("The connection failed"),
    );
    socket.addEventListener("close", (event) => {
      sockets.delete(id);
      handlers.close(event.code, event.reason, event.wasClean);
    });
  },
  send(id, data) {
    sockets.get(id)?.send(data);
  },
  close(id, code, reason) {
    sockets.get(id)?.close(code ?? undefined, reason);
  },
};

const target = new EventTargetShim();

const shimFetch = createFetch(fetchBridge);
const shimValues: unknown = {
  DOMException: DOMExceptionShim,
  Event: EventShim,
  EventTarget: EventTargetShim,
  CustomEvent: CustomEventShim,
  AbortController: AbortControllerShim,
  AbortSignal: AbortSignalShim,
  TextEncoder: TextEncoderShim,
  TextDecoder: TextDecoderShim,
  atob: atobShim,
  btoa: btoaShim,
  URL: URLShim,
  URLSearchParams: URLSearchParamsShim,
  structuredClone: structuredCloneShim,
  ReadableStream: ReadableStreamShim,
  WritableStream: WritableStreamShim,
  TransformStream: TransformStreamShim,
  TextEncoderStream: TextEncoderStreamShim,
  TextDecoderStream: TextDecoderStreamShim,
  CountQueuingStrategy: CountQueuingStrategyShim,
  ByteLengthQueuingStrategy: ByteLengthQueuingStrategyShim,
  Blob: BlobShim,
  File: FileShim,
  FormData: FormDataShim,
  Headers: HeadersShim,
  Request: RequestShim,
  Response: ResponseShim,
  fetch: shimFetch,
  WebSocket: createWebSocket(socketBridge),
  EventSource: createEventSource(shimFetch),
  crypto: createCrypto({
    fill: (bytes) => void webcrypto.getRandomValues(bytes),
    digest: (algorithm, data) =>
      new Uint8Array(
        createHash(algorithm.replace("-", "").toLowerCase())
          .update(data)
          .digest(),
      ),
  }),
  performance: createPerformance(() => performance.now()),
  navigator: createNavigator(),
  host: {
    sessionStorage: createStorage([]),
    matchMedia: matchMediaShim,
    onLine: () => environment.onLine,
    addEventListener: (type: string, listener: (event: Event) => void) =>
      target.addEventListener(type, listener as never),
    removeEventListener: (type: string, listener: (event: Event) => void) =>
      target.removeEventListener(type, listener as never),
    setEnvironment: (changes: Record<string, unknown>) => {
      const isBefore = environment.onLine;
      updateEnvironment(changes);
      if (isBefore !== environment.onLine)
        target.dispatchEvent(
          new EventShim(environment.onLine ? "online" : "offline"),
        );
    },
    globals: {
      window: Reflect.get(globalThis, "window"),
      self: Reflect.get(globalThis, "self"),
      global: globalThis,
    },
  },
};
const shims = shimValues as Web;

const natives: Web = {
  DOMException,
  Event,
  EventTarget,
  CustomEvent,
  AbortController,
  AbortSignal,
  TextEncoder,
  TextDecoder,
  atob,
  btoa,
  URL,
  URLSearchParams,
  structuredClone,
  ReadableStream,
  WritableStream,
  TransformStream,
  TextEncoderStream,
  TextDecoderStream,
  CountQueuingStrategy,
  ByteLengthQueuingStrategy,
  Blob,
  File,
  FormData,
  Headers,
  Request,
  Response,
  fetch,
  WebSocket,
  crypto: webcrypto as Crypto,
  performance,
  navigator,
};

let server: Server & { close: () => Promise<void> };

beforeAll(async () => {
  server = await startServer();
});

afterAll(async () => {
  await server.close();
});

for (const [mode, web] of [
  ["Node's built-in APIs", natives],
  ["the shims", shims],
] as const) {
  describe(`web APIs with ${mode}`, () => {
    for (const { name, run } of cases) {
      const isSkip = web === natives && hostCases.has(name);
      it.skipIf(isSkip)(name, async () => {
        await run(web, server);
      });
    }
  });
}
