import "swiftui-svelte/host";
import type { Web } from "./suite.ts";
import { runCases } from "./suite.ts";

declare global {
  function __nativeReport(json: string): void;
  var __runWebSuite: (json: string) => void;
}

const web: Web = {
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
  crypto,
  performance,
  navigator,
  host: {
    sessionStorage,
    matchMedia,
    onLine: () => navigator.onLine,
    addEventListener: (type, listener) => addEventListener(type, listener),
    removeEventListener: (type, listener) =>
      removeEventListener(type, listener),
    setEnvironment: (changes) => __svelteEnvironment(JSON.stringify(changes)),
  },
};

globalThis.__runWebSuite = (json) => {
  void runCases(web, JSON.parse(json) as { http: string; ws: string }).then(
    (results) => __nativeReport(JSON.stringify(results)),
  );
};
