declare function __nativeCommit(json: string, animation?: string): void;
declare function __nativeNow(): number;
declare var __nativeProtocols: Array<number> | undefined;
declare function __nativeInvoke(id: number, method: string, json: string): void;
declare var __svelteReply: (
  request: number,
  rect: { x: number; y: number; width: number; height: number } | null,
) => void;
declare function __nativeGC(): void;
declare function __nativeRequestFrame(): void;
declare var __svelteFrame: (time: number) => void;
declare function __nativeStats(): {
  nodes: number;
  maxFrameGapMs: number;
  applyMs: number;
};
declare function __nativeLog(
  level: "log" | "info" | "warn" | "error" | "debug",
  message: string,
): void;
declare var __nativeDiagnostic: ((json: string) => void) | undefined;
declare var __svelteBundle: { version: string; protocol: number };
declare var __svelteDispatch: (
  id: number,
  type: string,
  payload: unknown,
  request?: number,
) => void;
declare var __svelteMount: (
  mountId: number,
  name: string,
  json: string,
) => void;
declare var __svelteProps: (
  mountId: number,
  json: string,
  actions?: string,
) => void;
declare var __svelteUnmount: (mountId: number) => void;
declare function __nativeAction(
  mountId: number,
  name: string,
  json: string,
): void;
declare function __nativeStorageLoad(): string;
declare function __nativeStorageSave(json: string): void;
declare function __nativeRandomFill(bytes: Uint8Array<ArrayBuffer>): void;
declare function __nativeDigest(
  algorithm: string,
  data: Uint8Array<ArrayBuffer>,
): Uint8Array;
declare function __nativeEnvironment(): string;
declare var __svelteEnvironment: (json: string) => void;
declare var __svelteAppEvent: (type: string, payload: unknown) => void;
declare function __nativeFetch(
  id: number,
  request: string,
  body: Uint8Array<ArrayBuffer> | null,
  onResponse: (meta: string) => void,
  onData: (chunk: Uint8Array) => void,
  onEnd: (
    failure: { message: string; code?: number; name?: string } | null,
  ) => void,
): void;
declare function __nativeFetchCancel(id: number): void;
declare function __nativeWebSocketOpen(
  id: number,
  url: string,
  protocols: string,
  handlers: {
    open: (protocol: string) => void;
    message: (data: string | Uint8Array) => void;
    sent: (bytes: number) => void;
    close: (code: number, reason: string, wasClean: boolean) => void;
    error: (message: string) => void;
  },
): void;
declare function __nativeWebSocketSend(
  id: number,
  data: string | Uint8Array<ArrayBuffer>,
): void;
declare function __nativeWebSocketClose(
  id: number,
  code: number | null,
  reason: string,
): void;
declare function __nativeCall(
  id: number,
  module: string,
  method: string,
  json: string,
): void;
declare function __svelteNativeReply(
  id: number,
  error: string | null,
  json: string | null,
): void;
declare function __svelteNativeEvent(
  module: string,
  event: string,
  json: string | null,
): void;
