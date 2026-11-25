import { AbortSignalShim } from "./abort.ts";
import { blobBytes, BlobShim, FileShim } from "./blob.ts";
import {
  base64Decode,
  bytesOf,
  encodeUTF8,
  TextDecoderShim,
} from "./encoding.ts";
import { isIterable } from "./iterable.ts";
import { ReadableStreamShim, readAll } from "./streams.ts";
import {
  compareCodeUnits,
  formEncoding,
  URLSearchParamsShim,
  URLShim,
} from "./url.ts";

const token = /^[!#$%&'*+\-.^\w`|~]+$/;

function normalizeValue(value: unknown): string {
  const text = String(value).replaceAll(/^[\t\n\r ]+|[\t\n\r ]+$/g, "");
  if (/[\0\n\r]/.test(text))
    throw new TypeError(`Invalid header value: ${JSON.stringify(text)}`);
  return text;
}

function normalizeName(name: unknown): string {
  const text = String(name);
  if (!token.test(text))
    throw new TypeError(`Invalid header name: ${JSON.stringify(text)}`);
  return text.toLowerCase();
}

type HeadersInitShim =
  | HeadersShim
  | Iterable<Iterable<string>>
  | Record<string, string>;

const guards = new WeakMap<HeadersShim, "none" | "immutable">();

export class HeadersShim {
  static freeze(headers: HeadersShim): HeadersShim {
    guards.set(headers, "immutable");
    return headers;
  }

  #list: Array<[string, string]> = [];

  constructor(init?: HeadersInitShim) {
    guards.set(this, "none");
    if (init == null) return;
    if (init instanceof HeadersShim) {
      for (const [name, value] of init.#list) this.#list.push([name, value]);
    } else if (isIterable(init)) {
      for (const pair of init) {
        if (!isIterable(pair))
          throw new TypeError(
            "Each header pair must be an iterable [name, value] tuple",
          );
        const values = [...pair].map(String);
        if (values.length !== 2)
          throw new TypeError(
            "Each header pair must be an iterable [name, value] tuple",
          );
        this.append(values[0] ?? "", values[1] ?? "");
      }
    } else {
      for (const [name, value] of Object.entries(init))
        this.append(name, value);
    }
  }

  #check(): void {
    if (guards.get(this) === "immutable") throw new TypeError("immutable");
  }

  append(name: string, value: string): void {
    const key = normalizeName(name);
    const text = normalizeValue(value);
    this.#check();
    this.#list.push([key, text]);
  }

  delete(name: string): void {
    const key = normalizeName(name);
    this.#check();
    this.#list = this.#list.filter(([entry]) => entry !== key);
  }

  get(name: string): string | null {
    const key = normalizeName(name);
    const values = this.#list
      .filter(([entry]) => entry === key)
      .map(([, value]) => value);
    return values.length === 0 ? null : values.join(", ");
  }

  getSetCookie(): Array<string> {
    return this.#list
      .filter(([name]) => name === "set-cookie")
      .map(([, value]) => value);
  }

  has(name: string): boolean {
    const key = normalizeName(name);
    return this.#list.some(([entry]) => entry === key);
  }

  set(name: string, value: string): void {
    const key = normalizeName(name);
    const text = normalizeValue(value);
    this.#check();
    const index = this.#list.findIndex(([entry]) => entry === key);
    if (index === -1) {
      this.#list.push([key, text]);
      return;
    }
    this.#list[index] = [key, text];
    this.#list = this.#list.filter(
      ([entry], position) => position <= index || entry !== key,
    );
  }

  forEach(
    callback: (value: string, name: string, headers: HeadersShim) => void,
    thisArg?: unknown,
  ): void {
    for (const [name, value] of this.entries())
      callback.call(thisArg, value, name, this);
  }

  *entries(): Generator<[string, string], undefined, unknown> {
    const names = [...new Set(this.#list.map(([name]) => name))].toSorted(
      compareCodeUnits,
    );
    for (const name of names) {
      if (name === "set-cookie") {
        for (const value of this.getSetCookie()) yield [name, value];
      } else {
        const value = this.get(name);
        if (value != null) yield [name, value];
      }
    }
  }

  *keys(): Generator<string, undefined, unknown> {
    for (const [name] of this.entries()) yield name;
  }

  *values(): Generator<string, undefined, unknown> {
    for (const [, value] of this.entries()) yield value;
  }

  [Symbol.iterator](): Generator<[string, string], undefined, unknown> {
    return this.entries();
  }

  get [Symbol.toStringTag](): string {
    return "Headers";
  }
}

type FormValue = string | FileShim;

function toFormValue(value: string | BlobShim, filename?: string): FormValue {
  if (!(value instanceof BlobShim)) return value;
  if (filename === undefined && value instanceof FileShim) return value;
  return new FileShim(
    [value],
    filename ?? (value instanceof FileShim ? value.name : "blob"),
    {
      type: value.type,
      lastModified: value instanceof FileShim ? value.lastModified : undefined,
    },
  );
}

export class FormDataShim {
  #list: Array<[string, FormValue]> = [];

  append(name: string, value: string | BlobShim, filename?: string): void {
    this.#list.push([name, toFormValue(value, filename)]);
  }

  delete(name: string): void {
    this.#list = this.#list.filter(([entry]) => entry !== name);
  }

  get(name: string): FormValue | null {
    return this.#list.find(([entry]) => entry === name)?.[1] ?? null;
  }

  getAll(name: string): Array<FormValue> {
    return this.#list
      .filter(([entry]) => entry === name)
      .map(([, value]) => value);
  }

  has(name: string): boolean {
    return this.#list.some(([entry]) => entry === name);
  }

  set(name: string, value: string | BlobShim, filename?: string): void {
    const entry: [string, FormValue] = [name, toFormValue(value, filename)];
    const index = this.#list.findIndex(([existing]) => existing === name);
    if (index === -1) {
      this.#list.push(entry);
      return;
    }
    this.#list[index] = entry;
    this.#list = this.#list.filter(
      ([existing], position) => position <= index || existing !== name,
    );
  }

  forEach(
    callback: (value: FormValue, name: string, form: FormDataShim) => void,
    thisArg?: unknown,
  ): void {
    for (const [name, value] of this.#list)
      callback.call(thisArg, value, name, this);
  }

  *entries(): Generator<[string, FormValue], undefined, unknown> {
    for (let index = 0; index < this.#list.length; index++) {
      const entry = this.#list[index];
      if (entry != null) yield [entry[0], entry[1]];
    }
  }

  *keys(): Generator<string, undefined, unknown> {
    for (const [name] of this.entries()) yield name;
  }

  *values(): Generator<FormValue, undefined, unknown> {
    for (const [, value] of this.entries()) yield value;
  }

  [Symbol.iterator](): Generator<[string, FormValue], undefined, unknown> {
    return this.entries();
  }

  get [Symbol.toStringTag](): string {
    return "FormData";
  }
}

function randomDigits(): string {
  let digits = "";
  for (let index = 0; index < 12; index++)
    digits += String(Math.floor(Math.random() * 10));
  return digits;
}

function escapeName(name: string): string {
  return name
    .replaceAll("\n", "%0A")
    .replaceAll("\r", "%0D")
    .replaceAll('"', "%22");
}

function serializeMultipart(
  form: FormDataShim,
  boundary: string,
): Uint8Array<ArrayBuffer> {
  const parts: Array<Uint8Array> = [];
  for (const [name, value] of form) {
    let header = `--${boundary}\r\nContent-Disposition: form-data; name="${escapeName(name.replaceAll(/\r\n|\r|\n/g, "\r\n"))}"`;
    if (typeof value === "string") {
      parts.push(
        encodeUTF8(
          `${header}\r\n\r\n${value.replaceAll(/\r\n|\r|\n/g, "\r\n")}\r\n`,
        ),
      );
    } else {
      header += `; filename="${escapeName(value.name)}"\r\nContent-Type: ${value.type === "" ? "application/octet-stream" : value.type}\r\n\r\n`;
      parts.push(encodeUTF8(header), blobBytes(value), encodeUTF8("\r\n"));
    }
  }
  parts.push(encodeUTF8(`--${boundary}--\r\n`));
  return concat(parts);
}

function concat(parts: Array<Uint8Array>): Uint8Array<ArrayBuffer> {
  let length = 0;
  for (const part of parts) length += part.length;
  const output = new Uint8Array(length);
  let offset = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.length;
  }
  return output;
}

