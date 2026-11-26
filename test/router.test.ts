import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { flushSync } from "svelte";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import type { Matchers } from "swiftui-svelte/kit/match";
import {
  compareSegments,
  matchSegments,
  parseSegments,
  resolveRoute,
} from "swiftui-svelte/kit/match";
import { back, goto, invalidate } from "swiftui-svelte/kit/navigation";
import { resolve } from "swiftui-svelte/kit/paths";
import { page } from "swiftui-svelte/kit/state";
import Router from "../src/kit/Router.svelte";
import { routesModule } from "../src/routes.ts";
import {
  byTestId,
  dispatch,
  find,
  findAll,
  mountComponent,
  reset,
} from "./bridge.ts";

const matchers: Matchers = { digits: (value) => /^\d+$/.test(value) };

function match(
  pattern: string,
  pathname: string,
): Record<string, string | undefined> | null {
  return matchSegments(parseSegments(pattern), pathname, matchers);
}

async function tick(): Promise<void> {
  await new Promise((resolve) => setTimeout(resolve, 0));
  flushSync();
}

function text(id: string): string | undefined {
  return byTestId(id)?.children[0]?.text;
}

function titles(): Array<unknown> {
  return findAll("screen").map((screen) => screen.attributes.get("title"));
}

describe("route patterns", () => {
  it("matches static, rest, optional, and matcher segments", () => {
    expect(match("/files/[...path]", "/files/a/b")).toEqual({ path: "a/b" });
    expect(match("/[[lang]]", "/")).toEqual({ lang: undefined });
    expect(match("/[[lang]]", "/tr")).toEqual({ lang: "tr" });
    expect(match("/digits/[id=digits]", "/digits/12")).toEqual({ id: "12" });
    expect(match("/digits/[id=digits]", "/digits/ab")).toBeNull();
    expect(match("/items/[id]", "/items/a%20b")).toEqual({ id: "a b" });
    expect(match("/items/[id]", "/items")).toBeNull();
  });

  it("ranks static segments above dynamic ones and rest segments last", () => {
    const patterns = [
      "/[...rest]",
      "/[[x]]",
      "/[slug]",
      "/files/[...rest]",
      "/digits/[id=digits]",
      "/about",
    ];
    const sorted = patterns.toSorted((left, right) =>
      compareSegments(parseSegments(left), parseSegments(right)),
    );
    expect(sorted).toEqual([
      "/about",
      "/digits/[id=digits]",
      "/files/[...rest]",
      "/[slug]",
      "/[[x]]",
      "/[...rest]",
    ]);
  });

  it("resolves route IDs to paths", () => {
    expect(resolve("/items/[id]", { id: "7" })).toBe("/items/7");
    expect(resolve("/(static)/about")).toBe("/about");
    expect(resolve("/[[lang]]/files/[...path]", { path: "a/b" })).toBe(
      "/files/a/b",
    );
    expect(resolve("/")).toBe("/");
    expect(resolve("arama/sonuc?sources=TDK")).toBe("arama/sonuc?sources=TDK");
  });

  it("resolves the first route that matches", () => {
    const routes = ["/items/[id]", "/items/new"].map((id) => ({
      segments: parseSegments(id),
      id,
    }));
    const sorted = routes.toSorted((left, right) =>
      compareSegments(left.segments, right.segments),
    );
    expect(resolveRoute(sorted, "/items/new", matchers)?.route.id).toBe(
      "/items/new",
    );
    expect(resolveRoute(sorted, "/items/7", matchers)?.route.id).toBe(
      "/items/[id]",
    );
  });
});

describe("route generation", () => {
  it("emits the routes in rank order with their layouts, loads, and matchers", () => {
    const source = path.resolve("test/router/src");
    const code = routesModule(process.cwd(), source);
    expect(code).toContain('id: "/items/[id]"');
    expect(code).toContain('"digits": m');
    expect(code.indexOf('id: "/about"')).toBeLessThan(
      code.indexOf('id: "/items/[id]"'),
    );
    expect(code).toContain('presentation: "sheet"');
    expect(code).toContain("layout: m");
  });

  it("rejects routes that match the same URLs", () => {
    const root = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-routes-"));
    for (const group of ["(a)", "(b)"]) {
      const directory = path.join(root, "src", "routes", group, "x");
      mkdirSync(directory, { recursive: true });
      writeFileSync(path.join(directory, "+page.svelte"), "<txt>x</txt>\n");
    }
    expect(() => routesModule(root, path.join(root, "src"))).toThrow(
      /conflict/,
    );
  });

  it("rejects a matcher that has no file in params", () => {
    const root = mkdtempSync(path.join(tmpdir(), "swiftui-svelte-routes-"));
    const directory = path.join(root, "src", "routes", "[id=missing]");
    mkdirSync(directory, { recursive: true });
    writeFileSync(path.join(directory, "+page.svelte"), "<txt>x</txt>\n");
    expect(() => routesModule(root, path.join(root, "src"))).toThrow(
      /matcher missing/,
    );
  });
});

