import {
  collect,
  deep,
  delay,
  equal,
  hex,
  ok,
  rejects,
  throws,
} from "./assert.ts";
import setterData from "./wpt/setters_tests.json" with { type: "json" };
import urlData from "./wpt/urltestdata.json" with { type: "json" };

export type Web = {
  DOMException: typeof DOMException;
  Event: typeof Event;
  EventTarget: typeof EventTarget;
  CustomEvent: typeof CustomEvent;
  AbortController: typeof AbortController;
  AbortSignal: typeof AbortSignal;
  TextEncoder: typeof TextEncoder;
  TextDecoder: typeof TextDecoder;
  atob: typeof atob;
  btoa: typeof btoa;
  URL: typeof URL;
  URLSearchParams: typeof URLSearchParams;
  structuredClone: typeof structuredClone;
  Blob: typeof Blob;
  File: typeof File;
  FormData: typeof FormData;
  Headers: typeof Headers;
  Request: typeof Request;
  Response: typeof Response;
  fetch: typeof fetch;
  WebSocket: typeof WebSocket;
  crypto: Pick<Crypto, "getRandomValues" | "randomUUID" | "subtle">;
  performance: Pick<
    Performance,
    | "now"
    | "timeOrigin"
    | "mark"
    | "measure"
    | "getEntriesByName"
    | "getEntriesByType"
    | "clearMarks"
    | "clearMeasures"
  >;
  navigator: Pick<Navigator, "language" | "languages">;
  host?: {
    sessionStorage: Storage;
    matchMedia: (query: string) => MediaQueryList;
    onLine: () => boolean;
    addEventListener: (type: string, listener: (event: Event) => void) => void;
    removeEventListener: (
      type: string,
      listener: (event: Event) => void,
    ) => void;
    setEnvironment: (changes: Record<string, unknown>) => void;
  };
};

export type Server = { http: string; ws: string };

export type Case = { name: string; run: (web: Web, server: Server) => unknown };

type Host = NonNullable<Web["host"]>;

function host(web: Web): Host {
  if (web.host == null) throw new Error("This case needs the host environment");
  return web.host;
}

export const cases: Array<Case> = [];
export const hostCases = new Set<string>();

function test(name: string, run: Case["run"]): void {
  cases.push({ name, run });
}

function hostTest(name: string, run: Case["run"]): void {
  hostCases.add(name);
  cases.push({ name, run });
}

test("events dispatch to listeners in order, once, and deduplicated", (web) => {
  const target = new web.EventTarget();
  const calls: Array<string> = [];
  const first = (): void => void calls.push("first");
  target.addEventListener("ping", first);
  target.addEventListener("ping", first);
  target.addEventListener(
    "ping",
    () => {
      calls.push("once");
    },
    { once: true },
  );
  target.addEventListener("ping", {
    handleEvent: () => {
      calls.push("object");
    },
  });
  equal(target.dispatchEvent(new web.Event("ping")), true);
  target.dispatchEvent(new web.Event("ping"));
  deep(calls, ["first", "once", "object", "first", "object"]);
  target.removeEventListener("ping", first);
  target.dispatchEvent(new web.Event("ping"));
  deep(calls, ["first", "once", "object", "first", "object", "object"]);
});

test("events support preventDefault, stopImmediatePropagation, and signals", (web) => {
  const target = new web.EventTarget();
  const controller = new web.AbortController();
  let seen = 0;
  target.addEventListener("go", (event) => {
    event.preventDefault();
    event.stopImmediatePropagation();
  });
  target.addEventListener("go", () => seen++);
  target.addEventListener("other", () => seen++, { signal: controller.signal });
  const cancelable = new web.Event("go", { cancelable: true });
  equal(target.dispatchEvent(cancelable), false);
  equal(cancelable.defaultPrevented, true);
  equal(target.dispatchEvent(new web.Event("go")), true);
  equal(seen, 0);
  target.dispatchEvent(new web.Event("other"));
  controller.abort();
  target.dispatchEvent(new web.Event("other"));
  equal(seen, 1);
});

test("events expose their target, type, and flags", (web) => {
  const target = new web.EventTarget();
  let current: unknown = null;
  const event = new web.Event("look", { bubbles: true, cancelable: true });
  target.addEventListener("look", (received) => {
    current = received.currentTarget;
    equal(received.eventPhase, 2);
  });
  target.dispatchEvent(event);
  equal(current, target);
  equal(event.target, target);
  equal(event.currentTarget, null);
  equal(event.type, "look");
  equal(event.bubbles, true);
  equal(event.cancelable, true);
  equal(event.isTrusted, false);
});

test("CustomEvent carries detail", (web) => {
  const target = new web.EventTarget();
  let detail: unknown;
  target.addEventListener(
    "custom",
    (event) => (detail = (event as CustomEvent<{ id: number }>).detail),
  );
  target.dispatchEvent(new web.CustomEvent("custom", { detail: { id: 7 } }));
  deep(detail, { id: 7 });
  equal(new web.CustomEvent("empty").detail, null);
});

test("DOMException has a name, message, and legacy code", (web) => {
  const error = new web.DOMException("Gone", "AbortError");
  equal(error.name, "AbortError");
  equal(error.message, "Gone");
  equal(Reflect.get(error, "code"), 20);
  equal(Reflect.get(new web.DOMException("x", "CustomError"), "code"), 0);
  ok(error instanceof Error, "DOMException is an Error");
});