function isMatchAt(
  haystack: Uint8Array,
  needle: Uint8Array,
  index: number,
): boolean {
  for (const [offset, element] of needle.entries()) {
    if (haystack[index + offset] !== element) return false;
  }
  return true;
}

function indexOf(
  haystack: Uint8Array,
  needle: Uint8Array,
  from: number,
): number {
  for (let index = from; index <= haystack.length - needle.length; index++) {
    if (isMatchAt(haystack, needle, index)) return index;
  }
  return -1;
}

function parseMultipart(bytes: Uint8Array, boundary: string): FormDataShim {
  const form = new FormDataShim();
  const delimiter = encodeUTF8(`--${boundary}`);
  const decoder = new TextDecoderShim();
  let position = indexOf(bytes, delimiter, 0);
  if (position === -1)
    throw new TypeError("Failed to parse the body as FormData");
  for (;;) {
    position += delimiter.length;
    if (bytes[position] === 0x2d && bytes[position + 1] === 0x2d) break;
    position += 2;
    const headerEnd = indexOf(bytes, encodeUTF8("\r\n\r\n"), position);
    if (headerEnd === -1)
      throw new TypeError("Failed to parse the body as FormData");
    const headers = decoder
      .decode(bytes.subarray(position, headerEnd))
      .split("\r\n");
    const next = indexOf(bytes, delimiter, headerEnd + 4);
    if (next === -1)
      throw new TypeError("Failed to parse the body as FormData");
    const body = bytes.subarray(headerEnd + 4, next - 2);
    let name: string | null = null;
    let filename: string | null = null;
    let type = "";
    for (const line of headers) {
      const colon = line.indexOf(":");
      const key = line.slice(0, colon).trim().toLowerCase();
      const value = line.slice(colon + 1).trim();
      if (key === "content-disposition") {
        name = /\bname="([^"]*)"/.exec(value)?.[1] ?? null;
        filename = /\bfilename="([^"]*)"/.exec(value)?.[1] ?? null;
      } else if (key === "content-type") {
        type = value;
      }
    }
    if (name == null)
      throw new TypeError("Failed to parse the body as FormData");
    if (filename == null) form.append(name, decoder.decode(body));
    else
      form.append(
        name,
        new FileShim([new Uint8Array(body)], filename, { type }),
      );
    position = next;
  }
  return form;
}

