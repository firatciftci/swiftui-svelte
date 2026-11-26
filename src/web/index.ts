import type { HostEnvironment } from "./environment.ts";
import { AbortControllerShim, AbortSignalShim } from "./abort.ts";
import { BlobShim, FileShim } from "./blob.ts";
import { structuredCloneShim } from "./clone.ts";
import { createCrypto } from "./crypto.ts";
import {
  atobShim,
  btoaShim,
  TextDecoderShim,
  TextEncoderShim,
} from "./encoding.ts";
import {
  createNavigator,
  environment,
  matchMediaShim,
  MediaQueryListEventShim,
  MediaQueryListShim,
  observeEnvironment,
  updateEnvironment,
} from "./environment.ts";
import {
  CustomEventShim,
  DOMExceptionShim,
  EventShim,
  EventTargetShim,
} from "./events.ts";
import { createEventSource } from "./eventsource.ts";
import {
  createFetch,
  FormDataShim,
  HeadersShim,
  RequestShim,
  ResponseShim,
} from "./fetch.ts";
import { createPerformance } from "./performance.ts";
import { createStorage } from "./storage.ts";
import {
  ByteLengthQueuingStrategy,
  CountQueuingStrategy,
  ReadableByteStreamController,
  ReadableStream,
  ReadableStreamBYOBReader,
  ReadableStreamBYOBRequest,
  ReadableStreamDefaultController,
  ReadableStreamDefaultReader,
  TextDecoderStreamShim,
  TextEncoderStreamShim,
  TransformStream,
  TransformStreamDefaultController,
  WritableStream,
  WritableStreamDefaultController,
  WritableStreamDefaultWriter,
} from "./streams.ts";
import { URLSearchParamsShim, URLShim } from "./url.ts";
import {
  CloseEventShim,
  createWebSocket,
  MessageEventShim,
} from "./websocket.ts";

function hostJSON(json: string): unknown {
  try {
    return JSON.parse(json) as unknown;
  } catch (error) {
    reportError(error);
    return null;
  }
}

function define(name: string, create: () => unknown): void {
  if (Reflect.has(globalThis, name)) return;
  const value = create();
  if (typeof value === "function" && value.name !== name)
    Object.defineProperty(value, "name", { value: name, configurable: true });
  Object.defineProperty(globalThis, name, {
    value,
    writable: true,
    configurable: true,
    enumerable: false,
  });
}

export function installWebAPIs(): void {
  define("reportError", () => (error: unknown) => {
    console.error(error);
  });
  define("window", () => globalThis);
  define("self", () => globalThis);
  define("DOMException", () => DOMExceptionShim);
  define("Event", () => EventShim);
  define("EventTarget", () => EventTargetShim);
  define("CustomEvent", () => CustomEventShim);
  define("MessageEvent", () => MessageEventShim);
  define("CloseEvent", () => CloseEventShim);
  define("AbortController", () => AbortControllerShim);
  define("AbortSignal", () => AbortSignalShim);
  define("TextEncoder", () => TextEncoderShim);
  define("TextDecoder", () => TextDecoderShim);
  define("atob", () => atobShim);
  define("btoa", () => btoaShim);
  define("URL", () => URLShim);
  define("URLSearchParams", () => URLSearchParamsShim);
  define("Blob", () => BlobShim);
  define("File", () => FileShim);
  define("FormData", () => FormDataShim);
  define("Headers", () => HeadersShim);
  define("Request", () => RequestShim);
  define("Response", () => ResponseShim);
  define("structuredClone", () => structuredCloneShim);
  const streams = {
    ReadableStream,
    ReadableStreamDefaultReader,
    ReadableStreamBYOBReader,
    ReadableStreamDefaultController,
    ReadableByteStreamController,
    ReadableStreamBYOBRequest,
    WritableStream,
    WritableStreamDefaultWriter,
    WritableStreamDefaultController,
    TransformStream,
    TransformStreamDefaultController,
    ByteLengthQueuingStrategy,
    CountQueuingStrategy,
    TextEncoderStream: TextEncoderStreamShim,
    TextDecoderStream: TextDecoderStreamShim,
  };
  for (const [name, value] of Object.entries(streams))
    define(name, () => value);
  define("performance", () =>
    createPerformance(
      typeof __nativeNow === "function" ? __nativeNow : Date.now,
    ),
  );
  define("sessionStorage", () => createStorage([]));
  define("navigator", createNavigator);
  define("matchMedia", () => matchMediaShim);
  define("MediaQueryList", () => MediaQueryListShim);
  define("MediaQueryListEvent", () => MediaQueryListEventShim);

  if (
    typeof __nativeRandomFill === "function" &&
    typeof __nativeDigest === "function"
  ) {
    define("crypto", () =>
      createCrypto({ fill: __nativeRandomFill, digest: __nativeDigest }),
    );
  }
  if (typeof __nativeFetch === "function") {
    const fetchShim = createFetch({
      start: __nativeFetch,
      cancel: __nativeFetchCancel,
    });
    define("fetch", () => fetchShim);
    define("EventSource", () => createEventSource(fetchShim));
  }
  if (typeof __nativeWebSocketOpen === "function") {
    define("WebSocket", () =>
      createWebSocket({
        open: __nativeWebSocketOpen,
        send: __nativeWebSocketSend,
        close: __nativeWebSocketClose,
      }),
    );
  }
  if (typeof __nativeStorageLoad === "function") {
    define("localStorage", () => {
      const loaded = hostJSON(__nativeStorageLoad());
      const entries: Array<[string, string]> = [];
      if (loaded != null && typeof loaded === "object") {
        for (const [key, value] of Object.entries(loaded))
          if (typeof value === "string") entries.push([key, value]);
      }
      let isSaving = false;
      return createStorage(entries, (items) => {
        if (isSaving) return;
        isSaving = true;
        queueMicrotask(() => {
          isSaving = false;
          try {
            __nativeStorageSave(JSON.stringify(Object.fromEntries(items)));
          } catch (error) {
            reportError(error);
          }
        });
      });
    });
  }

  if (!("addEventListener" in globalThis)) {
    const target = globalThis;
    const prototype = EventTargetShim.prototype;
    const methods = {
      addEventListener: (
        ...args: Parameters<EventTargetShim["addEventListener"]>
      ): void => prototype.addEventListener.apply(target, args),
      removeEventListener: (
        ...args: Parameters<EventTargetShim["removeEventListener"]>
      ): void => prototype.removeEventListener.apply(target, args),
      dispatchEvent: (event: Event): boolean =>
        prototype.dispatchEvent.call(target, event),
    };
    for (const [name, method] of Object.entries(methods))
      define(name, () => method);
    observeEnvironment((previous) => {
      if (previous.onLine !== environment.onLine) {
        prototype.dispatchEvent.call(
          target,
          new EventShim(environment.onLine ? "online" : "offline"),
        );
      }
    });
  }

  if (typeof __nativeEnvironment === "function") {
    updateEnvironment(
      hostJSON(__nativeEnvironment()) as Partial<HostEnvironment>,
    );
  }
  globalThis.__svelteEnvironment = (json) =>
    updateEnvironment(hostJSON(json) as Partial<HostEnvironment>);
}