test("AbortController aborts once with an AbortError by default", (web) => {
  const controller = new web.AbortController();
  let events = 0;
  controller.signal.addEventListener("abort", () => events++);
  equal(controller.signal.aborted, false);
  controller.abort();
  controller.abort("again");
  equal(events, 1);
  equal(controller.signal.aborted, true);
  equal((controller.signal.reason as Error).name, "AbortError");
  throws(() => controller.signal.throwIfAborted(), "AbortError");
});

test("AbortSignal.abort, timeout, and any", async (web) => {
  equal(web.AbortSignal.abort("why").reason, "why");
  const timeout = web.AbortSignal.timeout(10);
  equal(timeout.aborted, false);
  await delay(40);
  equal(timeout.aborted, true);
  equal((timeout.reason as Error).name, "TimeoutError");
  const controller = new web.AbortController();
  const combined = web.AbortSignal.any([
    controller.signal,
    web.AbortSignal.timeout(10_000),
  ]);
  controller.abort("first");
  equal(combined.aborted, true);
  equal(combined.reason, "first");
  equal(web.AbortSignal.any([web.AbortSignal.abort("done")]).reason, "done");
});

test("TextEncoder encodes UTF-8, including astral and lone surrogates", (web) => {
  const encoder = new web.TextEncoder();
  equal(encoder.encoding, "utf-8");
  equal(hex(encoder.encode("aé€😀")), "61c3a9e282acf09f9880");
  equal(hex(encoder.encode("\u{D800}x")), "efbfbd78");
  equal(encoder.encode().length, 0);
  const target = new Uint8Array(5);
  deep(encoder.encodeInto("a😀b", target), { read: 3, written: 5 });
  deep(encoder.encodeInto("😀😀", new Uint8Array(6)), { read: 2, written: 4 });
});

test("TextDecoder decodes UTF-8, handles errors, the BOM, and streaming", (web) => {
  const decoder = new web.TextDecoder();
  const bytes = new web.TextEncoder().encode("Merhaba dünya 🌍");
  equal(decoder.decode(bytes), "Merhaba dünya 🌍");
  equal(decoder.decode(new Uint8Array([0xef, 0xbb, 0xbf, 0x41])), "A");
  equal(
    new web.TextDecoder("utf-8", { ignoreBOM: true }).decode(
      new Uint8Array([0xef, 0xbb, 0xbf, 0x41]),
    ),
    "\u{FEFF}A",
  );
  equal(
    decoder.decode(new Uint8Array([0x41, 0xff, 0x42, 0xe2, 0x82])),
    "A\u{FFFD}B\u{FFFD}",
  );
  equal(decoder.decode(new Uint8Array([0xf0, 0x9f, 0x98])), "\u{FFFD}");
  throws(
    () =>
      new web.TextDecoder("utf-8", { fatal: true }).decode(
        new Uint8Array([0xc3]),
      ),
    "TypeError",
  );
  const stream = new web.TextDecoder();
  equal(
    stream.decode(new Uint8Array([0xf0, 0x9f]), { stream: true }) +
      stream.decode(new Uint8Array([0x98, 0x80])),
    "😀",
  );
  equal(decoder.decode(bytes.buffer), "Merhaba dünya 🌍");
  equal(decoder.decode(new DataView(bytes.buffer, 0, 7)), "Merhaba");
  equal(decoder.decode(), "");
});

test("TextDecoder supports UTF-16LE and Latin-1 labels", (web) => {
  equal(
    new web.TextDecoder("utf-16le").decode(
      new Uint8Array([0x48, 0x00, 0x3d, 0xd8, 0x00, 0xde]),
    ),
    "H😀",
  );
  const latin = new web.TextDecoder("latin1");
  equal(latin.encoding, "windows-1252");
  equal(latin.decode(new Uint8Array([0x63, 0x61, 0x66, 0xe9, 0x80])), "café€");
  equal(new web.TextDecoder(" UTF8 ").encoding, "utf-8");
  throws(() => new web.TextDecoder("klingon"), "RangeError");
});

test("atob and btoa round trip and reject bad input", (web) => {
  equal(web.btoa("Hello, world"), "SGVsbG8sIHdvcmxk");
  equal(web.btoa("\u{FF}\u{FE}"), "//4=");
  equal(web.atob("SGVsbG8sIHdvcmxk"), "Hello, world");
  equal(web.atob(" SGVs bG8 "), "Hello");
  equal(web.atob("YQ"), "a");
  throws(() => web.btoa("€"), "InvalidCharacterError");
  throws(() => web.atob("a"), "InvalidCharacterError");
  throws(() => web.atob("a*b="), "InvalidCharacterError");
});

type URLCase = {
  input: string;
  base: string | null;
  failure?: boolean;
  href?: string;
  origin?: string;
};