describe("router", () => {
  let unmount: (() => void) | undefined;

  beforeAll(async () => {
    reset();
    unmount = mountComponent(Router);
    await tick();
  });

  afterEach(async () => {
    while (findAll("screen").length > 1 || find("sheet") != null) {
      if (find("sheet") != null) dispatch(find("sheet"), "dismiss");
      else dispatch(find("navstack"), "pop", 0);
      await tick();
    }
  });

  it("renders the root route with its layout and screen title", () => {
    expect(text("home")).toBe("Home");
    expect(byTestId("root-layout")).toBeDefined();
    expect(titles()).toEqual(["Home"]);
  });

  it("pushes a route, exposes it on page, and pops it from the native stack", async () => {
    await goto("/items/2");
    await tick();
    expect(titles()).toEqual(["Home", "Item 2"]);
    expect(page.url.pathname).toBe("/items/2");
    expect(page.route.id).toBe("/items/[id]");
    expect(page.params.id).toBe("2");
    expect(text("item")).toBe("Item 2 loaded 1 times");
    dispatch(find("navstack"), "pop", 0);
    await tick();
    expect(titles()).toEqual(["Home"]);
    expect(page.url.pathname).toBe("/");
  });

  it("replaces the top screen with replaceState", async () => {
    await goto("/items/1");
    await goto("/items/3", { replaceState: true });
    await tick();
    expect(titles()).toEqual(["Home", "Item 3"]);
    back();
    await tick();
    expect(titles()).toEqual(["Home"]);
  });

  it("renders the root error page with the status when a load fails", async () => {
    await goto("/items/9");
    await tick();
    expect(text("root-error")).toBe("404 No such item");
    expect(page.status).toBe(404);
    expect(page.error?.message).toBe("No such item");
    expect(byTestId("root-layout")).toBeDefined();
  });

  it("renders the nearest error page inside the layouts above it", async () => {
    await goto("/nested/missing");
    await tick();
    expect(text("nested-error")).toBe("Nested error 404");
    expect(byTestId("nested-layout")).toBeUndefined();
    expect(byTestId("root-layout")).toBeDefined();
  });

  it("renders a 404 for unknown routes and a 500 for thrown errors", async () => {
    await goto("/nope");
    await tick();
    expect(text("root-error")).toBe("404 Not Found");
    await goto("/broken");
    await tick();
    expect(text("root-error")).toBe("500 Internal Error");
  });

  it("follows redirects from load", async () => {
    await goto("/redirect");
    await tick();
    expect(text("home")).toBe("Home");
    expect(titles()).toEqual(["Home"]);
  });

  it("matches parameters with matchers and rest segments", async () => {
    await goto("/digits/12");
    await tick();
    expect(text("digits")).toBe("Digits 12");
    await goto("/digits/ab");
    await tick();
    expect(text("root-error")).toBe("404 Not Found");
    await goto("/files/a/b");
    await tick();
    expect(text("files")).toBe("a/b");
  });

  it("presents sheet routes over the current screen with their group layout", async () => {
    await goto("/about");
    await tick();
    expect(find("sheet")).toBeDefined();
    expect(text("about")).toBe("About this app");
    expect(text("static-layout")).toBe("Static layout");
    dispatch(find("sheet"), "dismiss");
    await tick();
    expect(find("sheet")).toBeUndefined();
  });

  it("reruns loads that depend on an invalidated key", async () => {
    await goto("/items/1");
    await tick();
    const before = text("item");
    await invalidate("app:items");
    await tick();
    expect(text("item")).not.toBe(before);
  });

  it("resolves deep links through the router", async () => {
    globalThis.__svelteAppEvent("openurl", "route:/items/3");
    await new Promise((resolve) => setTimeout(resolve, 10));
    await tick();
    expect(titles()).toEqual(["Home", "Item 3"]);
  });

  it("cancels a navigation from beforeNavigate until the screen that added it closes", async () => {
    await goto("/guarded");
    await tick();
    await goto("/items/1");
    await tick();
    expect(titles()).toEqual(["Home", "Guarded"]);
    back();
    await tick();
    await goto("/items/1");
    await tick();
    expect(titles()).toEqual(["Home", "Item 1"]);
  });

  it("unmounts cleanly", () => {
    unmount?.();
    unmount = undefined;
  });
});
