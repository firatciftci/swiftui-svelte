import type { RequestInitShim, ResponseShim } from "./fetch.ts";
import type { ByteStream } from "./streams.ts";
import { DOMExceptionShim, EventShim, EventTargetShim } from "./events.ts";
import { URLShim } from "./url.ts";
import { MessageEventShim } from "./websocket.ts";

type Fetch = (input: string, init: RequestInitShim) => Promise<ResponseShim>;

const DEFAULT_RETRY = 3000;
const LINE_END = /\r\n|\r|\n/;
const fetches = new WeakMap<object, Fetch>();

class EventSourceShim extends EventTargetShim {
  static readonly CONNECTING = 0;
  static readonly OPEN = 1;
  static readonly CLOSED = 2;
  #fetch: Fetch;
  #readyState = 0;
  #origin: string;
  #lastEventId = "";
  #retry = DEFAULT_RETRY;
  #controller: AbortController | null = null;
  #timer: ReturnType<typeof setTimeout> | null = null;
  #eventType = "";
  #data: Array<string> = [];
  #pending = "";
  #pendingLineEnd = false;
  readonly CONNECTING = 0;
  readonly OPEN = 1;
  readonly CLOSED = 2;
  readonly url: string;
  readonly withCredentials: boolean;
  onopen: ((event: EventShim) => unknown) | null = null;
  onmessage: ((event: MessageEventShim) => unknown) | null = null;
  onerror: ((event: EventShim) => unknown) | null = null;

  constructor(url: string | URL, init: { withCredentials?: boolean } = {}) {
    super();
    const fetchImpl = fetches.get(new.target);
    if (fetchImpl == null) throw new TypeError("Illegal constructor");
    this.#fetch = fetchImpl;
    let parsed: URLShim;
    try {
      parsed = new URLShim(String(url));
    } catch {
      throw new DOMExceptionShim(
        `Failed to construct 'EventSource': The URL '${String(url)}' is invalid.`,
        "SyntaxError",
      );
    }
    this.url = parsed.href;
    this.#origin = parsed.origin;
    this.withCredentials = init.withCredentials ?? false;
    void this.#connect();
  }

  #abort(): void {
    this.#controller?.abort();
    this.#controller = null;
    if (this.#timer != null) clearTimeout(this.#timer);
    this.#timer = null;
  }

  async #connect(): Promise<void> {
    const controller = new AbortController();
    this.#controller = controller;
    const headers: Record<string, string> = {
      Accept: "text/event-stream",
      "Cache-Control": "no-cache",
    };
    if (this.#lastEventId !== "") headers["Last-Event-ID"] = this.#lastEventId;
    let response: ResponseShim;
    try {
      response = await this.#fetch(this.url, {
        headers,
        cache: "no-store",
        credentials: this.withCredentials ? "include" : "same-origin",
        signal: controller.signal,
      });
    } catch {
      this.#reconnect(controller);
      return;
    }
    this.#receive(response, controller);
  }

  #receive(response: ResponseShim, controller: AbortController): void {
    if (controller.signal.aborted) return;
    const type = response.headers.get("content-type") ?? "";
    const mime = type.split(";", 1)[0]?.trim().toLowerCase();
    if (mime !== "text/event-stream" || response.status !== 200) {
      this.#fail(controller);
      return;
    }
    this.#readyState = 1;
    this.dispatchEvent(new EventShim("open"));
    const body = response.body;
    if (body == null) {
      this.#reconnect(controller);
      return;
    }
    void this.#read(body, controller);
  }

  async #read(body: ByteStream, controller: AbortController): Promise<void> {
    const decoder = new TextDecoder();
    const reader = body.getReader();
    this.#pending = "";
    this.#pendingLineEnd = false;
    this.#eventType = "";
    this.#data = [];
    try {
      let chunk = await reader.read();
      while (!chunk.done) {
        if (controller.signal.aborted) return;
        if (chunk.value instanceof Uint8Array)
          this.#parse(decoder.decode(chunk.value, { stream: true }));
        chunk = await reader.read();
      }
      this.#reconnect(controller);
    } catch {
      this.#reconnect(controller);
    }
  }

  #parse(chunk: string): void {
    let text = chunk;
    if (this.#pendingLineEnd && text.startsWith("\n")) text = text.slice(1);
    this.#pendingLineEnd = text.endsWith("\r");
    const pieces = (this.#pending + text).split(LINE_END);
    this.#pending = pieces.pop() ?? "";
    for (const line of pieces) {
      if (this.#readyState === 2) return;
      this.#line(line);
    }
  }

  #line(line: string): void {
    if (line === "") {
      this.#dispatch();
      return;
    }
    if (line.startsWith(":")) return;
    const colon = line.indexOf(":");
    const field = colon === -1 ? line : line.slice(0, colon);
    let value = colon === -1 ? "" : line.slice(colon + 1);
    if (value.startsWith(" ")) value = value.slice(1);
    switch (field) {
      case "event": {
        this.#eventType = value;
        break;
      }
      case "data": {
        this.#data.push(value);
        break;
      }
      case "id": {
        if (!value.includes("\0")) this.#lastEventId = value;

        break;
      }
      default: {
        if (field === "retry" && /^\d+$/.test(value)) {
          this.#retry = Number(value);
        }
      }
    }
  }

  #dispatch(): void {
    const type = this.#eventType === "" ? "message" : this.#eventType;
    const lines = this.#data;
    this.#eventType = "";
    this.#data = [];
    if (lines.length === 0 || this.#readyState === 2) return;
    this.dispatchEvent(
      new MessageEventShim(type, {
        data: lines.join("\n"),
        origin: this.#origin,
        lastEventId: this.#lastEventId,
      }),
    );
  }

  #fail(controller: AbortController): void {
    if (controller.signal.aborted) return;
    this.#abort();
    this.#readyState = 2;
    this.dispatchEvent(new EventShim("error"));
  }

  #reconnect(controller: AbortController): void {
    if (this.#readyState === 2 || controller.signal.aborted) return;
    this.#abort();
    this.#readyState = 0;
    this.dispatchEvent(new EventShim("error"));
    if (this.#readyState !== 0) return;
    this.#timer = setTimeout(() => {
      this.#timer = null;
      if (this.#readyState === 0) void this.#connect();
    }, this.#retry);
  }

  get readyState(): number {
    return this.#readyState;
  }

  close(): void {
    this.#readyState = 2;
    this.#abort();
  }
}

export function createEventSource(fetch: Fetch): typeof EventSourceShim {
  const EventSource = class EventSource extends EventSourceShim {};
  fetches.set(EventSource, fetch);
  return EventSource;
}