test("URL passes the web-platform-tests parsing data", (web) => {
  const failures: Array<string> = [];
  for (const entry of urlData as Array<unknown>) {
    if (typeof entry !== "object" || entry === null) continue;
    const { input, base, failure, href, origin } = entry as URLCase;
    let url: URL | null = null;
    try {
      url = new web.URL(input, base ?? undefined);
    } catch {
      url = null;
    }
    const isMatches =
      failure === true
        ? url == null
        : url != null &&
          url.href === href &&
          (origin == null || url.origin === origin);
    if (!isMatches) {
      failures.push(
        `${JSON.stringify(input)} against ${String(base)}: ${String(url?.href)}`,
      );
    }
  }
  deep(failures.slice(0, 5), []);
});

test("URL setters pass the web-platform-tests data", (web) => {
  const failures: Array<string> = [];
  for (const [property, tests] of Object.entries(setterData)) {
    if (!Array.isArray(tests)) continue;
    for (const test of tests as Array<unknown>) {
      if (typeof test !== "object" || test === null) continue;
      const {
        href,
        new_value: value,
        expected,
      } = test as {
        href: string;
        new_value: string;
        expected: Record<string, string>;
      };
      const url = new web.URL(href);
      Reflect.set(url, property, value);
      for (const [key, result] of Object.entries(expected)) {
        if (Reflect.get(url, key) !== result)
          failures.push(
            `${property}=${JSON.stringify(value)} on ${href}: ${key}`,
          );
      }
    }
  }
  deep(failures.slice(0, 5), []);
});

test("URL exposes components, canParse, parse, and JSON", (web) => {
  const url = new web.URL(
    "../b/c?x=1#top",
    "https://user:pw@例子.example:8080/a/z",
  );
  equal(url.href, "https://user:pw@xn--fsqu00a.example:8080/b/c?x=1#top");
  equal(url.origin, "https://xn--fsqu00a.example:8080");
  equal(url.host, "xn--fsqu00a.example:8080");
  equal(url.pathname, "/b/c");
  equal(
    JSON.stringify({ url }),
    '{"url":"https://user:pw@xn--fsqu00a.example:8080/b/c?x=1#top"}',
  );
  equal(web.URL.canParse("nope"), false);
  equal(web.URL.canParse("/x", "http://a"), true);
  throws(() => new web.URL("http://exa mple.com"), "TypeError");
  url.port = "443";
  equal(url.port, "");
  url.protocol = "http";
  url.port = "81";
  equal(url.href, "http://user:pw@xn--fsqu00a.example:81/b/c?x=1#top");
  url.searchParams.append("y", "a b");
  equal(url.search, "?x=1&y=a+b");
  url.search = "";
  equal(url.searchParams.size, 0);
});

test("URLSearchParams parses, mutates, sorts, and serializes", (web) => {
  const params = new web.URLSearchParams("?a=1&b=x+y&a=2&c=%F0%9F%98%80&d");
  equal(params.get("a"), "1");
  deep(params.getAll("a"), ["1", "2"]);
  equal(params.get("b"), "x y");
  equal(params.get("c"), "😀");
  equal(params.get("d"), "");
  equal(params.get("missing"), null);
  equal(params.has("a", "2"), true);
  equal(params.size, 5);
  params.set("a", "3");
  params.delete("d");
  params.append("z", "~!'()*");
  params.sort();
  equal(params.toString(), "a=3&b=x+y&c=%F0%9F%98%80&z=%7E%21%27%28%29*");
  deep(collect(params.keys()), ["a", "b", "c", "z"]);
  deep(Object.fromEntries(new web.URLSearchParams({ q: "1", r: "2" })), {
    q: "1",
    r: "2",
  });
  deep([...new web.URLSearchParams([["k", "v"]])], [["k", "v"]]);
  const order: Array<string> = [];
  new web.URLSearchParams("b=2&a=1").forEach((value, name) => {
    order.push(name + value);
  });
  deep(order, ["b2", "a1"]);
});

test("structuredClone copies values, cycles, and shared buffers", (web) => {
  const shared = new Uint8Array([1, 2, 3, 4]);
  const source = {
    date: new Date(5),
    map: new Map<unknown, unknown>([["k", { v: 1 }]]),
    set: new Set([1, 2]),
    regexp: /a+/gi,
    big: 10n,
    left: shared.subarray(1, 3),
    right: new Uint16Array(shared.buffer, 2, 1),
    nested: [undefined, null, NaN, -0],
    self: null as unknown,
  };
  source.self = source;
  const copy = web.structuredClone(source);
  ok(copy !== source && copy.self === copy, "the cycle is preserved");
  equal(copy.date.getTime(), 5);
  deep(copy.map.get("k"), { v: 1 });
  ok(copy.map.get("k") !== source.map.get("k"), "nested values are copied");
  deep([...copy.set], [1, 2]);
  equal(copy.regexp.flags, "gi");
  equal(copy.big, 10n);
  ok(copy.left.buffer === copy.right.buffer, "views share one copied buffer");
  ok(copy.left.buffer !== shared.buffer, "the buffer is copied");
  deep([...copy.left], [2, 3]);
  equal(copy.nested.length, 4);
  equal(Object.is(copy.nested[3], -0), true);
  equal(Number.isNaN(copy.nested[2]), true);
});