type BodySource =
  | Uint8Array<ArrayBuffer>
  | ReadableStreamShim<Uint8Array>
  | null;
type BodyState = {
  source: BodySource;
  used: boolean;
  stream: ReadableStreamShim<Uint8Array> | null;
};

const bodies = new WeakMap<object, BodyState>();

export type BodyInitShim =
  | string
  | BlobShim
  | ArrayBuffer
  | ArrayBufferView
  | URLSearchParamsShim
  | URLSearchParams
  | FormDataShim
  | ReadableStreamShim<Uint8Array>
  | null;

function extractBody(init: BodyInitShim | undefined): {
  source: BodySource;
  type: string | null;
} {
  if (init == null) return { source: null, type: null };
  if (typeof init === "string")
    return { source: encodeUTF8(init), type: "text/plain;charset=UTF-8" };
  if (init instanceof BlobShim)
    return {
      source: blobBytes(init),
      type: init.type === "" ? null : init.type,
    };
  if (init instanceof ArrayBuffer || ArrayBuffer.isView(init))
    return { source: new Uint8Array(bytesOf(init)), type: null };
  if (
    init instanceof URLSearchParamsShim ||
    (typeof URLSearchParams === "function" && init instanceof URLSearchParams)
  ) {
    return {
      source: encodeUTF8(init.toString()),
      type: "application/x-www-form-urlencoded;charset=UTF-8",
    };
  }
  if (init instanceof FormDataShim) {
    const boundary = `----formdata-swiftui-${randomDigits()}`;
    return {
      source: serializeMultipart(init, boundary),
      type: `multipart/form-data; boundary=${boundary}`,
    };
  }
  if (init instanceof ReadableStreamShim) return { source: init, type: null };
  return { source: encodeUTF8(String(init)), type: "text/plain;charset=UTF-8" };
}

