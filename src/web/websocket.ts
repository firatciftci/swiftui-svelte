import { blobBytes, BlobShim } from "./blob.ts";
import { bytesOf, encodeUTF8 } from "./encoding.ts";
import { DOMExceptionShim, EventShim, EventTargetShim } from "./events.ts";
import { URLShim } from "./url.ts";

export class MessageEventShim<T = unknown> extends EventShim {
  readonly data: T | null;
  readonly origin: string;
  readonly lastEventId: string;
  readonly source = null;
  readonly ports: ReadonlyArray<never> = [];

  constructor(
    type: string,
    init: { data?: T; origin?: string; lastEventId?: string } & EventInit = {},
  ) {
    super(type, init);
    this.data = init.data ?? null;
    this.origin = init.origin ?? "";
    this.lastEventId = init.lastEventId ?? "";
  }
}

export class CloseEventShim extends EventShim {
  readonly code: number;
  readonly reason: string;
  readonly wasClean: boolean;

  constructor(
    type: string,
    init: {
      code?: number;
      reason?: string;
      wasClean?: boolean;
    } & EventInit = {},
  ) {
    super(type, init);
    this.code = init.code ?? 0;
    this.reason = init.reason ?? "";
    this.wasClean = Boolean(init.wasClean);
  }
}

type WebSocketHandlers = {
  open: (protocol: string) => void;
  message: (data: string | Uint8Array) => void;
  sent: (bytes: number) => void;
  close: (code: number, reason: string, wasClean: boolean) => void;
  error: (message: string) => void;
};

export type NativeWebSocketBridge = {
  open: (
    id: number,
    url: string,
    protocols: string,
    handlers: WebSocketHandlers,
  ) => void;
  send: (id: number, data: string | Uint8Array<ArrayBuffer>) => void;
  close: (id: number, code: number | null, reason: string) => void;
};