test("structuredClone handles errors, rejects functions, and transfers buffers", (web) => {
  const error = web.structuredClone(new RangeError("too far"));
  ok(error instanceof RangeError, "the error type is kept");
  equal(error.message, "too far");
  throws(() => web.structuredClone({ run: () => 1 }), "DataCloneError");
  throws(() => web.structuredClone(Symbol("s")), "DataCloneError");
  const buffer = new Uint8Array([9, 8]).buffer;
  const moved = web.structuredClone({ buffer }, { transfer: [buffer] });
  equal(buffer.byteLength, 0);
  deep([...new Uint8Array(moved.buffer)], [9, 8]);
  class Point {
    x = 1;
  }
  const point = web.structuredClone(new Point());
  deep(point, { x: 1 });
  ok(!(point instanceof Point), "class instances become plain objects");
});

test("Blob and File store bytes, types, and names", async (web) => {
  const blob = new web.Blob(
    ["héllo ", new Uint8Array([0x77]), new web.Blob(["orld"])],
    { type: "Text/Plain" },
  );
  equal(blob.size, 12);
  equal(blob.type, "text/plain");
  equal(await blob.text(), "héllo world");
  equal(await blob.slice(7).text(), "world");
  equal(await blob.slice(-5, -1, "x/y").text(), "worl");
  equal(blob.slice(0, 1, "X/Y").type, "x/y");
  equal(new Uint8Array(await blob.arrayBuffer())[0], 0x68);
  equal(new web.Blob(["x"], { type: "a\u{E9}" }).type, "");
  const file = new web.File(["data"], "notes.txt", {
    type: "text/plain",
    lastModified: 42,
  });
  equal(file.name, "notes.txt");
  equal(file.lastModified, 42);
  ok(file instanceof web.Blob, "a File is a Blob");
  ok(
    Math.abs(new web.File([], "now").lastModified - Date.now()) < 5000,
    "lastModified defaults to now",
  );
  const reader = blob.stream().getReader();
  let read = "";
  for (
    let result = await reader.read();
    !result.done;
    result = await reader.read()
  )
    read += new web.TextDecoder().decode(result.value);
  equal(read, "héllo world");
});

test("FormData keeps entries and turns blobs into files", async (web) => {
  const form = new web.FormData();
  form.append("a", "1");
  form.append("a", "2");
  form.append("file", new web.Blob(["x"], { type: "text/plain" }));
  form.append("named", new web.Blob(["y"]), "y.bin");
  equal(form.get("a"), "1");
  deep(form.getAll("a"), ["1", "2"]);
  const file = form.get("file") as File;
  equal(file.name, "blob");
  equal(file.type, "text/plain");
  equal((form.get("named") as File).name, "y.bin");
  form.set("a", "3");
  deep(form.getAll("a"), ["3"]);
  form.delete("named");
  equal(form.has("named"), false);
  deep(collect(form.keys()), ["a", "file"]);
  equal(await file.text(), "x");
});

test("Headers normalize names, combine values, and sort", (web) => {
  const headers = new web.Headers({ "X-B": "2", "x-a": " 1 " });
  headers.append("X-A", "3");
  headers.append("Set-Cookie", "a=1");
  headers.append("set-cookie", "b=2");
  equal(headers.get("x-a"), "1, 3");
  equal(headers.get("X-B"), "2");
  equal(headers.get("set-cookie"), "a=1, b=2");
  deep(headers.getSetCookie(), ["a=1", "b=2"]);
  deep(
    [...headers],
    [
      ["set-cookie", "a=1"],
      ["set-cookie", "b=2"],
      ["x-a", "1, 3"],
      ["x-b", "2"],
    ],
  );
  headers.set("x-a", "4");
  headers.delete("X-B");
  deep(collect(headers.keys()), ["set-cookie", "set-cookie", "x-a"]);
  throws(() => new web.Headers({ "bad name": "x" }), "TypeError");
  throws(() => headers.set("x", "a\nb"), "TypeError");
  deep([...new web.Headers([["a", "1"]])], [["a", "1"]]);
});

test("Request normalizes methods, bodies, and defaults", async (web) => {
  const request = new web.Request("https://example.com/a?b#c", {
    method: "post",
    body: "hi",
  });
  equal(request.method, "POST");
  equal(request.url, "https://example.com/a?b#c");
  equal(request.headers.get("content-type"), "text/plain;charset=UTF-8");
  equal(request.redirect, "follow");
  equal(request.credentials, "same-origin");
  equal(request.cache, "default");
  equal(request.mode, "cors");
  equal(request.signal.aborted, false);
  equal(new web.Request("https://x", { method: "patch" }).method, "patch");
  const clone = request.clone();
  equal(await request.text(), "hi");
  equal(request.bodyUsed, true);
  equal(await clone.text(), "hi");
  throws(
    () => new web.Request("https://x", { method: "GET", body: "no" }),
    "TypeError",
  );
  throws(() => new web.Request("https://user:pw@x"), "TypeError");
  throws(() => new web.Request("not a url"), "TypeError");
  throws(() => new web.Request("https://x", { method: "TRACE" }), "TypeError");
  const params = new web.Request("https://x", {
    method: "PUT",
    body: new web.URLSearchParams("a=1"),
  });
  equal(
    params.headers.get("content-type"),
    "application/x-www-form-urlencoded;charset=UTF-8",
  );
  const controller = new web.AbortController();
  const signaled = new web.Request("https://x", { signal: controller.signal });
  controller.abort();
  equal(signaled.signal.aborted, true);
});