function state(target: object): BodyState {
  const value = bodies.get(target);
  if (value == null) throw new TypeError("Illegal invocation");
  return value;
}

async function consume(target: BodyShim): Promise<Uint8Array<ArrayBuffer>> {
  const body = state(target);
  const stream =
    body.source instanceof ReadableStreamShim ? body.source : body.stream;
  if (target.bodyUsed || stream?.locked === true)
    throw new TypeError("Body is unusable: Body has already been read");
  body.used = true;
  if (body.source == null) return new Uint8Array();
  if (body.source instanceof ReadableStreamShim) return readAll(body.source);
  return new Uint8Array(body.source);
}

abstract class BodyShim {
  abstract readonly headers: HeadersShim;

  get body(): ReadableStreamShim<Uint8Array> | null {
    const body = state(this);
    if (body.source == null) return null;
    if (body.source instanceof ReadableStreamShim) return body.source;
    if (body.stream == null) {
      const bytes = body.source;
      body.stream = new ReadableStreamShim<Uint8Array>({
        start(controller) {
          if (bytes.length > 0) controller.enqueue(new Uint8Array(bytes));
          controller.close();
        },
      });
    }
    return body.stream;
  }

  get bodyUsed(): boolean {
    const body = state(this);
    const stream =
      body.source instanceof ReadableStreamShim ? body.source : body.stream;
    return body.used || stream?.disturbed === true;
  }

  async arrayBuffer(): Promise<ArrayBuffer> {
    const bytes = await consume(this);
    return bytes.buffer;
  }

  async bytes(): Promise<Uint8Array<ArrayBuffer>> {
    return consume(this);
  }

  async blob(): Promise<BlobShim> {
    return new BlobShim([await consume(this)], {
      type: this.headers.get("content-type") ?? "",
    });
  }

  async text(): Promise<string> {
    return new TextDecoderShim().decode(await consume(this));
  }

  async json(): Promise<unknown> {
    return JSON.parse(await this.text());
  }

  async formData(): Promise<FormDataShim> {
    const type = this.headers.get("content-type") ?? "";
    const bytes = await consume(this);
    if (/^multipart\/form-data/i.test(type)) {
      const boundary = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(type);
      const value = boundary?.[1] ?? boundary?.[2];
      if (value == null) throw new TypeError("Missing multipart boundary");
      return parseMultipart(bytes, value.trim());
    }
    if (/^application\/x-www-form-urlencoded/i.test(type)) {
      const form = new FormDataShim();
      const entries = formEncoding.parse(new TextDecoderShim().decode(bytes));
      for (const [name, value] of entries) form.append(name, value);
      return form;
    }
    throw new TypeError("Could not parse content as FormData");
  }
}