const token = /^[!#$%&'*+\-.^\w`|~]+$/;
const socketIds = { next: 1 };
const bridges = new WeakMap<object, NativeWebSocketBridge>();

class WebSocketShim extends EventTargetShim {
  static readonly CONNECTING = 0;
  static readonly OPEN = 1;
  static readonly CLOSING = 2;
  static readonly CLOSED = 3;
  #native: NativeWebSocketBridge;
  #id = socketIds.next++;
  #readyState = 0;
  #protocol = "";
  #binaryType: BinaryType = "blob";
  #bufferedAmount = 0;
  #origin: string;
  readonly CONNECTING = 0;
  readonly OPEN = 1;
  readonly CLOSING = 2;
  readonly CLOSED = 3;
  readonly url: string;
  readonly extensions = "";
  onopen: ((event: EventShim) => unknown) | null = null;
  onmessage: ((event: MessageEventShim) => unknown) | null = null;
  onerror: ((event: EventShim) => unknown) | null = null;
  onclose: ((event: CloseEventShim) => unknown) | null = null;

  constructor(
    url: string | URLShim | URL,
    protocols: string | Array<string> = [],
  ) {
    super();
    const native = bridges.get(new.target);
    if (native == null) throw new TypeError("Illegal constructor");
    this.#native = native;
    let parsed: URLShim;
    try {
      parsed = new URLShim(String(url));
    } catch {
      throw new DOMExceptionShim(
        `Failed to construct 'WebSocket': The URL '${String(url)}' is invalid.`,
        "SyntaxError",
      );
    }
    if (parsed.protocol === "http:") parsed.protocol = "ws:";
    else if (parsed.protocol === "https:") parsed.protocol = "wss:";
    if (parsed.protocol !== "ws:" && parsed.protocol !== "wss:") {
      throw new DOMExceptionShim(
        `Failed to construct 'WebSocket': The URL's scheme must be either 'ws' or 'wss'.`,
        "SyntaxError",
      );
    }
    if (parsed.hash !== "" || parsed.href.endsWith("#")) {
      throw new DOMExceptionShim(
        "Failed to construct 'WebSocket': The URL contains a fragment identifier.",
        "SyntaxError",
      );
    }
    const list = typeof protocols === "string" ? [protocols] : [...protocols];
    if (
      new Set(list).size !== list.length ||
      list.some((value) => !token.test(value))
    ) {
      throw new DOMExceptionShim(
        "Failed to construct 'WebSocket': The subprotocol is invalid.",
        "SyntaxError",
      );
    }
    this.url = parsed.href;
    this.#origin = parsed.origin;
    native.open(this.#id, this.url, JSON.stringify(list), {
      open: (protocol) => {
        if (this.#readyState !== 0) return;
        this.#readyState = 1;
        this.#protocol = protocol;
        this.dispatchEvent(new EventShim("open"));
      },
      message: (data) => {
        if (this.#readyState !== 1 && this.#readyState !== 2) return;
        let value: string | ArrayBuffer | BlobShim = data as string;
        if (typeof data !== "string")
          value =
            this.#binaryType === "arraybuffer"
              ? new Uint8Array(data).buffer
              : new BlobShim([data]);
        this.dispatchEvent(
          new MessageEventShim("message", {
            data: value,
            origin: this.#origin,
          }),
        );
      },
      sent: (bytes) => {
        this.#bufferedAmount = Math.max(0, this.#bufferedAmount - bytes);
      },
      close: (code, reason, wasClean) => {
        if (this.#readyState === 3) return;
        this.#readyState = 3;
        this.dispatchEvent(
          new CloseEventShim("close", { code, reason, wasClean }),
        );
      },
      error: () => {
        if (this.#readyState === 3) return;
        this.dispatchEvent(new EventShim("error"));
      },
    });
  }

  get readyState(): number {
    return this.#readyState;
  }

  get protocol(): string {
    return this.#protocol;
  }

  get bufferedAmount(): number {
    return this.#bufferedAmount;
  }

  get binaryType(): BinaryType {
    return this.#binaryType;
  }

  set binaryType(value: BinaryType) {
    const candidate: string = value;
    if (candidate === "blob" || candidate === "arraybuffer")
      this.#binaryType = candidate;
  }

  send(data: string | ArrayBuffer | ArrayBufferView | BlobShim): void {
    if (this.#readyState === 0) {
      throw new DOMExceptionShim(
        "Failed to execute 'send' on 'WebSocket': Still in CONNECTING state.",
        "InvalidStateError",
      );
    }
    let payload: string | Uint8Array<ArrayBuffer>;
    let size: number;
    if (typeof data === "string") {
      payload = data;
      size = encodeUTF8(data).length;
    } else if (data instanceof BlobShim) {
      payload = new Uint8Array(blobBytes(data));
      size = payload.length;
    } else if (data instanceof ArrayBuffer || ArrayBuffer.isView(data)) {
      payload = new Uint8Array(bytesOf(data));
      size = payload.length;
    } else {
      payload = String(data);
      size = encodeUTF8(payload).length;
    }
    this.#bufferedAmount += size;
    if (this.#readyState !== 1) return;
    this.#native.send(this.#id, payload);
  }

  close(code?: number, reason?: string): void {
    if (code !== undefined && code !== 1000 && (code < 3000 || code > 4999)) {
      throw new DOMExceptionShim(
        `Failed to execute 'close' on 'WebSocket': The close code must be either 1000, or between 3000 and 4999. ${String(code)} is neither.`,
        "InvalidAccessError",
      );
    }
    const text = reason ?? "";
    if (encodeUTF8(text).length > 123) {
      throw new DOMExceptionShim(
        "Failed to execute 'close' on 'WebSocket': The close reason must not be greater than 123 UTF-8 bytes.",
        "SyntaxError",
      );
    }
    if (this.#readyState === 2 || this.#readyState === 3) return;
    const wasConnecting = this.#readyState === 0;
    this.#readyState = 2;
    if (wasConnecting) {
      this.#native.close(this.#id, null, text);
      void Promise.resolve().then(() => {
        this.#readyState = 3;
        this.dispatchEvent(new EventShim("error"));
        this.dispatchEvent(
          new CloseEventShim("close", {
            code: 1006,
            reason: "",
            wasClean: false,
          }),
        );
      });
      return;
    }
    this.#native.close(this.#id, code ?? null, text);
  }

  get [Symbol.toStringTag](): string {
    return "WebSocket";
  }
}

export function createWebSocket(
  native: NativeWebSocketBridge,
): typeof WebSocketShim {
  const WebSocket = class WebSocket extends WebSocketShim {};
  bridges.set(WebSocket, native);
  return WebSocket;
}