test("Response reads bodies once and clones", async (web) => {
  const response = new web.Response('{"a":1}', {
    status: 201,
    statusText: "Made",
    headers: { "x-y": "z" },
  });
  equal(response.status, 201);
  equal(response.statusText, "Made");
  equal(response.ok, true);
  equal(response.type, "default");
  equal(response.headers.get("content-type"), "text/plain;charset=UTF-8");
  const clone = response.clone();
  deep(await response.json(), { a: 1 });
  await rejects(response.text(), "TypeError");
  equal(await clone.text(), '{"a":1}');
  const bytes = await new web.Response(new Uint8Array([1, 2])).arrayBuffer();
  equal(bytes.byteLength, 2);
  const typed = await new web.Response("blob", {
    headers: { "content-type": "text/x" },
  }).blob();
  equal(typed.type, "text/x");
  equal(new web.Response(null, { status: 204 }).body, null);
  throws(() => new web.Response("x", { status: 204 }), "TypeError");
  throws(() => new web.Response("x", { status: 99 }), "RangeError");
  equal(new web.Response().status, 200);
  equal(await new web.Response().text(), "");
});

test("Response static helpers", async (web) => {
  const error = web.Response.error();
  equal(error.type, "error");
  equal(error.status, 0);
  const redirect = web.Response.redirect("https://example.com/next", 301);
  equal(redirect.status, 301);
  equal(redirect.headers.get("location"), "https://example.com/next");
  throws(() => web.Response.redirect("https://example.com", 200), "RangeError");
  const json = web.Response.json({ ok: true }, { status: 202 });
  equal(json.status, 202);
  equal(json.headers.get("content-type"), "application/json");
  deep(await json.json(), { ok: true });
});

test("Response bodies stream and parse form data", async (web) => {
  const reader = new web.Response("streamed").body?.getReader();
  ok(reader, "the body is a stream");
  let text = "";
  for (
    let result = await reader.read();
    !result.done;
    result = await reader.read()
  )
    text += new web.TextDecoder().decode(result.value);
  equal(text, "streamed");
  const form = new web.FormData();
  form.append("name", "Ada\nLovelace");
  form.append("file", new web.File(["bytes"], "f.txt", { type: "text/plain" }));
  const multipart = new web.Response(form);
  ok(
    multipart.headers
      .get("content-type")
      ?.startsWith("multipart/form-data; boundary="),
    "multipart content type",
  );
  const parsed = await multipart.formData();
  equal(parsed.get("name"), "Ada\r\nLovelace");
  const file = parsed.get("file") as File;
  equal(file.name, "f.txt");
  equal(file.type, "text/plain");
  equal(await file.text(), "bytes");
  const encoded = await new web.Response(
    new web.URLSearchParams("a=1&b=two"),
  ).formData();
  equal(encoded.get("b"), "two");
});

type Echo = {
  method: string;
  path: string;
  headers: Record<string, string>;
  body: string;
};

test("fetch GETs JSON and exposes the response", async (web, server) => {
  const response = await web.fetch(`${server.http}/json`);
  equal(response.status, 200);
  equal(response.statusText, "OK");
  equal(response.ok, true);
  equal(response.type, "basic");
  equal(response.url, `${server.http}/json`);
  equal(response.redirected, false);
  equal(response.headers.get("content-type"), "application/json");
  deep(await response.json(), { ok: true, list: [1, 2, 3] });
});

test("fetch sends methods, headers, and text bodies", async (web, server) => {
  const response = await web.fetch(`${server.http}/echo?q=1`, {
    method: "PUT",
    headers: { "X-Custom": "yes", "Content-Type": "text/plain" },
    body: "hello ü",
  });
  const echo = (await response.json()) as Echo;
  equal(echo.method, "PUT");
  equal(echo.path, "/echo?q=1");
  equal(echo.headers["x-custom"], "yes");
  equal(echo.headers["content-type"], "text/plain");
  equal(echo.body, "hello ü");
});

test("fetch sends JSON, URLSearchParams, and FormData bodies", async (web, server) => {
  const jsonResponse = await web.fetch(`${server.http}/echo`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ a: 1 }),
  });
  const json = (await jsonResponse.json()) as Echo;
  equal(json.body, '{"a":1}');
  const paramsResponse = await web.fetch(`${server.http}/echo`, {
    method: "POST",
    body: new web.URLSearchParams({ a: "1 2" }),
  });
  const params = (await paramsResponse.json()) as Echo;
  equal(
    params.headers["content-type"],
    "application/x-www-form-urlencoded;charset=UTF-8",
  );
  equal(params.body, "a=1+2");
  const form = new web.FormData();
  form.append("field", "value");
  const multipartResponse = await web.fetch(`${server.http}/echo`, {
    method: "POST",
    body: form,
  });
  const multipart = (await multipartResponse.json()) as Echo;
  ok(
    multipart.headers["content-type"]?.startsWith(
      "multipart/form-data; boundary=",
    ),
    "multipart content type",
  );
  ok(
    multipart.body.includes(
      'Content-Disposition: form-data; name="field"\r\n\r\nvalue\r\n',
    ),
    "multipart body",
  );
});