function cloneBody(source: object, target: object): void {
  const body = state(source);
  if (
    body.used ||
    (body.source instanceof ReadableStreamShim && body.source.locked)
  ) {
    throw new TypeError("Body has already been consumed");
  }
  if (body.source instanceof ReadableStreamShim) {
    const [left, right] = body.source.tee();
    body.source = left;
    bodies.set(target, { source: right, used: false, stream: null });
  } else {
    bodies.set(target, { source: body.source, used: false, stream: null });
  }
}

const methods = new Set(["DELETE", "GET", "HEAD", "OPTIONS", "POST", "PUT"]);

type RequestInitShim = {
  method?: string;
  headers?: HeadersInitShim;
  body?: BodyInitShim;
  redirect?: RequestRedirect;
  credentials?: RequestCredentials;
  cache?: RequestCache;
  mode?: RequestMode;
  referrer?: string;
  referrerPolicy?: ReferrerPolicy;
  integrity?: string;
  keepalive?: boolean;
  signal?: AbortSignalShim | AbortSignal | null;
  duplex?: "half";
  priority?: RequestPriority;
};

export class RequestShim extends BodyShim {
  readonly url: string;
  readonly method: string;
  readonly headers: HeadersShim;
  readonly redirect: RequestRedirect;
  readonly credentials: RequestCredentials;
  readonly cache: RequestCache;
  readonly mode: RequestMode;
  readonly referrer: string;
  readonly referrerPolicy: ReferrerPolicy;
  readonly integrity: string;
  readonly keepalive: boolean;
  readonly signal: AbortSignalShim;
  readonly destination = "";
  readonly duplex = "half";

  constructor(
    input: string | URLShim | URL | RequestShim,
    init: RequestInitShim = {},
  ) {
    super();
    const source = input instanceof RequestShim ? input : null;
    let url: URLShim;
    try {
      url = new URLShim(source?.url ?? String(input));
    } catch (error) {
      throw new TypeError(`Failed to parse URL from ${String(input)}`, {
        cause: error,
      });
    }
    if (url.username !== "" || url.password !== "") {
      throw new TypeError(
        `Request cannot be constructed from a URL that includes credentials: ${url.href}`,
      );
    }
    this.url = url.href;
    let method = init.method ?? source?.method ?? "GET";
    if (!token.test(method))
      throw new TypeError(`'${method}' is not a valid HTTP method.`);
    const upper = method.toUpperCase();
    if (["CONNECT", "TRACE", "TRACK"].includes(upper)) {
      throw new TypeError(`'${method}' HTTP method is unsupported.`);
    }
    if (methods.has(upper)) method = upper;
    this.method = method;
    this.headers = new HeadersShim(init.headers ?? source?.headers);
    this.redirect = init.redirect ?? source?.redirect ?? "follow";
    this.credentials = init.credentials ?? source?.credentials ?? "same-origin";
    this.cache = init.cache ?? source?.cache ?? "default";
    this.mode = init.mode ?? source?.mode ?? "cors";
    this.referrer = init.referrer ?? source?.referrer ?? "about:client";
    this.referrerPolicy = init.referrerPolicy ?? source?.referrerPolicy ?? "";
    this.integrity = init.integrity ?? source?.integrity ?? "";
    this.keepalive = init.keepalive ?? source?.keepalive ?? false;
    const signals = [init.signal ?? source?.signal].filter(
      (signal) => signal != null,
    );
    this.signal = AbortSignalShim.any(signals);
    const hasBody =
      init.body != null ||
      (init.body === undefined &&
        source != null &&
        state(source).source != null);
    if (hasBody && (method === "GET" || method === "HEAD")) {
      throw new TypeError("Request with GET/HEAD method cannot have body.");
    }
    if (init.body !== undefined) {
      const { source: body, type } = extractBody(init.body);
      if (type != null && !this.headers.has("content-type"))
        this.headers.append("content-type", type);
      bodies.set(this, { source: body, used: false, stream: null });
    } else if (source != null) {
      const body = state(source);
      if (source.bodyUsed)
        throw new TypeError(
          "Cannot construct a Request with a Request object that has already been used.",
        );
      bodies.set(this, { source: body.source, used: false, stream: null });
      if (body.source != null) body.used = true;
    } else {
      bodies.set(this, { source: null, used: false, stream: null });
    }
  }

  clone(): RequestShim {
    const copy = new RequestShim(this.url, {
      method: this.method,
      headers: this.headers,
      redirect: this.redirect,
      credentials: this.credentials,
      cache: this.cache,
      mode: this.mode,
      referrer: this.referrer,
      referrerPolicy: this.referrerPolicy,
      integrity: this.integrity,
      keepalive: this.keepalive,
      signal: this.signal,
    });
    cloneBody(this, copy);
    return copy;
  }

  get [Symbol.toStringTag](): string {
    return "Request";
  }
}

const reasons = new Map<number, string>([
  [100, "Continue"],
  [101, "Switching Protocols"],
  [200, "OK"],
  [201, "Created"],
  [202, "Accepted"],
  [203, "Non-Authoritative Information"],
  [204, "No Content"],
  [205, "Reset Content"],
  [206, "Partial Content"],
  [300, "Multiple Choices"],
  [301, "Moved Permanently"],
  [302, "Found"],
  [303, "See Other"],
  [304, "Not Modified"],
  [307, "Temporary Redirect"],
  [308, "Permanent Redirect"],
  [400, "Bad Request"],
  [401, "Unauthorized"],
  [402, "Payment Required"],
  [403, "Forbidden"],
  [404, "Not Found"],
  [405, "Method Not Allowed"],
  [406, "Not Acceptable"],
  [407, "Proxy Authentication Required"],
  [408, "Request Timeout"],
  [409, "Conflict"],
  [410, "Gone"],
  [411, "Length Required"],
  [412, "Precondition Failed"],
  [413, "Payload Too Large"],
  [414, "URI Too Long"],
  [415, "Unsupported Media Type"],
  [416, "Range Not Satisfiable"],
  [417, "Expectation Failed"],
  [418, "I'm a Teapot"],
  [421, "Misdirected Request"],
  [422, "Unprocessable Entity"],
  [423, "Locked"],
  [424, "Failed Dependency"],
  [425, "Too Early"],
  [426, "Upgrade Required"],
  [428, "Precondition Required"],
  [429, "Too Many Requests"],
  [431, "Request Header Fields Too Large"],
  [451, "Unavailable For Legal Reasons"],
  [500, "Internal Server Error"],
  [501, "Not Implemented"],
  [502, "Bad Gateway"],
  [503, "Service Unavailable"],
  [504, "Gateway Timeout"],
  [505, "HTTP Version Not Supported"],
  [506, "Variant Also Negotiates"],
  [507, "Insufficient Storage"],
  [508, "Loop Detected"],
  [510, "Not Extended"],
  [511, "Network Authentication Required"],
]);

const nullBodyStatuses = new Set([101, 103, 204, 205, 304]);
const redirectStatuses = new Set([301, 302, 303, 307, 308]);

type ResponseMeta = { type: ResponseType; url: string; redirected: boolean };
const metas = new WeakMap<ResponseShim, ResponseMeta>();

export class ResponseShim extends BodyShim {
  static error(): ResponseShim {
    const response = Object.create(this.prototype) as ResponseShim;
    Object.assign(response, {
      status: 0,
      statusText: "",
      headers: HeadersShim.freeze(new HeadersShim()),
    });
    metas.set(response, { type: "error", url: "", redirected: false });
    bodies.set(response, { source: null, used: false, stream: null });
    return response;
  }

  static redirect(url: string | URLShim | URL, status = 302): ResponseShim {
    const parsed = new URLShim(String(url));
    if (!redirectStatuses.has(status))
      throw new RangeError(`Invalid status code ${String(status)}`);
    const response = new ResponseShim(null, {
      status,
      headers: { location: parsed.href },
    });
    HeadersShim.freeze(response.headers);
    return response;
  }