test("fetch uploads and downloads binary bodies", async (web, server) => {
  const bytes = new Uint8Array(70_000);
  for (let index = 0; index < bytes.length; index++) bytes[index] = index % 251;
  const response = await web.fetch(`${server.http}/mirror`, {
    method: "POST",
    body: bytes,
  });
  equal(response.headers.get("content-type"), "application/octet-stream");
  const received = new Uint8Array(await response.arrayBuffer());
  equal(received.length, bytes.length);
  equal(
    received.every((byte, index) => byte === bytes[index]),
    true,
  );
  const downloadResponse = await web.fetch(`${server.http}/bytes?n=300`);
  const download = new Uint8Array(await downloadResponse.arrayBuffer());
  equal(download.length, 300);
  equal(download[299], 299 % 256);
  const blobResponse = await web.fetch(`${server.http}/bytes?n=10`);
  const blob = await blobResponse.blob();
  equal(blob.size, 10);
  equal(blob.type, "application/octet-stream");
});

test("fetch reports HTTP errors without rejecting", async (web, server) => {
  const missing = await web.fetch(`${server.http}/status/404`);
  equal(missing.status, 404);
  equal(missing.ok, false);
  equal(missing.statusText, "Not Found");
  equal(await missing.text(), "status 404");
  const empty = await web.fetch(`${server.http}/status/204`);
  equal(empty.status, 204);
  equal(empty.body, null);
  const unavailable = await web.fetch(`${server.http}/status/503`);
  equal(unavailable.statusText, "Service Unavailable");
});

test("fetch follows, exposes, and refuses redirects", async (web, server) => {
  const followed = await web.fetch(`${server.http}/redirect?to=/json`);
  equal(followed.status, 200);
  equal(followed.redirected, true);
  equal(followed.url, `${server.http}/json`);
  const manual = await web.fetch(`${server.http}/redirect?to=/json`, {
    redirect: "manual",
  });
  equal(manual.status, 302);
  equal(manual.headers.get("location"), "/json");
  await rejects(
    web.fetch(`${server.http}/redirect?to=/json`, { redirect: "error" }),
    "TypeError",
  );
});

test("fetch exposes response headers", async (web, server) => {
  const response = await web.fetch(`${server.http}/headers`);
  equal(response.headers.get("x-one"), "1");
  equal(response.headers.get("X-Two"), "two");
  throws(() => response.headers.set("x-one", "2"), "TypeError");
});

test("fetch streams response bodies as they arrive", async (web, server) => {
  const response = await web.fetch(`${server.http}/stream`);
  const reader = response.body?.getReader();
  ok(reader, "the body is a stream");
  const chunks: Array<string> = [];
  const decoder = new web.TextDecoder();
  for (
    let result = await reader.read();
    !result.done;
    result = await reader.read()
  ) {
    chunks.push(decoder.decode(result.value, { stream: true }));
  }
  equal(chunks.join(""), "one\ntwo\nthree\n");
  ok(
    chunks.length >= 2,
    `expected several chunks, got ${String(chunks.length)}`,
  );
});

test("fetch aborts before and during a request", async (web, server) => {
  await rejects(
    web.fetch(`${server.http}/json`, { signal: web.AbortSignal.abort() }),
    "AbortError",
  );
  const controller = new web.AbortController();
  const pending = web.fetch(`${server.http}/slow`, {
    signal: controller.signal,
  });
  setTimeout(() => controller.abort(), 20);
  await rejects(pending, "AbortError");
  await rejects(
    web.fetch(`${server.http}/slow`, { signal: web.AbortSignal.timeout(30) }),
    "TimeoutError",
  );
  const headersFirst = new web.AbortController();
  const response = await web.fetch(`${server.http}/stream?slow=1`, {
    signal: headersFirst.signal,
  });
  const reading = response.text();
  headersFirst.abort();
  await rejects(reading, "AbortError");
});

test("fetch rejects bad URLs, unsupported schemes, and network failures", async (web, server) => {
  await rejects(web.fetch("not a url"), "TypeError");
  await rejects(web.fetch("ftp://example.com/file"), "TypeError");
  const closed = server.http.replace(/:\d+$/, ":1");
  await rejects(web.fetch(`${closed}/json`), "TypeError");
});

test("fetch reads data URLs", async (web) => {
  const text = await web.fetch("data:,Hello%20there");
  equal(await text.text(), "Hello there");
  equal(text.headers.get("content-type"), "text/plain;charset=US-ASCII");
  const binary = await web.fetch(
    "data:application/octet-stream;base64,AAEC/w==",
  );
  deep([...new Uint8Array(await binary.arrayBuffer())], [0, 1, 2, 255]);
  equal(binary.headers.get("content-type"), "application/octet-stream");
});

async function open(
  web: Web,
  url: string,
  protocols?: Array<string>,
): Promise<WebSocket> {
  return new Promise((resolve, reject) => {
    const socket = new web.WebSocket(url, protocols);
    socket.addEventListener("open", () => resolve(socket));
    socket.addEventListener("error", () =>
      reject(new Error("The WebSocket failed to open")),
    );
  });
}

async function next(socket: WebSocket): Promise<MessageEvent> {
  return new Promise((resolve) =>
    socket.addEventListener("message", (event) => resolve(event), {
      once: true,
    }),
  );
}

async function closed(socket: WebSocket): Promise<CloseEvent> {
  return new Promise((resolve) =>
    socket.addEventListener("close", (event) => resolve(event), { once: true }),
  );
}

test("WebSocket connects, echoes text, and closes cleanly", async (web, server) => {
  const socket = await open(web, `${server.ws}/ws`);
  equal(socket.readyState, web.WebSocket.OPEN);
  equal(socket.url, `${server.ws}/ws`);
  equal(socket.protocol, "");
  const reply = next(socket);
  socket.send("hello ü");
  const message = await reply;
  equal(message.data, "hello ü");
  const done = closed(socket);
  socket.close(1000, "done");
  equal(socket.readyState, web.WebSocket.CLOSING);
  const event = await done;
  equal(event.code, 1000);
  equal(event.reason, "done");
  equal(event.wasClean, true);
  equal(socket.readyState, web.WebSocket.CLOSED);
});

test("WebSocket echoes binary as blobs or array buffers", async (web, server) => {
  const socket = await open(web, `${server.ws}/ws`);
  equal(socket.binaryType, "blob");
  let reply = next(socket);
  socket.send(new Uint8Array([1, 2, 3]));
  const blobMessage = await reply;
  const blob = blobMessage.data as Blob;
  deep([...new Uint8Array(await blob.arrayBuffer())], [1, 2, 3]);
  socket.binaryType = "arraybuffer";
  reply = next(socket);
  socket.send(new web.Blob([new Uint8Array([4, 5])]));
  const bufferMessage = await reply;
  const buffer = bufferMessage.data as ArrayBuffer;
  ok(buffer instanceof ArrayBuffer, "the message is an ArrayBuffer");
  deep([...new Uint8Array(buffer)], [4, 5]);
  const done = closed(socket);
  socket.close();
  const event = await done;
  equal(event.code, 1005);
});

test("WebSocket negotiates protocols and reports server closes", async (web, server) => {
  const socket = await open(web, `${server.ws}/ws`, ["chat", "superchat"]);
  equal(socket.protocol, "chat");
  const done = closed(socket);
  socket.send("close");
  const event = await done;
  equal(event.code, 4000);
  equal(event.reason, "bye");
  equal(event.wasClean, true);
});

test("WebSocket validates URLs, protocols, sends, and close codes", async (web, server) => {
  throws(() => new web.WebSocket("ftp://example.com"), "SyntaxError");
  throws(() => new web.WebSocket(`${server.ws}/ws#frag`), "SyntaxError");
  throws(() => new web.WebSocket(`${server.ws}/ws`, ["a", "a"]), "SyntaxError");
  const socket = new web.WebSocket(`${server.http}/ws`);
  equal(socket.url, `${server.ws}/ws`);
  equal(socket.readyState, web.WebSocket.CONNECTING);
  throws(() => socket.send("early"), "InvalidStateError");
  throws(() => socket.close(1001), "InvalidAccessError");
  throws(() => socket.close(1000, "x".repeat(124)), "SyntaxError");
  await new Promise((resolve) => socket.addEventListener("open", resolve));
  const done = closed(socket);
  socket.close(4001);
  const event = await done;
  equal(event.code, 4001);
});

test("WebSocket fires error and close when the connection fails", async (web, server) => {
  const socket = new web.WebSocket(server.ws.replace(/:\d+$/, ":1"));
  let isErrored = false;
  socket.addEventListener("error", () => (isErrored = true));
  const event = await closed(socket);
  equal(isErrored, true);
  equal(event.code, 1006);
  equal(event.wasClean, false);
});

test("crypto.getRandomValues fills integer arrays", (web) => {
  const bytes = new Uint8Array(64);
  equal(web.crypto.getRandomValues(bytes), bytes);
  ok(
    bytes.some((byte) => byte !== 0),
    "random bytes",
  );
  const words = web.crypto.getRandomValues(new Uint32Array(8));
  ok(
    words.some((word) => word !== 0),
    "random words",
  );
  ok(
    web.crypto.getRandomValues(new BigUint64Array(2))[0] !== undefined,
    "BigInt arrays work",
  );
  throws(
    () => web.crypto.getRandomValues(new Uint8Array(65_537)),
    "QuotaExceededError",
  );
  const floats: unknown = new Float32Array(1);
  throws(
    () => web.crypto.getRandomValues(floats as Uint8Array<ArrayBuffer>),
    "TypeMismatchError",
  );
});

test("crypto.randomUUID returns unique version 4 UUIDs", (web) => {
  const ids = new Set(
    Array.from({ length: 50 }, () => web.crypto.randomUUID()),
  );
  equal(ids.size, 50);
  for (const id of ids)
    ok(
      /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(
        id,
      ),
      id,
    );
});