  static json(
    data: unknown,
    init: ResponseInit & { headers?: HeadersInitShim } = {},
  ): ResponseShim {
    const text: unknown = JSON.stringify(data);
    if (typeof text !== "string")
      throw new TypeError("Value is not JSON serializable");
    const response = new ResponseShim(text, init);
    response.headers.set("content-type", "application/json");
    return response;
  }

  static native(
    meta: {
      status: number;
      url: string;
      redirected: boolean;
      headers: Array<[string, string]>;
    },
    body: ReadableStreamShim<Uint8Array> | Uint8Array<ArrayBuffer> | null,
  ): ResponseShim {
    const response = Object.create(this.prototype) as ResponseShim;
    const headers = new HeadersShim();
    for (const [name, value] of meta.headers) {
      try {
        headers.append(name, value);
      } catch {
        continue;
      }
    }
    Object.assign(response, {
      status: meta.status,
      statusText: reasons.get(meta.status) ?? "",
      headers: HeadersShim.freeze(headers),
    });
    metas.set(response, {
      type: "basic",
      url: meta.url,
      redirected: meta.redirected,
    });
    bodies.set(response, {
      source: nullBodyStatuses.has(meta.status) ? null : body,
      used: false,
      stream: null,
    });
    return response;
  }

  readonly status: number;
  readonly statusText: string;
  readonly headers: HeadersShim;

  constructor(
    body?: BodyInitShim,
    init: ResponseInit & { headers?: HeadersInitShim } = {},
  ) {
    super();
    const status = init.status ?? 200;
    if (!Number.isSafeInteger(status) || status < 200 || status > 599) {
      throw new RangeError(
        `init["status"] must be in the range of 200 to 599, inclusive.`,
      );
    }
    const statusText = init.statusText ?? "";
    if (!/^[\t\x20-\x7E\x80-\xFF]*$/.test(statusText))
      throw new TypeError("Invalid statusText");
    this.status = status;
    this.statusText = statusText;
    this.headers = new HeadersShim(init.headers);
    metas.set(this, { type: "default", url: "", redirected: false });
    if (body != null && nullBodyStatuses.has(status))
      throw new TypeError("Response with null body status cannot have body");
    const { source, type } = extractBody(body);
    if (type != null && !this.headers.has("content-type"))
      this.headers.append("content-type", type);
    bodies.set(this, { source, used: false, stream: null });
  }

  get type(): ResponseType {
    return metas.get(this)?.type ?? "default";
  }

  get url(): string {
    return metas.get(this)?.url ?? "";
  }

  get redirected(): boolean {
    return metas.get(this)?.redirected ?? false;
  }

  get ok(): boolean {
    return this.status >= 200 && this.status <= 299;
  }

  clone(): ResponseShim {
    const copy = Object.create(ResponseShim.prototype) as ResponseShim;
    const headers = new HeadersShim(this.headers);
    if (guards.get(this.headers) === "immutable") HeadersShim.freeze(headers);
    Object.assign(copy, {
      status: this.status,
      statusText: this.statusText,
      headers,
    });
    metas.set(copy, {
      ...(metas.get(this) ?? { type: "default", url: "", redirected: false }),
    });
    cloneBody(this, copy);
    return copy;
  }

  get [Symbol.toStringTag](): string {
    return "Response";
  }
}

export type NativeFetchBridge = {
  start: (
    id: number,
    request: string,
    body: Uint8Array<ArrayBuffer> | null,
    onResponse: (meta: string) => void,
    onData: (chunk: Uint8Array) => void,
    onEnd: (error: string | null) => void,
  ) => void;
  cancel: (id: number) => void;
};

function fetchData(url: URLShim): ResponseShim {
  const href = url.href.slice(5);
  const comma = href.indexOf(",");
  if (comma === -1) throw new TypeError("fetch failed: invalid data URL");
  let type = href.slice(0, comma).trim();
  let body = href.slice(comma + 1);
  const hash = body.indexOf("#");
  if (hash !== -1) body = body.slice(0, hash);
  let bytes: Uint8Array<ArrayBuffer> = Uint8Array.from(
    decodeURIComponentBytes(body),
  );
  if (/;\s*base64\s*$/i.test(type)) {
    type = type.replace(/;\s*base64\s*$/i, "");
    bytes = base64Decode(String.fromCharCode(...bytes));
  }
  if (type.startsWith(";")) type = `text/plain${type}`;
  if (type === "") type = "text/plain;charset=US-ASCII";
  return ResponseShim.native(
    {
      status: 200,
      url: url.href,
      redirected: false,
      headers: [["content-type", type]],
    },
    bytes,
  );
}

function decodeURIComponentBytes(text: string): Array<number> {
  const bytes = encodeUTF8(text);
  const output: Array<number> = [];
  for (let index = 0; index < bytes.length; index++) {
    const byte = bytes[index] ?? 0;
    const pair = String.fromCharCode(
      bytes[index + 1] ?? 0,
      bytes[index + 2] ?? 0,
    );
    if (byte === 0x25 && /^[0-9a-f]{2}$/i.test(pair)) {
      output.push(Number.parseInt(pair, 16));
      index += 2;
    } else {
      output.push(byte);
    }
  }
  return output;
}

const fetchIds = { next: 1 };

export function createFetch(native: NativeFetchBridge) {
  return async function fetch(
    input: string | URLShim | URL | RequestShim,
    init?: RequestInitShim,
  ): Promise<ResponseShim> {
    const request = new RequestShim(input, init);
    const { signal } = request;
    signal.throwIfAborted();
    const url = new URLShim(request.url);
    if (url.protocol === "data:") return fetchData(url);
    if (
      url.protocol !== "http:" &&
      url.protocol !== "https:" &&
      url.protocol !== "file:"
    ) {
      throw new TypeError(
        `fetch failed: the ${url.protocol} scheme is not supported`,
      );
    }
    const body = request.body == null ? null : await request.bytes();
    signal.throwIfAborted();
    const id = fetchIds.next++;
    const { promise, resolve, reject } = Promise.withResolvers<ResponseShim>();
    let controller: {
      enqueue: (chunk: Uint8Array) => void;
      close: () => void;
      error: (reason: unknown) => void;
    } | null = null;
    let isFinished = false;
    const onAbort = (): void => {
      if (isFinished) return;
      isFinished = true;
      native.cancel(id);
      reject(signal.reason);
      controller?.error(signal.reason);
    };
    signal.addEventListener("abort", onAbort, { once: true });
    native.start(
      id,
      JSON.stringify({
        url: request.url,
        method: request.method,
        headers: [...request.headers],
        redirect: request.redirect,
        credentials: request.credentials,
        cache: request.cache,
      }),
      body,
      (json) => {
        if (isFinished) return;
        const meta = JSON.parse(json) as {
          status: number;
          url: string;
          redirected: boolean;
          headers: Array<[string, string]>;
        };
        const stream = new ReadableStreamShim<Uint8Array>({
          start(streamController) {
            controller = streamController;
          },
          cancel() {
            if (isFinished) return;
            isFinished = true;
            native.cancel(id);
          },
        });
        resolve(ResponseShim.native(meta, stream));
      },
      (chunk) => {
        if (!isFinished) controller?.enqueue(chunk);
      },
      (error) => {
        if (isFinished) return;
        isFinished = true;
        signal.removeEventListener("abort", onAbort);
        if (error == null) {
          controller?.close();
        } else {
          const failure = new TypeError("fetch failed", {
            cause: new Error(error),
          });
          reject(failure);
          controller?.error(failure);
        }
      },
    );
    return promise;
  };
}