test("crypto.subtle.digest hashes with SHA-1 and SHA-2", async (web) => {
  const data = new web.TextEncoder().encode("abc");
  equal(
    hex(await web.crypto.subtle.digest("SHA-256", data)),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
  equal(
    hex(await web.crypto.subtle.digest({ name: "SHA-1" }, data)),
    "a9993e364706816aba3e25717850c26c9cd0d89d",
  );
  const sha384 = await web.crypto.subtle.digest("sha-384", data);
  equal(sha384.byteLength, 48);
  equal(
    hex(await web.crypto.subtle.digest("SHA-512", data.buffer)),
    "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
  );
  await rejects(web.crypto.subtle.digest("MD5", data), "NotSupportedError");
});

test("performance measures time with marks and measures", async (web) => {
  const start = web.performance.now();
  ok(
    Math.abs(web.performance.timeOrigin + start - Date.now()) < 1000,
    "timeOrigin plus now is the wall clock",
  );
  web.performance.mark("suite-start", { detail: { step: 1 } });
  await delay(15);
  web.performance.mark("suite-end");
  const measure = web.performance.measure("suite", "suite-start", "suite-end");
  ok(measure.duration >= 10, `duration ${String(measure.duration)}`);
  equal(measure.entryType, "measure");
  const json: unknown = web.performance
    .getEntriesByName("suite-start")[0]
    ?.toJSON();
  deep(
    typeof json === "object" && json != null
      ? Reflect.get(json, "detail")
      : json,
    { step: 1 },
  );
  equal(
    web.performance.measure("since", { start: "suite-start", duration: 5 })
      .duration,
    5,
  );
  ok(web.performance.now() > start, "now is monotonic");
  throws(() => web.performance.measure("bad", "missing-mark"), "SyntaxError");
  web.performance.clearMarks("suite-start");
  equal(web.performance.getEntriesByName("suite-start").length, 0);
  web.performance.clearMeasures();
  equal(web.performance.getEntriesByType("measure").length, 0);
});

test("navigator reports languages", (web) => {
  ok(web.navigator.languages.length > 0, "at least one language");
  equal(web.navigator.language, web.navigator.languages[0]);
  for (const language of web.navigator.languages)
    ok(/^[a-z]{2,3}(?:-[A-Za-z0-9]+)*$/.test(language), language);
});

hostTest("sessionStorage stores strings in memory", (web) => {
  const storage = host(web).sessionStorage;
  storage.clear();
  const number: unknown = 1;
  storage.setItem("n", number as string);
  equal(storage.getItem("n"), "1");
  equal(Reflect.get(storage, "n"), "1");
  Reflect.set(storage, "p", "q");
  equal(storage.getItem("p"), "q");
  equal(storage.length, 2);
  equal(storage.key(0), "n");
  equal(storage.key(5), null);
  deep(Object.keys(storage), ["n", "p"]);
  storage.removeItem("n");
  equal(storage.getItem("n"), null);
  storage.clear();
  equal(storage.length, 0);
});

hostTest(
  "navigator.onLine and online and offline events follow the host",
  (web) => {
    const environment = host(web);
    const events: Array<string> = [];
    const listener = (event: Event): void => void events.push(event.type);
    environment.addEventListener("online", listener);
    environment.addEventListener("offline", listener);
    environment.setEnvironment({ onLine: false });
    equal(environment.onLine(), false);
    environment.setEnvironment({ onLine: false });
    environment.setEnvironment({ onLine: true });
    equal(environment.onLine(), true);
    environment.removeEventListener("online", listener);
    environment.removeEventListener("offline", listener);
    deep(events, ["offline", "online"]);
  },
);

hostTest(
  "matchMedia evaluates color scheme and motion queries and reports changes",
  (web) => {
    const environment = host(web);
    environment.setEnvironment({ colorScheme: "light", reduceMotion: false });
    const dark = environment.matchMedia("(prefers-color-scheme: dark)");
    equal(dark.matches, false);
    equal(
      environment.matchMedia("(prefers-color-scheme: light)").matches,
      true,
    );
    equal(
      environment.matchMedia("(prefers-reduced-motion: no-preference)").matches,
      true,
    );
    equal(
      environment.matchMedia("screen and (prefers-reduced-motion: reduce)")
        .matches,
      false,
    );
    equal(
      environment.matchMedia("not all and (prefers-color-scheme: dark)")
        .matches,
      true,
    );
    equal(
      environment.matchMedia("(prefers-color-scheme: dark), (hover: none)")
        .matches,
      true,
    );
    equal(environment.matchMedia("(pointer: coarse)").matches, true);
    equal(environment.matchMedia("(min-width: 600px)").matches, false);
    equal(environment.matchMedia("garbage").matches, false);
    const changes: Array<boolean> = [];
    const listener = (event: MediaQueryListEvent): void =>
      void changes.push(event.matches);
    dark.addEventListener("change", listener as (event: Event) => void);
    environment.setEnvironment({ colorScheme: "dark" });
    equal(dark.matches, true);
    environment.setEnvironment({ reduceMotion: true });
    environment.setEnvironment({ colorScheme: "light" });
    dark.removeEventListener("change", listener as (event: Event) => void);
    environment.setEnvironment({ colorScheme: "dark" });
    deep(changes, [true, false]);
    environment.setEnvironment({ colorScheme: "light", reduceMotion: false });
  },
);

export async function runCases(
  web: Web,
  server: Server,
  shouldRun?: (name: string) => boolean,
): Promise<Array<{ name: string; error: string | null }>> {
  const results: Array<{ name: string; error: string | null }> = [];
  for (const { name, run } of cases) {
    if (shouldRun != null && !shouldRun(name)) continue;
    try {
      await run(web, server);
      results.push({ name, error: null });
    } catch (error) {
      results.push({
        name,
        error:
          error instanceof Error
            ? `${error.name}: ${error.message}`
            : String(error),
      });
    }
  }
  return results;
}
